import
  sdl2_nim/sdl,
  sdl2_nim/sdl_gfx_primitives_font as font

import piigui/types

import tables

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

proc recalcFlex*(this: Divref, layer: Layer): tuple[w,h:int] =
  ## flow:
  ##  *if ~[this.activeStyle].flexDirection == fdRow:
  ##     for elem in DivRef:
  ##       calc elem.h, elem.w, lineH, lineW
  ##      *postProcessRow():
  ##         article.lines.add(line)
  ##         article.lineDims.add((w: lineW, h: lineH, x: nextX, y:nextY))
  ##        *FOR ELEM:
  ##          CASE this.styleCache[this.activeStyle].alignItems
  ##          GET flexGrowDivider
  ##          GET elementWithBiggestGrow
  ##          APPLY FLEX-GROW
  ##
  ##        *flexGrowFrom ?
  ##        *ELSE JUSTIFY CONTENT
  ## 
  ## 
  ##  *elif ~[this.activeStyle].flexDirection == fdColumn:
  ##     for elem in DivRef:
  ##       calc elem.h, elem.w, lineH, lineW
  ##      *postProcessColumn():
  ##         article.lines.add(line)
  ##         article.lineDims.add((w: lineW, h: lineH, x: nextX, y:nextY))
  ##        *FOR ELEM:
  ##          CASE this.styleCache[this.activeStyle].alignItems
  ##          GET flexGrowDivider
  ##          GET elementWithBiggestGrow
  ##          APPLY FLEX-GROW
  ## 
  ## 
  ##  *distributeContent()
  ##    *~[this.activeStyle].flexDirection == fdRow:
  ##       SCROLL ?
  ##      *CASE [this.activeStyle].alignContent:
  #TODO ERROR 
  ##    *~[this.activeStyle].flexDirection == fdColumn:
  ##       [this.activeStyle].justifyContent:
  ##    
  #TODO    case this.styleCache[this.activeStyle].alignContent
  const debug = 2
  
  when debug > 0: echo "\n", this.name, " recalcFlex <<<<<<<<<<<<<<<<<<<<"

  if this.layers[0].elems.len == 0:
    when debug > 0: echo "NO CHILDS? EXITING", this.name, " recalcFlex <<<<<<<<<<<<<<<<<<<<"
    return

  when debug > 1:
    echo "this.style.spacing ", this.style.spacing
    echo "this.style.flexDirection ", this.style.flexDirection
    echo "this.style.justifyContent ", this.style.justifyContent
    echo "this.style.alignItems ", this.style.alignItems
    echo "this.style.alignContent ", this.style.alignContent
    echo "this.x1 ", this.x1, "   this.y1 ", this.y1

  # for root, get window size - useful if window resized
  if this.parent == nil:
    var ww, wh: cint
    sdl.getSize(this.pgui.window, addr(ww), addr(wh))
    this.w = ww
    this.h = wh

  when debug > 1:
    echo "this.w ", this.w
    echo "this.h ", this.h

  # innerW innerH for scroll
  result.w = this.w
  result.h = this.h

  # article holds lines of elems,
  # needed for line distribution at end
  type Article = object
    lines: seq[seq[DivRef]]
    lineDims: seq[tuple[w,h, x,y:int]]

  var  #padding#
    availW: int
    availH: int
    thisY2: int
    thisX2: int
    #newY = this.y1
    #newX = this.x1
    nextY = this.y1 + this.style.padding # used at line calculation #padding#
    nextX = this.x1 + this.style.padding

    line: seq[DivRef] # the current line
    lineH: int
    lineW: int

    totalW: int # used at aligning the whole area
    totalH: int # and by result

    article: Article

  if this.style.padding > -1:
    availW = this.w - (this.style.padding * 2) # used at line calculation
    availH = this.h - (this.style.padding * 2)
    thisX2 = this.x2 - this.style.padding
    thisY2 = this.y2 - this.style.padding

    if this.x1 > thisX2: thisX2 = this.x1 #patch
    if this.y1 > thisY2: thisY2 = this.y1

    if availW < 0: availW = 0 #patch
    if availH < 0: availH = 0

  else:
    availW = this.w # used at line calculation
    availH = this.h
    thisX2 = this.x2
    thisY2 = this.y2


  #[ if (availH <= 0 or availW <= 0) and this.parent == nil:
    var ww, wh: cint
    sdl.getSize(this.pgui.window, addr(ww), addr(wh))
    if this.style.padding > -1:
      availW = ww - (this.style.padding * 2) # used at line calculation
      availH = wh - (this.style.padding * 2)
      if availW < 0: availW = 0 #patch
      if availH < 0: availH = 0
    else:
      availW = ww # used at line calculation
      availH = wh
    this.w = ww
    this.h = wh ]#

  let
    origiW = availW
    origiH = availH
  when debug > 0: echo "origi W x H: ", origiW, " x ", origiH

  #*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #[ 
      ########  ####  ######  ######## 
      ##     ##  ##  ##    ##    ##    
      ##     ##  ##  ##          ##    
      ##     ##  ##   ######     ##    
      ##     ##  ##        ##    ##    
      ##     ##  ##  ##    ##    ##    
      ########  ####  ######     ##    
  ]#
  proc distributeContent()=#! distributeContent distributeContent
    ## it is flex-alignContent,
    ## but i like the word distribute more!

    # if useless
    if this.styleCache[this.activeStyle].alignContent == facStart: return
    #...................

    var
      nY:int # new Y
      delta:int # distance
      remainder:int

    if this.styleCache[this.activeStyle].flexDirection == fdRow:
      
      # if useless
      if totalH > origiH: # else scroll :)
        when debug > 0: echo "#### distributeContent totalH > origiH ####"
        return 

      case this.styleCache[this.activeStyle].alignContent:
        of facUndefined, facStart: discard

        of facEnd:
          nY = thisY2#this.y2
          for i_line in countdown(article.lines.high,0):
            nY -= (article.lineDims[i_line].h - 1)
            delta = nY - (article.lineDims[i_line].y)
            for elem in article.lines[i_line]:
              elem.y1 += delta
              elem.y2 += delta
        
        of facCenter:
          when debug > 0: echo "#### distributeContent facCenter ####"
          nY = thisY2#this.y2
          for i_line in countdown(article.lines.high,0): #TODO refractor
            nY -= (article.lineDims[i_line].h - 1)
            delta = (nY - (article.lineDims[i_line].y)) div 2
            for elem in article.lines[i_line]:
              elem.y1 += delta
              elem.y2 += delta

        of facStretch: #TODO ERROR
          #if article.lines.len == 0: return
          delta = (origiH - totalH) div article.lines.len
          remainder = origiH - (delta * article.lines.len)

          for elem in article.lines[0]:
            elem.y2 += delta
            elem.h += delta
            if remainder > 0:
              elem.y2 += 1
              elem.h += 1
          article.lineDims[0].y += delta
          article.lineDims[0].h += delta

          if remainder > 0: remainder -= 1
          
          if article.lines.len > 1:
            for i_line in 1..article.lines.high:
              for i_elem in 0..article.lines[i_line].high:
                article.lines[i_line][i_elem].y1 = article.lineDims[i_line - 1].y +
                              article.lineDims[i_line - 1].h + 1
                article.lineDims[i_line].h += delta
                article.lines[i_line][i_elem].y2 = article.lines[i_line][i_elem].y1 +
                                  (article.lines[i_line][i_elem].h - 1) +
                                  delta
                article.lines[i_line][i_elem].h += delta
                if remainder > 0:
                  article.lines[i_line][i_elem].y2 += 1
                  article.lines[i_line][i_elem].h += 1
                remainder -= 1

        of facSpaceBetween:
          if article.lines.len > 1:
            delta = (origiH - totalH) div (article.lines.len - 1)
            remainder = origiH - (delta * (article.lines.len - 1))

            for i_line in 1..article.lines.high:
              for i_elem in 0..article.lines[i_line].high:
                article.lines[i_line][i_elem].y1 += delta * i_line
                article.lines[i_line][i_elem].y2 += delta * i_line
                if remainder > 0:
                  article.lines[i_line][i_elem].y1 += 1 * i_line
                  article.lines[i_line][i_elem].y2 += 1 * i_line
                  remainder -= 1
   

        of facSpaceAround:
          if article.lines.len > 1:
            delta = (origiH - totalH) div (article.lines.len + 1)
            remainder = origiH - (delta * (article.lines.len + 1))

            for i_line in 0..article.lines.high:
              for i_elem in 0..article.lines[i_line].high:
                article.lines[i_line][i_elem].y1 += delta * (i_line + 1)
                article.lines[i_line][i_elem].y2 += delta * (i_line + 1)
                if remainder > 0:
                  article.lines[i_line][i_elem].y1 += 1 * (i_line + 1)
                  article.lines[i_line][i_elem].y2 += 1 * (i_line + 1)
                  remainder -= 1


    #!............flexDirection == fdColumn:................
    if this.styleCache[this.activeStyle].flexDirection == fdColumn:#!............
      if totalW < origiW: # else scroll :)
        case this.styleCache[this.activeStyle].justifyContent:
          of fjcUndefined, fjcStart: discard
          of fjcEnd:
            delta = origiW - totalW
            for i_line in 0..article.lines.high:
              for i_elem in 0..article.lines[i_line].high:
                article.lines[i_line][i_elem].x1 += delta
                article.lines[i_line][i_elem].x2 += delta
          of fjcCenter:
            delta = ((origiW - (this.style.padding * 2)) - totalW) div 2
            for i_line in 0..article.lines.high:
              for i_elem in 0..article.lines[i_line].high:
                article.lines[i_line][i_elem].x1 += delta
                article.lines[i_line][i_elem].x2 += delta
      #else:
      #  return
      # TODO CONTINUE
      case this.styleCache[this.activeStyle].alignContent:
        of facCenter, facSpaceAround:
          when debug > 0: echo "#### distributeContent facCenter ####"
          
          for i_line in countdown(article.lines.high,0):
            #nY = thisY2#this.y2
            delta = (thisY2 - (article.lineDims[i_line].y)) div 2
            for elem in article.lines[i_line]:
              elem.y1 += delta
              elem.y2 += delta
        of facUndefined: discard
        of facStretch: discard
        of facStart: discard
        of facEnd: discard
        of facSpaceBetween: discard
        #else: discard
  #*______________________________________________________

  #[ 
      ########   #######   ######  ######## 
      ##     ## ##     ## ##    ##    ##    
      ##     ## ##     ## ##          ##    
      ########  ##     ##  ######     ##    
      ##        ##     ##       ##    ##    
      ##        ##     ## ##    ##    ##    
      ##         #######   ######     ##    

      ######   #######  ##       
      ##    ## ##     ## ##       
      ##       ##     ## ##       
      ##       ##     ## ##       
      ##       ##     ## ##       
      ##    ## ##     ## ##       
      ######   #######  ######## 
  ]#

  #! PostProcess ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  proc postProcessColumn()= #! postProcessColumn postProcessColumn
    if this.style.spacing > -1: #spacing#
      lineH -= this.style.spacing
    # add line to Article for content distribution
    totalW += lineW
    article.lines.add(line)
    article.lineDims.add((w: lineW, h: lineH, x: nextX, y:nextY))
    #~~~~~~~~~~~~~~~~~~~~~~
    var
      flexGrowDivider:int
      elementWithBiggestGrow: int = -1


    # muStretch w, h
    # align items in column horizontally:
    for i_elem in 0..line.high: # unorthodox method:
      case this.styleCache[this.activeStyle].alignItems:
        of faiUndefined, faiStart: discard
        of faiEnd:
            if line[i_elem].w < lineW:
              let delta = lineW - line[i_elem].w
              line[i_elem].x1 += delta
              line[i_elem].x2 += delta
        of faiCenter:
            if line[i_elem].w < lineW:
              let delta = (lineW - line[i_elem].w) div 2
              if delta > 0:
                line[i_elem].x1 += delta
                line[i_elem].x2 += delta
        of faiStretch:
            if line[i_elem].w < lineW:
              let delta = lineW - line[i_elem].w
              line[i_elem].x2 += delta
              line[i_elem].h += delta
      
      # for correcting int division
      #   store the elementWithBiggestGrow
      #   later add the 'error' to its dimension
      if line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow > 0:
        flexGrowDivider += line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow
        if elementWithBiggestGrow == -1: # save for adding remaining space to
          elementWithBiggestGrow = i_elem
        elif line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow > line[elementWithBiggestGrow].styleCache[line[elementWithBiggestGrow].activeStyle].flexGrow:
          elementWithBiggestGrow = i_elem
    #........................................
    if this.styleCache[this.activeStyle].flexGrowFrom <= (lineH / origiH * 100).int and
      flexGrowDivider > 0 and lineH < origiH:

      when debug > 0: 
        echo "flexGrowFrom ", (lineH / origiH * 100).int
        echo "flexGrowDivider ", flexGrowDivider, " origiH ", origiH, " lineH ", lineH

      let deltaSpace = if flexGrowDivider > origiH - lineH: 1 else: (origiH - lineH) div flexGrowDivider
      when debug > 0: echo "deltaSpace ", deltaSpace

      # int division error patch
      let remainingSpace =  if flexGrowDivider > origiH - lineH: 0 else: origiH - (flexGrowDivider * deltaSpace) - lineH
      when debug > 0: echo "remainingSpace ", remainingSpace
      
      for i_elem in 0..line.high:
        
        if lineH == origiH: break #!!!

        if line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow > 0:
          var delta = line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow * deltaSpace
          if i_elem == elementWithBiggestGrow: # int division error patch
            delta += remainingSpace
          if delta + lineH > origiH: delta = origiH - lineH #? patch

          line[i_elem].h += delta
          line[i_elem].y2 += delta
          lineH += delta

          when debug > 0: echo ">>> ",line[i_elem].name, " ", line[i_elem].y1, " ",line[i_elem].y2

          # adjust the rest
          if i_elem < line.high:
            for ii_elem in i_elem + 1 .. line.high:
              line[ii_elem].y1 += delta
              line[ii_elem].y2 += delta

    #[ elif lineH < origiH:# if not grown full width

      echo "alignContent"
      case this.styleCache[this.activeStyle].alignContent:
        of facStart: discard
        of facEnd:
          if line[line.high].y2 < this.y2:
            let delta = this.y2 - line[line.high].y2
            for elem in line:
              elem.y2 += delta
              elem.y1 += delta
        of facCenter:
          echo "facCenter"
          if line[line.high].y2 < this.y2:
            let delta = (this.y2 - line[line.high].y2) div 2
            if delta > 0:
              for elem in line:
                elem.y2 += delta
                elem.y1 += delta ]#


    # todo 

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
  proc postProcessRow()= #! postProcessRow  postProcessRow  postProcessRow
    # add line to Article for content distribution
    if this.style.spacing > -1: #spacing#
      lineW -= this.style.spacing
    totalH += lineH
    article.lines.add(line)
    article.lineDims.add((w: lineW, h: lineH, x: nextX, y:nextY))
    #~~~~~~~~~~~~~~~~~~~~~~
    var
      flexGrowDivider:int
      elementWithBiggestGrow: int = -1

    when debug > 2:
      for i_elem in 0..line.high:
        echo " >>>>>> ", $i_elem, " <<<<<<< "
        
    for i_elem in 0..line.high:
      case this.styleCache[this.activeStyle].alignItems:
        of faiUndefined,faiStart: discard
        of faiEnd:
            if line[i_elem].h < lineH:
              let delta = lineH - line[i_elem].h
              line[i_elem].y1 += delta
              line[i_elem].y2 += delta
        of faiCenter:
            if line[i_elem].h < lineH:
              let delta = (lineH - line[i_elem].h) div 2
              if delta > 0:
                line[i_elem].y1 += delta
                line[i_elem].y2 += delta
              when debug > 1: echo i_elem, " ###### lineH ", lineH, ", ", line[i_elem].h, ", ", line[i_elem].name, ", ", delta, ", ", line[i_elem].y1
        of faiStretch:
            if line[i_elem].h < lineH:
              let delta = lineH - line[i_elem].h
              line[i_elem].y2 += delta

      # for correcting int division
      # store the elementWithBiggestGrow
      # later add the error to its dimension
      if line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow > 0:
        flexGrowDivider += line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow
        if elementWithBiggestGrow == -1: # save for adding remaining space to
          elementWithBiggestGrow = i_elem
        elif line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow > 
          line[elementWithBiggestGrow].styleCache[line[elementWithBiggestGrow].activeStyle].flexGrow:
          elementWithBiggestGrow = i_elem


    if this.styleCache[this.activeStyle].flexGrowFrom <= (lineW / origiW * 100).int and flexGrowDivider > 0 and lineW < origiW:
      when debug > 1:echo "flexGrowDivider ", flexGrowDivider, " origiW ", origiW, " lineW ", lineW

      let deltaSpace = if flexGrowDivider > origiW - lineW: 1 else: (origiW - lineW) div flexGrowDivider
      when debug > 1:echo "deltaSpace ", deltaSpace

      # int division error patch
      let remainingSpace =  if flexGrowDivider > origiW - lineW: 0 else: origiW - (flexGrowDivider * deltaSpace) - lineW
      when debug > 1:echo "remainingSpace ", remainingSpace
      
      for i_elem in 0..line.high:
        
        if lineW == origiW: break #!!!

        if line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow > 0:
          var delta = line[i_elem].styleCache[line[i_elem].activeStyle].flexGrow * deltaSpace
          if i_elem == elementWithBiggestGrow: # int division error patch
            delta += remainingSpace
          if delta + lineW > origiW: delta = origiW - lineW #? patch

          line[i_elem].w += delta
          line[i_elem].x2 += delta
          lineW += delta

          when debug > 1: echo ">>> ",line[i_elem].name, " ", line[i_elem].x1, " ",line[i_elem].x2

          # adjust the rest
          if i_elem < line.high:
            for ii_elem in i_elem + 1 .. line.high:
              line[ii_elem].x1 += delta
              line[ii_elem].x2 += delta

    elif lineW < origiW:# if not grown full width
      when debug > -1: echo "justifyContent ", this.styleCache[this.activeStyle].justifyContent
      case this.styleCache[this.activeStyle].justifyContent:
        of fjcUndefined,fjcStart: discard
        of fjcEnd:
          if line[line.high].x2 < thisX2:
            let delta = thisX2 - line[line.high].x2
            for elem in line:
              elem.x2 += delta
              elem.x1 += delta
        of fjcCenter:
          if line[line.high].x2 < thisX2:
            let delta = (thisX2 - line[line.high].x2) div 2
            if delta > 0:
              for elem in line:
                elem.x2 += delta
                elem.x1 += delta

    # todo justifyContent
    # todo postProxessRows() for distributing rows alignContent
  #end postProcessRow......................




  #[

  8b  8 8888 Yb        dP 8    888 8b  8 8888 
  8Ybm8 8www  Yb  db  dP  8     8  8Ybm8 8www 
  8  "8 8      YbdPYbdP   8     8  8  "8 8    
  8   8 8888    YP  YP    8888 888 8   8 8888 
                                                                      
  ]#
  #! Process ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  #   support functions:
  proc newRow()=
    when debug > 1: echo "newRow"
    if line.len > 0: postProcessRow()

    availW = origiW
    availH -= lineH

    nextY = nextY + lineH - 1 
    if this.style.spacing > -1:
      nextY += this.style.spacing #spacing#
    
    nextX = this.x1
    if this.style.padding > -1:
      nextX += this.style.padding #padding#
      
    
    lineW = 0
    lineH = 0
    line.setLen(0)

  proc newColumn()=
    when debug > 1: echo "newColumn"
    if line.len > 0: postProcessColumn()

    availH = origiH
    availW -= lineW

    nextY = this.y1
    if this.style.padding > -1:
      nextY += this.style.padding #padding#
      
    nextX = nextX + lineW - 1
    if this.style.spacing > -1:
      nextX += this.style.spacing #spacing#
    
    lineH = 0
    lineW = 0
    line.setLen(0)
  #......................................



  #[ 
       ######  ########    ###    ########  ######## 
      ##    ##    ##      ## ##   ##     ##    ##    
      ##          ##     ##   ##  ##     ##    ##    
       ######     ##    ##     ## ########     ##    
            ##    ##    ######### ##   ##      ##    
      ##    ##    ##    ##     ## ##    ##     ##    
       ######     ##    ##     ## ##     ##    ##    
  ]#

  #[ 
      ███████ ██████  ██████   ██████  ██     ██ 
      ██      ██   ██ ██   ██ ██    ██ ██     ██ 
      █████   ██   ██ ██████  ██    ██ ██  █  ██ 
      ██      ██   ██ ██   ██ ██    ██ ██ ███ ██ 
      ██      ██████  ██   ██  ██████   ███ ███  
                                            
  ]#
  if this.styleCache[this.activeStyle].flexDirection == fdRow:#! ---- fdRow
    #todo valign, align
    when debug > 1: echo "this.styleCache[this.activeStyle].flexDirection == fdRow:"
    for elem in layer.elems:

      if elem of BRElem:
        newRow()
        continue


      case elem.h_unit:#. . . . . . . . . . . . 
        of muAuto: 
          #calced before
          #discard
          elem.h = availH
        of muStretch: #todo lineH! or availH?!
          #elem.h = availH
          elem.h = origiH
          when debug > 1: echo " availH ", availH
        of muPx:
          elem.h = elem.h_value
        of muPc:
          elem.h = (origiH.float / (100.float / elem.h_value.float)).int
  
      


      case elem.w_unit:
        #[ of muAuto:
          # needs calculated childs bounding box
          #[ (elem.w, elem.h) = elem.recalc(elem)
          if availW - elem.w < 0:
            newRow()
          availW -= elem.w
          line.add(elem) ]#
          discard ]#

        of muAuto,muStretch:
          elem.w = availW
          line.add(elem)
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
          #nextX = nextX + elem.w
          lineW += elem.w #!
          newRow()

        of muPx:
          elem.w = elem.w_value
          if availW - elem.w < 0:
            newRow()
          
          lineW += elem.w  
          availW -= elem.w
          line.add(elem)
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
          nextX = nextX + elem.w
          if this.style.spacing > -1: 
            nextX += this.style.spacing
            lineW += this.style.spacing
            availW -= this.style.spacing

        of muPc:
          elem.w = (origiW.float / (100.float / elem.w_value.float)).int
          if availW - elem.w < 0:
            newRow()
          
          lineW += elem.w
          availW -= elem.w
          line.add(elem)
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
          nextX = nextX + elem.w
          if this.style.spacing > -1:
            nextX += this.style.spacing
            lineW += this.style.spacing
            availW -= this.style.spacing

          when debug > 1: echo " availW ", availW




      #lineW += elem.w
      if lineH < elem.h: lineH = elem.h #todo


      # coordinates
      #[ elem.x1 = nextX
      elem.x2 = nextX + elem.w - 1
      elem.y1 = nextY
      elem.y2 = nextY + elem.h - 1
      nextX = nextX + elem.w ]#

      when debug > 1:
        echo elem.name, " flex w/h: ", elem.w, " / ", elem.h
        echo elem.name, " flex x1/x2: ", elem.x1, " / ", elem.x2
        echo elem.name, " flex y1,y2: ", elem.y1, " / ", elem.y2
        echo elem.name, ", padding: ", this.style.padding
        echo ""

    if line.len > 0: postProcessRow() # post process last row
    #todo justify
    distributeContent()
    #TODO SCROLL

  #[

  888888 8888b.   dP""b8  dP"Yb  88     88   88 8b    d8 88b 88 
  88__    8I  Yb dP   `" dP   Yb 88     88   88 88b  d88 88Yb88 
  88""    8I  dY Yb      Yb   dP 88  .o Y8   8P 88YbdP88 88 Y88 
  88     8888Y"   YboodP  YbodP  88ood8 `YbodP' 88 YY 88 88  Y8 
  
  ]#
  #!................................
  elif this.styleCache[this.activeStyle].flexDirection == fdColumn:#!---- fdColumn
    ## calculate childs position Vertically

    when debug > 0: echo this.name

    #todo valign, align

    for elem in layer.elems:
      #echo "test  ", elem.name
      if elem of BRElem:
        newColumn()
        continue

      case elem.w_unit:
        #[ of muAuto:
          #? elem.w = elem.w_value
          #(elem.w, elem.h) = elem.recalc(elem)
          discard ]#

        of muAuto,muStretch:#todo test
          elem.w = availW

        of muPx:
          elem.w = elem.w_value

        of muPc:
          elem.w = (origiW.float / (100.float / elem.w_value.float)).int

      case elem.h_unit: # H H H H H H H H H H H H H H H H H H 
        of muAuto: discard # calculated
        of muStretch:
          elem.h = availH
          line.add(elem)
          availH -= elem.h
          #line.add(elem) #????
          lineH += elem.h
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
          nextY = nextY + elem.h
          #[ if this.style.spacing > -1:
            nextY += this.style.spacing
            lineH += this.style.spacing
            availH -= this.style.spacing ]#
          ####
          newColumn()

        of muPx:
          elem.h = elem.h_value
          if availH - elem.h < 0:
            newColumn()

          availH -= elem.h
          line.add(elem)
          lineH += elem.h
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
          nextY = nextY + elem.h
          if this.style.spacing > -1:
            nextY += this.style.spacing
            lineH += this.style.spacing
            availH -= this.style.spacing
          #echo ">  availH ", availH, " this.h ", this.h

        of muPc:
          elem.h = (origiH.float / (100.float / elem.h_value.float)).int
          when debug > 1: echo "elem.h: ", elem.h, " !"
          if availH - elem.h < 0:
            newColumn()

          availH -= elem.h
          line.add(elem)
          lineH += elem.h
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
          nextY = nextY + elem.h
          if this.style.spacing > -1:
            nextY += this.style.spacing
            lineH += this.style.spacing
            availH -= this.style.spacing

      if lineW < elem.w: lineW = elem.w  #todo
      


      when debug > 1:
        echo elem.name, " w/h: ", elem.w, " / ", elem.h
        echo elem.name, " x1/x2: ", elem.x1, " / ", elem.x2
        echo elem.name, " y1,y2: " , elem.y1, " / ", elem.y2
        echo elem.name, ", padding: ", this.style.padding
        echo ""
    
    #todo justify
    if line.len > 0: postProcessColumn() # post process last row

    distributeContent()
    #TODO SCROLL




  this.isRecalculated = true
  result.h = totalH
  result.w = totalW
  when debug > 1: echo " ------ ENDFLEX ------ ", this.name, "\n"
  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)


