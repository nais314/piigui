import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf,
  std.monotimes, os, tables

import piigui
import piigui/[types, style, simple, hidevents]

import piigui/ui/[label, dosbtn, atogglebtn, gradbtn]

###########################################################



var gui = newSimpleGui()
gui.rootElem.setPadding(10)
gui.rootElem.inlineStyle.alignContent = facCenter

let quitBtn = gui.rootElem.newDosBtn(width="25%", height="25%", text="quit")
quitBtn.inlineStyle.setBackGroundColor(0xDDDDDDFF.HexColor)

proc quitBtnonClick(this:DivRef)=
  var sdlevent: sdl.Event
  sdlevent.kind = sdl.QuitEvent
  discard sdl.pushEvent(sdlevent.addr)
  echo "quitBtnonClick"
quitBtn.addEventListener("click", quitBtnonClick)



###########################################################

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()


var done:bool=false
while not done:
  let startTime = getMonoTime() # FPS capping

  done = gui.hid_events()
  gui.runTimedEvents()

  gui.drawDom(gui.rootElem)
  gui.renderer.present()

  # FPS capping
  let endTime = getMonoTime()
  var elapsedTime = endTime.ticks - startTime.ticks
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(gui)