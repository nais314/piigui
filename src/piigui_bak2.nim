
import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf




# todo multiwindow
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


################################################################################


type
  MeasurementUnit = enum
    muAuto,
    muPx,
    muPc

  DivRef = ref DivObj
  DivObj = object of RootObj
    w,h:int
    w_value, h_value:int # original user numeric value
    w_unit, h_unit: MeasurementUnit # PiXel, PerCent
    minW, minH:int # if recalc needs advise

    recalc: proc(self:DivRef)
    x1,x2,y1,y2: int
    
    childs: seq[DivRef]
    parent: DivRef
    name: string


var
  rootElem: DivRef



import parseUtils

proc parseSizeStr*(sizeStr:string): tuple[unit:MeasurementUnit,value:int]=
  ## relative sizeStr parser for controlls
  var
    unit:string
    value:int

  if sizeStr == "auto":
    result.unit = muAuto
  else:
    var w_str: string # discard
    var count_numeric = sizeStr.parseUntil(w_str, {'%', 'p'}, 0) #https://nim-lang.org/docs/strutils.html#toLowerAscii%2Cstring
    if count_numeric > 0 : # 0 == error, or not found
      case sizeStr.substr(count_numeric):
        of "%", "pc": result.unit = muPc
        of "px": result.unit = muPx
        else: result.unit = muPc
      
    else: result.unit = muPc # like HTML

    discard sizeStr.parseInt(value)

  result.value = value



proc newDiv*(parent: DivRef,
             name: string,
             width:string="auto",
             height:string="auto",
             recalcFun:proc(self:DivRef) = nil): DivRef =
  result = new DivRef
  result.parent = parent
  (result.w_unit, result.w_value) = parseSizeStr(width)
  (result.h_unit, result.h_value) = parseSizeStr(height)
  result.childs = @[]
  result.recalc = recalcFun
  result.name = name
  parent.childs.add(result)
  echo " result.w_value ", name, ": ", (result.w_unit, result.w_value)
  echo " result.h_value ", name, ": ", (result.h_unit, result.h_value)
  echo ""


#####################################################################

proc recalcH*(self:DivRef)=
  ## calculate childs position Horizontally
  var
    availW = self.w
    availH = self.h
    wCount:int
    hCount:int

  echo self.name

  #todo valign, align
  if self.childs.len > 0:
    # not auto
    for elem in self.childs:
      echo "recalcH ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcH ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto: discard
        of muPx:
          elem.w = elem.w_value
          availW -= elem.w
          wCount += 1
        of muPc:
          elem.w = (self.w.float / (100.float / elem.w_value.float)).int
          availW -= elem.w
          wCount += 1

      case elem.h_unit:
        of muAuto: 
          elem.h = self.h
        of muPx:
          elem.h = elem.h_value
        of muPc:
          elem.h = (self.h.float / (100.float / elem.h_value.float)).int

          
    # auto -- could be faster with cache seq[elem]...
    if wCount < self.childs.len:
      let autoW = availW div (self.childs.len - wCount)
      for elem in self.childs:
        if elem.w_unit == muAuto: elem.w = autoW


    # coordinates
    var nextX = self.x1
    for elem in self.childs:
      # todo align
      elem.x1 = nextX
      elem.x2 = elem.x1 + elem.w - 1
      nextX = elem.x2 + 1
      
      # todo valign
      elem.y1 = self.y1
      elem.y2 = elem.y1 + elem.h - 1

      echo "w/h", elem.w, "/", elem.h
      echo "x1/x2", elem.x1, "/", elem.x2
      echo "y1,y2", elem.y1, "/", elem.y2
      echo ""

    for elem in self.childs:
      if elem.childs.len > 0 and elem.recalc != nil:
        elem.recalc(elem)

  else: echo "NO CHILDS"
  # todo recursive




#-------------------------------------------------------



proc recalcV(self: DivRef)=
  ## calculate childs position Vertically
  var
    availW = self.w
    availH = self.h
    wCount:int
    hCount:int

  echo self.name

  #todo valign, align
  if self.childs.len > 0:
    # not auto
    for elem in self.childs:
      echo "recalcV ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcV", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto:
          elem.w = elem.w_value
        of muPx:
          elem.w = elem.w_value
        of muPc:
          elem.w = (self.w.float / (100.float / elem.w_value.float)).int

      case elem.h_unit:
        of muAuto: discard
        of muPx:
          elem.h = elem.h_value
          availH -= elem.h
          hCount += 1
        of muPc:
          elem.h = (self.h.float / (100.float / elem.h_value.float)).int
          echo elem.h, " !"
          availH -= elem.h
          hCount += 1

          
    # auto -- could be faster with cache seq[elem]...
    if hCount < self.childs.len:
      echo "calc AUTO"
      let autoH = availH div (self.childs.len - hCount)
      for elem in self.childs:
        if elem.h_unit == muAuto: elem.h = autoH

    # coordinates
    var nextY = self.y1
    for elem in self.childs:
      # todo align
      elem.x1 = self.x1
      elem.x2 = elem.x1 + elem.w - 1
      #nextX = elem.x2 + 1
      
      # todo valign
      elem.y1 = nextY
      elem.y2 = elem.y1 + elem.h - 1
      nextY = elem.y2 + 1

      echo "w/h", elem.w, "/", elem.h
      echo "x1/x2", elem.x1, "/", elem.x2
      echo "y1,y2", elem.y1, "/", elem.y2
      echo ""

    # recursively calc
    for elem in self.childs:
      if elem.childs.len > 0 and elem.recalc != nil:
        elem.recalc(elem)

  else: echo "NO CHILDS"



#-------------------------------------------------------






proc recalcFlowH(self: DivRef)=
  ## calculate childs position Horizontally
  var
    availW = self.w
    availH = self.h
    wCount:int
    hCount:int
    newY = self.y1
    nextY = self.y1
    nextX:int

  echo self.name

  #todo valign, align
  if self.childs.len > 0:
    # not auto
    for elem in self.childs:
      echo "recalcH ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcH ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto:
          elem.w = availW
          availW = self.w # newLine
          nextY = newY + 1
          nextX = self.x1
          availW -= elem.w

        of muPx:
          elem.w = elem.w_value
          if availW - elem.w < 0:
            availW = self.w # newLine
            nextY = newY + 1
            nextX = self.x1
          availW -= elem.w

        of muPc:
          elem.w = (self.w.float / (100.float / elem.w_value.float)).int
          if availW - elem.w < 0:
            availW = self.w # newLine
            nextY = newY + 1
            nextX = self.x1
          availW -= elem.w

      elem.x1 = nextX
      elem.x2 = nextX + elem.w - 1
      nextX = nextX + elem.w


      case elem.h_unit:
        of muAuto: 
          elem.h = elem.minH
        of muPx:
          elem.h = elem.h_value
        of muPc:
          elem.h = (self.h.float / (100.float / elem.h_value.float)).int

      if nextY + elem.h > newY: newY = nextY + elem.h - 1
      elem.y1 = nextY
      elem.y2 = nextY + elem.h - 1


      echo "w/h", elem.w, "/", elem.h
      echo "x1/x2", elem.x1, "/", elem.x2
      echo "y1,y2", elem.y1, "/", elem.y2
      echo ""

    for elem in self.childs:
      if elem.childs.len > 0 and elem.recalc != nil:
        elem.recalc(elem)

  else: echo "NO CHILDS"
  # todo recursive





















###########################################################
###########################################################

proc initDOM()=
  rootElem = new DivRef
  rootElem.childs = @[]
  rootElem.parent = nil
  rootElem.w = 640
  rootElem.h = 480
  rootElem.w_unit = muPx
  rootElem.h_unit = muPx
  rootElem.recalc = recalcV
  #................

  var
    #[ a1 = newDiv(rootElem, "a1", "100%", "auto", recalcH)
    a2 = newDiv(rootElem, "a2", "100%", "33%", recalcH)

    a1b1 = newDiv(a1, "a1b1", "auto", "100%", recalcV)
    a1b2 = newDiv(a1, "a1b2", "33%", "100%", recalcV)

    a1b1c1 = newDiv(a1b1, "a1b1c1", "100%", "auto", recalcH)
    a1b1c2 = newDiv(a1b1, "a1b1c2", "100%", "50%", recalcH)

    a1b1c2d1 = newDiv(a1b1c2, "a1b1c2d1", "auto", "100%", recalcH)
    a1b1c2d2 = newDiv(a1b1c2, "a1b1c2d2", "50%", "100%", recalcH) ]#

    header = newDiv(rootElem, "header", "100%", "10%", recalcH)
    frame1 = newDiv(rootElem, "frame1", "100", "80", recalcH)
    content = newDiv(frame1, "content", "70", "auto", recalcFlowH)
    sidebar = newDiv(frame1, "sidebar", "auto", "auto", recalcV)
    footer = newDiv(rootElem, "footer", "100", "10", recalcH)


  for i in 0..19:
    discard content.newDiv("contentbtn" & $i, "40px", "40px")
  for i in 0..9:
    discard sidebar.newDiv("sidebarbtn" & $i, "100", "20px")

  var outscreen = newDiv(content, "outscreen", "100px", "800px")

  rootElem.recalc(rootElem)






import random
proc testDrawDOM(app:App, r: DivRef)=
  var clipRect: sdl.Rect
  clipRect.x = 0
  clipRect.y = 0
  clipRect.w = 640 div 4
  clipRect.h = 480 div 4
  #echo "renderSetClipRect ", sdl.setClipRect(app.renderer, clipRect.addr)


  var ww, wh: cint
  sdl.getSize(app.window, addr(ww), addr(wh))
  echo "getSize ", ww, "x", wh
  randomize()
  for elem in r.childs:
    var
      r = (rand(127) + 128).uint8
      g = (rand(127) + 128).uint8
      b = (rand(127) + 128).uint8
      rect : sdl.Rect = (
        x:elem.x1,
        y:elem.y1, 
        w:(elem.x2 - elem.x1 + 1),
        h:(elem.y2 - elem.y1 + 1)
        )
    discard app.renderer.setRenderDrawColor(r, g, b, 0xFF)
    discard app.renderer.fillRect(addr(rect))

    if elem.childs.len > 0:
      testDrawDOM(app, elem)





########################################################################################################################


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



  # Clear screen with draw color
  if app.renderer.clear() != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't clear screen: %s",
                sdl.getError())
  


  initDOM()
  testDrawDOM(app, rootElem)
  # Update renderer
  app.renderer.renderPresent()
  # Main loop
  while not done:



    # Render




    # Update renderer
    #app.renderer.renderPresent()

    # Event handling
    done = events()

  # Free assets
  #free(image1)

# Shutdown
exit(app)

