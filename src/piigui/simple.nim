import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases

import
  piigui,
  piigui/[types,style],
  piigui/layout/flex,
  tables

import
  os


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
  let io = sdl.ioFromConstMem(RegularMono_FontResrc.cstring, RegularMono_FontResrc.len.csize_t)
  result = ttf.openFontIO(io, closeio = true, ptsize.cfloat)

proc load_BoldMono_FontResrc*(ptsize: cint, str:string=""): FontPtr =
  let io = sdl.ioFromConstMem(BoldMono_FontResrc.cstring, BoldMono_FontResrc.len.csize_t)
  result = ttf.openFontIO(io, closeio = true, ptsize.cfloat)

proc load_H2_FontResrc*(ptsize: cint, str:string=""): FontPtr =
  let io = sdl.ioFromConstMem(BoldMono_FontResrc.cstring, BoldMono_FontResrc.len.csize_t)
  result = ttf.openFontIO(io, closeio = true, ptsize.cfloat)

proc load_H1_FontResrc*(ptsize: cint, str:string=""): FontPtr =
  let io = sdl.ioFromConstMem(RegularMono_FontResrc.cstring, RegularMono_FontResrc.len.csize_t)
  result = ttf.openFontIO(io, closeio = true, ptsize.cfloat) 

# ===================================================
#* INITIALIZE SDL
# ===================================================

proc simpleSDLInit*(pgui: Pgui): bool =
  # Init SDL
  if not sdl.init(sdl.INIT_VIDEO):
    #TODO: LOG
    echo "Can't initialize SDL: ", sdl.getError()
    return false

  # ---------------------------------------------------
  #* Init SDL_TTF
  # ---------------------------------------------------
  if not ttf.init(): 
    echo "Can't initialize TTF: ", sdl.getError()
    return false

  #[var
    font = ttf.openFont(os.getAppDir() & os.DirSep & "assets" & os.DirSep & "agave_regular_mono_nerd.ttf", 16) ]#

  var font = load_RegularMono_FontResrc(16, "") # 16pt is a common baseline for UI text at 96 DPI / 1x scaling

  when debug > 0:
    # TEST WIDTH
    var surface = font.renderTextShaded(
                  "W",
                  0,
                  sdl.Color(r:0'u8,g:0'u8,b:0'u8,a:255'u8),
                  sdl.Color(r:0'u8,g:0'u8,b:0'u8,a:0'u8)
                  )
    if surface != nil:
      echo "font \"W\" width: ", surface.w, "px"
      sdl.destroySurface(surface)
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
  sdl.destroyRenderer(pgui.renderer)
  sdl.destroyWindow(pgui.window)
  
  ttf.quit()
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
                x: cint = sdl.WINDOWPOS_UNDEFINED.cint,
                y: cint = sdl.WINDOWPOS_UNDEFINED.cint,
                w: cint = DefaultWindowW, h: cint = DefaultWindowH,
                flags: sdl.WindowFlags = DefaultWindowFlags,
                styleSheetTbl: StyleSheetRef_Tbl,
                recalcFun: proc(this:DivRef, layer:Layer):tuple[w,h:int] = recalcFlex
                ): PgWindow =
  ## creates a PgWindow for a Pgui
  ## creates rootElem for PgWindow
  ## 
  

  let newSdlWindow = sdl.createWindow(title, w, h, flags)
  if newSdlWindow == nil:
    return nil

  if x != sdl.WINDOWPOS_UNDEFINED.cint or y != sdl.WINDOWPOS_UNDEFINED.cint:
    discard sdl.setWindowPosition(newSdlWindow, x, y)

  let newSdlWindowId = newSdlWindow.getID()

  #........................

  let renderer = sdl.createRenderer(newSdlWindow, nil)

  if renderer == nil:
    return nil

  #discard sdl.setRenderDrawBlendMode(renderer, sdl.BLENDMODE_BLEND)
  discard renderer.setRenderDrawBlendMode(sdl.BLENDMODE_BLEND)

  #........................


  if not renderer.clear(): return nil

  discard renderer.present()

  #.........................
  #.........................


  result = PgWindow(
    pgui: pgui,
    window: newSdlWindow,
    renderer: renderer,
    rootElem: nil,
    styleSheet: styleSheetTbl
  )

  pgui.windows[newSdlWindowId] = result

  pgui.windows[newSdlWindowId].rootElem = newRoot(
                                      win = pgui.windows[newSdlWindowId],
                                      recalcFun = recalcFun,
                                      name = "root_" & $newSdlWindowId
                                      )

  #........................
  pgui.currentWindowId = newSdlWindowId

  pgui.window = newSdlWindow
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



    let newWindow = newSimpleWindow(
        result,
        name,
        sdl.WINDOWPOS_UNDEFINED.cint,
        sdl.WINDOWPOS_UNDEFINED.cint,
        windowW,
        windowH,
        DefaultWindowFlags,
        rootSSRT,
        recalcFun
        ) 
        
    if newWindow == nil: quit("cannot create window" & $sdl.getError(), QuitFailure)

    
    setDPIMultiplier(newWindow)
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
  sdl.destroyRenderer(pgui.renderer)
  sdl.destroyWindow(pgui.window)
  for i in 0..pgui.fonts.high:
    ttf.closeFont(pgui.fonts[i].fontPtr)
  ttf.quit()
  #sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()


#[ 
template rootElem*(pgui:Pgui):DivRef=
  pgui.activeWindow.rootElem

template elems*(this:DivRef):seq[DivRef]=
  this.layers[0].elems
 ]#
