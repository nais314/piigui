
import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import locks
import tables
import parseUtils



const
  DefaultWindowW* = 640 # Window width
  DefaultWindowH* = 480 # Window height
  DefaultWindowFlags*: cuint = sdl.SDL_WINDOW_SHOWN
  DefaultRendererFlags*: cint = sdl.Renderer_Accelerated or sdl.Renderer_PresentVsync or sdl.Renderer_TargetTexture

  EmptyColor* : sdl.Color = (r:0'u8,g:0'u8,b:0'u8,a:0'u8)

#-------------------------------------------------------
type
  HexColor* = uint32
  
  MeasurementUnit* = enum
    muAuto,
    muStretch,
    muPx,
    muPc

#-------------------------------------------------------
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
    fdUndefined,
    fdRow,
    fdColumn #[ ,
    fdRowReverse,
    fdColumnReverse ]#
  
  FlexJustifyContentKind* = enum
    fjcUndefined,
    fjcStart,
    fjcCenter,
    fjcEnd

  FlexAlignContentKind* = enum
    facUndefined,
    facStretch,
    facCenter,
    facStart,
    facEnd,
    facSpaceBetween,
    facSpaceAround

  FlexAlignItemsKind* = enum
    faiUndefined,
    faiStretch,
    faiCenter,
    faiStart,
    faiEnd,
    #faiBaseLine #todo

  PositionKind* = enum
    posRelative,
    posAbsolute,
    posFixed
  #.......................................
  
  #sdl.Color* = ref sdl.Color # can test for nil

  StyleSheetRef* = ref StyleSheetObj # style data
  StyleSheetObj* = object of RootObj
    ## remember to update types.nim `<-` too
    # todo width*: int
    # todo height*: int
    # child related:::::::
    flexGrow*: int ## 0 < to activate growth
    flexGrowFrom*:int # eg 75: grow if line >= 75% of availW
    #flexShrink*: int

    flexDirection*: FlexDirectionKind
    #flexWrap*: bool #! overflow?????
    justifyContent*: FlexJustifyContentKind # horizontal distribute the lines
    alignContent*: FlexAlignContentKind # vertical distribute the lines
    alignItems*: FlexAlignItemsKind # vertical, elems in line

    spacing*:int # elems margin

    # self related::::::::
    #maxWidth*:int
    #maxHeight*:int

    #borderWidth*:tuple[top,right,bottom,left:int]

    color*: sdl.Color
    backGroundColor*: sdl.Color
    borderColor*: sdl.Color

    #TODO BACKGROUND
    #background*: BackGroundKindRef
    #backGroundTexture*: sdl.Texture
    #backGroundTexture_nineScale*: int
    #backGroundProc*: proc(w,h:int, color:sdl.Color, x:int):Texture #? ptr? x for future and custom info pass
    #backGroundRepeat*: BackgroundRepeatKind

    font*:string # fontTable[string, sdl.font] #TODO

    #overFlow*: OverFlowKind

    #opacity*: int #TODO how to add opacity? 0 - 1.0 * alpha?

    #position*: PositionKind

    padding*: int

    pseudoStyles*: TableRef[string, StyleSheetRef]

  # "CSS" in table
  StyleSheetRef_Tbl* = TableRef[string, StyleSheetRef]

  # used by Elements
  StyleSheetSeq* = seq[tuple[name:string, style:StyleSheetRef]]

  #FontTable* = TableRef[string, ttf.FontPtr]


  #------------------------------------------------------

  SdlWindowID* = uint32
  PgWindow* = ref object of RootObj
    pgui*:Pgui
    window*: sdl.WindowPtr
    renderer*: sdl.RendererPtr
    rootElem*:DivRef
    styleSheet*:StyleSheetRef_Tbl # newStyleSheetRef_Tbl*()

  #------------------------------------------------------
  Layer* = ref object of RootObj
    recalc*: proc(this:DivRef, layer:Layer):tuple[w,h:int] # flex, absolute, free, fixed
    elems*: seq[DivRef]
    w*,h*:int
  #------------------------------------------------------
  RootElementObj* = object of RootObj # extra root :-?
  #------------------------------------------------------

  #! REMEMBER TO MODIFY proc `=destroy`(this: var DivObj)
  DivRef* = ref DivObj
  DivObj* = object of RootElementObj
    typeName*: string # for type introspection
    w*,h*:int
    w_value*, h_value*:int # original user numeric value
    w_unit*, h_unit*: MeasurementUnit # PiXel, PerCent
    #innerW*, innerH*:int #* for scrollables - recalc sets it for parent

    window*: PgWindow
    pgui*:Pgui
    
    name*: string # id - html id
    group*:string # group id - html name
    iD*: uint # uniq ID for AI and such... result.iD = piigui.getNextGlobalID()

    parent*: DivRef
    nthChild*:int

    #layers*: seq[seq[DivRef]] # childs on layers
    layers*: seq[Layer]
    layer*: int

    #recalc*: proc(this:DivRef):tuple[w,h:int] # flex, absolute, free, fixed
    x1*,x2*,y1*,y2*: int

    redrawFlag*:int # changed? needs redraw? what to redraw?
    draw*:proc(this:DivRef)

    styles*: StyleSheetSeq # sequence of styles "cascading style sheet"
    styleCache*: StyleSheetRef_Tbl #TableRef[string, StyleSheetRef]
    activeStyle*: string #StyleSheetRef # todo rethink if table needed or just default
    prevStyle*: string #StyleSheetRef
    inlineStyle*: StyleSheetRef # props changed on the fly

    isRecalculated*: bool #??? muAuto calculates childs for its own dimensions

    onMouseButtonDown*: proc(this:DivRef)
    onMouseButtonUp*: proc(this:DivRef)

    onHover*: proc(this:DivRef)
    onFocus*: proc(this:DivRef)
    onBlur*: proc(this:DivRef)
    
    onDragStart*: proc(this:DivRef)
    onDragEnd*: proc(this:DivRef)
    onDragOver*: proc(this:DivRef)
    onDrop*: proc(this:DivRef)

    onClick*: proc(this:DivRef, e:sdl.Event)
    onTextInput*: proc(this:DivRef, text:string)

    textureCache*: sdl.TexturePtr

    ## p.e.: add validation here via "change" event
    ## handle keyboard shortcuts / events
    listeners*: ListenerList

    lock*:Lock





  #------------------------------------------------------

  #Pgui* = AppObj
  Pgui* = ref object of RootObj #AppBase
    #todo windows:
    #todo   window
    #todo   rootElem
    # window and renderer references must be updated
    windows*: Table[uint32, PgWindow] # uses SDL's WindowID
    currentWindowId*:uint32
    window*: sdl.WindowPtr # Window pointer
    #renderer*: sdl.Renderer # Rendering state pointer

    font_normal*: ttf.FontPtr

    focusElem*:DivRef # for routing user events
    hoverElem*:DivRef # for removing :hover from prev hovered elem

    mouseSource*:DivRef # drag and drop
    #mouseTarget*:DivRef # drag and drop

    fonts*:TableRef[string, ttf.FontPtr]

    listeners*: ListenerList #* system wide events


  RootElem* = ref object of DivRef
  BRElem* = ref object of DivRef # <br>

  #------------------------------------------------------

  Listener* = tuple[name:string,
                    actions: seq[proc(source:DivRef):void]]
  ListenerList* = seq[Listener]
  #------------------------------------------------------


#[ template activeWindow*(pgui): PgWindow =
  pgui.windows[pgui.currentWindowId]
 ]#

#[ proc newApp*():Pgui=
  result = new Pgui
  result.fonts = newTable[string, ttf.FontPtr]()
 ]#

#[ template trigger*(pgui:Pgui, evtname:string )=
  pgui.trigger(evtname) ]#

proc `=destroy`(this: var DivObj) =
  ## called when a DivRef is collected (ORC)
  ## frees the per-element GPU cache texture
  if this.textureCache != nil:
    sdl.destroyTexture(this.textureCache)
    this.textureCache = nil

  # a custom =destroy suppresses Nim's default field teardown,
  # so GC-managed fields must be released explicitly here.
  # (skipped: shared/cyclic refs parent, pgui, window)
  `=destroy`(this.typeName)
  `=destroy`(this.name)
  `=destroy`(this.group)
  `=destroy`(this.layers)
  `=destroy`(this.styles)
  `=destroy`(this.styleCache)
  `=destroy`(this.activeStyle)
  `=destroy`(this.prevStyle)
  `=destroy`(this.inlineStyle)
  `=destroy`(this.listeners)
  `=destroy`(this.draw)
  `=destroy`(this.onMouseButtonDown)
  `=destroy`(this.onMouseButtonUp)
  `=destroy`(this.onHover)
  `=destroy`(this.onFocus)
  `=destroy`(this.onBlur)
  `=destroy`(this.onDragStart)
  `=destroy`(this.onDragEnd)
  `=destroy`(this.onDragOver)
  `=destroy`(this.onDrop)
  `=destroy`(this.onClick)
  `=destroy`(this.onTextInput)
  deinitLock(this.lock)

template style*(this:DivRef):StyleSheetRef=
  this.styleCache[this.activeStyle]

proc getID*(this: DivRef): string =
  if this.name == "":
    result = this.typeName & $this.iD
  else:
    result = this.name & $this.iD



#[ 
########     ###    ########   ######  ######## 
##     ##   ## ##   ##     ## ##    ## ##       
##     ##  ##   ##  ##     ## ##       ##       
########  ##     ## ########   ######  ######   
##        ######### ##   ##         ## ##       
##        ##     ## ##    ##  ##    ## ##       
##        ##     ## ##     ##  ######  ######## 
 
 ######  #### ######## ########                 
##    ##  ##       ##  ##                       
##        ##      ##   ##                       
 ######   ##     ##    ######                   
      ##  ##    ##     ##                       
##    ##  ##   ##      ##                       
 ######  #### ######## ########                 

 ]#

proc parseSizeStr*(sizeStr:string): tuple[unit:MeasurementUnit,value:int]=
  ## relative sizeStr parser for controlls
  var
    value:int

  if sizeStr == "auto":
    result.unit = muAuto
  elif sizeStr == "stretch":
    result.unit = muStretch
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



#proc recalcFlex*(this: DivRef)#!FWD


#[

 ######  ######## ##    ## ##       ########  ######  
##    ##    ##     ##  ##  ##       ##       ##    ## 
##          ##      ####   ##       ##       ##       
 ######     ##       ##    ##       ######    ######  
      ##    ##       ##    ##       ##             ## 
##    ##    ##       ##    ##       ##       ##    ## 
 ######     ##       ##    ######## ########  ######  

 ]#


proc newStyleSheetRef_Tbl*(): StyleSheetRef_Tbl =
  ## init controlls StyleSheetSeq
  newTable[string, StyleSheetRef](8)


proc newStyleSheet*(): StyleSheetRef =
  result = new(StyleSheetRef)

  result.flexGrow = -1
  result.flexGrowFrom = -1

  result.flexDirection = fdUndefined
  result.justifyContent = fjcUndefined
  result.alignContent = facUndefined
  result.alignItems = faiUndefined

  result.color = EmptyColor
  result.backGroundColor = EmptyColor

  result.padding = -1
  result.spacing = -1


proc clearStyleSheet*(s: StyleSheetRef) =
  s.flexGrow = -1
  s.flexGrowFrom = -1

  s.flexDirection = fdUndefined
  s.justifyContent = fjcUndefined
  s.alignContent = facUndefined
  s.alignItems = faiUndefined

  s.color = EmptyColor
  s.backGroundColor = EmptyColor

  s.padding = -1
  s.spacing = -1


proc addPseudoStyle*(parent, child: StyleSheetRef, childName :string)=
  if parent.pseudoStyles == nil:
    parent.pseudoStyles = newTable[string, StyleSheetRef](4)
  parent.pseudoStyles[childName] = child

proc addNewPseudoStyle*(parent: StyleSheetRef, childName :string)=
  if parent.pseudoStyles == nil:
    parent.pseudoStyles = newTable[string, StyleSheetRef](4)
  parent.pseudoStyles[childName] = newStyleSheet()

#import styles from styleshhet
proc `<-`*(t: StyleSheetRef, s: StyleSheetRef)=
  if s.flexGrow > -1: t.flexGrow = s.flexGrow
  if s.flexGrowFrom > -1: t.flexGrowFrom = s.flexGrowFrom
  if s.flexDirection != fdUndefined: t.flexDirection = s.flexDirection
  if s.justifyContent != fjcUndefined: t.justifyContent = s.justifyContent
  if s.alignContent != facUndefined: t.alignContent = s.alignContent
  if s.alignItems != faiUndefined: t.alignItems = s.alignItems
  if s.color != EmptyColor :
    t.color = s.color
    #echo "<- t.color.r ", t.color.r.int
  if s.backGroundColor != EmptyColor : t.backGroundColor = s.backGroundColor
  if s.borderColor != EmptyColor : t.borderColor = s.borderColor
  if s.font != "" : t.font = s.font
  #echo t.padding, " <- ", s.padding
  if s.padding > -1: t.padding = s.padding
  if s.spacing > -1: t.spacing = s.spacing

template updateWith*(t: StyleSheetRef, s: StyleSheetRef)=
  t <- s


#proc `<=`*(a: var )
#[
if no styles:
  rootElem stores the FULL CSS, it uses body, body:hover
  rootelem should have defaults
  lookup for:
    style[firmware]
    style[body]
    style[parent]
    style[elemtype]
    style[elemname]

    copy unknown from upper classes
]#

