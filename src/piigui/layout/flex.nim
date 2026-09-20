import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui/types

import tables, math

const debug = 1

#[ 
  ######     ###    ##        ######  
##    ##   ## ##   ##       ##    ## 
##        ##   ##  ##       ##       
##       ##     ## ##       ##       
##       ######### ##       ##       
##    ## ##     ## ##       ##    ## 
 ######  ##     ## ########  ######  

######## ##       ######## ##     ## 
##       ##       ##        ##   ##  
##       ##       ##         ## ##   
######   ##       ######      ###    
##       ##       ##         ## ##   
##       ##       ##        ##   ##  
##       ######## ######## ##     ##   
 ]#

#------------------------------------------------------------------------------
# Types describing one layout run.
#------------------------------------------------------------------------------

type
  LineDims = tuple[w, h, x, y: int]  # one assembled line/column: size + origin
  Article = object
    lines: seq[seq[DivRef]]          # every line/column, each holding its children
    lineDims: seq[LineDims]          # geometry of each line/column (same order)

  FlexLayout = object
    ## mutable state shared by every step of one layout pass.
    ## Hoisted out of `recalcFlex` (it used to be closure-captured variables)
    ## so the helper procedures can be plain `nimcall` procs: faster and,
    ## together with the forward declarations below, readable top-down.
    remainingWidth: int     # free width still left in the current line/column
    remainingHeight: int    # free height still left in the current line/column
    areaWidth: int          # full inner width of this pass (this.w - padding - scrollbar)
    areaHeight: int         # full inner height of this pass
    nextX: int              # where the next child's x1 goes
    nextY: int              # where the next child's y1 goes
    currentLine: seq[DivRef] # children of the line/column currently being assembled
    lineWidth: int          # accumulated width of the current line/column
    lineHeight: int         # accumulated height of the current line/column
    contentWidth: int       # total width of all lines (the final content size)
    contentHeight: int      # total height of all lines (the final content size)
    article: Article        # finished lines + geometry, for distributeContent

#------------------------------------------------------------------------------
# Forward declarations, so `recalcFlex` can be read top-down first.
#------------------------------------------------------------------------------

proc resetState(this: DivRef, state: var FlexLayout, areaWidth, areaHeight: int) #!FWD
proc postProcessRow(this: DivRef, state: var FlexLayout) #!FWD
proc postProcessColumn(this: DivRef, state: var FlexLayout) #!FWD
proc newRow(this: DivRef, state: var FlexLayout) #!FWD
proc newColumn(this: DivRef, state: var FlexLayout) #!FWD
proc distributeContent(this: DivRef, state: var FlexLayout) #!FWD
proc mainLayout(this: DivRef, layer: Layer, state: var FlexLayout) #!FWD
proc layoutPass(this: DivRef, layer: Layer, state: var FlexLayout,
                areaWidth, areaHeight: int): tuple[w, h: int] #!FWD

#------------------------------------------------------------------------------
# recalcFlex
#------------------------------------------------------------------------------

proc recalcFlex*(this: Divref, layer: Layer): tuple[w,h:int] =
  ## Flex layout for one layer of `this`.
  ##
  ## Flow (top-down):
  ##   1. if `this` is the root, sync its box to the window size
  ##   2. compute the inner area (this.w/h minus padding)
  ##   3. run the layout, once or twice:
  ##        * one pass for ofHidden, or when nothing overflows
  ##        * two passes for ofScroll, to reserve scrollbar space
  ##   4. each pass:
  ##        resetState -> mainLayout -> distributeContent
  ##      mainLayout walks the children, sizes them from their w_unit/h_unit,
  ##      and breaks into lines (fdRow) or columns (fdColumn):
  ##        newRow/newColumn close a line; postProcessRow/Column then apply
  ##        alignItems and flexGrow; distributeContent spreads the finished
  ##        lines with alignContent/justifyContent.
  ##   5. store the content size (innerW/innerH) and recurse into children
  when debug > 0:
    echo "\n this = ", this.name, " ########## BEGIN recalcFlex ##########"

  # nothing to lay out: stop early
  if layer.elems.len == 0:
    when debug > 1:
      echo "recalcFlex: no children, EXITING ", this.name, " ########## END recalcFlex ##########"
    return

  when debug > 1:
    echo "this.style.spacing ", this.style.spacing
    echo "this.style.flexDirection ", this.style.flexDirection
    echo "this.style.justifyContent ", this.style.justifyContent
    echo "this.style.alignItems ", this.style.alignItems
    echo "this.style.alignContent ", this.style.alignContent
    echo "this.x1, y1 ", this.x1, ", ", this.y1
    echo "this.x2, y2 ", this.x2, ", ", this.y2
    echo "this.w, h ", this.w, " x ", this.h

  # the root's box tracks the window size, so a resize updates the layout
  if this.parent == nil:
    var windowWidth, windowHeight: cint
    sdl.getSize(this.pgui.window, windowWidth, windowHeight)
    this.w = windowWidth
    this.h = windowHeight
    this.x1 = 0
    this.y1 = 0
    this.x2 = this.w - 1
    this.y2 = this.h - 1

    when debug > 1:
      echo "this.w ", this.w
      echo "this.h ", this.h

  result.w = this.w
  result.h = this.h
  # .w and .h are now initialised and ready to use

  # inner area available to the content (after padding, before scrollbar)
  var
    baseAreaWidth: int
    baseAreaHeight: int
  if this.style.padding > -1:
    baseAreaWidth = this.w - (this.style.padding * 2)
    baseAreaHeight = this.h - (this.style.padding * 2)
    if baseAreaWidth < 0: baseAreaWidth = 0   # boundary check
    if baseAreaHeight < 0: baseAreaHeight = 0 # boundary check
  else:
    baseAreaWidth = this.w
    baseAreaHeight = this.h

  # one state object, reused across both passes (resetState clears it)
  var state: FlexLayout

  if this.style.overflow == ofScroll:
    # two-pass layout: measure with the full area first; if the content
    # overflows, reserve scrollbar space and measure again so no content
    # hides behind the scrollbar
    var (contentW, contentH) = layoutPass(this, layer, state, baseAreaWidth, baseAreaHeight)
    var needsVerticalScrollbar = contentH > baseAreaHeight
    var needsHorizontalScrollbar = contentW > baseAreaWidth

    if needsVerticalScrollbar or needsHorizontalScrollbar:
      let availableWidth = baseAreaWidth - (if needsVerticalScrollbar: ScrollBarSize else: 0)
      let availableHeight = baseAreaHeight - (if needsHorizontalScrollbar: ScrollBarSize else: 0)
      (contentW, contentH) = layoutPass(this, layer, state, availableWidth, availableHeight)
      needsVerticalScrollbar = contentH > availableHeight   # re-check, rarely changes
      needsHorizontalScrollbar = contentW > availableWidth

    this.innerW = contentW
    this.innerH = contentH
    result.w = contentW
    result.h = contentH
  else:
    result = layoutPass(this, layer, state, baseAreaWidth, baseAreaHeight)

  this.isRecalculated = true
  when debug > 1: echo " ------ ENDFLEX ------ ", this.name, "\n"

  # recurse into children, so the whole tree gets its coordinates bottom-up
  for elem in layer.elems:
    elem.redrawFlag = 1
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)

#------------------------------------------------------------------------------
# resetState
#------------------------------------------------------------------------------

proc resetState(this: DivRef, state: var FlexLayout, areaWidth, areaHeight: int) =
  ## (re)initialise the per-pass layout state.
  ## `areaWidth`/`areaHeight` are the inner area available this pass
  ## (already reduced by padding and any reserved scrollbar space).
  when debug > 1: echo "resetState: BEGIN ", this.name
  state.remainingWidth = areaWidth
  state.remainingHeight = areaHeight
  state.areaWidth = areaWidth
  state.areaHeight = areaHeight
  state.nextY = this.y1
  state.nextX = this.x1
  if this.style.padding > -1:
    state.nextY += this.style.padding
    state.nextX += this.style.padding
  state.currentLine.setLen(0)
  state.lineWidth = 0
  state.lineHeight = 0
  state.contentWidth = 0
  state.contentHeight = 0
  state.article.lines = @[]
  state.article.lineDims = @[]
  when debug > 1: echo "resetState: area W x H: ", state.areaWidth, " x ", state.areaHeight
  when debug > 1: echo "resetState: remaining W x H: ", state.remainingWidth, " x ", state.remainingHeight
  when debug > 1: echo "resetState: END ", this.name

#------------------------------------------------------------------------------
# postProcessRow
#------------------------------------------------------------------------------

#[ 
  ########   #######   ######  ######## 
  ##     ## ##     ## ##    ##    ##    
  ##     ## ##     ## ##          ##    
  ########  ##     ##  ######     ##    
  ##        ##     ##       ##    ##    
  ##        ##     ## ##    ##    ##    
  ##         #######   ######     ##    

  ########   #######  ##      ##        
  ##     ## ##     ## ##  ##  ##        
  ##     ## ##     ## ##  ##  ##        
  ########  ##     ## ##  ##  ##        
  ##   ##   ##     ## ##  ##  ##        
  ##    ##  ##     ## ##  ##  ##        
  ##     ##  #######   ###  ###         
 ]#

proc postProcessRow(this: DivRef, state: var FlexLayout) =
  ## Finalise the current row once its children have been collected:
  ##   - record it in the article (so distributeContent can align it later)
  ##   - apply vertical alignItems
  ##   - grow flexible children horizontally (flexGrow), if there is room
  ##   - update the content totals
  when debug > 1: echo "postProcessRow: BEGIN ", this.name

  # the spacing was added after every child except the last; remove the
  # trailing spacing so the line width is the real content width
  if this.style.spacing > -1:
    state.lineWidth -= this.style.spacing

  state.contentHeight += state.lineHeight
  state.article.lines.add(state.currentLine)
  state.article.lineDims.add((w: state.lineWidth, h: state.lineHeight,
                              x: state.nextX, y: state.nextY))

  var
    flexGrowTotal: int         # sum of flexGrow over all growing children
    biggestGrowIndex: int = -1 # child with the largest flexGrow (gets the rounding remainder)

  when debug > 2:
    for elemIndex in 0..state.currentLine.high:
      echo "postProcessRow: >>>>>> ", $elemIndex, " <<<<<<< "

  for elemIndex in 0..state.currentLine.high:
    let elem = state.currentLine[elemIndex]

    # muAuto/muStretch rows stretch to the line height
    case elem.h_unit:
      of muAuto, muStretch:
        if state.lineHeight <= 1: # no explicit height yet: stretch to the full row
          let oldLineHeight = state.lineHeight
          state.lineHeight = if state.remainingHeight <= 0: state.areaHeight
                             else: state.remainingHeight
          elem.h = state.lineHeight
          elem.y2 += (state.lineHeight - 1)
          state.contentHeight += (state.lineHeight - oldLineHeight)
          state.article.lineDims[state.article.lineDims.high].h = state.lineHeight
        else:
          elem.h = state.lineHeight
          elem.y2 += (state.lineHeight - 1)
      else: discard

    # vertical alignment inside the line
    case this.style.alignItems:
      of faiUndefined, faiStart: discard
      of faiEnd:
        if elem.h < state.lineHeight:
          let delta = state.lineHeight - elem.h
          elem.y1 += delta
          elem.y2 += delta
      of faiCenter:
        if elem.h < state.lineHeight:
          let delta = (state.lineHeight - elem.h) div 2
          if delta > 0:
            elem.y1 += delta
            elem.y2 += delta
          when debug > 1:
            echo elemIndex, " postProcessRow: lineHeight ", state.lineHeight, ", ", elem.h, ", ", elem.name, ", ", delta, ", ", elem.y1
      of faiStretch:
        if elem.h < state.lineHeight:
          let delta = state.lineHeight - elem.h
          elem.y2 += delta
          elem.h += delta

    # collect flexGrow info for the grow pass below
    if elem.style.flexGrow > 0:
      flexGrowTotal += elem.style.flexGrow
      if biggestGrowIndex == -1: # first growing child: remember it for the remainder
        biggestGrowIndex = elemIndex
      elif elem.style.flexGrow > state.currentLine[biggestGrowIndex].style.flexGrow:
        biggestGrowIndex = elemIndex

  # grow flexible children to fill the row horizontally
  if state.lineWidth < state.areaWidth and flexGrowTotal > 0 and
    this.style.flexGrowFrom <= (state.lineWidth / state.areaWidth * 100).int:
    when debug > 1:
      echo "postProcessRow: flexGrowTotal ", flexGrowTotal, " areaWidth ", state.areaWidth, " lineWidth ", state.lineWidth

    let spacePerGrowUnit = if flexGrowTotal > state.areaWidth - state.lineWidth: 1
                           else: (state.areaWidth - state.lineWidth) div flexGrowTotal
    when debug > 1: echo "postProcessRow: spacePerGrowUnit ", spacePerGrowUnit

    # integer-division remainder, handed to the biggest-growing child
    let remainingSpace = if flexGrowTotal > state.areaWidth - state.lineWidth: 0
                         else: state.areaWidth - (flexGrowTotal * spacePerGrowUnit) - state.lineWidth
    when debug > 1: echo "postProcessRow: remainingSpace ", remainingSpace

    for elemIndex in 0..state.currentLine.high:
      if state.lineWidth == state.areaWidth: break # row already filled

      let elem = state.currentLine[elemIndex]
      if elem.style.flexGrow > 0:
        var delta = elem.style.flexGrow * spacePerGrowUnit
        if elemIndex == biggestGrowIndex: # integer-division remainder patch
          delta += remainingSpace
        if delta + state.lineWidth > state.areaWidth: # clamp to the available space
          delta = state.areaWidth - state.lineWidth

        elem.w += delta
        elem.x2 += delta
        state.lineWidth += delta

        when debug > 1:
          echo "postProcessRow: >>> ", elem.name, " ", elem.x1, " ", elem.x2

        # shift the children after this one by the same delta
        if elemIndex < state.currentLine.high:
          for followingIndex in elemIndex + 1 .. state.currentLine.high:
            state.currentLine[followingIndex].x1 += delta
            state.currentLine[followingIndex].x2 += delta

  # finalise the article entry with the (possibly grown) line width, so
  # distributeContent sees the real content size. contentHeight is kept up
  # to date by the muAuto/muStretch branch above.
  state.contentWidth += state.lineWidth
  state.article.lineDims[state.article.lineDims.high].w = state.lineWidth

  when debug > 1: echo "postProcessRow: END ", this.name

#------------------------------------------------------------------------------
# postProcessColumn
#------------------------------------------------------------------------------

#[ 
  ########   #######   ######  ######## 
  ##     ## ##     ## ##    ##    ##    
  ##     ## ##     ## ##          ##    
  ########  ##     ##  ######     ##    
  ##        ##     ##       ##    ##    
  ##        ##     ## ##    ##    ##    
  ##         #######   ######     ##    
 ]#

proc postProcessColumn(this: DivRef, state: var FlexLayout) =
  ## Finalise the current column once its children have been collected:
  ##   - apply horizontal alignItems
  ##   - grow flexible children vertically (flexGrow), if there is room
  ##   - record the column in the article and update the content totals
  when debug > 1: echo "postProcessColumn: BEGIN ", this.name

  # trailing spacing, as in postProcessRow
  if this.style.spacing > -1:
    state.lineHeight -= this.style.spacing

  var
    flexGrowTotal: int
    biggestGrowIndex: int = -1

  for elemIndex in 0..state.currentLine.high:
    let elem = state.currentLine[elemIndex]

    # horizontal alignment inside the column
    case this.style.alignItems:
      of faiUndefined, faiStart: discard
      of faiEnd:
        if elem.w < state.lineWidth:
          let delta = state.lineWidth - elem.w
          elem.x1 += delta
          elem.x2 += delta
      of faiCenter:
        if elem.w < state.lineWidth:
          let delta = (state.lineWidth - elem.w) div 2
          if delta > 0:
            elem.x1 += delta
            elem.x2 += delta
      of faiStretch:
        if elem.w < state.lineWidth:
          let delta = state.lineWidth - elem.w
          elem.x2 += delta
          elem.w += delta

    # collect flexGrow info for the grow pass below
    if elem.style.flexGrow > 0:
      flexGrowTotal += elem.style.flexGrow
      if biggestGrowIndex == -1: # first growing child: remember it for the remainder
        biggestGrowIndex = elemIndex
      elif elem.style.flexGrow > state.currentLine[biggestGrowIndex].style.flexGrow:
        biggestGrowIndex = elemIndex

  # grow flexible children to fill the column vertically
  if state.lineHeight < state.areaHeight and flexGrowTotal > 0 and
    this.style.flexGrowFrom <= (state.lineHeight / state.areaHeight * 100).int:
    when debug > 1:
      echo "postProcessColumn: flexGrowFrom ", (state.lineHeight / state.areaHeight * 100).int
      echo "postProcessColumn: flexGrowTotal ", flexGrowTotal, " areaHeight ", state.areaHeight, " lineHeight ", state.lineHeight

    let spacePerGrowUnit = if flexGrowTotal > state.areaHeight - state.lineHeight: 1
                           else: (state.areaHeight - state.lineHeight) div flexGrowTotal
    when debug > 1: echo "postProcessColumn: spacePerGrowUnit ", spacePerGrowUnit

    # integer-division remainder, handed to the biggest-growing child
    let remainingSpace = if flexGrowTotal > state.areaHeight - state.lineHeight: 0
                         else: state.areaHeight - (flexGrowTotal * spacePerGrowUnit) - state.lineHeight
    when debug > 1: echo "postProcessColumn: remainingSpace ", remainingSpace

    for elemIndex in 0..state.currentLine.high:
      if state.lineHeight == state.areaHeight: break # column already filled

      let elem = state.currentLine[elemIndex]
      if elem.style.flexGrow > 0:
        var delta = elem.style.flexGrow * spacePerGrowUnit
        if elemIndex == biggestGrowIndex: # integer-division remainder patch
          delta += remainingSpace
        if delta + state.lineHeight > state.areaHeight: # clamp to the available space
          delta = state.areaHeight - state.lineHeight

        elem.h += delta
        elem.y2 += delta
        state.lineHeight += delta

        when debug > 1:
          echo "postProcessColumn>>> ", elem.name, " y1 ", elem.y1, " y2 ", elem.y2
          echo "postProcessColumn>>>  x1 ", elem.x1, " x2 ", elem.x2

        # shift the children after this one down by the same delta
        if elemIndex < state.currentLine.high:
          for followingIndex in elemIndex + 1 .. state.currentLine.high:
            state.currentLine[followingIndex].y1 += delta
            state.currentLine[followingIndex].y2 += delta

  # finalise the article entry with the (possibly grown) line size, so
  # distributeContent sees the real content size (a stale contentHeight here
  # made distributeContent falsely vertical-center the content).
  state.contentWidth += state.lineWidth
  state.contentHeight += state.lineHeight # content height (needed for scrollables)
  state.article.lines.add(state.currentLine)
  state.article.lineDims.add((w: state.lineWidth, h: state.lineHeight,
                              x: state.nextX, y: state.nextY))

  when debug > 1: echo "postProcessColumn: END ", this.name

#------------------------------------------------------------------------------
# newRow / newColumn
#------------------------------------------------------------------------------

#[ 
8b  8 8888 Yb        dP 8    888 8b  8 8888 
8Ybm8 8www  Yb  db  dP  8     8  8Ybm8 8www 
8  "8 8      YbdPYbdP   8     8  8  "8 8    
8   8 8888    YP  YP    8888 888 8   8 8888 
 ]#

proc newRow(this: DivRef, state: var FlexLayout) =
  ## End the current row (if any) and start a new one below it.
  when debug > 1: echo "newRow: line.len ", state.currentLine.len
  if state.currentLine.len > 0:
    postProcessRow(this, state)

  state.remainingWidth = state.areaWidth     # a new row has the full width again
  state.remainingHeight -= state.lineHeight  # the new row sits one line lower

  state.nextY = state.nextY + state.lineHeight - 1
  if this.style.spacing > -1:
    state.nextY += this.style.spacing

  state.nextX = this.x1
  if this.style.padding > -1:
    state.nextX += this.style.padding

  state.lineWidth = 0
  state.lineHeight = 0
  state.currentLine.setLen(0)

proc newColumn(this: DivRef, state: var FlexLayout) =
  ## End the current column (if any) and start a new one to its right.
  when debug > 1: echo "newColumn: line.len ", state.currentLine.len
  if state.currentLine.len > 0:
    postProcessColumn(this, state)

  state.remainingHeight = state.areaHeight    # a new column has the full height again
  state.remainingWidth -= state.lineWidth     # the new column sits one column to the right

  state.nextY = this.y1
  if this.style.padding > -1:
    state.nextY += this.style.padding

  state.nextX = state.nextX + state.lineWidth - 1
  if this.style.spacing > -1:
    state.nextX += this.style.spacing

  state.lineHeight = 0
  state.lineWidth = 0
  state.currentLine.setLen(0)

#------------------------------------------------------------------------------
# distributeContent
#------------------------------------------------------------------------------

#[ 
  ########  ####  ######  ######## 
  ##     ##  ##  ##    ##    ##    
  ##     ##  ##  ##          ##    
  ##     ##  ##   ######     ##    
  ##     ##  ##        ##    ##    
  ##     ##  ##  ##    ##    ##    
  ########  ####  ######     ##    
 ]#

proc distributeContent(this: DivRef, state: var FlexLayout) =
  ## Distribute the finished lines/columns inside the container.
  ## This is flex-alignContent, but the author prefers "distribute".
  ##
  ## For fdRow:   alignContent spreads the rows vertically;
  ##              justifyContent spreads each row's content horizontally.
  ## For fdColumn: alignContent spreads the columns horizontally;
  ##              justifyContent spreads each column's content vertically.
  when debug > 1: echo "distributeContent: BEGIN ", this.name

  # nothing was laid out
  if state.article.lines.len == 0:
    when debug > 0: echo "distributeContent: article.lines.len == 0   RETURN"
    return

  var
    newY: int      # temporary cursor (row facEnd)
    delta: int     # how far to shift one line/element
    remainder: int # integer-division leftover, handed out one pixel at a time

  #--------------------------------------------------------------
  # fdRow: lines flow horizontally
  #--------------------------------------------------------------
  if this.style.flexDirection == fdRow:

    # if the content overflows, it will scroll: nothing to distribute
    if state.contentHeight > state.areaHeight:
      when debug > 0:
        echo "distributeContent: contentHeight > areaHeight ", state.contentHeight, " > ", state.areaHeight, " RETURN"
      return

    case this.style.alignContent: #* align rows vertically in the parent
      of facUndefined, facStart: discard

      of facEnd: #TODO: scroll ?!
        # pack the rows against the inner bottom edge (this.y2 - padding)
        let contentBottom = (if this.style.padding > -1: max(this.y1, this.y2 - this.style.padding)
                             else: this.y2)
        newY = contentBottom
        for lineIndex in countdown(state.article.lines.high, 0):
          newY -= (state.article.lineDims[lineIndex].h - 1)
          delta = newY - state.article.lineDims[lineIndex].y
          for elem in state.article.lines[lineIndex]:
            elem.y1 += delta
            elem.y2 += delta

      of facCenter:
        when debug > 1:
          echo "distributeContent: row alignContent facCenter"
          echo state.areaHeight, " - ", state.contentHeight, " div 2 = ", (state.areaHeight - state.contentHeight) div 2
        delta = (state.areaHeight - state.contentHeight) div 2
        if delta > 1:
          for lineIndex in countdown(state.article.lines.high, 0):
            for elem in state.article.lines[lineIndex]:
              elem.y1 += delta
              elem.y2 += delta

      of facStretch: #TODO TEST
        # each row grows by an equal share of the free height, so the rows
        # together fill the container
        delta = (state.areaHeight - state.contentHeight) div state.article.lines.len
        remainder = state.areaHeight - (delta * state.article.lines.len) # rounding patch

        var offset = 0 # cumulative vertical shift applied to later rows
        for lineIndex in 0..state.article.lines.high:
          let grow = delta + (if remainder > 0: 1 else: 0) # rounding patch
          if remainder > 0: remainder -= 1

          state.article.lineDims[lineIndex].h += grow
          state.article.lineDims[lineIndex].y += offset

          for elem in state.article.lines[lineIndex]:
            elem.y1 += offset          # shift down by previous rows' growth
            elem.h += grow             # stretch to the new row height
            elem.y2 += offset + grow   # both shift and stretch
          offset += grow

      of facSpaceBetween:
        if state.article.lines.len > 1:
          delta = (state.areaHeight - state.contentHeight) div (state.article.lines.len - 1) #! -1 (4 rows have 3 gaps)
          remainder = (state.areaHeight - state.contentHeight) - (delta * (state.article.lines.len - 1))

          for lineIndex in 1..state.article.lines.high: # starts at 1: no gap above the first row
            for elem in state.article.lines[lineIndex]:
              elem.y1 += delta * lineIndex
              elem.y2 += delta * lineIndex
              if remainder > 0:
                elem.y1 += lineIndex
                elem.y2 += lineIndex
            remainder -= 1

      of facSpaceAround:
        if state.article.lines.len > 1:
          delta = (state.areaHeight - state.contentHeight) div (state.article.lines.len + 1)
          remainder = state.areaHeight - (delta * (state.article.lines.len + 1))

          for lineIndex in 0..state.article.lines.high:
            for elem in state.article.lines[lineIndex]:
              elem.y1 += delta * (lineIndex + 1)
              elem.y2 += delta * (lineIndex + 1)
              if remainder > 0:
                elem.y1 += (lineIndex + 1)
                elem.y2 += (lineIndex + 1)
            remainder -= 1

    #[ 
    88888 88   88 .dP"Y8 888888 88 888888 Yb  dP 
        88 88   88 `Ybo."   88   88 88__    YbdP  
    o.  88 Y8   8P o.`Y8b   88   88 88""     8P   
    "bodP' `YbodP' 8bodP'   88   88 88      dP    

    88""Yb  dP"Yb  Yb        dP                   
    88__dP dP   Yb  Yb  db  dP                    
    88"Yb  Yb   dP   YbdPYbdP                     
    88  Yb  YbodP     YP  YP                      
    ]#

    # horizontal distribution of each row's content
    if state.contentWidth < state.areaWidth: # else the content scrolls
      case this.style.justifyContent: #* align rows horizontally in the parent
        of fjcUndefined, fjcStart: discard

        of fjcEnd:
          for lineIndex in 0..state.article.lines.high:
            delta = state.areaWidth - state.article.lineDims[lineIndex].w
            for elem in state.article.lines[lineIndex]:
              elem.x1 += delta
              elem.x2 += delta

        of fjcCenter:
          for lineIndex in 0..state.article.lines.high:
            delta = (state.areaWidth - state.article.lineDims[lineIndex].w) div 2
            if delta > 1:
              for elem in state.article.lines[lineIndex]:
                elem.x1 += delta
                elem.x2 += delta

  #--------------------------------------------------------------
  # fdColumn: lines flow vertically
  #--------------------------------------------------------------
  if this.style.flexDirection == fdColumn:
    when debug > 1: echo "distributeContent: fdColumn"

    # horizontal distribution of the columns (if the content does not scroll)
    if state.contentWidth < state.areaWidth:
      case this.style.alignContent: #* align columns horizontally in the parent
        of facUndefined, facStart: discard

        of facCenter:
          when debug > 1: echo ">>> distributeContent: fdColumn facCenter <<<"
          delta = (state.areaWidth - state.contentWidth) div 2
          remainder = (state.areaWidth - state.contentWidth) - (delta * 2)
          for lineIndex in 0..state.article.lines.high:
            for elem in state.article.lines[lineIndex]:
              elem.x1 += delta
              elem.x2 += delta
              if remainder > 0:
                elem.x1 += 1
                elem.x2 += 1
            remainder -= 1

        of facSpaceBetween:
          if state.article.lines.len > 1:
            delta = (state.areaWidth - state.contentWidth) div (state.article.lines.len - 1)
            remainder = (state.areaWidth - state.contentWidth) - (delta * (state.article.lines.len - 1))
            var offset = 0
            for lineIndex in 0..state.article.lines.high:
              if lineIndex > 0:
                offset += delta
                if remainder > 0:
                  offset += 1
                  remainder -= 1
              for elem in state.article.lines[lineIndex]:
                elem.x1 += offset
                elem.x2 += offset
          else: # single column: center it (same as facCenter)
            delta = (state.areaWidth - state.contentWidth) div 2
            remainder = (state.areaWidth - state.contentWidth) - (delta * 2)
            for elem in state.article.lines[0]:
              elem.x1 += delta
              elem.x2 += delta
              if remainder > 0:
                elem.x1 += 1
                elem.x2 += 1

        of facSpaceAround:
          if state.article.lines.len > 1:
            delta = (state.areaWidth - state.contentWidth) div (state.article.lines.len + 1)
            remainder = (state.areaWidth - state.contentWidth) - (delta * (state.article.lines.len + 1))
          elif state.article.lines.len == 1: # single line: treat like facCenter
            delta = (state.areaWidth - state.contentWidth) div 2
            remainder = (state.areaWidth - state.contentWidth) - (delta * 2)
          var gapIndex = 0
          for lineIndex in 0..state.article.lines.high:
            gapIndex += 1
            for elem in state.article.lines[lineIndex]:
              elem.x1 += delta * gapIndex
              elem.x2 += delta * gapIndex
              if remainder > 0:
                elem.x1 += 1
                elem.x2 += 1
            remainder -= 1

        of facStretch:
          delta = (state.areaWidth - state.contentWidth) div state.article.lines.len
          remainder = (state.areaWidth - state.contentWidth) - (delta * state.article.lines.len)
          for lineIndex in 0..state.article.lines.high:
            state.article.lineDims[lineIndex].w += delta
            if remainder > 0: state.article.lineDims[lineIndex].w += 1
            for elem in state.article.lines[lineIndex]:
              elem.x1 += lineIndex * delta
              elem.x2 += lineIndex * delta + delta
              elem.w += delta
              if remainder > 0:
                elem.x2 += 1
                elem.w += 1
            remainder -= 1

        of facEnd:
          delta = (state.areaWidth - state.contentWidth)
          for lineIndex in 0..state.article.lines.high:
            for elem in state.article.lines[lineIndex]:
              elem.x1 += delta
              elem.x2 += delta

    #[ 
     88888 88   88 .dP"Y8 888888 88 888888 Yb  dP  
        88 88   88 `Ybo."   88   88 88__    YbdP   
    o.  88 Y8   8P o.`Y8b   88   88 88""     8P    
    "bodP' `YbodP' 8bodP'   88   88 88      dP     

     dP""b8  dP"Yb  88     88   88 8b    d8 88b 88 
    dP   `" dP   Yb 88     88   88 88b  d88 88Yb88 
    Yb      Yb   dP 88  .o Y8   8P 88YbdP88 88 Y88 
     YboodP  YbodP  88ood8 `YbodP' 88 YY 88 88  Y8 
    ]#

    # vertical distribution of each column's content (if it does not scroll)
    if state.contentHeight < state.areaHeight:
      case this.style.justifyContent: #* align columns vertically in the parent
        of fjcUndefined, fjcStart: discard

        of fjcEnd:
          for lineIndex in 0..state.article.lines.high:
            delta = state.areaHeight - state.article.lineDims[lineIndex].h
            for elem in state.article.lines[lineIndex]:
              elem.y1 += delta
              elem.y2 += delta

        of fjcCenter:
          when debug > 1: echo ">>> distributeContent: fdColumn fjcCenter <<<"
          for lineIndex in 0..state.article.lines.high:
            delta = (state.areaHeight - state.article.lineDims[lineIndex].h) div 2
            for elem in state.article.lines[lineIndex]:
              elem.y1 += delta
              elem.y2 += delta

  when debug > 1: echo "distributeContent: END ", this.name

#------------------------------------------------------------------------------
# mainLayout
#------------------------------------------------------------------------------

#[ 
     ######  ########    ###    ########  ######## 
    ##    ##    ##      ## ##   ##     ##    ##    
    ##          ##     ##   ##  ##     ##    ##    
     ######     ##    ##     ## ########     ##    
          ##    ##    ######### ##   ##      ##    
    ##    ##    ##    ##     ## ##    ##     ##    
     ######     ##    ##     ## ##     ##    ##    
 ]#

proc mainLayout(this: DivRef, layer: Layer, state: var FlexLayout) =
  ## The core layout loop. Iterate the layer's children, size each one from
  ## its w_unit/h_unit, place it, and break into new lines (fdRow) or
  ## columns (fdColumn) as needed. Flex-grow and line distribution happen
  ## in postProcessRow/Column and distributeContent, after the loop.
  when debug > 1: echo "mainLayout: BEGIN ", this.name

  if this.style.flexDirection == fdRow: #! ---- fdRow: children flow left -> right
    when debug > 1: echo "##### mainLayout: flexDirection == fdRow"

    for elem in layer.elems:

      if elem of BRElem: # explicit line break
        newRow(this, state)
        continue

      # ---- measure the child's height ----
      case elem.h_unit:
        of muAuto, muStretch:
          elem.h = 1 # grow to the line height later in postProcessRow
        of muPx:
          elem.h = elem.h_value
          if elem.window.scale != 1.0: elem.h = (elem.h.float * elem.window.scale).int
        of muPc:
          elem.h = (state.areaHeight.float / (100.float / elem.h_value.float)).floor.int - 1

      # ---- measure the child's width and place it ----
      case elem.w_unit:
        of muAuto, muStretch:
          # take the remaining width. Not the same as justify-stretch:
          # useful for the last element in a row; for several elements,
          # use flexGrow instead.
          elem.w = state.remainingWidth
          state.currentLine.add(elem)
          # coordinates
          elem.x1 = state.nextX
          elem.x2 = state.nextX + elem.w - 1
          elem.y1 = state.nextY
          elem.y2 = state.nextY + elem.h - 1
          state.lineWidth += elem.w
          newRow(this, state)

        of muPx:
          elem.w = elem.w_value
          if elem.window.scale != 1.0: elem.w = (elem.w.float * elem.window.scale).int

          if state.remainingWidth - elem.w < 0: # does not fit: wrap to a new row (unless scrolling)
            if not (this.style.overflow == ofScroll): newRow(this, state)

          state.lineWidth += elem.w
          state.remainingWidth -= elem.w
          state.currentLine.add(elem)
          # coordinates
          elem.x1 = state.nextX
          elem.x2 = state.nextX + elem.w - 1
          elem.y1 = state.nextY
          elem.y2 = state.nextY + elem.h - 1
          state.nextX = state.nextX + elem.w
          if this.style.spacing > -1:
            state.nextX += this.style.spacing
            state.lineWidth += this.style.spacing
            state.remainingWidth -= this.style.spacing

        of muPc:
          elem.w = (state.areaWidth.float / (100.float / elem.w_value.float)).floor.int - 1

          if state.remainingWidth - elem.w <= 0: # does not fit: wrap to a new row (unless scrolling)
            if not (this.style.overflow == ofScroll): newRow(this, state)

          state.lineWidth += elem.w
          state.remainingWidth -= elem.w
          state.currentLine.add(elem)
          # coordinates
          elem.x1 = state.nextX
          elem.x2 = state.nextX + elem.w - 1
          elem.y1 = state.nextY
          elem.y2 = state.nextY + elem.h - 1
          state.nextX = state.nextX + elem.w
          if this.style.spacing > -1:
            state.nextX += this.style.spacing
            state.lineWidth += this.style.spacing
            state.remainingWidth -= this.style.spacing

          when debug > 1: echo "row muPc ", elem.w_value, "->", elem.w, " remainingWidth: ", state.remainingWidth

      # keep the line height equal to the tallest child
      if state.lineHeight < elem.h: state.lineHeight = elem.h

      when debug > 1:
        echo elem.name, " flex w/h: ", elem.w, " / ", elem.h
        echo elem.name, " flex x1,y1: ", elem.x1, ", ", elem.y1
        echo elem.name, " flex x2,y2: ", elem.x2, ", ", elem.y2
        echo elem.name, ", padding: ", this.style.padding
        echo ""

    if state.currentLine.len > 0: postProcessRow(this, state) # finalise the last row

    if state.contentHeight < state.areaHeight or state.contentWidth < state.areaWidth:
      distributeContent(this, state)

    #TODO SCROLL

  #!................................ fdColumn (and fdUndefined, ~ fdColumn)
  elif this.style.flexDirection == fdColumn or
       this.style.flexDirection == fdUndefined:
    ## calculate children positions vertically
    when debug > 1: echo "mainLayout: flexDirection == fdColumn ", this.name

    for elem in layer.elems:

      if elem of BRElem: # explicit column break
        newColumn(this, state)
        continue

      # ---- measure the child's width ----
      case elem.w_unit:
        of muAuto, muStretch:
          elem.w = state.remainingWidth
        of muPx:
          elem.w = elem.w_value
          if elem.window.scale != 1.0: elem.w = (elem.w.float * elem.window.scale).int
        of muPc:
          elem.w = (state.areaWidth.float / (100.float / elem.w_value.float)).floor.int - 1

      # keep the column width equal to the widest child
      if state.lineWidth < elem.w: state.lineWidth = elem.w

      # ---- measure the child's height and place it ----
      case elem.h_unit:
        of muAuto, muStretch:
          when debug > 1: echo "muStretch"
          elem.h = state.remainingHeight
          state.currentLine.add(elem)
          state.remainingHeight -= elem.h
          state.lineHeight += elem.h
          # coordinates
          elem.x1 = state.nextX
          elem.x2 = state.nextX + elem.w - 1
          elem.y1 = state.nextY
          elem.y2 = state.nextY + elem.h - 1
          state.nextY = state.nextY + elem.h
          newColumn(this, state)

        of muPx:
          elem.h = elem.h_value
          if elem.window.scale != 1.0: elem.h = (elem.h.float * elem.window.scale).int

          if state.remainingHeight - elem.h < 0: # does not fit: wrap to a new column (unless scrolling)
            when debug > 1: echo "remainingHeight - elem.h < 0: ", state.remainingHeight, " - ", elem.h, " !"
            if not (this.style.overflow == ofScroll): newColumn(this, state)

          state.remainingHeight -= elem.h
          state.currentLine.add(elem)
          state.lineHeight += elem.h
          # coordinates
          elem.x1 = state.nextX
          elem.x2 = state.nextX + elem.w - 1
          elem.y1 = state.nextY
          elem.y2 = state.nextY + elem.h - 1
          state.nextY = state.nextY + elem.h
          if this.style.spacing > -1:
            state.nextY += this.style.spacing
            state.lineHeight += this.style.spacing
            state.remainingHeight -= this.style.spacing

        of muPc:
          elem.h = (state.areaHeight.float / (100.float / elem.h_value.float)).floor.int - 1

          if state.remainingHeight - elem.h <= 0: # does not fit: wrap to a new column (unless scrolling)
            when debug > 1: echo "remainingHeight - elem.h < 0: ", state.remainingHeight, " - ", elem.h, " !"
            if not (this.style.overflow == ofScroll): newColumn(this, state)

          state.remainingHeight -= elem.h
          state.currentLine.add(elem)
          state.lineHeight += elem.h
          # coordinates
          elem.x1 = state.nextX
          elem.x2 = state.nextX + elem.w - 1
          elem.y1 = state.nextY
          elem.y2 = state.nextY + elem.h - 1
          state.nextY = state.nextY + elem.h
          if this.style.spacing > -1:
            state.nextY += this.style.spacing
            state.lineHeight += this.style.spacing
            state.remainingHeight -= this.style.spacing

      # keep the column width equal to the widest child
      if state.lineWidth < elem.w: state.lineWidth = elem.w

      when debug > 1:
        echo elem.name, " w/h: ", elem.w, " / ", elem.h
        echo elem.name, " x1/x2: ", elem.x1, " / ", elem.x2
        echo elem.name, " y1,y2: ", elem.y1, " / ", elem.y2
        echo elem.name, ", padding: ", this.style.padding
        echo ""

    when debug > 1: echo "   Column line.len = ", state.currentLine.len
    if state.currentLine.len > 0: postProcessColumn(this, state) # finalise the last column

    if state.contentWidth < state.areaWidth: distributeContent(this, state)

    #TODO SCROLL

  when debug > 1: echo "mainLayout: END ", this.name

#------------------------------------------------------------------------------
# layoutPass
#------------------------------------------------------------------------------

proc layoutPass(this: DivRef, layer: Layer, state: var FlexLayout,
                areaWidth, areaHeight: int): tuple[w, h: int] =
  ## Run one full layout pass with the given inner area, returning the
  ## content size (which may exceed the area when the content scrolls).
  resetState(this, state, areaWidth, areaHeight)
  mainLayout(this, layer, state)
  result.w = state.contentWidth
  result.h = state.contentHeight
