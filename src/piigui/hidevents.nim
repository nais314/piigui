
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
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases

import piigui
import piigui/[types,style]

import tables


#!FWD
proc markWindowDirty(pgui:Pgui, windowID:uint32) #!FWD
proc markElemWindowDirty(elem:DivRef) #!FWD


# Event handling
# Return true on pgui shutdown request, otherwise return false
proc hid_events*(pgui:Pgui): bool = # exit pgui on true
  const debug = 0
  result = false
  var e: sdl.Event

  while sdl.pollEvent( e ): #! ==== POLL EVENT

    # Quit requested
    if e.`type` == sdl.EVENT_QUIT:
      return true

    # Key pressed
    elif e.`type` == sdl.EVENT_KEY_DOWN: #! ----- KeyDown
      let windowID = e.key.windowID
      pgui.currentWindowId = windowID # set activeWindow # todo setter events focus window
      # keyboard events may change styles; repaint the focused window
      if pgui.focusElem != nil and pgui.focusElem.window != nil:
        markElemWindowDirty(pgui.focusElem)
      else:
        markWindowDirty(pgui, windowID)
      #! Exit on Escape key press
      # Drag stop on Escape
      if e.key.key == sdl.SDLK_ESCAPE:
        if pgui.mouseSource != nil:
          # Escape cancels the drag: restore the begin state
          if pgui.mouseSource.onDragCancel != nil:
            pgui.mouseSource.onDragCancel(pgui.mouseSource)
          else:
            piigui.default_onDragCancel(pgui.mouseSource)
          pgui.mouseSource.dragSaved = false
          pgui.mouseSource = nil
        else:
          return true
      #......... end ESC ..................  
      when debug >= 2:
        echo e.key.key
        echo e.key.scancode.int

      #* keyboard bubbling: focusElem -> window -> pgui. Each scope tries the
      #* fine-grained "keydown" bus, then the legacy per-scancode bus; the
      #* first listener that returns true handles the event and stops bubbling.
      var handled = false
      if pgui.focusElem != nil:
        handled = pgui.focusElem.trigger("keydown", e)
        if not handled:
          handled = pgui.focusElem.trigger($e.key.scancode, e)
      if not handled and pgui.windows.hasKey(windowID):
        let win = pgui.windows[windowID]
        handled = win.trigger("keydown", e)
        if not handled:
          handled = win.trigger($e.key.scancode, e)
      if not handled:
        handled = pgui.trigger("keydown", e)
        if not handled:
          discard pgui.trigger($e.key.scancode, e)


    elif e.`type` == sdl.EVENT_MOUSE_MOTION: #! ----- MouseMotion
      let windowID = e.motion.windowID
      let mx = e.motion.x.cint
      let my = e.motion.y.cint

      pgui.mouseX = mx
      pgui.mouseY = my
      
      let eventTarget = getElementAtCoord(
        pgui.windows[windowID].rootElem,
        mx,
        my)

      if eventTarget != nil:
        pgui.currentWindowId = windowID
        let previousHover = pgui.hoverElem

        # if there was onmousedown before
        # then its a drag/dragover operation:
        if pgui.mouseSource != nil:
          markElemWindowDirty(eventTarget)
          if not pgui.mouseSource.dragSaved and pgui.mouseSource.onDragStart != nil:
            pgui.mouseSource.onDragStart(pgui.mouseSource)
          if pgui.mouseSource.onDragOver != nil:
            pgui.mouseSource.onDragOver(pgui.mouseSource)
          if eventTarget != pgui.mouseSource and eventTarget.onDragOver != nil:
            eventTarget.onDragOver(eventTarget)

        # elif its a simple hover event:
        elif eventTarget.onHover != nil:
          eventTarget.onHover(eventTarget)
          # only repaint when the hover target changed; the default hover
          # handler is a no-op when this element is already hovered
          if eventTarget != previousHover:
            markElemWindowDirty(eventTarget)
            if previousHover != nil:
              markElemWindowDirty(previousHover)

        # else maybe cleanup needed?
        else:
          if previousHover != nil:
            previousHover.setDefaultStyle()
            pgui.hoverElem = nil
            markElemWindowDirty(previousHover)
            markElemWindowDirty(eventTarget)


    elif e.`type` == sdl.EVENT_MOUSE_BUTTON_DOWN: #! ----- MOUSEBUTTONDOWN
      let windowID = e.button.windowID
      let mx = e.button.x.cint
      let my = e.button.y.cint

      pgui.currentWindowId = windowID

      let eventTarget = getElementAtCoord(
            pgui.windows[ windowID ].rootElem,
            mx, my)
      if eventTarget != nil:
        markElemWindowDirty(eventTarget)
        pgui.mouseSource = eventTarget
        if eventTarget.onMouseButtonDown != nil:
          eventTarget.onMouseButtonDown(eventTarget)

    
    elif e.`type` == sdl.EVENT_MOUSE_BUTTON_UP: #! ----- MOUSEBUTTONUP
      let windowID = e.button.windowID
      let mx = e.button.x.cint
      let my = e.button.y.cint
      pgui.currentWindowId = windowID

      let eventTarget = getElementAtCoord(
            pgui.windows[windowID].rootElem,
            mx, my)
      
      if eventTarget != nil:
        markElemWindowDirty(eventTarget)
        # Default
        if eventTarget.onMouseButtonUp != nil:
          eventTarget.onMouseButtonUp(eventTarget)
    
        if pgui.mouseSource != nil:
          if pgui.mouseSource == eventTarget:
            when debug > 0: echo "pgui.mouseSource == eventTarget"
            # Blur inputs on panel click
            if eventTarget.pgui.focusElem != nil and eventTarget.pgui.focusElem != eventTarget:
              if eventTarget.pgui.focusElem.onBlur != nil:
                eventTarget.pgui.focusElem.onBlur(eventTarget.pgui.focusElem)
              if eventTarget.onFocus != nil: #****
                eventTarget.onFocus(eventTarget)
            eventTarget.pgui.focusElem = eventTarget
            # Click:
            if eventTarget.onClick != nil:
              eventTarget.onClick(eventTarget, e)
            eventTarget.trigger("click", e)

          else: # ~ on other elem = possible Drop
            when debug > 0: echo "pgui.mouseSource != eventTarget"
            if pgui.mouseSource.onDragEnd != nil: #* draggable true
              pgui.mouseSource.onDragEnd(pgui.mouseSource)
              #! Drop
              if eventTarget.onDrop != nil:
                eventTarget.onDrop(eventTarget) #TODO FILEDROP!!!
            if eventTarget.onFocus != nil: #****
              eventTarget.onFocus(eventTarget)

          
      if pgui.mouseSource != nil:
        pgui.mouseSource.dragSaved = false
      pgui.mouseSource = nil


    elif e.`type` == sdl.EVENT_MOUSE_WHEEL: #! ----- MOUSEWHEEL
      let windowID = e.wheel.windowID
      # wheel scrolls the hovered element's window
      if pgui.hoverElem != nil:
        markElemWindowDirty(pgui.hoverElem)
      else:
        markWindowDirty(pgui, windowID)
      
      if pgui.hoverElem != nil:
        var handled = false
        if e.wheel.y > 0.0:
          when debug > 0: echo "wheelup"
          handled = pgui.hoverElem.trigger("wheelup", e)
        elif e.wheel.y < 0.0:
          when debug > 0: echo "wheeldown"
          handled = pgui.hoverElem.trigger("wheeldown", e)
        elif e.wheel.x > 0.0:
          when debug > 0: echo "wheelright"
          handled = pgui.hoverElem.trigger("wheelright", e)
        elif e.wheel.x < 0.0:
          when debug > 0: echo "wheelleft"
          handled = pgui.hoverElem.trigger("wheelleft", e)

        # if no listener handled it, scroll the nearest scrollable ancestor
        if not handled:
          var cur = pgui.hoverElem
          while cur != nil:
            if cur.scrollable and cur.scrollbar != nil:
              scrollWheel(cur, e.wheel.x.cint, e.wheel.y.cint)
              break
            cur = cur.parent


    elif e.`type` == sdl.EVENT_TEXT_INPUT: #! ----- TEXTINPUT
      let windowID = e.text.windowID
      markElemWindowDirty(pgui.focusElem)
      if pgui.focusElem != nil and pgui.focusElem.window != nil:
        if sdl.textInputActive(pgui.focusElem.window.window):
          if pgui.focusElem.onTextInput != nil:
            pgui.focusElem.onTextInput(pgui.focusElem, $e.text.text)
    

    elif e.`type` == sdl.EVENT_WINDOW_EXPOSED:
      markWindowDirty(pgui, e.window.windowID)

    elif e.`type` == sdl.EVENT_WINDOW_RESIZED or e.`type` == sdl.EVENT_WINDOW_PIXEL_SIZE_CHANGED:
      let windowID = e.window.windowID
      markWindowDirty(pgui, windowID)
      let cw = e.window.data1
      let ch = e.window.data2
      pgui.windows[windowID].rootElem.w_value = cw
      pgui.windows[windowID].rootElem.h_value = ch

    elif e.`type` == sdl.EVENT_WINDOW_MAXIMIZED or e.`type` == sdl.EVENT_WINDOW_RESTORED:
      markWindowDirty(pgui, e.window.windowID)

    elif e.`type` == sdl.EVENT_WINDOW_MOVED:
      discard

#--------------------------------------------
# dirty marking
#--------------------------------------------

proc markWindowDirty(pgui:Pgui, windowID:uint32)=
  ## flags a window for redraw. Falls back to the active window when SDL
  ## does not name one (windowID == 0 or an unknown id).
  if pgui == nil:
    return
  var id = windowID
  if id == 0 or not pgui.windows.hasKey(id):
    id = pgui.currentWindowId
  if pgui.windows.hasKey(id):
    pgui.windows[id].redrawFlag = true

proc markElemWindowDirty(elem:DivRef)=
  ## flags the window owning the touched element.
  if elem != nil and elem.window != nil:
    elem.window.redrawFlag = true

