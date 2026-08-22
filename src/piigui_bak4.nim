
import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf

import random
import tables
import times
import os

###########################################


import piigui/[types,style]
export types

import piigui/layout/flex
import piigui/layout/vhbox



###########################################

var SCROLL_SPEED* = 5

###########################################

# TODO: scale-up: multiply font sizes, pixel sizes 
# TODO:   according to a design time window size or user value


#[ 
  88  88  dP"Yb  Yb    dP 888888 88""Yb 
  88  88 dP   Yb  Yb  dP  88__   88__dP 
  888888 Yb   dP   YbdP   88""   88"Yb  
  88  88  YbodP     YP    888888 88  Yb 
 ]#


proc default_onHover*(this:DivRef){.nosinks.}=
  if this.app.mouseSource == nil: # else dragover
    if this.app.hoverElem != this and
    this.app.focusElem != this :

      setActiveStyle(this,"hover")
      
      # restore prev hover elems style
      # unless its focused - dont remove focus style!
      if this.app.hoverElem != nil and
      this.app.focusElem != this.app.hoverElem :
        this.app.hoverElem.setBackActiveStyle()
    
    # for hover events to work, like scroll:
    if this.app.hoverElem != this:
      this.app.hoverElem = this


proc default_onFocus*(this:DivRef){.nosinks.}=
  echo this.name, " FOCUSING"
  if this.app.focusElem != this :

    setBackActiveStyle(this) # remove :hover
    this.app.hoverElem = nil
    setActiveStyle(this,"focus")
    
    if this.app.focusElem != nil: # prev focused elem blur
      this.app.focusElem.setBackActiveStyle()
      if this.app.focusElem.onBlur != nil:
        this.app.focusElem.onBlur(this.app.focusElem)
    
    this.app.focusElem = this



proc default_onDragStart*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  echo " * DRAG START * DRAG START * DRAG START * "
  setBackActiveStyle(this) # hover
  this.setActiveStyle("dragstart")
  this.app.hoverElem = nil


proc default_onDragEnd*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  setBackActiveStyle(this)
  echo " * DRAGEND * DRAGEND * DRAGEND * "
  if this.app.hoverElem != nil:
    this.app.hoverElem.setBackActiveStyle()
    this.app.hoverElem = nil


proc default_onDragOver*(this:DivRef){.nosinks.}=
  ## useful, if you not need special proc
  if this.app.hoverElem != this:
    if this.app.mouseSource != this:
      #setActiveStyle(this,"dragover")
      setActiveStyle(this,"hover")
      if this.app.hoverElem != nil:
        this.app.hoverElem.setBackActiveStyle()
      this.app.hoverElem = this

  if this.app.mouseSource == this and
    this.app.hoverElem != this:
      this.app.hoverElem.setBackActiveStyle()
      this.app.hoverElem = nil


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

# todo move ui_div
proc newDiv*(parent: DivRef,
             layer:int = 0,
             name: string,
             width: string="auto",
             height: string="auto",
             recalcFun: proc(this:DivRef) = recalcFlex,
             styles: openArray[string] = []
             ): DivRef =
  const debug = 0b0

  result = new DivRef

  result.typeName = "Div"

  result.parent = parent
  if parent != nil:
    if parent.app != nil: result.app = parent.app
    result.nthChild = parent.layers[layer].len
  if parent != nil:
    if parent.window != nil: result.window = parent.window
    result.nthChild = parent.layers[layer].len    

  result.layers = @[]
  result.layers.add(newSeq[DivRef](0))
  result.name = name
  # todo move to back if style not adds it
  (result.w_unit, result.w_value) = parseSizeStr(width)
  (result.h_unit, result.h_value) = parseSizeStr(height)
  result.recalc = recalcFun
  result.redrawFlag = 1
  result.isRecalculated = false


  result.onHover = piigui.default_onHover
  result.onFocus = piigui.default_onFocus


  result.inlineStyle = newStyleSheet()
  result.pseudoStyles = newTable[string, StyleSheetRef](4)
  result.styleCache = newTable[string, StyleSheetRef](4)

  #DEBUG FALLBACK
  #result.activeStyle = defaultSST["column"]
   
  for style in styles:
    result.styles.add((style, defaultSST[style]))

  result.activeStyle = "default"
  recalcStyle(result)


  #echo result.activeStyle.flexGrow
  #echo result.activeStyle.flexGrowFrom
  #echo result.activeStyle.flexDirection
  #echo result.activeStyle.flexWrap
  #echo result.activeStyle.justifyContent
  #echo result.activeStyle.alignContent
  #echo result.activeStyle.alignItems



  if parent != nil : parent.layers[layer].add(result)
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
template row*(parent: DivRef,
             layer:int = 0,
             name: string,
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    newDiv(parent,
          layer,
          name,
          width,
          height,
          recalcFun = recalcH,
          styles
        )


template column*(parent: DivRef,
             layer:int = 0,
             name: string,
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    newDiv(parent,
          layer,
          name,
          width,
          height,
          recalcFun = recalcV,
          styles
        )


#--------------------------------------------

template flex*(parent: DivRef,
             layer:int = 0,
             name: string,
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    newDiv(parent,
          layer,
          name,
          width,
          height,
          recalcFun = recalcFlex,
          styles
        )

template flexColumn*(parent: DivRef,
             layer:int = 0,
             name: string,
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    var stylesr = @["column"]
    stylesr.add(styles)
    newDiv(parent,
          layer,
          name,
          width,
          height,
          recalcFun = recalcFlex,
          stylesr
        )

template flexRow*(parent: DivRef,
             layer:int = 0,
             name: string,
             width:string="auto",
             height:string="auto",
             styles:openArray[string] = []
             ):DivRef=
    var stylesr = @["row"]
    stylesr.add(styles)
    newDiv(parent,
          layer,
          name,
          width,
          height,
          recalcFun = recalcFlex,
          stylesr
        )

#--------------------------------------------



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





#[ 
########   #######   #######  ######## 
##     ## ##     ## ##     ##    ##    
##     ## ##     ## ##     ##    ##    
########  ##     ## ##     ##    ##    
##   ##   ##     ## ##     ##    ##    
##    ##  ##     ## ##     ##    ##    
##     ##  #######   #######     ##    
 ]#

proc newRoot*(win:PgWindow,
              recalcFun: proc(this:DivRef) = recalcFlex,
              styles:openArray[string] = ["column"]): RootElem =
  #result = RootElem(newDiv(nil, 0, "root", "100%", "100%", recalcFun, styles))
  result = new RootElem

  result.parent = nil
  result.app = win.app

  result.layers = @[]
  result.layers.add(newSeq[DivRef](0))
  result.name = "root"
  # todo move to back if style not adds it
  #(result.w_unit, result.w_value) = parseSizeStr(width)
  #(result.h_unit, result.h_value) = parseSizeStr(height)
  result.w_unit = muPx
  result.h_unit = muPx
  var cw,ch:cint
  sdl.getSize(win.window, addr(cw), addr(ch))
  result.w_value = cw
  result.h_value = ch
  result.x1 = 0
  result.x2 = cw - 1
  result.y1 = 0
  result.y2 = ch - 1

  result.recalc = recalcFun
  result.redrawFlag = 1
  result.isRecalculated = false


  result.inlineStyle = newStyleSheet()
  result.pseudoStyles = newTable[string, StyleSheetRef](4)
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

proc newWindow*(app:App,
                # sdl.createWindow
                title: cstring;
                x: cint; y: cint; w: cint; h: cint; flags: uint32,
                styleSheetTbl: StyleSheetTbl): PgWindow =
  ## creates a PgWindow for an App
  ## creates rootElem for PgWindow
  ## 
  
  let newWin = sdl.createWindow(
        title, x,y, w,h, flags)
  if newWin == nil:
    sdl.logCritical(sdl.LogCategoryError,
                  "Can't create window: %s",
                  sdl.getError())
    return nil
  #........................
  let newWinId = newWin.getWindowID()

  let renderer = sdl.createRenderer(
        newWin,
        -1,
        sdl.RendererAccelerated or sdl.RendererPresentVsync or sdl.RendererTargetTexture)
  if renderer == nil:
    sdl.logCritical(sdl.LogCategoryError,
                    "Can't create renderer: %s",
                    sdl.getError())
    return nil
  #........................


  result = PgWindow(
    app: app,
    window: newWin,
    renderer: renderer,
    rootElem: nil,
    styleSheet: styleSheetTbl
  )

  app.windows[newWinId]= result

  app.windows[newWinId].rootElem = newRoot(app.windows[newWinId])

  app.currentWindowId = newWinId

  app.window = newWin
  app.renderer = renderer







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

proc testDrawDOM*(app:App, r: DivRef)=

  for layer in r.layers:
    for elem in layer:

      #[ if elem.redrawFlag > 0: #! flickers
        if elem.draw != nil:
          elem.draw(elem)
        #elem.redrawFlag = 0 ]#
      if elem.draw != nil:
          elem.draw(elem)
          
      testDrawDOM(app, elem)




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
  const debug = 1
  
  result = nil
  #echo "getElementAtCoord_______________"
  for i_layer in countdown(root.layers.high,0):
    for elem in root.layers[i_layer]:
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

proc createUTF8_Shaded*(font: Font,
                        str:string,
                        fontColor,
                        fontBgColor: sdl.Color): Surface =
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


proc trigger*(controll:DivRef, evtname:string ):bool=
  result = false
  for i in 0..controll.listeners.high:
    if controll.listeners[i].name == evtname:
      for j in 0..controll.listeners[i].actions.high:
        controll.listeners[i].actions[j](controll)
      result = true

