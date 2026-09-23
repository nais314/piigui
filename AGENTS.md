# AGENTS.md

## Agent Contract

This file is the operating guide for AI agents working on PiiGUI. Follow it
before making assumptions from generic coding conventions.

- Explore and inspect freely in read-only mode.
- Before editing any file, present a file-level plan and wait for explicit user
  approval. The plan must name every file that may change and describe the
  intended change.
- After approval, change only the approved files and scope. Ask again if the
  scope needs to expand.
- Do not commit, amend, push, or perform destructive Git operations unless the
  user explicitly requests it.
- Preserve unrelated user changes in the working tree. Inspect them before
  touching a file that already differs from `HEAD`.
- Report findings proactively, but do not implement unrequested fixes or
  improvements. Separate confirmed bugs, risks, and optional design ideas.
- Prefer the smallest correct change. Favor readable, human-friendly code and
  reusable templates or helpers when they clearly reduce repetition without
  hiding important behavior.
- Before proposing code, inspect the relevant implementation and documentation;
  do not infer behavior from filenames alone.

## Engineering Review Expectations

For every non-trivial change, proactively inspect and report:

- Performance: unnecessary allocations, repeated traversal, hot-loop work,
  closure captures, and avoidable rendering or layout recalculation.
- Readability: confusing control flow, duplicated logic, misleading names, and
  opportunities for small templates or helpers.
- Memory and resource safety: Nim ref lifetimes and cycles, SDL window,
  renderer, surface, texture, font, RWops, and subsystem cleanup, plus cleanup
  on error paths.
- Thread safety: shared mutable state, channel ownership, main-thread SDL
  access, callback lifetimes, and shutdown ordering.
- Boundary safety: integer and unsigned overflow, sequence bounds, sentinel
  values, nil references, failed SDL calls, and invalid external input.
- Portability: Linux/X11 is the only supported platform currently. Report
  concrete SDL, filesystem, compiler, threading, or build assumptions that
  would block Windows or macOS later, and suggest a narrowly scoped TODO hint.

These reviews are reports only. Do not widen the implementation plan unless
the user explicitly asks for one of the reported changes. Ask focused follow-up
questions when the preferred solution or scope is unclear.

## Project

PiiGUI is a Nim SDL2 GUI toolkit, licensed under MPL-2.0. The author is Istvan
Nagy. Linux with an available X11 display is the supported runtime environment.

There is no README. Use `AGENTS.md` for agent workflow and `doc/` for design
notes. `PiiGUI-POLICY.md`, `LICENCE.md`, and `LICENCE_POLICY.md` describe the
licensing and project policy.

## Noise to ignore

- `(copy 1).nim` files (e.g. `src/utf8container (copy 1).nim`, `aiwebserver (copy 1).nim`, `flex (copy 1).nim`) are accidental copies committed to git. Do not edit or build them.
- Root-level `*.out` binaries (e.g. `test_scroll.out`) are stray build artifacts.
- `ui_templates/` is an empty placeholder.
- `.vscode/launch.json` is an unmodified default (not wired to the project).

## Project Structure And Main Files

- `src/piigui.nim`: Umbrella module.
- `src/piigui/layout/flex.nim`: Flex layout and scrolling support.
- `src/piigui/hidevents.nim`: Main HID event loop (`hid_events`).
- `src/piigui/simple.nim`: GUI boilerplate and embedded font.
- `src/piigui/style.nim`: Style recalculation (`recalcStyle`) and `rootSSRT`.
- `src/piigui/types.nim`: Core types and enums.
- `src/piigui/ui/`: Widget modules (`dosbtn`, `label`, `atogglebtn`, `gradbtn`, `scrollbar`, `utf8textarea`, etc.).
- `tests/`: Interactive SDL demos and headless tests.

## Toolchain And Dependencies

- Use `/home/istvan/.choosenim/toolchains/nim-2.2.10/bin/nim`; `nim` and
  `nimble` are not on `PATH`.
- `piigui.nimble` declares Nim 2.2.10 or newer and the SDL2 Nim package.
- SDL2 system libraries and a display are required for GUI execution.
- `nimble.paths` is machine-specific and ignored by Git. It may provide the
  local `src/` and SDL2 package paths; do not assume it exists on another
  machine.
- `nim.cfg` enables threads, ORC, dead-code elimination, logging, input-event
  and timed-action features. Do not enable commented experimental defines for
  unrelated work.
- `config.nims` includes `nimble.paths` only when it exists.
- `tests/.config.nims` adds `src/` to the import path and enables threads and
  ORC. Tests depend on this configuration.
- `src/.piigui.nims` enables threads for source builds.

## Build And Verification

Run commands from the repository root with the pinned Nim executable:

```text
/home/istvan/.choosenim/toolchains/nim-2.2.10/bin/nim c -r tests/headless_test.nim
/home/istvan/.choosenim/toolchains/nim-2.2.10/bin/nim c -r tests/test_1_2.nim
```

`tests/headless_test.nim` is the headless pure-logic sanity test. The other tests are
interactive SDL demos: they open a window, run an event loop, and do not finish
automatically. Run them only when an X11 display is available and state clearly
when they could not be run.

For a compile-only check, omit `-r`. Build artifacts ending in `.out` are
ignored. The project uses `/tmp/.nimcache` through `nim.cfg`.

The default font is embedded at compile time in `src/piigui/simple.nim` from:

```text
../assets/AgaveNerdFontMono-Regular.ttf
../assets/AgaveNerdFontMono-Bold.ttf
```

Keep those paths valid relative to `simple.nim`.

## Architecture Map

- `src/piigui.nim` is the umbrella module. It exports `types` and
  `ui/scrollbar`, but imports rather than re-exports the style and layout
  modules. Consumers commonly import
  `piigui/[types,style,simple,hidevents]` explicitly.
- `src/piigui/types.nim` defines core types such as `DivRef`/`DivObj`,
  `StyleSheetRef`, `Layer`, `ScrollBar`, measurement units, layout enums, and
  window state.
- `src/piigui/simple.nim` initializes and closes the basic SDL GUI and embeds
  the default fonts.
- `src/piigui/hidevents.nim` contains `hid_events(pgui)`, the main HID event
  loop. It returns `true` when the application should quit.
- `src/piigui/style.nim` recalculates styles and owns the global `rootSSRT`
  style table.
- `src/piigui/layout/flex.nim` implements flex layout and scrolling support.
- `src/piigui/layout/recalcH.nim` and `recalcV.nim` implement single-line
  horizontal and vertical box layouts used by `row` and `column`. They are not
  scrollable; use `flexRow` or `flexColumn` when scrolling is required.
- Import the recalc modules with aliases, for example
  `import piigui/layout/recalcH as recalcHMod`, because the module name can
  shadow the exported `recalcH` procedure.
- `src/piigui/ui/` contains widgets including labels, buttons, text boxes,
  text areas, and scrollbars.
- `src/piigui/ai/aiwebserver.nim` is a separate web-server stub.
- `src/piigui/app/intercom.nim` contains application communication support.

## Behavioral Conventions

- Styling is global through `rootSSRT`, keyed by element type, group, name,
  `rootStyle`, and pseudo-style keys such as `hover` and `focus`.
- Add a group with `rootSSRT["myGroup"] = newStyleSheet()` and create or add
  pseudo-styles with `addNewPseudoStyle("hover")` or `addPseudoStyle(...)`.
- Run `recalcStyle(true)` before `recalcDOM()` in demos.
- Overflow defaults to scrolling (`ofScroll`). Overflowing containers receive
  scrollbars automatically. Use `ofHidden` to clip and disable scrolling.
- Read `doc/scroll_system.md` before changing scrollbar or scroll-layout code.
- `doc/recalcflex_pipeline.md`, `doc/element_clipping.md`, and
  `doc/piigui.nim_visibleClipRect.md` describe current layout and clipping
  behavior.
- `doc/style_logic.txt`, `doc/recalcflex_logic.txt`, and
  `doc/flex_styling_aid.txt` are design notes and may be stale. Verify their
  claims against the implementation.
- `doc/todo.md` records the author's intended direction and unresolved ideas;
  do not treat it as an approved implementation plan.

## Nim Coding Conventions

Follow Nim NEP 1 unless this section overrides it. Mirror the existing style
of the module being changed.

### File Layout (must read top-down, human-first)

Order every source file as:
1. Module doc comment (`##`) at the very top: the file's role in the project.
2. Imports.
3. `const debug = 1` and other module constants.
4. Types: data first, then state/context objects.
5. Forward declarations (`#!FWD`) for procs used before they are defined.
6. The public entry proc FIRST, so the reader meets the high-level flow first.
7. Helper procs below, in dependency order.
8. Tiny private helpers last.

Rule: the top of the file must tell the story; details come later.

- Use two-space indentation and no tabs.
- Put a module `##` comment first when adding or substantially reorganizing a
  source file, followed by imports, constants, types, forward declarations,
  the public entry procedure, and helpers in dependency order.
- Export public procedures with `*` and document their public contract with
  `##` comments.
- Keep one procedure focused on one job. Keep entry procedures short and move
  reusable logic to named module-level helpers.
- Avoid closure captures in layout, event, and other hot paths. Pass mutable
  context explicitly, normally as `var state: ContextObj`.
- Use PascalCase for types and camelCase for procedures, variables, and fields.
  Use `FooRef`/`FooObj` for ref/object pairs and `Kind` suffixes for enum types.
- Constants use the project style of CapitalizedCamelCase, such as
  `ScrollBarSize` and `DefaultWindowW`.
- Prefer descriptive names. Conventional short names such as `w`, `h`, `px`,
  and `i` are acceptable in local, obvious contexts.
- Boolean names should normally begin with `is`, `has`, or `needs`.
- Preserve existing enum prefixes such as `mu`, `fd`, `fjc`, `fac`, `fai`,
  `of`, and `bgr`.
- `-1` is the unset sentinel for integer style properties including `padding`,
  `spacing`, `flexGrow`, and `flexGrowFrom`. Guard it with `> -1` and document
  the meaning where new code declares or reads it.
- Prefer `result` for procedure results, tuple returns such as
  `tuple[w, h: int]`, `seq.setLen(0)` for clearing reusable sequences, and
  local aliases instead of repeated `seq[i]` access.
- Reuse state objects in repeated passes and avoid allocations inside
  per-element or per-line loops.
- Explain why non-obvious logic exists. Preserve useful existing section
  banners and update comments when behavior changes.
- Debug output must be gated by the module's existing debug convention. Do not
  add noisy unconditional tracing to hot paths.

## NAMING

- Types / objects: PascalCase. Enums: suffix `Kind`. Ref/object pairs:
  `FooRef` / `FooObj`.
- Procs, variables, fields: camelCase.
- Constants: CapitalizedCamelCase (project override): `ScrollBarSize`,
  `DefaultWindowW`, `MaxScale`, `EmptyColor`.
- NO cryptic abbreviations: `scrollBar` not `sb`; `elementWithBiggestGrow`
  not `ewbg`; `remainingWidth` not `availW` when it is read often.
- Conventional abbreviations ARE allowed when universally understood:
  `maxH`, `minW`, `w`, `h`, `x1`, `y1`, `x2`, `y2`, `px`, `i`.
- Iterator indices: `i_elem`, `i_line`, `i_layer`; double the leading letter
  for nested loops (`ii_elem`). Prefer `elemIndex`/`lineIndex` when not nested.
- Booleans: `is` / `has` / `needs` prefix: `isRecalculated`,
  `needsVerticalScrollbar`.
- The self parameter is `this`. The shared mutable state object is `state`.
- Enum member prefixes stay short and consistent: `mu` measurement unit,
  `fd` flex direction, `fjc` justify content, `fac` align content,
  `fai` align items, `of` overflow, `bgr` background repeat.
- Prefer full words; fall back to a conventional abbreviation only for
  long, hot, or universally-known names. When you abbreviate, do it
  consistently across the codebase.

## Comments

- Comment the reason for non-obvious logic, not merely what the code does.
- Document sentinel values, boundary assumptions, ownership, and cleanup at
  the point where they are declared or used.
- Keep useful existing section banners and update comments when behavior
  changes; do not remove explanatory comments without replacing their value.
- Use `#!` for very important warnings, variables, procedures, and forward declarations
  such as `#!FWD`, logic or code breaking, early returns, optimizations.
- Use `#*` for emphasis and section markers, `#TODO:` for known improvement
  opportunities, and `#?` for questionable code that needs review.
- Keep comments concise and human-readable. Do not add comments that merely
  restate a variable declaration or straightforward operation.
- Before every non-obvious logic block: one line explaining WHY it exists.
- After (or beside) every variable declaration: its role.
- Use `#!` as a marker for important comments variables, procs, section tags (`#!FWD`, `#! watch out`).
- Use `#*` as a marker for emphasis and section tags (`#* content height`, `#* importan variable`).
- Use `#TODO:` as a marker for "here is room to improve the code", "need to refactor"
- Use `#?` to mark questionable lines or variables in the code
- Keep existing section banner comments; do not delete them. You can add your own.
- Comment the "why", not the "what". Update comments when code changes.
- Document sentinel values and boundary checks at the point of use.
- This is a banner style before large block of code, segments of code (variables block, types block, proc for some topic)
    ```nim
    #*=================================================
    #*           RECALCULATE STYLESSHEETS
    #*=================================================
    ```
- This is a banner for the finalizing part of some proc
    ```nim
    #--------------------------------------------
    # finally
    #--------------------------------------------
    ```

## PERFORMANCE

- No closure capture in hot code; pass state as a `var` object parameter.
- Avoid repeated `seq[i]` indexing; bind a local alias.
- Keep allocations out of per-element / per-line loops.
- Prefer a value object (`object`) passed by `var` over a `ref` for transient
  state.

## DEBUG TRACING

- Keep a module-level `const debug = <level>`.
- Use `when debug > <level>:` format so debug can be switched off.
- Level convention: `> 0` lifecycle only, `> 1` per-proc / per-line detail,
  `> 2` per-element dumps.
- Prefix every echo with the proc name: `echo "procName: ..."`.
- Add `BEGIN <name>` / `END <name>` traces to every proc.

## Change Completion Checklist

- The implementation matches the approved file-level plan.
- Unrelated worktree changes remain untouched.
- Relevant source and documentation were inspected.
- The pinned Nim compile check was run, or the reason it could not run is
  reported.
- `tests/headless_test.nim` was run when relevant.
- Interactive SDL tests were run only with a working display and their status
  is reported.
- New warnings, resource leaks, thread-safety concerns, portability blockers,
  and boundary risks were checked and reported.
- No unrequested bug fixes, refactors, TODO changes, or commits were made.
