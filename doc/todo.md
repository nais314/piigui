# TODO LIST

## TODO

- types.nim
  - #borderWidth*:tuple[top,right,bottom,left:int]
  - #background*:
  - layer:int

- piigui.nim
  - recalcDOM*(pgui:Pgui)=

### complex gui elements, templates

- textMatrixArea: a rectangle, it has rows and columns of monospace characters, like a **terminal**, except the scrolling.
like an LCD screen. the characters can be modified individually.

- support functions, like line, row, news-scroll

- sheetRow: a row of elements, can have background colors like red, green, blue, gray,

- the most basic boilerplate code\
  (create templates for human and ai)

### subsystems, mechanisms

- simple.nim:
  - dynlib load when clause

- styles:
  - default: fg, bg, focus

- ui scaling:
  - BaselineDPI: float = 96.0  #TODO the "1.0 scale" reference point (same convention as CSS)
  - recalcScaling - onScalingChange: modified recalcDOM, if muPx then w=w x scale; h=h x scale
  - type.nim PgWindow.scale*:float=1.0
  - DivObj w_unscaled*, h_unscaled*:int # scaling system stores original w h values

- DivObj and scrolling

    ```# generic begin-state for drags (saved once per drag in default_onDragStart)
    origX1*, origY1*: int #TODO: remove. scrollbar needs reviewd. other ui elems dragged on _top_ layer
    dragSaved*: bool #TODO: remove```

### ui elements

- border drawing

## DOING

## DONE

- DONE: vhbox -> recalcVbox & recalcHBox
- DONE: gui element timed events (blinking)
