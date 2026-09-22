# The flex layout pipeline

This document describes `src/piigui/layout/flex.nim` — the flex layout engine
used by `flex`, `flexRow`, `flexColumn` and friends. It is a high-level
specification of what happens and in which order. For the code-grained
skeleton, see `doc/recalcflex_logic.txt`.

## What flex layout does

`recalcFlex` computes, for one layer of one element, the box (`x1`, `y1`, `x2`,
`y2`, `w`, `h`) of every child and the size of the content as a `(w, h)` tuple.

Children are organised either in **rows** (`flexDirection: fdRow`, flow
left → right and wrap to new rows) or in **columns** (`fdColumn`, flow
top → bottom and wrap to new columns). `fdUndefined` behaves like `fdColumn`.

A single reusable `FlexLayout` state object is threaded through every step of
one pass. It holds the free space remaining in the line being assembled, a
cursor (`nextX` / `nextY`) where the next child goes, the finished lines
(`article`), and the content totals. Passing a `var state` around instead of
capturing it in closures keeps this hot path allocation-free and the helpers
plain `nimcall` procs.

## The pipeline at a glance

```
recalcFlex
  ├─ sync the root box to the window size (if this is the root)
  ├─ compute the inner area  (w/h minus padding)
  ├─ layoutPass … 1 or 2 times (ofScroll reserves scrollbar space)
  │     resetState → mainLayout → (postProcess*) → distributeContent
  ├─ store the content size as innerW / innerH
  └─ recurse into every child's layers (bottom-up)
```

### Pass 1: the entry point — `recalcFlex`

1. **No children** → return immediately, nothing to lay out.
2. **Root sync** — if `this.parent == nil`, the container's box is overwritten
   with the window size (`sdl.getSize`). A window resize therefore automatically
   re-layouts the whole tree on the next `recalcDOM`.
3. **Inner area** — the space actually available to the content is the
   container's size minus `padding` on both sides, clamped to ≥ 0.
4. **One or two passes.** Scrolling is the default (`ofScroll`), and a
   scrollable container is laid out twice:
   - Pass 1 uses the full inner area. If the resulting content is taller or
     wider than the area, a scrollbar is needed.
   - Pass 2 reserves `ScrollBarSize` pixels for the bars (a vertical bar shrinks
     the width, a horizontal one shrinks the height) and re-runs, so no content
     hides behind the scrollbar. The need is re-checked, which rarely changes.
   - `ofHidden` containers run a single pass; overflow is simply clipped.
5. **Result** — the final content size is stored on the container as `innerW` /
   `innerH`. For a scrollable container this is the value the scroll system
   turns into a scroll range. `recalcFlex` returns it as its result.
6. **Recurasion** — after a container is done, each child's layers are laid out
   the same way, so the whole tree is positioned bottom-up.

### One pass — `layoutPass`

```
resetState   →   mainLayout   →   distributeContent
```

`resetState` zeroes the state: cursors back to the inner top-left corner,
`remainingWidth` / `remainingHeight` filled back to the whole area, and the
line buffers cleared. Reusing one object means no allocation per pass.

### The core loop — `mainLayout`

Walks the layer's children in order and does three things per child:
**measure**, **place**, **break**.

- `BRElem` children are explicit line breaks: they close the current line/column
  and start a new one.
- **Measure.** Each child's size comes from its units:
  - `muPx` — a fixed pixel value (scaled by `window.scale`).
  - `muPc` — a percentage of the area (floor minus 1).
  - `muAuto` / `muStretch` — no explicit size: for `fdRow` the height is set to
    1 and stretched to the row height later; in `fdColumn` the width is the
    remaining width. The *stretch* variant on the main axis takes the
    **remaining** space and ends its own line — it is meant for the last child
    of a row/column (or as an explicit full-width/height separator). To grow
    several children equally, use `flexGrow` instead.
- **Place.** The cursor `nextX` / `nextY` is where the next child's upper-left
  corner goes; coordinates are written as `x1 = nextX`, `x2 = nextX + w - 1`,
  and so on. `spacing` (if set) is added after every child except the last — the
  trailing spacing is subtracted again in `postProcess*` so line widths stay the
  true content widths.
- **Break.** In `fdRow` the line height is kept equal to the tallest child. A
  fixed/percentage child that does not fit the remaining width wraps to a new
  row — *unless* the container scrolls, in which case rows flow on forever and
  scrolling exposes the rest. The auto/stretch child always ends the row.
  `fdColumn` is the mirror image, with the line *width* equal to the widest
  child and wrapping based on remaining height.

When the loop ends, the last line is finalized (`postProcessRow` /
`postProcessColumn`) and `distributeContent` runs if there is free space in the
container.

### Newline bookkeeping — `newRow` / `newColumn`

Closing the current line runs its `postProcess*` first, then the cursor moves
down (a row) or right (a column), `remainingWidth`/`remainingHeight` are
returned to full for the new line, and `nextX`/`nextY` are reset to the inner
edge plus `spacing`.

### Finalizing a line — `postProcessRow` / `postProcessColumn`

These two do the same job in their own axis: align children inside the line,
grow flexible children, and record the line in `article`.

1. **Record the line** (row variant: before the grow pass; column variant:
   after it — the column records the grown size so `distributeContent` sees the
   real content, see the ordering reminder below).
2. **Stretch auto children** (row variant) — children sized `muAuto`/
   `muStretch` whose height was still 1 grow to the line height, or to the whole
   remaining/area height the first time around.
3. **`alignItems`** — the vertical alignment *inside* the row: `start` (top),
   `end`, `center`, or `stretch` (grow to the line height). In a column this
   alignment is horizontal.
4. **`flexGrow`** — if the line does not fill the main axis and the `flexGrow`
   total is positive, free space is divided among the growing children
   proportional to their `flexGrow` value. Integer division leftovers go (one by
   one) to the child with the largest `flexGrow`, and each grown element pushes
   the following children along so the line stays contiguous. The whole grow
   only happens if the line already fills the `flexGrowFrom` percentage of the
   area.
5. **Totals** — `contentWidth` / `contentHeight` and the `article.lineDims`
   entry are updated after any growing, so the final content size is accurate.

### Spreading the content — `distributeContent`

After all lines exist, this places them inside the container.

- **`alignContent`** arranges the *lines* in the opposite axis of the flow
  (rows spread vertically, columns horizontally):
  - `start` — leave everything as is.
  - `end` — pack against the inner bottom (row) / right (column) edge.
  - `center` — shift the whole block by half the free space.
  - `stretch` — grow each line by an equal share of the free space until the
    container is filled.
  - `spaceBetween` — equal gaps *between* the lines.
  - `spaceAround` — equal gaps around each line.
  All space divisions use integer math; rounding leftovers are handed out one
  pixel at a time.
- **`justifyContent`** arranges the content *inside each line* on the main axis:
  `start`, `end`, `center` (each line kept as its own width/height, so rows
  align left/right independently).
- **Guard:** if the content already overflows the container (`content > area`),
  nothing is spread — the content will scroll, so shifting it would be wrong.

## Ordering reminder: flex-grow runs before the content size is final

The flex-grow pass lives in `postProcessColumn` / `postProcessRow`. It can grow
a line (`lineWidth` for a row, `lineHeight` for a column) *after* the children
were first sized. The content totals and the `article.lineDims` entry for that
line must therefore be finalized **after** the grow pass (the column variant
already records its article entry at the end; keep it that way).

If they are recorded too early, `distributeContent` sees a content size smaller
than the real one, concludes the line does not fill the container, and applies
`justifyContent` (e.g. `fjcCenter`) to add a phantom offset — pushing the
content away from the container's padding edge.

## Two axes, one template

Everything in this pipeline exists twice, once per axis; only the meaning of
`width`/`height` and `x`/`y` swaps. In `fdRow` the "line" is a row: its height
is the tallest child and items grow horizontally. In `fdColumn` the "line" is a
column: its width is the widest child and items grow vertically. Keeping the
mental mirror image makes the state machine easy to follow.

## Interaction with the rest of the project

- **Scrolling** — only `recalcFlex` does the two-pass scrollbar reservation and
  sets `innerW` / `innerH`; `recalcH` / `recalcV` (used by `row` / `column`) are
  intentionally single-line and non-scrollable. See `doc/scroll_system.md`.
- **Clears** — the `debug` echo level is `0` by default; raise it per file to
  trace passes (`> 0` lifecycle, `> 1` per line/element, `> 2` full dumps).