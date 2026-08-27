import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf
import piigui
import piigui/[types,style]
import piigui/layout/flex
import piigui/layout/vhbox
import tables
import unicode
import locks

#import random

type TextBox* = ref object of DivRef
  val*: string
  cursorPos*: int

#----------------------------------------------------
#[ 
##    ## ######## ##      ## 
###   ## ##       ##  ##  ## 
####  ## ##       ##  ##  ## 
## ## ## ######   ##  ##  ## 
##  #### ##       ##  ##  ## 
##   ### ##       ##  ##  ## 
##    ## ########  ###  ###  
 ]#


proc default_onFocus*(this:DivRef){.nosinks.}=
  piigui.default_onFocus(this)
  sdl.startTextInput()

proc default_onBlur*(this:DivRef){.nosinks.}=
  sdl.stopTextInput()

proc default_onTextInput*(this: DivRef, val:string){.nosinks.}=
      #[ this.val &= val
      this.cursorPos += 1 # = val.runeLen.uint
      this.redrawFlag = 1 ]#
      let self = TextBox(this)
      if self.cursorPos == 0:
        self.val = val & self.val
      elif self.cursorPos == self.val.runeLen:
        self.val &= val
      else:
        self.val = self.val.runeSubStr(0, self.cursorPos ) &
                    val &
                    self.val.runeSubStr(self.cursorPos)
      self.cursorPos += val.runeLen
      self.redrawFlag = 1


proc draw*(self:DivRef) #!FWD

proc newTextBox*(parent: DivRef,
             layer:int = 0,
             name: string,
             group: string,
             width: string="auto",
             height: string="auto",
             recalcFun: proc(this:DivRef, layer:Layer): tuple[w: int, h: int] = recalcFlex,
             styles: openArray[string] = []
             ): TextBox =
  const debug = 0b0

  result = new TextBox
  initLock(result.lock)
  result.typeName = "TextBox"
  result.iD = piigui.getNextGlobalID()

  result.val = "" #TODO

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
  result.redrawFlag = 1
  result.isRecalculated = false

  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)

  #DEBUG FALLBACK
  #result.activeStyle = defaultSST["column"]
   
  for style in styles:
    result.styles.add((style, defaultSST[style]))

  result.activeStyle = "default"
  recalcStyle(result)

  result.draw = draw

  result.onFocus = textbox.default_onFocus
  result.onBlur = textbox.default_onBlur
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = piigui.default_onDragEnd
  result.onDragOver = piigui.default_onDragOver

  result.onTextInput = textbox.default_onTextInput


  if parent != nil : parent.layers[layer].elems.add(result)
  when debug > 0:
    echo "newDiv result.w_value ", name, ": ", (result.w_unit, result.w_value)
    echo "newDiv result.h_value ", name, ": ", (result.h_unit, result.h_value)
    echo ""

#----------------------------------------------------
#[

########  ########   #######   ######  
##     ## ##     ## ##     ## ##    ## 
##     ## ##     ## ##     ## ##       
########  ########  ##     ## ##       
##        ##   ##   ##     ## ##       
##        ##    ##  ##     ## ##    ## 
##        ##     ##  #######   ######  
                         
]#

proc `value=`*(this: TextBox, val:string)=
  withLock this.lock:
    this.val = val
    this.cursorPos = val.runeLen
  this.redrawFlag = 1


proc value*(this: TextBox):string= this.val


#----------------------------------------------------




#[ 
########  ########     ###    ##      ## 
##     ## ##     ##   ## ##   ##  ##  ## 
##     ## ##     ##  ##   ##  ##  ##  ## 
##     ## ########  ##     ## ##  ##  ## 
##     ## ##   ##   ######### ##  ##  ## 
##     ## ##    ##  ##     ## ##  ##  ## 
########  ##     ## ##     ##  ###  ###  
 ]#


proc draw*(self:DivRef)=
  ## calculate inner x,y,w,h,etc
  ## if update only
  ## if visible
  withLock self.lock:
    let this = TextBox(self)

    const debug = 0b0

    when debug > 0:
      echo "draw()"
      echo this.name
      echo "w: ",this.w, " h: ", this.h
      echo "x1: ",this.x1, " y1: ", this.y1
      echo "___________"

    #.............................
    # clipRect hides overflow
    var clipRect: sdl.Rect
    if this.parent == nil:
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

    # canvasRect is the rect we can paint
    # after
    # sdl.setRenderTarget(this.pgui.renderer, this.textureCache) 
    var canvasRect: sdl.Rect
    canvasRect.x = 0.cint
    canvasRect.y = 0.cint
    canvasRect.w = this.w.cint
    canvasRect.h = this.h.cint

    #.............................

    # the area to paint to
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
      # todo setup cahce at recalc
      if this.textureCache == nil:
        this.textureCache = sdl.createTexture(
          this.pgui.renderer,
          sdl.SDL_PIXELFORMAT_UNKNOWN,#PIXELFORMAT_RGBA8888,
          sdl.SDL_TEXTUREACCESS_TARGET,
          this.w.cint,
          this.h.cint)
        discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

      # the elems. texture is the render target x=0 y=0!
      discard sdl.setRenderTarget(this.pgui.renderer, this.textureCache)
      this.pgui.renderer.setDrawColor(clearColor)
      discard this.pgui.renderer.clear()
      #.............................


      # get font heigth
      var fh = this.pgui.fonts[
                  this.styleCache[this.activeStyle].font
                  ].fontHeight() + 2

      if canvasRect.h > fh:
        canvasRect.y = (canvasRect.h - fh) div 2
        canvasRect.h = fh

      # draw the elem
      if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
        this.pgui.renderer.setDrawColor(
          this.styleCache[this.activeStyle].backGroundColor)

      discard this.pgui.renderer.fillRect(addr(canvasRect))

      # draw border
      if this.styleCache[this.activeStyle].borderColor != EmptyColor:
        this.pgui.renderer.setDrawColor(
          this.styleCache[this.activeStyle].borderColor)
      discard this.pgui.renderer.drawRect(addr(canvasRect))


      #=====================================
      #[ discard this.pgui.renderer.setRenderDrawColor(
          this.styleCache[this.activeStyle].backGroundColor) ]#
      # render text --- render text --- render text ---
      var
        fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8))
        fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:1'u8))

      #var surface = this.pgui.font_normal.renderUTF8_Solid(this.name, fontColor)
      #[ discard this.pgui.renderer.getRenderDrawColor(
                    fontBgColor.r.addr,
                    fontBgColor.g.addr,
                    fontBgColor.b.addr,
                    fontBgColor.a.addr) ]#
      #[ echo this.activeStyle
      echo this.styleCache[this.activeStyle].color.r.int
      echo this.styleCache[this.activeStyle].color.g.int
      echo this.styleCache[this.activeStyle].color.b.int
      echo this.styleCache[this.activeStyle].color.a.int ]#

      var surface = this.pgui.font_normal.renderUtf8Shaded(
                    this.val,
                    this.styleCache[this.activeStyle].color,
                    fontBgColor)
      #discard surface.setColorKey(1,0)

      var srect : sdl.Rect = (
                          x: canvasRect.x + 1,
                          y: canvasRect.y + 1,
                          w: surface.w,
                          h: surface.h)

      var texture = sdl.createTextureFromSurface(this.pgui.renderer, surface)

      discard this.pgui.renderer.copy(texture,
          nil, srect.addr)

      sdl.freeSurface(surface)
      destroyTexture(texture)

      #................................

      # DRAW CURSOR ................................
      if this.pgui.focusElem == this:
        this.pgui.renderer.setDrawColor(
            this.styleCache[this.activeStyle].color)
        
        #this.cursorPos = rand(this.val.len).uint
        #this.cursorPos = (this.val.runeLen)

        discard this.pgui.renderer.drawLine(
            cint(this.cursorPos * 8),
            canvasRect.y.cint,
            cint(this.cursorPos * 8),
            canvasRect.y.cint + canvasRect.h.cint
            )


      #=====================================
      discard sdl.setRenderTarget(this.pgui.renderer, nil)
      discard this.pgui.renderer.copy(
          this.textureCache,
          nil, thisRect.addr)


    # reset clipping
    discard sdl.setClipRect(this.pgui.renderer, nil)

    this.redrawFlag = 0

#........................................................



