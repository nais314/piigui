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

proc draw*(self:DivRef) #!FWD
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
    result.nthChild = parent.layers[layer].elems.len

  result.layers = @[]
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
    result.styles.add((style, defaultSST[style]))

  result.activeStyle = "default"
  recalcStyle(result)
  # ....
  result.draw = draw
  result.redrawFlag = 1

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


proc draw*(self:DivRef)=
  # calculate inner x,y,w,h,etc
  # if update only
  # if visible
  withLock self.lock:
    let this = AToggleBtn(self)

    const debug = 0b0

    # .............................
    # clipRect hides overflow
    var clipRect: sdl.Rect
    if this.parent == nil:
      clipRect.x = this.x1
      clipRect.y = this.y1
      clipRect.w = this.w
      clipRect.h = this.h
    else:
      clipRect.x = this.parent.x1
      clipRect.y = this.parent.y1
      clipRect.w = this.parent.w #(this.x2 - this.x1 + 1)
      clipRect.h = this.parent.h #(this.y2 - this.y1 + 1)
    discard sdl.setClipRect(this.window.renderer, clipRect.addr)
    # .............................

    # canvasRect is the rect we can paint
    # after
    # sdl.setRenderTarget(this.window.renderer, this.textureCache) 
    var canvasRect: sdl.Rect
    canvasRect.x = 0
    canvasRect.y = 0
    canvasRect.w = this.w
    canvasRect.h = this.h

    # .............................

    # the area, to paint to - on the renderer
    var thisRect: sdl.Rect
    thisRect.x = this.x1
    thisRect.y = this.y1
    thisRect.w = this.w
    thisRect.h = this.h

    # .............................
    #! we need to redraw, even if not changed
    if this.redrawFlag == 0 and this.textureCache != nil:
        discard this.window.renderer.copy(
            this.textureCache,
            nil, thisRect.addr)


    else:
      # if need to re-render
      # check if cache setted up
      # todo setup cache at recalc
      if this.textureCache == nil:
        this.textureCache = sdl.createTexture(
          this.window.renderer,
          sdl.SDL_PIXELFORMAT_UNKNOWN,#PIXELFORMAT_RGBA8888,
          sdl.SDL_TEXTUREACCESS_TARGET,
          this.w,
          this.h)
        discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

      # the elems. texture is the render target x=0 y=0!
      discard sdl.setRenderTarget(this.window.renderer, this.textureCache)
      this.window.renderer.setDrawColor(clearColor)
      discard this.window.renderer.clear()
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

        this.window.renderer.setDrawColor(
          this.styleCache[this.activeStyle].backGroundColor )

        discard this.window.renderer.fillRect(addr(canvasRect))
        
        # draw border
        if this.styleCache[this.activeStyle].borderColor != EmptyColor:
          this.window.renderer.setDrawColor(
            this.styleCache[this.activeStyle].borderColor)
        discard this.window.renderer.drawRect(addr(canvasRect))


        # text::::::::::::::::::::::::::
        var surface = this.pgui.fonts["default"].renderUtf8Shaded(
                    this.text.cstring,
                    this.styleCache[this.activeStyle].color,
                    this.styleCache[this.activeStyle].backGroundColor)

        var texture = sdl.createTextureFromSurface(this.window.renderer, surface)


        # get font heigth
        var fh = this.pgui.fonts[
                    this.styleCache[this.activeStyle].font
                    ].fontHeight() + 2
        # center
        if canvasRect.h > fh:
          canvasRect.y = (canvasRect.h - fh) div 2
          canvasRect.h = fh
        if canvasRect.w > surface.w:
          canvasRect.x = (canvasRect.w - surface.w ) div 2
          canvasRect.w = surface.w


        discard this.window.renderer.copy(texture,
          nil, canvasRect.addr)

        sdl.freeSurface(surface)
        destroyTexture(texture)

        # ...............................


      elif this.state == 1: # pressed, toggled state
          
        # btn face:::::
        this.window.renderer.setDrawColor(
          this.styleCache[this.activeStyle].color )
        discard this.window.renderer.fillRect(addr(canvasRect))
        
        # draw border
        if this.styleCache[this.activeStyle].borderColor != EmptyColor:
          this.window.renderer.setDrawColor(
            this.styleCache[this.activeStyle].borderColor)
        discard this.window.renderer.drawRect(addr(canvasRect))

        # text::::::::::::::::::::::::::
        var surface = this.pgui.fonts["default"].renderUtf8Shaded(
                    this.text,
                    this.styleCache[this.activeStyle].backGroundColor,
                    this.styleCache[this.activeStyle].color)

        var texture = sdl.createTextureFromSurface(this.window.renderer, surface)


        # get font heigth
        var fh = this.pgui.fonts[
                    this.styleCache[this.activeStyle].font
                    ].fontHeight() + 2
        # center
        if canvasRect.h > fh:
          canvasRect.y = (canvasRect.h - fh) div 2
          canvasRect.h = fh
        if canvasRect.w > surface.w:
          canvasRect.x = (canvasRect.w - surface.w ) div 2
          canvasRect.w = surface.w


        discard this.window.renderer.copy(texture,
          nil, canvasRect.addr)

        sdl.freeSurface(surface)
        destroyTexture(texture)

        # ...............................

      # =====================================
      # =====================================
      #! IMPORTANT
      # release rendertarget
      discard sdl.setRenderTarget(this.window.renderer, nil)
      # copy texture to its place
      discard this.window.renderer.copy(
          this.textureCache,
          nil, thisRect.addr)
      # =====================================        

    # ............................................
    # reset clipping
    discard sdl.setClipRect(this.window.renderer, nil)

    this.redrawFlag = 0



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
  this.redrawFlag = 1
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
  this.redrawFlag = 1
  this.setActiveStyle("focus")
  #[ ## this elem not receives focus
  ## focus comes at MouseUp, so let's restore style to normal
  this.pgui.hoverElem = nil

  this.setActiveStyle("focus")

  #setDefaultStyle(this)
  #AToggleBtn(this).state = 0
  this.redrawFlag = 1 ]#


proc atbtn_onBlur*(this:DivRef){.nosinks.}=
  AToggleBtn(this).state = 0
  setDefaultStyle(this)
  this.redrawFlag = 1


proc setText*(this:AToggleBtn, text:string)=
  withLock this.lock:
    this.text = text
  this.redrawFlag = 1