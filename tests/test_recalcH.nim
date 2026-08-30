import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui
import piigui/[types, style, simple, hidevents]
import piigui/layout/flex
import piigui/layout/recalcH as recalcHMod
import piigui/layout/recalcV as recalcVMod

import piigui/ui/[dosbtn, gradbtn, label]

import random
import tables
import os
import std/monotimes

###########################################
# 800x600 window.

var gui = newSimpleGui("recalcH test", windowW = 800, windowH = 600)

gui.rootElem.setPadding(10)
gui.rootElem.setBackGroundColor(0x404040FF.HexColor)

defaultSST["lightgray"] = newStyleSheet()
defaultSST["lightgray"].backGroundColor = (r:210, g:210, b:210, a:255)

randomize()

proc randColor(): HexColor =
  ((rand(0xFFFFFF).uint32) shl 8) or 0xFF'u32

proc addRandomWidget(parent: DivRef, baseName: string, idx: int,
                     minW, maxW, minH, maxH: int): DivRef =
  ## adds a random dosbtn / gradbtn / label with random size and color
  let
    w = minW + rand(maxW - minW + 1)
    h = minH + rand(maxH - minH + 1)
    name = baseName & "_" & $idx
  case rand(2):
    of 0:
      let b = parent.newDosBtn(
        name = name, width = $w & "px", height = $h & "px", text = name)
      b.setBackGroundColor(randColor())
      result = b
    of 1:
      let g = parent.newGradBtn(
        name = name, width = $w & "px", height = $h & "px", text = name)
      g.setBackGroundColor(randColor())
      result = g
    else:
      let l = parent.newLabel(
        name = name, width = $w & "px", height = $h & "px")
      l.value = name
      l.setBackGroundColor(randColor())
      result = l

###########################################
# 1) three recalcH rows directly on the root.
#    their children must stay within availW (780px),
#    so nothing overflows and no scrollbar appears.
const availW = 780

var quitCandidate: DosBtn = nil
for i in 0 ..< 3:
  let r = row(gui.rootElem, 0, "row" & $i, "", "auto", "70px")
  r.setPadding(4)

  var used = 0
  var idx = 0
  while idx < 6:
    let w = 60 + rand(81) # 60..140
    if used + w > availW - 40: break # keep the row within availW
    used += w
    let wd = addRandomWidget(r, r.name, idx, 60, 140, 40, 70)
    if wd of DosBtn and quitCandidate == nil:
      quitCandidate = DosBtn(wd)
    inc idx
  echo r.name, ": children ", idx, ", summed width ~", used, "px (availW ", availW, ")"

###########################################
# 2) table1 (flexColumn, ofScroll is the default),
#    filled with recalcH rows that are wider than the
#    container -> horizontal scrollbar is created.
let table1 = flexColumn(gui.rootElem, 0, "table1", "", "90%", "58%", ["lightgray"])
table1.setPadding(4)

let nRows = 5 + rand(3) # 5..7 rows
for i in 0 ..< nRows:
  let rowW = 800 + rand(401) # 800..1200 px
  let r = row(table1, 0, "trow" & $i, "", $rowW & "px", "40px")
  r.setPadding(2)

  var used = 0
  var idx = 0
  while idx < 12:
    let w = 60 + rand(121) # 60..180
    if used + w > rowW - 20: break
    used += w
    let wd = addRandomWidget(r, r.name, idx, 60, 180, 24, 40)
    if wd of DosBtn and quitCandidate == nil:
      quitCandidate = DosBtn(wd)
    inc idx
  echo r.name, ": row width ", rowW, "px, children ", idx, ", summed width ~", used

if quitCandidate != nil:
  proc quitOnClick(this: DivRef) =
    var sdlevent: sdl.Event
    sdlevent.kind = sdl.QuitEvent
    discard sdl.pushEvent(sdlevent.addr)
  quitCandidate.addEventListener("click", quitOnClick)
  echo "quit button: ", quitCandidate.name
else:
  echo "no dosbtn generated, close the window with the X button"

###########################################

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()

echo " ++++++ RECALCED +++++++"
echo "root  innerW/innerH: ", gui.rootElem.innerW, "/", gui.rootElem.innerH,
     " scrollable=", gui.rootElem.scrollable
echo "table1 innerW: ", table1.innerW, " vs w: ", table1.w,
     " innerH: ", table1.innerH, " vs h: ", table1.h,
     " scrollable=", table1.scrollable,
     " hscroll=", (table1.scrollbar != nil and table1.scrollbar.hScroll)

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
