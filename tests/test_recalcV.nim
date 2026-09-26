import
  sdl3 as sdl,
  sdl3_ttf as ttf

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

var gui = newSimpleGui("recalcV test", windowW = 800, windowH = 600)

gui.rootElem.setPadding(10)
gui.rootElem.setBackGroundColor(0x404040FF.HexColor)

rootSSRT["lightgray"] = newStyleSheet()
rootSSRT["lightgray"].backGroundColor = (r:210, g:210, b:210, a:255)

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
# a row with two columns:
#   col1 - a plain column() (recalcV). Content fits -> no scrollbar.
#   col2 - a flexColumn. Content overflows -> vertical scrollbar.
# (a plain column() cannot scroll: recalcV does not report innerW/innerH,
#  so the scrolling column has to be a flexColumn.)

let outerRow = row(gui.rootElem, 0, "outerRow", "", "100%", "55%")
outerRow.setPadding(4)

var quitCandidate: DosBtn = nil

###########################################
# col1 (recalcV): 6 children, 40..45px high each.
#   max 270px of content vs ~300px column content area -> fits.
let col1 = column(outerRow, 0, "col1", "", "49%", "auto")
col1.setPadding(4)
col1.setBackGroundColor(0x505050FF.HexColor)

var col1ContentH = 0
for i in 0 ..< 6:
  let wd = addRandomWidget(col1, col1.name, i, 60, 180, 40, 45)
  col1ContentH += wd.h_value
  if wd of DosBtn and quitCandidate == nil:
    quitCandidate = DosBtn(wd)
echo col1.name, ": children 6, summed height ~", col1ContentH,
     "px (column content area ~300px)"

###########################################
# col2 (flexColumn): 14 children, 40..45px high each.
#   min 560px of content vs ~300px column content area -> overflows.
let col2 = flexColumn(outerRow, 0, "col2", "", "49%", "auto", ["lightgray"])
col2.setPadding(4)

var col2ContentH = 0
for i in 0 ..< 14:
  let wd = addRandomWidget(col2, col2.name, i, 60, 180, 40, 45)
  col2ContentH += wd.h_value
  if wd of DosBtn and quitCandidate == nil:
    quitCandidate = DosBtn(wd)
echo col2.name, ": children 14, summed height ~", col2ContentH,
     "px (column content area ~300px)"

if quitCandidate != nil:
  proc quitOnClick(this: DivRef) =
    var sdlevent: sdl.Event
    sdlevent.`type` = sdl.EVENT_QUIT
    discard sdl.pushEvent(sdlevent)
  quitCandidate.addEventListener("click", quitOnClick)
  echo "quit button: ", quitCandidate.name
else:
  echo "no dosbtn generated, close the window with the X button"

###########################################

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()

echo " ++++++ RECALCED +++++++"
echo "root    innerW/innerH: ", gui.rootElem.innerW, "/", gui.rootElem.innerH,
     " scrollable=", gui.rootElem.scrollable
echo "outerRow innerW/innerH: ", outerRow.innerW, "/", outerRow.innerH,
     " scrollable=", outerRow.scrollable
echo "col1    content ~", col1ContentH, "px, h: ", col1.h,
     " scrollable=", col1.scrollable
echo "col2    innerH: ", col2.innerH, " vs h: ", col2.h,
     " scrollable=", col2.scrollable,
     " vscroll=", (col2.scrollbar != nil and col2.scrollbar.vScroll)

var done: bool = false
while not done:
  let nowNs = getMonoTime().ticks

  done = gui.hid_events()
  gui.runTimedEvents(nowNs)

  gui.drawDom(gui.rootElem)
  discard gui.renderer.present()

  let endNs = getMonoTime().ticks
  var st = endNs - nowNs
  st = st div 1_000_000
  sleep(max(0, 16 - st.int))

closeGui(gui)
