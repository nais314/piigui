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

  when debug > 0 : echo this.name

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

  #...
  if this.style.spacing > -1:
    availW -= layer.elems.high * this.style.spacing


  let origiW = availW

  #...... 


  #todo valign, align
  for elem in layer.elems:

    when debug > 0 : 
      echo "recalcH ", elem.name, " elem.w_value: ", elem.w_value, " ", elem.w_unit
      echo "recalcH ", elem.name, " elem.h_value: ", elem.h_value, " ", elem.h_unit

    case elem.w_unit:
      of muAuto, muStretch:
        countAutoWidthElems += 1
      of muPx:
        elem.w = elem.w_value
        availW -= elem.w
        #countAutoWidthElems += 1
      of muPc:
        #elem.w = (this.w.float / (100.float / elem.w_value.float)).int
        elem.w = (origiW.float / (100.float / elem.w_value.float)).int
        availW -= elem.w
        #countAutoWidthElems += 1

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
    var
      nextX = thisX1
    totalW = 0


    if this.style.spacing > 1:
      for elem in layer.elems:
        elem.x1 = nextX
        elem.x2 = elem.x1 + elem.w - 1
        nextX = elem.x2 + 1 + this.style.spacing
        
        elem.y1 = thisY1
        elem.y2 = elem.y1 + elem.h - 1

        # result
        totalW += elem.w + this.style.spacing

    else:
      for elem in layer.elems:
        elem.x1 = nextX
        elem.x2 = elem.x1 + elem.w - 1
        nextX = elem.x2 + 1
        
        elem.y1 = thisY1
        elem.y2 = elem.y1 + elem.h - 1

        # result
        totalW += elem.w
    #[ for elem in layer.elems:
      # todo align
      elem.x1 = nextX
      elem.x2 = elem.x1 + elem.w - 1
      nextX = elem.x2 + 1
      
      # todo valign
      elem.y1 = thisY1
      elem.y2 = elem.y1 + elem.h - 1

      # result
      totalW += elem.w ]#

      #[ when debug > 0:
        echo elem.name, " recalcH. w/h ", elem.w, "/", elem.h
        echo elem.name, " recalcH. x1/x2 ", elem.x1, "/", elem.x2
        echo elem.name, " recalcH. y1,y2 ", elem.y1, "/", elem.y2
        echo "" ]#

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
    availH = this.h # used at line calculation
    thisX1 = this.x1
    thisY1 = this.y1
    thisW = this.w

  if this.style.spacing > -1:
    availH -= layer.elems.high * this.style.spacing


  #todo valign, align
  for elem in layer.elems:

    case elem.w_unit:
      of muAuto, muStretch:
        elem.w = this.w
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
        #countAutoHElems += 1
      of muPc:
        elem.h = (this.h.float / (100.float / elem.h_value.float)).int
        echo elem.h, " !"
        availH -= elem.h
        #countAutoHElems += 1

        

  if countAutoHElems > 0 and availH > 1:
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
  if this.style.spacing > 1:
    for elem in layer.elems:
      elem.x1 = this.x1
      elem.x2 = elem.x1 + elem.w - 1
      #nextX = elem.x2 + 1
      
      elem.y1 = nextY
      elem.y2 = elem.y1 + elem.h - 1
      nextY = elem.y2 + 1 + this.style.spacing

      # for result
      totalH += elem.h + this.style.spacing
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

  if totalH > result.h: result.h = totalH
  #TODO STRETCH!!!!!!!
  
  # recursively calc

  for elem in layer.elems:
    for elemLayer in elem.layers:
      if elemLayer.recalc != nil:
        (elemLayer.w, elemLayer.h) = elemLayer.recalc(elem, elemLayer)


