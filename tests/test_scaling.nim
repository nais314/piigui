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

#gui.rootElem.inlineStyle.setBackGroundColor(0x55DD55FF.HexColor)



let content = flexColumn(
  gui.rootElem, 0, "content", "", "100%", "70%", ["dark"]
  )
content.inlineStyle.setBackGroundColor(0x55DD55FF.HexColor)

let scaleLabel = content.newLabel(val="1.0", width="25%", height="20px")
#..........................


let plusBtn = content.newDosBtn(width="150px", height="150px", text="+")
proc plusBtnClick(this:DivRef)=
  this.window.scale += 0.125
  this.redrawFlag = 1
  gui.rootElem.recalcDOM()
  gui.rootElem.refreshTextureCache()
  scaleLabel.setText($this.window.scale)
  gui.rootElem.recalcDOM()
plusBtn.addEventListener("click", plusBtnClick)
plusBtn.inlineStyle.setBackGroundColor(0xccDDDDFF.HexColor)
#..........................


let minusBtn = content.newDosBtn(width="15%", height="15%", text="-")
proc minusBtnClick(this:DivRef)=
  this.window.scale -= 0.125
  this.redrawFlag = 1
  gui.rootElem.recalcDOM()
  gui.rootElem.refreshTextureCache()
  scaleLabel.setText($this.window.scale)
  gui.rootElem.recalcDOM()
minusBtn.addEventListener("click", minusBtnClick)    
#__________________________


#..........................
let quitBtn = content.newDosBtn(width="6%", height="6%", text="quit")
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