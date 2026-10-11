## NineBtn: an importable 9-slice (9-grid) button.
##
## Three 42x42 RGBA tiles compose the button face into the element's cached
## texture: a white base mask tinted from the active style's background, then a
## black shadow layer, then a highlight layer. The tint, the pressed fallback
## and the :hover / :active pseudo-styles all come from the shared style system.
##
## Lifecycle: call `loadNineBtnTextures` once (after the renderer exists) and
## `freeNineBtnTextures` before the renderer is destroyed.

import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases
import piigui/sdl3_img as img
import piigui
import piigui/[types,style]
import piigui/layout/flex
import tables
import locks
import std/os

###########################################################

const debug = 1

#*=================================================
#*                 ELEMENT
#*=================================================
type NineBtn* = ref object of DivRef
  text*: string
  state*:uint8

# one set of 9-slice layers shared by every button; the base is tinted per
# button in draw(), so the tiles live at module scope
var
  nineBase: sdl.Texture
  nineDark: sdl.Texture
  nineLight: sdl.Texture

#*=================================================
#*             9-SLICE GEOMETRY
#*=================================================
const
  # source corners are 18px in the 42px tile; the stretched middle is 6px
  NineSliceCorner: cfloat = 18.0

proc draw(self:DivRef, scrollXArg, scrollYArg:int) #!FWD
proc onMouseButtonDown(this:DivRef){.nosinks.} #!FWD
proc onMouseButtonUp(this:DivRef){.nosinks.} #!FWD
proc ninebtn_onFocus(this:DivRef){.nosinks.} #!FWD
proc ninebtn_onBlur(this:DivRef){.nosinks.} #!FWD
proc ninebtn_onDragEnd(this:DivRef){.nosinks.} #!FWD


proc newNineBtn*(parent: DivRef,
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
             ): NineBtn =

  result = new NineBtn
  initLock(result.lock)
  result.typeName = "NineBtn"
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
  result.onFocus = ninebtn_onFocus
  result.onBlur = ninebtn_onBlur
  result.onHover = piigui.default_onHover
  result.onDragStart = piigui.default_onDragStart
  result.onDragEnd = ninebtn_onDragEnd
  result.onDragOver = piigui.default_onDragOver

  # ......................
  result.text = text

  #-----------------------
  if parent != nil : parent.layers[layer].elems.add(result)
#----------------------------------------------------


#*=================================================
#*             9-SLICE DRAW
#*=================================================
# copy of piigui.drawDivRef with the debug blocks removed and the single
# renderFillRect replaced by a clear + three 9-grid copies
proc draw(self:DivRef, scrollXArg, scrollYArg:int) =
  let this = NineBtn(self)
  var clipRect = this.clipRect

  # backgroundFRect is the subpixel float rect for accelerated painting
  var backgroundFRect = sdl.FRect(
    x: 0.0,
    y: 0.0,
    w: this.w.cfloat,
    h: this.h.cfloat
  )

  # the area of this elem on screen, shifted by ancestor scroll offsets
  var thisFRect = sdl.FRect(
    x: (this.x1 - scrollXArg).cfloat,
    y: (this.y1 - scrollYArg).cfloat,
    w: this.w.cfloat,
    h: this.h.cfloat
  )

  #--------------------------------------------
  # cached: blit only
  #--------------------------------------------
  if this.redrawFlag != rkFullRedraw and this.textureCache != nil:
    discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
    discard this.window.renderer.renderTexture(
        this.textureCache,
        nil, addr thisFRect)

  #--------------------------------------------
  # dirty: rebuild the cache
  #--------------------------------------------
  else:
    if this.textureCache != nil:
      sdl.destroyTexture(this.textureCache)
    this.textureCache = sdl.createTexture(
      this.window.renderer,
      sdl.PIXELFORMAT_UNKNOWN,
      sdl.TEXTUREACCESS_TARGET,
      this.w.cint, this.h.cint)

    discard this.textureCache.setTextureBlendMode(sdl.BLENDMODE_BLEND)

    # the elems texture is the render target at x=0 y=0
    discard sdl.setRenderTarget(this.window.renderer, this.textureCache)
    #! clear first: the base has transparent rounded corners and the shadow /
    #! highlight layers use alpha, so stale target pixels must not show through
    discard setRenderDrawColor(this.window.renderer, transparentColor)
    discard this.window.renderer.clear()

    #--------------------------------------------
    # button color derived from the active style
    #--------------------------------------------
    var buttonColor = this.styleCache[this.activeStyle].backGroundColor
    #! no :active pseudo-style defined: the style is unchanged while pressed,
    #! so invert the background to show the pressed state
    if this.state == 1 and this.activeStyle != "active":
      buttonColor = invertColor(buttonColor)

    let textColor = calcFgColor(buttonColor)

    #! tint the shared white base mask per button. setTextureColorMod changes
    #! RGB only, so the rounded-corner alpha of the 9-slice stays intact
    if nineBase != nil:
      discard nineBase.setTextureColorMod(buttonColor.r,
                                          buttonColor.g,
                                          buttonColor.b)

    # nine-grid each layer in composite order: base, shadow, highlight
    for layer in [nineBase, nineDark, nineLight]:
      if layer != nil:
        discard this.window.renderer.renderTexture9Grid(
          layer, nil,
          NineSliceCorner, NineSliceCorner, NineSliceCorner, NineSliceCorner,
          1.0.cfloat, addr backgroundFRect)

    #--------------------------------------------
    # text label
    #--------------------------------------------
    #! text is rendered INTO textureCache while it is still the target, using
    #! texture-local coordinates (backgroundFRect sits at 0,0). Rendering it
    #! after releasing the target would place it at the window origin and it
    #! would be clipped away, and it would not survive cached blits.
    if this.text.len > 0:
      let font = this.pgui.fonts[this.styleCache[this.activeStyle].font].fontPtr

      let textSurf = ttf.renderTextBlended(font, this.text.cstring, 0, textColor)

      if textSurf == nil:
        #! font render failed: release target before bailing, keep redrawFlag set
        discard sdl.setRenderTarget(this.window.renderer, nil)
        discard sdl.setRenderClipRect(this.window.renderer, nil)
        return

      let textTexture = sdl.createTextureFromSurface(this.window.renderer, textSurf)

      var textFRect = sdl.FRect(
        x: backgroundFRect.x,
        y: backgroundFRect.y,
        w: textSurf.w.cfloat,
        h: textSurf.h.cfloat
      )

      # center text on the rendered surface, not the font line height
      if backgroundFRect.h > textSurf.h.cfloat:
        textFRect.y = backgroundFRect.y + (backgroundFRect.h - textSurf.h.cfloat) / 2.0
      if backgroundFRect.w > textSurf.w.cfloat:
        textFRect.x = backgroundFRect.x + (backgroundFRect.w - textSurf.w.cfloat) / 2.0

      sdl.destroySurface(textSurf)

      if getLuminance(textColor) >= 128:
        # shadow
        discard sdl.setTextureColorMod(textTexture, 0, 0, 0)
        discard sdl.setTextureAlphaMod(textTexture, 160)      # optional: softer shadow
        var shadow = textFRect
        shadow.x += 2; shadow.y += 2
        discard this.window.renderer.renderTexture(textTexture, nil, addr shadow)

      discard sdl.setTextureColorMod(textTexture, 255, 255, 255)
      discard sdl.setTextureAlphaMod(textTexture, 255)
      discard this.window.renderer.renderTexture(textTexture, nil, addr textFRect)

      #! transient per-frame text texture: release after compositing
      sdl.destroyTexture(textTexture)

    # release rendertarget, then blit the finished cache to its place on screen
    discard sdl.setRenderTarget(this.window.renderer, nil)
    # clip only the screen-space copy
    discard sdl.setRenderClipRect(this.window.renderer, clipRect.addr)
    discard this.window.renderer.renderTexture(
        this.textureCache,
        nil, addr thisFRect)

  # reset clipping
  discard sdl.setRenderClipRect(this.window.renderer, nil)

  this.redrawFlag = rkNoRedraw


#*=================================================
#*                 HANDLERS
#*=================================================
proc onMouseButtonDown(this:DivRef){.nosinks.}=
  ## pressed visual: switch to the :active pseudo-style when it exists,
  ## otherwise draw() inverts the style background (state == 1)
  NineBtn(this).state = 1
  this.setActiveStyle("active")
  this.redrawFlag = rkFullRedraw

proc onMouseButtonUp(this:DivRef){.nosinks.}=
  ## release visual: return to the element's base style (default today,
  ## RED/YELLOW/... later). Do not restore :hover here: a click makes this the
  ## pgui.focusElem and a stale hover style would linger until the next motion.
  NineBtn(this).state = 0
  this.restoreActiveStyle()
  this.redrawFlag = rkFullRedraw

proc ninebtn_onFocus(this:DivRef){.nosinks.}=
  ## keyboard focus only. The mouse-up path also calls onFocus, but keeps
  ## pgui.mouseSource set for the duration, so ignore that call to avoid
  ## leaving a clicked button stuck in the pressed visual.
  if this.pgui.mouseSource == nil:
    onMouseButtonDown(this)

proc ninebtn_onBlur(this:DivRef){.nosinks.}=
  ## focus lost: reset the pressed visual; never triggers a click
  onMouseButtonUp(this)

proc ninebtn_onDragEnd(this:DivRef){.nosinks.}=
  ## released over another element: restore style and clear the pressed state
  piigui.default_onDragEnd(this)
  NineBtn(this).state = 0
  this.redrawFlag = rkFullRedraw


#*=================================================
#*             9-SLICE ASSETS
#*=================================================
proc assetPath(name: string): string =
  ## resolves the 9-slice tiles relative to this source file so the widget
  ## works from any CWD; from src/piigui/ui/ninegrid the assets live four
  ## directories up under <repo>/assets
  result = parentDir(currentSourcePath()) / ".." / ".." / ".." / ".." / "assets" / name

proc loadNineSliceLayer(renderer: RendererPtr, path: string): sdl.Texture =
  let surface = imgLoad(path.cstring)
  if surface == nil:
    echo "loadNineSliceLayer: cannot load ", path, ": ", sdl.getError()
    return nil
  result = sdl.createTextureFromSurface(renderer, surface)
  sdl.destroySurface(surface)
  if result != nil:
    discard result.setTextureBlendMode(sdl.BLENDMODE_BLEND)
  when debug > 0: echo "loadNineSliceLayer: loaded ", path

proc loadNineBtnTextures*(renderer: RendererPtr) =
  ## loads the three 9-slice layers; call once after the renderer exists.
  ## the white base mask is tinted per button in draw().
  nineBase = loadNineSliceLayer(renderer, assetPath("button_9slice_base.png"))
  nineDark = loadNineSliceLayer(renderer, assetPath("button_9slice_dark.png"))
  nineLight = loadNineSliceLayer(renderer, assetPath("button_9slice_light.png"))

proc freeNineBtnTextures*() =
  ## releases the shared 9-slice layers; call before the renderer is destroyed.
  if nineBase != nil:
    sdl.destroyTexture(nineBase)
    nineBase = nil
  if nineDark != nil:
    sdl.destroyTexture(nineDark)
    nineDark = nil
  if nineLight != nil:
    sdl.destroyTexture(nineLight)
    nineLight = nil


#*=================================================
#*                 PUBLIC API
#*=================================================
template setText*(this: NineBtn, val: string)=
  this.text = val
  this.redrawFlag = rkFullRedraw
