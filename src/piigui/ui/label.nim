# TODO Background box ??????!!!!!

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
import locks

type Label* = ref object of DivRef
  val: string

#----------------------------------------------------
proc draw*(self:DivRef) #!FWD
proc newLabel*(parent: DivRef,
             layer:int = 0,
             name: string,
             group: string = "",
             width: string="auto",
             height: string="auto",
             recalcFun: proc (this: DivRef, layer: Layer): tuple[w: int, h: int] = recalcFlex,
             styles: openArray[string] = []
             ): Label =
  const debug = 0b0

  result = new Label
  initLock(result.lock)

  result.typeName = "Label"

  result.parent = parent
  if parent != nil:
    result.pgui = parent.pgui
    result.window = parent.window
    result.nthChild = parent.layers[layer].elems.len

  result.layers = @[]
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

  result.onFocus = piigui.default_onFocus
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = piigui.default_onDragEnd
  result.onDragOver = piigui.default_onDragOver



  if parent != nil : parent.layers[layer].elems.add(result)
  when debug > 0:
    echo "newDiv result.w_value ", name, ": ", (result.w_unit, result.w_value)
    echo "newDiv result.h_value ", name, ": ", (result.h_unit, result.h_value)
    echo ""

#----------------------------------------------------



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

proc `value=`*(this: Label, val:string)=
  withLock this.lock:
    this.val = val
  this.redrawFlag = 1


proc value*(this: Label):string= this.val


proc setText*(this:Label, text:string)=
  withLock this.lock:
    this.val = text
  this.redrawFlag = 1

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
    const debug = 0

    let this = Label(self)

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

      #[ # draw the background
      if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
        this.pgui.renderer.setDrawColor(
          this.styleCache[this.activeStyle].backGroundColor)

      discard this.pgui.renderer.fillRect(addr(canvasRect))

      # draw border
      if this.styleCache[this.activeStyle].borderColor != EmptyColor:
        this.pgui.renderer.setDrawColor(
          this.styleCache[this.activeStyle].borderColor)
      discard this.pgui.renderer.drawRect(addr(canvasRect))
      ]#

      #=====================================
      if this.val.len > 0:
        this.pgui.renderer.setDrawColor(
            this.styleCache[this.activeStyle].backGroundColor)
        # render text --- render text --- render text ---
        var
          fontColor = this.styleCache[this.activeStyle].color #sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8))
          #fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))
          fontBgColor = this.styleCache[this.activeStyle].backGroundColor

        #var surface = this.pgui.font_normal.renderUTF8_Solid(this.name, fontColor)

        #[ discard this.pgui.renderer.getRenderDrawColor(
                      fontBgColor.r.addr,
                      fontBgColor.g.addr,
                      fontBgColor.b.addr,
                      fontBgColor.a.addr) ]#

        var surface = this.pgui.fonts["default"].renderUtf8Shaded(
                      this.val,
                      fontColor,
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

