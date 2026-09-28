# Build a VS Code Nim Color Preview Extension

Create a small, self-contained VS Code extension in TypeScript.

## Goal

Display inline color swatches in Nim source files and support the native VS Code color picker.

## Supported syntax

1. HexColor:
   `0xDDDDDDFF.HexColor`

2. RGB/RGBA function arguments:
   `setBackGroundColor(220, 220, 220, 255)`
   `setColor(50,120,255,255)`
   `sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8))`
   `rgbaColor(r=0,g=0,b=0,a=255)`

3. Also support:
   `setBackGroundColor(220, 220, 220)`
   `setBackgroundColor(220, 220, 220, 255)`
   `.setColor(50,120,255)`

## Hexadecimal interpretation

For `.HexColor`, interpret the 8 hexadecimal digits as RRGGBBAA.

For example, `0xDDDDDDFF` means:

* Red: 221
* Green: 221
* Blue: 221
* Alpha: 255

Support 6-digit RGB literals as well, with alpha defaulting to 255.

## RGB interpretation

* Three arguments: RGB, alpha defaults to 255.
* Four arguments: RGBA.
* Each component must be an integer between 0 and 255.
* Ignore expressions that do not contain literal integer arguments.
* Do not match unrelated function calls.

## Editor behavior

* Register a VS Code DocumentColorProvider for Nim files.
* Display inline color swatches.
* Support the native VS Code color picker.
* When a color is changed, update the original source expression while preserving its format.
* For hexadecimal literals, preserve the `.HexColor` suffix and use uppercase hexadecimal digits.
* For RGB calls, update the numeric arguments without changing the function name or surrounding code.
* Preserve alpha correctly.

## Implementation requirements

* Use the VS Code API rather than a webview.
* Keep the implementation small and dependency-light.
* Do not modify the user's source code unless they use the color picker.
* Include tests for parsing, alpha handling, and source-code replacement.
* Include instructions for running with F5 and packaging as a VSIX.
* Do not modify any files outside the extension project.
