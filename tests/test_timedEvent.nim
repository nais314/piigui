import
  sdl2 as sdl,
  sdl2/image as img,
  sdl2/gfx,
  sdl2/ttf

import piigui
import piigui/[types, style, simple, hidevents]
import piigui/ui/dosbtn

import os
import tables
import std/monotimes


var gui = newSimpleGui(
  "timed event test",
  windowW = 800,
  windowH = 600)

gui.rootElem.setBackGroundColor(0x6B859C.HexColor)
# For a column, alignContent centers the column horizontally; justifyContent
# centers its contents vertically.
gui.rootElem.inlineStyle.alignContent = facCenter
gui.rootElem.inlineStyle.justifyContent = fjcCenter

rootSSRT["blinkBtn"] = newStyleSheet()
rootSSRT["blinkBtn"].setBackGroundColor(0x2266CCFF.HexColor)
rootSSRT["blinkBtn"].setColor(0xFFFFFFFF.HexColor)
rootSSRT["blinkBtn"].addNewPseudoStyle("blink")
rootSSRT["blinkBtn"].pseudoStyles["blink"].setBackGroundColor(0xCC2222FF.HexColor)
rootSSRT["blinkBtn"].pseudoStyles["blink"].setColor(0xFFFFFFFF.HexColor)

let blinkBtn = gui.rootElem.newDosBtn(
  name = "blinkBtn",
  width = "240px",
  height = "64px",
  styles = ["blinkBtn"],
  text = "BLINK")

proc blink(this: DivRef) =
  if this.activeStyle == "default":
    this.setActiveStyle("blink")
  else:
    this.setDefaultStyle()

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()
gui.addTimedEvent(blinkBtn, 500, blink)

var done = false
while not done:
  let smtick = getMonoTime()

  done = gui.hid_events()
  gui.runTimedEvents()

  gui.drawDom(gui.rootElem)
  gui.renderer.present()

  let emtick = getMonoTime()
  let st = (emtick.ticks - smtick.ticks) div 1_000_000
  sleep(max(0, 16 - st.int))

closeGui(gui)
