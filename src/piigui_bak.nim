import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf





const
  Title = "SDL2 App"
  ScreenW = 640 # Window width
  ScreenH = 480 # Window height
  WindowFlags = 0
  RendererFlags = sdl.RendererAccelerated or sdl.RendererPresentVsync


type
  App = ref AppObj
  AppObj = object
    window*: sdl.Window # Window pointer
    renderer*: sdl.Renderer # Rendering state pointer


  Image = ref ImageObj
  ImageObj = object of RootObj
    texture: sdl.Texture # Image texture
    w, h: int # Image dimensions


#########
# IMAGE #
#########

proc newImage(): Image = Image(texture: nil, w: 0, h: 0)
proc free(obj: Image) = sdl.destroyTexture(obj.texture)
proc w(obj: Image): int {.inline.} = return obj.w
proc h(obj: Image): int {.inline.} = return obj.h


# Load image from file
# Return true on success or false, if image can't be loaded
proc load(obj: Image, renderer: sdl.Renderer, file: string): bool =
  result = true
  # Load image to texture
  obj.texture = renderer.loadTexture(file)
  if obj.texture == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't load image %s: %s",
                    file, img.getError())
    return false
  # Get image dimensions
  var w, h: cint
  if obj.texture.queryTexture(nil, nil, addr(w), addr(h)) != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't get texture attributes: %s",
                    sdl.getError())
    sdl.destroyTexture(obj.texture)
    return false
  obj.w = w
  obj.h = h


# Render texture to screen
proc render(obj: Image, renderer: sdl.Renderer, x, y: int): bool =
  var rect : sdl.Rect = (x: x, y: y, w: obj.w, h: obj.h)
  if renderer.copy(obj.texture, nil, addr(rect)) == 0:
    return true
  else:
    return false

# Render surface
proc render(renderer: sdl.Renderer,
            surface: sdl.Surface, x, y: int): bool =
  result = true
  var rect : sdl.Rect = (x: x, y: y, w: surface.w, h: surface.h)
  # Convert to texture
  var texture = sdl.createTextureFromSurface(renderer, surface)
  if texture == nil:
    return false
  # Render texture
  if renderer.copy(texture, nil, addr(rect)) == 0:
    result = false
  # Clean
  destroyTexture(texture)


# Render surface
proc render(renderer: sdl.Renderer,
            surface: sdl.Surface,
            x, y: int,
            clip: var sdl.Rect): bool =
  result = true
  var rect : sdl.Rect = (x: x, y: y, w: surface.w, h: surface.h)
  if clip.w < rect.w: rect.w = clip.w
  if clip.h < rect.h: rect.h = clip.h
  # Convert to texture
  var texture = sdl.createTextureFromSurface(renderer, surface)
  if texture == nil:
    return false
  # Render texture
  if renderer.copy(texture, addr(clip), addr(rect)) == 0:
    result = false
  # Clean
  destroyTexture(texture)

##########
# COMMON #
##########


# Initialization sequence
proc init(app: App): bool =
  # Init SDL
  if sdl.init(sdl.InitVideo) != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL: %s",
                    sdl.getError())
    return false

  # Init SDL_Image
  if img.init(img.InitPng) == 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL_Image: %s",
                    img.getError())

  # Init SDL_TTF
  if ttf.init() != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL_TTF: %s",
                    ttf.getError())

  # Create window
  app.window = sdl.createWindow(
    Title,
    sdl.WindowPosUndefined,
    sdl.WindowPosUndefined,
    ScreenW,
    ScreenH,
    WindowFlags)
  if app.window == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create window: %s",
                    sdl.getError())
    return false

  # Create renderer
  app.renderer = sdl.createRenderer(app.window, -1, RendererFlags)
  if app.renderer == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create renderer: %s",
                    sdl.getError())
    return false

  # Set draw color
  if app.renderer.setRenderDrawColor(0x00, 0x00, 0x00, 0xFF) != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't set draw color: %s",
                sdl.getError())
    return false

  sdl.logInfo(sdl.LogCategoryApplication, "SDL initialized successfully")
  return true


# Shutdown sequence
proc exit(app: App) =
  app.renderer.destroyRenderer()
  app.window.destroyWindow()
  ttf.quit()
  img.quit()
  sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()


# Event handling
# Return true on app shutdown request, otherwise return false
proc events(): bool =
  result = false
  var e: sdl.Event

  while sdl.pollEvent(addr(e)) != 0:

    # Quit requested
    if e.kind == sdl.Quit:
      return true

    # Key pressed
    elif e.kind == sdl.KeyDown:
      # Exit on Escape key press
      if e.key.keysym.sym == sdl.K_Escape:
        return true


########
# MAIN #
########

var
  app = App(window: nil, renderer: nil)
  done = false # Main loop exit condition

import times

var
  t0: float

t0 = epochTime()

if init(app):

  # Load assets
  #[ var
    image1 = newImage()
  if not image1.load(app.renderer, "img/img1.png"):
    done = true ]#

  # Load assets
  var
    font, outlinedFont: ttf.FontPtr
    textColor = sdl.Color(r: 0xFF, g: 0xFF, b: 0xFF)
    bgColor = sdl.Color(r: 0x30, g: 0x30, b: 0x30)

  font = ttf.openFont("agave_regular_mono_nerd.ttf", 16)
  outlinedFont = ttf.openFont("agave_regular_mono_nerd.ttf", 48)

  if font == nil or outlinedFont == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't load font: %s",
                    ttf.getError())
    done = true

  # Set outline thickness
  outlinedFont.setFontOutline(1)



  # Clear screen with draw color
  if app.renderer.clear() != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't clear screen: %s",
                sdl.getError())
  



  var colBox: sdl.Color = tupleToColor((r:0xFF, g:0xFF, b:0x00, a:0xFF))
  var colBorder: sdl.Color = tupleToColor((r:0xFF, g:0x77, b:0x00, a:0xFF))
  var
    col2: sdl.Color = colBox
    col1: sdl.Color = tupleToColor((r:0xFF, g:0x77, b:0x00, a:0xFF))




  var rect : sdl.Rect = (x: 5, y: 240, w: 630, h: 235)
  discard app.renderer.setRenderDrawColor(0xFF, 0xFF, 0xFF, 0xFF)
  discard app.renderer.drawRect(addr(rect))

  var clip : sdl.Rect = (x: 0, y: 0, w: 615, h: 630)
  var lineH = font.fontHeight()
  var sl: sdl.Surface
  for il in 0 .. (rect.h div lineH) - 1 :
    sl = font.renderUTF8_Solid("#########_#########_#########_#########_#########_#########_#########_#########_#########_", textColor)
    discard app.renderer.render(sl, 10, ((rect.y + 5) + (il * lineH)), clip)
    sdl.freeSurface(sl)



  # Main loop
  while not done:
    # Clear screen with draw color
    #[ if app.renderer.clear() != 0:
      sdl.logWarn(sdl.LogCategoryVideo,
                  "Can't clear screen: %s",
                  sdl.getError()) ]#

    # Render textures
    #[ if not image1.render(app.renderer, 0, 0):
      sdl.logWarn(sdl.LogCategoryVideo,
                  "Can't render image1: %s",
                  sdl.getError()) ]#
    rect : sdl.Rect = (x: 10, y: 30, w: 100, h: 50)
    discard app.renderer.setRenderDrawColor(colBox.r, colBox.g, colBox.b, colBox.a)
    discard app.renderer.fillRect(addr(rect))
    discard app.renderer.setRenderDrawColor(colBorder.r, colBorder.g, colBorder.b, colBorder.a)
    discard app.renderer.drawRect(addr(rect))
    #[ rect.x += 1
    rect.y += 1
    rect.w -= 2
    rect.h -= 2
    discard app.renderer.drawRect(addr(rect)) ]#

    if epochTime() - t0 >= 1.0:
      if colBox == col1: 
        colBox = col2
      else:
        colBox = col1
      t0 = epochTime()




    # Render text

    var s: sdl.Surface

    s = font.renderUTF8_Solid("Solid text", textColor)
    discard app.renderer.render(s, 10, 10)
    sdl.freeSurface(s)

    s = font.renderUtf8Shaded("Shaded text", textColor, bgColor)
    discard app.renderer.render(s, 10, 30)
    sdl.freeSurface(s)

    s = font.renderUTF8_Blended("Blended text", textColor)
    discard app.renderer.render(s, 10, 50)
    sdl.freeSurface(s)

    s = font.renderUTF8_Blended_Wrapped(
      "This is really long line of text.", textColor, 150)
    discard app.renderer.render(s, 10, 90)
    sdl.freeSurface(s)

    s = outlinedFont.renderUTF8_Blended("Outlined text", textColor)
    discard app.renderer.render(s, 10, 150)
    sdl.freeSurface(s)





    # Update renderer
    app.renderer.renderPresent()

    # Event handling
    done = events()

  # Free assets
  #free(image1)

# Shutdown
exit(app)

