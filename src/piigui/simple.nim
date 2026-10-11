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


# ===================================================
#* TEXTURE COLOR MOD CAPABILITY PROBE
# ===================================================

proc probeColorModSupport*(renderer: RendererPtr): SdlSupportsColorModKind =
  ## One-time capability test run when a renderer appears. Tinted widgets blit
  ## static textures, so probe with the same surface->texture path they use.
  ## SDL documents setTextureColorMod returning false when unsupported.
  ## sscmUnknown is returned while no probe texture could be created, so the
  ## caller can retry with the next renderer.
  let surface = sdl.createSurface(1, 1, sdl.PIXELFORMAT_RGBA8888)
  if surface == nil:
    return sscmUnknown
  defer: sdl.destroySurface(surface)

  let texture = sdl.createTextureFromSurface(renderer, surface)
  if texture == nil:
    return sscmUnknown
  defer: sdl.destroyTexture(texture)

  #* non-white: a real modulation; white may be short-circuited as a no-op
  if texture.setTextureColorMod(128'u8, 128'u8, 128'u8):
    result = sscmSupported
  else:
    result = sscmUnsupported


# ===================================================
#* GPU CACHE TEARDOWN
# ===================================================
#? Currently UNUSED: `=destroy`/`dispose` already release element caches, and
#? closeGui drops the tree before the renderer, so ORC collects them. This is a
#? deterministic, GC-independent alternative kept for future use.
#? Safe to comment this whole section out if not needed.
proc freeGpuCaches*(this: DivRef) #!FWD
proc freeGpuCaches*(sb: ScrollBar) #!FWD

proc freeGpuCaches*(this: DivRef) =
  ## Recursively frees cached GPU textures for `this` and its subtree,
  ## including standalone scrollbar parts, without relying on the GC.
  if this == nil:
    return
  for layer in this.layers:
    for child in layer.elems:
      freeGpuCaches(child)
  if this.scrollbar != nil:
    freeGpuCaches(this.scrollbar)
  #! virtual widget cleanup (e.g. MonoTextBox extra textures)
  this[].dispose()
  if this.textureCache != nil:
    sdl.destroyTexture(this.textureCache)
    this.textureCache = nil

proc freeGpuCaches*(sb: ScrollBar) =
  ## Scrollbar parts are not in any layer, so they need their own walk.
  if sb == nil:
    return
  freeGpuCaches(sb.vTrack)
  freeGpuCaches(sb.vSlider)
  freeGpuCaches(sb.vUp)
  freeGpuCaches(sb.vDown)
  freeGpuCaches(sb.hTrack)
  freeGpuCaches(sb.hSlider)
  freeGpuCaches(sb.hLeft)
  freeGpuCaches(sb.hRight)


# Shutdown sequence
proc closeGui*(pgui: Pgui) #!FWD

proc exit*(pgui: Pgui) =
  ## Full teardown; delegates to closeGui so both paths free the element tree
  ## before the renderer.
  closeGui(pgui)








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

  #! renderer capability, probed once per pgui; tinted widgets consult it later
  if pgui.state.SupportsColorMod == sscmUnknown:
    pgui.state.SupportsColorMod = probeColorModSupport(renderer)

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


proc closeGui*(pgui: Pgui) =
  pgui.guiTimedEvents.setLen(0)
  #! Release the element tree BEFORE the renderer is destroyed. Dropping the
  #! owning refs leaves the parent<->child cycles unreachable, and
  #! GC_fullCollect runs their =destroy/dispose hooks, freeing every element
  #! GPU texture while the renderer is still valid.
  for _, win in pgui.windows:
    win.rootElem = nil
  pgui.focusElem = nil
  pgui.hoverElem = nil
  pgui.mouseSource = nil
  GC_fullCollect()
  sdl.destroyRenderer(pgui.renderer)
  sdl.destroyWindow(pgui.window)
  closeAllFonts(pgui)
  ttf.quit()
  #sdl.logInfo(sdl.LogCategoryApplication, "SDL shutdown completed")
  sdl.quit()


#[ 
template rootElem*(pgui:Pgui):DivRef=
  pgui.activeWindow.rootElem

template elems*(this:DivRef):seq[DivRef]=
  this.layers[0].elems
 ]#
