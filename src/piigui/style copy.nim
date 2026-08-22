
import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf

import piigui/types
import piigui/layout/flex
import piigui/layout/vhbox
import tables

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

let clearColor* = sdl.Color((r:50'u8,g:50'u8,b:50'u8,a:0'u8))

var fontTable* = newTable[string, ttf.FontPtr](8)

var defaultSST* = newStyleSheetTbl()

defaultSST["rootStyle"] = StyleSheetRef(
  flexGrow: 0,
  flexGrowFrom: 0,
  flexDirection: fdColumn,
  #flexWrap: false,
  justifyContent: fjcCenter,
  alignContent: facStart,
  alignItems: faiCenter,
  color: (r:255'u8,g:255'u8,b:255'u8,a:255'u8),
  backGroundColor: (r:46,g:38,b:31,a:255),
  font:"default",
  #overFlow: ofHidden,
  #position: posAbsolute
  padding: -1 #8
)

defaultSST["row"] = StyleSheetRef(
  flexGrow: 1,
  flexGrowFrom: 75,
  flexDirection: fdRow,
  #flexWrap: true,
  justifyContent: fjcCenter,
  alignContent: facCenter,
  alignItems: faiCenter,
  color: (r:255'u8,g:255'u8,b:255'u8,a:255'u8),
  backGroundColor: (r:46,g:38,b:31,a:255),
  padding: -1
)

defaultSST["column"] = StyleSheetRef(
  flexGrow: 1,
  flexGrowFrom: 66,
  flexDirection: fdColumn,
  #flexWrap: true,
  justifyContent: fjcCenter,
  alignContent: facSpaceAround,
  alignItems: faiCenter,
  color: (r:255'u8,g:255'u8,b:255'u8,a:255'u8),
  backGroundColor: (r:46,g:38,b:31,a:255),
  padding: -1
)

GC_ref(defaultSST)







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


proc addOrUpdate*(target: TableRef[string, StyleSheetRef],
                  styleName: string,
                  style:StyleSheetRef)=
  if target.hasKey(styleName):
    target[styleName] <- style
  else:
    target[styleName] = style


#______________________________________



proc recalcStyle*(this:DivRef, recursive:bool=false){.gcsafe.}=
  ## recalculate styleCache from:
  ## - default style
  ## - parent style
  ## - lem styles
  ## 
  ## + pseudo styles if any
  {.gcsafe.}:
    #[ if this.pseudoStyles == nil:
      echo "*** NO PSEUDOSTYLES **** ", this.name
      return ]#
    var
      pseudoStyles = newTable[string, StyleSheetRef](4)

    var
      styleForAll = newStyleSheet()
      typeStyle = newStyleSheet()
      groupStyle = newStyleSheet()

    #* type style ***********
    for key in defaultSST.keys():
      #......................
      if key == "*":
        this.styles.add((name:key, style: defaultSST[key]))
      if key.len > 2:
        if key[0..1] == "*:":
          pseudoStyles.addOrUpdate(key[2..key.high], defaultSST[key])
      
      #......................

      if key == this.typeName:
        this.styles.add((name:key, style: defaultSST[key]))
      if key.len > this.typeName.len:
        if key[0..this.typeName.len] == this.typeName & ":" :
          #this.pseudoStyles.add(key[6..key.high], defaultSST[key])
          pseudoStyles.addOrUpdate(key[this.typeName.len .. key.high], defaultSST[key])

      #......................

      if key == this.group:
        pseudoStyles.addOrUpdate("default", defaultSST[key])
      
      if key.len > this.group.len: #eg: buttonGroup:hover
        if key[0..this.group.len] == this.group & ':':
          pseudoStyles.addOrUpdate(key[this.group.len + 1 .. key.high],
                                   defaultSST[key])

    # todo breadCrumbStyle "DivRef Label" "ul li"

    #* named styles / pseudo styles *******
    # replaces object pseudostyles
    for key in defaultSST.keys():
      if key == this.name:
        pseudoStyles.addOrUpdate("default", defaultSST[key])
      
      if key.len > this.name.len: #eg: mybutton:hover
        if key[0..this.name.len] == this.name & ':':
          #echo "*** key[0..this.name.len]  ", key, ", ", key[this.name.len + 1 .. key.high]
          let pseudoStyleName = key[this.name.len + 1 .. key.high]
          if (pseudoStyleName == "even" and this.nthChild mod 2 == 0) or
            ( pseudoStyleName == "odd" and this.nthChild mod 2 == 1):

              pseudoStyles.addOrUpdate("default", defaultSST[key])
          
          else:

            pseudoStyles.addOrUpdate(pseudoStyleName, defaultSST[key])
            

    #* calc activestyle .......................

    this.styleCache.clear()
    this.styleCache["default"] = newStyleSheet() #! start

    # if this is not styled
    var hasOwnStyle:bool=true
    if not pseudoStyles.hasKey("default"):
      pseudoStyles["default"] = newStyleSheet()
      #system.deepCopy(pseudoStyles[this.name], defaultSST["rootStyle"])
      pseudoStyles["default"] <- defaultSST["rootStyle"]
      hasOwnStyle = false

    # INIT this.styleCache["default"]
    this.styleCache["default"] <- pseudoStyles["default"]


    # parents
    if this.parent != nil:
      #this.styleCache["default"] <- this.parent.pseudoStyles["default"]
      this.styleCache["default"] <- this.parent.styleCache["default"]

    # named == its own style
    if hasOwnStyle:
      this.styleCache["default"] <- pseudoStyles["default"]

    # "classes"
    for style in this.styles:
      this.styleCache["default"] <- style.style

      # todo style pseudostyles ?
      #[ for key in defaultSST.keys():
        if key.len > this.name.len: #eg: mybutton:hover
          if key[0..this.name.len] == this.name & ':':
            #echo "*** key[0..this.name.len]  ", key, ", ", key[this.name.len + 1 .. key.high]
            let pseudoStyleName = key[this.name.len + 1 .. key.high]
            if (pseudoStyleName == "even" and this.nthChild mod 2 == 0) or
              ( pseudoStyleName == "odd" and this.nthChild mod 2 == 1):

                pseudoStyles.addOrUpdate("default", defaultSST[key])
            
            else:
              pseudoStyles.addOrUpdate(pseudoStyleName, defaultSST[key]) ]#
              

    # inline styling
    this.styleCache["default"] <- this.inlineStyle

    #[ proc `$`(c:SdlColorRef):string=
      if c != nil:
        result = $c.r.int & ", " & $c.g.int & ", " & $c.b.int & ", " & $c.a.int
    for field in this.inlineStyle[].fields:
      echo field ]#
    
    # other pseudostyles
    if pseudoStyles.len > 1:
      for key in pseudoStyles.keys:
        if key != "default":
          this.styleCache[key] = newStyleSheet()
          this.styleCache[key] <- this.styleCache["default"]
          this.styleCache[key] <- pseudoStyles[key]
          #echo this.name, " -- ", key


    
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

proc setBackGroundColor*(this:DivRef,
                      r:uint8=255,
                      g:uint8=255,
                      b:uint8=255,
                      a:uint8=255)=
  if this.inlineStyle.backGroundColor == nil:
    this.inlineStyle.backGroundColor = new SdlColorRef
  this.inlineStyle.backGroundColor.r = r
  this.inlineStyle.backGroundColor.g = g
  this.inlineStyle.backGroundColor.b = b
  this.inlineStyle.backGroundColor.a = a
  this.recalcStyle()

proc setBackGroundColor*(this:DivRef,
                        col:uint32)=
  if this.inlineStyle.backGroundColor == nil:
    this.inlineStyle.backGroundColor = new SdlColorRef
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
  if this.inlineStyle.borderColor == nil:
    this.inlineStyle.borderColor = new SdlColorRef
  this.inlineStyle.borderColor.r = r
  this.inlineStyle.borderColor.g = g
  this.inlineStyle.borderColor.b = b
  this.inlineStyle.borderColor.a = a
  this.recalcStyle()

proc setBorderColor*(this:DivRef,
                     col:uint32)=
  if this.inlineStyle.borderColor == nil:
    this.inlineStyle.borderColor = new SdlColorRef
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
  if this.inlineStyle.color == nil:
    this.inlineStyle.color = new SdlColorRef
  this.inlineStyle.color.r = r
  this.inlineStyle.color.g = g
  this.inlineStyle.color.b = b
  this.inlineStyle.color.a = a
  this.recalcStyle()

proc setColor*(this:DivRef,
                col:uint32)=
  if this.inlineStyle.color == nil:
    this.inlineStyle.color = new SdlColorRef
  this.inlineStyle.color.r = ((col shr 24) and 0xFF).uint8
  this.inlineStyle.color.g = ((col shr 16) and 0xFF).uint8
  this.inlineStyle.color.b = ((col shr 8) and 0xFF).uint8
  this.inlineStyle.color.a = ( col and 0xFF).uint8
  this.recalcStyle()


proc setPadding*(this:DivRef, val:int= -1)=
  this.inlineStyle.padding = val
  this.recalcStyle()