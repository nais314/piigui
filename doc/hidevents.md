# HID Events

This document explains how PiiGUI turns SDL input into element handlers.
The single entry point is `hid_events(pgui)` in `src/piigui/hidevents.nim`.
It returns `true` when the application should quit.

Everything below happens on the main thread, which is the only thread
allowed to touch SDL or the element tree.

## Pipeline

```text
main loop
  |
  v
sdl.pollEvent(e)                         # hidevents.nim
  |
  +-- EVENT_QUIT --------------------> return true (quit)
  |
  +-- EVENT_KEY_DOWN ---------------> focus/window -> Escape/drag cancel
  |                                     -> focusElem: keydown, then scancode
  |                                     -> window:    keydown, then scancode
  |                                     -> pgui:      keydown, then scancode
  |                                        (first handled listener stops)
  |
  +-- EVENT_TEXT_INPUT -------------> focusElem.onTextInput(text)
  |
  +-- EVENT_MOUSE_MOTION -----------> getElementAtCoord -> hover / drag
  +-- EVENT_MOUSE_BUTTON_DOWN ------> mouseSource = target
  +-- EVENT_MOUSE_BUTTON_UP --------> onClick(e) -> trigger("click", e)
  |                                     -> drop / blur / focus
  +-- EVENT_MOUSE_WHEEL ------------> trigger("wheelup", e) ...
  |                                     else scroll nearest scrollable
  |
  +-- EVENT_WINDOW_* ---------------> markWindowDirty / resize root
```

`getElementAtCoord` (`src/piigui.nim`) walks the layer tree and returns the
top-most element under a screen coordinate.

## The event bus

Elements, windows (`PgWindow`), and the app (`Pgui`) expose a small
named-event registry:

```nim
proc addEventListener*(this: DivRef, evtname: string,
                       fun: proc(source: DivRef, e: sdl.Event): bool)
proc removeEventListener*(this: DivRef, evtname: string,
                          fun: proc(source: DivRef, e: sdl.Event): bool)
proc trigger*(this: DivRef, evtname: string,
              e: sdl.Event = default(sdl.Event)): bool

# the same add/remove/trigger trio exists for PgWindow and Pgui
```

A listener returns `true` when it handled the event and `false` when it did
not. `trigger` passes the event through unchanged, runs every matching
listener in registration order, and returns `true` if any of them returned
`true`.

> A listener that does not consume an event **must return `false`**.
> Otherwise bubbling stops at that listener and later scopes never see the
> event.

## Bubbling and the handled flag

Keyboard events bubble through three scopes, and at each scope two named
events are tried in order:

```text
1. focusElem  -> "keydown", then $scancode
2. window     -> "keydown", then $scancode
3. pgui       -> "keydown", then $scancode
```

Bubbling stops at the first scope where a listener returns `true`. A focused
`MonoTextBox` that returns `true` for the Left arrow, for example, prevents
window- and app-level handlers from seeing that key. Return `false` to let the
key continue bubbling, for example so an app-wide shortcut still fires.

The fine-grained `"keydown"` event and the legacy per-scancode event are two
separate buses: the scancode bus is only tried when the `"keydown"` bus at
that scope reported `false`.

### Is the event real?

`trigger` can be called without an event (for example
`trigger(this, "click")`). In that case `e` is the no-event sentinel
`default(sdl.Event)`. A listener tells a real event from that sentinel with:

```nim
if e.`type` != sdl.EVENT_KEY_DOWN:
  return false
```

or, to only ask whether any event was passed:

```nim
if e.`type` != sdl.EVENT_FIRST:
  discard # a real event was passed
```

`EVENT_FIRST == 0` is a range marker; `sdl.pollEvent` never delivers it.

## If you want a simple key press: per-scancode listener

The scancode event name is the string form of `e.key.scancode`, e.g.
`"SCANCODE_RETURN"`, `"SCANCODE_A"`, `"SCANCODE_F1"`. This is the easiest
way to react to one key:

```nim
proc onEnter(source: DivRef, e: sdl.Event): bool =
  echo "Enter pressed on ", source.name
  return true # handled: stop bubbling

someElem.addEventListener("SCANCODE_RETURN", onEnter)
```

## If you want fine-grained key handling: `"keydown"`

For modifier keys, auto-repeat, or editing keys, subscribe to `"keydown"`
and inspect the full event:

```nim
import sdl3 as sdl

proc onKeyDown(source: DivRef, e: sdl.Event): bool =
  if e.`type` != sdl.EVENT_KEY_DOWN:
    return false
  # e.key.key      -> layout-aware keycode (sdl.SDLK_*)
  # e.key.scancode -> physical key (sdl.SCANCODE_*)
  # e.key.`mod`    -> sdl.KMOD_CTRL / KMOD_SHIFT / KMOD_ALT
  # e.key.repeat   -> true for key auto-repeat
  if (e.key.`mod`.uint32 and sdl.KMOD_CTRL) != 0'u32:
    case e.key.key
    of sdl.SDLK_Z:
      echo "Ctrl+Z"
      return true
    else:
      return false
  else:
    case e.key.key
    of sdl.SDLK_LEFT:
      echo "cursor left"
      return true
    of sdl.SDLK_RETURN:
      echo "enter"
      return true
    else:
      return false

someElem.addEventListener("keydown", onKeyDown)
```

See `src/piigui/ui/monotextbox.nim`, `keyDownEventListener`, for a full
example: arrow/Home/End navigation, Backspace/Delete, Ctrl+Z undo, and
Enter-to-blur.

Note that `sdl.SDLK_*` constants are `uint32` while `e.key.`mod`` is
`uint16`; convert before combining with `KMOD_*`.

## Mouse events

Simple reactions can use the per-element callbacks, which receive the raw
SDL event where useful:

```nim
elem.onMouseButtonDown = proc(this: DivRef) = discard
elem.onMouseButtonUp   = proc(this: DivRef) = discard
elem.onClick           = proc(this: DivRef, e: sdl.Event) = discard
```

Or subscribe to the bus:

```nim
elem.addEventListener("click", proc(source: DivRef, e: sdl.Event): bool = true)
elem.addEventListener("wheelup", proc(source: DivRef, e: sdl.Event): bool = true)
```

- `"click"` fires from `EVENT_MOUSE_BUTTON_UP` when the press started on the
  same element.
- `"wheelup"`, `"wheeldown"`, `"wheelleft"`, `"wheelright"` fire from
  `EVENT_MOUSE_WHEEL`. If every matching listener returns `false`, the nearest
  scrollable ancestor is scrolled; return `true` to consume the wheel event.

## Hover and drag and drop

- `onHover` runs on `EVENT_MOUSE_MOTION`; the default handler is a no-op
  when the element is already hovered.
- `EVENT_MOUSE_BUTTON_DOWN` stores `pgui.mouseSource`.
- While dragging, `onDragStart`, `onDragOver` and `onDragEnd` run.
- Dropping on another element fires `onDrop`.
- `Escape` cancels an in-progress drag via `onDragCancel`.

## Text input

Character input does not go through `"keydown"`. It arrives as
`EVENT_TEXT_INPUT`, routed to the focused element:

```nim
proc onTextInput(this: DivRef, text: string) =
  discard # append `text` at the caret
elem.onTextInput = onTextInput
```

Keyboard handling and text input are complementary: use `"keydown"` for
navigation and editing commands, and `onTextInput` for the actual characters.

## Window-level and system-wide listeners

`PgWindow` and `Pgui` expose the same `addEventListener` /
`removeEventListener` / `trigger` trio as elements.

- Window listeners receive the window's `rootElem` as `source`.
- App-wide (`pgui`) listeners receive `nil` as `source`, meaning "no element".

```nim
proc onWindowKey(source: DivRef, e: sdl.Event): bool =
  # source == window.rootElem here
  return false # not handled: keep bubbling to app-wide listeners

window.addEventListener("keydown", onWindowKey)

proc onAnyKey(source: DivRef, e: sdl.Event): bool =
  # source == nil here
  return true

pgui.addEventListener("keydown", onAnyKey)
```

These scopes are only consulted when the focused element (and then the window)
did not handle the key. See "Bubbling and the handled flag" above.

## Timed and animated elements

The cursor blink in `MonoTextBox` is not a HID event. It uses
`pgui.addTimedEvent(...)` / `removeTimedEvent(...)` (see `src/piigui.nim`,
`runTimedEvents`), which the main loop calls each frame.
