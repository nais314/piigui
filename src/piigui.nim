# TODO: flex.nim column distribution, flex.nim refractor

import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import tables
import os
#import times
import random
import locks

###########################################


import piigui/[types,style]
export types

import piigui/layout/flex
import piigui/layout/vhbox


###########################################

var SCROLL_SPEED* = 5

const debug = 0

###########################################

converter cintToInt*(x: cint): int = x.int
converter intToCint*(x: int): cint = x.cint

converter SDL_ReturnToBool*(x: SDL_Return): bool = 
  if x == SDLSuccess:
    result = true
  else:
    result = false
converter BoolToSDL_Return*(x: bool): SDL_Return = 
  if x: 
    result = SDLSuccess
  else:
    result = SdlError
###########################################


var GlobalIDCounter: uint = 0
type IDCounterOverflowError* = object of ValueError
proc getNextGlobalID*(): uint =
  ## Safely increments the counter by 1 and returns the new value.  if GlobalIDCounter == uint.high:
  if GlobalIDCounter == uint.high:
    # Strategy 1: Exception, when the counter is full
    raise newException(IDCounterOverflowError, "A globalIDCounter túlcsordult (uint.high)!")
      
    # Strategy 2 (Alternative): Reset to 1,
    #GlobalIDCounter = 1

  inc GlobalIDCounter
  return GlobalIDCounter


###########################################
# TODO: scale-up: multiply font sizes, pixel sizes 
# TODO:   according to a design time window size or user value

template activeWindow*(pgui): PgWindow =
  pgui.windows[pgui.currentWindowId]

template renderer*(pgui: Pgui): sdl.RendererPtr =
  ## template to ease typing and
  ## make src code readable
  pgui.activeWindow.renderer



#[ 
##          ###    ##    ## ######## ########   ######  
##         ## ##    ##  ##  ##       ##     ## ##    ## 
##        ##   ##    ####   ##       ##     ## ##       
##       ##     ##    ##    ######   ########   ######  
##       #########    ##    ##       ##   ##         ## 
##       ##     ##    ##    ##       ##    ##  ##    ## 
######## ##     ##    ##    ######## ##     ##  ######  
]#
#TODO

#[ proc newLayer*(this:DivRef,
              recalcFun: proc(this:DivRef): tuple[w,h:int] = recalcFlex):int=
  this.layers.add(new Layer)
  this.layers[this.layers.high].elems = @[]
  this.layers[this.layers.high].recalc = recalcFun ]#

proc newLayer*(this:DivRef,
              recalcFun: proc(this:DivRef, layer:Layer): tuple[w,h:int] = recalcFlex):Layer=
  result = new Layer
  this.layers.add(result)
  this.layers[this.layers.high].elems = @[]
  this.layers[this.layers.high].recalc = recalcFun


#[ 
######## ##     ## ######## ##    ## ########  ######  
##       ##     ## ##       ###   ##    ##    ##    ## 
##       ##     ## ##       ####  ##    ##    ##       
######   ##     ## ######   ## ## ##    ##     ######  
##        ##   ##  ##       ##  ####    ##          ## 
##         ## ##   ##       ##   ###    ##    ##    ## 
########    ###    ######## ##    ##    ##     ######  
]#

proc default_onHover*(this:DivRef){.nosinks.}=
  const debug = 1
  if this.pgui.mouseSource == nil: # else dragover

    # dont touch if already hovered or focused
    if this.pgui.hoverElem != this and
    this.pgui.focusElem != this :

      setActiveStyle(this,"hover")
      when debug > 0: echo "hovering ", this.name
      # restore prev hover elems style
      # unless its focused - dont remove focus style!
      if this.pgui.hoverElem != nil and
      this.pgui.focusElem != this.pgui.hoverElem :
        when debug > 0: echo "hovering ", this.name, " previously: ",this.pgui.hoverElem.name
        this.pgui.hoverElem.setDefaultStyle()
    
    # for hover events to work, like scroll:
    if this.pgui.hoverElem != this:
      this.pgui.hoverElem = this

proc parent_onHover*(this:DivRef){.nosinks.}=
  ## use this for "click-through"
  this.parent.onHover(this.parent)
#.........


proc default_onFocus*(this:DivRef){.nosinks.}=
  when debug > 1: echo this.name, " FOCUSING"

  if this.pgui.focusElem != this :

    #setDefaultStyle(this) # remove :hover
    this.pgui.hoverElem = nil
    setActiveStyle(this,"focus")
    
    if this.pgui.focusElem != nil: # prev focused elem blur
      this.pgui.focusElem.setDefaultStyle()
      if this.pgui.focusElem.onBlur != nil:
        this.pgui.focusElem.onBlur(this.pgui.focusElem)
    
    this.pgui.focusElem = this

proc parent_onFocus*(this:DivRef){.nosinks.}=
  this.parent.onFocus(this.parent)
#..........


proc default_onDragStart*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  echo " * DRAG START * DRAG START * DRAG START * "
  #setDefaultStyle(this) # hover
  this.setActiveStyle("dragstart")
  this.pgui.hoverElem = nil

proc parent_onDragStart*(this:DivRef){.nosinks.}=
  this.parent.onDragStart(this.parent)
#..........


proc default_onDragEnd*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  setDefaultStyle(this)
  #echo " * DRAGEND * DRAGEND * DRAGEND * "
  if this.pgui.hoverElem != nil:
    this.pgui.hoverElem.setDefaultStyle()
    this.pgui.hoverElem = nil

proc parent_onDragEnd*(this:DivRef){.nosinks.}=
  this.parent.onDragEnd(this.parent)
#...........


proc default_onDragOver*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  if this.pgui.hoverElem != this:
    if this.pgui.mouseSource != this:
      #setActiveStyle(this,"dragover")
      setActiveStyle(this,"hover")
      if this.pgui.hoverElem != nil:
        this.pgui.hoverElem.setDefaultStyle()
      this.pgui.hoverElem = this

  if this.pgui.mouseSource == this and
    this.pgui.hoverElem != this:
      this.pgui.hoverElem.setDefaultStyle()
      this.pgui.hoverElem = nil

proc parent_onDragOver*(this:DivRef){.nosinks.}=
  this.parent.onDragOver(this.parent)

#..................................................


#[ 
      ########  #### ##     ## 
      ##     ##  ##  ##     ## 
      ##     ##  ##  ##     ## 
      ##     ##  ##  ##     ## 
      ##     ##  ##   ##   ##  
      ##     ##  ##    ## ##   
      ########  ####    ###    
 ]#




proc drawDivRef*(this:DivRef)=
  const debug = 0

  when debug > 1: echo this.name

  when debug > 2:
    if this.name == "btn":
      echo "divDrawTest"
      echo this.name
      echo "w: ",this.w, " h: ", this.h
      echo "x1: ",this.x1, " y1: ", this.y1
      echo "___________"

  #.............................
  # clipRect hide overflow
  var clipRect: sdl.Rect
  if this.parent == nil:  #padding# 
    clipRect.x = this.x1.cint
    clipRect.y = this.y1.cint
    clipRect.w = this.w.cint
    clipRect.h = this.h.cint
  else:
    clipRect.x = this.parent.x1.cint
    clipRect.y = this.parent.y1.cint
    clipRect.w = this.parent.w.cint #(this.x2 - this.x1 + 1)
    clipRect.h = this.parent.h.cint #(this.y2 - this.y1 + 1)
  discard sdl.setClipRect(this.pgui.renderer, clipRect.addr)
  #.............................

  # backgroundRect is the rect we can paint
  # after
  # sdl.setRenderTarget(this.pgui.renderer, this.textureCache) 
  var backgroundRect: sdl.Rect
  backgroundRect.x = 0.cint
  backgroundRect.y = 0.cint
  backgroundRect.w = this.w.cint
  backgroundRect.h = this.h.cint

  #.............................

  # the area of this elem on the screen 
  var thisRect: sdl.Rect
  thisRect.x = this.x1.cint
  thisRect.y = this.y1.cint
  thisRect.w = this.w.cint
  thisRect.h = this.h.cint

  #.............................
  # we need to redraw, even if not changed
  if this.redrawFlag == 0 and this.textureCache != nil:
      discard this.pgui.renderer.copy(
          this.textureCache,
          nil, thisRect.addr)


  else:
    # if need to redraw, check if cache setted up
    # todo setup cache at recalc
    if this.textureCache == nil:
      this.textureCache = sdl.createTexture(
        this.pgui.renderer,
        sdl.SDL_PIXELFORMAT_UNKNOWN,#PIXELFORMAT_RGBA8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        this.w.cint, this.h.cint)
        
      discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

    # the elems. texture is the render target x=0 y=0!
    discard sdl.setRenderTarget(this.pgui.renderer, this.textureCache)
    this.pgui.renderer.setDrawColor(clearColor)
    #discard this.pgui.renderer.clear()
    #.............................

    if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
      this.pgui.renderer.setDrawColor(
        this.styleCache[this.activeStyle].backGroundColor)
    when debug > 0:
        if this.styleCache[this.activeStyle].backGroundColor == EmptyColor:
          randomize()
          var
            r: uint8 = (rand(127) + 128).uint8
            g: uint8 = (rand(127) + 128).uint8
            b: uint8 = (rand(127) + 128).uint8
            a: uint8 = 255
          discard this.pgui.renderer.setDrawColor(r, g, b, a)


    # draw the elem
    discard this.pgui.renderer.fillRect(addr(backgroundRect))

    #=====================================

    when debug > 0:
        # render text --- render text --- render text ---
        var
          fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:128'u8))
          fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))

        discard this.pgui.renderer.getRenderDrawColor(
                      fontBgColor.r.addr,
                      fontBgColor.g.addr,
                      fontBgColor.b.addr,
                      fontBgColor.a.addr)
        var surface = this.pgui.fonts["default"].renderUtf8Shaded(
                      this.name,
                      fontColor,
                      fontBgColor)
        
        if surface != nil:
            var srect : sdl.Rect = (
                                x: 0,
                                y: 0,
                                w: surface.w,
                                h: surface.h)

            var texture = sdl.createTextureFromSurface(this.pgui.renderer, surface)

            discard this.pgui.renderer.copy(texture,
                nil, srect.addr)

            sdl.freeSurface(surface)
            destroyTexture(texture) #?


    #=====================================
    discard sdl.setRenderTarget(this.pgui.renderer, nil)
    discard this.pgui.renderer.copy(
        this.textureCache,
        nil, thisRect.addr)


  # reset clipping
  discard sdl.setClipRect(this.pgui.renderer, nil)

  this.redrawFlag = 0

#........................................................


#[ 
                      
##    ## ######## ##      ## 
###   ## ##       ##  ##  ## 
####  ## ##       ##  ##  ## 
## ## ## ######   ##  ##  ## 
##  #### ##       ##  ##  ## 
##   ### ##       ##  ##  ## 
##    ## ########  ###  ###  

########  #### ##     ## 
##     ##  ##  ##     ## 
##     ##  ##  ##     ## 
##     ##  ##  ##     ## 
##     ##  ##   ##   ##  
##     ##  ##    ## ##   
########  ####    ###    
                      
 ]#


# todo move ui_div
proc newDiv*(parent: DivRef,
             layer:int = 0,
             name: string,
             group:string = "",
             width: string="auto",
             height: string="auto",
             recalcFun: proc(this:DivRef, layer:Layer): tuple[w,h:int] = recalcFlex,
             styles: openArray[string] = []
             ): DivRef =
  const debug = 0b0

  result = new DivRef

  initLock(result.lock)

  result.typeName = "Div"
  result.iD = getNextGlobalID()

  result.draw = drawDivRef

  result.parent = parent
  if parent != nil:
    result.pgui = parent.pgui
    result.window = parent.window
    result.nthChild = parent.layers[layer].elems.len


  result.layers = @[]
  result.layer = layer
  discard result.newLayer(recalcFun)

  result.name = name
  result.group = group
  # todo move to back if style not adds it
  (result.w_unit, result.w_value) = parseSizeStr(width)
  (result.h_unit, result.h_value) = parseSizeStr(height)
  #result.recalc = recalcFun
  result.redrawFlag = 1
  result.isRecalculated = false


  result.onHover = piigui.default_onHover
  result.onFocus = piigui.default_onFocus

  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)
  
  for style in styles:
    result.styles.add((style, defaultSST[style]))

  result.activeStyle = "default"
  recalcStyle(result) #* the default RootStyle applied here


  when debug > 2:
    echo "result.activeStyle.flexGrow", result.activeStyle.flexGrow
    echo "result.activeStyle.flexGrowFrom", result.activeStyle.flexGrowFrom
    echo "result.activeStyle.flexDirection", result.activeStyle.flexDirection
    echo "result.activeStyle.flexWrap", result.activeStyle.flexWrap
    echo "result.activeStyle.justifyContent", result.activeStyle.justifyContent
    echo "result.activeStyle.alignContent", result.activeStyle.alignContent
    echo "result.activeStyle.alignItems", result.activeStyle.alignItems



  if parent != nil : parent.layers[layer].elems.add(result)
  when debug > 0:
    echo "newDiv result.w_value ", name, ": ", (result.w_unit, result.w_value)
    echo "newDiv result.h_value ", name, ": ", (result.h_unit, result.h_value)
    echo ""

#----------------------------------------------------
#[ 
##          ###    ##    ##  #######  ##     ## ######## 
##         ## ##    ##  ##  ##     ## ##     ##    ##    
##        ##   ##    ####   ##     ## ##     ##    ##    
##       ##     ##    ##    ##     ## ##     ##    ##    
##       #########    ##    ##     ## ##     ##    ##    
##       ##     ##    ##    ##     ## ##     ##    ##    
######## ##     ##    ##     #######   #######     ##    
 ]#
proc row*(parent: DivRef,
             layer:int = 0,
             name: string = "",
             group: string = "",
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    newDiv(parent,
          layer,
          name,
          group,
          width,
          height,
          recalcFun = recalcH,
          styles
        )


proc column*(parent: DivRef,
             layer:int = 0,
             name: string = "",
             group: string = "",
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    newDiv(parent,
          layer,
          name,
          group,
          width,
          height,
          recalcFun = recalcV,
          styles
        )


#--------------------------------------------

proc flex*(parent: DivRef,
             layer:int = 0,
             name: string = "",
             group: string = "",
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    newDiv(parent,
          layer,
          name,
          group,
          width,
          height,
          recalcFun = recalcFlex,
          styles
        )
# Alias forwarding template
template flexBox*(args: varargs[untyped]): untyped =
  flex(args)
template panel*(args: varargs[untyped]): untyped =
  flex(args)


proc flexColumn*(parent: DivRef,
             layer:int = 0,
             name: string = "",
             group: string = "",
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    var stylesResult = @["column"] & @styles
    result = newDiv(parent,
          layer,
          name,
          group,
          width,
          height,
          recalcFun = recalcFlex,
          stylesResult
        )
# Alias forwarding template
template vBox*(args: varargs[untyped]): untyped =
  flexColumn(args)


proc flexRow*(parent: DivRef,
             layer: int = 0,
             name: string = "",
             group: string = "",
             width: string = "auto",
             height: string = "auto",
             styles: openArray[string] = []
             ): DivRef =
  var stylesResult = @["row"] & @styles
  newDiv(parent,
        layer,
        name,
        group,
        width,
        height,
        recalcFun = recalcFlex,
        stylesResult
  )
# Alias forwarding template
template hBox*(args: varargs[untyped]): untyped =
  flexRow(args)
#--------------------------------------------




#[ 
########   #######   #######  ######## 
##     ## ##     ## ##     ##    ##    
##     ## ##     ## ##     ##    ##    
########  ##     ## ##     ##    ##    
##   ##   ##     ## ##     ##    ##    
##    ##  ##     ## ##     ##    ##    
##     ##  #######   #######     ##    
 ]#

proc newRoot*(
    win:PgWindow,
    recalcFun: proc(this:DivRef, layer:Layer):tuple[w,h:int] = recalcFlex,
    styles:openArray[string] = ["rootStyle"]
    ): RootElem =
  ## the root Div. its dimensions are the window dimensions,
  ## it cannot be calculated like the rest of the Divs,
  ## wich are using parents dimensions.
  ## window events should take care!
  result = new RootElem

  initLock(result.lock)

  result.parent = nil
  result.pgui = win.pgui
  result.window = win

  result.layers = @[]
  result.layer = -1 # -1 marks the root: it has no parent
  discard result.newLayer(recalcFun)
  result.name = "root"
  result.iD = getNextGlobalID()

  result.w_unit = muPx
  result.h_unit = muPx
  var cw,ch:cint
  sdl.getSize(win.window, cw, ch)
  #echo "win: ", cw,"x",ch
  result.w_value = cw
  result.h_value = ch
  result.w = cw
  result.h = ch
  result.x1 = 0
  result.x2 = cw - 1
  result.y1 = 0
  result.y2 = ch - 1

  result.draw = drawDivRef
  result.redrawFlag = 1
  result.isRecalculated = false

  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)
  for style in styles:
    result.styles.add((style, defaultSST[style]))
  result.activeStyle = "default"
  recalcStyle(result)



###########################################



#[ 
##    ## ######## ##      ## 
###   ## ##       ##  ##  ## 
####  ## ##       ##  ##  ## 
## ## ## ######   ##  ##  ## 
##  #### ##       ##  ##  ## 
##   ### ##       ##  ##  ## 
##    ## ########  ###  ###  


##      ## #### ##    ##     
##  ##  ##  ##  ###   ##     
##  ##  ##  ##  ####  ##     
##  ##  ##  ##  ## ## ##     
##  ##  ##  ##  ##  ####     
##  ##  ##  ##  ##   ###     
 ###  ###  #### ##    ##     
 ]#



proc newWindow*(pgui:Pgui,
                title: cstring,
                x: cint = sdl.SDL_WINDOWPOS_UNDEFINED,
                y: cint = sdl.SDL_WINDOWPOS_UNDEFINED,
                w: cint = 640, h: cint = 480,
                flags: uint32 = DefaultWindowFlags,
                styleSheetTbl: StyleSheetRef_Tbl
                ): PgWindow =
  ## creates a PgWindow for an Pgui
  ## creates rootElem for PgWindow
  ## 
  
  let newWin = sdl.createWindow(
        title, x,y, w,h, flags)
  if newWin == nil:
    #[ sdl.logCritical(sdl.LogCategoryError,
                  "Can't create window: %s",
                  sdl.getError()) ]#
    return nil
  #........................
  let newWinId = newWin.getID()

  let renderer = sdl.createRenderer(
        newWin,
        -1,
        sdl.RendererAccelerated or sdl.RendererPresentVsync or sdl.RendererTargetTexture)
  if renderer == nil:
    #[ sdl.logCritical(sdl.LogCategoryError,
                    "Can't create renderer: %s",
                    sdl.getError()) ]#
    return nil
  #........................


  result = PgWindow(
    pgui: pgui,
    window: newWin,
    renderer: renderer,
    rootElem: nil,
    styleSheet: styleSheetTbl
  )

  pgui.windows[newWinId]= result

  #pgui.windows[newWinId].rootElem = newRoot(pgui.windows[newWinId])

  pgui.currentWindowId = newWinId

  pgui.window = newWin






###########################################

#[ 
########  ########     ###    ##      ## 
##     ## ##     ##   ## ##   ##  ##  ## 
##     ## ##     ##  ##   ##  ##  ##  ## 
##     ## ########  ##     ## ##  ##  ## 
##     ## ##   ##   ######### ##  ##  ## 
##     ## ##    ##  ##     ## ##  ##  ## 
########  ##     ## ##     ##  ###  ###  
 ]#



proc drawDOM*(pgui:Pgui, r:DivRef)=
  if r.draw != nil: r.draw(r)

  for layer in r.layers:
    for elem in layer.elems:
          
      drawDOM(pgui, elem)

#..................................

proc recalcDOM*(rootElem: DivRef)=
  for layer in rootElem.layers:
    if layer.recalc != nil:
      (layer.w, layer.h) = layer.recalc(rootElem, layer)

template recalcDOM*(win:PgWindow)=
  recalcDOM(win.rootElem)
###########################################

#[ 
 ######   ######## ######## ######## ##       ######## ##     ## 
##    ##  ##          ##    ##       ##       ##       ###   ### 
##        ##          ##    ##       ##       ##       #### #### 
##   #### ######      ##    ######   ##       ######   ## ### ## 
##    ##  ##          ##    ##       ##       ##       ##     ## 
##    ##  ##          ##    ##       ##       ##       ##     ## 
 ######   ########    ##    ######## ######## ######## ##     ## 
 ]#

# todo SdlWindowId
proc getElementAtCoord*(root: DivRef, x,y:int): DivRef =
  ## gets element clicked on
  ## search from top to bottom
  const debug = 0
  
  result = nil
  #echo "getElementAtCoord_______________"
  for i_layer in countdown(root.layers.high,0):
    for elem in root.layers[i_layer].elems:
      var resultElem = getElementAtCoord(elem,x,y)
      if resultElem != nil:
        return resultElem
      else:
        if elem.x1 <= x and
           elem.x2 >= x and
           elem.y1 <= y and
           elem.y2 >= y:
              when debug > 1: echo "---- PLAUSIBLE ", elem.name, ":", $type(elem),", ",elem.x1,",",elem.y1,",",elem.x2,",",elem.y2,",", "\n"
              if elem.parent != nil:
                when debug > 1: echo "---- parent ",  elem.parent.name, ":",elem.parent.x1,",",elem.parent.y1,",",elem.parent.x2,",",elem.parent.y2,",", "\n"
                if elem.parent.x1 <= x and
                   elem.parent.x2 >= x and
                   elem.parent.y1 <= y and
                   elem.parent.y2 >= y:
                      when debug > 0: echo "---- FOUND ",  elem.name, ":",elem.x1,",",elem.y1,",",elem.x2,",",elem.y2,",", "\n"
                      return elem
              else:
                when debug > 0: echo "~~~~ FOUND ",  elem.name, ":",elem.x1,",",elem.y1,",",elem.x2,",",elem.y2,",", "\n"
                return elem
  #echo "................................"



###########################################
#[
######## ##     ## ##    ## 
##       ##     ## ###   ## 
##       ##     ## ####  ## 
######   ##     ## ## ## ## 
##       ##     ## ##  #### 
##       ##     ## ##   ### 
##        #######  ##    ## 
]#


proc createUTF8_Shaded*(font: ttf.FontPtr,
                        str:string,
                        fontColor,
                        fontBgColor: sdl.Color): sdl.SurfacePtr =
  result = renderUtf8Shaded(
              font,
              str,
              fontColor,
              fontBgColor)



proc addEventListener*(controll:DivRef, evtname:string, fun:proc(source:DivRef):void)=
  var exists = false
  var newListener: Listener
  for i in 0..controll.listeners.high:
    if controll.listeners[i].name == evtname:
      controll.listeners[i].actions.add(fun)
      exists = true
  if not exists:
    newListener.name = evtname
    newListener.actions = @[]
    newListener.actions.add(fun)
    controll.listeners.add(newListener)


proc removeEventListener*(controll:DivRef, evtname:string, fun:proc(source:DivRef):void)=
  for i in 0..controll.listeners.high:
    if controll.listeners[i].name == evtname:
      for j in 0..controll.listeners[i].actions.high:
        if controll.listeners[i].actions[j] == fun:
          controll.listeners[i].actions.del(j)


proc trigger*(controll:DivRef, evtname:string ):bool{.discardable.}=
  result = false
  for i in 0..controll.listeners.high:
    if controll.listeners[i].name == evtname:
      for j in 0..controll.listeners[i].actions.high:
        controll.listeners[i].actions[j](controll)
      result = true


proc trigger*(pgui:Pgui, evtname:string ):bool{.discardable.}=
  result = false
  for i in 0..pgui.listeners.high:
    if pgui.listeners[i].name == evtname:
      for j in 0..pgui.listeners[i].actions.high:
        pgui.listeners[i].actions[j](nil) #! nil means no DivRef, not gui elem
      result = true
#..............
proc changeWindowRecursive(this:DivRef, win:PgWindow)=
  ## helper for copyElem
  ## changes the window prop for all children
  for layer in this.layers:
    for elem in layer.elems:
      elem.window = win
      changeWindowRecursive(elem, win)

proc copyElem*(this:DivRef, dest:DivRef, layerNum: int = 0)=
  ## copy the elem into dest's layer (elem keeps its old parent)
  if layerNum < 0 or layerNum > dest.layers.high: return
  dest.layers[layerNum].elems.add(this)
  this.layer = layerNum
  this.parent = dest
  this.window = dest.window
  changeWindowRecursive(this, dest.window)
  dest.layers[layerNum].renumberNthChild()
  recalcStyle(dest,true)
  recalcDOM(dest)

proc removeElem*(layer: Layer, elem: DivRef)=
  if layer.elems.len > 0:
    for i in 0.. layer.elems.high:
      if layer.elems[i] == elem:
        layer.elems.delete(i)
        break
  layer.renumberNthChild()

proc removeElem*(elem: DivRef)=
  ## removes elem from its parent's layer using the stored layer index
  if elem.parent == nil: return
  let l = elem.layer
  if l < 0 or l > elem.parent.layers.high: return
  removeElem(elem.parent.layers[l], elem)
#..............

proc setPosition*(this:DivRef, x,y:int)=
  withLock this.lock:
    this.x1 = x
    this.y1 = y

    this.x2 = x + this.w - 1
    this.y2 = y + this.h - 1