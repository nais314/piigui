
import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases

import piigui/types
import piigui/layout/flex
import piigui/layout/recalcH as recalcHMod
import piigui/layout/recalcV as recalcVMod
import tables
import locks

#######################################################


##[
    i dont create the option for multiple stylesheets,
    the storing should be like wordpress stores its database
    with "wp_" prefix.
    so a "blue_", "admin_" styleSheet can be stored in 
    the only one stylsheet.
    it keeps it simple
]##
# TODO: add default hover style, and add to controlls!


#######################################################


#[ 
       ######   ######  ########  ######## 
      ##    ## ##    ## ##     ##    ##    
      ##       ##       ##     ##    ##    
       ######   ######  ########     ##    
            ##       ## ##   ##      ##    
      ##    ## ##    ## ##    ##     ##    
       ######   ######  ##     ##    ##     
]#




#[ proc newColor*(r, g, b, a: uint8): SdlColorRef =
  new(result)
  result[] = (r: r, g: g, b: b, a: a)

let opaqueWhiteColor* = newColor(r = 255'u8, g = 255'u8, b = 255'u8, a = 255'u8) ]#

proc rgbaColor*(r:int, g:int, b:int, a:int): sdl.Color=
  return sdl.Color(r: r.uint8, g: g.uint8, b: b.uint8, a: a.uint8)

#[ 
# colors moved to types.nim
let transparentColor* = sdl.Color((r:50'u8,g:50'u8,b:50'u8,a:0'u8))
let blackColor* = rgbaColor(r=0,g=0,b=0,a=255)
let bgColor* = rgbaColor(r=200,g=200,b=184,a=255) ]#

#*=================================================
var rootSSRT* = newStyleSheetRef_Tbl()
#*=================================================

rootSSRT["rootStyle"] = StyleSheetRef(
  ## default style for every elem, see recalc
  ## it has sane defaults, it is not empty
  ## for styles like "bold" or "hover"
  ## - which are mostly empty eg
  ## not overwriting undefined style properties -
  ## use proc newStyleSheet*(): StyleSheetRef
  flexGrow: -1,
  flexGrowFrom: 0,
  flexDirection: fdColumn,
  #flexWrap: false,
  justifyContent: fjcCenter,
  alignContent: facStart, #? why not facCenter ?
  alignItems: faiCenter,
  spacing: -1,
  color: blackColor, #sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8)),
  backGroundColor: bgColor, #sdl.Color((r:200'u8,g:186'u8,b:163'u8,a:255'u8)),
  #borderColor: EmptyColor, #(r:55'u8, g:55'u8, b:55'u8, a:255'u8),
  font:0, # Regular Mono font, 16pt
  overFlow: ofScroll,
  #position: posAbsolute
  padding: -1
)

rootSSRT["row"] = StyleSheetRef(
  flexGrow: -1,
  flexGrowFrom: 0,
  flexDirection: fdRow,
  #flexWrap: true,
  justifyContent: fjcCenter,
  alignContent: facCenter,
  alignItems: faiCenter,
  spacing: -1,
  #color: transparentColor,
  #backGroundColor: EmptyColor,
  padding: -1
)

rootSSRT["column"] = StyleSheetRef(
  flexGrow: -1,
  flexGrowFrom: 0,
  flexDirection: fdColumn,
  #flexWrap: true,
  justifyContent: fjcCenter,
  alignContent: facCenter,#facSpaceAround,
  alignItems: faiCenter,
  spacing: -1,
  #color: sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8)),
  #backGroundColor: sdl.Color((r:46'u8,g:38'u8,b:31'u8,a:255'u8)),
  padding: -1
)



rootSSRT["bold"] = StyleSheetRef(
  font:1
)
rootSSRT["H2"] = StyleSheetRef(
  font:2
)
rootSSRT["H1"] = StyleSheetRef(
  font:3
)






#######################################################


#[ 
     ######  ######## ##    ## ##       ########  ######  
    ##    ##    ##     ##  ##  ##       ##       ##    ## 
    ##          ##      ####   ##       ##       ##       
     ######     ##       ##    ##       ######    ######  
          ##    ##       ##    ##       ##             ## 
    ##    ##    ##       ##    ##       ##       ##    ## 
     ######     ##       ##    ######## ########  ######  
 ]#


template initStyleCache(theStyleSheetRef_Tbl: StyleSheetRef_Tbl)=
  ## re/initialize stylesheet table with defaults
  theStyleSheetRef_Tbl.clear()
  theStyleSheetRef_Tbl["default"] = newStyleSheet() #! start
  theStyleSheetRef_Tbl["default"] <- rootSSRT["rootStyle"]

#...................................

#TODO use, test, evaluate
proc addOrUpdate*(target: TableRef[string, StyleSheetRef],
                  styleName: string,
                  style:StyleSheetRef)=
  if target.hasKey(styleName):
    target[styleName] <- style
  else:
    target[styleName] = style

#...................................

# hexcolor, human readable, online pickable
proc setBackGroundColor*(this:StyleSheetRef,
                          col:HexColor)=
  this.backGroundColor.r = ((col shr 24) and 0xFF).uint8
  this.backGroundColor.g = ((col shr 16) and 0xFF).uint8
  this.backGroundColor.b = ((col shr 8) and 0xFF).uint8
  this.backGroundColor.a = ( col and 0xFF).uint8

proc setColor*(this:StyleSheetRef,
                col:HexColor)=
  this.color.r = ((col shr 24) and 0xFF).uint8
  this.color.g = ((col shr 16) and 0xFF).uint8
  this.color.b = ((col shr 8) and 0xFF).uint8
  this.color.a = ( col and 0xFF).uint8

proc setBorderColor*(this:StyleSheetRef,
                      col:HexColor)=
  this.borderColor.r = ((col shr 24) and 0xFF).uint8
  this.borderColor.g = ((col shr 16) and 0xFF).uint8
  this.borderColor.b = ((col shr 8) and 0xFF).uint8
  this.borderColor.a = ( col and 0xFF).uint8

# int to uint8 helpers
proc setBackGroundColor*(this:StyleSheetRef,
                         r,g,b,a:int)=
  this.backGroundColor.r = r.uint8
  this.backGroundColor.g = g.uint8
  this.backGroundColor.b = b.uint8
  this.backGroundColor.a = a.uint8

proc setColor*(this:StyleSheetRef,
               r,g,b,a:int)=
  this.color.r = r.uint8
  this.color.g = g.uint8
  this.color.b = b.uint8
  this.color.a = a.uint8

proc setBorderColor*(this:StyleSheetRef,
                         r,g,b,a:int)=
  this.borderColor.r = r.uint8
  this.borderColor.g = g.uint8
  this.borderColor.b = b.uint8
  this.borderColor.a = a.uint8
#______________________________________


#[ 
                                    dP          
                                    88          
88d888b. .d8888b. .d8888b. .d8888b. 88 .d8888b. 
88'  `88 88ooood8 88'  `"" 88'  `88 88 88'  `"" 
88       88.  ... 88.  ... 88.  .88 88 88.  ... 
dP       `88888P' `88888P' `88888P8 dP `88888P' 
                                                
########  ########  ######     ###    ##        ######  
##     ## ##       ##    ##   ## ##   ##       ##    ## 
##     ## ##       ##        ##   ##  ##       ##       
########  ######   ##       ##     ## ##       ##       
##   ##   ##       ##       ######### ##       ##       
##    ##  ##       ##    ## ##     ## ##       ##    ## 
##     ## ########  ######  ##     ## ########  ######  
 ]#

#*=================================================
#*           RECALCULATE STYLESSHEETS
#*=================================================

proc recalcStyle*(this:DivRef, recursive:bool=false){.gcsafe.}=
  ## recalculate styleCache from:
  ## - default style ("*")
  ## - parent style
  ## - elem styles (typeName, group, name)
  ## - this.styles seq and inlineStyle
  ##
  ## + pseudo styles (hover, even, odd, ...) if any
  ##
  ## Cascade order (default and pseudostyles alike):
  ##   "*" -> parent -> typeName -> group -> name
  ##   -> this.styles -> inlineStyle

  if this.styleCache == nil: return # e.g. bare BRElem line-break markers
  {.gcsafe.}:

    #--------------------------------------------
    #* COLLECT MATCHING STYLES IN CASCADE ORDER
    #--------------------------------------------
    var
      matched: seq[StyleSheetRef] = @[]
      wildcard: StyleSheetRef
      parentSrc: StyleSheetRef
      typeSrc: StyleSheetRef
      groupSrc: StyleSheetRef
      nameSrc: StyleSheetRef

    if rootSSRT.hasKey("*"):
      wildcard = rootSSRT["*"]
      matched.add(wildcard)
    if this.parent != nil and this.parent.styleCache != nil:
      parentSrc = this.parent.styleCache.getOrDefault(this.parent.activeStyle)
      matched.add(parentSrc)
    if rootSSRT.hasKey(this.typeName):
      typeSrc = rootSSRT[this.typeName]
      matched.add(typeSrc)
    if rootSSRT.hasKey(this.group):
      groupSrc = rootSSRT[this.group]
      matched.add(groupSrc)
    if rootSSRT.hasKey(this.name):
      nameSrc = rootSSRT[this.name]
      matched.add(nameSrc)
    for style in this.styles:
      matched.add(style.style)
    matched.add(this.inlineStyle)

    #--------------------------------------------
    #* INIT STYLE CACHE - ELEM STYLE
    #--------------------------------------------
    this.styleCache.initStyleCache() # creates this.styleCache["default"] too!

    #--------------------------------------------
    #* ASSEMBLE "default"
    #--------------------------------------------
    for style in matched:
      if style != nil:
        this.styleCache["default"] <- style

    #--------------------------------------------
    #* ASSEMBLE PSEUDOSTYLES (same cascade order)
    #--------------------------------------------
    template mergePseudo(pkey: string, pstyle: StyleSheetRef) =
      if pkey != "default" and pstyle != nil:
        if not this.styleCache.hasKey(pkey):
          this.styleCache[pkey] = newStyleSheet()
          this.styleCache[pkey] <- this.styleCache["default"]
        this.styleCache[pkey] <- pstyle

    template mergePseudos(source: StyleSheetRef) =
      if source != nil and source.pseudoStyles != nil:
        for pkey, pstyle in source.pseudoStyles:
          mergePseudo(pkey, pstyle)

    mergePseudos(wildcard)
    mergePseudos(typeSrc)
    mergePseudos(groupSrc)
    mergePseudos(nameSrc)
    for style in this.styles:
      mergePseudos(style.style)
    mergePseudos(this.inlineStyle)

    #--------------------------------------------
    # finally
    #--------------------------------------------

    this.redrawFlag = 1

    if not this.styleCache.hasKey(this.activeStyle): #safeguard
      this.activeStyle = "default"

    if recursive:
      for layer in this.layers:
        for i_elem in 0..layer.elems.high:
          layer.elems[i_elem].recalcStyle(recursive=true)

    #[ for layer in this.layers:
      for i_elem in 0..layer.elems.high:
        if recursive:
          layer.elems[i_elem].recalcStyle(recursive=true)
        else:
          layer.elems[i_elem].redrawFlag = 1 ]#


#######################################################


#[ 
   ###    ########  ########                              
  ## ##   ##     ## ##     ##                             
 ##   ##  ##     ## ##     ##                             
##     ## ##     ## ##     ##                             
######### ##     ## ##     ##                             
##     ## ##     ## ##     ##                             
##     ## ######## ##     ##                              


 ########  ######## ##     ##  #######  ##     ## ######## 
##     ## ##       ###   ### ##     ## ##     ## ##       
##     ## ##       #### #### ##     ## ##     ## ##       
########  ######   ## ### ## ##     ## ##     ## ######   
##   ##   ##       ##     ## ##     ##  ##   ##  ##       
##    ##  ##       ##     ## ##     ##   ## ##   ##       
##     ## ######## ##     ##  #######     ###    ######## 

  ]#

#######################################################

#TODO use, test, evaluate
proc addStyle*(this:DivRef,
               style:tuple[name:string,
                           style:StyleSheetRef],
               recalcChilds:bool=true) {.gcsafe.} =
  ## push a style in the style sequence
  ## DivRef.styles must be ordered, and named at once
  ## use `recalcChilds = false` for micro-optimisation
  this.styles.add(style)
  this.recalcStyle(recalcChilds)

#TODO use, test, evaluate
proc addStyle*(this:DivRef,
               styleName:string,
               recalcChilds:bool=true) {.gcsafe.} =
  ## push a style in the style sequence
  ## DivRef.styles must be ordered, and named at once
  ## use `recalcChilds = false` for micro-optimisation
  {.gcsafe.}:
    this.styles.add((styleName, rootSSRT[styleName]))
  this.recalcStyle(recalcChilds)
  #[ for style in this.styles:
    echo style.name ]#

#TODO use, test, evaluate
proc removeStyle*(this:DivRef,
                  name:string,
                  recalcChildrenStyles:bool=true) {.gcsafe.} =
  ## delete a style from the style sequence
  ## DivRef.styles must be ordered, and named at once
  ## use `recalcChildrenStyles = false` for micro-optimisation
  for i in 0..this.styles.high:
    if this.styles[i].name == name:
      this.styles.delete(i)
  this.recalcStyle(recalcChildrenStyles)


proc setActiveStyle*(this:DivRef, styleName:string,
                     recalcChildrenStyles:bool=false)=
  ## recalcChildrenStyles is false by default
  ## as more pseudoStyle changes like
  ## hovering, dragging occurs than Theme change
  ## in the app,
  ## and this is way faster.
  ## But you should know when a big theme change needs
  ## to be inherited by children
  if this != nil:
    if styleName == this.activeStyle: return
    if this.styleCache.hasKey(styleName):
      if this.styleCache[styleName] != nil:
        this.prevStyle = this.activeStyle
        this.activeStyle = styleName
        this.redrawFlag = 1

        if recalcChildrenStyles:
          this.recalcStyle(recursive=true)
          
    #echo repr this.styleCache


proc setDefaultStyle*(this:DivRef,
                      recalcChildrenStyles:bool=false)=
  if this != nil:
    withLock this.lock:
      this.activeStyle = "default"
      if not recalcChildrenStyles:
        this.redrawFlag = 1
    if recalcChildrenStyles:
      this.recalcStyle(recursive=true)
#.........................


#######################################################


#[ 
#### ##    ## ##       #### ##    ## ######## 
 ##  ###   ## ##        ##  ###   ## ##       
 ##  ####  ## ##        ##  ####  ## ##       
 ##  ## ## ## ##        ##  ## ## ## ######   
 ##  ##  #### ##        ##  ##  #### ##       
 ##  ##   ### ##        ##  ##   ### ##       
#### ##    ## ######## #### ##    ## ######## 
 ]#

#######################################################

proc setBackGroundColor*(this:DivRef, color:sdl.Color)=
  this.inlineStyle.backGroundColor = color
  this.recalcStyle()

proc setBackGroundColor*(this:DivRef,
                      r:uint8=255,
                      g:uint8=255,
                      b:uint8=255,
                      a:uint8=255)=
  this.inlineStyle.backGroundColor.r = r
  this.inlineStyle.backGroundColor.g = g
  this.inlineStyle.backGroundColor.b = b
  this.inlineStyle.backGroundColor.a = a
  this.recalcStyle()

proc setBackGroundColor*(this:DivRef,
                        col:HexColor)=
  this.inlineStyle.backGroundColor.r = ((col shr 24) and 0xFF).uint8
  this.inlineStyle.backGroundColor.g = ((col shr 16) and 0xFF).uint8
  this.inlineStyle.backGroundColor.b = ((col shr 8) and 0xFF).uint8
  this.inlineStyle.backGroundColor.a = ( col and 0xFF).uint8
  this.recalcStyle()

  #[ echo (col shr 24) and 0xFF
  echo this.inlineStyle.backGroundColor.r.int
  echo this.inlineStyle.backGroundColor.g.int
  echo this.inlineStyle.backGroundColor.b.int
  echo this.inlineStyle.backGroundColor.a.int ]#

proc setBackGroundColor*(this:DivRef,
                      r:int=255,
                      g:int=255,
                      b:int=255,
                      a:int=255)=
  this.inlineStyle.backGroundColor.r = r.uint8
  this.inlineStyle.backGroundColor.g = g.uint8
  this.inlineStyle.backGroundColor.b = b.uint8
  this.inlineStyle.backGroundColor.a = a.uint8
  this.recalcStyle()

proc setBorderColor*(this:DivRef,
                      r:uint8=255,
                      g:uint8=255,
                      b:uint8=255,
                      a:uint8=255)=
  this.inlineStyle.borderColor.r = r
  this.inlineStyle.borderColor.g = g
  this.inlineStyle.borderColor.b = b
  this.inlineStyle.borderColor.a = a
  this.recalcStyle()

proc setBorderColor*(this:DivRef,
                     col:HexColor)=
  this.inlineStyle.borderColor.r = ((col shr 24) and 0xFF).uint8
  this.inlineStyle.borderColor.g = ((col shr 16) and 0xFF).uint8
  this.inlineStyle.borderColor.b = ((col shr 8) and 0xFF).uint8
  this.inlineStyle.borderColor.a = ( col and 0xFF).uint8
  this.recalcStyle()


proc setColor*(this:DivRef,
                      r:uint8=255,
                      g:uint8=255,
                      b:uint8=255,
                      a:uint8=255)=
  this.inlineStyle.color.r = r
  this.inlineStyle.color.g = g
  this.inlineStyle.color.b = b
  this.inlineStyle.color.a = a
  this.recalcStyle()

proc setColor*(this:DivRef,
                col:HexColor)=
  this.inlineStyle.color.r = ((col shr 24) and 0xFF).uint8
  this.inlineStyle.color.g = ((col shr 16) and 0xFF).uint8
  this.inlineStyle.color.b = ((col shr 8) and 0xFF).uint8
  this.inlineStyle.color.a = ( col and 0xFF).uint8
  this.recalcStyle()


proc setPadding*(this:DivRef, val:int= -1)=
  this.inlineStyle.padding = val
  this.recalcStyle()

proc setSpacing*(this:DivRef, val:int= -1)=
  this.inlineStyle.spacing = val
  this.recalcStyle()


# COLOR ###########################

proc toRGBA*(col:sdl.Color):uint32=
  result = col.r
  result = result shl 8
  result = result or col.g
  result = result shl 8
  result = result or col.b
  result = result shl 8
  result = result or col.a

proc lighten*(col:sdl.Color, val:uint8 = 50):sdl.Color=
  result.r = if (255 - col.r) < val: 255 else: col.r + val
  result.g = if (255 - col.g) < val: 255 else: col.g + val
  result.b = if (255 - col.b) < val: 255 else: col.b + val
  result.a = col.a

proc darken*(col:sdl.Color, val:uint8 = 50):sdl.Color=
  result.r = if col.r < val: 0 else: col.r - val
  result.g = if col.g < val: 0 else: col.g - val
  result.b = if col.b < val: 0 else: col.b - val
  result.a = col.a

proc buttonTextColor*(col:sdl.Color):sdl.Color=
  ## https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
  let lightness = (0.299 * col.r.float + 0.587 * col.g.float + 0.114 * col.b.float)
  if lightness > 100:
    result.r = 0
    result.g = 0
    result.b = 0
  else:
    result.r = 255
    result.g = 255
    result.b = 255
  result.a = 255
