# SDL3 Migration Guide & Conceptual Reference for PiiGUI

This document explains the differences between SDL2 and SDL3, the architectural changes introduced in SDL3, and how PiiGUI is redesigned to take full advantage of SDL3's modern GPU-accelerated rendering, subpixel geometry (`FRect`), and updated event model.
(made with Gemini 3.8)

---

## 1. Architectural Evolution: Why SDL3?

SDL3 represents a major redesign of the Simple DirectMedia Layer, modernizing APIs that had accumulated decades of legacy compatibility in SDL2:

1. **Subpixel & High-DPI First**:
   - In SDL2, rendering coordinates on `SDL_Renderer` were primarily integers (`SDL_Rect`), with experimental/limited float variants (`SDL_FRect` added late in SDL2).
   - In SDL3, all 2D renderer operations operate natively in floating-point (`SDL_FRect`, `SDL_FPoint`). This eliminates rounding errors, jitter during smooth animations, and awkward fractional scaling across High-DPI screens.
2. **Simplified Initialization & Defaults**:
   - Hardware acceleration and VSync are standard in modern systems. SDL3 removes outdated renderer flags (`SDL_RENDERER_ACCELERATED`, `SDL_RENDERER_TARGETTEXTURE`) and makes optimal choices automatically.
3. **Cleaner Resource & Stream Model**:
   - `SDL_RWops` is replaced by the cleaner, 64-bit-ready `SDL_IOStream` API (`SDL_IOFromConstMem`, `SDL_IOFromFile`).
4. **Direct, Type-Safe Event Unions**:
   - The event structure is an explicit union where fields (`e.motion`, `e.button`, `e.key`, `e.window`) can be accessed directly without cast helpers. Window events are now top-level event IDs rather than nested sub-events.
5. **Window-Scoped Text Input**:
   - Text input (`SDL_StartTextInput`, `SDL_StopTextInput`) is explicitly associated with a window handle, fixing focus ambiguities in multi-window applications.

---

## 2. Rosetta Stone: SDL2 vs. SDL3 API Comparison

| Feature / Domain | SDL2 | SDL3 | Notes in PiiGUI |
| :--- | :--- | :--- | :--- |
| **Window Type** | `WindowPtr` (`ptr Window`) | `Window` (`ptr WindowObj`) | PiiGUI aliases `WindowPtr = Window` |
| **Renderer Type** | `RendererPtr` (`ptr Renderer`) | `Renderer` (`ptr RendererObj`) | PiiGUI aliases `RendererPtr = Renderer` |
| **Texture Type** | `TexturePtr` (`ptr Texture`) | `Texture` (`ptr TextureObj`) | PiiGUI aliases `TexturePtr = Texture` |
| **Surface Type** | `SurfacePtr` (`ptr Surface`) | `ptr Surface` | PiiGUI aliases `SurfacePtr = ptr Surface` |
| **Font Type** | `FontPtr` (`ptr Font`) | `Font` (`ptr object`) | PiiGUI aliases `FontPtr = Font` |
| **Window Creation** | `createWindow(title, x, y, w, h, flags)` | `createWindow(title, w, h, flags)` | Window position is set via `setWindowPosition` if specified |
| **Renderer Creation** | `createRenderer(win, index, flags)` | `createRenderer(win, name)` | SDL3 renderers default to accelerated/target-capable |
| **Return Status** | `0` = success, `< 0` = error | `bool` (`true` = success, `false` = error) | Cleaner Nim `if not proc():` idiomatic checks |
| **Memory Buffer Streams** | `rwFromConstMem(ptr, len)` (`SDL_RWops`) | `ioFromConstMem(ptr, size)` (`SDL_IOStream`) | Used for embedded fonts in `simple.nim` |
| **Open Font from Memory** | `openFontRW(rw, freesrc, ptsize)` | `openFontIO(io, closeio, ptsize)` | `ptsize` is `cfloat` in SDL3_ttf |
| **Renderer Draw Color** | `setDrawColor(renderer, r, g, b, a)` | `setRenderDrawColor(renderer, r, g, b, a)` | Supports `uint8` or float `setRenderDrawColorFloat` |
| **Clear Render Target** | `clear(renderer)` | `renderClear(renderer)` | |
| **Filled Rectangle** | `fillRect(renderer, addr Rect)` | `renderFillRect(renderer, addr FRect)` | Uses floating-point `FRect` |
| **Outline Rectangle** | `drawRect(renderer, addr Rect)` | `renderRect(renderer, addr FRect)` | Uses floating-point `FRect` |
| **Texture Copy / Blit** | `copy(renderer, tex, srcrect, dstrect)` | `renderTexture(renderer, tex, srcrect, dstrect)` | `srcrect` and `dstrect` are `ptr FRect` |
| **Scissor / Clip Rect** | `setClipRect(renderer, addr Rect)` | `setRenderClipRect(renderer, addr Rect)` | **Remains integer `Rect`** (scissor buffer is physical pixels) |
| **Free Surface** | `freeSurface(surface)` | `destroySurface(surface)` | Unified naming with `destroyTexture` / `destroyWindow` |
| **Display Scale / DPI** | Manual `getDisplayDPI` math | `getDisplayContentScale(displayID)` | Direct scale factor (e.g. `1.0`, `1.25`, `2.0`) |
| **Event Poll** | `pollEvent(e)` | `pollEvent(e)` | Returns `bool` |
| **Event Type Field** | `e.kind` (enum `EventType`) | `e.`type`` (enum `EventType`) | |
| **Mouse Coordinates** | `e.motion.x: cint` | `e.motion.x: cfloat` | SDL3 events report subpixel float coordinates |
| **Keyboard Event Key** | `eventObj.keysym.sym` | `e.key.key` (`Keycode`) | Flat struct, no `keysym` nesting |
| **Escape Key Constant** | `sdl.K_Escape` | `sdl.SDLK_ESCAPE` | |
| **Window Resize Event** | Sub-event of `WINDOWEVENT` | Top-level `EVENT_WINDOW_RESIZED` | `e.window.data1` = width, `e.window.data2` = height |
| **Text Input State** | `isTextInputActive()` | `textInputActive(win)` | Takes window parameter |
| **Text Input Toggle** | `startTextInput()`, `stopTextInput()` | `startTextInput(win)`, `stopTextInput(win)` | Window-scoped |
| **Ticks Count** | `getTicks(): uint32` (wraps in 49 days) | `getTicks(): uint64` (never wraps) | 64-bit millisecond counter |

---

## 3. Deep Dive: Rendering Coordinates (`Rect` vs `FRect`)

One of the most important concepts to understand when migrating to SDL3 is the distinction between **Hardware Scissor Clipping** and **Hardware Drawing**:

### A. Scissor Clipping operates in Framebuffer Pixels (`sdl.Rect`)
The GPU scissor test restricts rasterization to a specific rectangular bounding box of physical pixels on the render target (window or texture).
* Function: `setRenderClipRect(renderer: Renderer, rect: ptr Rect): bool`
* In PiiGUI, `visibleClipRect(this, scrollX, scrollY)` computes the intersection of all ancestor boxes on the screen in physical pixels (`cint`). It continues to return `sdl.Rect`.

### B. Drawing & Blitting operates in Subpixel Floating-Point (`sdl.FRect`)
Vertices, primitives, and textures are rasterized through floating-point pipeline coordinates:
* `renderFillRect(renderer: Renderer, rect: ptr FRect): bool`
* `renderRect(renderer: Renderer, rect: ptr FRect): bool`
* `renderTexture(renderer: Renderer, texture: Texture, srcrect, dstrect: ptr FRect): bool`

### C. How PiiGUI Widgets Construct `FRect`
Each widget converts its local integer bounds into `FRect` values when submitting draw calls to the renderer:

```nim
# Canvas destination (local inside target texture cache)
var canvasFRect = FRect(
  x: 0.0,
  y: 0.0,
  w: this.w.cfloat,
  h: this.h.cfloat
)

# Screen destination (on-screen display shifted by scroll)
var screenFRect = FRect(
  x: (this.x1 - scrollXArg).cfloat,
  y: (this.y1 - scrollYArg).cfloat,
  w: this.w.cfloat,
  h: this.h.cfloat
)

# Blit texture cache to screen
discard this.window.renderer.renderTexture(
  this.textureCache,
  nil,
  addr screenFRect
)
```

---

## 4. Deep Dive: Events & Input System

In SDL2, `sdl.Event` was often wrapped using custom procedures like `evMouseMotion(e)` or `cast[ptr sdl.KeyboardEventObj](addr e)`.

In SDL3, `Event` is defined as a tagged union with explicit sub-structs:

```nim
# In SDL3:
case e.`type`:
  of EVENT_QUIT:
    return true

  of EVENT_KEY_DOWN:
    if e.key.key == SDLK_ESCAPE:
      handleEscape()

  of EVENT_MOUSE_MOTION:
    # Mouse coordinates are cfloat:
    pgui.mouseX = e.motion.x.cint
    pgui.mouseY = e.motion.y.cint

  of EVENT_MOUSE_BUTTON_DOWN:
    let x = e.button.x.cint
    let y = e.button.y.cint

  of EVENT_WINDOW_RESIZED:
    let newWidth = e.window.data1
    let newHeight = e.window.data2
```

---

## 5. Pruning Dead Dependencies: `image` and `gfx`

PiiGUI historically included `import sdl2/image as img` and `import sdl2/gfx` across almost all modules:
1. **`sdl2/image`**: Only `img.init` and `img.quit` were called in `simple.nim`. PiiGUI embeds its monochrome and bold fonts directly as TTF memory bytes via `simple.nim` and does not load PNG/JPEG assets. Dropping `image` eliminates an external shared library dependency without losing any features.
2. **`sdl2/gfx`**: Never had any active procedures called. All button borders, shadows, backgrounds, and scrollbars are drawn using renderer primitives (`renderFillRect`, `renderRect`, `renderTexture`). Dropping `gfx` cleans up compilation and eliminates obsolete bindings.

---

## 6. Type Aliases in `piigui/types.nim`

To preserve PiiGUI's clear pointer naming convention, `piigui/types.nim` defines:

```nim
type
  WindowPtr*   = sdl.Window
  RendererPtr* = sdl.Renderer
  TexturePtr*  = sdl.Texture
  SurfacePtr*  = ptr sdl.Surface
  FontPtr*     = ttf.Font
```

This guarantees that external PiiGUI consumers, callbacks, and internal structures maintain clean, readable names while compiling directly against native SDL3 types.
