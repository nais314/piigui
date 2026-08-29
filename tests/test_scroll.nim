import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/ttf

import piigui
import piigui/[types, style, simple, hidevents]
import piigui/layout/flex
import piigui/layout/vhbox

import piigui/ui/[dosbtn, label]

import tables
import os
import std/monotimes

###########################################
# optional scrollbar styles (strictly optional:
# without them the parts inherit rootStyle)

defaultSST["scrollbarTrack"] = newStyleSheet()
defaultSST["scrollbarTrack"].backGroundColor = (r:70, g:70, b:70, a:255)

defaultSST["scrollbarSlider"] = newStyleSheet()
defaultSST["scrollbarSlider"].color = (r:200, g:200, b:200, a:255)
defaultSST["scrollbarSlider"].addNewPseudoStyle("hover")
defaultSST["scrollbarSlider"].pseudoStyles["hover"].color = (r:235, g:235, b:235, a:255)
defaultSST["scrollbarSlider"].addNewPseudoStyle("focus")
defaultSST["scrollbarSlider"].pseudoStyles["focus"].color = (r:255, g:220, b:120, a:255)

defaultSST["scrollbarArrow"] = newStyleSheet()
defaultSST["scrollbarArrow"].color = (r:110, g:110, b:110, a:255)
defaultSST["scrollbarArrow"].backGroundColor = (r:215, g:215, b:215, a:255)
defaultSST["scrollbarArrow"].addNewPseudoStyle("hover")
defaultSST["scrollbarArrow"].pseudoStyles["hover"].backGroundColor = (r:255, g:255, b:255, a:255)
defaultSST["scrollbarArrow"].addNewPseudoStyle("focus")
defaultSST["scrollbarArrow"].pseudoStyles["focus"].backGroundColor = (r:170, g:170, b:170, a:255)

###########################################

var gui = newSimpleGui()
gui.rootElem.setPadding(10)
gui.rootElem.setBackGroundColor(0x404040FF.HexColor)

defaultSST["demobtn"] = newStyleSheet()
defaultSST["demobtn"].backGroundColor = (r:120, g:120, b:120, a:255)
defaultSST["demobtn"].color = (r:0, g:0, b:0, a:255)

# vertical scroll test: a bounded column of fixed-height buttons
# ofScroll is the default, so it scrolls automatically on overflow
let scrollCol = flexColumn(gui.rootElem, 0, "scrollCol", "", "60%", "55%", ["demobtn"])
scrollCol.setPadding(4)

for i in 0 ..< 40:
  discard scrollCol.newDosBtn(
    name = "vbtn" & $i,
    width = "100%", height = "36px",
    styles = ["demobtn"], text = "item " & $i)

# horizontal scroll test: BRElem forces a second column -> wider content
let scrollRow = flexRow(gui.rootElem, 0, "scrollRow", "", "100%", "25%", ["demobtn"])
scrollRow.setPadding(4)

for i in 0 ..< 6:
  discard scrollRow.newDosBtn(
    name = "hbtn" & $i,
    width = "120px", height = "60%",
    styles = ["demobtn"], text = "col" & $i)
let br = new BRElem
br.parent = scrollRow
br.pgui = gui
scrollRow.layers[0].elems.add(br)
scrollRow.layers[0].renumberNthChild()
for i in 6 ..< 12:
  discard scrollRow.newDosBtn(
    name = "hbtn" & $i,
    width = "120px", height = "60%",
    styles = ["demobtn"], text = "col" & $i)

# clip test: ofHidden disables the scrollbar, extra parts are clipped away
let clipCol = flexColumn(gui.rootElem, 0, "clipCol", "", "100%", "12%", ["demobtn"])
clipCol.inlineStyle.overFlow = ofHidden
clipCol.setPadding(4)
for i in 0 ..< 10:
  discard clipCol.newDosBtn(
    name = "clipbtn" & $i,
    width = "100%", height = "24px",
    styles = ["demobtn"], text = "clip " & $i)

let quitBtn = flexRow(gui.rootElem, 0, "quitRow", "", "100%", "8%")
let quit = quitBtn.newDosBtn(
  name = "quitBtn", width = "25%", height = "100%",
  text = "quit", shadowSizePx = 3)
proc quitBtnonClick(this: DivRef) =
  var sdlevent: sdl.Event
  sdlevent.kind = sdl.QuitEvent
  discard sdl.pushEvent(sdlevent.addr)
quit.addEventListener("click", quitBtnonClick)

###########################################

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()

echo " ++++++ RECALCED +++++++"
echo "scrollCol innerH: ", scrollCol.innerH, " vs h: ", scrollCol.h, " scrollable=", scrollCol.scrollable
echo "scrollRow innerW: ", scrollRow.innerW, " vs w: ", scrollRow.w, " scrollable=", scrollRow.scrollable
echo "clipCol   innerH: ", clipCol.innerH, " vs h: ", clipCol.h, " scrollable=", clipCol.scrollable

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
