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

type GradBtn* = ref object of DivRef
  text*: string
  state*:uint8
  #shadowSizePx*:int

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
  GradBtn(this).state = 0

proc draw*(self:DivRef, scrollXArg, scrollYArg:int) #!FWD
proc gradbtn_onFocus*(this:DivRef){.nosinks.} #!FWD
proc gradbtn_onClick*(this:DivRef, e:sdl.Event){.nosinks.} #!FWD
proc gradbtn_onDragEnd*(this:DivRef){.nosinks.} #!FWD




proc newGradBtn*(parent: DivRef,
             layer:int = 0,
             name: string = "",
             group: string = "",
             width: string="auto",
             height: string="auto",
             recalcFun: proc (this: DivRef, layer: Layer): tuple[w: int, h: int] = recalcFlex,
             styles: openArray[string] = [],
             #:::::::::::::
             text = "",
             state = 0,
             #shadowSizePx: int = 4
             ): GradBtn =

  result = new GradBtn
  initLock(result.lock)
  result.typeName = "GradBtn"
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
  result.onFocus = gradbtn_onFocus
  #result.onBlur = piigui.default_onBlur
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = gradbtn_onDragEnd
  result.onDragOver = piigui.default_onDragOver
  result.onClick = gradbtn_onClick

  # ......................
  result.text = text
  #result.shadowSizePx = shadowSizePx

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
    let this = GradBtn(self)

    const debug = 0

    # .............................
    # clipRect (screen coordinates) hides overflow: the intersection of all
    # ancestors' on-screen rects. It must clip ONLY the final on-screen copy,
    # not the texture-local rendering below.
    var clipRect = this.clipRect
    if clipRect.w == 0 or clipRect.h == 0:
      #! off-screen: skip render; redrawFlag stays set so it repaints when visible again
      return
    # .............................

    # Screen-space destination rectangle for rendering (adjusted for scroll) in FRect.
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


      #*------------------------------------------
      #* gradient magic - source of idea unknown
      #*------------------------------------------
      
      var paintFRect = sdl.FRect(
        x: 0.0,
        y: 0.0,
        w: this.w.cfloat,
        h: this.h.cfloat
      )

      if this.state == 0:
        #discard sdl.setHint(HINT_RENDER_SCALE_QUALITY,"1")

        var gradientTexture = sdl.createTexture(
          this.window.renderer,
          sdl.PIXELFORMAT_RGBA8888,
          sdl.TEXTUREACCESS_STREAMING, #This creates a 4×4 texture. STREAMING means the CPU can write pixels into it directly.
          4,4)
        discard gradientTexture.setTextureBlendMode(sdl.BLENDMODE_BLEND)
        
        #This asks SDL to use linear filtering instead of nearest-neighbor when scaling textures.
        discard gradientTexture.setTextureScaleMode(sdl.SCALEMODE_LINEAR)
      
        var
          gradientRGBA_top: uint32 = toRGBA(this.styleCache[this.activeStyle].color)
          gradientRGBA_bottom: uint32 = toRGBA(this.styleCache[this.activeStyle].backGroundColor)
          textureBitmapPointer: pointer
          pixelPitch: cint
          gradientTextureTileFRect = sdl.FRect(x:1.0, y:1.0, w:2.0, h:2.0) # 4x4 RGBA 0..3 1..2==middle

        # This gives you a raw pointer to the texture's pixel memory
        if not sdl.lockTexture(gradientTexture,
                            nil,
                            textureBitmapPointer,
                            pixelPitch): quit(QuitFailure)

        # The pointer is cast to an array of 16 uint32 values (4×4 pixels, one integer per pixel):
        #   Indices 0–7 get the top color and 8–15 get the bottom color.
        #   The code assumes each row is exactly 4 pixels wide with no padding (pixelPitch == 16).
        #   That is usually true for such a small texture, 
        #   but strictly you should use pixelPitch to be safe.
        for i in 0..7:
          cast[ptr array[16, uint32]](textureBitmapPointer)[i] = gradientRGBA_top
        for i in 8..15:
          cast[ptr array[16, uint32]](textureBitmapPointer)[i] = gradientRGBA_bottom

        sdl.unlockTexture(gradientTexture)

        
        #[ This is where the gradient appears:
           The source rectangle (1, 1, 2, 2) selects only the middle 2×2 pixels of the 4×4 texture,
           which is one row of top color (row 1) and one row of bottom color (row 2).
           The destination nil means "fill the entire render target".   ]#
        discard this.window.renderer.renderTexture(
          gradientTexture,
          addr gradientTextureTileFRect,
          nil
        )


        sdl.destroyTexture(gradientTexture)


        #*----------------------------------------
        #* text drawing
        #*----------------------------------------

        if this.text.len > 0:
          var surface = ttf.renderTextBlendedWrapped(
                                      this.pgui.fonts[
                                        this.styleCache[this.activeStyle].font
                                      ].fontPtr,
                                      this.text.cstring,
                                      0,
                                      buttonTextColor(this.styleCache[this.activeStyle].backGroundColor),
                                      paintFRect.w.cint
                                      )

          if surface == nil:
            #! font render failed: release target/clip before bailing, keep redrawFlag set
            discard sdl.setRenderTarget(this.window.renderer, nil)
            discard sdl.setRenderClipRect(this.window.renderer, nil)
            return

          var texture = sdl.createTextureFromSurface(this.window.renderer, surface)
          discard texture.setTextureBlendMode(sdl.BLENDMODE_BLEND)

          var textFRect = sdl.FRect(
            x: 0.0,
            y: 0.0,
            w: surface.w.cfloat,
            h: surface.h.cfloat
          )

          # center text on the rendered surface, not the font line height
          if paintFRect.h > surface.h.cfloat:
            textFRect.y = (paintFRect.h - surface.h.cfloat) / 2.0
          if paintFRect.w > surface.w.cfloat:
            textFRect.x = (paintFRect.w - surface.w.cfloat) / 2.0

          discard this.window.renderer.renderTexture(texture,
            nil, addr textFRect)

          sdl.destroySurface(surface)
          sdl.destroyTexture(texture)
        # ...............................


      elif this.state == 1: #! pressed, toggled state -------
        discard setRenderDrawColor(this.window.renderer,
          darken(this.styleCache[this.activeStyle].backGroundColor) )
        discard this.window.renderer.renderFillRect(addr(paintFRect))


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

##[
  Buttons have spec behavior:
    focus is not a state, only ToggleButtons have focused (visual) state
]##
proc onMouseButtonDown(this:DivRef){.nosinks.}=
  GradBtn(this).state = 1
  this.redrawFlag = rkFullRedraw
  #this.setActiveStyle("focus")

proc onMouseButtonUp(this:DivRef){.nosinks.}=
  GradBtn(this).state = 0
  this.redrawFlag = rkFullRedraw
  #setDefaultStyle(this)
  #this.pgui.hoverElem = nil


proc gradbtn_onClick*(this:DivRef, e:sdl.Event){.nosinks.}=
  discard
  ## event on MouseDown
  #[ GradBtn(this).state = 1
  this.redrawFlag = rkFullRedraw
  this.setActiveStyle("focus") ]#

  
proc gradbtn_onFocus*(this:DivRef){.nosinks.}=
  discard
  ## this elem not receives focus
  ## focus comes at MouseUp, so let's restore style to normal
  #this.pgui.hoverElem = nil
  #setDefaultStyle(this)
  #[ GradBtn(this).state = 0
  this.redrawFlag = rkFullRedraw
  discard trigger(this, "click") ]#

proc gradbtn_onDragEnd*(this:DivRef){.nosinks.}=
  piigui.default_onDragEnd(this)

  setDefaultStyle(this)
  GradBtn(this).state = 0
  this.redrawFlag = rkFullRedraw



proc setText*(this:GradBtn, text:string)=
  withLock this.lock:
    this.text = text
  this.redrawFlag = rkFullRedraw