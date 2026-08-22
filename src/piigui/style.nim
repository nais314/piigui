
import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui/types
import piigui/layout/flex
import piigui/layout/vhbox
import tables
import locks

###########################################

# TODO: add default hover style, and add to controlls!



###########################################
#[ 
##        ######   ######  ######## 
 ##      ##    ## ##    ##    ##    
  ##     ##       ##          ##    
   ##     ######   ######     ##    
  ##           ##       ##    ##    
 ##      ##    ## ##    ##    ##    
##        ######   ######     ##    
]#

#[ proc newColor*(r, g, b, a: uint8): SdlColorRef =
  new(result)
  result[] = (r: r, g: g, b: b, a: a)

let opaqueWhiteColor* = newColor(r = 255'u8, g = 255'u8, b = 255'u8, a = 255'u8) ]#

let clearColor* = sdl.Color((r:50'u8,g:50'u8,b:50'u8,a:0'u8))

var fontTable* = newTable[string, ttf.FontPtr](8)

var defaultSST* = newStyleSheetRef_Tbl()

defaultSST["rootStyle"] = StyleSheetRef(
  ## default style for every elem, see recalc
  flexGrow: 0,
  flexGrowFrom: 0,
  flexDirection: fdColumn,
  #flexWrap: false,
  justifyContent: fjcCenter,
  alignContent: facStart,
  alignItems: faiCenter,
  spacing: -1,
  color: sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8)),
  backGroundColor: sdl.Color((r:46'u8,g:38'u8,b:31'u8,a:255'u8)),
  font:"default",
  #overFlow: ofHidden,
  #position: posAbsolute
  padding: -1
)

defaultSST["row"] = StyleSheetRef(
  flexGrow: 1,
  flexGrowFrom: 75,
  flexDirection: fdRow,
  #flexWrap: true,
  justifyContent: fjcCenter,
  alignContent: facCenter,
  alignItems: faiCenter,
  spacing: -1,
  color: clearColor,
  backGroundColor: EmptyColor,
  padding: -1
)

defaultSST["column"] = StyleSheetRef(
  flexGrow: 1,
  flexGrowFrom: 66,
  flexDirection: fdColumn,
  #flexWrap: true,
  justifyContent: fjcCenter,
  alignContent: facCenter,#facSpaceAround,
  alignItems: faiCenter,
  spacing: -1,
  color: sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8)),
  backGroundColor: sdl.Color((r:46'u8,g:38'u8,b:31'u8,a:255'u8)),
  padding: -1
)

#GC_ref(defaultSST)







###########################################
#[ 
     ######  ######## ##    ## ##       ########  ######  
    ##    ##    ##     ##  ##  ##       ##       ##    ## 
    ##          ##      ####   ##       ##       ##       
     ######     ##       ##    ##       ######    ######  
          ##    ##       ##    ##       ##             ## 
    ##    ##    ##       ##    ##       ##       ##    ## 
     ######     ##       ##    ######## ########  ######  
 ]#
template init(theStyleSheetRef_Tbl: StyleSheetRef_Tbl)=
  ## re/initialize stylesheet table with defaults
  theStyleSheetRef_Tbl.clear()
  theStyleSheetRef_Tbl["default"] = newStyleSheet() #! start
  theStyleSheetRef_Tbl["default"] <- defaultSST["rootStyle"]

#...................................


proc addOrUpdate*(target: TableRef[string, StyleSheetRef],
                  styleName: string,
                  style:StyleSheetRef)=
  if target.hasKey(styleName):
    target[styleName] <- style
  else:
    target[styleName] = style

#...................................


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
proc recalcStyle*(this:DivRef, recursive:bool=false){.gcsafe.}=
  ## recalculate styleCache from:
  ## - default style
  ## - parent style
  ## - elem styles
  ## 
  ## + pseudo styles if any
  {.gcsafe.}:
    #[ if this.pseudoStyles == nil:
      echo "*** NO PSEUDOSTYLES **** ", this.name
      return ]#
    var
      #pseudoStyles = newTable[string, StyleSheetRef](4)
      pseudoStylesForAll = newStyleSheetRef_Tbl() #newTable[string, StyleSheetRef](4)
      typePseudoStyles = newStyleSheetRef_Tbl()
      groupPseudoStyles = newStyleSheetRef_Tbl()
      namedPseudoStyles = newStyleSheetRef_Tbl()
      #TODO inlinePseudoStyles = newStyleSheetRef_Tbl()

    var
      styleForAll = newStyleSheet()
      typeStyle = newStyleSheet()
      groupStyle = newStyleSheet()
      nameStyle = newStyleSheet()

    
    #[ this.styleCache.clear()
    this.styleCache["default"] = newStyleSheet() #! start
    this.styleCache["default"] <- defaultSST["rootStyle"] ]#
    this.styleCache.init()

    #* type style ***********
    for key in defaultSST.keys():

      if key == "*":
        styleForAll <- defaultSST[key]
                
        if defaultSST[key].pseudoStyles != nil:
          for pkey in defaultSST[key].pseudoStyles.keys():
            if pkey != "default":
              if not this.styleCache.hasKey(pkey): #then initialize with default
                this.styleCache[pkey] = newStyleSheet()
                this.styleCache[pkey] <- this.styleCache["default"]
                this.styleCache[pkey] <- styleForAll
              this.styleCache[pkey] <- defaultSST[key].pseudoStyles[pkey]
  
      #......................

      if key == this.typeName:
        #this.styles.add((name:key, style: defaultSST[key]))
        typeStyle <- defaultSST[key]
        
        if defaultSST[key].pseudoStyles != nil:
          for pkey in defaultSST[key].pseudoStyles.keys():
            if pkey != "default":
              if not this.styleCache.hasKey(pkey):
                this.styleCache[pkey] = newStyleSheet()
                this.styleCache[pkey] <- this.styleCache["default"]
                this.styleCache[pkey] <- typeStyle
              this.styleCache[pkey] <- defaultSST[key].pseudoStyles[pkey]

      #[ if key.len > this.typeName.len:
        if key[0..this.typeName.len] == this.typeName & ":" :
          #this.pseudoStyles.add(key[6..key.high], defaultSST[key])
          typePseudoStyles.addOrUpdate(key[this.typeName.len .. key.high], defaultSST[key]) ]#

      #......................

      if key == this.group:
        #pseudoStyles.addOrUpdate("default", defaultSST[key])
        groupStyle <- defaultSST[key]

        if defaultSST[key].pseudoStyles != nil:
          for pkey in defaultSST[key].pseudoStyles.keys():
            if pkey != "default":
              if not this.styleCache.hasKey(pkey):
                this.styleCache[pkey] = newStyleSheet()
                this.styleCache[pkey] <- this.styleCache["default"]
                this.styleCache[pkey] <- groupStyle
              this.styleCache[pkey] <- defaultSST[key].pseudoStyles[pkey]

      #[ # "groupname:hover"
      if key.len > this.group.len: #eg: buttonGroup:hover
        if key[0..this.group.len] == this.group & ':':
          groupPseudoStyles.addOrUpdate(
                key[this.group.len + 1 .. key.high],
                defaultSST[key]) ]#

      #......................

      if key == this.name:
        #echo "###### ", key
        #pseudoStyles.addOrUpdate("default", defaultSST[key])
        nameStyle <- defaultSST[key]
                
        if defaultSST[key].pseudoStyles != nil:
          for pkey in defaultSST[key].pseudoStyles.keys():
            #echo "###### ",this.name, " : ", pkey, " ######"
            if (pkey == "even" and this.nthChild mod 2 == 0) or
               (pkey == "odd" and this.nthChild mod 2 == 1):

              nameStyle <- defaultSST[key].pseudoStyles[pkey]
            
            elif pkey != "default":
              if not this.styleCache.hasKey(pkey):
                this.styleCache[pkey] = newStyleSheet()
                this.styleCache[pkey] <- this.styleCache["default"] # hint: rootStyle, font
                this.styleCache[pkey] <- nameStyle # hint: color
              this.styleCache[pkey] <- defaultSST[key].pseudoStyles[pkey]
            #echo "###### "
        else: echo " NOPSEUDOSTYLES ------"

      #[ if key.len > this.name.len: #eg: mybutton:hover
        if key[0..this.name.len] == this.name & ':':

          let pseudoStyleName = key[this.name.len + 1 .. key.high]
          if (pseudoStyleName == "even" and this.nthChild mod 2 == 0) or
            ( pseudoStyleName == "odd" and this.nthChild mod 2 == 1):

              nameStyle = defaultSST[key]
          
          else:
            namedPseudoStyles.addOrUpdate(pseudoStyleName, defaultSST[key]) ]#

    #.........................................
  
    # parent
    if this.parent != nil:
      #this.styleCache["default"] <- this.parent.pseudoStyles["default"]
      this.styleCache["default"] <- this.parent.styleCache["default"]

    # same type
    this.styleCache["default"] <- typeStyle

    # logical group
    this.styleCache["default"] <- groupStyle

    # name == its own style
    this.styleCache["default"] <- nameStyle

    # "classes"
    for style in this.styles:
      this.styleCache["default"] <- style.style

    #TODO: inline styling
    this.styleCache["default"] <- this.inlineStyle


    #.........................................
    # pseudostyles
    if pseudoStylesForAll.len > 1:
      for key in pseudoStylesForAll.keys:
        if key != "default":
          if not this.styleCache.hasKey(key):
            this.styleCache[key] = newStyleSheet()
            this.styleCache[key] <- this.styleCache["default"]
          this.styleCache[key] <- pseudoStylesForAll[key]

    if typePseudoStyles.len > 1:
      for key in typePseudoStyles.keys:
        if key != "default":
          if not this.styleCache.hasKey(key):
            this.styleCache[key] = newStyleSheet()
            this.styleCache[key] <- this.styleCache["default"]
          this.styleCache[key] <- typePseudoStyles[key]

    #[ parent pseudostyles left out intentionally ]#

    if groupPseudoStyles.len > 1:
      for key in groupPseudoStyles.keys:
        if key != "default":
          if not this.styleCache.hasKey(key):
            this.styleCache[key] = newStyleSheet()
            this.styleCache[key] <- this.styleCache["default"]
          this.styleCache[key] <- groupPseudoStyles[key]

    if namedPseudoStyles.len > 1:
      for key in namedPseudoStyles.keys:
        if key != "default":
          if not this.styleCache.hasKey(key):
            this.styleCache[key] = newStyleSheet()
            this.styleCache[key] <- this.styleCache["default"]
          this.styleCache[key] <- namedPseudoStyles[key]

    # "classes"
    for style in this.styles:
      if style.style.pseudoStyles != nil:
        for key in style.style.pseudoStyles.keys():
          if key != "default":
            if not this.styleCache.hasKey(key):
              this.styleCache[key] = newStyleSheet()
              this.styleCache[key] <- this.styleCache["default"]
            this.styleCache[key] <- style.style.pseudoStyles[key]


    
    # finally
    this.redrawFlag = 1


    if not this.styleCache.hasKey(this.activeStyle): #? needed?
      this.activeStyle = "default"



    
    for layer in this.layers:
      for i_elem in 0..layer.elems.high:
        #echo this.name, " >>>>>> ", i_elem, " = ", layer[i_elem].name
        if not (layer.elems[i_elem] of BRElem):
          layer.elems[i_elem].nthChild = i_elem + 1 # +1 for mod 2 - even/odd
          if recursive:
            layer.elems[i_elem].recalcStyle(recursive=true)
          else:
            layer.elems[i_elem].redrawFlag = 1

#[ 
   ###    ########  ########                              
  ## ##   ##     ## ##     ##                             
 ##   ##  ##     ## ##     ##                             
##     ## ##     ## ##     ##                             
######### ##     ## ##     ##                             
##     ## ##     ## ##     ##                             
##     ## ########  ########                              
 

########  ######## ##     ##  #######  ##     ## ######## 
##     ## ##       ###   ### ##     ## ##     ## ##       
##     ## ##       #### #### ##     ## ##     ## ##       
########  ######   ## ### ## ##     ## ##     ## ######   
##   ##   ##       ##     ## ##     ##  ##   ##  ##       
##    ##  ##       ##     ## ##     ##   ## ##   ##       
##     ## ######## ##     ##  #######     ###    ######## 
 ]#

proc addStyle*(this:DivRef,
               style:tuple[name:string,
                           style:StyleSheetRef],
               recalcChilds:bool=true) {.gcsafe.} =
  ## push a style in the style sequence
  ## DivRef.styles must be ordered, and named at once
  ## use `recalcChilds = false` for micro-optimisation
  this.styles.add(style)
  this.recalcStyle(recalcChilds)


proc addStyle*(this:DivRef,
               styleName:string,
               recalcChilds:bool=true) {.gcsafe.} =
  ## push a style in the style sequence
  ## DivRef.styles must be ordered, and named at once
  ## use `recalcChilds = false` for micro-optimisation
  {.gcsafe.}:
    this.styles.add((styleName, defaultSST[styleName]))
  this.recalcStyle(recalcChilds)
  #[ for style in this.styles:
    echo style.name ]#


proc removeStyle*(this:DivRef,
                  name:string,
                  recalcChilds:bool=true) {.gcsafe.} =
  ## delete a style from the style sequence
  ## DivRef.styles must be ordered, and named at once
  ## use `recalcChilds = false` for micro-optimisation
  for i in 0..this.styles.high:
    if this.styles[i].name == name:
      this.styles.delete(i)
  this.recalcStyle(recalcChilds)

#TODO can be changed to a system where only pseudostyle is 
#TODO stored - because activestyle is always "default"
#TODO wich is modifyed with add/remove style procs
#TODO and recalculated
proc setActiveStyle*(this:DivRef, styleName:string)=
  if this != nil:
    if this.styleCache.hasKey(styleName):
      if this.styleCache[styleName] != nil:
        this.prevStyle = this.activeStyle
        this.activeStyle = styleName
        this.redrawFlag = 1
#[ proc setDefaultStyle*(this:DivRef)=
  if this != nil:
    if this.prevStyle != "":
      this.activeStyle = this.prevStyle
    this.redrawFlag = 1 ]#
proc setDefaultStyle*(this:DivRef)=
  if this != nil:
    withLock this.lock:
      this.activeStyle = "default"
      this.redrawFlag = 1
#.........................


#[ 
#### ##    ## ##       #### ##    ## ######## 
 ##  ###   ## ##        ##  ###   ## ##       
 ##  ####  ## ##        ##  ####  ## ##       
 ##  ## ## ## ##        ##  ## ## ## ######   
 ##  ##  #### ##        ##  ##  #### ##       
 ##  ##   ### ##        ##  ##   ### ##       
#### ##    ## ######## #### ##    ## ######## 
 ]#

#--------------------------------------
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

#[ proc lighten*(col:sdl.Color, val:uint8 = 25):sdl.Color=
  result.r = if (255 - col.r) < val: 255 else: col.r + val
  result.g = if (255 - col.g) < val: 255 else: col.g + val
  result.b = if (255 - col.b) < val: 255 else: col.b + val
  result.a = col.a ]#

proc darken*(col:sdl.Color, val:uint8 = 25):sdl.Color=
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