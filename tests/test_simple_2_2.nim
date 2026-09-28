## Interactive demo for the mono text box, plus boundary checks for the
## MaxValRunes cap using random valid runes (1-4 byte UTF-8).

import
  sdl3 as sdl,
  std/[monotimes, os, random],
  unicode

import piigui
import piigui/[types, style, simple, hidevents]

import piigui/ui/[dosbtn, monotextbox]

###########################################################
#* random valid runes for the boundary checks
###########################################################

proc randomValidRuneString(count: int): string =
  ## Deterministic mix of 1-4 byte runes so truncation and cursor math are
  ## exercised with real multibyte input.
  const RuneRanges = [
    (0x20'u32, 0x7E'u32),      # ASCII printable
    (0xA0'u32, 0x2FF'u32),     # Latin-1 supplement, Greek, Cyrillic
    (0x4E00'u32, 0x4FFF'u32),  # CJK
    (0x1F300'u32, 0x1F5FF'u32) # emoji
  ]
  var rng = initRand(0xC0FFEE)
  for i in 0 ..< count:
    let runeRange = RuneRanges[rng.rand(RuneRanges.high)]
    let span = (runeRange[1] - runeRange[0]).uint32
    result.add toUTF8(Rune(runeRange[0] + rng.rand(span.int).uint32))

proc sendKey(tb: TextBox, key: sdl.Keycode) =
  ## Feeds a synthetic keydown through the widget's registered listener.
  var e: sdl.Event
  e.`type` = sdl.EVENT_KEY_DOWN
  e.key.key = key
  discard tb.trigger("keydown", e)

###########################################################

var pgui = newSimpleGui()
#pgui.rootElem.setPadding(10)
#pgui.rootElem.inlineStyle.alignContent = facCenter
#.....................

let body = pgui.rootElem.vBox(
  name="body", width="100%", height="100%"
  )
body.setPadding(4)
body.inlineStyle.backGroundColor = rgbaColor(220,220,50,255)
body.inlineStyle.flexGrowFrom = 0
#.....................

let content = body.flexColumn(
  name="content", width="100%", height="auto", styles=[]
  )
content.inlineStyle.flexGrow = 4
content.inlineStyle.backGroundColor = rgbaColor(180,220,180,255)
#.....................

let footer = body.flexRow(
  name="footer", width="100%", height="10%", styles=[]
  )
footer.inlineStyle.alignContent = facSpaceAround
footer.inlineStyle.backGroundColor = rgbaColor(180,140,140,255)

#.....................

let quitBtn = footer.newDosBtn(
  width="auto", height="auto", text="quit")
quitBtn.inlineStyle.setBackGroundColor(0xDDDDDDFF.HexColor)

proc quitBtnonClick(this:DivRef, e:sdl.Event):bool=
  var sdlevent: sdl.Event
  sdlevent.`type` = sdl.EVENT_QUIT
  discard sdl.pushEvent(sdlevent)
  echo "quitBtnonClick"
  return true
quitBtn.addEventListener("click", quitBtnonClick)
#.....................

let textinput1 = content.newMonoTextBox(val="Test Text", name="textinput1", width="50%", height="24px")
textinput1.setBackGroundColor(220,220,220,255)


let textinput2 = content.newMonoTextBox(val="Test textinput2", name="textinput2", width="50%", height="28px")
textinput2.setColor(50,120,255,255)

let textinput3 = content.newMonoTextBox(val="Test textinput3", name="textinput2", width="50%", height="28px")
textinput3.setColor(222,222,255,255)
textinput3.setBackGroundColor(50,50,220,255)

#* long texts, narrow boxes: exercise scroll + cursor tracking
let textinput4 = content.newMonoTextBox(
  val=randomValidRuneString(220), name="textinput4", width="90%", height="28px")
textinput4.setBackGroundColor(240,240,200,255)

let textinput5 = content.newMonoTextBox(
  val="Árvíztűrő tükörfúrógép – Привет мир – 日本語テキスト – 😀🎉🚀 end",
  name="textinput5", width="90%", height="28px")
textinput5.setColor(80,40,10,255)
textinput5.setBackGroundColor(220,220,220,255)

let textinput6 = content.newMonoTextBox(val="", name="textinput6", width="50%", height="28px")
textinput6.setBackGroundColor(230,230,230,255)

#*=============================================
#* MaxValRunes boundary checks (random runes)
#*=============================================
block maxValRunesBoundaryChecks:
  let atMax = randomValidRuneString(MaxValRunes)
  let overMax = randomValidRuneString(MaxValRunes + 1)
  doAssert atMax.runeLen == MaxValRunes
  doAssert overMax.runeLen == MaxValRunes + 1
  doAssert overMax.validateUtf8 == -1

  # constructor truncates an oversized value on a rune boundary
  let capped = content.newMonoTextBox(
    val=overMax, name="capped", width="90%", height="28px")
  doAssert capped.valRuneLen == MaxValRunes
  doAssert capped.val.runeLen == MaxValRunes
  doAssert capped.val.validateUtf8 == -1

  # a full box drops further input
  capped.insertText("X")
  doAssert capped.valRuneLen == MaxValRunes

  # value= truncates and leaves the cursor at the end
  capped.value = overMax
  doAssert capped.valRuneLen == MaxValRunes
  doAssert capped.valCursorPos == MaxValRunes

  # growth clamps exactly at the cap
  let grow = content.newMonoTextBox(
    val=atMax.runeSubStr(0, MaxValRunes - 1), name="grow",
    width="90%", height="28px")
  doAssert grow.valRuneLen == MaxValRunes - 1
  grow.insertText("Z") # cursor starts at 0: prepends one rune
  doAssert grow.valRuneLen == MaxValRunes
  grow.insertText(randomValidRuneString(32))
  doAssert grow.valRuneLen == MaxValRunes
  doAssert grow.val.validateUtf8 == -1

  # key edits keep the rune cache in sync with the byte string
  grow.valCursorPos = 1
  sendKey(grow, sdl.SDLK_BACKSPACE)
  doAssert grow.valRuneLen == MaxValRunes - 1
  doAssert grow.val.runeLen == grow.valRuneLen
  doAssert grow.valCursorPos == 0
  sendKey(grow, sdl.SDLK_DELETE)
  doAssert grow.valRuneLen == MaxValRunes - 2
  doAssert grow.val.runeLen == grow.valRuneLen
  sendKey(grow, sdl.SDLK_END)
  doAssert grow.valCursorPos == grow.valRuneLen
  sendKey(grow, sdl.SDLK_HOME)
  doAssert grow.valCursorPos == 0

  echo "[test_simple_2_2] boundary checks passed: ",
    MaxValRunes, " runes = ", atMax.len, " bytes"

###########################################################

pgui.rootElem.recalcStyle(true)
pgui.rootElem.recalcDOM()

#*=============================================
#* scroll/cursor view checks (need layout width)
#*=============================================
block scrollViewChecks:
  doAssert textinput4.w > 0
  sendKey(textinput4, sdl.SDLK_END)
  doAssert textinput4.maxScreenCursorPos < textinput4.valRuneLen # must scroll
  doAssert textinput4.scrollOffset ==
    max(0, textinput4.valRuneLen - textinput4.maxScreenCursorPos)
  doAssert textinput4.screenCursorPos == textinput4.maxScreenCursorPos
  doAssert textinput4.valCursorPos - textinput4.scrollOffset ==
    textinput4.screenCursorPos

  sendKey(textinput4, sdl.SDLK_HOME)
  doAssert textinput4.scrollOffset == 0
  doAssert textinput4.screenCursorPos == 0
  doAssert textinput4.valCursorPos == 0

  # walking to the end keeps the cursor inside the visible window
  for i in 0 ..< textinput4.valRuneLen:
    sendKey(textinput4, sdl.SDLK_RIGHT)
  doAssert textinput4.valCursorPos == textinput4.valRuneLen
  doAssert textinput4.screenCursorPos <= textinput4.maxScreenCursorPos
  doAssert textinput4.valCursorPos - textinput4.scrollOffset ==
    textinput4.screenCursorPos
  echo "[test_simple_2_2] scroll checks passed: max column ",
    textinput4.maxScreenCursorPos, ", scroll offset ", textinput4.scrollOffset

#*#############################################
#!        ---== MAIN LOOP AHEAD ==---
#*#############################################
var done:bool=false
while not done:
  let nowNs = getMonoTime().ticks # FPS capping

  done = pgui.hid_events()
  pgui.runTimedEvents(nowNs)

  pgui.drawWindows() #* includes renderer.present()

  # FPS capping
  let endNs = getMonoTime().ticks
  var elapsedTime = endNs - nowNs
  #echo elapsedTime 
  elapsedTime = elapsedTime div 1_000_000 # ns to ms convert
  #echo elapsedTime 
  sleep(max(0, 16 - elapsedTime.int))

closeGui(pgui)
