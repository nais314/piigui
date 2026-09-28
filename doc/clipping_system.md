# PiiGUI Clipping System

How PiiGUI decides which pixels of a UI element are allowed on screen.
This covers the drawing side only; scrolling itself is in `scroll_system.md`
and the input-side twin is in `element_clipping.md`.

Every element is always clipped to the intersection of **all** of its
ancestors' on-screen rects, regardless of `overFlow`. `overFlow` only controls
whether a scrollbar exists so clipped-away content can be scrolled back in.

---

## 1. Overview

Clipping is recalculated on every frame, at draw time:

1. `drawWindows` (`src/piigui.nim`) calls `drawDOM` for each dirty window.
2. `drawDOM` seeds the accumulated scroll and the root clip once, then calls
   `drawDOMImpl`.
3. `drawDOMImpl` walks the tree top-down, writing each element's visible rect
   into `DivObj.clipRect` and passing an already-intersected `ancestorClip` to
   its children. Clipping the children is an O(1) intersection — no upward walk
   per element.
4. Each element's `draw` proc renders into its own off-screen texture
   (`textureCache`) unclipped, then applies SDL's render clip rect from
   `this.clipRect` only around the final on-screen copy.
5. A `ScrollBar` overlay is drawn last, on top of the content.

An element is therefore only visible inside its parent, its parent inside the
grandparent, and so on up to the root.

---

## 2. Variables, Data Structures, Procedures

- `scrollX`, `scrollY: int` — params of `drawDOMImpl` / `draw`
  (`src/piigui.nim`). Accumulated scroll of the element's **scrollable
  ancestors** (not its own). An element's on-screen left is `x1 - scrollX`.

- `ancestorClip: sdl.Rect` — param of `drawDOMImpl` (`src/piigui.nim:877`).
  Intersection of every ancestor's on-screen rect. The clip for `this` itself,
  in screen coordinates.

- `childClip: sdl.Rect` — local in `drawDOMImpl` (`src/piigui.nim:893`).
  `ancestorClip` further intersected with `this`'s own on-screen rect; passed to
  children.

- `clipRect: sdl.Rect` — field `DivObj` (`src/piigui/types.nim:222`).
  Per-element cache of the current frame's clip, assigned by `drawDOMImpl`
  before `draw` runs. Exported; other systems read it.

- `scrollable: bool` — field `DivObj` (`src/piigui/types.nim:201`). True when
  content overflows and the element scrolls. Set by `recalcScrollbars`.

- `scrollX`, `scrollY: int` — fields `DivObj` (`src/piigui/types.nim:202`).
  Current scroll offset of this element. Added to the child offset only, never
  to the element's own position.

- `drawDOMImpl` (`src/piigui.nim:877`) — recursive top-down propagator. Sets
  `clipRect`, calls `draw`, computes `childClip`, recurses, then draws the
  scrollbar.

- `drawDOM` (`src/piigui.nim:910`) — public entry for a tree/subtree. Seeds
  everything by calling `scrollOffset` and `visibleClipRect` once.

- `visibleClipRect` (`src/piigui.nim:288`) — O(depth) upward walk returning the
  intersection of all ancestors' on-screen rects. Used only to seed the root.

- `scrollOffset` (`src/piigui.nim:276`) — sums `scrollX`/`scrollY` of all
  scrollable ancestors; seeds the offset for a subtree draw.

- `drawDivRef` (`src/piigui.nim:357`) — draws plain `Div`/`row`/`column`.
  Applies `this.clipRect` around the on-screen copy only.

- Widget `draw` procs (`src/piigui/ui/*.nim`) — `label`, `dosbtn`, `gradbtn`,
  `atogglebtn`, `monotextbox` do the same clip dance; most early-return when
  `clipRect.w == 0 or clipRect.h == 0`.

- `setParentClip` (`src/piigui/ui/scrollbar.nim:88`) — sets the render clip to a
  scrollbar part's parent (owner) on-screen rect.

- `drawScrollBar` (`src/piigui/ui/scrollbar.nim:304`) — draws the overlay parts
  on top of the owner's content.

- `getElementAtCoord` (`src/piigui.nim:1000`) — input-side mirror. A point only
  hits an element inside every ancestor rect, with the same scroll accumulation.

---

## 3. How Clipping Is Calculated

### Seeding (`drawDOM`)

```nim
let off = scrollOffset(this)                        # ancestors' scroll
let rootClip = visibleClipRect(this, off.x, off.y)  # O(depth), once
drawDOMImpl(pgui, this, off.x, off.y, rootClip)
```

`visibleClipRect` starts from the parent's rect and intersects every ancestor
up to the root. While walking up it subtracts each scrollable ancestor's own
scroll (`accX -= ancestor.scrollX`) because scrolling a container shifts its
content left/up: `screenX = docX - scroll`. An ancestor's own scroll must not
move the ancestor's own rect, only its children.

If the intersection is empty it returns a zero-size rect and nothing is drawn.

### Propagation (`drawDOMImpl`)

```nim
this.clipRect = ancestorClip          # this element's visible area
if this.draw != nil: this.draw(this, scrollX, scrollY)

# children are clipped to this element's on-screen rect too
let thisScreenX = (this.x1 - scrollX).cint
let thisScreenY = (this.y1 - scrollY).cint
let childLeft   = max(ancestorClip.x, thisScreenX)
let childTop    = max(ancestorClip.y, thisScreenY)
let childRight  = min(ancestorClip.x + ancestorClip.w, thisScreenX + this.w.cint)
let childBottom = min(ancestorClip.y + ancestorClip.h, thisScreenY + this.h.cint)
var childClip = sdl.Rect(
  x: childLeft, y: childTop,
  w: max(0.cint, childRight - childLeft),
  h: max(0.cint, childBottom - childTop))

let nX = scrollX + (if this.scrollable: this.scrollX else: 0)
let nY = scrollY + (if this.scrollable: this.scrollY else: 0)
for layer in this.layers:
  for elem in layer.elems:
    drawDOMImpl(pgui, elem, nX, nY, childClip)
```

Key points:

- `clipRect` is the clip for `this`; children additionally intersect with
  `this`'s on-screen rect, so grandchildren are clipped by the grandparent too.
- Only children receive this element's own scroll (`nX`, `nY`). The element's
  own on-screen position uses the incoming `scrollX`, never its own.
- Because `clipRect` is overwritten every frame, it must be assigned before
  `draw` runs. A subtree that is not redrawn (window not dirty) keeps a stale
  `clipRect`.

### Rendering (inside each `draw`)

The element is drawn into `textureCache` at `(0,0,w,h)` — texture-local
coordinates, **no clip**. Then the render target is reset to the window, the
clip is set from `this.clipRect`, the texture is copied to
`(x1 - scrollX, y1 - scrollY, w, h)`, and the clip is reset to `nil`.

### Scrollbar overlay

After the children, `drawDOMImpl` calls `drawScrollBar(this.scrollbar, scrollX,
scrollY)` — note the owner's own scroll is intentionally **not** applied: the
overlay lives in the owner's frame. `scrollbar.nim` clips each part to the
owner's on-screen rect via `setParentClip` and clears the clip afterwards.

### Hit-testing must agree

`getElementAtCoord` returns `nil` as soon as the cursor is outside an element's
rect (`x1..x2`, `y1..y2`), then recurses with the parent's scroll added
(`ex = x + accX`). This is the same rule as drawing, so clipped-away content is
not clickable.

---

## 4. Source-Code Reference

| Topic | Location |
|---|---|
| Clipping overview comment | `src/piigui.nim:288-297` |
| `scrollOffset` | `src/piigui.nim:276` |
| `visibleClipRect` (root case / loop / return) | `src/piigui.nim:298`, `316`, `338`, `341` |
| `drawDivRef` clip application | `src/piigui.nim:376`, `401`, `482` |
| `drawDOMImpl` (assign clip / childClip / recurse / scrollbar) | `src/piigui.nim:882`, `887-897`, `900-904`, `907-908` |
| `drawDOM` seed | `src/piigui.nim:915-917` |
| `drawWindows` | `src/piigui.nim:919` |
| `clipRect` field | `src/piigui/types.nim:222` |
| `scrollable`, `scrollX/Y` fields | `src/piigui/types.nim:201-202` |
| Widget `clipRect` use | `src/piigui/ui/label.nim:151`, `dosbtn.nim:142`, `gradbtn.nim:138`, `atogglebtn.nim:136`, `monotextbox.nim:319` |
| `setParentClip` / `drawScrollBar` | `src/piigui/ui/scrollbar.nim:88`, `304` |
| Hit-test mirror | `src/piigui.nim:1000` |

---

## 5. Pitfalls

- **Two coordinate spaces.** `clipRect` is in **screen** coordinates; the
  texture/background fill is at `(0,0,w,h)`. SDL interprets the clip in the
  current render target's space, so the clip must be applied only after
  `setRenderTarget(renderer, nil)`, around the on-screen copy. Applying it
  while the texture is the target cuts the element's top/left.
- **Off-by-one between seed and children.** `visibleClipRect` returns an
  inclusive width `maxX - minX + 1` (`src/piigui.nim:342`), while `drawDOMImpl`
  computes `childClip.w = childRight - childLeft` (`:896`). The initial
  `clipRect` can be one pixel wider/taller than what descendants receive.
- **Scrollbar overlay clip is local.** `setParentClip`
  (`scrollbar.nim:88-103`) clips only to the owner's rect; it is **not**
  intersected with the owner's `clipRect`/`ancestorClip`. If the owner is
  clipped by an ancestor, a scrollbar part may paint into the clipped-away
  region.
- **Clip is not permanent.** Every `draw` resets the SDL clip to `nil`
  (`src/piigui.nim:489`). Code that sets a clip must clear it before returning.
- **Scroll changes need a redraw.** `clipRect` and `childClip` are derived from
  `x1/y1/w/h` and the scroll fields at draw time. Changing `scrollX`/`scrollY`
  without flagging the window/element dirty leaves the old visibility.
- **Empty clip.** Widget draw procs early-return on `w == 0 or h == 0`; plain
  `drawDivRef` does not, but SDL clips the empty copy to nothing. Do not rely
  on a zero-size `clipRect` alone to skip work in custom widgets.
