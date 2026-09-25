# TODO LIST AND IDEA BOX

## TODO

- fonts should be property of window for multi screen multi dpi

- types.nim
  - #borderWidth*:tuple[top,right,bottom,left:int]
  - #background*:
  - layer:int
  - PositionKind

- piigui.nim
  - recalcDOM*(pgui:Pgui)=

- styles
  - pseudostyles helper functions/templates like .focus
    - if not exists pseudostyle create
    - return stylesheet

- 9-scale:
  discard SDL_SetTextureColorMod(tex, 255, 128, 128)   # multiplies RGB
  discard SDL_SetTextureAlphaMod(tex, 200)

### complex gui elements

- textMatrixArea: a rectangle, it has rows and columns of monospace characters, like a **terminal**, except the scrolling.
like an LCD screen. the characters can be modified individually.

- support functions, like line, row, news-scroll

- sheetRow: a row of elements, can have background colors like red, green, blue, gray,
  - even/odd fill - custom addChild, Removechild methods for style change hooks

### templates

- the most basic boilerplate code\
  (create templates for human and ai)

### subsystems, mechanisms

- simple.nim:
  - dynlib load when clause

- styles:
  - default: fg, bg, focus

- DivObj and scrolling

    ```# generic begin-state for drags (saved once per drag in default_onDragStart)
    origX1*, origY1*: int #TODO: remove. scrollbar needs reviewd. other ui elems dragged on _top_ layer
    dragSaved*: bool #TODO: remove```

### ui elements

- border drawing `-[panel name]---[*]-`

## DOING

## DONE

- DONE: vhbox -> recalcVbox & recalcHBox
- DONE: gui element timed events (blinking)

- ui scaling:
  - BaselineDPI: float = 96.0  #TODO the "1.0 scale" reference point (same convention as CSS)
  - recalcScaling - onScalingChange: modified recalcDOM, if muPx then w=w x scale; h=h x scale
  - type.nim PgWindow.scale*:float=1.0
  - DivObj w_unscaled*, h_unscaled*:int # scaling system stores original w h values



One thing I preserved but you may want to fix later

resetState sets nextX = this.x1 + this.style.padding (so x1 - 1 when padding is unset), while newRow uses this.x1 guarded by if padding > -1. Pre-existing off-by-one inconsistency between the first line and subsequent lines — I left it exactly as-is.
