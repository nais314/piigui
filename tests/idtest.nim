import std/[strutils, json]

type
  IDKind* = enum
    idCustom, idPath, idAuto

  ComponentID* = object
    kind*: IDKind
    value*: string

  # Bázis Widget típus a teszteléshez
  Widget* = ref object of RootObj
    id*: ComponentID
    kindName*: string
    parent*: Widget
    children*: seq[Widget]

var globalIDCounter: uint64 = 0

# --- ID Generálási Funkciók ---

proc initComponentID*(customName: string = ""): ComponentID =
  if customName.len > 0:
    result = ComponentID(kind: idCustom, value: customName)
  else:
    inc globalIDCounter
    result = ComponentID(kind: idAuto, value: "widget_" & $globalIDCounter)

proc buildPathID*(w: Widget): string =
  ## Generál egy fa-hierarchia alapú elérési utat (pl. "root/VBox_0/Button_1")
  if w.parent == nil:
    return "root"
  
  var siblingIndex = 0
  for child in w.parent.children:
    if child == w: break
    if child.kindName == w.kindName:
      inc siblingIndex

  let parentPath = w.parent.buildPathID()
  return parentPath & "/" & w.kindName & "_" & $siblingIndex

proc ensureValidID*(w: Widget) =
  ## Beállítja a hierarchikus ID-t, ha nincs egyedi azonosító megadva
  if w.id.kind == idAuto and w.parent != nil:
    w.id = ComponentID(kind: idPath, value: w.buildPathID())

# --- JSON & AI Segédfüggvények ---

proc `$`*(id: ComponentID): string =
  id.value

proc `%`*(id: ComponentID): JsonNode =
  %id.value

# --- Példa Használat ---

when isMainModule:
  # 1. Root HBox példányosítás
  var root = Widget(kindName: "HBox", id: initComponentID("main_window"))
  
  # 2. Szülőhöz adás automatikus ID-val
  var input = Widget(kindName: "TextInput", id: initComponentID(), parent: root)
  root.children.add(input)
  input.ensureValidID()

  var btn = Widget(kindName: "Button", id: initComponentID("submit_btn"), parent: root)
  root.children.add(btn)
  btn.ensureValidID()

  # 3. Kimenet ellenőrzése
  echo "Root ID: ", root.id            # -> main_window
  echo "TextInput ID: ", input.id      # -> root/TextInput_0
  echo "Button ID: ", btn.id           # -> submit_btn