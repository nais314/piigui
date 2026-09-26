# TODO: flex.nim column distribution, flex.nim refractor

import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases

import tables
import os
import std/monotimes
#import times
import random
import locks

###########################################


import piigui/[types,style]
export types

import piigui/layout/flex
import piigui/layout/recalcH as recalcHMod
import piigui/layout/recalcV as recalcVMod
import piigui/ui/scrollbar
export scrollbar


###########################################

var SCROLL_SPEED* = 5

const debug = 0

###########################################

converter cintToInt*(x: cint): int = x.int
converter intToCint*(x: int): cint = x.cint

###########################################


proc setDPIMultiplier*(window:PgWindow) =
  let displayID = sdl.getDisplayForWindow(window.window)
  let scale = sdl.getDisplayContentScale(displayID)
  if scale > 0.0:
    window.scale = scale.float
  else:
    when debug > 0: debugEcho "Failed to get DPI scale, defaulting to 1.0: ", sdl.getError()
    window.scale = 1.0


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

#[ 
######## ######## ##     ## ########  ##          ###    ######## ########  ######  
   ##    ##       ###   ### ##     ## ##         ## ##      ##    ##       ##    ## 
   ##    ##       #### #### ##     ## ##        ##   ##     ##    ##       ##       
   ##    ######   ## ### ## ########  ##       ##     ##    ##    ######    ######  
   ##    ##       ##     ## ##        ##       #########    ##    ##             ## 
   ##    ##       ##     ## ##        ##       ##     ##    ##    ##       ##    ## 
   ##    ######## ##     ## ##        ######## ##     ##    ##    ########  ######  
 ]#
#======================================
#*  TEMPLATES
#======================================
## templates to ease typing and
## make src code readable

template activeWindow*(pgui): PgWindow =
  pgui.windows[pgui.currentWindowId]

template renderer*(pgui: Pgui): RendererPtr =
  pgui.windows[pgui.currentWindowId].renderer
  #pgui.activeWindow.renderer

template rootElem*(pgui:Pgui):DivRef=
  pgui.windows[pgui.currentWindowId].rootElem
  #pgui.activeWindow.rootElem

template elems*(this:DivRef):seq[DivRef]=
  this.layers[0].elems


#[ 
##          ###    ##    ## ######## ########   ######  
##         ## ##    ##  ##  ##       ##     ## ##    ## 
##        ##   ##    ####   ##       ##     ## ##       
##       ##     ##    ##    ######   ########   ######  
##       #########    ##    ##       ##   ##         ## 
##       ##     ##    ##    ##       ##    ##  ##    ## 
######## ##     ##    ##    ######## ##     ##  ######  
]#
#======================================
#*  LAYERS
#======================================
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
#======================================
#*  EVENTS
#======================================
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
    setActiveStyle(this,"focus", false)
    
    if this.pgui.focusElem != nil: # prev focused elem blur
      this.pgui.focusElem.setDefaultStyle(false)
      if this.pgui.focusElem.onBlur != nil:
        this.pgui.focusElem.onBlur(this.pgui.focusElem)
    
    this.pgui.focusElem = this

proc parent_onFocus*(this:DivRef){.nosinks.}=
  this.parent.onFocus(this.parent)
#..........

proc default_onBlur*(this:DivRef){.nosinks.}=
  if this.window != nil:
    discard sdl.stopTextInput(this.window.window)

#..........

proc default_onDragStart*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  echo " * DRAG START * DRAG START * DRAG START * "
  # save begin state once, so Escape can restore it
  if not this.dragSaved:
    this.origX1 = this.x1
    this.origY1 = this.y1
    this.dragSaved = true
  #setDefaultStyle(this) # hover
  this.setActiveStyle("dragstart")
  this.pgui.hoverElem = nil

proc setPosition*(this: DivRef, x,y:int) #!FWD

proc parent_onDragStart*(this:DivRef){.nosinks.}=
  this.parent.onDragStart(this.parent)
#..........


proc default_onDragEnd*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  setDefaultStyle(this)
  this.dragSaved = false
  #echo " * DRAGEND * DRAGEND * DRAGEND * "
  if this.pgui.hoverElem != nil:
    this.pgui.hoverElem.setDefaultStyle()
    this.pgui.hoverElem = nil

proc parent_onDragEnd*(this:DivRef){.nosinks.}=
  this.parent.onDragEnd(this.parent)
#...........


proc default_onDragCancel*(this:DivRef){.nosinks.}=
  ## Escape pressed mid-drag: restore the begin state
  if this.dragSaved:
    this.setPosition(this.origX1, this.origY1)
    this.dragSaved = false
  setDefaultStyle(this)
  if this.pgui.hoverElem != nil:
    this.pgui.hoverElem.setDefaultStyle()
    this.pgui.hoverElem = nil


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
 ######   ######  ########   #######  ##       ##       
##    ## ##    ## ##     ## ##     ## ##       ##       
##       ##       ##     ## ##     ## ##       ##       
 ######  ##       ########  ##     ## ##       ##       
      ## ##       ##   ##   ##     ## ##       ##       
##    ## ##    ## ##    ##  ##     ## ##       ##       
 ######   ######  ##     ##  #######  ######## ######## 
 ]#
#======================================
#*  SCROLLING
#======================================

proc scrollOffset*(this:DivRef): tuple[x,y:int] =
  ## sum of scrollX/scrollY of all scrollable ancestors.
  ## used to shift the destination rect of a drawn element
  ## so scrolled content appears shifted inside its viewport.
  var cur = this.parent
  while cur != nil:
    if cur.scrollable:
      result.x += cur.scrollX
      result.y += cur.scrollY
    cur = cur.parent


proc visibleClipRect*(this: DivRef, scrollX, scrollY: int): sdl.Rect =
  ## On-screen clip rect for drawing `this`: the intersection of the
  ## on-screen rects of every ancestor, each shifted by its own
  ## ancestors' accumulated scroll. A deep child is therefore clipped
  ## inside every scrollable ancestor, not only its direct parent.
  ## `scrollX/Y` is the accumulated scroll of `this`'s ancestors.
  ##
  ## This upward walk is O(depth), so it is called once per drawDOM() to seed
  ## the running clip; drawDOMImpl then propagates it top-down in O(1) per
  ## element (stored in DivObj.clipRect).
  if this.parent == nil:
    return sdl.Rect((x: this.x1.cint, y: this.y1.cint,
            w: this.w.cint, h: this.h.cint))

  # accX/Y = the parent's accumulated ancestor scroll
  # (the parent's own scroll shifts its children, not the parent itself)
  var accX = scrollX
  var accY = scrollY
  if this.parent.scrollable:
    accX -= this.parent.scrollX
    accY -= this.parent.scrollY

  var
    minX = this.parent.x1 - accX
    minY = this.parent.y1 - accY
    maxX = this.parent.x2 - accX
    maxY = this.parent.y2 - accY

  var ancestor = this.parent.parent
  while ancestor != nil:
    if ancestor.scrollable:
      accX -= ancestor.scrollX
      accY -= ancestor.scrollY
    minX = max(minX, ancestor.x1 - accX)
    minY = max(minY, ancestor.y1 - accY)
    maxX = min(maxX, ancestor.x2 - accX)
    maxY = min(maxY, ancestor.y2 - accY)
    ancestor = ancestor.parent
    ##[ 
    The reason it's specifically accX -= scrollX (subtracting)
    rather than accX += scrollX comes down to what scroll does geometrically:

    When a container is scrolled right by scrollX, 
    its content appears shifted left on screen 
    relative to the container's own box.
    Equivalently, to convert a child's document-space coordinate 
    into the container's on-screen coordinate space, 
    you subtract the scroll: screenX = docX - scrollX. 
    ]##

  if minX > maxX or minY > maxY: # empty intersection: nothing visible
    return (x: 0.cint, y: 0.cint, w: 0.cint, h: 0.cint)

  return (x: minX.cint, y: minY.cint,
          w: (maxX - minX + 1).cint,
          h: (maxY - minY + 1).cint)

#[ 
      ########  #### ##     ## 
      ##     ##  ##  ##     ## 
      ##     ##  ##  ##     ## 
      ##     ##  ##  ##     ## 
      ##     ##  ##   ##   ##  
      ##     ##  ##    ## ##   
      ########  ####    ###    
 ]#
#======================================
#*  DivRef
#====================================== 
proc drawDivRef*(this:DivRef, scrollX, scrollY:int)=
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
  # clipRect (screen coordinates) hides overflow: this element's clip is the
  # intersection of all ancestors' on-screen rects, precomputed top-down by
  # drawDOMImpl into this.clipRect.
  # It must clip ONLY the final on-screen copy, not the texture-local
  # rendering below.
  var clipRect = this.clipRect
  #.............................

  # backgroundFRect is the subpixel float rect for accelerated painting
  var backgroundFRect = sdl.FRect(
    x: 0.0,
    y: 0.0,
    w: this.w.cfloat,
    h: this.h.cfloat
  )

  #.............................

  # the area of this elem on the screen in FRect
  # shifted by the accumulated scroll offsets of its scrollable ancestors
  var thisFRect = sdl.FRect(
    x: (this.x1 - scrollX).cfloat,
    y: (this.y1 - scrollY).cfloat,
    w: this.w.cfloat,
    h: this.h.cfloat
  )

  #.............................
  # we need to redraw, even if not changed
  if this.redrawFlag != rkFullRedraw and this.textureCache != nil:
      discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
      discard this.window.renderer.renderTexture(
          this.textureCache,
          nil, addr thisFRect)


  else:
    # if need to redraw, check if cache setted up
    # todo setup cache at recalc
    if this.textureCache != nil:
      sdl.destroyTexture(this.textureCache)
    this.textureCache = sdl.createTexture(
      this.window.renderer,
      sdl.PIXELFORMAT_UNKNOWN,
      sdl.TEXTUREACCESS_TARGET,
      this.w.cint, this.h.cint)
      
    discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

    # the elems. texture is the render target x=0 y=0!
    discard sdl.setRenderTarget(this.window.renderer, this.textureCache)
    discard setRenderDrawColor(this.window.renderer, transparentColor)
    #discard this.window.renderer.clear()
    #.............................

    if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
      discard setRenderDrawColor(this.window.renderer,
        this.styleCache[this.activeStyle].backGroundColor)
    when debug > 0:
        if this.styleCache[this.activeStyle].backGroundColor == EmptyColor:
          randomize()
          var
            r: uint8 = (rand(127) + 128).uint8
            g: uint8 = (rand(127) + 128).uint8
            b: uint8 = (rand(127) + 128).uint8
            a: uint8 = 255
          discard this.window.renderer.setRenderDrawColor(r, g, b, a)


    # draw the elem
    discard this.window.renderer.renderFillRect(addr(backgroundFRect))

    #=====================================

    when debug > 0:
        # render text --- render text --- render text ---
        var
          fontColor = sdl.Color(r:0'u8,g:0'u8,b:0'u8,a:128'u8)
          fontBgColor = sdl.Color(r:0'u8,g:0'u8,b:0'u8,a:0'u8)

        discard this.window.renderer.getRenderDrawColor(
                      fontBgColor.r,
                      fontBgColor.g,
                      fontBgColor.b,
                      fontBgColor.a)
        var surface = ttf.renderTextShaded(
                      this.pgui.fonts[0].fontPtr,
                      this.name.cstring,
                      0,
                      fontColor,
                      fontBgColor)
        
        if surface != nil:
            var sFRect = sdl.FRect(
                                x: 0.0,
                                y: 0.0,
                                w: surface.w.cfloat,
                                h: surface.h.cfloat)

            var texture = sdl.createTextureFromSurface(this.window.renderer, surface)

            discard this.window.renderer.renderTexture(texture,
                nil, addr sFRect)

            sdl.destroySurface(surface)
            sdl.destroyTexture(texture) #?


    #=====================================
    discard sdl.setRenderTarget(this.window.renderer, nil)
    # clip only the screen-space copy
    discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
    discard this.window.renderer.renderTexture(
        this.textureCache,
        nil, addr thisFRect)


  # reset clipping
  discard sdl.setRenderClipRect(this.window.renderer, nil)

  this.redrawFlag = rkNoRedraw

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


  result.layers = @[]
  result.layer = layer
  discard result.newLayer(recalcFun)

  result.name = name
  result.group = group
  # todo move to back if style not adds it
  (result.w_unit, result.w_value) = parseSizeStr(width)
  (result.h_unit, result.h_value) = parseSizeStr(height)
  #result.recalc = recalcFun
  result.redrawFlag = rkFullRedraw
  result.isRecalculated = false


  result.onHover = piigui.default_onHover
  result.onFocus = piigui.default_onFocus
  result.onBlur = piigui.default_onBlur #TODO: review, test
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = piigui.default_onDragEnd
  result.onDragOver = piigui.default_onDragOver
  result.onDragCancel = piigui.default_onDragCancel

  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)
  
  for style in styles:
    if rootSSRT.contains(style):
      result.styles.add((style, rootSSRT[style]))

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
#======================================
#*  LAYOUT
#====================================== 
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
# Alias forwarding template
template hBox*(args: varargs[untyped]): untyped =
  row(args)


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
# Alias forwarding template
template vBox*(args: varargs[untyped]): untyped =
  column(args)

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
#======================================
#*  RootElem
#====================================== 
proc newRoot*(
    win:PgWindow,
    name:string="",
    recalcFun: proc(this:DivRef, layer:Layer):tuple[w,h:int] = recalcFlex,
    styles:openArray[string] = ["rootStyle"]
    ): RootElem =
  ## the root Div. its dimensions are the window dimensions,
  ## it cannot be calculated like the rest of the Divs,
  ## wich are using parents dimensions.
  ## window events should take care!
  result = new RootElem
  result.typeName = "root"

  initLock(result.lock)

  result.parent = nil
  result.pgui = win.pgui
  result.window = win
  win.redrawFlag = true # fresh tree needs its first frame drawn

  result.layers = @[]
  result.layer = -1 # -1 marks the root: it has no parent
  discard result.newLayer(recalcFun)
  
  result.iD = getNextGlobalID()
  if name == "": result.name = "root_" & $result.iD

  result.w_unit = muPx
  result.h_unit = muPx
  var cw,ch:cint
  discard win.window.getSize(cw, ch)
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
  result.redrawFlag = rkFullRedraw
  result.isRecalculated = false

  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)
  for style in styles:
    result.styles.add((style, rootSSRT[style]))
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


#======================================
#*  WINDOW
#====================================== 
proc newWindow*(pgui:Pgui,
                title: cstring,
                x: cint = sdl.WINDOWPOS_UNDEFINED.cint,
                y: cint = sdl.WINDOWPOS_UNDEFINED.cint,
                w: cint = 640, h: cint = 480,
                flags: sdl.WindowFlags = DefaultWindowFlags,
                styleSheetTbl: StyleSheetRef_Tbl
                ): PgWindow =
  ## creates a PgWindow for an Pgui
  ## creates rootElem for PgWindow
  ## 
  
  let newWin = sdl.createWindow(title, w, h, flags)
  if newWin == nil:
    return nil
  if x != sdl.WINDOWPOS_UNDEFINED.cint or y != sdl.WINDOWPOS_UNDEFINED.cint:
    discard sdl.setWindowPosition(newWin, x, y)
  #........................
  let newWinId = newWin.getID()

  let renderer = sdl.createRenderer(newWin, nil)
  if renderer == nil:
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


#======================================
#*  DRAW DOM
#====================================== 
proc drawDOMImpl(pgui:Pgui, this:DivRef, scrollX, scrollY:int, ancestorClip: sdl.Rect)=
  ## draw the tree, carrying the accumulated scroll offsets of the scrollable
  ## ancestors and the running on-screen clip down to every element.
  ## `ancestorClip` is the intersection of all ancestors' on-screen rects,
  ## computed top-down so no element needs an upward walk (see visibleClipRect).
  this.clipRect = ancestorClip
  if this.draw != nil: this.draw(this, scrollX, scrollY)
  #if this.redrawFlag > rkNoRedraw and this.draw != nil: this.draw(this, scrollX, scrollY)

  # children are additionally clipped to this element's own on-screen rect
  let thisScreenX = (this.x1 - scrollX).cint
  let thisScreenY = (this.y1 - scrollY).cint
  let childLeft = max(ancestorClip.x, thisScreenX)
  let childTop = max(ancestorClip.y, thisScreenY)
  let childRight = min(ancestorClip.x + ancestorClip.w, thisScreenX + this.w.cint)
  let childBottom = min(ancestorClip.y + ancestorClip.h, thisScreenY + this.h.cint)
  var childClip = sdl.Rect(
    x: childLeft,
    y: childTop,
    w: max(0.cint, childRight - childLeft),
    h: max(0.cint, childBottom - childTop))

  # this's own children are shifted by this's scroll, if this is scrollable
  let nX = scrollX + (if this.scrollable: this.scrollX else: 0)
  let nY = scrollY + (if this.scrollable: this.scrollY else: 0)
  for layer in this.layers:
    for elem in layer.elems:
      drawDOMImpl(pgui, elem, nX, nY, childClip)

  # the scrollbar overlay sits in the owner's frame (its own scroll NOT applied)
  if this.scrollable and this.scrollbar != nil:
    drawScrollBar(this.scrollbar, scrollX, scrollY)

proc drawDOM*(pgui:Pgui, this:DivRef)=
  ## draw a tree (or subtree) from its root.
  ## the first call seeds the offset with the element's own scrollable
  ## ancestors, so it can be called with any element, not just the root.
  ## The clip is computed once here; descendants inherit it as a running value.
  let off = scrollOffset(this)
  let rootClip = visibleClipRect(this, off.x, off.y)
  drawDOMImpl(pgui, this, off.x, off.y, rootClip)

proc drawWindows*(pgui:Pgui)=
  ## redraw and present only the windows flagged dirty.
  ## Elements resolve their renderer through their own `window`,
  ## so the active window does not need to be switched here.
  if pgui == nil:
    return
  for _, win in pgui.windows:
    if not win.redrawFlag or win.rootElem == nil:
      continue
    pgui.drawDOM(win.rootElem)
    discard win.renderer.present()
    win.redrawFlag = false

#..................................

proc recalcDOM*(rootElem: DivRef)=
  #[ if rootElem.parent == nil:
    var cw,ch:cint
    getSize(rootElem.window.window, cw, ch)
    rootElem.w_value = cw
    rootElem.h_value = ch
    rootElem.w = cw
    rootElem.h = ch ]#
  for layer in rootElem.layers:
    if layer.recalc != nil:
      (layer.w, layer.h) = layer.recalc(rootElem, layer)

  # position scrollbar overlays after the layout settles
  recalcScrollbars(rootElem)

template recalcDOM*(win:PgWindow)=
  recalcDOM(win.rootElem)

#TODO: template recalcDOM*(pgui:Pgui)=


proc markRedraw*(this: DivRef, kind: RedrawKind) =
  ## Requests a redraw of `this`. Two different pending requests on an already
  ## dirty element escalate to rkFullRedraw, so a full rebuild is never weakened
  ## by a later partial request and a partial update is upgraded when needed.
  if this == nil or kind == rkNoRedraw:
    return
  if this.redrawFlag == rkNoRedraw:
    this.redrawFlag = kind
  elif this.redrawFlag != kind:
    this.redrawFlag = rkFullRedraw

proc refreshTextureCache*(rootElem: DivRef)=
  for layer in rootElem.layers:
    for elem in layer.elems:
      elem.redrawFlag = rkFullRedraw



#======================================
#*  SCALING
#====================================== 
proc onScaleDown*(this: DivRef)=
  ## for manual scaling of gui
  this.window.scale = clampScale(this.window.scale - 0.1)
  
proc onScaleUp*(this: DivRef)=
  ## for manual scaling of gui  
  this.window.scale = clampScale(this.window.scale + 0.1)


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
#======================================
#*  GET ELEM
#====================================== 
# todo SdlWindowId
proc getElementAtCoord*(root: DivRef, x,y:int): DivRef =
  ## gets element clicked on
  ## search from top to bottom
  ## x,y are screen coords; the scroll offsets of scrollable
  ## ancestors are added so scrolled content is hit correctly.

  proc rec(elem: DivRef, accX, accY: int): DivRef =
    # elem and its children are clipped to elem's on-screen rect,
    # so if the point is outside it, nothing inside can be hit
    # (this also hides overflowed content of non-scrollable parents)
    let ex = x + accX
    let ey = y + accY
    if ex < elem.x1 or ex > elem.x2 or ey < elem.y1 or ey > elem.y2:
      return nil

    # the scrollbar overlay sits on top of elem's content
    if elem.scrollable and elem.scrollbar != nil:
      result = elem.scrollbar.hitTest(ex, ey)
      if result != nil:
        return result

    # elem's own children are shifted by elem's scroll too
    let cAccX = accX + (if elem.scrollable: elem.scrollX else: 0)
    let cAccY = accY + (if elem.scrollable: elem.scrollY else: 0)
    for i_layer in countdown(elem.layers.high, 0):
      for child in elem.layers[i_layer].elems:
        result = rec(child, cAccX, cAccY)
        if result != nil:
          return result

    # the point is inside elem (checked above); return it.
    # (the root is never passed to rec, so elem.parent is always non-nil)
    return elem

  # the root can scroll too: check its overlay at the window edge first
  if root.scrollable and root.scrollbar != nil:
    result = root.scrollbar.hitTest(x, y)
    if result != nil:
      return result

  # root's children are shifted by the root's own scroll
  let rAccX = if root.scrollable: root.scrollX else: 0
  let rAccY = if root.scrollable: root.scrollY else: 0
  for i_layer in countdown(root.layers.high, 0):
    for elem in root.layers[i_layer].elems:
      result = rec(elem, rAccX, rAccY)
      if result != nil:
        return result



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


# ===================================================
#* FONT
# ===================================================

proc createUTF8_Shaded*(font: FontPtr,
                        str:string,
                        fontColor,
                        fontBgColor: sdl.Color): SurfacePtr =
  result = ttf.renderTextShaded(
              font,
              str.cstring,
              0,
              fontColor,
              fontBgColor)

proc closeAllFonts*(pgui: Pgui) =
  for _, font in pgui.fonts:
    if font.fontPtr != nil:
      ttf.closeFont(font.fontPtr)
  pgui.fonts.setLen(0)
template destroyFonts*(pgui: Pgui) = closeAllFonts(pgui)


# ===================================================
#* EVENT HANDLERS
# ===================================================

proc addEventListener*(
        this:DivRef,
        evtname:string,
        fun:proc(source:DivRef, e:sdl.Event):bool)=
  var exists = false
  var newListener: Listener
  for i in 0..this.listeners.high:
    if this.listeners[i].name == evtname:
      this.listeners[i].actions.add(fun)
      exists = true
  if not exists:
    newListener.name = evtname
    newListener.actions = @[]
    newListener.actions.add(fun)
    this.listeners.add(newListener)


proc removeEventListener*(this:DivRef, evtname:string, fun:proc(source:DivRef, e:sdl.Event):bool)=
  for i in countdown(this.listeners.high, 0):
    if this.listeners[i].name == evtname:
      for j in countdown(this.listeners[i].actions.high, 0):
        if this.listeners[i].actions[j] == fun:
          this.listeners[i].actions.del(j)
      if this.listeners[i].actions.len == 0:
        this.listeners.del(i)


proc trigger*(this:DivRef, evtname:string, e:sdl.Event = default(sdl.Event)):bool{.discardable.}=
  ## Dispatches `evtname` to this element's listeners, passing `e` through.
  ## When `trigger` is called without an event, `e` is the zero value
  ## `default(sdl.Event)`. A listener tells a real event from that sentinel with
  ## `if e.`type` != sdl.EVENT_FIRST:` (EVENT_FIRST == 0; pollEvent never
  ## delivers it). All matching listeners run in registration order. Returns
  ## true when at least one of them reported the event as handled (returned
  ## true); otherwise false, so the event may bubble to window/pgui listeners.
  result = false
  for i in 0..this.listeners.high:
    if this.listeners[i].name == evtname:
      for j in 0..this.listeners[i].actions.high:
        if this.listeners[i].actions[j](this, e):
          result = true


#--------------------------------------
# PgWindow-level listeners
#--------------------------------------

proc addEventListener*(
        this:PgWindow,
        evtname:string,
        fun:proc(source:DivRef, e:sdl.Event):bool)=
  var exists = false
  var newListener: Listener
  for i in 0..this.listeners.high:
    if this.listeners[i].name == evtname:
      this.listeners[i].actions.add(fun)
      exists = true
  if not exists:
    newListener.name = evtname
    newListener.actions = @[]
    newListener.actions.add(fun)
    this.listeners.add(newListener)


proc removeEventListener*(this:PgWindow, evtname:string, fun:proc(source:DivRef, e:sdl.Event):bool)=
  for i in countdown(this.listeners.high, 0):
    if this.listeners[i].name == evtname:
      for j in countdown(this.listeners[i].actions.high, 0):
        if this.listeners[i].actions[j] == fun:
          this.listeners[i].actions.del(j)
      if this.listeners[i].actions.len == 0:
        this.listeners.del(i)


proc trigger*(this:PgWindow, evtname:string, e:sdl.Event = default(sdl.Event)):bool{.discardable.}=
  ## Dispatches `evtname` to this window's listeners; `source` is the window's
  ## root element. Returns true when at least one listener handled the event.
  result = false
  for i in 0..this.listeners.high:
    if this.listeners[i].name == evtname:
      for j in 0..this.listeners[i].actions.high:
        if this.listeners[i].actions[j](this.rootElem, e):
          result = true


#--------------------------------------
# Pgui-level (system-wide) listeners
#--------------------------------------

proc addEventListener*(
        pgui:Pgui,
        evtname:string,
        fun:proc(source:DivRef, e:sdl.Event):bool)=
  var exists = false
  var newListener: Listener
  for i in 0..pgui.listeners.high:
    if pgui.listeners[i].name == evtname:
      pgui.listeners[i].actions.add(fun)
      exists = true
  if not exists:
    newListener.name = evtname
    newListener.actions = @[]
    newListener.actions.add(fun)
    pgui.listeners.add(newListener)


proc removeEventListener*(pgui:Pgui, evtname:string, fun:proc(source:DivRef, e:sdl.Event):bool)=
  for i in countdown(pgui.listeners.high, 0):
    if pgui.listeners[i].name == evtname:
      for j in countdown(pgui.listeners[i].actions.high, 0):
        if pgui.listeners[i].actions[j] == fun:
          pgui.listeners[i].actions.del(j)
      if pgui.listeners[i].actions.len == 0:
        pgui.listeners.del(i)


proc trigger*(pgui:Pgui, evtname:string, e:sdl.Event = default(sdl.Event)):bool{.discardable.}=
  ## Dispatches system-wide listeners. `source` is nil: "no element".
  ## Returns true when at least one listener handled the event.
  result = false
  for i in 0..pgui.listeners.high:
    if pgui.listeners[i].name == evtname:
      for j in 0..pgui.listeners[i].actions.high:
        if pgui.listeners[i].actions[j](nil, e): #! nil means no DivRef, not gui elem
          result = true
#..............

#--------------------------------------
# Add event listeners to multiple elems
#--------------------------------------
proc addEventListener*(
      elems:seq[DivRef],
      evtname:string,
      fun:proc(source:DivRef, e:sdl.Event):bool)=
  var newListener: Listener
  for controll in elems:
    var exists = false #* must reset per element, else one match skips the rest
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
        fun:proc(source:DivRef, e:sdl.Event):bool)=
  for control in elems:
    for i in countdown(control.listeners.high, 0):
      if control.listeners[i].name == evtname:
        for j in countdown(control.listeners[i].actions.high, 0):
          if control.listeners[i].actions[j] == fun:
            control.listeners[i].actions.del(j)
        if control.listeners[i].actions.len == 0:
          control.listeners.del(i)


proc trigger*(elems:seq[DivRef], evtname:string, e:sdl.Event = default(sdl.Event)):bool=
  result = false
  for controll in elems:
    for i in 0..controll.listeners.high:
      if controll.listeners[i].name == evtname:
        for j in 0..controll.listeners[i].actions.high:
          if controll.listeners[i].actions[j](controll, e):
            result = true




#--------------------------------------
# Add timed gui events
#--------------------------------------

proc addTimedEvent*(pgui: Pgui,
                    elem: DivRef,
                    intervalNs: int64,
                    fun: proc(this: DivRef, nowNs: int64),
                    repeat: bool = true) =
  ## Registers a main-thread callback for an element.
  ## intervalNs is the interval in nanoseconds.
  if pgui == nil or elem == nil or fun == nil:
    return
  if intervalNs <= 0:
    raise newException(ValueError, "Timed event interval must be positive")

  pgui.guiTimedEvents.add(TimedEvent(
    elem: elem,
    intervalNs: intervalNs,
    nextFireNs: getMonoTime().ticks + intervalNs,
    repeat: repeat,
    fun: fun))


proc removeTimedEvent*(pgui: Pgui,
                       elem: DivRef,
                       fun: proc(this: DivRef, nowNs: int64)) =
  if pgui == nil:
    return
  var i = pgui.guiTimedEvents.high
  while i >= 0:
    let event = pgui.guiTimedEvents[i]
    if event.elem == elem and event.fun == fun:
      pgui.guiTimedEvents.delete(i)
    dec i


proc clearTimedEvents*(pgui: Pgui, elem: DivRef) =
  if pgui == nil:
    return
  var i = pgui.guiTimedEvents.high
  while i >= 0:
    if pgui.guiTimedEvents[i].elem == elem:
      pgui.guiTimedEvents.delete(i)
    dec i


proc clearTimedEventsRecursive(pgui: Pgui, elem: DivRef) =
  ## used by proc removeElem
  if elem == nil:
    return
  clearTimedEvents(pgui, elem)
  for layer in elem.layers:
    for child in layer.elems:
      clearTimedEventsRecursive(pgui, child)


proc runTimedEvents*(pgui: Pgui, nowNs: int64) =
  ## Runs due callbacks on the thread that owns the GUI.
  ## nowNs is the frame timestamp in nanoseconds, supplied by the caller so
  ## the run loop does not need an extra getMonoTime() call.
  if pgui == nil:
    return

  var i = 0
  while i < pgui.guiTimedEvents.len:
    let event = pgui.guiTimedEvents[i]
    if nowNs < event.nextFireNs:
      inc i
      continue

    if event.repeat:
      # Schedule from now so a slow frame does not cause callback bursts.
      pgui.guiTimedEvents[i].nextFireNs = nowNs + event.intervalNs
    else:
      pgui.guiTimedEvents.delete(i)

    event.fun(event.elem, nowNs)

    #! a callback may have changed the tree;
    #! repaint its window in --= MAIN LOOP =--
    if event.elem != nil and event.elem.window != nil:
      event.elem.window.redrawFlag = true

    # A callback may remove or replace its own event.
    if event.repeat and i < pgui.guiTimedEvents.len and
       pgui.guiTimedEvents[i].elem == event.elem and
       pgui.guiTimedEvents[i].fun == event.fun:
      inc i

#..............

# ===================================================
#* DOM MANIPULATION
# ===================================================

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
  recalcStyle(dest,true)
  recalcDOM(dest)

proc removeElem*(layer: Layer, elem: DivRef)=
  if layer.elems.len > 0:
    for i in 0.. layer.elems.high:
      if layer.elems[i] == elem:
        layer.elems.delete(i)
        break

proc removeElem*(elem: DivRef)=
  ## removes elem from its parent's layer using the stored layer index
  if elem.parent == nil: return
  clearTimedEventsRecursive(elem.pgui, elem)
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
