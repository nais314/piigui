
import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf

import piigui
import piigui/[types,style]
import piigui/layout/flex
import piigui/layout/vhbox

import piigui/ui_textbox
import piigui/ui/textarea/utf8unstyled

###########################################

import random
import tables
import times
import os

###########################################

var
  rootElem: DivRef

###########################################

const
  Title = "SDL2 Pgui"
  ScreenW = 640 # Window width
  ScreenH = 480 # Window height
  WindowFlags = 0
  RendererFlags = sdl.RendererAccelerated or sdl.RendererPresentVsync or sdl.RendererTargetTexture


type
  Image = ref ImageObj
  ImageObj = object of RootObj
    texture: sdl.Texture # Image texture
    w, h: int # Image dimensions




###########################################################
###########################################################

#[
########  ########     ###    ##      ##
##     ## ##     ##   ## ##   ##  ##  ##
##     ## ##     ##  ##   ##  ##  ##  ##
##     ## ########  ##     ## ##  ##  ##
##     ## ##   ##   ######### ##  ##  ##
##     ## ##    ##  ##     ## ##  ##  ##
########  ##     ## ##     ##  ###  ###

######## ########  ######  ########
   ##    ##       ##    ##    ##
   ##    ##       ##          ##
   ##    ######    ######     ##
   ##    ##             ##    ##
   ##    ##       ##    ##    ##
   ##    ########  ######     ##


]#

proc divDrawTest(this:DivRef)=
  const debug = 0b0

  when debug > 0:
    echo "divDrawTest"
    echo this.name
    echo "w: ",this.w, " h: ", this.h
    echo "x1: ",this.x1, " y1: ", this.y1
    echo "___________"

  #.............................
  # clipRect hide overflow
  var clipRect: sdl.Rect
  if this.parent == nil:
    clipRect.x = this.x1
    clipRect.y = this.y1
    clipRect.w = this.w
    clipRect.h = this.h
  else:
    clipRect.x = this.parent.x1
    clipRect.y = this.parent.y1
    clipRect.w = this.parent.w #(this.x2 - this.x1 + 1)
    clipRect.h = this.parent.h #(this.y2 - this.y1 + 1)
  discard sdl.setClipRect(this.app.renderer, clipRect.addr)
  #.............................

  # backgroundRect is the rect we can paint
  # after
  # sdl.setRenderTarget(this.app.renderer, this.textureCache) 
  var backgroundRect: sdl.Rect
  backgroundRect.x = 0
  backgroundRect.y = 0
  backgroundRect.w = this.w
  backgroundRect.h = this.h

  #.............................

  # the area to paint to
  var thisRect: sdl.Rect
  thisRect.x = this.x1
  thisRect.y = this.y1
  thisRect.w = this.w
  thisRect.h = this.h

  #.............................
  # we need to redraw, even if not changed
  if this.redrawFlag == 0 and this.textureCache != nil:
      discard this.app.renderer.copy(
          this.textureCache,
          nil, thisRect.addr)


  else:
    # if need to redraw, check if cache setted up
    # todo setup cahce at recalc
    if this.textureCache == nil:
      this.textureCache = sdl.createTexture(
        this.app.renderer,
        sdl.SDL_PIXELFORMAT_UNKNOWN,#PIXELFORMAT_RGBA8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        this.w,
        this.h)
      discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

    # the elems. texture is the render target x=0 y=0!
    discard sdl.setRenderTarget(this.app.renderer, this.textureCache)
    discard this.app.renderer.setRenderDrawColor(clearColor)
    #discard this.app.renderer.clear()
    #.............................

    if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
      discard this.app.renderer.setRenderDrawColor(
        this.styleCache[this.activeStyle].backGroundColor)
    else:
      randomize()
      var
        r: uint8 = (rand(127) + 128).uint8
        g: uint8 = (rand(127) + 128).uint8
        b: uint8 = (rand(127) + 128).uint8
        a: uint8 = 255
      discard this.app.renderer.setRenderDrawColor(r, g, b, a)

    # draw the elem
    discard this.app.renderer.fillRect(addr(backgroundRect))



    #=====================================
    # render text --- render text --- render text ---
    var
      fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8))
      fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))

    #var surface = this.app.font_normal.renderUTF8_Solid(this.name, fontColor)
    discard this.app.renderer.getRenderDrawColor(
                  fontBgColor.r.addr,
                  fontBgColor.g.addr,
                  fontBgColor.b.addr,
                  fontBgColor.a.addr)
    var surface = this.app.font_normal.renderUtf8Shaded(
                  this.name,
                  fontColor,
                  fontBgColor)
    #discard surface.setColorKey(1,0)

    var srect : sdl.Rect = (
                        x: 0,
                        y: 0,
                        w: surface.w,
                        h: surface.h)

    var texture = sdl.createTextureFromSurface(this.app.renderer, surface)

    discard this.app.renderer.copy(texture,
        nil, srect.addr)

    sdl.freeSurface(surface)
    destroyTexture(texture) #?


    #=====================================
    discard sdl.setRenderTarget(this.app.renderer, nil)
    discard this.app.renderer.copy(
        this.textureCache,
        nil, thisRect.addr)


  # reset clipping
  discard sdl.setClipRect(this.app.renderer, nil)

  this.redrawFlag = 0

#........................................................








#[
#### ##    ## #### ########
 ##  ###   ##  ##     ##
 ##  ####  ##  ##     ##
 ##  ## ## ##  ##     ##
 ##  ##  ####  ##     ##
 ##  ##   ###  ##     ##
#### ##    ## ####    ##


########   #######  ##     ##
##     ## ##     ## ###   ###
##     ## ##     ## #### ####
##     ## ##     ## ## ### ##
##     ## ##     ## ##     ##
##     ## ##     ## ##     ##
########   #######  ##     ##

 ]#


proc initDOM(win:PgWindow)=


  rootElem = win.rootElem
  #................


  defaultSST["header"] = StyleSheetRef(
    flexGrow: 1,
    flexGrowFrom: 66,
    flexDirection: fdRow,
    flexWrap: true,
    justifyContent: fjcCenter,
    alignContent: facSpaceAround,
    alignItems: faiCenter,
    color: (r:0,g:0,b:0,a:0),
    backGroundColor: (r:255'u8,g:255'u8,b:255'u8,a:255'u8)
  )

  defaultSST["red"] = newStyleSheet()
  defaultSST["red"].backGroundColor = (r:255,g:0,b:0,a:255)

  defaultSST["white"] = newStyleSheet()
  defaultSST["white"].backGroundColor = (r:255'u8,g:255'u8,b:255'u8,a:255'u8)


  var
    header = newDiv(rootElem, 0, "header", "100%", "10%")
    #frame1 = newDiv(rootElem, 0, "frame1", "100", "80")
    frame1 = row(rootElem, 0, "frame1", "100", "80")
    content = flex(frame1, 0, "content", "70", "stretch",["row"])
    #content = newDiv(frame1, 0, "content", "70", "stretch")
    #sidebar = newDiv(frame1, 0, "sidebar", "stretch", "stretch", recalcFlex, ["column"])
    sidebar = flexColumn(frame1, 0, "sidebar", "stretch", "stretch")

    footer = row(rootElem, 0, "footer", "100", "10", ["red"])

  sidebar.addStyle("white")
  #echo sidebar.styles

  header.draw = divDrawTest
  frame1.draw = divDrawTest
  content.draw = divDrawTest
  sidebar.draw = divDrawTest
  footer.draw = divDrawTest

  #frame1.activeStyle = defaultSST["row"]
  #content.activeStyle = defaultSST["row"]

  #[ header.app = win.app
  frame1.app = win.app
  content.app = win.app
  sidebar.app = win.app
  footer.app = win.app ]#

  var textbox1 = header.newTextBox(0,"textbox1","400px","50px")
  textbox1.borderColor(255,128,0,255)
  defaultSST["textbox1"] = newStyleSheet()
  defaultSST["textbox1"].backGroundColor = (r:235,g:235,b:0,a:255)



  var contentbtn_hover_style = newStyleSheet()
  contentbtn_hover_style.backGroundColor = (r:0, g:230, b:191, a:255)
  defaultSST.add("btn:hover", contentbtn_hover_style)

  var contentbtn_focus_style = newStyleSheet()
  contentbtn_focus_style.backGroundColor = (r:255, g:213, b:0, a:255)
  defaultSST.add("btn:focus", contentbtn_focus_style)

  var contentbtn_dragstart_style = newStyleSheet()
  contentbtn_dragstart_style.backGroundColor = (r:191, g:0, b:230, a:255)
  defaultSST.add("btn:dragstart", contentbtn_dragstart_style)

  randomize()
  for i in 0..1:
    if i mod 5 == 0:
      content.layers[0].add(new(BRElem)) # todo template add
    var rw = $(rand(60) + 20) & "px"
    var tmp = content.flex(0, "btn", rw, rw, ["row"])
    tmp.draw = divDrawTest

    tmp.setBackGroundColorr = (rand(128) + 127).uint8,
                        g = (rand(128) + 127).uint8,
                        b = (rand(128) + 127).uint8)
    tmp.inlineStyle.alignContent = facCenter
    tmp.inlineStyle.justifyContent = fjcCenter

    tmp.onFocus = default_onFocus
    tmp.onHover = default_onHover

    tmp.onDragStart = default_onDragStart
    tmp.onDragEnd = default_onDragEnd
    tmp.onDragOver = default_onDragOver

    if tmp.w_value > 50:
      tmp = tmp.flex(0, "btn", "15px", "15px", ["row"])
      tmp.draw = divDrawTest

      tmp.setBackGroundColorr = (rand(128) + 127).uint8,
                          g = (rand(128) + 127).uint8,
                          b = (rand(128) + 127).uint8)

      tmp.onFocus = default_onFocus
      tmp.onHover = default_onHover

      tmp.onDragStart = default_onDragStart
      tmp.onDragEnd = default_onDragEnd
      tmp.onDragOver = default_onDragOver
    
  
  #content.recalcStyle(recursive = true)

  #................................................


  proc sidebtn_hover(this: DivRef){.nosinks.}=
    echo this.name, " HOVERING"
    if this.app.hoverElem != this and
      this.app.focusElem != this :
      echo "CHANGING app.hoverElem ", this.x1,this.y1

      setActiveStyle(this,"hover")

      if this.app.hoverElem != nil:
        this.app.hoverElem.setDefaultStyle()

      this.app.hoverElem = this


  proc sidebtn_focus(this: DivRef){.nosinks.}=
    echo this.name, " FOCUSING"
    if this.app.focusElem != this :
      echo "CHANGING app.focusElem ", this.x1,this.y1

      setDefaultStyle(this)
      this.app.hoverElem = nil
      setActiveStyle(this,"focus")

      if this.app.focusElem != nil:
        this.app.focusElem.setDefaultStyle()

      this.app.focusElem = this




  var
    sidebtn_even_style = newStyleSheet()
    sidebtn_odd_style = newStyleSheet()
    sidebtn_hover_style = newStyleSheet()
    sidebtn_focus_style = newStyleSheet()

  sidebtn_even_style.backGroundColor = (r:153, g:204, b:255, a:255)
  sidebtn_odd_style.backGroundColor = (r:102, g:204, b:255, a:255)
  defaultSST.add("sidebtn:even", sidebtn_even_style)
  defaultSST.add("sidebtn:odd", sidebtn_odd_style)

  sidebtn_hover_style.backGroundColor = (r:0, g:230, b:191, a:255)
  defaultSST.add("sidebtn:hover", sidebtn_hover_style)

  sidebtn_focus_style.backGroundColor = (r:255, g:213, b:0, a:255)
  defaultSST.add("sidebtn:focus", sidebtn_focus_style)

  for i in 0..9:
    var tmp = sidebar.newDiv(0, "sidebtn", "100", "20px")
    tmp.draw = divDrawTest
    tmp.app = win.app
    tmp.onHover = sidebtn_hover
    tmp.onFocus = sidebtn_focus


#[
  var outscreen = newDiv(content, "outscreen", "100px", "800px")
  outscreen.draw = divDrawTest
  outscreen.app = app ]#

  rootElem.recalc(rootElem)
  rootElem.recalcStyle(true)





















##########
# COMMON #
##########

#[
   ###    ########  ########  
  ## ##   ##     ## ##     ## 
 ##   ##  ##     ## ##     ## 
##     ## ########  ########  
######### ##        ##        
##     ## ##        ##        
##     ## ##        ##        
]#

#[ 
#### ##    ## #### ######## 
 ##  ###   ##  ##     ##    
 ##  ####  ##  ##     ##    
 ##  ## ## ##  ##     ##    
 ##  ##  ####  ##     ##    
 ##  ##   ###  ##     ##    
#### ##    ## ####    ##    
 ]#

# Initialization sequence
proc init(app: Pgui): bool =
  # Init SDL
  if sdl.init(sdl.InitVideo) != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL: %s",
                    sdl.getError())
    return false

#[   # Init SDL_Image
  if img.init(img.InitPng) == 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL_Image: %s",
                    img.getError()) ]#

  # Init SDL_TTF
  if ttf.init() != 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL_TTF: %s",
                    ttf.getError())
  var
    font = ttf.openFont(os.getAppDir() & os.DirSep & "fonts" & os.DirSep & "agave_regular_mono_nerd.ttf", 16)
    fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8)) #! REMOVE
  app.fonts = newTable[string, ttf.FontPtr](8)
  app.fonts["default"] = font

  app.font_normal = font #! REMOVE

  let window1 = app.newWindow(
    Title,
    sdl.WindowPosUndefined,
    sdl.WindowPosUndefined,
    ScreenW,
    ScreenH,
    WindowFlags,
    defaultSST
  )

  # Clear screen with draw color

  if app.renderer.clear() != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't clear screen: %s",
                sdl.getError())



  return true


#[ 
######## ##     ## #### ######## 
##        ##   ##   ##     ##    
##         ## ##    ##     ##    
######      ###     ##     ##    
##         ## ##    ##     ##    
##        ##   ##   ##     ##    
######## ##     ## ####    ##    
 ]#

# Shutdown sequence
proc exit(app: Pgui) =
  app.renderer.destroyRenderer()
  app.window.destroyWindow()
  ttf.quit()
  img.quit()
  sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()



#[ 
######## ##     ## ######## ##    ## ########  ######  
##       ##     ## ##       ###   ##    ##    ##    ## 
##       ##     ## ##       ####  ##    ##    ##       
######   ##     ## ######   ## ## ##    ##     ######  
##        ##   ##  ##       ##  ####    ##          ## 
##         ## ##   ##       ##   ###    ##    ##    ## 
########    ###    ######## ##    ##    ##     ######  

 ]#

# Event handling
# Return true on app shutdown request, otherwise return false
proc events(app:Pgui): bool =
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

    elif e.kind == sdl.MouseMotion:
      echo "> X: ",e.motion.x, " Y: ", e.motion.y
      
      
      let eventTarget = getElementAtCoord(
            app.windows[e.motion.windowID].rootElem,
            e.motion.x, e.motion.y)
      if eventTarget != nil:
        app.window = app.windows[e.motion.windowID].window
        app.renderer = app.windows[e.motion.windowID].renderer
        
        if app.mouseSource != nil:
          if app.mouseSource == eventTarget and
            app.mouseSource.activeStyle != "dragstart":#dragbegin
                if eventTarget.onDragStart != nil:
                  eventTarget.onDragStart(eventTarget)
          else:
            if eventTarget.onDragOver != nil:
              eventTarget.onDragOver(eventTarget)

        elif eventTarget.onHover != nil:
          eventTarget.onHover(eventTarget)
        else:
          if app.hoverElem != nil:
            app.hoverElem.setDefaultStyle()
            app.hoverElem = nil


    elif e.kind == sdl.MOUSEBUTTONDOWN:
      let eventTarget = getElementAtCoord(
            app.windows[e.motion.windowID].rootElem,
            e.motion.x, e.motion.y)
      if eventTarget != nil:
        if app.mouseSource != eventTarget:
          app.mouseSource = eventTarget

    
    elif e.kind == sdl.MOUSEBUTTONUP:
      let eventTarget = getElementAtCoord(
            app.windows[e.motion.windowID].rootElem,
            e.motion.x, e.motion.y)
      
      if eventTarget != nil:
        
        app.mouseTarget = eventTarget

        if app.mouseSource == eventTarget:
          if eventTarget.onFocus != nil:
            eventTarget.onFocus(eventTarget)
        else:
          if app.mouseSource != nil:
            if app.mouseSource.onDragEnd != nil:
              app.mouseSource.onDragEnd(app.mouseSource)
        app.mouseSource = nil
        app.mouseTarget = nil

      if app.mouseSource != nil:
        if app.mouseSource.onDragEnd != nil:
          app.mouseSource.onDragEnd(app.mouseSource)
      app.mouseSource = nil
      app.mouseTarget = nil


#[ 
##     ##    ###    #### ##    ## 
###   ###   ## ##    ##  ###   ## 
#### ####  ##   ##   ##  ####  ## 
## ### ## ##     ##  ##  ## ## ## 
##     ## #########  ##  ##  #### 
##     ## ##     ##  ##  ##   ### 
##     ## ##     ## #### ##    ## 
 ]#

########
# MAIN #
########

var
  app = Pgui(window: nil, renderer: nil)
  done = false # Main loop exit condition

import times

var
  t0: float

t0 = epochTime()

if init(app):

  # Load assets


  #[ discard app.renderer.setRenderDrawColor(0, 0, 0, 255)
  var backgroundRect: sdl.Rect
  backgroundRect.x = 0
  backgroundRect.y = 0
  backgroundRect.w = 639
  backgroundRect.h = 479
  discard app.renderer.fillRect(backgroundRect.addr) ]#




  initDOM(app.activeWindow)

  #[ app.renderer.renderPresent()
  testDrawDOM(app, rootElem)
  app.renderer.renderPresent() ]#

  #############################################################################
  proc testThread(elem:ptr DivRef) {.thread.} =
    #[ for i in 0..10:
      sdl.delay(30)
      var sss = ($(rand(65535)))
      `=sink`(rootElem.layers[0][0].name,  sss)
      #system.deepCopy(rootElem.layers[0][0].name, sss)
      rootElem.layers[0][0].redrawFlag = 1
      echo i, ".threadsink: ", rootElem.layers[0][0].name ]#
    #[ while true:
      sdl.delay(3) ]#
    while true:
      {.gcsafe.}:
        removeStyle(rootElem.layers[0][1].layers[0][1], "white", false)
        sdl.delay(100)
        addStyle(rootElem.layers[0][1].layers[0][1], "white", false)
        sdl.delay(100)

  var thread1: system.Thread[ptr DivRef]
  #system.createThread(thread1, testThread, rootElem.layers[0][1].layers[0][1].addr)
  #############################################################################

  let testfilename = "src/piigui/ui/textarea/SampleTextFile_10kb.txt"

  var testBuffer: UTF8Buffer

  testBuffer = loadUTF8TextFile(testfilename)

  echo testBuffer.high + 1

  echo "-------------------"

  dumpBuffer(testBuffer)

  #...................................

  




  #############################################################################
  
  # Main loop
  while not done:

    # Render
    testDrawDOM(app, rootElem)

    # Update renderer
    app.renderer.renderPresent()

    #sdl.delay(2)

    # Event handling
    done = events(app)

  # Free assets
  #free(image1)

# Shutdown
exit(app)

echo os.getAppDir()
