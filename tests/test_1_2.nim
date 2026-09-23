import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui
import piigui/[types,style, simple, hidevents]
import piigui/layout/flex
import piigui/layout/recalcH
import piigui/layout/recalcV

import piigui/ui/[label, dosbtn, atogglebtn, gradbtn]


###########################################

import random
import tables
import times
import os
import unicode

###########################################
#TODO: toggle button not active at start

var gui = newSimpleGui()
gui.rootElem.setPadding(10)
gui.rootElem.setBackGroundColor(0x808080FF.HexColor)


rootSSRT["white"] = newStyleSheet()
rootSSRT["white"].backGroundColor = (r:255,g:255,b:255,a:255)

rootSSRT["lightgray"] = newStyleSheet()
rootSSRT["lightgray"].backGroundColor = (r:210,g:210,b:210,a:255)


rootSSRT["tabbtn"] = newStyleSheet()
rootSSRT["tabbtn"].setBackGroundColor(0xcceeffff.HexColor)
rootSSRT["tabbtn"].setColor(0x00334dff.HexColor)
rootSSRT["tabbtn"].setBorderColor(0x0099e6ff.HexColor)

rootSSRT["tabbtn"].addPseudoStyle(newStyleSheet(), "hover")
rootSSRT["tabbtn"].pseudoStyles["hover"].backGroundColor = (r:0, g:230, b:191, a:255)


rootSSRT["DosBtn"] = newStyleSheet()
rootSSRT["DosBtn"].setBackGroundColor(0xff9900ff.HexColor)
rootSSRT["DosBtn"].setColor(0x331f00ff.HexColor)
rootSSRT["DosBtn"].setBorderColor(0x0099e6ff.HexColor)

rootSSRT["DosBtn"].addNewPseudoStyle("hover")
rootSSRT["DosBtn"].pseudoStyles["hover"].backGroundColor = (r:0, g:230, b:191, a:255)


# frame structure .......................
let header = row(
  parent = gui.rootElem,
  layer = 0,
  name = "header",
  group = "",
  width = "100%",
  height = "10%",
  styles = ["lightgray"]
  )
#.....................

let content = flexColumn(
  gui.rootElem, 0, "content", "", "100%", "80%", ["white"]
  )
#.....................
let footer = flexRow(
  gui.rootElem, 0, "footer", "", "100%", "10%", ["lightgray"]
  )
footer.setPadding(2)

#[ let leftFooter = footer.flexRow(name="leftFooter", width="50%")
let rightFooter = footer.flexRow(name="rightFooter")
 ]#
let leftFooter = footer.flexRow(name = "leftFooter", width = "50%")
let rightFooter = footer.flexRow(name = "rightFooter", width = "50%")

leftFooter.inlineStyle.justifyContent = fjcStart
rightFooter.inlineStyle.justifyContent = fjcEnd

discard leftFooter.newDosBtn(group="footBtn", width="25%", height="100%", text="nothing",shadowSizePx=0)
let quitBtn = rightFooter.newDosBtn(group="footBtn", width="25%", text="quit",shadowSizePx=0)

proc quitBtnonClick(this:DivRef)=
  var sdlevent: sdl.Event
  sdlevent.kind = sdl.QuitEvent
  discard sdl.pushEvent(sdlevent.addr)
  echo "quitBtnonClick"
quitBtn.addEventListener("click", quitBtnonClick)
#.....................


# header elems .......................

# tab buttons -----
let tab1Btn = header.newAToggleBtn(
  name="atb1", text="atb1", group="tabbtn")

let tab2Btn = header.newAToggleBtn(
  name="tab2Btn", text="tab2Btn", group="tabbtn")

let tab3Btn = header.newAToggleBtn(
  name="tab3Btn", text="tab3Btn", group="tabbtn")


# tab contents -----
let tabContentBox = gui.activeWindow.newRoot()
#................

let tabContent1 = tabContentBox.column(
  0, "tabContent1", "tabContent", "100%", "100%")
tabContent1.setPadding(4)

let tcbtn1: DosBtn = tabContent1.newDosBtn(
  layer = 0,
  name = "tc1Btn",
  group = "tcBtn",
  width = "45%",
  height = "45%",
  text = "tc1Btn"
  )
rootSSRT["tcBtn"]= newStyleSheet()
rootSSRT["tcBtn"].backGroundColor = (r:0, g:230, b:191, a:255)

rootSSRT["tcBtn"].addPseudoStyle(newStyleSheet(), "hover")
rootSSRT["tcBtn"].pseudoStyles["hover"].backGroundColor = (r:230, g:230, b:0, a:255)
rootSSRT["tcBtn"].pseudoStyles["hover"].color = (r:0, g:0, b:0, a:180)
#.....

let gradbtn1 = tabContent1.newGradBtn(
  layer = 0,
  name = "gradbtn1",
  group = "gradbtn",
  width = "20%",
  height = "15%",
  text = "gradbtn-1")

gradbtn1.setColor(0x99ccffff.uint32)
gradbtn1.setBackGroundColor(0x0080ffff.uint32)
rootSSRT["gradbtn1"]= newStyleSheet()
rootSSRT["gradbtn1"].addNewPseudoStyle("hover")
rootSSRT["gradbtn1"].pseudoStyles["hover"].backGroundColor = (r:230, g:230, b:0, a:255)

#................

let tabContent2 = tabContentBox.column(
          layer = 0,
          name = "tabContent2",
          group = "tabContent",
          width="100%",
          height="100%")

tabContent2.setPadding(4)

let label1 = tabContent2.newLabel(
  layer = 0,
  name = "Label1", width="75%", height = "20%"
)
label1.value = "GOMBAAAAAAA"
rootSSRT["Label1"]= newStyleSheet()
rootSSRT["Label1"].color = (r:230, g:230, b:0, a:255)
rootSSRT["Label1"].backGroundColor = transparentColor
rootSSRT["Label1"].font = 2

rootSSRT["Label1"].addNewPseudoStyle("blink")
rootSSRT["Label1"].pseudoStyles["blink"].color = (r:0, g:0, b:0, a:255)
rootSSRT["Label1"].pseudoStyles["blink"].backGroundColor = (r:0, g:0, b:0, a:0)


proc blink(this: DivRef) =
  if this.activeStyle != "blink":
    this.setActiveStyle("blink")
    #echo "this.setActiveStyle(blink) " & this.activeStyle
  else:
    #this.setDefaultStyle()
    this.setActiveStyle("default")
    #echo "this.setActiveStyle(Label1)" & this.activeStyle

gui.addTimedEvent(label1, 500, blink)

#................


proc switchTab(source:DivRef)=
  if source == tab1Btn:
    tab2Btn.onBlur(tab2Btn)
    tab3Btn.onBlur(tab3Btn)
    content.layers[0].elems.setLen(0)
    piigui.copyElem(tabContent1, content, 0)
  elif source == tab2Btn:
    tab1Btn.onBlur(tab1Btn)
    tab3Btn.onBlur(tab3Btn)
    content.layers[0].elems.setLen(0)
    piigui.copyElem(tabContent2, content, 0)
  elif source == tab3Btn:
    tab2Btn.onBlur(tab2Btn)
    tab1Btn.onBlur(tab1Btn)
    content.layers[0].elems.setLen(0)
    piigui.copyElem(tabContent1, content, 0)


header.elems.addEventListener("click", switchTab)

#................

piigui.copyElem(tabContent1, content, 0)

#........................................


#----------------------------------------

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()

echo " ++++++ RECALCED +++++++"
echo leftFooter.w
echo leftFooter.h
echo leftFooter.x1
echo leftFooter.y1
echo "rightFooter justify: ", rightFooter.style.justifyContent
echo "rightFooter x/w: ", rightFooter.x1, " / ", rightFooter.w
echo "quitBtn x/w: ", quitBtn.x1, " / ", quitBtn.w

import std.monotimes

var done:bool=false
while not done:
  let smtick = getMonoTime()

  done = gui.hid_events()
  gui.runTimedEvents()

  gui.drawDom(gui.rootElem)
  gui.renderer.present()

  let emtick = getMonoTime()
  var st = emtick.ticks - smtick.ticks
  #echo st 
  st = st div 1_000_000
  #echo st 
  sleep(max(0, 16 - st.int))

closeGui(gui)
