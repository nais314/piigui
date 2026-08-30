# AGENTS.md

Nim SDL2 GUI toolkit ("piigui"), GPL-2.0, single author (Istvan Nagy). Some comments/code strings are in Hungarian. There is no README; the authoritative docs live in `doc/` (see below).

## Toolchain (important)

- `nim`/`nimble` are NOT on `PATH`. Use the choosenim toolchain directly:
  `/home/istvan/.choosenim/toolchains/nim-2.2.10/bin/nim` (same path is hardcoded in `.vscode/tasks.json`).
- The only runtime dependency is the nimble `sdl2` 2.0.6 package. `nimble.paths` (checked in, machine-specific) hardcodes absolute paths to `src/` and `~/.nimble/pkgs2/sdl2-2.0.6-...`; `config.nims` includes it only if the file exists. On a different machine this file must be regenerated (`nimble.paths` lines) or builds will fail.
- SDL2 system libs are required at runtime.

## Building and running

- Tests are **interactive SDL GUI demos, not unit tests**. They open a window and run an event loop (`hid_events` + `drawDom`), so they need a working X11/display and will not complete on their own.
- Build/run a test from the repo root:
  ```
  /home/istvan/.choosenim/toolchains/nim-2.2.10/bin/nim c -r tests/test_1_2.nim
  ```
  Compiling with `-o:name.out` writes the binary next to the source (`.out` is gitignored). Bare `nim c -r tests/foo.nim` drops `foo` beside the source.
- `tests/idtest.nim` is the one pure-logic (headless) test — good for quick sanity checks.
- The font is embedded at compile time via `staticRead("../assets/agave_regular_mono_nerd.ttf")` in `src/piigui/simple.nim`; keep that path valid relative to the module.

## Config layering (build flags are split across files)

- `nim.cfg` (repo root): `--threads:on --gc:orc --deadCodeElim:on --nimcache:/tmp/.nimcache` plus feature `--define:` flags. The defines gate experimental subsystems (`mainChannelInt_*`, `timedActions_*`, etc.); most are commented out. Do not enable them for unrelated work.
- `config.nims` -> includes `nimble.paths`.
- `tests/.config.nims`: adds `--path:$projectDir/../src`, threads+orc. Test files rely on this for `import piigui`.
- `src/.piigui.nims`: `--threads:on`.

## Architecture

- `src/piigui.nim` is the umbrella module. It `export`s only `types` and `ui/scrollbar`; it `import`s (but does not re-export) `style`, `layout/flex`, `layout/recalcH`, and `layout/recalcV`. Demos therefore also `import piigui/[types,style,simple,hidevents]` explicitly — follow that pattern rather than assuming `import piigui` pulls everything in.
- Key modules under `src/piigui/`:
  - `types.nim` — core types: `DivRef`/`DivObj`, `StyleSheetRef`, `Layer`, `ScrollBar`, size units (`muAuto`/`muStretch`/`muPx`/`muPc`), layout enums.
  - `simple.nim` — boilerplate: `newSimpleGui`, `closeGui`, embedded font.
  - `hidevents.nim` — `hid_events(pgui)`: the main HID event loop (returns `true` to quit).
  - `style.nim` — `recalcStyle`; `defaultSST` global style table.
  - `layout/flex.nim` — flex layout with scrolling support (`ofScroll`, `innerW`/`innerH`).
  - `layout/recalcH.nim`, `layout/recalcV.nim` — horizontal/vertical single-line box layouts, used by `row`/`column`. Intentionally **not scrollable** and single-line by design; use `flexRow`/`flexColumn` (see `src/piigui.nim`) when scrolling is needed. Import them as `import piigui/layout/recalcH as recalcHMod` / `... as recalcVMod`: the module name shadows the exported proc (`recalcH`), so a bare `import piigui/layout/recalcH` makes `recalcH` resolve to the module, not the proc.
  - `ui/` — widgets (`textbox`, `label`, `dosbtn`, `atogglebtn`, `gradbtn`, `scrollbar`, `utf8textarea`).
  - `ai/aiwebserver.nim` — small web server stub, separate from the GUI.

## Conventions that differ from defaults

- Styling is global via the `defaultSST` table, keyed by element **type name / group / name**, plus `"rootStyle"` (base) and pseudo-style keys (`"hover"`, `"focus"`). Add styles as `defaultSST["myGroup"] = newStyleSheet()`; pseudo-styles via `addNewPseudoStyle("hover")` / `addPseudoStyle(...)`. `recalcStyle(true)` must run before `recalcDOM()` in a demo.
- Scrolling is automatic and on by default (`overFlow == ofScroll`): containers that overflow get a scrollbar without opt-in. Set `overFlow = ofHidden` to clip instead. Do not re-derive this; the pipeline is documented in detail in `doc/scroll_system.md` (read it before touching scrollbar/layout code).
- `doc/style_logic.txt`, `doc/recalcflex_logic.txt`, `doc/flex_styling_aid.txt` are design notes; some may be stale relative to the code.
- `doc/todo.txt` is the author's scratch todo — consult it for intended direction.

## Noise to ignore

- `(copy 1).nim` files (e.g. `src/utf8container (copy 1).nim`, `aiwebserver (copy 1).nim`, `flex (copy 1).nim`) are accidental copies committed to git. Do not edit or build them.
- Root-level `*.out` binaries (e.g. `test_scroll.out`) are stray build artifacts.
- `ui_templates/` is an empty placeholder.
- `.vscode/launch.json` is an unmodified default (not wired to the project).


## Project Structure

- `src/piigui/layout` gui elements position and dimension recalculation
- `src/piigui/ui` gui elements
- `assets/` fonts and other bundled files
- `ui_templates` example gui snippets library (TODO)
- `src/piigui/ai` http api tool server, connect to opencode or open-webui via tool call (TODO)