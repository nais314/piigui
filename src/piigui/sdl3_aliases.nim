##[
  This library contains the wrapper functions
  to SDL3, which are not present in the official wrapper
]##

#[ 
when defined(emscripten):
  const LibName* = "libSDL3.so"
  proc emscripten_set_main_loop*(f: proc() {.cdecl.}, a: cint, b: bool) {.importc: "SDL_emscripten_set_main_loop".}
  proc emscripten_cancel_main_loop*()  {.importc: "SDL_emscripten_cancel_main_loop".}
elif defined(windows):
  const LibName* = "SDL3.dll"
elif defined(macosx):
  const LibName* = "libSDL3.dylib"
else:
  const LibName* = "libSDL3.so"
 ]#
import
  sdl3 as sdl,
  sdl3_ttf as ttf
#import piigui/[types]  

when defined(emscripten):
  {.push callConv: cdecl.}
else:
  {.push callConv: cdecl, dynlib: LibName.}


converter toColor*(t: tuple[r, g, b, a: uint8]): Color =
  Color(r: t.r, g: t.g, b: t.b, a: t.a)

converter toColorInt*(t: tuple[r, g, b, a: int]): Color =
  result.r = uint8(t.r)
  result.g = uint8(t.g)
  result.b = uint8(t.b)
  result.a = uint8(t.a)

proc color*(r, g, b, a: uint8): Color =
  Color(r: r, g: g, b: b, a: a)

proc color*(r, g, b, a: int): Color =
  result.r = uint8(r)
  result.g = uint8(g)
  result.b = uint8(b)
  result.a = uint8(a)


proc rectToFRect*(rect: Rect): FRect {.inline.} =
  FRect(x: rect.x.cfloat, y: rect.y.cfloat, w: rect.w.cfloat, h: rect.h.cfloat)

converter toRect*(t: tuple[x, y, w, h: cint]): Rect =
  Rect(x: t.x, y: t.y, w: t.w, h: t.h)

converter toFRect*(t: tuple[x, y, w, h: cfloat]): FRect =
  FRect(x: t.x, y: t.y, w: t.w, h: t.h)

proc rect*(x, y, w, h: cint): Rect {.inline.} =
  Rect(x: x, y: y, w: w, h: h)

proc fRect*(x, y, w, h: cfloat): FRect {.inline.} =
  FRect(x: x, y: y, w: w, h: h)

template kind*(e: Event): EventType = e.`type`
template `kind=`*(e: var Event, k: EventType) = e.`type` = k


const HINT_RENDER_SCALE_QUALITY* = "SDL_RENDER_SCALE_QUALITY"


proc getID*(window: Window): WindowID = getWindowID(window)

proc getSize*(window: Window, w,h: var cint): bool = getWindowSize(window, w, h)


#proc drawLine*(renderer: Renderer, x1,y1,x2,y2: cfloat): bool = renderLine(renderer, x1, y1, x2, y2)
proc clear*(renderer: Renderer): bool = renderClear(renderer)

#proc pushEvent*(event: ptr Event): bool = (if event != nil: pushEvent(event[]) else: false)

proc setRenderDrawColor*(renderer: Renderer, col: Color): bool = setRenderDrawColor(renderer, col.r, col.g, col.b, col.a)
proc setDrawBlendMode*(renderer: Renderer, blendMode: BlendMode): bool = setRenderDrawBlendMode(renderer, blendMode)
#proc renderTexture*(renderer: Renderer, texture: Texture, srcrect,dstrect: var FRect): bool {.importc: "SDL_RenderTexture".}
#proc renderTexture*(renderer: Renderer, texture: Texture, srcrect: ptr FRect, dstrect: FRect): bool = renderTexture(renderer, texture, srcrect, dstrect.addr)
proc present*(renderer: Renderer): bool = renderPresent(renderer)

#######################################################
# not SDL extras
#######################################################

proc duplicateTexture*(renderer: Renderer, source: Texture, srcW: cfloat = 0.0, srcH: cfloat = 0.0): Texture =
  var 
    w = srcW
    h = srcH

  # Get the dimensions of the original texture
  if srcW == 0.0 or srcH == 0.0:
    if not getTextureSize(source, w, h):
      return nil

  # 1. Create a new texture with the TARGET flag
  let dest = createTexture(
    renderer,
    PIXELFORMAT_RGBA8888, # Use the same format as the source if you know it
    TEXTUREACCESS_TARGET,
    w.cint, h.cint
  )
  if dest.isNil:
    return nil

  # 2. Set the new texture as the target
  if not setRenderTarget(renderer, dest):
    destroyTexture(dest)
    return nil

  # Copy the source texture onto the new target
  # Using nil for source and dest rects copies the entire texture to the entire target
  if not renderTexture(renderer, source, nil, nil):
    discard setRenderTarget(renderer, nil) # Reset target on failure
    destroyTexture(dest)
    return nil

  # 3. Reset the target back to the window (nil)
  discard setRenderTarget(renderer, nil)

  return dest