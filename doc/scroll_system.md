# Scrolling in piigui

## What the scroll system does

The scroll system provides scrollbars, if needed.

Scrolling is the default. Every container whose children are taller or wider than
its own box gets a scrollbar automatically, and the user can move through the
content with the mouse wheel, by clicking the arrow buttons, by clicking the
track to page-scroll, or by dragging the slider.

When the content fits, no scrollbar is shown and nothing changes: the container
behaves exactly like a normal one.

You normally do not configure anything. If you want a container to *not* scroll
and instead clip away the parts that overflow, set its `overFlow` property to
`ofHidden`, for example:

```nim
let list = flexColumn(gui.rootElem, 0, "list", "", "100%", "60%")
list.inlineStyle.overFlow = ofHidden
```

The root element (`gui.rootElem`) is a normal scrollable container too: if its
content overflows the window, it gets a scrollbar at the window edge.

Everything else is handled automatically: the layout reports the real content
size, a `ScrollBar` overlay is built on demand (a track, a slider and four arrow
buttons), the overlay is drawn on top of the content, hit-tested first, and
wheel / click / drag input is routed to it.

The scrollbar is styled through the usual style system. It always inherits
`defaultSST["rootStyle"]`, and it optionally layers the class styles
`scrollbarTrack`, `scrollbarSlider` and `scrollbarArrow` on top if you define
them in `defaultSST` (including their `hover` / `focus` pseudo-styles). If you
do not define them, the scrollbar simply uses the inherited colors.

---

## The scrolling pipeline

Here is what happens, step by step.

First you build the tree. Scrolling needs no opt-in; a container scrolls as soon
as its children overflow:

```nim
let list = flexColumn(gui.rootElem, 0, "list", "", "100%", "60%")

for i in 0 ..< 50:
  discard list.newLabel(0, "item" & $i, "", "100%", "24px")
```

Then, after all elements are added, `gui.rootElem.recalcDOM()` is called.



`recalcDOM(rootElem)` walks the layout. For every layer it calls the layer's
`recalc` procedure (for example `recalcFlex`), which positions every child
(`x1`, `y1`, `x2`, `y2`, `w`, `h`) inside the parent and returns the content
size as a `(w, h)` tuple. That tuple is stored on the layer as `layer.w` and
`layer.h`.

`recalcDOM` then calls `recalcScrollbars(rootElem)`, which walks the whole tree.
For every element whose style is `overFlow == ofScroll` (the default) and whose
content overflows (`innerW > w` or `innerH > h`), it lazily builds the `ScrollBar`
overlay, sets the derived `scrollable` flag to `true`, and positions the overlay.
Elements with `overFlow == ofHidden` never scroll (their overflow is clipped).

Inside a layout procedure, a scrollable container (`overFlow == ofScroll`) lays
its children out twice. The first pass uses the full available width and height.
If the resulting content size is larger than the available space, a scrollbar is
needed, and the container reserves `ScrollBarSize` pixels: a vertical scrollbar
shrinks the available width, a horizontal scrollbar shrinks the available height.
The layout is then run a second time with the reduced space, so no content is
hidden behind the scrollbar.

The final content size is stored on the container itself as `innerW` and
`innerH`. These two values are the source of truth for everything that follows:

`recalcScrollbar` derives two flags from them. `vScroll = innerH > this.h`
means the content is taller than the viewport, so a vertical scrollbar is shown.
`hScroll = innerW > this.w` means the content is wider than the viewport, so a
horizontal scrollbar is shown. It then positions the track, the slider and the
two arrow buttons of each visible axis from `innerW` / `innerH`, the container
size and the current scroll offsets `scrollX` / `scrollY`.

The slider size and position are proportional. The slider height is
`trackH * this.h div innerH`, so it visually represents the visible part of the
content. Its position is computed from `scrollY` relative to the total scroll
range, which is `max(0, innerH - this.h)`.

Scrolling itself is just changing `scrollX` / `scrollY`. `scrollTo` clamps the
new offset to `[0, innerW - this.w]` / `[0, innerH - this.h]` and repositions
the slider. `scrollBy` adds a delta and calls `scrollTo`. `scrollWheel` is the
mouse-wheel entry point and moves by `ScrollBarWheelStep` per wheel notch.

When the offsets change, the content is not re-laid-out and not re-rendered.
`drawDOM` walks the tree carrying the accumulated scroll offsets of the
scrollable ancestors down to every element (`drawDOM` seeds the first call with
`scrollOffset`, `drawDOMImpl` adds each scrollable element's own `scrollX` /
`scrollY` for its children). Each element is drawn from its cached texture, and
its `draw` procedure shifts the destination rectangle by the offset it received.
The clip rectangle clips the shifted content to the parent's visible rectangle,
which is exactly the viewport effect a scrollbar needs.

Input is routed as follows.

The mouse wheel event first triggers the `wheelup`, `wheeldown`, `wheelleft` or
`wheelright` listeners on the hovered element. If none of those listeners
handled the event, the handler walks up from the hovered element and scrolls the
nearest scrollable ancestor with `scrollWheel`.

Clicking an arrow button calls `scrollArrow_onClick`, which scrolls by
`ScrollBarArrowStep` in that direction.

Clicking the track calls `track_onClick`, which page-scrolls by one viewport
size (`this.h` or `this.w`) toward the cursor.

Dragging the slider works through the normal drag-and-drop system. When the
mouse button is pressed on the slider, `pgui.mouseSource` is set to the slider.
`default_onDragStart` saves the begin state (here the begin scroll offset) into
`origX1` / `origY1` and sets `dragSaved = true`. On every mouse motion the drag
source receives `onDragOver`; `slider_onDragOver` maps the cursor position
inside the track to a scroll offset, clamps it, and calls `scrollTo`. The slider
therefore stays inside its track by construction.

If the user presses Escape while dragging, `onDragCancel` is called.
`default_onDragCancel` restores the begin position; the slider's own handler
restores the begin scroll offset, so a cancelled drag returns the content to
where it started.

Hit-testing is scroll-aware. `getElementAtCoord` adds the accumulated ancestor
scroll offsets to the coordinates before comparing them with an element's
bounds. For a scrollable container it first asks the scrollbar overlay with
`hitTest`, so the arrows, the slider and the track are the topmost, clickable
surfaces; only then the scrolled content is considered.

---

## How element dimensions are calculated

Every element has a box of four absolute coordinates, `x1`, `y1`, `x2`, `y2`,
and a size, `w` and `h`. These are produced by a layout procedure and are not
stored per layer; the layout recalculates them on every `recalcDOM`.

The layout is recursive. `recalcDOM` starts at the root element. For each layer
it calls the layer's `recalc` procedure, for example:

```nim
proc recalcFlex*(this: DivRef, layer: Layer): tuple[w,h:int]
```

A layout procedure only looks at the children of one layer of one element. It
reads the parent's `w` and `h` (plus padding, spacing, `flexDirection`,
`alignItems`, `justifyContent` and so on from `this.style`), decides each child's
size from the child's `w_unit` / `w_value` / `h_unit` / `h_value`
(`muAuto`, `muStretch`, `muPx`, `muPc`), and then places the child by writing
its `x1`, `y1`, `x2`, `y2`. At the end it returns the content size:

```nim
result.w = totalW
result.h = totalH
```

`recalcDOM` stores that return value on the layer:

```nim
(layer.w, layer.h) = layer.recalc(rootElem, layer)
```

`layer.w` and `layer.h` are the content size of that layer, which for a
scrollable container is its `innerW` and `innerH`. They can be larger than the
container's own `w` and `h`, and that difference is exactly what the scroll
system turns into a scroll range.

After a layout procedure has finished a container, it recurses into each child's
layers, so the whole tree gets its coordinates computed bottom-up:

```nim
for elem in layer.elems:
  for elemLayer in elem.layers:
    if elemLayer.recalc != nil:
      (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)
```

For a scrollable container (`overFlow == ofScroll`), the layout runs twice inside
`recalcFlex` (only flex layouts scroll — `recalcV` / `recalcH` are intentionally
non-scrollable single-line layouts): once with the full space and once with
the scrollbar space reserved. The final content size is stored on the container
as `innerW` and `innerH`, and the two-pass also decides whether `vScroll` /
`hScroll` are needed, which `recalcScrollbar` reads when it positions the
overlay.

---

## Reference

### Types

`DivRef` / `DivObj` (`src/piigui/types.nim`)

Scroll-related fields:

- `scrollable: bool` — derived runtime flag; `true` while a scrollbar is shown
  (set by `recalcScrollbars` after each `recalcDOM`).
- `scrollX`, `scrollY: int` — current scroll offsets.
- `innerW`, `innerH: int` — content size, set by the layout procedure.
- `scrollbar: ScrollBar` — the overlay object (see below), built lazily when the
  content overflows.
- `origX1`, `origY1: int` — begin position saved at drag start.
- `dragSaved: bool` — whether the begin state has been saved this drag.
- `onDragCancel: proc(this: DivRef)` — called when Escape cancels a drag.

`StyleSheetRef` / `StyleSheetObj` (`src/piigui/types.nim`)

- `overFlow: OverFlowKind` — the scrolling policy. Default is `ofScroll` (scroll
  x and y when content overflows). Set it to `ofHidden` to disable the scrollbar
  and clip the overflowing parts. Cascades like every other style property;
  `ofScroll` is the default so only `ofHidden` propagates through the `<-`
  operator.

`OverFlowKind` (`src/piigui/types.nim`)

```nim
OverFlowKind* = enum
  ofScroll, # default: scroll x and y when content overflows
  ofHidden  # scrollbar disabled, clip away extra parts
  #ofX #notimplemented
  #ofY #notimplemented
```

`ScrollBar` (`src/piigui/types.nim`)

A standalone overlay object, not a child in any layer:

- `parent: DivRef` — the scrollable container.
- `pgui: Pgui`, `window: PgWindow` — context access.
- `vUp`, `vDown`, `vTrack`, `vSlider` — vertical arrow, track, slider parts.
- `hLeft`, `hRight`, `hTrack`, `hSlider` — horizontal parts.
- `vScroll`, `hScroll: bool` — derived by `recalcScrollbar`.
- `beginScrollX`, `beginScrollY: int` — begin scroll for Escape-cancel.

`Pgui`

- `mouseX`, `mouseY: int` — last cursor position, used by the slider drag.

Constants (`src/piigui/types.nim`)

- `ScrollBarSize` — thickness of the track and arrows in pixels.
- `ScrollBarArrowSize` — arrow button size.
- `ScrollBarMinSlider` — minimum slider length.
- `ScrollBarWheelStep` — pixels per mouse-wheel notch.
- `ScrollBarArrowStep` — pixels per arrow click.

### Procedures

Scroll API (`src/piigui/ui/scrollbar.nim`)

- `scrollTo(this: DivRef, x, y: int)` — set the scroll offsets, clamped, and
  reposition the overlay.
- `scrollBy(this: DivRef, dx, dy: int)` — add a delta, then `scrollTo`.
- `scrollWheel(this: DivRef, dx, dy: int)` — wheel entry point; moves by
  `ScrollBarWheelStep` (negated on `y`, because wheel-up scrolls toward the top).
- `recalcScrollbar(sb: ScrollBar)` — derive `vScroll` / `hScroll` and position
  all parts.
- `recalcScrollbars(rootElem: DivRef)` — walk the tree; auto-activate scrolling
  where `overFlow == ofScroll` and the content overflows (lazily builds the
  overlay, sets `scrollable`, positions it). Called at the end of `recalcDOM`.
- `drawScrollBar(sb: ScrollBar, scrollX, scrollY: int)` — draw the visible parts
  at the owner's accumulated offset; called by `drawDOM`.
- `hitTest(sb: ScrollBar, x, y: int): DivRef` — topmost part under the point;
  called by `getElementAtCoord`.

Internal helpers

- `newScrollBarPart(parent, name, typeName, styleName)` — build one overlay
  part; applies `styleName` only if it exists in `defaultSST`, else `rootStyle`.
- `ancestorScroll(elem)` / `ownerOffset(elem)` / `scrollOwner(elem)` —
  compute the on-screen shift of the overlay (owner's ancestors only).
- `setParentClip(this)` — clip a part to its parent's visible rectangle.
- `clampInt(v, lo, hi)` / `clampFloat(v, lo, hi)` / `setRect(...)` — helpers.

Event handlers

- `scrollArrow_onMouseButtonDown` / `scrollArrow_onMouseButtonUp` —
  `focus` (clicked) / `hover` pseudo-states on the arrows.
- `scrollArrow_onClick` — scroll by `ScrollBarArrowStep`.
- `track_onClick` — page-scroll one viewport toward the cursor.
- `slider_onDragStart` — save begin scroll, switch to `focus`.
- `slider_onDragOver` — map the cursor to a clamped scroll offset.
- `slider_onDragEnd` — drop, restore `default` style.
- `slider_onDragCancel` — Escape: restore the begin scroll.
- `scrollPart_onHover` — `hover` pseudo-state for parts that define it.

Layout (`src/piigui/layout/flex.nim`, `src/piigui/layout/recalcH.nim`,
`src/piigui/layout/recalcV.nim`)

- `recalcFlex(this: DivRef, layer: Layer): tuple[w,h:int]` — flex layout; used
  by `flex`, `flexRow`, `flexColumn` etc.
- `recalcH` / `recalcV` — horizontal / vertical box layout, used by `row` /
  `column`. These are intentionally **single-line and not scrollable**; use
  `flexRow` / `flexColumn` when scrolling is needed.
- Only `recalcFlex` sets `this.innerW` / `this.innerH` and does the two-pass
  scrollbar space reservation when `this.style.overFlow == ofScroll`
  (`ofHidden` containers use a single pass).

Core (`src/piigui.nim`)

- `recalcDOM(rootElem: DivRef)` — run the layout and then
  `recalcScrollbars(rootElem)`.
- `scrollOffset(this: DivRef): tuple[x,y:int]` — sum of the scroll offsets of
  all scrollable ancestors; used to seed the first `drawDOM` call.
- `drawDivRef(this: DivRef, scrollX, scrollY: int)` — draws a plain element;
  shifts its destination rectangle by the passed scroll offset and clips to the
  parent's on-screen rectangle.
- `drawDOM(pgui, r)` — draws the tree from `r`. It seeds the offset with
  `scrollOffset(r)` (so any subtree can be drawn), then `drawDOMImpl` carries
  the accumulated scroll offsets down to every element and draws the scrollbar
  overlay of a scrollable element on top.
- `getElementAtCoord(root, x, y)` — scroll-aware hit-testing; tests the
  scrollbar overlay first.
- `default_onDragStart` — saves the begin state (`origX1` / `origY1`,
  `dragSaved = true`) when it was not saved yet.
- `default_onDragEnd` — clears `dragSaved`, restores the default style.
- `default_onDragCancel` — Escape: restores the begin position, clears
  `dragSaved`.

Events (`src/piigui/hidevents.nim`)

- `hid_events(pgui)` — the main event loop. Handles:
  - `MouseMotion` — updates `pgui.mouseX` / `pgui.mouseY`; during a drag it
    fires `onDragStart` once on the source (begin state saved), then
    `onDragOver` on the source and on the hovered target.
  - `KeyDown` with Escape — cancels the drag via `onDragCancel`; otherwise
    Escape quits.
  - `MouseWheel` — triggers `wheelup` / `wheeldown` / `wheelleft` / `wheelright`
    on the hovered element; if nothing handled it, scrolls the nearest
    scrollable ancestor.
