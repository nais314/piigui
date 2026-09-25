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


type DosBtn* = ref object of DivRef
  text*: string
  state*:uint8
  shadowSizePx*:int
  ## this.shadowSizePx is substracted from w & h

#----------------------------------------------------
## currently shadow is black
## 
## this.styleCache[this.activeStyle].backGroundColor
## is used for "pressed" bg-color
#[ 
##    ## ######## ##      ## 
###   ## ##       ##  ##  ## 
####  ## ##       ##  ##  ## 
## ## ## ######   ##  ##  ## 
##  #### ##       ##  ##  ## 
##   ### ##       ##  ##  ## 
##    ## ########  ###  ###  
 ]#



#[ proc default_onFocus*(this:DivRef){.nosinks.}=
  piigui.default_onFocus(this)

proc default_onBlur*(this:DivRef){.nosinks.}=
  DosBtn(this).state = 0 ]#

proc draw*(self:DivRef, scrollXArg, scrollYArg:int) #!FWD
proc onMouseButtonDown*(this:DivRef){.nosinks.} #!FWD
proc onMouseButtonUp*(this:DivRef){.nosinks.} #!FWD
proc dosbtn_onFocus*(this:DivRef){.nosinks.} #!FWD
proc dosbtn_onClick*(this:DivRef, e:sdl.Event){.nosinks.} #!FWD
proc dosbtn_onDragEnd*(this:DivRef){.nosinks.} #!FWD




proc newDosBtn*(parent: DivRef,
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
             shadowSizePx: int = 0
             ): DosBtn =

  result = new DosBtn
  initLock(result.lock)
  result.typeName = "DosBtn"
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
  result.redrawFlag = 1

  result.onMouseButtonDown = onMouseButtonDown
  result.onMouseButtonUp = onMouseButtonUp
  result.onFocus = dosbtn_onFocus
  #result.onBlur = piigui.default_onBlur
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = dosbtn_onDragEnd
  result.onDragOver = piigui.default_onDragOver
  result.onClick = dosbtn_onClick

  # ......................
  result.text = text
  result.shadowSizePx = shadowSizePx

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
  withLock self.lock:
    
    let this = DosBtn(self)

    const debug = 0

    # .............................
    # clipRect (screen coordinates) hides overflow: the intersection of all
    # ancestors' on-screen rects. It must clip ONLY the final on-screen copy,
    # not the texture-local rendering below. Applying it before rendering into
    # textureCache would clip the fill in the wrong coordinate space.
    var clipRect = visibleClipRect(this, scrollXArg, scrollYArg)
    if clipRect.w == 0 or clipRect.h == 0:
      #! off-screen: skip render; redrawFlag stays set so it repaints when visible again
      return
    when debug > 0:
      echo "repr(clipRect) " & this.name
      echo repr(clipRect) & "\n"
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
    if this.redrawFlag == 0 and this.textureCache != nil:
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
        sdl.PIXELFORMAT_UNKNOWN,
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

      if this.shadowSizePx == 0:
        this.shadowSizePx = min((min(this.w, this.h) div 5), 12)

      # draw the elem with FRect:
      var paintFRect: sdl.FRect

      if this.state == 0:

        # shadow::::::::
        paintFRect.x = this.shadowSizePx.cfloat
        paintFRect.y = this.shadowSizePx.cfloat
        paintFRect.w = (this.w - this.shadowSizePx).cfloat
        paintFRect.h = (this.h - this.shadowSizePx).cfloat
        when debug > 1:
          echo "paintFRect.x ", paintFRect.x
          echo "paintFRect.y ", paintFRect.y
          echo "paintFRect.w ", paintFRect.w
          echo "paintFRect.h ", paintFRect.h
          
        discard setRenderDrawColor(this.window.renderer, sdl.Color(r:0'u8,g:0'u8,b:0'u8,a:160'u8))
        discard this.window.renderer.renderFillRect(addr(paintFRect))

        # btn face:::::
        paintFRect.x = 0.0
        paintFRect.y = 0.0
        paintFRect.w = (this.w - this.shadowSizePx).cfloat
        paintFRect.h = (this.h - this.shadowSizePx).cfloat
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].backGroundColor )

        discard this.window.renderer.renderFillRect(addr(paintFRect))

        # text::::::::::::::::::::::::::
        if this.text.len > 0:
          var surface = ttf.renderTextBlendedWrapped(
                                    this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr,
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

          var textFRect = sdl.FRect(
            x: paintFRect.x,
            y: paintFRect.y,
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

        # ::::::::::::::::::::::::::


      elif this.state == 1: # pressed, toggled state
        # btn face shifted by shadow size:::::
        paintFRect.x = this.shadowSizePx.cfloat
        paintFRect.y = this.shadowSizePx.cfloat
        paintFRect.w = (this.w - this.shadowSizePx).cfloat
        paintFRect.h = (this.h - this.shadowSizePx).cfloat
          
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].backGroundColor )
        discard this.window.renderer.renderFillRect(addr(paintFRect))


        # text::::::::::::::::::::::::::
        if this.text.len > 0:
          var surface = ttf.renderTextBlendedWrapped(
                                    this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr,
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

          var textFRect = sdl.FRect(
            x: paintFRect.x,
            y: paintFRect.y,
            w: surface.w.cfloat,
            h: surface.h.cfloat
          )

          # center text on the rendered surface, not the font line height
          if paintFRect.h > surface.h.cfloat:
            textFRect.y = paintFRect.y + (paintFRect.h - surface.h.cfloat) / 2.0
          if paintFRect.w > surface.w.cfloat:
            textFRect.x = paintFRect.x + (paintFRect.w - surface.w.cfloat) / 2.0

          discard this.window.renderer.renderTexture(texture,
            nil, addr textFRect)

          sdl.destroySurface(surface)
          sdl.destroyTexture(texture)

        # ::::::::::::::::::::::::::




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

    this.redrawFlag = 0




##[
  Buttons have spec behavior:
    focus is not a state, only ToggleButtons have focused (visual) state
]##
proc onMouseButtonDown*(this:DivRef){.nosinks.}=
  DosBtn(this).state = 1
  this.redrawFlag = 1
  #this.setActiveStyle("focus")

proc onMouseButtonUp*(this:DivRef){.nosinks.}=
  DosBtn(this).state = 0
  this.redrawFlag = 1
  #setDefaultStyle(this)
  #this.pgui.hoverElem = nil

proc dosbtn_onClick*(this:DivRef, e:sdl.Event){.nosinks.}=
  discard
  #[ ## event on MouseDown
  DosBtn(this).state = 1
  this.redrawFlag = 1
  this.setActiveStyle("focus") ]#

  
proc dosbtn_onFocus*(this:DivRef){.nosinks.}=
  discard
  ## this elem not receives focus
  ## focus comes at MouseUp, so let's restore style to normal
  #this.pgui.hoverElem = nil
  #setDefaultStyle(this)
  #[ DosBtn(this).state = 0
  this.redrawFlag = 1
  discard trigger(this, "click") ]#

proc dosbtn_onDragEnd*(this:DivRef){.nosinks.}=
  piigui.default_onDragEnd(this)

  setDefaultStyle(this)
  DosBtn(this).state = 0
  this.redrawFlag = 1

template setText*(this:DosBtn, val:string)=
  this.text = val
  this.redrawFlag = 1
