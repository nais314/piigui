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
import unicode
import locks

type AToggleBtn* = ref object of DivRef
  text*: string
  state*:uint8

#----------------------------------------------------
## currently shadow is black
## 
#[ 
##    ## ######## ##      ## 
###   ## ##       ##  ##  ## 
####  ## ##       ##  ##  ## 
## ## ## ######   ##  ##  ## 
##  #### ##       ##  ##  ## 
##   ### ##       ##  ##  ## 
##    ## ########  ###  ###  
 ]#


proc onMouseButtonDown(this:DivRef){.nosinks.} #!FWD
proc onMouseButtonUp(this:DivRef){.nosinks.} #!FWD

proc default_onFocus*(this:DivRef){.nosinks.}=
  piigui.default_onFocus(this)

proc default_onBlur*(this:DivRef){.nosinks.}=
  AToggleBtn(this).state = 0

proc draw*(self:DivRef, scrollXArg, scrollYArg:int) #!FWD
proc atbtn_onFocus*(this:DivRef){.nosinks.} #!FWD
proc atbtn_onBlur*(this:DivRef){.nosinks.} #!FWD
proc atbtn_onclick*(this:DivRef, e:sdl.Event){.nosinks.} #!FWD


proc newAToggleBtn*(
            parent: DivRef,
            layer:int = 0,
            name: string,
            group: string = "",
            width: string="auto",
            height: string="auto",
            recalcFun: proc (this: DivRef, layer: Layer): tuple[w: int, h: int] = recalcFlex,
            styles: openArray[string] = [],
            #:::::::::::::
            text = "",
            state = 0,
            ): AToggleBtn =

  result = new AToggleBtn
  initLock(result.lock)
  result.typeName = "AToggleBtn"
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

  result.isRecalculated = false # ??????????????
  # ....
  # todo move to back if style not adds it
  (result.w_unit, result.w_value) = parseSizeStr(width)
  (result.h_unit, result.h_value) = parseSizeStr(height)
  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)
  for style in styles:
    result.styles.add((style, rootSSRT[style]))

  result.activeStyle = "default"
  recalcStyle(result)
  # ....
  result.draw = draw
  result.redrawFlag = rkFullRedraw

  result.onMouseButtonDown = onMouseButtonDown
  result.onMouseButtonUp = onMouseButtonUp
  result.onFocus = atbtn_onFocus
  result.onBlur = atbtn_onBlur
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = piigui.default_onDragEnd
  result.onDragOver = piigui.default_onDragOver
  result.onClick = atbtn_onclick

  # ......................
  result.text = text

  #-----------------------
  if parent != nil : parent.layers[layer].elems.add(result)
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
  # calculate inner x,y,w,h,etc
  # if update only
  # if visible
  withLock self.lock:
    let this = AToggleBtn(self)

    const debug = 0b0

    # .............................
    # clipRect (screen coordinates) hides overflow: the intersection of all
    # ancestors' on-screen rects. It must clip ONLY the final on-screen copy,
    # not the texture-local rendering below.
    var clipRect = this.clipRect
    if clipRect.w == 0 or clipRect.h == 0:
      #! off-screen: skip render; redrawFlag stays set so it repaints when visible again
      return
    # .............................

    # canvasRect is the rect we can paint
    # after
    # sdl.setRenderTarget(this.window.renderer, this.textureCache) 
    var canvasRect: sdl.Rect
    canvasRect.x = 0
    canvasRect.y = 0
    canvasRect.w = this.w
    # canvasFRect in local coords
    var canvasFRect = sdl.FRect(
      x: 0.0,
      y: 0.0,
      w: this.w.cfloat,
      h: this.h.cfloat
    )

    # .............................

    # The area of this button on the screen in FRect,
    # shifted by the accumulated scroll offsets of its ancestors.
    var screenFRect = sdl.FRect(
      x: (this.x1 - scrollXArg).cfloat,
      y: (this.y1 - scrollYArg).cfloat,
      w: this.w.cfloat,
      h: this.h.cfloat
    )

    # .............................
    #! we need to redraw, even if not changed
    if this.redrawFlag != rkFullRedraw and this.textureCache != nil:
        discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
        discard this.window.renderer.renderTexture(
            this.textureCache,
            nil, addr screenFRect)


    else:
      # if need to re-render
      # check if cache setted up
      # todo setup cache at recalc
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
      discard setRenderDrawColor(this.window.renderer, transparentColor)
      discard this.window.renderer.renderClear()
      # =====================================
      # =====================================
      #[ 
      e    e eeeee e   e eeeee     eeee e   e eeeee 
      8    8 8  88 8   8 8   8     8    8   8 8   8 
      8eeee8 8   8 8e  8 8eee8e    8eee 8e  8 8e  8 
        88   8   8 88  8 88   8    88   88  8 88  8 
        88   8eee8 88ee8 88   8    88   88ee8 88  8 
      ]#

      #! CUSTOM FUN HERE:


      # draw the elem:::::::

      if this.state == 0:

        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].backGroundColor )

        discard this.window.renderer.renderFillRect(addr(canvasFRect))
        
        # draw border
        if this.styleCache[this.activeStyle].borderColor != EmptyColor:
          discard setRenderDrawColor(this.window.renderer,
            this.styleCache[this.activeStyle].borderColor)
          discard this.window.renderer.renderRect(addr(canvasFRect))


        # text::::::::::::::::::::::::::
        if this.text.len > 0:
          var surface = ttf.renderTextBlendedWrapped(
                                      this.pgui.fonts[
                                        this.styleCache[this.activeStyle].font
                                      ].fontPtr,
                                      this.text.cstring,
                                      0,
                                      buttonTextColor(this.styleCache[this.activeStyle].backGroundColor),
                                      this.w.cint
                                      )

          if surface == nil:
            #! font render failed: release target/clip before bailing, keep redrawFlag set
            discard sdl.setRenderTarget(this.window.renderer, nil)
            discard sdl.setRenderClipRect(this.window.renderer, nil)
            return

          var texture = sdl.createTextureFromSurface(this.window.renderer, surface)

          var textFRect = sdl.FRect(
            x: 0.0,
            y: 0.0,
            w: surface.w.cfloat,
            h: surface.h.cfloat
          )

          # center text on the rendered surface, not the font line height
          if canvasFRect.h > surface.h.cfloat:
            textFRect.y = (canvasFRect.h - surface.h.cfloat) / 2.0
          if canvasFRect.w > surface.w.cfloat:
            textFRect.x = (canvasFRect.w - surface.w.cfloat) / 2.0

          discard this.window.renderer.renderTexture(texture,
            nil, addr textFRect)

          sdl.destroySurface(surface)
          sdl.destroyTexture(texture)

        # ...............................


      elif this.state == 1: # pressed, toggled state
          
        # btn face:::::
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].color )
        discard this.window.renderer.renderFillRect(addr(canvasFRect))
        
        # draw border
        if this.styleCache[this.activeStyle].borderColor != EmptyColor:
          discard setRenderDrawColor(this.window.renderer,
            this.styleCache[this.activeStyle].borderColor)
          discard this.window.renderer.renderRect(addr(canvasFRect))

        # text::::::::::::::::::::::::::
        if this.text.len > 0:
          var surface = ttf.renderTextBlendedWrapped(
                                      this.pgui.fonts[
                                        this.styleCache[this.activeStyle].font
                                      ].fontPtr,
                                      this.text.cstring,
                                      0,
                                      buttonTextColor(this.styleCache[this.activeStyle].color),
                                      this.w.cint
                                      )

          if surface == nil:
            #! font render failed: release target/clip before bailing, keep redrawFlag set
            discard sdl.setRenderTarget(this.window.renderer, nil)
            discard sdl.setRenderClipRect(this.window.renderer, nil)
            return

          var texture = sdl.createTextureFromSurface(this.window.renderer, surface)

          var textFRect = sdl.FRect(
            x: 0.0,
            y: 0.0,
            w: surface.w.cfloat,
            h: surface.h.cfloat
          )

          # center text on the rendered surface, not the font line height
          if canvasFRect.h > surface.h.cfloat:
            textFRect.y = (canvasFRect.h - surface.h.cfloat) / 2.0
          if canvasFRect.w > surface.w.cfloat:
            textFRect.x = (canvasFRect.w - surface.w.cfloat) / 2.0

          discard this.window.renderer.renderTexture(texture,
            nil, addr textFRect)

          sdl.destroySurface(surface)
          sdl.destroyTexture(texture)

        # ...............................

      # =====================================
      # =====================================
      #! IMPORTANT
      # release rendertarget
      discard sdl.setRenderTarget(this.window.renderer, nil)
      # clip only the screen-space copy
      discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
      # copy texture to its place
      discard this.window.renderer.renderTexture(
          this.textureCache,
          nil, addr screenFRect)
      # =====================================        

    # ............................................
    # reset clipping
    discard sdl.setRenderClipRect(this.window.renderer, nil)

    this.redrawFlag = rkNoRedraw



#[

########  ########   #######   ######  
##     ## ##     ## ##     ## ##    ## 
##     ## ##     ## ##     ## ##       
########  ########  ##     ## ##       
##        ##   ##   ##     ## ##       
##        ##    ##  ##     ## ##    ## 
##        ##     ##  #######   ######  
                         
]#

proc onMouseButtonDown(this:DivRef){.nosinks.}=
  #AToggleBtn(this).state = 1
  this.redrawFlag = rkFullRedraw
  this.setActiveStyle("focus")

proc onMouseButtonUp(this:DivRef){.nosinks.}=
  if AToggleBtn(this).state == 0:
    AToggleBtn(this).state = 1
  else:
    AToggleBtn(this).state = 0

  #setDefaultStyle(this)
  #this.pgui.hoverElem = nil


proc atbtn_onclick*(this:DivRef, e:sdl.Event){.nosinks.}=
  discard

  
proc atbtn_onFocus*(this:DivRef){.nosinks.}=
  this.redrawFlag = rkFullRedraw
  this.setActiveStyle("focus")
  if AToggleBtn(this).state == 0:
    AToggleBtn(this).state = 1
  else:
    AToggleBtn(this).state = 0
  #[ ## this elem not receives focus
  ## focus comes at MouseUp, so let's restore style to normal
  this.pgui.hoverElem = nil

  this.setActiveStyle("focus")

  #setDefaultStyle(this)
  #AToggleBtn(this).state = 0
  this.redrawFlag = rkFullRedraw ]#


proc atbtn_onBlur*(this:DivRef){.nosinks.}=
  AToggleBtn(this).state = 0
  setDefaultStyle(this)
  this.redrawFlag = rkFullRedraw


proc setText*(this:AToggleBtn, text:string)=
  withLock this.lock:
    this.text = text
  this.redrawFlag = rkFullRedraw