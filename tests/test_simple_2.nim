import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases,
  std/monotimes, os, tables

import piigui
import piigui/[types, style, simple, hidevents]

import piigui/ui/[label, dosbtn, atogglebtn, gradbtn]

###########################################################



var pgui = newSimpleGui()
pgui.rootElem.setPadding(10)
pgui.rootElem.inlineStyle.alignContent = facCenter

let quitBtn = pgui.rootElem.newDosBtn(width="25%", height="25%", text="quit")
quitBtn.inlineStyle.setBackGroundColor(0xDDDDDDFF.HexColor)

proc quitBtnonClick(this:DivRef)=
  var sdlevent: sdl.Event
  sdlevent.`type` = sdl.EVENT_QUIT
  discard sdl.pushEvent(sdlevent)
  echo "quitBtnonClick"
quitBtn.addEventListener("click", quitBtnonClick)



###########################################################

pgui.rootElem.recalcStyle(true)
pgui.rootElem.recalcDOM()


var done:bool=false
while not done:
  let startTime = getMonoTime() # FPS capping

  done = pgui.hid_events()
  pgui.runTimedEvents()

  pgui.drawWindows() #* includes renderer.present()

  # FPS capping
  let endTime = getMonoTime()
  var elapsedTime = endTime.ticks - startTime.ticks
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(pgui)
