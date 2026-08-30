import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui/types



proc recalcV*(this: DivRef, layer:Layer):tuple[w,h:int]=
  ## Calculate children vertical positions.
  const debug = 0

  result.w = this.w
  result.h = this.h # will not change

  var
    #availW = this.w
    availH = this.h
    thisX1: int
    thisY1: int
    #thisH: int
    thisW: int
    #countAutoWidthElems:int
    countAutoHElems:int
    #totalW: int # used at aligning the whole area
    totalH: int # and by result

  when debug > 1: echo "recalcV ", this.name

  if this.style.padding > -1:
     availH = this.h - (this.style.padding * 2)
     thisX1 = this.x1 + this.style.padding
     thisY1 = this.y1 + this.style.padding
     thisW = this.w - (this.style.padding * 2)
  else:
    availH = this.h
    thisX1 = this.x1
    thisY1 = this.y1
    thisW = this.w

  if this.style.spacing > 0 and layer.elems.len > 1:
    availH -= layer.elems.high * this.style.spacing


  #todo valign, align
  # size fixed-size elements
  for elem in layer.elems:

    case elem.w_unit:
      of muAuto, muStretch:
        elem.w = this.w
      of muPx:
        elem.w = elem.w_value
      of muPc:
        elem.w = (thisW.float * elem.w_value.float / 100.0).int

    case elem.h_unit:
      of muAuto, muStretch:
        countAutoHElems += 1
      of muPx:
        elem.h = elem.h_value
        availH -= elem.h
        #countAutoHElems += 1
      of muPc:
        elem.h = (this.h.float * elem.h_value.float / 100.0).int
        availH -= elem.h
        #countAutoHElems += 1

        

  if countAutoHElems > 0 and availH > countAutoHElems:
    when debug > 0 : echo "calc AUTO"
    let autoH = availH div countAutoHElems
    for elem in layer.elems:
      if elem.h_unit in [muAuto,muStretch]: elem.h = autoH
  else:
    let autoH = if this.style.padding > -1: (this.h - (this.style.padding * 2)) else: this.h
    for elem in layer.elems:
      if elem.h_unit in [muAuto,muStretch]: elem.h = autoH


  # coordinates
  var nextY = this.y1
  totalH = 0
  if this.style.spacing > 0:
    for elem in layer.elems:
      elem.x1 = this.x1
      elem.x2 = elem.x1 + elem.w - 1
      #nextX = elem.x2 + 1
      
      elem.y1 = nextY
      elem.y2 = elem.y1 + elem.h - 1
      nextY = elem.y2 + 1 + this.style.spacing

      # for result
      totalH += elem.h + this.style.spacing # trailing spacing patched below
  else:
    for elem in layer.elems:
      elem.x1 = this.x1
      elem.x2 = elem.x1 + elem.w - 1
      #nextX = elem.x2 + 1
      
      elem.y1 = nextY
      elem.y2 = elem.y1 + elem.h - 1
      nextY = elem.y2 + 1

      # for result
      totalH += elem.h

      when debug > 1: 
        echo elem.name, " recalcV w/h ", elem.w, "/", elem.h
        echo elem.name, " recalcV x1/x2 ", elem.x1, "/", elem.x2
        echo elem.name, " recalcV y1,y2 ", elem.y1, "/", elem.y2
        echo ""

  if this.style.spacing > 0: totalH -= this.style.spacing # subtract trailing spacing
  if totalH > result.h: result.h = totalH
  #TODO STRETCH!!!!!!!
  
  # recursively calc

  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)


