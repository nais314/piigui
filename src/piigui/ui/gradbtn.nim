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

proc draw*(self:DivRef, scrollX, scrollY:int) #!FWD
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
    result.nthChild = parent.layers[layer].elems.len

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
    result.styles.add((style, defaultSST[style]))

  result.activeStyle = "default"
  recalcStyle(result)
  # ....
  result.draw = draw
  result.redrawFlag = 1

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


proc draw*(self:DivRef, scrollX, scrollY:int)=
  # calculate inner x,y,w,h,etc
  # if update only
  # if visible
  withLock self.lock:
    let this = GradBtn(self)

    const debug = 0

    # .............................
    # clipRect hides overflow
    var clipRect: sdl.Rect
    if this.parent == nil:
      clipRect.x = this.x1
      clipRect.y = this.y1
      clipRect.w = this.w
      clipRect.h = this.h
    else:
      var pAccX = scrollX
      var pAccY = scrollY
      if this.parent.scrollable:
        pAccX -= this.parent.scrollX
        pAccY -= this.parent.scrollY
      clipRect.x = this.parent.x1 - pAccX
      clipRect.y = this.parent.y1 - pAccY
      clipRect.w = this.parent.w #(this.x2 - this.x1 + 1)
      clipRect.h = this.parent.h #(this.y2 - this.y1 + 1)
    
    discard sdl.setClipRect(this.window.renderer, clipRect.addr)
    # .............................

    # canvasRect is the rect we can paint
    # after
    # sdl.setRenderTarget(this.window.renderer, this.textureCache) 
    var canvasRect: sdl.Rect
    canvasRect.x = 0 #!
    canvasRect.y = 0 #!
    canvasRect.w = this.w
    canvasRect.h = this.h

    # .............................

    # the area to paint to on the screen (renderer)
    var thisRect: sdl.Rect
    thisRect.x = this.x1 - scrollX #!
    thisRect.y = this.y1 - scrollY #!
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
            #fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8))
            #fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))


      # draw the elem:::::::
      var
        paintRect: sdl.Rect
        #fontColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:255'u8))
        #fontBgColor = sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:0'u8))

      if this.state == 0:

        #[ # shadow::::::::
        paintRect.x = canvasRect.x + this.shadowSizePx
        paintRect.y = canvasRect.y + this.shadowSizePx
        paintRect.w = canvasRect.w - this.shadowSizePx
        paintRect.h = canvasRect.h - this.shadowSizePx
        when debug > 0:
          echo "paintRect.x ", paintRect.x
          echo "paintRect.y ", paintRect.y
          echo "paintRect.w ", paintRect.w
          echo "paintRect.h ", paintRect.h
          
        this.window.renderer.setDrawColor( sdl.Color((r:0'u8,g:0'u8,b:0'u8,a:100'u8)) )
        discard this.window.renderer.fillRect(addr(canvasRect))
  ]#
        # btn face:::::
        paintRect.x = canvasRect.x # 0
        paintRect.y = canvasRect.y # 0
        paintRect.w = canvasRect.w # w
        paintRect.h = canvasRect.h # h

        ## https://stackoverflow.com/questions/20348616/how-to-create-a-color-gradientTexture-in-sdl
        discard sdl.setHint(sdl.HINT_RENDER_SCALE_QUALITY,"1")

        var gradientTexture = sdl.createTexture(
          this.window.renderer,
          sdl.SDL_PIXELFORMAT_RGBA8888, #SDL_PIXELFORMAT_UNKNOWN
          sdl.SDL_TEXTUREACCESS_STREAMING,
          4,4)
        discard sdl.setTextureBlendMode(gradientTexture, sdl.BLENDMODE_BLEND)
      
        var
          gradientRGBA_top: uint32 = toRGBA(this.styleCache[this.activeStyle].color)
          gradientRGBA_bottom: uint32 = toRGBA(this.styleCache[this.activeStyle].backGroundColor)
          
          textureBitmapPointer: pointer
          pixelPitch: cint

          #gradientTextureRect : sdl.Rect = (x:0,y:0,w:4,h:4)
          gradientTextureTileRect : sdl.Rect = (x:1,y:1,w:2,h:2)

        #echo gradientRGBA_top, " -- ", gradientRGBA_bottom

        if sdl.lockTexture(gradientTexture,
                            nil,
                            textureBitmapPointer.unsafeAddr,
                            pixelPitch.unsafeAddr) != SDLSuccess: quit(QuitFailure)

        for i in 0..7:
          cast[ptr array[16, uint32]](textureBitmapPointer)[i] = gradientRGBA_top
        for i in 8..15:
          cast[ptr array[16, uint32]](textureBitmapPointer)[i] = gradientRGBA_bottom

        sdl.unlockTexture(gradientTexture)

        echo sdl.copy(
          this.window.renderer,
          gradientTexture,
          gradientTextureTileRect.addr,#nil,
          nil #canvasRect.addr
        )



        # text::::::::::::::::::::::::::
        var textBGColor = this.styleCache[this.activeStyle].backGroundColor
        textBGColor.a = 1 #! patch

        var surface = this.pgui.fonts["default"].renderUtf8Shaded(
                    this.text,
                    buttonTextColor(this.styleCache[this.activeStyle].backGroundColor),
                    #lighten(this.styleCache[this.activeStyle].color, 100),
                    #this.styleCache[this.activeStyle].backGroundColor
                    textBGColor
                    )

        var texture = sdl.createTextureFromSurface(this.window.renderer, surface)
        discard sdl.setTextureBlendMode(texture, sdl.BLENDMODE_BLEND)


        # get font heigth
        var fh = this.pgui.fonts[
                    this.styleCache[this.activeStyle].font
                    ].fontHeight() + 2

        if paintRect.h > fh:
          paintRect.y = (paintRect.h - fh) div 2
          paintRect.h = fh
        if paintRect.w > surface.w:
          paintRect.x = (paintRect.w - surface.w ) div 2
          paintRect.w = surface.w


        discard this.window.renderer.copy(texture,
          nil, paintRect.addr)

        sdl.freeSurface(surface)
        destroyTexture(texture)
        # ...............................


      elif this.state == 1: #! pressed, toggled state -------
        paintRect.x = canvasRect.x
        paintRect.y = canvasRect.y
        paintRect.w = canvasRect.w
        paintRect.h = canvasRect.h
          
        # btn face:::::
        this.window.renderer.setDrawColor(
          darken(this.styleCache[this.activeStyle].backGroundColor) )
        discard this.window.renderer.fillRect(addr(paintRect))


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

##[
  Buttons have spec behavior:
    focus is not a state, only ToggleButtons have focused (visual) state
]##
proc onMouseButtonDown(this:DivRef){.nosinks.}=
  GradBtn(this).state = 1
  this.redrawFlag = 1
  #this.setActiveStyle("focus")

proc onMouseButtonUp(this:DivRef){.nosinks.}=
  GradBtn(this).state = 0
  this.redrawFlag = 1
  #setDefaultStyle(this)
  #this.pgui.hoverElem = nil


proc gradbtn_onClick*(this:DivRef, e:sdl.Event){.nosinks.}=
  discard
  ## event on MouseDown
  #[ GradBtn(this).state = 1
  this.redrawFlag = 1
  this.setActiveStyle("focus") ]#

  
proc gradbtn_onFocus*(this:DivRef){.nosinks.}=
  discard
  ## this elem not receives focus
  ## focus comes at MouseUp, so let's restore style to normal
  #this.pgui.hoverElem = nil
  #setDefaultStyle(this)
  #[ GradBtn(this).state = 0
  this.redrawFlag = 1
  discard trigger(this, "click") ]#

proc gradbtn_onDragEnd*(this:DivRef){.nosinks.}=
  piigui.default_onDragEnd(this)

  setDefaultStyle(this)
  GradBtn(this).state = 0
  this.redrawFlag = 1



proc setText*(this:GradBtn, text:string)=
  withLock this.lock:
    this.text = text
  this.redrawFlag = 1