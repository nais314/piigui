# TODO Background box ??????!!!!!

import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases
import piigui
import piigui/[types,style]
import piigui/layout/flex
import piigui/layout/recalcH as recalcHMod
import piigui/layout/recalcV as recalcVMod
import tables
import locks

type Label* = ref object of DivRef
  val: string

#----------------------------------------------------
proc draw*(self:DivRef, scrollXArg, scrollYArg:int) #!FWD
proc newLabel*(parent: DivRef,
              val: string = "",
              layer:int = 0,
              name: string = "",
              group: string = "",
              width: string="auto",
              height: string="auto",
              recalcFun: proc (this: DivRef, layer: Layer): tuple[w: int, h: int] = recalcFlex,
              styles: openArray[string] = []
              ): Label =
  const debug = 0

  result = new Label
  initLock(result.lock)

  result.typeName = "Label"
  result.iD = piigui.getNextGlobalID()

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
  result.redrawFlag = rkFullRedraw
  result.isRecalculated = false


  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)

  #DEBUG FALLBACK
  #result.activeStyle = rootSSRT["column"]

  for style in styles:
    result.styles.add((style, rootSSRT[style]))

  result.activeStyle = "default"
  recalcStyle(result)

  result.draw = draw

  result.onFocus = piigui.default_onFocus
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = piigui.default_onDragEnd
  result.onDragOver = piigui.default_onDragOver

  result.val = val



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
  this.redrawFlag = rkFullRedraw


proc value*(this: Label):string= this.val


proc setText*(this:Label, text:string)=
  withLock this.lock:
    this.val = text
  this.redrawFlag = rkFullRedraw

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

proc draw*(self:DivRef, scrollXArg, scrollYArg:int)=
  ## calculate inner x,y,w,h,etc
  ## if update only
  ## if visible
  withLock self.lock:
    const debug = 1

    let this = Label(self)

    when debug > 1 :
      echo "draw()"
      echo this.name
      echo "w: ",this.w, " h: ", this.h
      echo "x1: ",this.x1, " y1: ", this.y1
      echo "___________"

    #.............................
    # clipRect (screen coordinates) hides overflow: the intersection of all
    # ancestors' on-screen rects. It must clip ONLY the final on-screen copy,
    # not the texture-local rendering below.
    var clipRect = this.clipRect
    if clipRect.w == 0 or clipRect.h == 0:
      #! off-screen: skip render; redrawFlag stays set so it repaints when visible again
      return
    #.............................

    var canvasFRect = sdl.FRect(
      x: 0.0,
      y: 0.0,
      w: this.w.cfloat,
      h: this.h.cfloat
    )

    #.............................

    # The area of this button on the screen in FRect,
    # shifted by the accumulated scroll offsets of its ancestors.
    var screenFRect = sdl.FRect(
      x: (this.x1 - scrollXArg).cfloat,
      y: (this.y1 - scrollYArg).cfloat,
      w: this.w.cfloat,
      h: this.h.cfloat
    )

    #.............................
    # we need to redraw, even if not changed
    if this.redrawFlag != rkFullRedraw and this.textureCache != nil:
        discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
        discard this.window.renderer.renderTexture(
            this.textureCache,
            nil, addr screenFRect)




    else:
      #* if need to redraw, check if cache setted up ----------
      # todo setup cahce at recalc
      if this.textureCache != nil:
        sdl.destroyTexture(this.textureCache)
      this.textureCache = sdl.createTexture(
        this.window.renderer,
        sdl.PIXELFORMAT_UNKNOWN,#PIXELFORMAT_RGBA8888,
        sdl.TEXTUREACCESS_TARGET,
        this.w.cint,
        this.h.cint)
      discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

      # the elems. texture is the render target x=0 y=0!
      discard sdl.setRenderTarget(this.window.renderer, this.textureCache)
      discard setRenderDrawColor(this.window.renderer, EmptyColor)
      discard this.window.renderer.renderClear()
      #.............................


      #* draw the background -----------------------
      if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].backGroundColor)

      discard this.window.renderer.renderFillRect(addr(canvasFRect))

      # draw border
      if this.styleCache[this.activeStyle].borderColor != EmptyColor:
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].borderColor)
      discard this.window.renderer.renderRect(addr(canvasFRect))
      


      #* draw the text --------------------------------------
      if this.val.len > 0:
        var
          fontColor = this.styleCache[this.activeStyle].color
          fontBgColor = this.styleCache[this.activeStyle].backGroundColor

        let surface = ttf.renderTextBlendedWrapped(
                                    this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr,
                                    this.val.cstring,
                                    0,
                                    fontColor,
                                    this.w.cint)

        if surface == nil:
          #* font render failed: release target/clip before bailing, keep redrawFlag set
          discard sdl.setRenderTarget(this.window.renderer, nil)
          discard sdl.setRenderClipRect(this.window.renderer, nil)
          return

        let texture = sdl.createTextureFromSurface(this.window.renderer, surface)

        var textFRect = sdl.FRect(
          x: 0.0,
          y: 0.0,
          w: surface.w.cfloat,
          h: surface.h.cfloat
        )

        # center text --------------------------
        if canvasFRect.h > surface.h.cfloat:
          textFRect.y = (canvasFRect.h - surface.h.cfloat) / 2.0
        if canvasFRect.w > surface.w.cfloat:
          textFRect.x = (canvasFRect.w - surface.w.cfloat) / 2.0

        discard this.window.renderer.renderTexture(texture,
            nil, addr textFRect)

        sdl.destroySurface(surface)
        sdl.destroyTexture(texture)


      #=====================================
      #* DRAW ON WINDOW
      discard sdl.setRenderTarget(this.window.renderer, nil) #! from texcureCache to Window
      # clip only the screen-space copy
      discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
      discard this.window.renderer.renderTexture(
          this.textureCache,
          nil, addr screenFRect)


    # reset clipping
    discard sdl.setRenderClipRect(this.window.renderer, nil)

    this.redrawFlag = rkNoRedraw

#........................................................

