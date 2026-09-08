import os, locks, times, tables, json

import std/deques

type
  EventOrigin* {.pure.} = enum
    User,     # user interaction, HID events
    Api,      # Web API event
    Internal  # ...like timed events, other system ev

  GuiEvent* = object
    kind*: string        # pl. "click", "change"
    source*: uint        # GUI widget ID
    #dest*: uint         # GUI widget ID, optional
    origin*: EventOrigin # User, Api, Internal
    value*: string       # optional data, json, "target": 10

# Létrehozzuk a FIFO eseménysort
var guiEventQueue* = initDeque[GuiEvent]()

proc addGuiEvent*(event:GuiEvent)=
  guiEventQueue.addLast(event)

proc addGuiEvent*():GuiEvent=
  guiEventQueue.popFirst()