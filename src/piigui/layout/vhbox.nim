import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui/types

#TODO: style pading V, padding H
#[ 
 ######     ###    ##        ######  
##    ##   ## ##   ##       ##    ## 
##        ##   ##  ##       ##       
##       ##     ## ##       ##       
##       ######### ##       ##       
##    ## ##     ## ##       ##    ## 
 ######  ##     ## ########  ######  


##     ##                            
##     ##                            
##     ##                            
#########                            
##     ##                            
##     ##                            
##     ##                              
 ]#


proc recalcH*(this:DivRef, layer:Layer):tuple[w,h:int]=
  ## calculate childs position Horizontally
  const debug = 0

  var
    availW: int # = this.w  #padding# 
    thisX1: int
    thisY1: int
    thisH: int

  when debug > 0: echo this.name

  #......
  if this.style.padding > -1:
      availW = this.w - (this.style.padding * 2)
      thisX1 = this.x1 + this.style.padding
      thisY1 = this.y1 + this.style.padding
      thisH = this.h - (this.style.padding * 2)
  else:
      availW = this.w # used at line calculation
      thisX1 = this.x1
      thisY1 = this.y1
      thisH = this.h

  proc layoutPass(availWArg, thisX1Arg, thisY1Arg, thisHArg: int): int =
    var
      availW = availWArg
      thisX1 = thisX1Arg
      thisY1 = thisY1Arg
      thisH = thisHArg
      countAutoWidthElems: int
      totalW: int # used at aligning the whole area

    if this.style.spacing > -1:
      availW -= layer.elems.high * this.style.spacing

    let origiW = availW

    #todo valign, align
    for elem in layer.elems:

      when debug > 0:
        echo "recalcH ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
        echo "recalcH ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

      case elem.w_unit:
        of muAuto, muStretch:
          countAutoWidthElems += 1
        of muPx:
          elem.w = elem.w_value
          availW -= elem.w
        of muPc:
          elem.w = (origiW.float / (100.float / elem.w_value.float)).int
          availW -= elem.w

      case elem.h_unit:
        of muAuto, muStretch:
          elem.h = thisH
        of muPx:
          elem.h = elem.h_value
        of muPc:
          elem.h = (thisH.float / (100.float / elem.h_value.float)).int

    ## the problem with auto types
    ## if there are more, and scrolling is needed,
    ## there is no availW to divide.
    if countAutoWidthElems > 0 and availW > 1:
      let autoW = availW div countAutoWidthElems
      for elem in layer.elems:
        if elem.w_unit in [muAuto,muStretch]: elem.w = autoW
    else:
      let autoW = if this.style.padding > -1: (this.w - (this.style.padding * 2)) else: this.w
      for elem in layer.elems:
        if elem.w_unit in [muAuto,muStretch]: elem.w = autoW

    # coordinates
    var nextX = thisX1
    totalW = 0
    if this.style.spacing > 1:
      for elem in layer.elems:
        elem.x1 = nextX
        elem.x2 = elem.x1 + elem.w - 1
        nextX = elem.x2 + 1 + this.style.spacing
        elem.y1 = thisY1
        elem.y2 = elem.y1 + elem.h - 1
        totalW += elem.w + this.style.spacing
    else:
      for elem in layer.elems:
        elem.x1 = nextX
        elem.x2 = elem.x1 + elem.w - 1
        nextX = elem.x2 + 1
        elem.y1 = thisY1
        elem.y2 = elem.y1 + elem.h - 1
        totalW += elem.w

    result = totalW

  result.w = this.w
  result.h = this.h # will not change

  var totalW: int
  if this.parent != nil and this.style.overflow == ofScroll:
    var tw = layoutPass(availW, thisX1, thisY1, thisH)
    var hS = tw > availW # horizontal scrollbar needed?
    if hS:
      # a horizontal scrollbar shows at the bottom: reserve its height
      thisH = thisH - ScrollBarSize
      tw = layoutPass(availW, thisX1, thisY1, thisH)
      hS = tw > availW
    this.innerW = tw
    this.innerH = this.h
    totalW = tw
  else:
    totalW = layoutPass(availW, thisX1, thisY1, thisH)
    this.innerW = totalW
    this.innerH = this.h

  if totalW > result.w: result.w = totalW

  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)






#-------------------------------------------------------




#[ 
 ######     ###    ##        ######  
##    ##   ## ##   ##       ##    ## 
##        ##   ##  ##       ##       
##       ##     ## ##       ##       
##       ######### ##       ##       
##    ## ##     ## ##       ##    ## 
 ######  ##     ## ########  ######  


##     ##                            
##     ##                            
##     ##                            
##     ##                            
 ##   ##                             
  ## ##                              
   ###                               

 ]#
proc recalcV*(this: DivRef, layer:Layer):tuple[w,h:int]=
  ## calculate childs position Vertically
  const debug = 0

  var
    availH: int
    thisW: int

  when debug > 1: echo "recalcV ", this.name

  if this.style.padding > -1:
    availH = this.h - (this.style.padding * 2)
    thisW = this.w - (this.style.padding * 2)
  else:
    availH = this.h # used at line calculation
    thisW = this.w

  proc layoutPass(availWArg, availHArg, thisWArg: int): tuple[totalW,totalH:int] =
    var
      availW = availWArg
      availH = availHArg
      thisW = thisWArg
      countAutoHElems: int
      totalW: int
      totalH: int

    if this.style.spacing > -1:
      availH -= layer.elems.high * this.style.spacing

    #todo valign, align
    for elem in layer.elems:

      case elem.w_unit:
        of muAuto, muStretch:
          elem.w = availW
        of muPx:
          elem.w = elem.w_value
        of muPc:
          elem.w = (thisW.float / (100.float / elem.w_value.float)).int

      case elem.h_unit:
        of muAuto, muStretch:
          countAutoHElems += 1
        of muPx:
          elem.h = elem.h_value
          availH -= elem.h
        of muPc:
          elem.h = (this.h.float / (100.float / elem.h_value.float)).int
          availH -= elem.h

    if countAutoHElems > 0 and availH > 1:
      when debug > 0: echo "calc AUTO"
      let autoH = availH div countAutoHElems
      for elem in layer.elems:
        if elem.h_unit in [muAuto,muStretch]: elem.h = autoH
    else:
      let autoH = if this.style.padding > -1: (this.h - (this.style.padding * 2)) else: this.h
      for elem in layer.elems:
        if elem.h_unit in [muAuto,muStretch]: elem.h = autoH

    # coordinates
    var nextY = this.y1
    if this.style.spacing > 1:
      for elem in layer.elems:
        elem.x1 = this.x1
        elem.x2 = elem.x1 + elem.w - 1
        elem.y1 = nextY
        elem.y2 = elem.y1 + elem.h - 1
        nextY = elem.y2 + 1 + this.style.spacing
        totalH += elem.h + this.style.spacing
        if elem.w > totalW: totalW = elem.w
    else:
      for elem in layer.elems:
        elem.x1 = this.x1
        elem.x2 = elem.x1 + elem.w - 1
        elem.y1 = nextY
        elem.y2 = elem.y1 + elem.h - 1
        nextY = elem.y2 + 1
        totalH += elem.h
        if elem.w > totalW: totalW = elem.w

        when debug > 1:
          echo elem.name, " recalcV w/h ", elem.w, "/", elem.h
          echo elem.name, " recalcV x1/x2 ", elem.x1, "/", elem.x2
          echo elem.name, " recalcV y1,y2 ", elem.y1, "/", elem.y2
          echo ""

    result.totalW = totalW
    result.totalH = totalH

  result.w = this.w
  result.h = this.h # will not change

  var
    totalW: int
    totalH: int
  if this.parent != nil and this.style.overflow == ofScroll:
    (totalW, totalH) = layoutPass(this.w, availH, thisW)
    var vS = totalH > availH # vertical scrollbar needed?
    var hS = totalW > this.w # horizontal scrollbar needed?
    if vS or hS:
      var aw = this.w - (if vS: ScrollBarSize else: 0)
      var ah = availH - (if hS: ScrollBarSize else: 0)
      (totalW, totalH) = layoutPass(aw, ah, thisW)
    this.innerW = totalW
    this.innerH = totalH
  else:
    (totalW, totalH) = layoutPass(this.w, availH, thisW)
    this.innerW = totalW
    this.innerH = totalH

  if totalH > result.h: result.h = totalH
  #TODO STRETCH!!!!!!!

  # recursively calc
  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)



