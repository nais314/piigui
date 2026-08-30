# Element clipping in piigui

An overview of how piigui decides what is visible on screen and what is not.
It describes clipping (the drawing side) and hit-testing (the input side),
which must agree with each other.

Clipping has nothing to do with `overFlow` being `ofScroll` or `ofHidden`:
every element is always clipped to the visible area of **all** of its
ancestors. `overFlow` only decides whether a scrollbar appears (and therefore
whether the clipped-away content can be scrolled into view). Scrolling itself
is described in `scroll_system.md`.

---

## The idea

Every element is drawn into its own off-screen texture (`textureCache`) and is
then copied onto the window at its on-screen position. Before that copy, an SDL
clip rect is set. SDL drops every pixel of the copy that falls outside the clip
rect, so an element is only visible inside its allowed area.

That allowed area is the intersection of the on-screen rects of every ancestor:
a child can never be visible outside its parent, the parent can never be
visible outside the grandparent, and so on up to the root. This is what makes a
deeply nested container (for example `table1 -> row -> button`) clip its
grandchildren too, and not just its direct children.

---

## The drawing pipeline

The whole tree is redrawn on every frame.

```
gui.drawDom(gui.rootElem)
   |
   +-- scrollOffset(rootElem)      accumulated scroll of root's ancestors (0 for root)
   |
   +-- drawDOMImpl(pgui, rootElem, off.x, off.y)
         |
         +-- for element r (recursively):
         |     r.draw(r, scrollX, scrollY)         -> drawDivRef or a widget draw
         |         |
         |         +-- clipRect = visibleClipRect(r, scrollX, scrollY)
         |         +-- sdl.setClipRect(renderer, clipRect)
         |         +-- redraw textureCache if needed (fill bg, draw text)
         |         +-- copy texture to screenRect = (x1-scrollX, y1-scrollY, w, h)
         |         +-- sdl.setClipRect(renderer, nil)     # reset clip
         |
         +-- recurse into r's children with scroll + r.scrollX/Y if r.scrollable
         |
         +-- if r.scrollable and r.scrollbar != nil:
               drawScrollBar(r.scrollbar, scrollX, scrollY)   # overlay on top
```

The `scrollX`/`scrollY` passed to `draw` are the accumulated scroll offsets of
the element's *scrollable ancestors* (not the element's own scroll). When a
container is scrolled, all of its children receive a bigger `scrollX`, so their
`screenRect` shifts left/up and previously hidden content becomes visible.

The different elements use different draw procs, but they all share the same
clip logic through `visibleClipRect`:

| element | draw proc |
|---|---|
| plain `Div`, `row`, `column`, containers | `drawDivRef` (src/piigui.nim) |
| `DosBtn` | `draw` (src/piigui/ui/dosbtn.nim) |
| `GradBtn` | `draw` (src/piigui/ui/gradbtn.nim) |
| `Label` | `draw` (src/piigui/ui/label.nim) |
| `TextBox` | `draw` (src/piigui/ui/textbox.nim) |
| `AToggleBtn` | `draw` (src/piigui/ui/atogglebtn.nim) |

---

## How the clip rect is calculated (`visibleClipRect`)

`visibleClipRect(this, scrollX, scrollY)` in `src/piigui.nim`:

1. If `this` has no parent (the root), its clip is its own rect.
2. Otherwise it walks up from the parent to the root. For every ancestor it
   computes the ancestor's on-screen rect and intersects all of them into one
   rectangle.
3. If the intersection is empty (the element is completely outside every
   visible area), it returns a zero-size rect, and nothing is drawn.

An ancestor's on-screen rect is

```
ancestor.x1 - accX,  ancestor.y1 - accY
width = ancestor.w,  height = ancestor.h
```

where `accX/accY` is the accumulated scroll of *that ancestor's* ancestors.
This matters: an ancestor's own scroll shifts its children but not the ancestor
itself, so the ancestor's rect must not be moved by its own scroll.

---

## The variables at a glance

| variable | meaning |
|---|---|
| `scrollX`, `scrollY` | accumulated scroll offsets of an element's scrollable ancestors, passed down by `drawDOMImpl`. An element's on-screen position is `x1 - scrollX`. |
| `accX`, `accY` | working copies inside `visibleClipRect` while walking up: the accumulated ancestor scroll of the ancestor currently being intersected. Each step up subtracts that next ancestor's own scroll (if it is scrollable). |
| `clipRect` | the SDL clip rect (screen coordinates) an element may paint into. |
| `canvasRect`, `backgroundRect` | the element's own texture area `(0,0,w,h)` used to fill the background and draw contents, before the texture is copied to the screen. |
| `screenRect`, `thisRect` | destination rect on screen where the element's texture is copied: `(x1 - scrollX, y1 - scrollY, w, h)`. |
| `minX, minY, maxX, maxY` | the running bounds of the ancestor intersection inside `visibleClipRect` (`x2 = x1 + w - 1`). |

---

## DOM calculation (layout before drawing)

Before anything is drawn, the layout must be computed once:

```
gui.rootElem.recalcStyle(true)     # rebuild styleCache for the whole tree
gui.rootElem.recalcDOM()           # run the layout, position every element
```

`recalcDOM`:

1. For every layer it calls the layer's `recalc` proc — `recalcFlex`
   (`flexRow`/`flexColumn`), `recalcH` (`row`) or `recalcV` (`column`) — which
   sets `x1, y1, x2, y2, w, h` on every child and returns the content size as a
   `(w, h)` tuple. Scrollable containers also store `innerW`/`innerH` here.
2. Then it calls `recalcScrollbars(rootElem)`, which walks the whole tree:
   for every `overFlow == ofScroll` element whose content overflows
   (`innerW > w` or `innerH > h`) it lazily builds the `ScrollBar` overlay and
   sets `scrollable = true`; otherwise `scrollable = false`.

---

## How a mouse click finds its target

On a mouse button event, `hid_events` calls
`getElementAtCoord(rootElem, x, y)` (`src/piigui.nim`) to find the topmost
element under the cursor.

It searches from top to bottom (the last drawn elements are on top) and checks
the same rule the drawing uses: a point belongs to an element only if it is
inside **every** ancestor's rect. The click position is shifted by the same
accumulated scroll as drawing, so clipped-away content is not clickable —
drawing and hit-testing stay in sync.

The search, per element:

1. **Scrollbar overlay first.** If the element is scrollable and has a
   `scrollbar`, `scrollbar.hitTest(x, y)` is tried. It returns the topmost
   scrollbar part under the cursor (`vUp`, `vDown`, `vSlider`, `vTrack`,
   `hLeft`, `hRight`, `hSlider`, `hTrack`). The overlay sits on top of the
   content, so it wins over any content underneath.
2. **Children** are searched next, recursing with the element's own scroll
   added (children are shifted inside a scrolled container).
3. **The element itself** is returned if the point is inside its rect.

The root element is handled the same way: its own scrollbar overlay is checked
first, then its children.

So a click in the middle of a scrollbar slider moves the slider, a click on
content hits the button/label/textbox under the cursor, and a click on an area
that was clipped away hits nothing at all.
