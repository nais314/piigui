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

#pgui.rootElem.inlineStyle.setBackGroundColor(0x55DD55FF.HexColor)



let content = flexColumn(
  pgui.rootElem, 0, "content", "", "100%", "70%", ["dark"]
  )
content.inlineStyle.setBackGroundColor(0x55DD55FF.HexColor)

let scaleLabel = content.newLabel(val="1.0", width="150px", height="20px")
scaleLabel.inlineStyle.setBackGroundColor(0x99aa99FF.HexColor)

#..........................


let plusBtn = content.newDosBtn(width="150px", height="150px", text="+")
proc plusBtnClick(this:DivRef, e:sdl.Event):bool=
  this.window.scale += 0.125

  scaleLabel.setText($this.window.scale)
  pgui.rootElem.recalcDOM()
  
  for fontObj in pgui.fonts:
    let newSize = max(2, (fontObj.ptsize.float * this.window.scale).int).cint
    let newFont = fontObj.loader(newSize)
    if newFont != nil:
      if fontObj.fontPtr != nil: ttf.closeFont(fontObj.fontPtr)
      fontObj.fontPtr = newFont

  return true
plusBtn.addEventListener("click", plusBtnClick)
plusBtn.inlineStyle.setBackGroundColor(0xccDDDDFF.HexColor)
#..........................


let minusBtn = content.newDosBtn(width="15%", height="15%", text="-")
proc minusBtnClick(this:DivRef, e:sdl.Event):bool=
  this.window.scale -= 0.125

  scaleLabel.setText($this.window.scale)
  pgui.rootElem.recalcDOM()
  return true
minusBtn.addEventListener("click", minusBtnClick)    
#__________________________


#..........................
let quitBtn = content.newDosBtn(width="6%", height="6%", text="quit")
quitBtn.inlineStyle.setBackGroundColor(0xDDDDDDFF.HexColor)

proc quitBtnonClick(this:DivRef, e:sdl.Event):bool=
  var sdlevent: sdl.Event
  sdlevent.`type` = sdl.EVENT_QUIT
  discard sdl.pushEvent(sdlevent)
  echo "quitBtnonClick"
  return true
quitBtn.addEventListener("click", quitBtnonClick)



###########################################################

pgui.rootElem.recalcStyle(true)
pgui.rootElem.recalcDOM()


var done:bool=false
while not done:
  let nowNs = getMonoTime().ticks # FPS capping

  done = pgui.hid_events()
  pgui.runTimedEvents(nowNs)

  pgui.drawDom(pgui.rootElem)
  discard pgui.renderer.present()

  # FPS capping
  let endNs = getMonoTime().ticks
  var elapsedTime = endNs - nowNs
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(pgui)