# How a DosBtn is drawn (for dummies)

This is a plain-language walkthrough of `src/piigui/ui/dosbtn.nim`'s `draw`
procedure. It covers the four ideas that trip people up: **rendering**,
**clipping**, **caching** and the **two coordinate spaces**.

No prior knowledge of SDL2 is assumed.

---

## 1. What a DosBtn is

A `DosBtn` is a retro "DOS" style button. Visually it is a rectangle with:

- a **face** (the button background color),
- a **shadow** (a dark strip on the right and bottom edges),
- a **text label** in the middle.

It has two states:

| state | meaning | look |
|---|---|---|
| `0` | not pressed | face at top-left, shadow on the right/bottom |
| `1` | pressed | face shifted right/down onto the shadow (button "sinks") |

The shadow size is `shadowSizePx`, computed once as
`min(min(w, h) div 5, 12)`.

---

## 2. The big picture: paint on a private canvas, then stick it on the window

Every piigui element draws itself in two steps:

1. **Paint onto a private texture** (`textureCache`), an off-screen canvas that
   is exactly `w × h` pixels.
2. **Copy (blit) that texture onto the window** at the element's on-screen
   position.

In SDL terms:

- `sdl.setRenderTarget(renderer, textureCache)` — "now draw on this texture".
- ... draw shadow, face, text ...
- `sdl.setRenderTarget(renderer, nil)` — "back to drawing on the window".
- `renderer.copy(textureCache, nil, screenRect)` — "blit the texture to the
  window at `screenRect`".

Why the extra canvas? Because re-drawing the button is expensive (font
rendering, etc.), so the result is cached in `textureCache` and only re-created
when something changed. Copying a texture every frame is cheap.

---

## 3. The two rectangles

`draw` computes two rectangles:

- **`canvasRect`** = `(0, 0, w, h)` — the texture-local area. This is where the
  shadow, face and text are painted *inside the texture*.
- **`screenRect`** = `(x1 - scrollX, y1 - scrollY, w, h)` — where on the
  **window** the texture will be placed. `scrollX`/`scrollY` are the accumulated
  scroll of the button's scrollable ancestors, so a scrolled container moves
  the button correctly.

The text is also centered inside `canvasRect`.

---

## 4. Clipping and the two coordinate spaces (the tricky part)

When a button is inside a scrollable container, it must not be drawn outside the
container's visible area. That is done with an SDL **clip rect**: SDL silently
drops any pixel of a `copy` that falls outside the clip rect.

The clip rect for the button is:

```
clipRect = visibleClipRect(this, scrollX, scrollY)
```

That rectangle is in **screen coordinates** (it uses `x1`/`y1`/`w`/`h`, the
on-screen boxes of the button's ancestors). It describes *where on the window*
the button may appear.

But the button is painted into its **texture**, which uses its **own**
coordinates starting at `(0, 0)`.

SDL has one clip rect for the whole renderer, and it is always interpreted in
the *current render target's* coordinate space. So:

- While the render target is the texture, a screen-space clip rect (e.g.
  `y = 68`) would mean "in the texture, only pixels below `y = 68` may be
  drawn" — which cuts off the top of the button.
- The clip is only correct while the render target is the window (screen
  space), right around the `copy`.

Therefore the order matters:

```
1. compute clipRect                         (screen coords, just a number)
2. setRenderTarget(textureCache)            (texture coords now)
3. clear + paint shadow, face, text         (NO clip applied — full texture)
4. setRenderTarget(nil)                     (back to screen coords)
5. setClipRect(renderer, clipRect)          (apply the screen clip)
6. copy(textureCache, nil, screenRect)      (clipped correctly)
7. setClipRect(renderer, nil)               (reset)
```

> Rule of thumb: **the clip rect is for the window, not for the canvas.** Apply
> it only around the final `copy`, never while filling `textureCache`.

---

## 5. Caching: `redrawFlag` and `textureCache`

- `redrawFlag` — "this element changed, please re-paint". Set to `1` by events
  (hover, press, `setText`, a layout change, ...).
- `textureCache` — the cached canvas.

`draw` branches on `redrawFlag`:

- **`redrawFlag == 0` and a cache exists** → nothing changed: just `copy` the
  existing texture to the window (fast path, step 6 above).
- **otherwise** → re-paint the texture from scratch, then `copy` it.

At the end of `draw`, `redrawFlag` is reset to `0` (the cache is now up to
date).

The texture is created lazily (`if textureCache == nil`) with the element's
current `w` and `h`, and blend mode `BLENDMODE_BLEND` so the transparent parts
(around the face, and around the shadow) stay transparent.

> Note for future work: the cache is currently created once and not re-sized
> when `w`/`h` later change (e.g. window scaling or a re-layout). That is a
> known, separate topic; for now the texture size must match `w`/`h` at
> creation time.

---

## 6. Paint order inside the texture

When re-painting (state `0`, not pressed):

1. **Clear** the texture with the transparent clear color.
2. **Shadow** — fill a rectangle offset by `shadowSizePx` to the right and
   bottom, in a dark translucent color.
3. **Face** — fill the top-left rectangle (up to `w - shadowSizePx`,
   `h - shadowSizePx`) with the button background color. This covers the
   top-left part of the shadow, leaving the classic bottom/right shadow edge.
4. **Text** — render the label, centered, in a color that contrasts with the
   background (`buttonTextColor`), and copy it onto the face.

In the pressed state (`1`) the face is drawn at the `shadowSizePx` offset
instead, so the button looks pushed in.

---

## 7. Quick reference

| symbol | coordinate space | meaning |
|---|---|---|
| `canvasRect` | texture-local `(0,0,w,h)` | area painted inside `textureCache` |
| `screenRect` | screen `(x1-scrollX, y1-scrollY, w, h)` | where the texture is copied on the window |
| `clipRect` | screen | allowed on-screen area (ancestor intersection) |
| `textureCache` | texture | cached painting, re-used until `redrawFlag` |
| `redrawFlag` | — | `1` = re-paint, `0` = reuse cache |

The three steps to remember:

1. Paint on the texture (unclipped).
2. Clip in screen space.
3. Copy the texture to the window.
