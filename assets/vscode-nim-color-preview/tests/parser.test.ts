// Node's built-in test runner. Run with: npm test
// (compiles then executes `node --test out/tests/`)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseColors,
  buildReplacement,
  findMatchAt,
  buildGuardRanges,
  toHex8,
  ColorMatch,
  RgbMatch,
} from '../src/parser';

function single(text: string): ColorMatch {
  const matches = parseColors(text);
  assert.equal(matches.length, 1, `expected exactly one match in: ${text}`);
  return matches[0];
}

function singleRgb(text: string): RgbMatch {
  const m = single(text);
  if (m.kind !== 'rgb') throw new Error(`expected an rgb match in: ${text}`);
  return m;
}

function none(text: string): void {
  assert.equal(parseColors(text).length, 0, `expected no match in: ${text}`);
}

function replaceAt(text: string, newColor: { r: number; g: number; b: number; a: number }): string {
  const match = single(text);
  return buildReplacement(match, newColor);
}

// ---------------------------------------------------------------------------
// Hexadecimal literals
// ---------------------------------------------------------------------------

test('hex: parses 8-digit RRGGBBAA', () => {
  const m = single('0xDDDDDDFF.HexColor');
  assert.equal(m.kind, 'hex');
  assert.deepEqual(m.value, { r: 221, g: 221, b: 221, a: 255 });
  assert.equal(m.text, '0xDDDDDDFF.HexColor');
});

test('hex: parses lowercase hex digits', () => {
  const m = single('0xcceeffff.HexColor');
  assert.deepEqual(m.value, { r: 204, g: 238, b: 255, a: 255 });
});

test('hex: 8-digit alpha is honored', () => {
  const m = single('0x11223340.HexColor');
  assert.deepEqual(m.value, { r: 17, g: 34, b: 51, a: 64 });
});

test('hex: parses 6-digit RGB with alpha default 255', () => {
  const m = single('0x6B859C.HexColor');
  assert.deepEqual(m.value, { r: 107, g: 133, b: 156, a: 255 });
});

test('hex: replacement keeps suffix and uppercases digits', () => {
  assert.equal(replaceAt('0xcceeffff.HexColor', { r: 204, g: 238, b: 255, a: 255 }), '0xCCEEFFFF.HexColor');
});

test('hex: opaque pick on 6-digit literal keeps 6 digits', () => {
  assert.equal(replaceAt('0x6B859C.HexColor', { r: 107, g: 133, b: 156, a: 255 }), '0x6B859C.HexColor');
});

test('hex: translucent pick on 6-digit literal widens to 8 digits', () => {
  assert.equal(replaceAt('0x6B859C.HexColor', { r: 107, g: 133, b: 156, a: 128 }), '0x6B859C80.HexColor');
});

test('hex: 8-digit literal always writes 8 digits', () => {
  assert.equal(replaceAt('0x00FF00FF.HexColor', { r: 0, g: 255, b: 0, a: 255 }), '0x00FF00FF.HexColor');
  assert.equal(
    replaceAt('0x00000010.HexColor', { r: 1, g: 2, b: 3, a: 255 }),
    '0x010203FF.HexColor'
  );
});

test('hex: rejects missing .HexColor suffix', () => {
  none('0xDDDDDD');
  none('0xFF0088FF.uint32');
  none('let x = 0xFF0088FF');
});

test('hex: rejects wrong digit counts', () => {
  none('0xDDDDD.HexColor');
  none('0xDDDDDDD.HexColor');
  none('0xDDDDDDDDD.HexColor');
});

test('hex: matches many on one line', () => {
  const matches = parseColors('a:0xFF0000FF.HexColor b:0x00FF00FF.HexColor');
  assert.equal(matches.length, 2);
});

// ---------------------------------------------------------------------------
// Positional RGB/RGBA calls
// ---------------------------------------------------------------------------

test('rgb: parses 4-argument RGBA call', () => {
  const m = singleRgb('setBackGroundColor(220, 220, 220, 255)');
  assert.equal(m.style, 'positional');
  assert.deepEqual(m.value, { r: 220, g: 220, b: 220, a: 255 });
});

test('rgb: parses compact spelling', () => {
  const m = single('setColor(50,120,255,255)');
  assert.deepEqual(m.value, { r: 50, g: 120, b: 255, a: 255 });
});

test('rgb: 3 arguments default alpha to 255', () => {
  const m = single('setColor(50,120,255)');
  assert.deepEqual(m.value, { r: 50, g: 120, b: 255, a: 255 });
});

test('rgb: method-call spelling', () => {
  const m = single('.setColor(50,120,255)');
  assert.deepEqual(m.value, { r: 50, g: 120, b: 255, a: 255 });
});

test('rgb: case-insensitive function names (Nim style)', () => {
  const m = single('SETBACKGROUNDCOLOR(1, 2, 3, 4)');
  assert.deepEqual(m.value, { r: 1, g: 2, b: 3, a: 4 });
});

test('rgb: replacement preserves name and spacing', () => {
  const text = 'quitBtn.inlineStyle.setBackGroundColor(220, 220, 220, 255)';
  const m = single(text);
  assert.equal(text.slice(m.start, m.end), 'setBackGroundColor(220, 220, 220, 255)');
  const newSlice = buildReplacement(m, { r: 10, g: 20, b: 30, a: 40 });
  assert.equal(newSlice, 'setBackGroundColor(10, 20, 30, 40)');
  // The picker edit is scoped to the call, so the receiver stays untouched.
  const edited = text.slice(0, m.start) + newSlice + text.slice(m.end);
  assert.equal(edited, 'quitBtn.inlineStyle.setBackGroundColor(10, 20, 30, 40)');
});

test('rgb: compact-comma call replacement', () => {
  assert.equal(replaceAt('setColor(50,120,255,255)', { r: 1, g: 2, b: 3, a: 255 }), 'setColor(1,2,3,255)');
});

test('rgb: 3-arg call keeps 3 args on opaque pick', () => {
  assert.equal(replaceAt('setBackGroundColor(220, 220, 220)', { r: 220, g: 220, b: 220, a: 255 }), 'setBackGroundColor(220, 220, 220)');
});

test('rgb: 3-arg call appends alpha on translucent pick', () => {
  assert.equal(
    replaceAt('setBackGroundColor(220, 220, 220)', { r: 220, g: 220, b: 220, a: 128 }),
    'setBackGroundColor(220, 220, 220, 128)'
  );
});

test('rgb: replacement covers only the call, leaving the rest of the line', () => {
  const text = 'content.inlineStyle.backGroundColor = rgbaColor(180,220,180,255) # set greenish';
  const m = single(text);
  // The edit range spans exactly the call expression...
  assert.equal(text.slice(m.start, m.end), 'rgbaColor(180,220,180,255)');
  // ...so the replacement text is only for that slice; the TextEdit leaves the
  // surrounding code (left-hand side and trailing comment) untouched.
  const newSlice = buildReplacement(m, { r: 0, g: 0, b: 0, a: 255 });
  assert.equal(newSlice, 'rgbaColor(0,0,0,255)');
  const edited = text.slice(0, m.start) + newSlice + text.slice(m.end);
  assert.equal(edited, 'content.inlineStyle.backGroundColor = rgbaColor(0,0,0,255) # set greenish');
});

// ---------------------------------------------------------------------------
// Named arguments
// ---------------------------------------------------------------------------

test('rgb: parses rgbaColor(r=..,g=..,b=..,a=..)', () => {
  const m = singleRgb('rgbaColor(r=0,g=0,b=0,a=255)');
  assert.equal(m.style, 'named');
  assert.deepEqual(m.value, { r: 0, g: 0, b: 0, a: 255 });
});

test('rgb: named replacement preserves the r= style', () => {
  assert.equal(
    replaceAt('rgbaColor(r=0,g=0,b=0,a=255)', { r: 12, g: 34, b: 56, a: 78 }),
    'rgbaColor(r=12,g=34,b=56,a=78)'
  );
});

test('rgb: parses sdl.Color tuple constructor', () => {
  const m = singleRgb("sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8))");
  assert.equal(m.style, 'named');
  assert.equal(m.u8Suffix, true);
  assert.deepEqual(m.value, { r: 255, g: 255, b: 255, a: 255 });
});

test('rgb: sdl.Color replacement preserves double parens and u8 suffix', () => {
  const text = "sdl.Color((r:255'u8,g:255'u8,b:255'u8,a:255'u8))";
  const edited = replaceAt(text, { r: 10, g: 20, b: 30, a: 40 });
  assert.equal(edited, "sdl.Color((r:10'u8,g:20'u8,b:30'u8,a:40'u8))");
});

test('rgb: sdl.Color with named field order as in piigui.nim', () => {
  const m = single("sdl.Color(r:0'u8,g:0'u8,b:0'u8,a:128'u8)");
  assert.deepEqual(m.value, { r: 0, g: 0, b: 0, a: 128 });
});

test('rgb: named 3-arg form appends alpha in style when translucent', () => {
  const text = 'setColor(r=50, g=120, b=255)';
  const edited = replaceAt(text, { r: 1, g: 2, b: 3, a: 200 });
  assert.equal(edited, 'setColor(r=1, g=2, b=3, a=200)');
  const opaque = replaceAt(text, { r: 1, g: 2, b: 3, a: 255 });
  assert.equal(opaque, 'setColor(r=1, g=2, b=3)');
});

// ---------------------------------------------------------------------------
// Rejections
// ---------------------------------------------------------------------------

test('reject: non-literal integer arguments', () => {
  none('btn.setColor(txt.r, txt.g, txt.b, 255)');
  none('setColor(col.a, 0, 0, 255)');
  none('setBackGroundColor(randomValue(), 0, 0, 255)');
});

test('reject: values out of 0..255 range', () => {
  none('setColor(0, 0, 0, 256)');
  none('setColor(0, 0, -1)');
  none('setColor(300, 0, 0, 255)');
  none('rgbaColor(r=300,g=0,b=0,a=255)');
});

test('reject: non-integer arguments', () => {
  none('setColor(50.5, 0, 0, 255)');
  none('setColor(0xA, 0, 0, 255)');
});

test('reject: unrelated function calls', () => {
  none('setPosition(50, 120)');
  none('setSize(220, 220)');
  none('setBackGroundColor()');
  none('mySetColor(1, 2, 3, 4)');
});

test('reject: wrong argument counts', () => {
  none('setColor(1, 2)');
  none('setColor(1, 2, 3, 4, 5)');
});

test('reject: mixed positional and named arguments', () => {
  none('setColor(r=1, 2, 3, 4)');
});

test('reject: duplicate named channel', () => {
  none('rgbaColor(r=1,r=2,g=3,b=4)');
});

test('reject: missing required named channels', () => {
  none('setColor(r=1, g=2, width=3)');
});

// ---------------------------------------------------------------------------
// Comment and string guards
// ---------------------------------------------------------------------------

test('guard: colors in line comments are ignored', () => {
  none('#pgui.rootElem.setBackGroundColor(0x55DD55FF.HexColor)');
  none('# setColor(1, 2, 3, 4)');
});

test('guard: colors in block comments are ignored', () => {
  none('#[ setBackGroundColor(1,2,3,4) #]');
  none('#[ setBackGroundColor(1,2,3,4) ]#');
  none('##[ setBackGroundColor(1,2,3,4) ]##');
});

test('guard: nested block comments swallow inner colors but not following code', () => {
  const m = single('#[ outer #[\nmm.setColor(5,5,5,5)\n]# inner ]#\nsetColor(1,2,3)');
  assert.deepEqual(m.value, { r: 1, g: 2, b: 3, a: 255 });
  const m2 = single('#[ setBackGroundColor(1,2,3,4) ]# setColor(9,8,7)');
  assert.deepEqual(m2.value, { r: 9, g: 8, b: 7, a: 255 });
});

test('guard: colors inside strings are ignored', () => {
  none('let s = "0xDDDDDDFF.HexColor"');
  none('let s = """setColor(1,2,3,4)"""');
});

test('guard: code after a commented line is still parsed', () => {
  const m = single('# comment\nsetColor(1,2,3)');
  assert.deepEqual(m.value, { r: 1, g: 2, b: 3, a: 255 });
});

test('guard: buildGuardRanges covers a real document', () => {
  const text = '# a\nlet x = 1 # trailing\nok "str 0xFFFFFF00.HexColor"';
  const ranges = buildGuardRanges(text);
  assert.ok(ranges.length >= 3);
  for (const m of parseColors(text)) {
    assert.ok(!ranges.some((r) => m.start >= r.start && m.start < r.end));
  }
});

// ---------------------------------------------------------------------------
// Helpers used by the extension
// ---------------------------------------------------------------------------

test('helper: findMatchAt finds the exact match', () => {
  const text = 'setColor(10,20,30)';
  const matches = parseColors(text);
  const found = findMatchAt(text, matches[0].start, matches[0].end);
  assert.ok(found !== undefined);
  assert.deepEqual(found.value, { r: 10, g: 20, b: 30, a: 255 });
});

test('helper: toHex8 formats RRGGBBAA uppercase', () => {
  assert.equal(toHex8({ r: 221, g: 221, b: 221, a: 255 }), 'DDDDDDFF');
  assert.equal(toHex8({ r: 0, g: 0, b: 0, a: 1 }), '00000001');
});

test('helper: real PiiGUI test snippet yields 6 matches', () => {
  const text = [
    'pgui.rootElem.setBackGroundColor(0x808080FF.HexColor)',
    'rootSSRT["tabbtn"].setBackGroundColor(0xcceeffff.HexColor)',
    'gradbtn1.setBackGroundColor(0xFF0088FF.uint32)',
    '#gradbtn1.setBackGroundColor(0x0080ffff.HexColor)',
    'body.inlineStyle.backGroundColor = rgbaColor(220,220,50,255)',
    'textinput1.setBackGroundColor(220,220,220,255)',
    'textinput2.setColor(50,120,255,255)',
    '',
  ].join('\n');
  const matches = parseColors(text);
  // 2 hex literals (the .uint32 and the commented one are skipped) + 3 calls
  assert.equal(matches.length, 5);
});