## Variant of tests/test_9slice.nim that uses the importable NineBtn widget
## from piigui/ui/ninegrid/btn9 instead of an inline copy. Four buttons show
## the style-driven tint, the invert fallback on press, and explicit
## :hover / :active pseudo-styles. Run from the repository root.

import
  sdl3 as sdl,
  piigui/sdl3_aliases
import piigui
import piigui/[types, style, hidevents]
import std/[monotimes, os]
import tables

import piigui/simple
import piigui/ui/[dosbtn]
import piigui/ui/ninegrid/btn9

###########################################################

const
  NineSliceTint = sdl.Color((r: 91'u8, g: 84'u8, b: 146'u8, a: 255'u8))
  NineSliceW = "220px"
  NineSliceH = "64px"

###########################################################

var gui = newSimpleGui()
gui.rootElem.setPadding(10)
gui.rootElem.inlineStyle.alignContent = facCenter

loadNineBtnTextures(gui.renderer)

# "dark" version: the original fixed tint, now supplied through the style system
let nineBtn = gui.rootElem.newNineBtn(
  name = "nineDarkButton",
  width = NineSliceW,
  height = NineSliceH)
nineBtn.text = "dark"
nineBtn.setBackGroundColor(NineSliceTint)

# no explicit color: inherits the root background; press inverts the fallback
let nineBtnNoStyle = gui.rootElem.newNineBtn(
  name = "nineNoStyleButton",
  width = NineSliceW,
  height = NineSliceH)
nineBtnNoStyle.text = "no style"

# warm sand (#CBBD93)
let nineBtnSand = gui.rootElem.newNineBtn(
  name = "nineSandButton",
  width = NineSliceW,
  height = NineSliceH)
nineBtnSand.text = "warm sand"
nineBtnSand.inlineStyle.setBackGroundColor(0xCBBD93FF.HexColor)

# sky blue (#87CEEB) with explicit :hover / :active pseudo-styles
let nineBtnSky = gui.rootElem.newNineBtn(
  name = "nineSkyButton",
  width = NineSliceW,
  height = NineSliceH)
nineBtnSky.text = "sky blue"
nineBtnSky.inlineStyle.setBackGroundColor(0x87CEEBFF.HexColor)
nineBtnSky.inlineStyle.addNewPseudoStyle("hover")
nineBtnSky.inlineStyle.pseudoStyles["hover"].setBackGroundColor(0xCFEB87FF.HexColor)
nineBtnSky.inlineStyle.addNewPseudoStyle("active")
nineBtnSky.inlineStyle.pseudoStyles["active"].setBackGroundColor(0xEBA387FF.HexColor)
nineBtnSky.recalcStyle()

let quitBtn = gui.rootElem.newDosBtn(width="25%", height="25%", text="quit")
quitBtn.inlineStyle.setBackGroundColor(0xDDDDDDFF.HexColor)

proc quitBtnonClick(this:DivRef, e:sdl.Event):bool=
  var sdlevent: sdl.Event
  sdlevent.`type` = sdl.EVENT_QUIT
  discard sdl.pushEvent(sdlevent)
  echo "quitBtnonClick"
  return true
quitBtn.addEventListener("click", quitBtnonClick)

###########################################################

gui.rootElem.recalcStyle(true)
gui.rootElem.recalcDOM()

var done:bool=false
while not done:
  let nowNs = getMonoTime().ticks # FPS capping

  done = gui.hid_events()
  gui.runTimedEvents(nowNs)

  gui.drawDom(gui.rootElem)
  discard gui.renderer.present()

  # FPS capping
  let endNs = getMonoTime().ticks
  var elapsedTime = endNs - nowNs
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  sleep(max(0, 16 - elapsedTime.int))

# release the shared 9-slice layers before closeGui tears down the renderer
freeNineBtnTextures()

closeGui(gui)
