# main files are:
src/piigui.nim
src/layout/flex.nim
src/ui/dosbtn.nim
src/ui/label.nim
src/ui/atogglebtn.nim
src/ui/gradbtn.nim
src/ui/scrollbar.nim
src/hidevents.nim
src/simple.nim
src/style.nim
src/types.nim
doc/*.*
tests/
tests/test_scaling.nim
tests/test_simple_1.nim
tests/test_mainloop_1.nim
tests/test_timedEvent.nim
tests/test_scroll.nim
tests/test_recalcV.nim
tests/test_recalcH.nim
tests/test_flex.nim
tests/test_1_2.nim
other files can be skipped.

====================================================================
# CODING STYLE GUIDE
(derived from src/piigui/layout/flex.nim - apply to all Nim code)
====================================================================

AUTHORITY
- Follow https://nim-lang.org/docs/nep1.html, EXCEPT where this guide overrides it.
- Override: const constants begin with a Capital letter (see NAMING).
- When in doubt, mirror the existing style of the file you are editing.

FILE LAYOUT (must read top-down, human-first)
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

PROCS
- Public procs are exported with `*` and carry a `##` doc comment.
- A long proc's doc comment describes purpose, workflow, and data "pipe",
  ideally as a numbered step list.
- Every proc gets trace echoes at entry and exit (see DEBUG TRACING).
- One proc = one job. Keep the entry proc short; delegate to named helpers.
- Hoist helpers to module scope and pass shared state explicitly via a
  `var state: <ContextObj>` parameter. Do NOT capture state in closures,
  especially in hot paths (layout, events).
- Forward-declare helpers at the top so the entry proc can be defined first.

COMMENTS
- Before every non-obvious logic block: one line explaining WHY it exists.
- After (or beside) every variable declaration: its role.
- Use `#!` as a marker for emphasis and section tags (`#!FWD`, `#! content height`).
- Keep existing section banner comments; do not delete them.
- Comment the "why", not the "what". Update comments when code changes.
- Document sentinel values and boundary checks at the point of use.

NAMING
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

SENTINELS
- `-1` means "unset" for int style props (`padding`, `spacing`, `flexGrow`,
  `flexGrowFrom`). Always guard with `> -1`.
- Document every sentinel where it is declared and where it is read.

NIM IDIOMS (as used in this project)
- 2-space indentation, no tabs.
- Use `result`; return tuples like `tuple[w, h: int]`.
- Expression form: `let x = if cond: a else: b`.
- `for i in 0..seq.high` when the index is needed; `for x in seq` otherwise.
- `countdown(seq.high, 0)` for reverse iteration.
- `seq.setLen(0)` to clear and reuse a sequence.
- Inside a loop, bind `let elem = seq[i]` once instead of re-indexing.
- Reset one reusable state object per pass instead of allocating per call.

PERFORMANCE
- No closure capture in hot code; pass state as a `var` object parameter.
- Avoid repeated `seq[i]` indexing; bind a local alias.
- Keep allocations out of per-element / per-line loops.
- Prefer a value object (`object`) passed by `var` over a `ref` for transient
  state.

DEBUG TRACING
- Keep a module-level `const debug = <level>`.
- Level convention: `> 0` lifecycle only, `> 1` per-proc / per-line detail,
  `> 2` per-element dumps.
- Prefix every echo with the proc name: `echo "procName: ..."`.
- Add `BEGIN <name>` / `END <name>` traces to every proc.

BEFORE FINISHING (checklist)
- [ ] Compiles with the project toolchain; no NEW warnings.
- [ ] Behavior is unchanged unless the change was requested; verified with a
      harness or test, not by assumption.
- [ ] Entry proc is readable top-down; helpers are below or forward-declared.
- [ ] Every long proc has a `##` doc comment; every file has a top doc comment.
- [ ] No cryptic names; sentinels documented; comments explain "why".
- [ ] Debug BEGIN/END traces present; debug levels consistent.