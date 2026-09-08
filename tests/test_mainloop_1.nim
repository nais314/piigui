import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf,
  std.monotimes, os, tables

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






defaultSST["mid"] = newStyleSheet()
defaultSST["mid"].backGroundColor = (r:186,g:186,b:175,a:255)

defaultSST["light"] = newStyleSheet()
defaultSST["light"].backGroundColor = lighten(defaultSST["mid"].backGroundColor)

defaultSST["dark"] = newStyleSheet()
defaultSST["dark"].backGroundColor = darken(defaultSST["mid"].backGroundColor)



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
defaultSST["footBtn"] = newStyleSheet()
defaultSST["footBtn"].backGroundColor = lighten(defaultSST["mid"].backGroundColor)
proc quitBtnonClick(this:DivRef)=
  var sdlevent: sdl.Event
  sdlevent.kind = sdl.QuitEvent
  discard sdl.pushEvent(sdlevent.addr)
  echo "quitBtnonClick"
quitBtn.addEventListener("click", quitBtnonClick)
#.....................


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
