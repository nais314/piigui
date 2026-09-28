# Nim Color Preview

Small, self-contained VS Code extension that shows inline color swatches for
the Nim color literals used by [PiiGUI](https://github.com/istvan-nagy/PiiGUI)
and wires them to the native VS Code color picker.

## Supported syntax

| Form | Example |
| --- | --- |
| HexColor literal (RRGGBBAA) | `0xDDDDDDFF.HexColor` |
| HexColor literal (RRGGBB, alpha = 255) | `0x6B859C.HexColor` |
| Positional RGB / RGBA call | `setBackGroundColor(220, 220, 220[, 255])` |
| Other setters | `setBackgroundColor(...)`, `setColor(...)` |
| Method-call spelling | `.setColor(50, 120, 255)` |
| Named arguments | `rgbaColor(r=0, g=0, b=0, a=255)` |
| SDL Color tuple | `sdl.Color((r:255'u8, g:255'u8, b:255'u8, a:255'u8))` |

Function names are matched case-insensitively (Nim is style-insensitive), but
only calls whose arguments are **literal integers in 0..255** are matched.
Calls with identifiers, expressions or out-of-range values, comments and
strings are ignored.

## Behavior

- Swatches are shown for hex literals and for the numeric calls above.
- Opening the color picker and choosing a color rewrites only the numeric
  values, preserving the surrounding code:
  - Hex literals keep the `.HexColor` suffix and are written with **uppercase**
    hexadecimal digits. A 6-digit literal stays 6 digits on an opaque pick and
    widens to 8 digits when alpha changes.
  - Calls keep their function name, separator style (`220, 220`, `r=` or
    `r:...'u8`) and spacing. A 3-argument call gains a fourth (alpha) argument
    only when a translucent color is picked; an opaque pick leaves it at 3.
- Source text is never modified unless you actually use the color picker.

## Run with F5 (development)

Requirements: Node.js 18+ (for the tests), VS Code.

```bash
npm install
```

Open this folder in VS Code (`code assets/vscode-nim-color-preview`) and press
**F5** (launch config "Run Extension"). A new Extension Development Host opens;
open any `.nim` file and the swatches appear automatically. Set a breakpoint in
`src/parser.ts` or `src/extension.ts` while iterating.

## Tests

The tests use Node's built-in runner and exercise parsing, alpha handling and
source-code replacement end to end with zero dependencies:

```bash
npm test          # compiles then runs node --test out/tests/
```

## Package as VSIX

Install the VS Code extension packager and produce `nim-color-preview-0.0.1.vsix`:

```bash
npm install -g @vscode/vsce
npm run package          # equivalent: vsce package
```

Install the resulting VSIX from the Extensions view (`...` menu →
*Install from VSIX...*) or the CLI:

```bash
code --install-extension nim-color-preview-0.0.1.vsix
```

`vsce package` needs a `publisher` — change `publisher` in `package.json`
(e.g. to your marketplace handle) before publishing to a marketplace.

## Layout

- `src/parser.ts` — pure tokenizing/parsing + edit-builder logic (testable without VS Code).
- `src/extension.ts` — activates and registers the `DocumentColorProvider` for `nim`.
- `tests/parser.test.ts` — node:test suite covering parsing, alpha defaults,
  3↔4 argument transitions, hex case/width rules and rejection cases.