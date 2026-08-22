import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf,

  os, unicode


const
  Title = "SDL2 Pgui"
  ScreenW = 640 # Window width
  ScreenH = 480 # Window height
  WindowFlags = 0
  RendererFlags = sdl.RendererAccelerated or sdl.RendererPresentVsync or sdl.RendererTargetTexture

#############################


# Init SDL
if sdl.init(sdl.InitVideo) != 0:
  sdl.logCritical(sdl.LogCategoryError,
                  "Can't initialize SDL: %s",
                  sdl.getError())

# Init SDL_TTF
if ttf.init() != 0:
  sdl.logCritical(sdl.LogCategoryError,
                  "Can't initialize SDL_TTF: %s",
                  ttf.getError())




##############################
let window = sdl.createWindow(
      "title", sdl.WindowPosUndefined,sdl.WindowPosUndefined,
      ScreenW,ScreenH, WindowFlags)
if window == nil:
  sdl.logCritical(sdl.LogCategoryError,
                "Can't create window: %s",
                sdl.getError())
  quit( "Can't create window: %s")

#........................

let renderer = sdl.createRenderer(
      window,
      -1,
      sdl.RendererAccelerated or sdl.RendererPresentVsync or sdl.RendererTargetTexture)
if renderer == nil:
  sdl.logCritical(sdl.LogCategoryError,
                  "Can't create renderer: %s",
                  sdl.getError())
  quit( "Can't create renderer: %s")

if renderer.clear() != 0:
  sdl.logWarn(sdl.LogCategoryVideo,
              "Can't clear screen: %s",
              sdl.getError())
  quit( "Can't clear")
#........................

sdl.renderPresent(renderer)
###############################x

# render text --- render text --- render text ---
var
  font_normal = ttf.openFont(os.getAppDir() & os.DirSep & "fonts" & os.DirSep & "agave_regular_mono_nerd.ttf", 16)
  fontColor = sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8))
  fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))
  text = "Elemózsiás"

echo os.getAppDir() & os.DirSep & "fonts" & os.DirSep & "agave_regular_mono_nerd.ttf"
if font_normal == nil: quit("font load error")
echo "fontHeight: ", font_normal.fontHeight()

var surface = font_normal.renderUtf8Shaded(
              text,
              fontColor,
              fontBgColor)

echo "surface.w: ",surface.w

var srect : sdl.Rect = (
                    x: 0,
                    y: 0,
                    w: surface.w,
                    h: surface.h)

var texture = sdl.createTextureFromSurface(renderer, surface)

discard renderer.copy(texture,
    nil, srect.addr)

sdl.freeSurface(surface)
destroyTexture(texture)

#..................................
#for ci in 0..text.high:
var r1:string
for r in text.runes():
  r1.add(r)
  var surface = font_normal.renderUtf8Shaded(
                r1,
                fontColor,
                fontBgColor)

  echo r1, ".w: ",surface.w

  var srect : sdl.Rect = (
                      x: 0,
                      y: 0,
                      w: surface.w,
                      h: surface.h)

  var texture = sdl.createTextureFromSurface(renderer, surface)

  discard renderer.copy(texture,
      nil, srect.addr)

  sdl.freeSurface(surface)
  destroyTexture(texture)


#........................

var
  #r1:string
  cursor:int
for r1 in text.utf8():
  var surface = font_normal.renderUtf8Shaded(
                r1,
                fontColor,
                fontBgColor)

  echo r1, ".w: ",surface.w

  var srect : sdl.Rect = (
                      x: cursor,
                      y: 20,
                      w: surface.w,
                      h: surface.h)

  cursor += 8

  var texture = sdl.createTextureFromSurface(renderer, surface)

  discard renderer.copy(texture,
      nil, srect.addr)

  sdl.freeSurface(surface)
  destroyTexture(texture)


#........................


sdl.renderPresent(renderer)


#........................

var
  e: sdl.Event
  done = false

while not done:
  while sdl.pollEvent(addr(e)) != 0:

    # Quit requested
    if e.kind == sdl.Quit:
      done = true
      break

    # Key pressed
    elif e.kind == sdl.KeyDown:
      # Exit on Escape key press
      if e.key.keysym.sym == sdl.K_Escape:
        done = true
        break
    
    
    elif e.kind == sdl.MOUSEBUTTONUP:
      if e.motion.y <= 16:
        let c1 = e.motion.x div 8 + 1
        if c1 <= text.runeLen:
          echo runeSubStr(text,0,c1)

###############################x
renderer.destroyRenderer()
window.destroyWindow()
ttf.quit()
#img.quit()
sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
sdl.quit()