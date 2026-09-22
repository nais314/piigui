import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf,

  os,

  piigui,
  piigui/[types,style],
  piigui/layout/flex,
  tables


const debug = 1


###########################################

#[ 
 ######  ########  ##       
##    ## ##     ## ##       
##       ##     ## ##       
 ######  ##     ## ##       
      ## ##     ## ##       
##    ## ##     ## ##       
 ######  ########  ######## 
 ]#

# ===================================================
#* a default font embedded
# ===================================================

const 
  #RegularMono_FontDataResource = staticRead("../assets/agave_regular_mono_nerd.ttf")
  RegularMono_FontResrc = staticRead("../assets/AgaveNerdFontMono-Regular.ttf")
  BoldMono_FontResrc = staticRead("../assets/AgaveNerdFontMono-Bold.ttf")


# 16pt is a common baseline for UI text at 96 DPI / 1x scaling
proc load_RegularMono_FontResrc*(ptsize: cint, str:string): FontPtr =
  let rw = sdl.rwFromConstMem(RegularMono_FontResrc.cstring, RegularMono_FontResrc.len.cint)
  result = ttf.openFontRW(rw, freesrc = 1, ptsize)

proc load_BoldMono_FontResrc*(ptsize: cint, str:string=""): FontPtr =
  let rw = sdl.rwFromConstMem(BoldMono_FontResrc.cstring, BoldMono_FontResrc.len.cint)
  result = ttf.openFontRW(rw, freesrc = 1, ptsize)

proc load_H2_FontResrc*(ptsize: cint, str:string=""): FontPtr =
  let rw = sdl.rwFromConstMem(BoldMono_FontResrc.cstring, BoldMono_FontResrc.len.cint)
  result = ttf.openFontRW(rw, freesrc = 1, ptsize)

proc load_H1_FontResrc*(ptsize: cint, str:string=""): FontPtr =
  let rw = sdl.rwFromConstMem(RegularMono_FontResrc.cstring, RegularMono_FontResrc.len.cint)
  result = ttf.openFontRW(rw, freesrc = 1, ptsize) 

# ===================================================
#* INITIALIZE SDL
# ===================================================

proc simpleSDLInit*(pgui: Pgui): bool =
  # Init SDL
  if sdl.init(sdl.INIT_EVERYTHING) == SdlError:
    #TODO: LOG
    echo "Can't initialize SDL: ", sdl.getError()
    return false

  #[   # Init SDL_Image
  if img.init(img.InitPng) == 0:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't initialize SDL_Image: %s",
                    img.getError()) ]#
  if img.init(img.IMG_INIT_PNG or img.IMG_INIT_JPG) == 0:
    return false

  # ---------------------------------------------------
  #* Init SDL_TTF
  # ---------------------------------------------------
  if ttf.ttfInit() == SdlError: 
    echo "Can't initialize TTF: ", sdl.getError()
    return false

  #[var
    font = ttf.openFont(os.getAppDir() & os.DirSep & "assets" & os.DirSep & "agave_regular_mono_nerd.ttf", 16) ]#

  var font = load_RegularMono_FontResrc(16, "") # 16pt is a common baseline for UI text at 96 DPI / 1x scaling

  when debug > 0:
    # TEST WIDTH
    var surface = font.renderUtf8Shaded(
                  "W",
                  sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8)),
                  sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))
                  )
    echo "font \"W\" width: ", surface.w, "px"
    surface.freeSurface()
    #sdl.delay(1000) # debug

  #:
  #[ pgui.fonts = newTable[string, FontObject](8)
  pgui.fonts["default"] = new FontObject
  pgui.fonts["default"].fontPtr = font
  pgui.fonts["default"].ptsize = 16
  pgui.fonts["default"].ttfPath = "" ]#
  for i in 1..4: pgui.fonts.add(new FontObject)

  pgui.fonts[0].loader = load_RegularMono_FontResrc
  pgui.fonts[1].loader = load_BoldMono_FontResrc
  pgui.fonts[2].loader = load_H2_FontResrc
  pgui.fonts[3].loader = load_H1_FontResrc

  pgui.fonts[0].fontPtr = font
  pgui.fonts[0].ptsize = 16
  pgui.fonts[0].ttfPath = ""

  font = load_BoldMono_FontResrc(16,"")
  pgui.fonts[1].fontPtr = font
  pgui.fonts[1].ptsize = 16
  pgui.fonts[1].ttfPath = ""

  font = load_H2_FontResrc(20,"")
  pgui.fonts[2].fontPtr = font
  pgui.fonts[2].ptsize = 16
  pgui.fonts[2].ttfPath = ""

  font = load_H1_FontResrc(24,"")
  pgui.fonts[3].fontPtr = font
  pgui.fonts[3].ptsize = 16
  pgui.fonts[3].ttfPath = ""



  # TODO may initDOM could create window if needd??
  #[ let window1 = newSimpleWindow(
    Title,
    sdl.SDL_WINDOWPOS_UNDEFINED,
    sdl.SDL_WINDOWPOS_UNDEFINED,
    ScreenW,
    ScreenH,
    WindowFlags,
    rootSSRT
  ) ]#

  # Clear screen with draw color

  #[ if pgui.renderer.clear() != 0:
    sdl.logWarn(sdl.LogCategoryVideo,
                "Can't clear screen: %s",
                sdl.getError()) ]#



  return true




# Shutdown sequence
proc exit*(pgui: Pgui) =
  pgui.destroyFonts()
  pgui.renderer.destroyRenderer()
  pgui.window.destroyWindow()
  
  ttf.ttfQuit()
  img.quit()
  #sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()








#[ 
##      ## #### ##    ## ########   #######  ##      ## 
##  ##  ##  ##  ###   ## ##     ## ##     ## ##  ##  ## 
##  ##  ##  ##  ####  ## ##     ## ##     ## ##  ##  ## 
##  ##  ##  ##  ## ## ## ##     ## ##     ## ##  ##  ## 
##  ##  ##  ##  ##  #### ##     ## ##     ## ##  ##  ## 
##  ##  ##  ##  ##   ### ##     ## ##     ## ##  ##  ## 
 ###  ###  #### ##    ## ########   #######   ###  ###  
 ]#

proc newSimpleWindow*(
                pgui:Pgui,
                title: cstring,
                x: cint = sdl.SDL_WINDOWPOS_UNDEFINED,
                y: cint = sdl.SDL_WINDOWPOS_UNDEFINED,
                w: cint = DefaultWindowW, h: cint = DefaultWindowH,
                flags: cuint = DefaultWindowFlags,
                styleSheetTbl: StyleSheetRef_Tbl,
                recalcFun: proc(this:DivRef, layer:Layer):tuple[w,h:int] = recalcFlex
                ): PgWindow =
  ## creates a PgWindow for a Pgui
  ## creates rootElem for PgWindow
  ## 
  

  let newWin = sdl.createWindow(
        title, x,y, w,h, sdl.SDL_WINDOW_SHOWN)
  if newWin == nil:
    return nil

  let newWinId = newWin.getID()

  #........................

  let renderer = sdl.createRenderer(
        newWin,
        -1,
        sdl.RendererAccelerated or sdl.RendererPresentVsync or sdl.RendererTargetTexture)

  if renderer == nil:
    return nil

  discard sdl.setDrawBlendMode(renderer, sdl.BLENDMODE_BLEND)
  
  #........................


  if renderer.clear() != SdlSuccess: return nil

  renderer.present()

  #.........................
  #.........................


  result = PgWindow(
    pgui: pgui,
    window: newWin,
    renderer: renderer,
    rootElem: nil,
    styleSheet: styleSheetTbl
  )

  pgui.windows[newWinId] = result

  pgui.windows[newWinId].rootElem = newRoot(
                                      win = pgui.windows[newWinId],
                                      recalcFun = recalcFun,
                                      name = "root_" & $newWinId
                                      )

  #........................
  pgui.currentWindowId = newWinId

  pgui.window = newWin
  #pgui.renderer = renderer

#.......................................

 
#[ 
 ######   ##     ## #### 
##    ##  ##     ##  ##  
##        ##     ##  ##  
##   #### ##     ##  ##  
##    ##  ##     ##  ##  
##    ##  ##     ##  ##  
 ######    #######  #### 
 ]#

proc newSimpleGui*(
  name: string = "Title",
  recalcFun: proc(this:DivRef, layer:Layer):tuple[w,h:int] = recalcFlex,
  windowW: int = DefaultWindowW,
  windowH: int = DefaultWindowH
  ): Pgui =

    result = new Pgui

    if not simpleSDLInit(result):
      quit("proc newSimpleGui: cannot initialize SDL")



    if newSimpleWindow(
        result,
        name,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        windowW,
        windowH,
        DefaultWindowFlags,
        rootSSRT,
        recalcFun
        ) == nil: quit("cannot create window" & $getError(), QuitFailure)

    
    setDPIMultiplier(result.activeWindow)
    #[ let theNewWindow: PgWindow = result.activeWindow
    let displayIndex = getDisplayIndex(result.activeWindow.window)
    if getDisplayDPI(displayIndex, addr theNewWindow.ddpi, addr theNewWindow.hdpi, addr theNewWindow.vdpi) == SdlSuccess:
      when debug > 0:
        debugEcho "Diagonal DPI: ", theNewWindow.ddpi
        debugEcho "Horizontal DPI: ", theNewWindow.hdpi
        debugEcho "Vertical DPI: ", theNewWindow.vdpi
      discard
    else:
      quit("Failed to get DPI: " & $getError(), QuitFailure) ]#


proc closeGui*(pgui: Pgui) =
  pgui.guiTimedEvents.setLen(0)
  pgui.renderer.destroyRenderer()
  pgui.window.destroyWindow()
  ttf.ttfQuit()
  img.quit()
  #sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()


#[ 
template rootElem*(pgui:Pgui):DivRef=
  pgui.activeWindow.rootElem

template elems*(this:DivRef):seq[DivRef]=
  this.layers[0].elems
 ]#
#[ 
proc addEventListener*(
      elems:seq[DivRef],
      evtname:string,
      fun:proc(source:DivRef):void)=
  var exists = false
  var newListener: Listener
  for controll in elems:
    for i in 0..controll.listeners.high:
      if controll.listeners[i].name == evtname:
        controll.listeners[i].actions.add(fun)
        exists = true
    if not exists:
      newListener.name = evtname
      newListener.actions = @[]
      newListener.actions.add(fun)
      controll.listeners.add(newListener)


proc removeEventListener*(
        elems:seq[DivRef],
        evtname:string,
        fun:proc(source:DivRef):void)=
  for control in elems:
    for i in countdown(control.listeners.high, 0):
      if control.listeners[i].name == evtname:
        for j in countdown(control.listeners[i].actions.high, 0):
          if control.listeners[i].actions[j] == fun:
            control.listeners[i].actions.del(j)
        if control.listeners[i].actions.len == 0:
          control.listeners.del(i)


proc trigger*(elems:seq[DivRef], evtname:string ):bool=
  result = false
  for controll in elems:
    for i in 0..controll.listeners.high:
      if controll.listeners[i].name == evtname:
        for j in 0..controll.listeners[i].actions.high:
          controll.listeners[i].actions[j](controll)
        result = true ]#
