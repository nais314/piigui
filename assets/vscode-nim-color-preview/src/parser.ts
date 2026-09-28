// Pure, vscode-free parser for the Nim color literals used by PiiGUI.
// Works on plain offsets so the extension can build vscode.Range objects and
// tests can run without the VS Code API.

export type Channel = 'r' | 'g' | 'b' | 'a';

export interface RgbValue {
  r: number;
  g: number;
  b: number;
  a: number;
}

// One numeric literal inside a call, positioned in the document text.
export interface RgbComponent {
  channel: Channel;
  start: number;
  end: number;
}

interface HexMatch {
  kind: 'hex';
  start: number;
  end: number;
  text: string;
  value: RgbValue;
  prefix: string; // original "0x" spelling
  suffix: string; // original ".HexColor" spelling
  digitCount: 6 | 8; // 6 -> alpha defaults to 255
}

export interface RgbMatch {
  kind: 'rgb';
  start: number;
  end: number;
  text: string;
  value: RgbValue;
  style: 'positional' | 'named';
  nameSep: '=' | ':'; // named-argument separator
  u8Suffix: boolean; // named arguments carry a trailing N'u8
  components: RgbComponent[]; // r,g,b[,a] in source order
  argCount: 3 | 4;
}

export type ColorMatch = HexMatch | RgbMatch;

interface GuardRange {
  start: number;
  end: number;
}

// Numeric-argument color setter families. HexColor literals are matched
// independently of their enclosing call, so setters not listed here (e.g.
// setBorderColor) still get swatches when fed a .HexColor literal.
const CALL_RE = /\b(setBackGroundColor|setBackgroundColor|setColor|rgbaColor|sdl\.Color)(?![0-9A-Za-z_])\s*\(/gi;
const HEX_RE = /(0[xX])([0-9a-fA-F]{6}|[0-9a-fA-F]{8})\.HexColor\b/g;
const CHANNEL_ORDER: Channel[] = ['r', 'g', 'b', 'a'];

// Regions where colors must not be reported: comments and string literals.
// Nim block comments open with "#[" and close with "]#" (and may nest);
// doc-comment blocks use "##[" ... "]##". Line comments run from "#" to EOL.
export function buildGuardRanges(text: string): GuardRange[] {
  const ranges: GuardRange[] = [];
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (c === '"') {
      if (text.startsWith('"""', i)) {
        const close = text.indexOf('"""', i + 3);
        if (close === -1) {
          ranges.push({ start: i, end: text.length });
          break;
        }
        ranges.push({ start: i, end: close + 3 });
        i = close + 3;
      } else {
        let j = i + 1;
        while (j < text.length) {
          if (text[j] === '\\') {
            j += 2;
            continue;
          }
          if (text[j] === '"') break;
          j++;
        }
        const end = j >= text.length ? text.length : j + 1;
        ranges.push({ start: i, end });
        i = end;
      }
    } else if (text.startsWith('##[', i)) {
      const close = text.indexOf(']##', i + 3);
      if (close === -1) {
        ranges.push({ start: i, end: text.length });
        break;
      }
      ranges.push({ start: i, end: close + 3 });
      i = close + 3;
    } else if (text.startsWith('#[', i)) {
      // "]#" is the canonical closer; also accept "#]" defensively. Track
      // nesting so inner blocks never terminate the outer range.
      let depth = 1;
      let j = i + 2;
      for (; j < text.length; j++) {
        if (text.startsWith('#[', j)) depth++;
        else if (text.startsWith(']#', j) || text.startsWith('#]', j)) {
          depth--;
          if (depth === 0) break;
        }
      }
      const close = j < text.length ? j + 2 : text.length;
      ranges.push({ start: i, end: close });
      if (j >= text.length) break;
      i = close;
    } else if (c === '#') {
      const eol = text.indexOf('\n', i);
      const end = eol === -1 ? text.length : eol;
      ranges.push({ start: i, end });
      i = end;
    } else {
      i++;
    }
  }
  return ranges;
}

function isGuarded(offset: number, guards: GuardRange[]): boolean {
  for (let k = 0; k < guards.length; k++) {
    if (offset >= guards[k].start && offset < guards[k].end) return true;
    if (offset < guards[k].start) break;
  }
  return false;
}

function toByte(value: number): number | undefined {
  if (!Number.isInteger(value) || value < 0 || value > 255) return undefined;
  return value;
}

export function toHex8(value: RgbValue): string {
  const byte = (v: number): string => v.toString(16).padStart(2, '0').toUpperCase();
  return byte(value.r) + byte(value.g) + byte(value.b) + byte(value.a);
}

// Finds the ')' that balances the '(' at openIndex, respecting nesting.
function findClosingParen(text: string, openIndex: number): number {
  let depth = 1;
  for (let j = openIndex + 1; j < text.length; j++) {
    if (text[j] === '(') depth++;
    else if (text[j] === ')') {
      depth--;
      if (depth === 0) return j;
    }
  }
  return -1;
}

function splitTopLevel(text: string, from: number, to: number): Array<{ text: string; start: number; end: number }> {
  const parts: Array<{ text: string; start: number; end: number }> = [];
  let depth = 0;
  let partStart = from;
  for (let j = from; j <= to; j++) {
    const ch = j < to ? text[j] : ',';
    if (ch === '(') depth++;
    else if (ch === ')') depth--;
    else if (ch === ',' && depth === 0) {
      parts.push({ text: text.slice(partStart, j), start: partStart, end: j });
      partStart = j + 1;
    }
  }
  const last = text.slice(partStart, to);
  if (last.trim().length > 0) {
    parts.push({ text: last, start: partStart, end: to });
  }
  return parts;
}

// The tuple form sdl.Color((r:..,g:..,b:..,a:..)) pads the real arguments with
// one enclosing paren pair; peel it when it wraps the whole argument region.
function unwrapOuterTuple(text: string, inner: { text: string; start: number; end: number }): { text: string; start: number; end: number } | undefined {
  const trimmed = inner.text.trim();
  if (!trimmed.startsWith('(') || !trimmed.endsWith(')')) return undefined;
  const lead = inner.text.indexOf(trimmed);
  const openAbs = inner.start + lead;
  const closeAbs = inner.end - 1;
  if (findClosingParen(text, openAbs) !== closeAbs) return undefined;
  return {
    text: text.slice(openAbs + 1, closeAbs),
    start: openAbs + 1,
    end: closeAbs,
  };
}

function parseRgbMatch(
  text: string,
  nameStart: number,
  openIndex: number,
  closeIndex: number,
  guards: GuardRange[]
): RgbMatch | undefined {
  if (isGuarded(nameStart, guards)) return undefined;

  let content = {
    text: text.slice(openIndex + 1, closeIndex),
    start: openIndex + 1,
    end: closeIndex,
  };
  const unwrapped = unwrapOuterTuple(text, content);
  if (unwrapped) content = unwrapped;

  const parts = splitTopLevel(text, content.start, content.end);
  if (parts.length < 3 || parts.length > 4) return undefined;

  // Every argument must be a bare integer (positional) or a named channel
  // (r=.. / r:..'u8). Mixed forms and unknown names are rejected.
  let style: 'positional' | 'named' = 'positional';
  let nameSep: '=' | ':' = '=';
  let u8Suffix = false;
  const components: RgbComponent[] = [];
  for (let k = 0; k < parts.length; k++) {
    const part = parts[k].text.trim();
    const lead = parts[k].start + parts[k].text.indexOf(part);
    const positional = /^\d+$/.exec(part);
    const namedEq = /^([rgba])\s*=\s*(\d+)$/i.exec(part);
    const namedColon = /^([rgba])\s*:\s*(\d+)\s*('[a-zA-Z][a-zA-Z0-9]{0,7})?$/i.exec(part);
    let digits: string;
    let digitPos = 0;
    if (positional) {
      if (style !== 'positional' && k > 0) return undefined;
      style = 'positional';
      digits = positional[0];
    } else if (namedEq) {
      if (style !== 'named' && k > 0) return undefined;
      style = 'named';
      nameSep = '=';
      digits = namedEq[2];
      digitPos = part.indexOf(digits, part.indexOf('='));
    } else if (namedColon) {
      if (style !== 'named' && k > 0) return undefined;
      style = 'named';
      nameSep = ':';
      if (namedColon[3]) u8Suffix = true;
      digits = namedColon[2];
      digitPos = part.indexOf(digits, part.indexOf(':'));
    } else {
      return undefined;
    }
    const value = toByte(Number(digits));
    if (value === undefined) return undefined;
    const digitStart = lead + (positional ? 0 : digitPos);
    components.push({ channel: 'r' as Channel, start: digitStart, end: digitStart + digits.length });
  }

  // Assign channels: positional maps by argument order; named by field name.
  const seen = new Set<Channel>();
  for (let k = 0; k < components.length; k++) {
    let channel: Channel;
    if (style === 'positional') {
      channel = CHANNEL_ORDER[k];
    } else {
      const part = parts[k].text.trim();
      const named = /^([rgba])\s*[=:]/.exec(part);
      if (!named) return undefined;
      channel = named[1].toLowerCase() as Channel;
      if (seen.has(channel)) return undefined; // duplicate channel
    }
    seen.add(channel);
    components[k].channel = channel;
  }

  if (style === 'named' && (!seen.has('r') || !seen.has('g') || !seen.has('b'))) {
    return undefined;
  }
  // Positional calls can only have 'a' when they carry 4 arguments already.
  if (seen.has('a') && components.length !== 4) return undefined;

  const value: RgbValue = {
    r: 0,
    g: 0,
    b: 0,
    a: components.length === 3 ? 255 : 0,
  };
  for (const comp of components) {
    value[comp.channel] = Number(text.slice(comp.start, comp.end));
  }

  return {
    kind: 'rgb' as const,
    start: nameStart,
    end: closeIndex + 1,
    text: text.slice(nameStart, closeIndex + 1),
    value,
    style,
    nameSep,
    u8Suffix,
    components,
    argCount: components.length === 4 ? 4 : 3,
  };
}

// Scans the whole document for recognized color expressions. Matches inside
// comments or string literals are skipped so dead code never shows swatches.
export function parseColors(text: string): ColorMatch[] {
  const guards = buildGuardRanges(text);
  const matches: ColorMatch[] = [];

  HEX_RE.lastIndex = 0;
  let res: RegExpExecArray | null;
  while ((res = HEX_RE.exec(text)) !== null) {
    const digits = res[2];
    const n = parseInt(digits, 16);
    const is8 = digits.length === 8;
    const match: HexMatch = {
      kind: 'hex',
      start: res.index,
      end: res.index + res[0].length,
      text: res[0],
      value: {
        // 8-digit literals carry RGBA in the full 32 bits; 6-digit literals
        // are plain RGB in the low 24 bits and default alpha to 255.
        r: (n >>> (is8 ? 24 : 16)) & 0xff,
        g: (n >>> (is8 ? 16 : 8)) & 0xff,
        b: (n >>> (is8 ? 8 : 0)) & 0xff,
        a: is8 ? n & 0xff : 255,
      },
      prefix: res[1],
      suffix: '.HexColor',
      digitCount: is8 ? 8 : 6,
    };
    if (!isGuarded(match.start, guards)) matches.push(match);
  }

  CALL_RE.lastIndex = 0;
  while ((res = CALL_RE.exec(text)) !== null) {
    const openIndex = res.index + res[0].lastIndexOf('(');
    const closeIndex = findClosingParen(text, openIndex);
    if (closeIndex === -1) {
      CALL_RE.lastIndex = openIndex + 1;
      continue;
    }
    const match = parseRgbMatch(text, res.index, openIndex, closeIndex, guards);
    if (match !== undefined) matches.push(match);
    CALL_RE.lastIndex = closeIndex + 1;
  }

  matches.sort((a, b) => a.start - b.start);
  return matches;
}

export function findMatchAt(text: string, start: number, end: number): ColorMatch | undefined {
  return parseColors(text).find((m) => m.start === start && m.end === end);
}

function hexReplacement(match: HexMatch, c: RgbValue): string {
  // Keep six hex digits for an opaque pick on a 6-digit literal; otherwise
  // write the full RRGGBBAA so alpha is never dropped.
  const eight = toHex8(c);
  const width = match.digitCount === 6 && c.a === 255 ? 6 : 8;
  return match.prefix + eight.slice(0, width) + match.suffix;
}

function digitString(c: RgbValue, channel: Channel): string {
  return String(c[channel]);
}

function alphaToken(match: RgbMatch, a: number): string {
  if (match.style === 'positional') return `, ${a}`;
  if (match.nameSep === '=') return `, a=${a}`;
  return `, a:${a}${match.u8Suffix ? "'u8" : ''}`;
}

// Splices the new decimal digits over the original numeric literals only,
// leaving the function name, separators, named args and surrounding code as-is.
// A translucent pick on a three-argument call appends the alpha argument.
export function buildReplacement(match: ColorMatch, c: RgbValue): string {
  if (match.kind === 'hex') return hexReplacement(match, c);
  const text = match.text;
  let out = '';
  let cursor = 0;
  for (const comp of match.components) {
    out += text.slice(cursor, comp.start - match.start);
    out += digitString(c, comp.channel);
    cursor = comp.end - match.start;
    if ((match.argCount as number) === 3 && c.a !== 255 && comp.channel === 'b') {
      out += alphaToken(match, c.a);
    }
  }
  out += text.slice(cursor);
  return out;
}