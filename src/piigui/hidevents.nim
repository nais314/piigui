
#[ 
######## ##     ## ######## ##    ## ########  ######  
##       ##     ## ##       ###   ##    ##    ##    ## 
##       ##     ## ##       ####  ##    ##    ##       
######   ##     ## ######   ## ## ##    ##     ######  
##        ##   ##  ##       ##  ####    ##          ## 
##         ## ##   ##       ##   ###    ##    ##    ## 
########    ###    ######## ##    ##    ##     ######  

 ]#
import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui
import piigui/[types,style]

import tables


# Event handling
# Return true on pgui shutdown request, otherwise return false
proc hid_events*(pgui:Pgui): bool = # exit pgui on true
  const debug = 0
  result = false
  var e: sdl.Event

  while sdl.pollEvent( e ) != false: #! ==== POLL EVENT


    # Quit requested
    if e.kind == sdl.QuitEvent:
      return true

    # Key pressed
    elif e.kind == sdl.KeyDown: #! ----- KeyDown
      #echo repr(e)
      let eventObj = evKeyboard(e)
      pgui.currentWindowId = eventObj.windowID # set activeWindow # todo setter events focus window
      # Exit on Escape key press
      if eventObj.keysym.sym == sdl.K_Escape:
        return true
      when debug >= 2:
        echo eventObj.keysym.sym
        echo eventObj.keysym.scancode.int

      if pgui.focusElem != nil:
        if not pgui.focusElem.trigger($eventObj.keysym.scancode):
          pgui.trigger($eventObj.keysym.scancode)
      else:
        pgui.trigger($eventObj.keysym.scancode)


    elif e.kind == sdl.MouseMotion: #! ----- MouseMotion
      let eventObj = evMouseMotion(e)
      when debug >= 1:
        #echo "> X: ",eventObj.x, " Y: ", eventObj.y
        echo eventObj.motion
      
      let eventTarget = getElementAtCoord(
        pgui.windows[eventObj.windowID].rootElem,
        eventObj.x,
        eventObj.y)

      if eventTarget != nil:
        # set window - holding eventtarget - active
        #pgui.window = pgui.windows[eventObj.windowID].window
        pgui.currentWindowId = eventObj.windowID
        #pgui.renderer = pgui.windows[eventObj.windowID].renderer
        
        # if there was onmousedown before
        # then its a drag/dragover operation:
        if pgui.mouseSource != nil:
          if pgui.mouseSource == eventTarget and
            pgui.mouseSource.activeStyle != "dragstart":#!dragstart
                if eventTarget.onDragStart != nil:
                  eventTarget.onDragStart(eventTarget)
          else:
            if eventTarget.onDragOver != nil:
              eventTarget.onDragOver(eventTarget)

        # elif its a simple hover event:
        elif eventTarget.onHover != nil:
          eventTarget.onHover(eventTarget)
        
        # else maybe cleanup needed?
        else:
          if pgui.hoverElem != nil:
            pgui.hoverElem.setDefaultStyle()
            pgui.hoverElem = nil


    elif e.kind == sdl.MOUSEBUTTONDOWN: #! ----- MOUSEBUTTONDOWN
      let eventObj = evMouseButton(e)

      pgui.currentWindowId = eventObj.windowID

      let eventTarget = getElementAtCoord(
            #pgui.windows[ cast[MouseMotionEventPtr](unsafeAddr(e)).windowID ].rootElem,
            #pgui.windows[ evMouseButton(e).windowID ].rootElem,
            pgui.windows[ eventObj.windowID ].rootElem,
            eventObj.x, eventObj.y)
      if eventTarget != nil:
        # D&D:
        pgui.mouseSource = eventTarget
        #[ if eventTarget.onDragStart != nil and # draggable true
          pgui.mouseSource != eventTarget: #???
            pgui.mouseSource = eventTarget ]#
        #[ # Click:
        if eventTarget.onClick != nil:
          eventTarget.onClick(eventTarget, e)
        eventTarget.trigger("click") ]#
        if eventTarget.onMouseButtonDown != nil:
          eventTarget.onMouseButtonDown(eventTarget)
          # please call Elems onFocus method
          # in eventTarget.onMouseButtonDown
          # if needed ((for flexibility))


    
    elif e.kind == sdl.MOUSEBUTTONUP: #! ----- MOUSEBUTTONUP
      let eventObj = evMouseButton(e)
      pgui.currentWindowId = eventObj.windowID

      let eventTarget = getElementAtCoord(
            pgui.windows[eventObj.windowID].rootElem,
            eventObj.x, eventObj.y)
      
      if eventTarget != nil:
        # Default
        if eventTarget.onMouseButtonUp != nil:
          eventTarget.onMouseButtonUp(eventTarget)
    
        if pgui.mouseSource != nil:
          if pgui.mouseSource == eventTarget:
            # Click:
            if eventTarget.onClick != nil:
              eventTarget.onClick(eventTarget, e)
            eventTarget.trigger("click")

          else: # ~ on other elem = possible Drop
            if pgui.mouseSource.onDragEnd != nil: #* draggable true
              pgui.mouseSource.onDragEnd(pgui.mouseSource)
              #! Drop
              if eventTarget.onDrop != nil:
                eventTarget.onDrop(eventTarget) #TODO FILEDROP!!!
            
            if eventTarget.onFocus != nil: #****
              eventTarget.onFocus(eventTarget)


          
      pgui.mouseSource = nil
      #pgui.mouseTarget = nil


    elif e.kind == sdl.MOUSEWHEEL: #! ----- MOUSEWHEEL
      let eventObj = evMouseWheel(e)
      when debug > 0: echo eventObj.wheel
      
      if pgui.hoverElem != nil:
        ## set window - holding eventtarget - active
        #pgui.window = pgui.windows[eventObj.windowID].window
        #pgui.renderer = pgui.windows[eventObj.windowID].renderer

        if eventObj.y > 0:
          when debug > 0: echo "wheelup"
          discard pgui.hoverElem.trigger("wheelup")
        elif eventObj.y < 0:
          when debug > 0: echo "wheeldown"
          discard pgui.hoverElem.trigger("wheeldown")
        elif eventObj.x > 0:
          when debug > 0: echo "wheelright"
          discard pgui.hoverElem.trigger("wheelright")
        elif eventObj.x < 0:
          when debug > 0: echo "wheelleft"
          discard pgui.hoverElem.trigger("wheelleft")


    elif e.kind == sdl.TEXTINPUT: #! ----- TEXTINPUT
      let eventObj = evTextInput(e)
      when debug > 0: echo eventObj.text
      #echo eventObj.text
      #textbox1.`value&=` $eventObj.text
      if pgui.focusElem != nil:
        if sdl.isTextInputActive():
          if pgui.focusElem.onTextInput != nil:
            pgui.focusElem.onTextInput(pgui.focusElem, $eventObj.text)
    

    elif e.kind == sdl.WINDOWEVENT: #! ----- WINDOWEVENT
        let eventObj = evWindow(e)
        case (eventObj.event):
          of WINDOWEVENT_SHOWN:
            when debug > 0:
              echo "WINDOWEVENT_SHOWN ", eventObj.windowId
            discard

          of WINDOWEVENT_HIDDEN:
            when debug > 0:
              echo "WINDOWEVENT_HIDDEN ", eventObj.windowId
            discard

          of WINDOWEVENT_EXPOSED:
            when debug > 0:
              echo "WINDOWEVENT_EXPOSED ", eventObj.windowId
            discard

          of WINDOWEVENT_MOVED:
            when debug > 0:
              echo "WINDOWEVENT_MOVED ", eventObj.windowId, "\n",
                eventObj.data1, "\n",
                eventObj.data2, "\n"
            
            discard

          of WINDOWEVENT_RESIZED:
            when debug > 0:
              echo "WINDOWEVENT_RESIZED ", eventObj.windowId, "\n",
                eventObj.data1, "\n",
                eventObj.data2, "\n"
            
            #pgui.windows[eventObj.windowID].recalc()
            var cw,ch:cint
            sdl.getSize(
              pgui.windows[eventObj.windowID].window,
              cw,ch
              )
            
            pgui.windows[eventObj.windowID].rootElem.w_value = cw
            pgui.windows[eventObj.windowID].rootElem.h_value = ch
            #........

            # TODO TSS change


          of WINDOWEVENT_SIZE_CHANGED:
            when debug > 0:
              echo "WINDOWEVENT_SIZE_CHANGED ", eventObj.windowId, "\n",
                eventObj.data1, "\n",
                eventObj.data2, "\n"
            #pgui.windows[eventObj.windowID].recalc()
            var cw,ch:cint
            sdl.getSize(
              pgui.windows[eventObj.windowID].window,
              cw,ch
              )
            
            pgui.windows[eventObj.windowID].rootElem.w_value = cw
            pgui.windows[eventObj.windowID].rootElem.h_value = ch


          of WINDOWEVENT_MINIMIZED:
            when debug > 0:
              echo "WINDOWEVENT_MINIMIZED ", eventObj.windowId
            discard
          of WINDOWEVENT_MAXIMIZED:
            when debug > 0:
              echo "WINDOWEVENT_MAXIMIZED ", eventObj.windowId
            discard
          of WINDOWEVENT_RESTORED:
            when debug > 0:
              echo "WINDOWEVENT_RESTORED ", eventObj.windowId
            discard
          of WINDOWEVENT_ENTER:
            when debug > 0:
              echo "WINDOWEVENT_ENTER ", eventObj.windowId
            discard
          of WINDOWEVENT_LEAVE:
            when debug > 0:
              echo "WINDOWINDOWEVENT_LEAVED ", eventObj.windowId
            discard
          of WINDOWEVENT_FOCUS_GAINED:
            when debug > 0:
              echo "WINDOWEVENT_FOCUS_GAINED ", eventObj.windowId
            discard
          of WINDOWEVENT_FOCUS_LOST:
            when debug > 0:
              echo "WINDOWEVENT_FOCUS_LOST ", eventObj.windowId
            discard
          of WINDOWEVENT_CLOSE:
            when debug > 0:
              echo "WINDOWEVENT_CLOSE ", eventObj.windowId
            discard
          #if VERSION_ATLEAST(2, 0, 5)
          of WINDOWEVENT_TAKE_FOCUS:
            when debug > 0:
              echo "WINDOWEVENT_TAKE_FOCUS ", eventObj.windowId
            discard
          of WINDOWEVENT_HIT_TEST:
            when debug > 0:
              echo "WINDOWEVENT_HIT_TEST ", eventObj.windowId
            discard
          #endif
          else:
            when debug > 0:
              echo "UNKNOWN WINDOW EVENT ", eventObj.windowId
            discard

