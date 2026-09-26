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
import std/monotimes

const
  debug = 1

type
  MonoTextBox* = ref object of DivRef
    val*: string # text is val here
    cursorPos*: int = 0
    selectionStart*: int = 0 # if == cursorPos: no selection
    scrollOffset*: int = 0 # which part `val` is seen ?
    undoVal*: string = "" # snapshot at text-input start; Ctrl+Z restores it

    # monospace font handling
    charWidth*: int
    #charHeight*: int
    #padding*: int

    textureCacheWithCursor*: TexturePtr
    lastDrawTick: int64
    drawCursor: bool = false

  TextBox* = MonoTextBox  

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


proc onFocus(this:DivRef){.nosinks.} #!FWD
proc onBlur(this:DivRef){.nosinks.} #!FWD
proc onTextInput(this: DivRef, val:string){.nosinks.} #!FWD
proc onMouseButtonUp(this:DivRef) #!FWD
proc onClick(this:DivRef, eventObj:sdl.Event) #!FWD
proc keyDownEventListener(this:DivRef, e:sdl.Event):bool {.nosinks.} #!FWD

proc draw*(self:DivRef, scrollXArg, scrollYArg:int) #!FWD



proc newMonoTextBox*(parent: DivRef,
              val: string="",
              layer: int = 0,
              name: string="",
              group: string="",
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

  result.val = val #TODO
  result.cursorPos = result.val.runeLen

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

  result.onFocus = onFocus
  result.onBlur = onBlur
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = piigui.default_onDragEnd
  result.onDragOver = piigui.default_onDragOver

  result.onTextInput = onTextInput
  result.onMouseButtonUp = onMouseButtonUp
  result.onClick = onClick

  #* fine-grained keyboard handling: navigation, edit keys, Ctrl+Z undo
  result.addEventListener("keydown", keyDownEventListener)


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
  this.redrawFlag = rkFullRedraw


proc value*(this: TextBox):string= this.val


#----------------------------------------------------

proc cursorTimedEvent*(this: DivRef, nowNs: int64)=
  let self = MonoTextBox(this)
  #let elapsed = nowNs - self.lastDrawTick
  if nowNs - self.lastDrawTick > 500_000_000'i64:
    self.drawCursor = not self.drawCursor
    self.lastDrawTick = nowNs
    # only the cursor changed; the widget's draw picks the cached cursor
    # texture. markRedraw escalates to a full redraw if another request is
    # already pending on this element.
    self.markRedraw(rkPartialRedraw)

proc onFocus(this:DivRef){.nosinks.}=
  when debug > 0: echo "[ MonoText Focusing ]"

  piigui.default_onFocus(this)
  if this.window != nil:
    discard sdl.startTextInput(this.window.window)
  #* snapshot for single-level Ctrl+Z undo at the moment input starts
  MonoTextBox(this).undoVal = MonoTextBox(this).val
  this.redrawFlag = rkFullRedraw

  MonoTextBox(this).drawCursor = true
  MonoTextBox(this).lastDrawTick = getMonoTime().ticks

  this.pgui.addTimedEvent(
    elem = this,
    intervalNs = 500_000000.int64,
    fun = cursorTimedEvent,
    repeat = true
    )

proc onBlur(this:DivRef){.nosinks.}=
  piigui.default_onBlur(this)

  MonoTextBox(this).pgui.removeTimedEvent(this, cursorTimedEvent)
  MonoTextBox(this).drawCursor = false

proc onMouseButtonUp(this:DivRef)=
  onFocus(this)


proc onClick(this:DivRef, eventObj:sdl.Event)=
  when debug > 0: echo "[ MonoText onClick ]" & repr eventObj.motion

  MonoTextBox(this).cursorPos = min( (eventObj.motion.x.int - this.x1) div MonoTextBox(this).charWidth, MonoTextBox(this).val.len)
  this.redrawFlag = rkFullRedraw

proc onTextInput(this: DivRef, val:string){.nosinks.}=
      #[ this.val &= val
      this.cursorPos += 1 # = val.runeLen.uint
      this.redrawFlag = rkFullRedraw ]#
      let self = TextBox(this)
      #TODO: if selection: clear
      #TODO: cursor to selection start
      if self.cursorPos == 0:
        # add text Before
        self.val = val & self.val
      elif self.cursorPos == self.val.len:
        # add text After
        self.val &= val
      else:
        # instert text UTF8 way
        self.val = self.val.runeSubStr(0, self.cursorPos ) &
                    val &
                    self.val.runeSubStr(self.cursorPos)
      # cursorPos counts runes; advance by runes
      self.cursorPos += val.runeLen
      self.redrawFlag = rkFullRedraw


proc keyDownEventListener(this:DivRef, e:sdl.Event):bool {.nosinks.}=
  # hidevents always hands us a real key event; a bare trigger("keydown")
  # would pass the default(sdl.Event) sentinel (type == EVENT_FIRST).
  # Return false for anything we do not consume so the event keeps bubbling to
  # window/pgui listeners (and so the scancode bus still fires at this scope).
  if e.`type` != sdl.EVENT_KEY_DOWN:
    return false

  let self = MonoTextBox(this)
  when debug > 1: echo "keyDownEventListener: key=", e.key.key

  #* Enter leaves the single-line field. Blur touches focus and timed events,
  #* so run it outside this element's data lock.
  if e.key.key == sdl.SDLK_RETURN:
    if self.onBlur != nil:
      self.onBlur(this)
    return true

  withLock self.lock:
    #* Ctrl+Z: single-level undo back to the value snapshotted at focus
    if (e.key.`mod`.uint32 and sdl.KMOD_CTRL) != 0'u32 and e.key.key == sdl.SDLK_Z:
      self.val = self.undoVal
      self.cursorPos = self.undoVal.runeLen
      self.selectionStart = self.cursorPos
      self.redrawFlag = rkFullRedraw
      return true

    case e.key.key
    of sdl.SDLK_LEFT:
      if self.cursorPos > 0: dec self.cursorPos
    of sdl.SDLK_RIGHT:
      if self.cursorPos < self.val.runeLen: inc self.cursorPos
    of sdl.SDLK_HOME:
      self.cursorPos = 0
    of sdl.SDLK_END:
      self.cursorPos = self.val.runeLen
    of sdl.SDLK_BACKSPACE:
      # remove the rune before the cursor; runeSubStr length counts runes
      if self.cursorPos > 0:
        self.val = self.val.runeSubStr(0, self.cursorPos - 1) &
                   self.val.runeSubStr(self.cursorPos)
        dec self.cursorPos
    of sdl.SDLK_DELETE:
      # remove the rune at the cursor
      if self.cursorPos < self.val.runeLen:
        self.val = self.val.runeSubStr(0, self.cursorPos) &
                   self.val.runeSubStr(self.cursorPos + 1)
    else:
      return false

    #! cursor moved or text edited: collapse the selection and repaint
    self.selectionStart = self.cursorPos
    self.redrawFlag = rkFullRedraw
    result = true





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
    let this = MonoTextBox(self)

    const debug = 0b0

    when debug > 0:
      echo "draw()"
      echo this.name
      echo "w: ",this.w, " h: ", this.h
      echo "x1: ",this.x1, " y1: ", this.y1
      echo "___________"

    #.............................

    # clipRect (screen coordinates) hides overflow: the intersection of all
    # ancestors' on-screen rects. It must clip ONLY the final on-screen copy,
    # not the texture-local rendering below.
    #* SCREEN CORDINATES
    var clipRect = this.clipRect
    if clipRect.w == 0 or clipRect.h == 0:
      #! off-screen: skip render; redrawFlag stays set so it repaints when visible again
      return
    #.............................

    # The area of this button on the screen,
    # shifted by the accumulated scroll offsets of its ancestors.
    # Screen-space destination rectangle for rendering (adjusted for scroll).
    #* SCREEN CORDINATES
    var screenFRect = sdl.FRect(
      x: (this.x1 - scrollXArg).cfloat,
      y: (this.y1 - scrollYArg).cfloat,
      w: this.w.cfloat,
      h: this.h.cfloat
    )
    # .............................

    # canvasRect is the rect we can paint
    # after
    # sdl.setRenderTarget(this.window.renderer, this.textureCache)
    #* TEXTURE COORDINATES
    var canvasFRect = sdl.FRect(
      x: 0.0,
      y: 0.0,
      w: this.w.cfloat,
      h: this.h.cfloat
    )
    # .............................


    # we need to redraw, even if not changed
    if this.redrawFlag != rkFullRedraw and this.textureCache != nil and this.textureCacheWithCursor != nil:
        discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)

        if this.pgui.focusElem == this:
          #* draw cursor
#[           let elapsedTicks = getMonoTime().ticks - this.lastDrawTick
          if elapsedTicks > 500_000_000.int64: # nanoseconds
            this.drawCursor = not this.drawCursor
            this.lastDrawTick = getMonoTime().ticks ]#

          if this.drawCursor:
            discard this.window.renderer.renderTexture(
              this.textureCacheWithCursor,
              nil, addr screenFRect)  
          else:
            discard this.window.renderer.renderTexture(
              this.textureCache,
              nil, addr screenFRect)           

        else:
          #* only texturecache plays here
          discard this.window.renderer.renderTexture(
              this.textureCache,
              nil, addr screenFRect)
      #=============================================


    else:
      #*--------------------------------------------
      #*          ---== REDRAWING ==---
      #*--------------------------------------------
      #* if need to redraw, check if cache setted up
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

      #* the elems. texture is the render target x=0 y=0!
      discard sdl.setRenderTarget(this.window.renderer, this.textureCache)
      discard setRenderDrawColor(this.window.renderer, transparentColor)
      discard this.window.renderer.renderClear()

      #*-----------------------------
      #* DRAWING ON TEXTURECACHE
      #*-----------------------------

      #* draw the background --------------------------------------
      if this.styleCache[this.activeStyle].backGroundColor != EmptyColor:
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].backGroundColor)

      discard this.window.renderer.renderFillRect(addr(canvasFRect))

      #* draw border --------------------------------------
      if this.styleCache[this.activeStyle].borderColor != EmptyColor:
        discard setRenderDrawColor(this.window.renderer,
          this.styleCache[this.activeStyle].borderColor)
      discard this.window.renderer.renderRect(addr(canvasFRect))
      
      #* draw the text --------------------------------------
      if this.val.len > 0:
        let
          fontColor = this.styleCache[this.activeStyle].color
          fontBgColor = this.styleCache[this.activeStyle].backGroundColor

        let surface = ttf.renderTextBlended(
                                    this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr,
                                    this.val.cstring,
                                    0,
                                    fontColor
                                    )

        if surface == nil:
          #* font render failed: release target/clip before bailing, keep redrawFlag set
          discard sdl.setRenderTarget(this.window.renderer, nil)
          discard sdl.setRenderClipRect(this.window.renderer, nil)
          return

        #* set important type fields for cursor drawing
        this.charWidth = surface.w div this.val.len

        let texture = sdl.createTextureFromSurface(this.window.renderer, surface)

        var textFRect = sdl.FRect(
          x: 0.0,
          y: 0.0,
          w: surface.w.cfloat,
          h: surface.h.cfloat
        )

        #* center text --------------------------
        #TODO: textFRect clippping to this.w this.h, add padding 2px for beauty
        if canvasFRect.h > surface.h.cfloat:
          textFRect.y = (canvasFRect.h - surface.h.cfloat) / 2.0
        #[if canvasFRect.w > surface.w.cfloat:
          textFRect.x = (canvasFRect.w - surface.w.cfloat) / 2.0 ]#

        discard this.window.renderer.renderTexture(texture,
            nil, addr textFRect)

        sdl.destroySurface(surface)
        sdl.destroyTexture(texture)
      
      else:
        this.charWidth = 0
        #................................


      #* DRAW CURSOR ................................
      #* duplicate texturecache
      this.textureCacheWithCursor = duplicateTexture(
        this.window.renderer,
        this.textureCache,
        this.w.cfloat, this.h.cfloat)

      discard sdl.setRenderTarget(this.window.renderer, this.textureCacheWithCursor)

      if this.pgui.focusElem == this:
        when debug > 0: echo "[ MonoText cursor drawing ]"
        discard setRenderDrawColor(this.window.renderer,
            this.styleCache[this.activeStyle].color)

        discard this.window.renderer.renderLine(
            (this.cursorPos * this.charWidth).cfloat,
            canvasFRect.y,
            (this.cursorPos * this.charWidth).cfloat,
            canvasFRect.y + canvasFRect.h
            )


      #=====================================
      #! Reset the target back to the window (nil)
      discard sdl.setRenderTarget(this.window.renderer, nil)
      # clip only the screen-space copy
      discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
      discard this.window.renderer.renderTexture(
          this.textureCache,
          nil, addr screenFRect)


    #* reset clipping ----------------------
    discard sdl.setRenderClipRect(this.window.renderer, nil)

    this.redrawFlag = rkNoRedraw

#........................................................

#[ 
Textbox
onclick:

 ]#

