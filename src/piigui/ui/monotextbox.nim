## Single-line monospace text input.
##
## Text is stored rune-oriented: `valCursorPos` counts runes in the whole
## `val`, while `screenCursorPos` is the column the cursor is painted at.
## The whole text is rendered once into `textTextureCache` and the background
## into `backgroundTextureCache`, so scrolling only recomposes the visible
## slice instead of re-rendering the font.

import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases
import piigui
import piigui/[types,style]
import piigui/layout/flex
#import piigui/layout/recalcH as recalcHMod
#import piigui/layout/recalcV as recalcVMod

import tables
import unicode
import locks
import std/monotimes

const
  debug = 1
  MaxValRunes* = 384 # 256 ## max rune count of `val`; bounds the cached text texture

type
  MonoTextBox* = ref object of DivRef
    val*: string # text is val here
    undoVal*: string = "" # snapshot at text-input start; Ctrl+Z restores it
    valCursorPos*: int = 0 # cursor position in `val`, counted in runes
    valRuneLen*: int = 0 # cached `val.runeLen`; bounds valCursorPos

    screenCursorPos*: int = 0 # cursor column on screen, counted in runes
    maxScreenCursorPos*: int = 0 # rightmost cursor column: w div charWidth
    scrollOffset*: int = 0 # index of the first visible rune in `val`

    selectionStart*: int = 0 # if == valCursorPos: no selection

    charWidth*: int

    backgroundTextureCache*: TexturePtr # background+border, reused while scrolling
    textTextureCache*: TexturePtr # whole `val` rendered once, sliced on scroll
    textureCacheWithCursor*: TexturePtr # textureCache plus the cursor line
    textTextureOffset*: cfloat # src.x into textTextureCache: scrollOffset*charWidth
    textTextureW*: int
    textTextureH*: int

    lastDrawTick: int64 # blink effect
    drawCursor: bool = false

  TextBox* = MonoTextBox

#----------------------------------------------------

#*=================================================
#*       FORWARD DECLARATIONS FOR READBILITY
#*=================================================

proc onFocus(this:DivRef){.nosinks.} #!FWD
proc onBlur(this:DivRef){.nosinks.} #!FWD
proc onTextInput(this: DivRef, val:string){.nosinks.} #!FWD
proc onMouseButtonUp(this:DivRef) #!FWD
proc onClick(this:DivRef, eventObj:sdl.Event) #!FWD
proc keyDownEventListener(self:DivRef, e:sdl.Event):bool {.nosinks.} #!FWD

proc clampToMaxRunes(val: string): string #!FWD
proc measureCharWidthIfNeeded(this: MonoTextBox) #!FWD
proc updateCursorView(this: MonoTextBox) #!FWD

#* texture-cache helpers used by draw, defined further down
proc ensureTextureTargets(this: MonoTextBox): bool #!FWD
proc renderBackgroundCache(this: MonoTextBox) #!FWD
proc renderTextTexture(this: MonoTextBox): bool #!FWD
proc composeTextureCache(this: MonoTextBox) #!FWD
proc composeCursorTexture(this: MonoTextBox) #!FWD

proc draw*(self:DivRef, scrollXArg, scrollYArg:int) #!FWD







#[ 
##    ## ######## ##      ## 
###   ## ##       ##  ##  ## 
####  ## ##       ##  ##  ## 
## ## ## ######   ##  ##  ## 
##  #### ##       ##  ##  ## 
##   ### ##       ##  ##  ## 
##    ## ########  ###  ###  
 ]#
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
  const debug = 0

  result = new TextBox
  initLock(result.lock)
  result.typeName = "TextBox"
  result.iD = piigui.getNextGlobalID()

  #* hard cap: a single cached text texture must stay within GPU size limits
  result.val = clampToMaxRunes(val)
  result.valRuneLen = result.val.runeLen
  result.valCursorPos = 0 #? result.val.runeLen

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
########  ########     ###    ##      ## 
##     ## ##     ##   ## ##   ##  ##  ## 
##     ## ##     ##  ##   ##  ##  ##  ## 
##     ## ########  ##     ## ##  ##  ## 
##     ## ##   ##   ######### ##  ##  ## 
##     ## ##    ##  ##     ## ##  ##  ## 
########  ##     ## ##     ##  ###  ###  
 ]#


proc draw*(self:DivRef, scrollXArg, scrollYArg:int)=
  ## Paints from the texture caches. Full redraws rebuild background and text;
  ## scrolling only recomposes the visible slice, cursor moves only the
  ## cursor texture, and blink blits whichever cursor texture is current.
  withLock self.lock:
    let this = MonoTextBox(self)

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

    # The area of this button on the screen, shifted by the accumulated scroll
    # offsets of its ancestors.
    #* SCREEN CORDINATES
    var screenFRect = sdl.FRect(
      x: (this.x1 - scrollXArg).cfloat,
      y: (this.y1 - scrollYArg).cfloat,
      w: this.w.cfloat,
      h: this.h.cfloat)
    #.............................

    this.measureCharWidthIfNeeded()
    this.updateCursorView()

    let needsFullRebuild =
      this.redrawFlag == rkFullRedraw or
      this.textureCache == nil or
      this.backgroundTextureCache == nil or
      this.textureCacheWithCursor == nil

    #*--------------------------------------------
    #*          ---== REDRAWING ==---
    #*--------------------------------------------
    if needsFullRebuild:
      if not this.ensureTextureTargets():
        #! SDL could not create the targets; keep redrawFlag set and retry
        return

      #* draw the background
      this.renderBackgroundCache()

      if not this.renderTextTexture():
        #* font render failed: release the target, keep redrawFlag set
        discard sdl.setRenderTarget(this.window.renderer, nil)
        return

      #* charWidth may have been re-derived from the rendered surface
      this.updateCursorView()
      this.composeTextureCache()
      this.composeCursorTexture()

    else:
      #* partial redraws: rebuild only what the flag says changed
      case this.redrawFlag
      of rkScrollTexture:
        this.composeTextureCache()
        this.composeCursorTexture()
      of rkCursorRedraw:
        this.composeCursorTexture()
      else:
        discard # rkPartialRedraw / rkNoRedraw: cached textures are current

    #*--------------------------------------------
    #* blit the current cache to the window
    #*--------------------------------------------
    discard sdl.setRenderTarget(this.window.renderer, nil)
    discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)

    #*--------------------------------------------
    #* blink the cursor :)
    #*--------------------------------------------
    #* pick the texture that matches the current blink phase
    let blitTexture =
      if this.pgui.focusElem == this and this.drawCursor:
        this.textureCacheWithCursor
      else:
        this.textureCache

    if blitTexture != nil:
      discard this.window.renderer.renderTexture(
          blitTexture,
          nil, addr screenFRect)

    #* reset clipping ----------------------
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

proc `value=`*(this: TextBox, val:string)=
  withLock this.lock:
    this.val = clampToMaxRunes(val)
    this.valRuneLen = this.val.runeLen
    this.valCursorPos = this.valRuneLen
    this.updateCursorView()
  this.redrawFlag = rkFullRedraw


proc value*(this: TextBox):string= this.val


proc insertText*(this: TextBox, text: string) =
  ## Inserts `text` at the cursor, UTF-8 safe and capped at `MaxValRunes`.
  ## Acquires the element lock, so it is safe to call from any thread.
  withLock this.lock:
    if text.len == 0:
      return

    let freeRunes = MaxValRunes - this.valRuneLen
    if freeRunes <= 0:
      return # full: drop the input instead of overflowing the texture cap

    var insertVal = text
    if insertVal.runeLen > freeRunes:
      insertVal = insertVal.runeSubStr(0, freeRunes) # never split a rune

    if this.valCursorPos == 0:
      # prepend
      this.val = insertVal & this.val
    elif this.valCursorPos >= this.valRuneLen:
      # append
      this.val &= insertVal
    else:
      # UTF-8 safe insert in the middle; runeSubStr counts runes
      this.val = this.val.runeSubStr(0, this.valCursorPos) &
                  insertVal &
                  this.val.runeSubStr(this.valCursorPos)

    this.valCursorPos += insertVal.runeLen
    this.valRuneLen = this.val.runeLen
    this.updateCursorView()
    this.redrawFlag = rkFullRedraw


#----------------------------------------------------








######## #### ##     ## ######## ########   ######  
   ##     ##  ###   ### ##       ##     ## ##    ## 
   ##     ##  #### #### ##       ##     ## ##       
   ##     ##  ## ### ## ######   ########   ######  
   ##     ##  ##     ## ##       ##   ##         ## 
   ##     ##  ##     ## ##       ##    ##  ##    ## 
   ##    #### ##     ## ######## ##     ##  ######  



proc cursorTimedEvent*(this: DivRef, nowNs: int64)=
  let self = MonoTextBox(this)
  #let elapsed = nowNs - self.lastDrawTick
  if nowNs - self.lastDrawTick > 500_000_000'i64:
    self.drawCursor = not self.drawCursor
    self.lastDrawTick = nowNs
    # only the cursor changed; the widget's draw picks the cached cursor
    # texture. setRedrawFlag escalates to a full redraw if another request is
    # already pending on this element.
    self.setRedrawFlag(rkPartialRedraw)








######## ##     ## ######## ##    ## ########                               
##       ##     ## ##       ###   ##    ##                                  
##       ##     ## ##       ####  ##    ##                                  
######   ##     ## ######   ## ## ##    ##                                  
##        ##   ##  ##       ##  ####    ##                                  
##         ## ##   ##       ##   ###    ##                                  
########    ###    ######## ##    ##    ##                                  
                                                                            
                                                                            
##     ##    ###    ##    ## ########  ##       ######## ########   ######  
##     ##   ## ##   ###   ## ##     ## ##       ##       ##     ## ##    ## 
##     ##  ##   ##  ####  ## ##     ## ##       ##       ##     ## ##       
######### ##     ## ## ## ## ##     ## ##       ######   ########   ######  
##     ## ######### ##  #### ##     ## ##       ##       ##   ##         ## 
##     ## ##     ## ##   ### ##     ## ##       ##       ##    ##  ##    ## 
##     ## ##     ## ##    ## ########  ######## ######## ##     ##  ######  



proc onFocus(this:DivRef){.nosinks.}=
  when debug > 0: echo "[ MonoText Focusing ]"

  piigui.default_onFocus(this)
  if this.window != nil:
    discard sdl.startTextInput(this.window.window)

  let self = MonoTextBox(this)
  self.measureCharWidthIfNeeded()
  withLock self.lock:
    #* snapshot for single-level Ctrl+Z undo at the moment input starts
    self.undoVal = self.val
    self.updateCursorView()

  this.redrawFlag = rkFullRedraw

  self.drawCursor = true
  self.lastDrawTick = getMonoTime().ticks

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

  let self = MonoTextBox(this)
  self.measureCharWidthIfNeeded()
  withLock self.lock:
    #* convert the clicked pixel column into a rune index in the whole text;
    #* scrollOffset maps the visible window back to `val`
    if self.charWidth > 0:
      let clickedCol = max(0, eventObj.motion.x.int - this.x1) div self.charWidth
      self.valCursorPos = clamp(self.scrollOffset + clickedCol, 0, self.valRuneLen)
    self.updateCursorView()
    self.drawCursor = true
    self.lastDrawTick = getMonoTime().ticks
  this.setRedrawFlag(rkCursorRedraw)

proc onTextInput(this: DivRef, val:string){.nosinks.}=
      let self = TextBox(this)
      #TODO: if selection: clear
      #TODO: cursor to selection start
      self.insertText(val)
      #! restart the blink so the caret shows immediately after the edit
      withLock self.lock:
        self.drawCursor = true
        self.lastDrawTick = getMonoTime().ticks


proc keyDownEventListener(self:DivRef, e:sdl.Event):bool {.nosinks.}=
  # hidevents always hands us a real key event; a bare trigger("keydown")
  # would pass the default(sdl.Event) sentinel (type == EVENT_FIRST).
  # Return false for anything we do not consume so the event keeps bubbling to
  # window/pgui listeners (and so the scancode bus still fires at this scope).
  if e.`type` != sdl.EVENT_KEY_DOWN:
    return false

  let this = MonoTextBox(self)
  when debug > 1: echo "keyDownEventListener: key=", e.key.key

  #* Enter leaves the single-line field. Blur touches focus and timed events,
  #* so run it outside this element's data lock.
  if e.key.key == sdl.SDLK_RETURN:
    if this.onBlur != nil:
      this.onBlur(this)
    return true

  this.measureCharWidthIfNeeded()

  withLock this.lock:
    #* Ctrl+Z: single-level undo back to the value snapshotted at focus
    if (e.key.`mod`.uint32 and sdl.KMOD_CTRL) != 0'u32 and e.key.key == sdl.SDLK_Z:
      this.val = this.undoVal
      this.valRuneLen = this.val.runeLen
      this.valCursorPos = this.valRuneLen
      this.selectionStart = this.valCursorPos
      this.updateCursorView()
      this.redrawFlag = rkFullRedraw
      return true

    let oldScrollOffset = this.scrollOffset
    var isTextEdit = false

    case e.key.key
    of sdl.SDLK_LEFT:
      if this.valCursorPos > 0:
        dec this.valCursorPos

    of sdl.SDLK_RIGHT:
      if this.valCursorPos < this.valRuneLen:
        inc this.valCursorPos

    of sdl.SDLK_HOME:
      this.valCursorPos = 0

    of sdl.SDLK_END:
      this.valCursorPos = this.valRuneLen

    of sdl.SDLK_BACKSPACE:
      # remove the rune before the cursor; runeSubStr counts runes
      if this.valCursorPos > 0:
        this.val = this.val.runeSubStr(0, this.valCursorPos - 1) &
                   this.val.runeSubStr(this.valCursorPos)
        dec this.valCursorPos
        isTextEdit = true

    of sdl.SDLK_DELETE:
      # remove the rune at the cursor
      if this.valCursorPos < this.valRuneLen:
        this.val = this.val.runeSubStr(0, this.valCursorPos) &
                   this.val.runeSubStr(this.valCursorPos + 1)
        isTextEdit = true

    else:
      return false

    #* text edits rebuild the font texture; pure navigation reuses it and
    #* only scrolls or repaints the cursor
    if isTextEdit:
      this.valRuneLen = this.val.runeLen
      this.updateCursorView()
      this.redrawFlag = rkFullRedraw
    else:
      this.updateCursorView()
      if this.scrollOffset != oldScrollOffset:
        this.setRedrawFlag(rkScrollTexture)
      else:
        this.setRedrawFlag(rkCursorRedraw)

    this.selectionStart = this.valCursorPos
    #! show the caret at once instead of waiting for the next blink phase
    this.drawCursor = true
    this.lastDrawTick = getMonoTime().ticks

  result = true














##     ## ######## ##       ########  
##     ## ##       ##       ##     ## 
##     ## ##       ##       ##     ## 
######### ######   ##       ########  
##     ## ##       ##       ##        
##     ## ##       ##       ##        
##     ## ######## ######## ##        


#*=================================================
#*              CURSOR / VIEW HELPERS
#*=================================================

proc clampToMaxRunes(val: string): string =
  ## Hard cap for `val`. `runeSubStr` keeps the truncation on a rune boundary.
  if val.runeLen > MaxValRunes:
    result = val.runeSubStr(0, MaxValRunes)
  else:
    result = val

proc measureCharWidthIfNeeded(this: MonoTextBox) =
  ## A single glyph advance gives the exact monospace step. Needed before the
  ## first draw (empty `val`, key press before any frame) where no text
  ## surface exists to derive `charWidth` from.
  if this.charWidth > 0 or this.pgui == nil:
    return
  let font = this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr
  var w, h: cint
  if ttf.getStringSize(font, "M".cstring, 1, w, h):
    this.charWidth = w.int

proc updateCursorView(this: MonoTextBox) =
  ## Single source of truth for the visible window: clamps the cursor, applies
  ## the minimal scroll that keeps it visible, then derives the drawn column
  ## and the text texture source offset.
  if this.charWidth <= 0 or this.w <= 0:
    # no usable metrics or width yet: keep the view at the start
    this.maxScreenCursorPos = 0
    this.scrollOffset = 0
    this.screenCursorPos = 0
    this.textTextureOffset = 0.0
    return

  this.maxScreenCursorPos = this.w div this.charWidth
  this.valCursorPos = clamp(this.valCursorPos, 0, this.valRuneLen)
  let maxScrollOffset = max(0, this.valRuneLen - this.maxScreenCursorPos)

  if this.valCursorPos < this.scrollOffset:
    this.scrollOffset = this.valCursorPos
  elif this.valCursorPos > this.scrollOffset + this.maxScreenCursorPos:
    this.scrollOffset = this.valCursorPos - this.maxScreenCursorPos

  this.scrollOffset = clamp(this.scrollOffset, 0, maxScrollOffset)
  this.screenCursorPos = this.valCursorPos - this.scrollOffset
  this.textTextureOffset = (this.scrollOffset * this.charWidth).cfloat

#*=================================================
#*              TEXTURE CACHES
#*=================================================

proc destroyCachedTexture(texture: var TexturePtr) =
  ## Releases one cached GPU texture and clears the reference so a later
  ## replacement never double-frees.
  if texture != nil:
    sdl.destroyTexture(texture)
    texture = nil

proc createTargetTexture(this: MonoTextBox): TexturePtr =
  ## Creates a blend-capable render target sized to this element.
  result = sdl.createTexture(
    this.window.renderer,
    sdl.PIXELFORMAT_RGBA8888,
    sdl.TEXTUREACCESS_TARGET,
    this.w.cint,
    this.h.cint)
  if result != nil:
    discard result.setTextureBlendMode(sdl.BLENDMODE_BLEND)

proc ensureTextureTargets(this: MonoTextBox): bool =
  ## (Re)creates the three render targets when missing or after a resize.
  ## Destroying the old textures first keeps resizing leak-free.
  ## Returns false when SDL could not create the targets, so the caller keeps
  ## the redraw request and retries on the next frame.
  var currentW, currentH: cfloat
  let hasValidTargets =
    this.textureCache != nil and
    this.backgroundTextureCache != nil and
    this.textureCacheWithCursor != nil and
    sdl.getTextureSize(this.textureCache, currentW, currentH) and
    currentW.int == this.w and currentH.int == this.h
  if hasValidTargets:
    return true

  destroyCachedTexture(this.textureCache)
  destroyCachedTexture(this.backgroundTextureCache)
  destroyCachedTexture(this.textureCacheWithCursor)

  this.textureCache = this.createTargetTexture()
  this.backgroundTextureCache = this.createTargetTexture()
  this.textureCacheWithCursor = this.createTargetTexture()

  result = this.textureCache != nil and
           this.backgroundTextureCache != nil and
           this.textureCacheWithCursor != nil

proc renderBackgroundCache(this: MonoTextBox) =
  ## Renders background+border exactly once; the result is reused verbatim
  ## whenever the text scrolls.
  discard sdl.setRenderTarget(this.window.renderer, this.backgroundTextureCache)
  discard setRenderDrawColor(this.window.renderer, transparentColor)
  discard this.window.renderer.renderClear()

  var canvasFRect = sdl.FRect(
    x: 0.0,
    y: 0.0,
    w: this.w.cfloat,
    h: this.h.cfloat)

  #* draw the background
  let backGroundColor = this.styleCache[this.activeStyle].backGroundColor
  if backGroundColor != EmptyColor:
    discard setRenderDrawColor(this.window.renderer, backGroundColor)
  else:
    discard setRenderDrawColor(this.window.renderer, transparentColor)
  discard this.window.renderer.renderFillRect(addr(canvasFRect))

  #* draw border (canvas edge; the outer half is clipped by the target)
  #TODO: bordersize
  if this.styleCache[this.activeStyle].borderColor != EmptyColor:
    discard setRenderDrawColor(this.window.renderer,
      this.styleCache[this.activeStyle].borderColor)
    discard this.window.renderer.renderRect(addr(canvasFRect))

proc renderTextTexture(this: MonoTextBox): bool =
  ## Renders the whole `val` once into `textTextureCache`; scrolling later
  ## slices this texture instead of re-rendering the font.
  ## Returns false on SDL failure so the caller keeps the redraw request.
  destroyCachedTexture(this.textTextureCache)
  this.textTextureW = 0
  this.textTextureH = 0

  if this.val.len == 0:
    return true

  let
    font = this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr
    fontColor = this.styleCache[this.activeStyle].color

  #* sscmSupported/sscmUnknown render white and tint with setTextureColorMod;
  #* sscmUnsupported renders already colored. Unknown probes the cheap path once.
  let useColorMod = this.pgui.state.SupportsColorMod != sscmUnsupported
  let renderColor = if useColorMod: whiteColor else: fontColor

  var surface = ttf.renderTextBlended(font, this.val.cstring, 0, renderColor)
  if surface == nil:
    return false

  var
    surfaceW = surface.w.int
    surfaceH = surface.h.int
    texture = sdl.createTextureFromSurface(this.window.renderer, surface)
  destroySurface(surface)
  if texture == nil:
    return false

  if useColorMod:
    #* tint the white render; alpha is not covered by setTextureColorMod
    if texture.setTextureColorMod(
        fontColor.r.uint8, fontColor.g.uint8, fontColor.b.uint8):
      if fontColor.a < 255'u8:
        discard texture.setTextureAlphaMod(fontColor.a)
      this.pgui.state.SupportsColorMod = sscmSupported
    else:
      #* tinting unsupported: drop the white texture and render colored instead
      this.pgui.state.SupportsColorMod = sscmUnsupported
      sdl.destroyTexture(texture)
      texture = nil
      surface = ttf.renderTextBlended(font, this.val.cstring, 0, fontColor)
      if surface == nil:
        return false
      surfaceW = surface.w.int
      surfaceH = surface.h.int
      texture = sdl.createTextureFromSurface(this.window.renderer, surface)
      destroySurface(surface)
      if texture == nil:
        return false

  this.textTextureCache = texture
  this.textTextureW = surfaceW
  this.textTextureH = surfaceH
  if this.valRuneLen > 0:
    this.charWidth = this.textTextureW div this.valRuneLen
  result = true

proc composeTextureCache(this: MonoTextBox) =
  ## Rebuilds `textureCache` from the cached background plus the visible slice
  ## of `textTextureCache`, starting at `textTextureOffset`.
  ## The render target is reset by the caller when this returns.
  discard sdl.setRenderTarget(this.window.renderer, this.textureCache)
  discard setRenderDrawColor(this.window.renderer, transparentColor)
  discard this.window.renderer.renderClear()

  if this.backgroundTextureCache != nil:
    discard this.window.renderer.renderTexture(this.backgroundTextureCache, nil, nil)

  if this.textTextureCache != nil and this.textTextureW > 0:
    let
      #* slice from the full text texture: rest of the text after the scroll
      visibleW = min(this.w.cfloat, this.textTextureW.cfloat - this.textTextureOffset)
      #* single line is vertically centered in the box
      textY =
        if this.h.cfloat > this.textTextureH.cfloat:
          (this.h.cfloat - this.textTextureH.cfloat) / 2.0
        else:
          0.0

    if visibleW > 0.0:
      var
        srcFRect = sdl.FRect(
          x: this.textTextureOffset,
          y: 0.0,
          w: visibleW,
          h: this.textTextureH.cfloat)
        dstFRect = sdl.FRect(
          x: 0.0,
          y: textY,
          w: visibleW,
          h: this.textTextureH.cfloat)
      discard this.window.renderer.renderTexture(
        this.textTextureCache, addr srcFRect, addr dstFRect)

proc composeCursorTexture(this: MonoTextBox) =
  ## Copies `textureCache` and bakes the cursor line into
  ## `textureCacheWithCursor` so blinking is a single texture blit.
  ## The render target is reset by the caller when this returns.
  discard sdl.setRenderTarget(this.window.renderer, this.textureCacheWithCursor)
  discard setRenderDrawColor(this.window.renderer, transparentColor)
  discard this.window.renderer.renderClear()

  if this.textureCache != nil:
    discard this.window.renderer.renderTexture(this.textureCache, nil, nil)

  if this.pgui.focusElem == this:
    discard setRenderDrawColor(this.window.renderer,
      this.styleCache[this.activeStyle].color)
    #* clamp to the last pixel so a cursor at the right edge stays visible
    let cursorX = max(0.0,
      min((this.screenCursorPos * this.charWidth).cfloat, (this.w - 1).cfloat))
    discard this.window.renderer.renderLine(
        cursorX,
        0.0,
        cursorX,
        this.h.cfloat)

#----------------------------------------------------



#==========================================================
# THE END
#==========================================================
