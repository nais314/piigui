import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui/types

import tables, math

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
  ##          CASE this.style.alignItems
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
  ##          CASE this.style.alignItems
  ##          GET flexGrowDivider
  ##          GET elementWithBiggestGrow
  ##          APPLY FLEX-GROW
  ## 
  ## 
  ##  *distributeContent()
  ##    *~[this.activeStyle].flexDirection == fdRow:
  ##       SCROLL ?
  ##      *CASE [this.activeStyle].alignContent:
  ##    *~[this.activeStyle].flexDirection == fdColumn:
  ##       [this.activeStyle].justifyContent:
  ##    
  #TODO    case this.style.alignContent
  const debug = 1
  
  when debug > 0: echo "\n this = ", this.name, " ########## BEGIN recalcFlex ##########"

  if this.layers[0].elems.len == 0:
    when debug > 0: echo "NO CHILDS? EXITING", this.name, " ########## END recalcFlex ##########"
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

  # for root, get window size - useful if window resized
  if this.parent == nil:
    var ww, wh: cint
    sdl.getSize(this.pgui.window, ww, wh)
    this.w = ww
    this.h = wh
    this.x1 = 0
    this.y1 = 0
    this.x2 = this.w - 1
    this.y2 = this.h - 1

    when debug > 1:
      echo "this.w ", this.w
      echo "this.h ", this.h

  # #TODO? innerW innerH for scroll 
  result.w = this.w
  result.h = this.h
  #* .w and .h are now initialized, ready for use

  # article holds lines of elems,
  # - needed for line distribution at end
  type Article = object
    lines: seq[seq[DivRef]]
    lineDims: seq[tuple[w,h, x,y:int]]

  var  #* padding *#
    availW: int # form line from parent.w downto 0
    availH: int
    thisX2: int # thisX2 = this.x2 - this.style.padding
    thisY2: int # thisY2 = this.y2 - this.style.padding
    nextX = this.x1 + this.style.padding
    nextY = this.y1 + this.style.padding # used at line calculation #padding#

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

    if this.x1 > thisX2: thisX2 = this.x1 #boundaries check
    if this.y1 > thisY2: thisY2 = this.y1 #boundaries check

    if availW < 0: availW = 0 #boundaries check
    if availH < 0: availH = 0 #boundaries check

  else:
    availW = this.w # used at line calculation
    availH = this.h
    thisX2 = this.x2
    thisY2 = this.y2

  #* padding calculated *#

  let # save original values for calculations
    origiW = availW
    origiH = availH
  when debug > 1: echo "origi W x H: ", origiW, " x ", origiH
  when debug > 1: echo "avail W x H: ", availW, " x ", availH

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
    if article.lines.len == 0:
      when debug > 0: echo "distributeContent:  article.lines.len == 0   RETURN" 
      return
    #if this.style.alignContent == facStart: return
    #...................

    var
      nY:int # new Y
      delta:int # distance
      remainder:int

    if this.style.flexDirection == fdRow:
      
      # if useless
      if totalH > origiH: # else scroll :)
        when debug > 0: echo "distributeContent totalH > origiH ",totalH, ">",origiH," RETURN"
        return 
      #[ 
        88""Yb  dP"Yb  Yb        dP                        
        88__dP dP   Yb  Yb  db  dP                         
        88"Yb  Yb   dP   YbdPYbdP                          
        88  Yb  YbodP     YP  YP

          db    88     88  dP""b8 88b 88                  
          dPYb   88     88 dP   `" 88Yb88                  
        dP__Yb  88  .o 88 Yb  "88 88 Y88                  
        dP""""Yb 88ood8 88  YboodP 88  Y8

        dP""b8  dP"Yb  88b 88 888888 888888 88b 88 888888 
        dP   `" dP   Yb 88Yb88   88   88__   88Yb88   88   
        Yb      Yb   dP 88 Y88   88   88""   88 Y88   88   
        YboodP  YbodP  88  Y8   88   888888 88  Y8   88   
      ]#
      case this.style.alignContent: #* ALIGN ROWS VERTICALLY IN PARENT
        of facUndefined, facStart: discard

        of facEnd: #TODO: scroll ?!
          nY = thisY2#this.y2
          for i_line in countdown(article.lines.high,0):
            nY -= (article.lineDims[i_line].h - 1)
            delta = nY - (article.lineDims[i_line].y)
            for elem in article.lines[i_line]:
              elem.y1 += delta
              elem.y2 += delta
        
        of facCenter:
          when debug > 1: echo "distributeContent:  row alignContent facCenter"
          when debug > 1: echo origiH," - ",totalH,"div 2 = ", (origiH - totalH) div 2

          delta = (origiH - totalH) div 2
          if delta > 1:
            for i_line in countdown(article.lines.high,0):
              for elem in article.lines[i_line]:
                elem.y1 += delta
                elem.y2 += delta

        of facStretch: #TODO TEST
          # [..]DS
          # get how much each line of elems heigth needs 2 grow
          delta = (origiH - totalH) div article.lines.len
          remainder = origiH - (delta * article.lines.len) # rounding patch

          var offset = 0 #*--offset
          for i_line in 0..article.lines.high:
            # rounding patch
            let grow = delta + (if remainder > 0: 1 else: 0)
            if remainder > 0: remainder -= 1

            article.lineDims[i_line].h += grow
            article.lineDims[i_line].y += offset #*--offset

            for i_elem in article.lines[i_line]:
              i_elem.y1 += offset        # shift down by previous lines' growth
              i_elem.h  += grow          # stretch to new line height
              i_elem.y2 += offset + grow # both shift and stretch

            offset += grow #*--offset


        of facSpaceBetween:
          if article.lines.len > 1:
            delta = (origiH - totalH) div (article.lines.len - 1) #! -1 (4 rows having 3 spaces between)
            remainder = origiH - (delta * (article.lines.len - 1))

            for i_line in 1..article.lines.high: #! starts from 1, no space above
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
      case this.style.justifyContent: #* ALIGN ROWS HORIZONTALLY IN PARENT
        of fjcUndefined, fjcStart: discard

        of fjcEnd:
          for i_line in 0..article.lines.high:
            delta = origiW - article.lineDims[i_line].w
            for i_elem in article.lines[i_line]:
              i_elem.x1 += delta
              i_elem.x2 += delta

        of fjcCenter:
          for i_line in 0..article.lines.high:
            delta = (origiW - article.lineDims[i_line].w) div 2
            if delta > 1:
              for i_elem in article.lines[i_line]:
                i_elem.x1 += delta
                i_elem.x2 += delta








#[ 
██████  ██ ███████ ████████ ██████  ██ ██████  ██    ██ ████████ ███████ 
██   ██ ██ ██         ██    ██   ██ ██ ██   ██ ██    ██    ██    ██      
██   ██ ██ ███████    ██    ██████  ██ ██████  ██    ██    ██    █████   
██   ██ ██      ██    ██    ██   ██ ██ ██   ██ ██    ██    ██    ██      
██████  ██ ███████    ██    ██   ██ ██ ██████   ██████     ██    ███████ 
                                                                         
                                                                         
 ██████  ██████  ██      ██    ██ ███    ███ ███    ██   
██      ██    ██ ██      ██    ██ ████  ████ ████   ██   
██      ██    ██ ██      ██    ██ ██ ████ ██ ██ ██  ██   
██      ██    ██ ██      ██    ██ ██  ██  ██ ██  ██ ██   
 ██████  ██████  ███████  ██████  ██      ██ ██   ████   
                                                                         
                                                                         
 ]#
    #!............flexDirection == fdColumn:................
    #! ROTATE YOUR VIEW 90 degrees
    if this.style.flexDirection == fdColumn:#!............
      when debug > 0: echo "distribute fdcolumn"

      if totalW < origiW: # else scroll :)

        # TODO CONTINUE
        case this.style.alignContent: #* ALIGN COLUMNS HORIZONTALLY IN PARENT
          of facUndefined: discard
          of facStart: discard
          of facCenter:
              when debug > 1: echo ">>> distribute fdcolumn  facCenter <<<"
              delta = (origiW - totalW) div 2
              remainder = (origiW - totalW) - (delta * 2)
              for i_line in 0..article.lines.high:
                for i_elem in article.lines[i_line]:
                  i_elem.x1 += delta
                  i_elem.x2 += delta
                  if remainder > 0:
                    i_elem.x1 += 1
                    i_elem.x2 += 1
                remainder -= 1

          of facSpaceBetween:
            if article.lines.len > 1:
              delta = (origiW - totalW) div (article.lines.len - 1)
              remainder = (origiW - totalW) - (delta * (article.lines.len - 1))
            elif article.lines.len == 1: # one line, facCenter:
              delta = (origiW - totalW) div 2
              remainder = (origiW - totalW) - (delta * 2)
            for i_line in 1..article.lines.high:
              for i_elem in article.lines[i_line]:
                i_elem.x1 += delta * i_line
                i_elem.x2 += delta * i_line
                if remainder > 0:
                  i_elem.x1 += 1
                  i_elem.x2 += 1
              remainder -= 1

          of facSpaceAround:
            if article.lines.len > 1:
              delta = (origiW - totalW) div (article.lines.len + 1)
              remainder = (origiW - totalW) - (delta * (article.lines.len + 1))
            elif article.lines.len == 1: # one line, facCenter:
              delta = (origiW - totalW) div 2
              remainder = (origiW - totalW) - (delta * 2)
            var i = 0
            for i_line in 0..article.lines.high:
              i += 1
              for i_elem in article.lines[i_line]:
                i_elem.x1 += delta * i
                i_elem.x2 += delta * i
                if remainder > 0:
                  i_elem.x1 += 1
                  i_elem.x2 += 1
              remainder -= 1

          of facStretch:
              delta = (origiW - totalW) div article.lines.len
              remainder = (origiW - totalW) - (delta * article.lines.len)
              for i_line in 0..article.lines.high:
                article.lineDims[i_line].w += delta
                if remainder > 0: article.lineDims[i_line].w += 1
                for i_elem in article.lines[i_line]:
                  i_elem.x1 += i_line * delta
                  i_elem.x2 += i_line * delta + delta
                  i_elem.w += delta
                  if remainder > 0:
                    i_elem.x2 += 1
                    i_elem.w += 1
                remainder -= 1

          of facEnd:
            delta = (origiW - totalW)
            for i_line in 0..article.lines.high:
              for i_elem in article.lines[i_line]:
                  i_elem.x1 += delta
                  i_elem.x2 += delta
          #else: discard

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
        case this.style.justifyContent:
          of fjcUndefined,fjcStart: discard
          of fjcEnd:
            for i_line in 0..article.lines.high:
              delta = origiH - article.lineDims[i_line].h
              for i_elem in article.lines[i_line]:
                i_elem.y1 += delta
                i_elem.y2 += delta
          of fjcCenter:
            when debug > 1: echo ">>> distribute fdcolumn  fjcCenter <<<"
            for i_line in 0..article.lines.high:
              delta = (origiH - article.lineDims[i_line].h) div 2
              for i_elem in article.lines[i_line]:
                i_elem.y1 += delta
                i_elem.y2 += delta
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
    if this.style.spacing > -1: #spacing# #TODO #????????
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
      case this.style.alignItems:
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
      if line[i_elem].style.flexGrow > 0:
        flexGrowDivider += line[i_elem].style.flexGrow
        if elementWithBiggestGrow == -1: # save for adding remaining space to
          elementWithBiggestGrow = i_elem
        #[ elif line[i_elem].style.flexGrow > line[elementWithBiggestGrow].styleCache[line[elementWithBiggestGrow].activeStyle].flexGrow:
          elementWithBiggestGrow = i_elem ]#
        elif line[i_elem].style.flexGrow > line[elementWithBiggestGrow].style.flexGrow:
          elementWithBiggestGrow = i_elem
    #........................................
    if lineH < origiH and flexGrowDivider > 0 and
      this.style.flexGrowFrom <= (lineH / origiH * 100).int:

      when debug > 1: 
        echo "postProcessColumn flexGrowFrom ", (lineH / origiH * 100).int
        echo "postProcessColumn flexGrowDivider ", flexGrowDivider, " origiH ", origiH, " lineH ", lineH

      let deltaSpace = if flexGrowDivider > origiH - lineH: 1 else: (origiH - lineH) div flexGrowDivider
      when debug > 1: echo "postProcessColumn deltaSpace ", deltaSpace

      # int division error patch
      let remainingSpace =  if flexGrowDivider > origiH - lineH: 0 else: origiH - (flexGrowDivider * deltaSpace) - lineH
      when debug > 1: echo "postProcessColumn remainingSpace ", remainingSpace
      
      for i_elem in 0..line.high:
        
        if lineH == origiH: break #!!!

        if line[i_elem].style.flexGrow > 0:
          var delta = line[i_elem].style.flexGrow * deltaSpace
          if i_elem == elementWithBiggestGrow: # int division error patch
            delta += remainingSpace
          if delta + lineH > origiH: delta = origiH - lineH #? patch

          line[i_elem].h += delta
          line[i_elem].y2 += delta
          lineH += delta

          when debug > 0:
            echo "postProcessColumn>>> ",line[i_elem].name, " y1 ", line[i_elem].y1, " y2 ",line[i_elem].y2
            echo "postProcessColumn>>> "," x1 ", line[i_elem].x1, " x2 ",line[i_elem].x2, "\n"
          # adjust the rest
          if i_elem < line.high:
            for ii_elem in i_elem + 1 .. line.high:
              line[ii_elem].y1 += delta
              line[ii_elem].y2 += delta





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
    #if lineH < 1: lineH = availH
    totalH += lineH #! important
    article.lines.add(line)
    article.lineDims.add((w: lineW, h: lineH, x: nextX, y:nextY))
    #~~~~~~~~~~~~~~~~~~~~~~
    var
      flexGrowDivider:int
      elementWithBiggestGrow: int = -1

    when debug > 2:
      for i_elem in 0..line.high:
        echo "postProcessRow: >>>>>> ", $i_elem, " <<<<<<< "
        

    for i_elem in 0..line.high:

      case line[i_elem].h_unit:#!NEW
        of muAuto, muStretch: #TODO TEST !!!!!!!!!!!!!!!
          if lineH <= 1: # if user not assigned height, stretch to lineH
            let oldLineH = lineH
            lineH = if availH <= 0: origiH else: availH
            line[i_elem].h = lineH
            line[i_elem].y2 += (lineH - 1)
            totalH += (lineH - oldLineH)
            article.lineDims[article.lineDims.high].h = lineH
          else:
            line[i_elem].h = lineH
            line[i_elem].y2 += (lineH - 1)
          #when debug > 1: echo "lineH: ", lineH
        else: discard

      case this.style.alignItems:
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
              when debug > 1: echo i_elem, "postProcessRow:  lineH ", lineH, ", ", line[i_elem].h, ", ", line[i_elem].name, ", ", delta, ", ", line[i_elem].y1
        of faiStretch:
            if line[i_elem].h < lineH:
              let delta = lineH - line[i_elem].h
              line[i_elem].y2 += delta

      # for correcting int division
      # store the elementWithBiggestGrow
      # later add the 'error' to its dimension (remainder)
      if line[i_elem].style.flexGrow > 0:
        flexGrowDivider += line[i_elem].style.flexGrow
        if elementWithBiggestGrow == -1: # save for adding remaining space to
          elementWithBiggestGrow = i_elem
        elif line[i_elem].style.flexGrow > 
          line[elementWithBiggestGrow].style.flexGrow:
          elementWithBiggestGrow = i_elem

    if lineW < origiW and flexGrowDivider > 0 and
      this.style.flexGrowFrom <= (lineW / origiW * 100).int:
      when debug > 1:echo "postProcessRow: flexGrowDivider ", flexGrowDivider, " origiW ", origiW, " lineW ", lineW

      let deltaSpace = if flexGrowDivider > origiW - lineW: 1 else: (origiW - lineW) div flexGrowDivider
      when debug > 1:echo "postProcessRow: deltaSpace ", deltaSpace

      # int division error patch
      let remainingSpace =  if flexGrowDivider > origiW - lineW: 0 else: origiW - (flexGrowDivider * deltaSpace) - lineW
      when debug > 1:echo "postProcessRow: remainingSpace ", remainingSpace
      
      for i_elem in 0..line.high:
        
        if lineW == origiW: break #!!!

        if line[i_elem].style.flexGrow > 0:
          var delta = line[i_elem].style.flexGrow * deltaSpace
          if i_elem == elementWithBiggestGrow: # int division error patch
            delta += remainingSpace
          if delta + lineW > origiW: delta = origiW - lineW #? patch

          line[i_elem].w += delta
          line[i_elem].x2 += delta
          lineW += delta

          when debug > 1: echo "postProcessRow: >>> ",line[i_elem].name, " ", line[i_elem].x1, " ",line[i_elem].x2

          # adjust the rest
          if i_elem < line.high:
            for ii_elem in i_elem + 1 .. line.high:
              line[ii_elem].x1 += delta
              line[ii_elem].x2 += delta

    #[ elif lineW < origiW:# if not grown full width
      when debug > -1: echo "justifyContent ", this.style.justifyContent
      case this.style.justifyContent:
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
                elem.x1 += delta ]#


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
    when debug > 1: echo "---newRow--- line.len ", line.len
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
    when debug > 1: echo "---newColumn. line len: ", line.len
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
  if this.style.flexDirection == fdRow:#! ---- fdRow
    #todo valign, align
    when debug > 1: echo "#####  this.style.flexDirection == fdRow:"
    for elem in layer.elems:

      if elem of BRElem:
        newRow()
        continue

      case elem.h_unit: #.................. 
        of muAuto, muStretch: 
          #discard
          elem.h = 1#availH #origiH #!NEW
        of muPx:
          elem.h = elem.h_value
        of muPc:
          elem.h = (origiH.float / (100.float / elem.h_value.float)).floor.int - 1
          #if elem.h > availH: elem.h = origiH

      #!TEST: if lineH < elem.h: lineH = elem.h #TODO boundaries and sanity check


      case elem.w_unit: #.................. 
        of muAuto,muStretch:
          # not the same as justify stretch
          # useful for the last elem in the row
          # for multiple elems see flexGrow!
          elem.w = availW
          line.add(elem)
          # coordinates
          elem.x1 = nextX
          elem.x2 = nextX + elem.w - 1
          elem.y1 = nextY
          elem.y2 = nextY + elem.h - 1
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
          elem.w = (origiW.float / (100.float / elem.w_value.float)).floor.int - 1
          if availW - elem.w <= 0:
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

          when debug > 1: echo "row muPc ", elem.w_value,"->",elem.w," aW:", availW

      if lineH < elem.h: lineH = elem.h #TODO boundaries and sanity check



      when debug > 1:
        echo elem.name, " flex w/h: ", elem.w, " / ", elem.h
        echo elem.name, " flex x1,y1: ", elem.x1, ", ", elem.y1
        echo elem.name, " flex x2,y2: ", elem.x2, ", ", elem.y2
        echo elem.name, ", padding: ", this.style.padding
        echo ""

    if line.len > 0: postProcessRow() # post process last row
    
    if totalH < origiH: distributeContent() # TODO: scroll
    
    #TODO SCROLL

  #[

  888888 8888b.   dP""b8  dP"Yb  88     88   88 8b    d8 88b 88 
  88__    8I  Yb dP   `" dP   Yb 88     88   88 88b  d88 88Yb88 
  88""    8I  dY Yb      Yb   dP 88  .o Y8   8P 88YbdP88 88 Y88 
  88     8888Y"   YboodP  YbodP  88ood8 `YbodP' 88 YY 88 88  Y8 
  
  ]#
  #!................................
  elif this.style.flexDirection == fdColumn:#!---- fdColumn
    ## calculate childs position Vertically

    when debug > 0: echo " START FDCOLUMN ", this.name

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
          elem.w = (origiW.float / (100.float / elem.w_value.float)).floor.int - 1


      if lineW < elem.w: lineW = elem.w  #todo


      case elem.h_unit: # H H H H H H H H H H H H H H H H H H 
        of muAuto, #: #discard # calculated #TODO think
          muStretch:
          when debug > 1: echo "muStretch"
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
            when debug > 1: echo "availH - elem.h < 0: ", availH, " - ", elem.h, " !"
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
          elem.h = (origiH.float / (100.float / elem.h_value.float)).floor.int - 1
          
          if availH - elem.h <= 0:
            when debug > 1: echo "availH - elem.h < 0: ", availH, " - ", elem.h, " !"
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
    when debug > 1: echo "   Column line.len = ", line.len
    if line.len > 0: postProcessColumn() # post process last row

    if totalW < origiW: distributeContent() #TODO: scroll
    #TODO SCROLL




  this.isRecalculated = true
  result.h = totalH
  result.w = totalW
  when debug > 1: echo " ------ ENDFLEX ------ ", this.name, "\n"
  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)


