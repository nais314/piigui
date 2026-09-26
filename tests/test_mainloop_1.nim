import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  std/monotimes, os, tables,
  piigui/sdl3_aliases

import piigui
import piigui/[types, style, simple, hidevents]

import piigui/ui/[label, dosbtn, atogglebtn, gradbtn]

import piigui/app/intercom


###########################################################

##      ____INIT____

var gui = newSimpleGui(
  "gui event test",
  windowW = 800,
  windowH = 600)






rootSSRT["mid"] = newStyleSheet()
rootSSRT["mid"].backGroundColor = (r:186,g:186,b:175,a:255)

rootSSRT["light"] = newStyleSheet()
rootSSRT["light"].backGroundColor = lighten(rootSSRT["mid"].backGroundColor)

rootSSRT["dark"] = newStyleSheet()
rootSSRT["dark"].backGroundColor = darken(rootSSRT["mid"].backGroundColor)



# ____frame structure_____
let header = row(
  parent = gui.rootElem,
  layer = 0,
  name = "header",
  group = "",
  width = "100%",
  height = "10%",
  styles = ["mid"]
  )
#.....................

let content = flexColumn(
  gui.rootElem, 0, "content", "", "100%", "80%", ["dark"]
  )
#.....................
let footer = flexRow(
  gui.rootElem, 0, "footer", "", "100%", "10%", ["mid"]
  )
footer.setPadding(4)


let leftFooter = footer.flexRow(name = "leftFooter", width = "50%")
let rightFooter = footer.flexRow(name = "rightFooter", width = "50%")

leftFooter.inlineStyle.justifyContent = fjcStart
rightFooter.inlineStyle.justifyContent = fjcEnd

discard leftFooter.newDosBtn(group="footBtn", width="25%", height="100%", text="nothing",shadowSizePx=0)
let quitBtn = rightFooter.newDosBtn(group="footBtn", width="25%", text="quit",shadowSizePx=0)
rootSSRT["footBtn"] = newStyleSheet()
rootSSRT["footBtn"].backGroundColor = lighten(rootSSRT["mid"].backGroundColor)
proc quitBtnonClick(this:DivRef, e:sdl.Event):bool=
  var sdlevent: sdl.Event
  sdlevent.`type` = sdl.EVENT_QUIT
  discard sdl.pushEvent(sdlevent)
  echo "quitBtnonClick"
  return true
quitBtn.addEventListener("click", quitBtnonClick)
#.....................


gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()


var done:bool=false
while not done:
  let nowNs = getMonoTime().ticks # FPS capping

  done = gui.hid_events()
  gui.runTimedEvents(nowNs)

  gui.drawDom(gui.rootElem)
  discard gui.renderer.present()

  # FPS capping
  let endNs = getMonoTime().ticks
  var elapsedTime = endNs - nowNs
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(gui)
