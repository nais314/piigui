import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/ttf

import piigui/[types, style]
import tables
import locks

##[
  Standalone overlay scrollbar.

  A ScrollBar hangs off a scrollable container via `DivObj.scrollbar`.
  It is NOT a child in any layer, so recalcDOM / flex layout / the scroll
  offset / copyElem / removeElem all ignore it. It is drawn and hit-tested
  explicitly:
    - drawn by `drawScrollBar` from `drawDOM` (on top of the content)
    - hit by `hitTest` from `getElementAtCoord` (topmost)
    - positioned by `recalcScrollbar`, called from `recalcScrollbars`
      (after recalcDOM) and after every scroll change.

  Styling is strictly optional: every part inherits `rootStyle` (the usual
  cascade). If the user registered `scrollbarTrack`, `scrollbarSlider` or
  `scrollbarArrow` in `defaultSST`, the part's class style is layered on
  top, including its `hover` / `focus` pseudo-styles.
]##

#-------------------------------------------------------
# helpers
#-------------------------------------------------------

type
  ArrowDir* = enum
    adUp, adDown, adLeft, adRight

proc clampInt*(v, lo, hi: int): int =
  if v < lo: lo
  elif v > hi: hi
  else: v

proc clampFloat*(v, lo, hi: float): float =
  if v < lo: lo
  elif v > hi: hi
  else: v

proc setRect*(elem: DivRef, x1, y1, w, h: int) =
  if elem == nil: return
  if w <= 0 or h <= 0:
    elem.w = 0
    elem.h = 0
    elem.x1 = x1
    elem.y1 = y1
    elem.x2 = x1 - 1
    elem.y2 = y1 - 1
    return
  elem.x1 = x1
  elem.y1 = y1
  elem.w = w
  elem.h = h
  elem.x2 = x1 + w - 1
  elem.y2 = y1 + h - 1

proc ancestorScroll*(elem: DivRef): tuple[x,y:int] =
  ## scroll offsets of all scrollable ancestors (screen-space delta)
  var cur = elem.parent
  while cur != nil:
    if cur.scrollable:
      result.x += cur.scrollX
      result.y += cur.scrollY
    cur = cur.parent

proc scrollOwner(elem: DivRef): DivRef =
  ## nearest scrollable ancestor that owns a scrollbar overlay
  var cur = elem.parent
  while cur != nil:
    if cur.scrollable and cur.scrollbar != nil:
      return cur
    cur = cur.parent
  result = nil

proc ownerOffset(elem: DivRef): tuple[x,y:int] =
  ## on-screen shift of the scrollbar (owner's ancestors only,
  ## NOT the owner's own scroll which moves the content)
  let owner = scrollOwner(elem)
  if owner != nil:
    result = ancestorScroll(owner)

proc setParentClip(this: DivRef, scrollX, scrollY: int) =
  ## clip a part to its parent's on-screen rect.
  ## scrollX/Y here are the scrollbar owner's accumulated ancestor scroll
  ## (the parts sit in the owner's frame, so no subtraction is applied).
  var clipRect: sdl.Rect
  if this.parent != nil:
    clipRect.x = (this.parent.x1 - scrollX).cint
    clipRect.y = (this.parent.y1 - scrollY).cint
    clipRect.w = this.parent.w.cint
    clipRect.h = this.parent.h.cint
  else:
    clipRect.x = this.x1.cint
    clipRect.y = this.y1.cint
    clipRect.w = this.w.cint
    clipRect.h = this.h.cint
  discard sdl.setClipRect(this.window.renderer, clipRect.addr)

#-------------------------------------------------------
# part construction
#-------------------------------------------------------

proc newScrollBarPart(parent: DivRef, name, typeName, styleName: string): DivRef =
  ## like newDiv, but the part is never added to any layer.
  ## styleName is applied only if the user defined it in defaultSST,
  ## otherwise the part falls back to the inherited rootStyle.
  result = new DivRef
  initLock(result.lock)
  result.typeName = typeName
  result.iD = 0
  result.parent = parent
  result.pgui = parent.pgui
  result.window = parent.window
  result.layers = @[]
  result.layer = 0
  result.name = name
  result.inlineStyle = newStyleSheet()
  result.styleCache = newTable[string, StyleSheetRef](4)
  if defaultSST.hasKey(styleName):
    result.styles.add((styleName, defaultSST[styleName]))
  result.activeStyle = "default"
  recalcStyle(result)
  result.redrawFlag = 1

#-------------------------------------------------------
# drawing
#-------------------------------------------------------

proc scrollTrack_draw(this: DivRef, scrollX, scrollY: int) =
  setParentClip(this, scrollX, scrollY)
  let st = this.styleCache[this.activeStyle]
  this.window.renderer.setDrawColor(st.backGroundColor)
  var r: sdl.Rect
  r.x = (this.x1 - scrollX).cint
  r.y = (this.y1 - scrollY).cint
  r.w = this.w.cint
  r.h = this.h.cint
  discard this.window.renderer.fillRect(r.addr)
  discard sdl.setClipRect(this.window.renderer, nil)

proc scrollSlider_draw(this: DivRef, scrollX, scrollY: int) =
  setParentClip(this, scrollX, scrollY)
  let st = this.styleCache[this.activeStyle]
  this.window.renderer.setDrawColor(st.color)
  var r: sdl.Rect
  r.x = (this.x1 - scrollX).cint
  r.y = (this.y1 - scrollY).cint
  r.w = this.w.cint
  r.h = this.h.cint
  discard this.window.renderer.fillRect(r.addr)
  discard sdl.setClipRect(this.window.renderer, nil)

proc scrollArrow_draw(this: DivRef, dir: ArrowDir, scrollX, scrollY: int) =
  ## face is drawn with StyleSheet.color, the glyph with
  ## StyleSheet.backGroundColor. The glyph is a small rect
  ## (a triangle could not be drawn reliably across sdl2 gfx builds).
  setParentClip(this, scrollX, scrollY)
  let st = this.styleCache[this.activeStyle]

  # face
  this.window.renderer.setDrawColor(st.color)
  var r: sdl.Rect
  r.x = (this.x1 - scrollX).cint
  r.y = (this.y1 - scrollY).cint
  r.w = this.w.cint
  r.h = this.h.cint
  discard this.window.renderer.fillRect(r.addr)

  # glyph rect (centered)
  let g = max(2, min(this.w, this.h) div 3)
  this.window.renderer.setDrawColor(st.backGroundColor)
  var gr: sdl.Rect
  gr.x = (this.x1 - scrollX + (this.w - g) div 2).cint
  gr.y = (this.y1 - scrollY + (this.h - g) div 2).cint
  gr.w = g.cint
  gr.h = g.cint
  discard this.window.renderer.fillRect(gr.addr)

  discard sdl.setClipRect(this.window.renderer, nil)

#-------------------------------------------------------
# scrolling API
#-------------------------------------------------------

proc recalcScrollbar*(sb: ScrollBar) =
  ## position the overlay parts from the container's inner/content size.
  ## called after layout (recalcScrollbars) and after every scroll change.
  let sbParent = sb.parent
  if sbParent == nil: return

  sb.vScroll = sbParent.innerH > sbParent.h
  sb.hScroll = sbParent.innerW > sbParent.w

  if sb.vScroll: # position vertical scrollbar parts (arrows, track, slider)
    let vx = sbParent.x2 - ScrollBarSize + 1
    let vDownY = sbParent.y2 - ScrollBarArrowSize + 1 - (if sb.hScroll: ScrollBarSize else: 0) # bottom arrow Y, accounting for horizontal scrollbar overlap
    setRect(sb.vUp, vx, sbParent.y1, ScrollBarSize, ScrollBarArrowSize)
    setRect(sb.vDown, vx, vDownY, ScrollBarSize, ScrollBarArrowSize)
    let trackTop = sbParent.y1 + ScrollBarArrowSize
    setRect(sb.vTrack, vx, trackTop, ScrollBarSize, vDownY - trackTop)

    let vtrackH = sb.vTrack.h
    let maxScroll = max(0, sbParent.innerH - sbParent.h)
    let sliderH = clampInt((vtrackH * sbParent.h) div max(1, sbParent.innerH), ScrollBarMinSlider, vtrackH) # proportional slider height, clamped to minimum
    let sliderY = if maxScroll > 0:
                    sb.vTrack.y1 + ((vtrackH - sliderH) * sbParent.scrollY) div maxScroll
                  else:
                    sb.vTrack.y1
    setRect(sb.vSlider, sb.vTrack.x1, sliderY, sb.vTrack.w, sliderH)

  if sb.hScroll: # position horizontal scrollbar parts (arrows, track, slider)
    let hy = sbParent.y2 - ScrollBarSize + 1
    let hRightX = sbParent.x2 - ScrollBarArrowSize + 1 - (if sb.vScroll: ScrollBarSize else: 0) # right arrow X, accounting for vertical scrollbar overlap
    setRect(sb.hLeft, sbParent.x1, hy, ScrollBarArrowSize, ScrollBarSize)
    setRect(sb.hRight, hRightX, hy, ScrollBarArrowSize, ScrollBarSize)
    let trackLeft = sbParent.x1 + ScrollBarArrowSize
    setRect(sb.hTrack, trackLeft, hy, hRightX - trackLeft, ScrollBarSize)

    let htrackW = sb.hTrack.w
    let maxScroll = max(0, sbParent.innerW - sbParent.w)
    let sliderW = clampInt((htrackW * sbParent.w) div max(1, sbParent.innerW), ScrollBarMinSlider, htrackW) # proportional slider width, clamped to minimum
    let sliderX = if maxScroll > 0:
                    sb.hTrack.x1 + ((htrackW - sliderW) * sbParent.scrollX) div maxScroll
                  else:
                    sb.hTrack.x1
    setRect(sb.hSlider, sliderX, sb.hTrack.y1, sliderW, sb.hTrack.h)

proc scrollTo*(this: DivRef, x, y: int) =
  ## clamp and apply scroll offsets, then reposition the scrollbar
  if not this.scrollable: return
  let maxX = max(0, this.innerW - this.w)
  let maxY = max(0, this.innerH - this.h)
  this.scrollX = clampInt(x, 0, maxX)
  this.scrollY = clampInt(y, 0, maxY)
  this.redrawFlag = 1
  if this.scrollbar != nil:
    recalcScrollbar(this.scrollbar)

proc scrollBy*(this: DivRef, dx, dy: int) =
  scrollTo(this, this.scrollX + dx, this.scrollY + dy)

proc scrollWheel*(this: DivRef, dx, dy: int) =
  ## SDL wheel: y > 0 is wheel-up (view toward top, scrollY decreases),
  ##            x > 0 is wheel-right (view toward right, scrollX increases)
  scrollBy(this, dx * ScrollBarWheelStep, -dy * ScrollBarWheelStep)


#[ 
########  ########  ######     ###    ##        ######                                         
##     ## ##       ##    ##   ## ##   ##       ##    ##                                        
##     ## ##       ##        ##   ##  ##       ##                                              
########  ######   ##       ##     ## ##       ##                                              
##   ##   ##       ##       ######### ##       ##                                              
##    ##  ##       ##    ## ##     ## ##       ##    ##                                        
##     ## ########  ######  ##     ## ########  ######                                         
                                                                                               
                                                                                            
                                                                                               
 ######   ######  ########   #######  ##       ##       ########     ###    ########   ######  
##    ## ##    ## ##     ## ##     ## ##       ##       ##     ##   ## ##   ##     ## ##    ## 
##       ##       ##     ## ##     ## ##       ##       ##     ##  ##   ##  ##     ## ##       
 ######  ##       ########  ##     ## ##       ##       ########  ##     ## ########   ######  
      ## ##       ##   ##   ##     ## ##       ##       ##     ## ######### ##   ##         ## 
##    ## ##    ## ##    ##  ##     ## ##       ##       ##     ## ##     ## ##    ##  ##    ## 
 ######   ######  ##     ##  #######  ######## ######## ########  ##     ## ##     ##  ######  
 ]#

proc newScrollBar(container: DivRef): ScrollBar #!FWD

proc recalcScrollbars*(this: DivRef) =
  ## walk the DOM; automatically activate scrolling where the style allows it
  ## (ofScroll, the default) and the content overflows the container.
  ## the root element scrolls like any other container.
  let canScroll = this.styleCache != nil and
                  this.style.overflow == ofScroll and
                  (this.innerW > this.w or this.innerH > this.h)
  if canScroll:
    if this.scrollbar == nil:
      this.scrollbar = newScrollBar(this)
    this.scrollable = true
    recalcScrollbar(this.scrollbar)
  else:
    this.scrollable = false
    if this.scrollbar != nil:
      recalcScrollbar(this.scrollbar) # hides (vScroll/hScroll false)
  for layer in this.layers:
    for elem in layer.elems:
      recalcScrollbars(elem)

#-------------------------------------------------------
# drawing & hit-testing the overlay (called by piigui)
#-------------------------------------------------------

proc drawScrollBar*(sb: ScrollBar, scrollX, scrollY: int) =
  if sb.parent == nil: return
  if sb.vScroll: # draw vertical scrollbar parts
    if sb.vUp != nil and sb.vUp.draw != nil: sb.vUp.draw(sb.vUp, scrollX, scrollY)
    if sb.vTrack != nil and sb.vTrack.draw != nil: sb.vTrack.draw(sb.vTrack, scrollX, scrollY)
    if sb.vSlider != nil and sb.vSlider.draw != nil: sb.vSlider.draw(sb.vSlider, scrollX, scrollY)
    if sb.vDown != nil and sb.vDown.draw != nil: sb.vDown.draw(sb.vDown, scrollX, scrollY)
  if sb.hScroll: # draw horizontal scrollbar parts
    if sb.hLeft != nil and sb.hLeft.draw != nil: sb.hLeft.draw(sb.hLeft, scrollX, scrollY)
    if sb.hTrack != nil and sb.hTrack.draw != nil: sb.hTrack.draw(sb.hTrack, scrollX, scrollY)
    if sb.hSlider != nil and sb.hSlider.draw != nil: sb.hSlider.draw(sb.hSlider, scrollX, scrollY)
    if sb.hRight != nil and sb.hRight.draw != nil: sb.hRight.draw(sb.hRight, scrollX, scrollY)

proc hitTest*(sb: ScrollBar, x, y: int): DivRef =
  ## topmost visible scrollbar part under (x,y).
  ## x,y are screen coords already adjusted for ancestor scroll.
  proc inside(this: DivRef): bool =
    this != nil and this.w > 0 and this.h > 0 and
      x >= this.x1 and x <= this.x2 and y >= this.y1 and y <= this.y2

  if sb.vScroll: # test vertical scrollbar parts
    if inside(sb.vUp): return sb.vUp
    if inside(sb.vDown): return sb.vDown
    if inside(sb.vSlider): return sb.vSlider
    if inside(sb.vTrack): return sb.vTrack
  if sb.hScroll: # test horizontal scrollbar parts
    if inside(sb.hLeft): return sb.hLeft
    if inside(sb.hRight): return sb.hRight
    if inside(sb.hSlider): return sb.hSlider
    if inside(sb.hTrack): return sb.hTrack
  result = nil

#-------------------------------------------------------
# event handlers
#-------------------------------------------------------

proc scrollPart_onHover(this: DivRef) {.nosinks.} =
  if this.pgui.hoverElem != this:
    this.setActiveStyle("hover")
    if this.pgui.hoverElem != nil and
       this.pgui.focusElem != this.pgui.hoverElem:
      this.pgui.hoverElem.setDefaultStyle()
    this.pgui.hoverElem = this

proc scrollArrow_onMouseButtonDown(this: DivRef) {.nosinks.} =
  this.setActiveStyle("focus")
  this.redrawFlag = 1

proc scrollArrow_onMouseButtonUp(this: DivRef) {.nosinks.} =
  if this.pgui.hoverElem == this:
    this.setActiveStyle("hover")
  else:
    this.setDefaultStyle()
  this.redrawFlag = 1

proc scrollArrow_onClick(this: DivRef, e: sdl.Event) {.nosinks.} =
  let container = this.parent
  if container == nil or container.scrollbar == nil: return
  let sb = container.scrollbar
  if this == sb.vUp: scrollBy(container, 0, -ScrollBarArrowStep)
  elif this == sb.vDown: scrollBy(container, 0, ScrollBarArrowStep)
  elif this == sb.hLeft: scrollBy(container, -ScrollBarArrowStep, 0)
  elif this == sb.hRight: scrollBy(container, ScrollBarArrowStep, 0)

proc track_onClick(this: DivRef, e: sdl.Event) {.nosinks.} =
  ## click the track to page-scroll toward the cursor
  let container = this.parent
  if container == nil or container.scrollbar == nil: return
  let sb = container.scrollbar
  let off = ownerOffset(this)
  let mx = container.pgui.mouseX + off.x
  let my = container.pgui.mouseY + off.y

  if this == sb.vTrack:
    let maxScroll = max(0, container.innerH - container.h)
    if maxScroll > 0:
      let page = container.h
      let ny = if my < this.y1 + this.h div 2:
                 container.scrollY - page
               else:
                 container.scrollY + page
      scrollTo(container, container.scrollX, ny)
  elif this == sb.hTrack:
    let maxScroll = max(0, container.innerW - container.w)
    if maxScroll > 0:
      let page = container.w
      let nx = if mx < this.x1 + this.w div 2:
                 container.scrollX - page
               else:
                 container.scrollX + page
      scrollTo(container, nx, container.scrollY)

proc slider_onDragStart(this: DivRef) {.nosinks.} =
  ## save the begin scroll (for Escape-cancel) and switch to "focus"
  let container = if this.parent != nil: this.parent.parent else: nil
  if container != nil:
    this.origX1 = container.scrollX
    this.origY1 = container.scrollY
    this.dragSaved = true
  this.setActiveStyle("focus")
  this.redrawFlag = 1

proc slider_onDragOver(this: DivRef) {.nosinks.} =
  ## map the cursor to a clamped scroll offset (the slider stays in the track)
  let track = this.parent
  let container = if track != nil: track.parent else: nil
  if container == nil or container.scrollbar == nil: return
  let sb = container.scrollbar
  let off = ownerOffset(this)
  let my = container.pgui.mouseY + off.y
  let mx = container.pgui.mouseX + off.x

  if this == sb.vSlider:
    let maxScroll = max(0, container.innerH - container.h)
    if maxScroll > 0 and track.h > this.h:
      let trackLen = track.h - this.h
      let frac = clampFloat((my - track.y1 - this.h div 2).float / trackLen.float, 0.0, 1.0)
      scrollTo(container, container.scrollX, int(frac * maxScroll.float))
  elif this == sb.hSlider:
    let maxScroll = max(0, container.innerW - container.w)
    if maxScroll > 0 and track.w > this.w:
      let trackLen = track.w - this.w
      let frac = clampFloat((mx - track.x1 - this.w div 2).float / trackLen.float, 0.0, 1.0)
      scrollTo(container, int(frac * maxScroll.float), container.scrollY)

proc slider_onDragEnd(this: DivRef) {.nosinks.} =
  this.dragSaved = false
  this.setDefaultStyle()
  this.redrawFlag = 1

proc slider_onDragCancel(this: DivRef) {.nosinks.} =
  ## Escape: restore the begin scroll
  let container = if this.parent != nil: this.parent.parent else: nil
  if container != nil and this.dragSaved:
    scrollTo(container, this.origX1, this.origY1)
  this.dragSaved = false
  this.setDefaultStyle()
  this.redrawFlag = 1

#-------------------------------------------------------
# construction
#-------------------------------------------------------

proc newScrollBar(container: DivRef): ScrollBar =
  result = new ScrollBar
  result.parent = container
  result.pgui = container.pgui
  result.window = container.window

  # vertical
  result.vUp = newScrollBarPart(container, container.name & "_vUp", "ScrollBarArrow", "scrollbarArrow")
  result.vDown = newScrollBarPart(container, container.name & "_vDown", "ScrollBarArrow", "scrollbarArrow")
  result.vTrack = newScrollBarPart(container, container.name & "_vTrack", "ScrollBarTrack", "scrollbarTrack")
  result.vSlider = newScrollBarPart(result.vTrack, container.name & "_vSlider", "ScrollBarSlider", "scrollbarSlider")

  # horizontal
  result.hLeft = newScrollBarPart(container, container.name & "_hLeft", "ScrollBarArrow", "scrollbarArrow")
  result.hRight = newScrollBarPart(container, container.name & "_hRight", "ScrollBarArrow", "scrollbarArrow")
  result.hTrack = newScrollBarPart(container, container.name & "_hTrack", "ScrollBarTrack", "scrollbarTrack")
  result.hSlider = newScrollBarPart(result.hTrack, container.name & "_hSlider", "ScrollBarSlider", "scrollbarSlider")

  # draw procs
  result.vUp.draw = proc(this: DivRef, scrollX, scrollY: int) =
    scrollArrow_draw(this, adUp, scrollX, scrollY)
  result.vDown.draw = proc(this: DivRef, scrollX, scrollY: int) =
    scrollArrow_draw(this, adDown, scrollX, scrollY)
  result.hLeft.draw = proc(this: DivRef, scrollX, scrollY: int) =
    scrollArrow_draw(this, adLeft, scrollX, scrollY)
  result.hRight.draw = proc(this: DivRef, scrollX, scrollY: int) =
    scrollArrow_draw(this, adRight, scrollX, scrollY)
  result.vTrack.draw = scrollTrack_draw
  result.hTrack.draw = scrollTrack_draw
  result.vSlider.draw = scrollSlider_draw
  result.hSlider.draw = scrollSlider_draw

  # arrows: hover / focus(clicked) pseudo-styles + click-to-scroll
  for a in [result.vUp, result.vDown, result.hLeft, result.hRight]:
    a.onHover = scrollPart_onHover
    a.onMouseButtonDown = scrollArrow_onMouseButtonDown
    a.onMouseButtonUp = scrollArrow_onMouseButtonUp
    a.onClick = scrollArrow_onClick

  # tracks: page-scroll on click
  result.vTrack.onClick = track_onClick
  result.hTrack.onClick = track_onClick

  # sliders: hover + drag, clamped to the track, Escape restores begin state
  for sl in [result.vSlider, result.hSlider]:
    sl.onHover = scrollPart_onHover
    sl.onDragStart = slider_onDragStart
    sl.onDragOver = slider_onDragOver
    sl.onDragEnd = slider_onDragEnd
    sl.onDragCancel = slider_onDragCancel
