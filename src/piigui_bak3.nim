
import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf

import random
import tables
import times

# todo multiwindow
#[ todo
    appbase - channels, change properties
    querySelector
    findElementByName
    getElementById
    getElementByPath
 ]#
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

    font_normal: ttf.FontPtr



  Image = ref ImageObj
  ImageObj = object of RootObj
    texture: sdl.Texture # Image texture
    w, h: int # Image dimensions


################################################################################


type
  MeasurementUnit* = enum
    muAuto,
    muPx,
    muPc

#-------------------------------------------------------------------------------
  BackgroundRepeatKind* = enum
    bgrRepeat,
    bgrNoRepeat,
    bgrRepeatX,
    bgrRepeatY

  OverFlowKind* = enum
    ofScroll,
    ofHidden,
    #ofVisible, #notimplemented
    ofX,
    ofY

  FlexDirectionKind* = enum
    fdRow,
    fdColumn,
    fdRowReverse,
    fdColumnReverse
  
  FlexJustifyContentKind* = enum
    jcStart,
    jcCenter,
    jcEnd

  FlexAlignContentKind* = enum
    facStretch,
    facCenter,
    facStart,
    facEnd,
    facSpaceBetween,
    facSpaceAround

  FlexAlignItemsKind* = enum
    faiStretch,
    faiCenter,
    faiStart,
    faiEnd,
    faiBaseLine

  PositionKind* = enum
    posRelative,
    posAbsolute,
    posFixed
  #.......................................
  PropertiesRef* = ref PropertiesObj
  PropertiesObj* = object of RootObj
    width*: int
    height*: int
    flexGrow*: int
    flexShrink*: int

    color*: sdl.Color
    backGroundColor*: sdl.Color
    backGroundTexture*: sdl.Texture
    backGroundTexture_nineScale*: int
    backGroundProc*: proc(w,h:int, color:sdl.Color, x:int):Texture #? ptr? x for future and custom info pass
    backGroundRepeat*: BackgroundRepeatKind

    overFlow*: OverFlowKind

    flexDirection*: FlexDirectionKind
    flexWrap*: bool #! overflow?????
    justifyContent*: FlexJustifyContentKind
    alignContent*: FlexAlignContentKind
    alignItems*: FlexAlignItemsKind

    opacity*: int #TODO how to add opacity? 0 - 1.0 * alpha?

    position*: PositionKind



  StyleSheets* = TableRef[string, PropertiesRef]

#-------------------------------------------------------------------------------

  DivRef = ref DivObj
  DivObj = object of RootObj
    w,h:int
    w_value, h_value:int # original user numeric value
    w_unit, h_unit: MeasurementUnit # PiXel, PerCent
    minW, minH:int # if recalc needs advise

    app:App
    name: string
    parent: DivRef
    childs: seq[DivRef]

    recalc: proc(this:DivRef)
    x1,x2,y1,y2: int
    redrawFlag:int # needs redraw? what to redraw?
    draw:proc(this:DivRef)
    changed:bool


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
             recalcFun:proc(this:DivRef) = nil): DivRef =
  result = new DivRef
  result.parent = parent
  (result.w_unit, result.w_value) = parseSizeStr(width)
  (result.h_unit, result.h_value) = parseSizeStr(height)
  result.childs = @[]
  result.recalc = recalcFun
  result.name = name
  result.changed = true
  parent.childs.add(result)
  echo " result.w_value ", name, ": ", (result.w_unit, result.w_value)
  echo " result.h_value ", name, ": ", (result.h_unit, result.h_value)
  echo ""


#####################################################################

proc recalcH*(this:DivRef)=
  ## calculate childs position Horizontally
  var
    availW = this.w
    availH = this.h
    wCount:int
    hCount:int

  echo this.name

  #todo valign, align
  if this.childs.len > 0:
    # not auto
    for elem in this.childs:
      echo "recalcH ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcH ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto: discard
        of muPx:
          elem.w = elem.w_value
          availW -= elem.w
          wCount += 1
        of muPc:
          elem.w = (this.w.float / (100.float / elem.w_value.float)).int
          availW -= elem.w
          wCount += 1

      case elem.h_unit:
        of muAuto: 
          elem.h = this.h
        of muPx:
          elem.h = elem.h_value
        of muPc:
          elem.h = (this.h.float / (100.float / elem.h_value.float)).int

          
    # auto -- could be faster with cache seq[elem]...
    if wCount < this.childs.len:
      let autoW = availW div (this.childs.len - wCount)
      for elem in this.childs:
        if elem.w_unit == muAuto: elem.w = autoW


    # coordinates
    var nextX = this.x1
    for elem in this.childs:
      # todo align
      elem.x1 = nextX
      elem.x2 = elem.x1 + elem.w - 1
      nextX = elem.x2 + 1
      
      # todo valign
      elem.y1 = this.y1
      elem.y2 = elem.y1 + elem.h - 1

      echo "w/h", elem.w, "/", elem.h
      echo "x1/x2", elem.x1, "/", elem.x2
      echo "y1,y2", elem.y1, "/", elem.y2
      echo ""

    for elem in this.childs:
      if elem.childs.len > 0 and elem.recalc != nil:
        elem.recalc(elem)

  else: echo "NO CHILDS"
  # todo recursive




#-------------------------------------------------------



proc recalcV(this: DivRef)=
  ## calculate childs position Vertically
  var
    availW = this.w
    availH = this.h
    wCount:int
    hCount:int

  echo this.name

  #todo valign, align
  if this.childs.len > 0:
    # not auto
    for elem in this.childs:
      echo "recalcV ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcV", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto:
          elem.w = elem.w_value
        of muPx:
          elem.w = elem.w_value
        of muPc:
          elem.w = (this.w.float / (100.float / elem.w_value.float)).int

      case elem.h_unit:
        of muAuto: discard
        of muPx:
          elem.h = elem.h_value
          availH -= elem.h
          hCount += 1
        of muPc:
          elem.h = (this.h.float / (100.float / elem.h_value.float)).int
          echo elem.h, " !"
          availH -= elem.h
          hCount += 1

          
    # auto -- could be faster with cache seq[elem]...
    if hCount < this.childs.len:
      echo "calc AUTO"
      let autoH = availH div (this.childs.len - hCount)
      for elem in this.childs:
        if elem.h_unit == muAuto: elem.h = autoH

    # coordinates
    var nextY = this.y1
    for elem in this.childs:
      # todo align
      elem.x1 = this.x1
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
    for elem in this.childs:
      if elem.childs.len > 0 and elem.recalc != nil:
        elem.recalc(elem)

  else: echo "NO CHILDS"



#-------------------------------------------------------






proc recalcFlowH(this: DivRef)=
  ## calculate childs position Horizontally
  var
    availW = this.w
    availH = this.h
    wCount:int
    hCount:int
    newY = this.y1
    nextY = this.y1
    nextX:int

  echo this.name

  #todo valign, align
  if this.childs.len > 0:
    # not auto
    for elem in this.childs:
      echo "recalcH ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcH ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto:
          elem.w = availW
          availW = this.w # newLine
          nextY = newY + 1
          nextX = this.x1
          availW -= elem.w

        of muPx:
          elem.w = elem.w_value
          if availW - elem.w < 0:
            availW = this.w # newLine
            nextY = newY + 1
            nextX = this.x1
          availW -= elem.w

        of muPc:
          elem.w = (this.w.float / (100.float / elem.w_value.float)).int
          if availW - elem.w < 0:
            availW = this.w # newLine
            nextY = newY + 1
            nextX = this.x1
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
          elem.h = (this.h.float / (100.float / elem.h_value.float)).int

      if nextY + elem.h > newY: newY = nextY + elem.h - 1
      elem.y1 = nextY
      elem.y2 = nextY + elem.h - 1


      echo "w/h", elem.w, "/", elem.h
      echo "x1/x2", elem.x1, "/", elem.x2
      echo "y1,y2", elem.y1, "/", elem.y2
      echo ""

    for elem in this.childs:
      if elem.childs.len > 0 and elem.recalc != nil:
        elem.recalc(elem)

  else: echo "NO CHILDS"
  # todo recursive





















###########################################################
###########################################################



proc divDrawTest(this:DivRef)=
  var clipRect: sdl.Rect
  clipRect.x = this.x1
  clipRect.y = this.y1
  clipRect.w = (this.x2 - this.x1 + 1)
  clipRect.h = (this.y2 - this.y1 + 1)
  discard sdl.setClipRect(this.app.renderer, clipRect.addr)

  randomize()
  var
    r = (rand(127) + 128).uint8
    g = (rand(127) + 128).uint8
    b = (rand(127) + 128).uint8
    a: uint8 = 255
    rect : sdl.Rect = (
      x:this.x1,
      y:this.y1, 
      w:(this.x2 - this.x1 + 1),
      h:(this.y2 - this.y1 + 1)
      )

  discard this.app.renderer.setRenderDrawColor(r, g, b, 0xFF)
  discard this.app.renderer.fillRect(addr(rect))

  var
    fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8))
    fontBgColor = sdl.Color((r:0'u8,g:255'u8,b:0'u8,a:255'u8))

  #var surface = this.app.font_normal.renderUTF8_Solid(this.name, fontColor)
  discard this.app.renderer.getRenderDrawColor(fontBgColor.r.addr, fontBgColor.g.addr, fontBgColor.b.addr, fontBgColor.a.addr)
  var surface = this.app.font_normal.renderUtf8Shaded(this.name, fontColor, fontBgColor)
  discard surface.setColorKey(1,0)

  var srect : sdl.Rect = (x: this.x1, y: this.y1, w: surface.w, h: surface.h)
  var texture = sdl.createTextureFromSurface(this.app.renderer, surface)
  discard this.app.renderer.copy(texture, nil, srect.addr) 

  #discard this.app.renderer.render(sl, this.x1 + 2, rhis.y1 + 2, clipRect)
  sdl.freeSurface(surface)
  destroyTexture(texture) #?



  discard sdl.setClipRect(this.app.renderer, nil)

#........................................................



proc initDOM(app:App)=
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

  header.draw = divDrawTest
  frame1.draw = divDrawTest
  content.draw = divDrawTest
  sidebar.draw = divDrawTest
  footer.draw = divDrawTest

  header.app = app
  frame1.app = app
  content.app = app
  sidebar.app = app
  footer.app = app


  for i in 0..19:
    var tmp = content.newDiv("contentbtn" & $i, "40px", "40px")
    tmp.draw = divDrawTest
    tmp.app = app
  for i in 0..9:
    var tmp = sidebar.newDiv("sidebarbtn" & $i, "100", "20px")
    tmp.draw = divDrawTest
    tmp.app = app

  var outscreen = newDiv(content, "outscreen", "100px", "800px")
  outscreen.draw = divDrawTest
  outscreen.app = app

  rootElem.recalc(rootElem)







proc testDrawDOM(app:App, r: DivRef)=
  #[ var clipRect: sdl.Rect
  clipRect.x = 0
  clipRect.y = 0
  clipRect.w = 640 div 4
  clipRect.h = 480 div 4 ]#
  #echo "renderSetClipRect ", sdl.setClipRect(app.renderer, clipRect.addr)


  #[ var ww, wh: cint
  sdl.getSize(app.window, addr(ww), addr(wh))
  echo "getSize ", ww, "x", wh ]#


#[   randomize()
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
    discard app.renderer.fillRect(addr(rect)) ]#

  for elem in r.childs:
    if elem.changed:
      elem.draw(elem)
      elem.changed = false

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
  var
    font = ttf.openFont("agave_regular_mono_nerd.ttf", 16)
    fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:1'u8))

  app.font_normal = font

  # Clear screen with draw color
  if app.renderer.clear() != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't clear screen: %s",
                sdl.getError())
  


  initDOM(app)
  testDrawDOM(app, rootElem)
  # Update renderer
  app.renderer.renderPresent()


  proc testThread(rootElem:ptr DivRef) {.thread.} =
    for i in 0..10:
      var sss = ($(rand(65535)))
      `=sink`(rootElem.childs[0].name,  sss)
      rootElem.childs[0].changed = true
      echo i, ": ", rootElem.childs[0].name 
      sdl.delay(300)

  var thread1: system.Thread[ptr DivRef]
  system.createThread(thread1,testThread, rootElem.addr)

  # Main loop
  while not done:



    # Render
    testDrawDOM(app, rootElem)

    sdl.delay(500)

    #rootElem.childs[0].name = "gomba"

    # Update renderer
    app.renderer.renderPresent()

    # Event handling
    done = events()

  # Free assets
  #free(image1)

# Shutdown
exit(app)

