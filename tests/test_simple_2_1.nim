import
  sdl3 as sdl,
  sdl3_ttf as ttf,
  piigui/sdl3_aliases,
  std/monotimes, os, tables

import piigui
import piigui/[types, style, simple, hidevents]

import piigui/ui/[label, dosbtn, atogglebtn, gradbtn, monotextbox]

###########################################################



var pgui = newSimpleGui()
#pgui.rootElem.setPadding(10)
#pgui.rootElem.inlineStyle.alignContent = facCenter
#.....................



let body = pgui.rootElem.vBox(
  name="body", width="100%", height="100%"
  )
body.setPadding(4)
body.inlineStyle.backGroundColor = rgbaColor(220,220,50,255)
body.inlineStyle.flexGrowFrom = 0
#.....................

let content = body.flexColumn(
  name="content", width="100%", height="auto", styles=[]
  )
content.inlineStyle.flexGrow = 4
content.inlineStyle.backGroundColor = rgbaColor(180,220,180,255)
#.....................

let footer = body.flexRow(
  name="footer", width="100%", height="10%", styles=[]
  )
footer.inlineStyle.alignContent = facSpaceAround
footer.inlineStyle.backGroundColor = rgbaColor(180,140,140,255)

#.....................

let quitBtn = footer.newDosBtn(
  width="auto", height="auto", text="quit")
quitBtn.inlineStyle.setBackGroundColor(0xDDDDDDFF.HexColor)

proc quitBtnonClick(this:DivRef, e:sdl.Event):bool=
  var sdlevent: sdl.Event
  sdlevent.`type` = sdl.EVENT_QUIT
  discard sdl.pushEvent(sdlevent)
  echo "quitBtnonClick"
  return true
quitBtn.addEventListener("click", quitBtnonClick)
#.....................





let textinput1 = content.newMonoTextBox(val="Test Text", name="textinput1", width="50%", height="24px")
textinput1.setBackGroundColor(220,220,220,255)


###########################################################

pgui.rootElem.recalcStyle(true)
pgui.rootElem.recalcDOM()

#*#############################################
#!        ---== MAIN LOOP AHEAD ==---
#*#############################################
var done:bool=false
while not done:
  let nowNs = getMonoTime().ticks # FPS capping

  done = pgui.hid_events()
  pgui.runTimedEvents(nowNs)

  pgui.drawWindows() #* includes renderer.present()

  # FPS capping
  let endNs = getMonoTime().ticks
  var elapsedTime = endNs - nowNs
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(pgui)
