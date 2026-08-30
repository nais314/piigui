import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui/types




proc recalcH*(this:DivRef, layer:Layer):tuple[w,h:int]=
  ## Calculate children horizontal positions.
  ##   only one row
  ##   no scrolling
  ## It can divide the space evenly 
  ##   for auto or stretch styled gui elements.
  const debug = 0
  
  result.w = this.w
  result.h = this.h # will not change

  var
    availW: int # = this.w  #padding# 
    thisX1: int
    thisY1: int
    thisH: int
    #availH = this.h
    countAutoWidthElems:int
    #countAutoHElems:int
    totalW: int # used at aligning the whole area
    #totalH: int # and by result

  let # runtime cache
    spacing = this.style.spacing 
    padding = this.style.padding

  when debug > 0 : echo this.name

  # Add padding style
  if padding > 0:
      availW = this.w - (padding * 2)
      thisX1 = this.x1 + padding
      thisY1 = this.y1 + padding
      thisH = this.h - (padding * 2)
  else:
      availW = this.w
      thisX1 = this.x1
      thisY1 = this.y1
      thisH = this.h

  # Add spacing style
  if spacing > 0 and layer.elems.len > 1:
    availW -= layer.elems.high * spacing


  # original available width
  let origiW = availW

  
  ####* Setup complete, now do the job ....... 


  
  # size fixed-width elements
  for elem in layer.elems:

    when debug > 0 : 
      echo "recalcH start: ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcH start: ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

    case elem.w_unit:
      of muAuto, muStretch:
        countAutoWidthElems += 1
      of muPx:
        elem.w = elem.w_value
        availW -= elem.w
        #countAutoWidthElems += 1
      of muPc:
        #elem.w = (this.w.float / (100.float / elem.w_value.float)).int
        elem.w = (origiW.float * elem.w_value.float / 100.0).int
        availW -= elem.w
        #countAutoWidthElems += 1

    case elem.h_unit: 
      of muAuto, muStretch: 
        elem.h = thisH
      of muPx:
        elem.h = elem.h_value
      of muPc:
        elem.h = (thisH.float * elem.h_value.float / 100.0).int

        
  if countAutoWidthElems > 0 and availW > countAutoWidthElems:
    let autoW = availW div countAutoWidthElems
    for elem in layer.elems:
      if elem.w_unit in [muAuto,muStretch]: elem.w = autoW
  else:
    let autoW = if padding > 0: (this.w - (padding * 2)) else: this.w
    for elem in layer.elems:
      if elem.w_unit in [muAuto,muStretch]: elem.w = autoW


  # calculate elem coordinates ..............
  # sum content width
  var
    nextX = thisX1
  totalW = 0

  if spacing > 0:
    for elem in layer.elems:
      elem.x1 = nextX
      elem.x2 = elem.x1 + (elem.w - 1) # 0+10=11px wide, 21+5=6px wide
      nextX = (elem.x2 + 1) + spacing # could be faster, but it is readable

      elem.y1 = thisY1
      elem.y2 = elem.y1 + (elem.h - 1)

      # result
      totalW += elem.w + spacing # trailing spacing patched below

  else: # if no spaceing
    for elem in layer.elems:
      elem.x1 = nextX
      elem.x2 = elem.x1 + elem.w - 1
      nextX = elem.x2 + 1

      elem.y1 = thisY1
      elem.y2 = elem.y1 + elem.h - 1

      # result
      totalW += elem.w
  if spacing > 0: totalW -= spacing # subtract trailing spacing


  # align elements vertically
  for elem in layer.elems:
    case this.style.alignItems:
      of faiUndefined,faiStart: discard
      of faiEnd:
          if elem.h < thisH:
            let delta = thisH - elem.h
            elem.y1 += delta
            elem.y2 += delta
      of faiCenter:
          if elem.h < thisH:
            let delta = (thisH - elem.h) div 2
            if delta > 0:
              elem.y1 += delta
              elem.y2 += delta
      #[ of faiStretch: # possible logical error
          if elem.h < thisH:
            let delta = thisH - elem.h
            elem.y2 += delta
            elem.h += delta ]#
      else: discard


  if totalW > result.w: result.w = totalW #!



  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)



