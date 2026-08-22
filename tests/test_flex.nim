import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui
import piigui/[types, style, simple, hidevents]
import piigui/layout/flex
import piigui/layout/vhbox

import piigui/ui/[dosbtn, atogglebtn, label]

import random
import tables
import os
import std/monotimes

###########################################

const
  minButtonSize = 30
  maxButtonSize = 90
  demoButtonCount = 8

###########################################

var gui = newSimpleGui()
gui.rootElem.setPadding(10)
gui.rootElem.setBackGroundColor(0x404040FF.HexColor)

# styles ..........................
defaultSST["lightgray"] = newStyleSheet()
defaultSST["lightgray"].backGroundColor = (r:210, g:210, b:210, a:255)

defaultSST["tabbar"] = newStyleSheet()
defaultSST["tabbar"].backGroundColor = (r:120, g:140, b:160, a:255)

defaultSST["contentbox"] = newStyleSheet()
defaultSST["contentbox"].backGroundColor = (r:240, g:240, b:240, a:255)

defaultSST["tabbtn"] = newStyleSheet()
defaultSST["tabbtn"].setBackGroundColor(0xcceeffff.HexColor)
defaultSST["tabbtn"].setColor(0x00334dff.HexColor)
defaultSST["tabbtn"].setBorderColor(0x0099e6ff.HexColor)
defaultSST["tabbtn"].addNewPseudoStyle("hover")
defaultSST["tabbtn"].pseudoStyles["hover"].backGroundColor = (r:0, g:230, b:191, a:255)

defaultSST["demobtn"] = newStyleSheet()
defaultSST["demobtn"].backGroundColor = (r:120, g:120, b:120, a:255)
defaultSST["demobtn"].color = (r:0, g:0, b:0, a:255)

# sections ..........................
let header = flexRow(gui.rootElem, 0, "header", "", "100%", "10%", ["lightgray"])
let tabs1 = flexRow(gui.rootElem, 0, "tabs1", "", "100%", "10%", ["tabbar"])
let tabs2 = flexRow(gui.rootElem, 0, "tabs2", "", "100%", "10%", ["tabbar"])
let content = flexColumn(gui.rootElem, 0, "content", "", "100%", "60%", ["contentbox"])
let footer = flexRow(gui.rootElem, 0, "footer", "", "100%", "10%", ["lightgray"])

# header title .....................
let titleLabel = header.newLabel(name = "titleLabel", width = "100%", height = "100%")
titleLabel.value = "flex.nim demo: alignItems"
titleLabel.setColor(0x222222FF.HexColor)

# tabs1: choose which flex proc to demo .....................
tabs1.setPadding(5)
let tab1ColBtn = tabs1.newAToggleBtn(
  name = "tab1ColBtn", group = "tabbtn", width = "50%", height = "100%",
  text = "postProcessColumn")
let tab1RowBtn = tabs1.newAToggleBtn(
  name = "tab1RowBtn", group = "tabbtn", width = "50%", height = "100%",
  text = "postProcessRow")

# tabs2: choose the alignItems case .....................
tabs2.setPadding(5)
let tab2StartBtn = tabs2.newAToggleBtn(
  name = "tab2StartBtn", group = "tabbtn", width = "25%", height = "100%",
  text = "faiStart")
let tab2EndBtn = tabs2.newAToggleBtn(
  name = "tab2EndBtn", group = "tabbtn", width = "25%", height = "100%",
  text = "faiEnd")
let tab2CenterBtn = tabs2.newAToggleBtn(
  name = "tab2CenterBtn", group = "tabbtn", width = "25%", height = "100%",
  text = "faiCenter")
let tab2StretchBtn = tabs2.newAToggleBtn(
  name = "tab2StretchBtn", group = "tabbtn", width = "25%", height = "100%",
  text = "faiStretch")

# footer .....................
let quitBtn = footer.newDosBtn(
  name = "quitBtn", group = "tabbtn", width = "25%", height = "100%",
  text = "quit", shadowSizePx = 3)

proc quitBtnonClick(this: DivRef) =
  var sdlevent: sdl.Event
  sdlevent.kind = sdl.QuitEvent
  discard sdl.pushEvent(sdlevent.addr)
  echo "quitBtnonClick"

quitBtn.addEventListener("click", quitBtnonClick)

###########################################
# demo content builders ...................

const
  caseNames = ["faiStart", "faiEnd", "faiCenter", "faiStretch"]
  caseKinds: array[4, FlexAlignItemsKind] = [faiStart, faiEnd, faiCenter, faiStretch]
  modeNames = ["col", "row"]

randomize()

proc applyRandomColor(btn: DosBtn) =
  let col: HexColor = ((rand(0xFFFFFF).uint32) shl 8) or 0xFF'u32
  btn.setBackGroundColor(col)
  let txt = buttonTextColor(btn.style.backGroundColor)
  btn.setColor(txt.r, txt.g, txt.b, 255)

let tabContentBox = gui.activeWindow.newRoot()

# demoContainers[mode][caseIdx]
var demoContainers: array[2, array[4, DivRef]]

for mode in 0 .. 1:
  for caseIdx in 0 .. 3:
    let name = "tabContent_" & caseNames[caseIdx] & "_" & modeNames[mode]
    var c: DivRef
    if mode == 0:
      c = flexColumn(tabContentBox, 0, name, "tabContent", "100%", "100%")
    else:
      c = flexRow(tabContentBox, 0, name, "tabContent", "100%", "100%")

    c.inlineStyle.alignItems = caseKinds[caseIdx]
    c.setBackGroundColor(0xF4F4F4FF.HexColor)

    for i in 0 ..< demoButtonCount:
      let w = $(minButtonSize + rand(maxButtonSize - minButtonSize + 1)) & "px"
      let h = $(minButtonSize + rand(maxButtonSize - minButtonSize + 1)) & "px"
      let btn = c.newDosBtn(
        name = name & "_btn" & $i,
        width = w, height = h, styles = ["demobtn"], text = $i)
      applyRandomColor(btn)

    demoContainers[mode][caseIdx] = c

###########################################
# tab switching ...................

var
  currentMode = 0
  currentCase = 2 # faiCenter

proc switchContent() =
  content.layers[0].elems.setLen(0)
  piigui.copyElem(demoContainers[currentMode][currentCase], content, 0)

proc onTabs1Click(source: DivRef) =
  case source.name:
    of "tab1ColBtn":
      currentMode = 0
      tab1RowBtn.onBlur(tab1RowBtn)
    of "tab1RowBtn":
      currentMode = 1
      tab1ColBtn.onBlur(tab1ColBtn)
    else: discard
  switchContent()

proc onTabs2Click(source: DivRef) =
  case source.name:
    of "tab2StartBtn": currentCase = 0
    of "tab2EndBtn": currentCase = 1
    of "tab2CenterBtn": currentCase = 2
    of "tab2StretchBtn": currentCase = 3
    else: discard
  for b in [tab2StartBtn, tab2EndBtn, tab2CenterBtn, tab2StretchBtn]:
    if b.name != source.name: b.onBlur(b)
  switchContent()

tab1ColBtn.addEventListener("click", onTabs1Click)
tab1RowBtn.addEventListener("click", onTabs1Click)
tab2StartBtn.addEventListener("click", onTabs2Click)
tab2EndBtn.addEventListener("click", onTabs2Click)
tab2CenterBtn.addEventListener("click", onTabs2Click)
tab2StretchBtn.addEventListener("click", onTabs2Click)

###########################################

piigui.copyElem(demoContainers[0][2], content, 0)

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()

echo " ++++++ RECALCED +++++++"

var done: bool = false
while not done:
  let smtick = getMonoTime()

  done = hid_events(gui)

  gui.drawDom(gui.rootElem)
  gui.renderer.present()

  let emtick = getMonoTime()
  var st = emtick.ticks - smtick.ticks
  st = st div 1_000_000
  sleep(16 - st.int)

closeGui(gui)
