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
proc plusBtnClick(this:DivRef)=
  this.window.scale += 0.125

  scaleLabel.setText($this.window.scale)
  pgui.rootElem.recalcDOM()
  
  for fontObj in pgui.fonts:
    let newSize = max(2, (fontObj.ptsize.float * this.window.scale).int).cint
    let newFont = fontObj.loader(newSize)
    if newFont != nil:
      if fontObj.fontPtr != nil: ttf.close(fontObj.fontPtr)
      fontObj.fontPtr = newFont

plusBtn.addEventListener("click", plusBtnClick)
plusBtn.inlineStyle.setBackGroundColor(0xccDDDDFF.HexColor)
#..........................


let minusBtn = content.newDosBtn(width="15%", height="15%", text="-")
proc minusBtnClick(this:DivRef)=
  this.window.scale -= 0.125

  scaleLabel.setText($this.window.scale)
  pgui.rootElem.recalcDOM()
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

pgui.rootElem.recalcStyle(true)
pgui.rootElem.recalcDOM()


var done:bool=false
while not done:
  let startTime = getMonoTime() # FPS capping

  done = pgui.hid_events()
  pgui.runTimedEvents()

  pgui.drawDom(pgui.rootElem)
  pgui.renderer.present()

  # FPS capping
  let endTime = getMonoTime()
  var elapsedTime = endTime.ticks - startTime.ticks
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(pgui)