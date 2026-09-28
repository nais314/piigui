// Activating entry point: registers the Nim DocumentColorProvider that feeds
// the native VS Code color picker and applies format-preserving edits.
import * as vscode from 'vscode';
import {
  buildReplacement,
  findMatchAt,
  parseColors,
  toHex8,
  ColorMatch,
} from './parser';

function toColor(match: ColorMatch): vscode.Color {
  return new vscode.Color(
    match.value.r / 255,
    match.value.g / 255,
    match.value.b / 255,
    match.value.a / 255
  );
}

function newRgbValue(color: vscode.Color): { r: number; g: number; b: number; a: number } {
  return {
    r: Math.round(color.red * 255),
    g: Math.round(color.green * 255),
    b: Math.round(color.blue * 255),
    a: Math.round(color.alpha * 255),
  };
}

export function activate(context: vscode.ExtensionContext): void {
  const provider: vscode.DocumentColorProvider = {
    provideDocumentColors(
      document: vscode.TextDocument,
      token: vscode.CancellationToken
    ): vscode.ColorInformation[] {
      const text = document.getText();
      const infos: vscode.ColorInformation[] = [];
      for (const match of parseColors(text)) {
        if (token.isCancellationRequested) break;
        const range = new vscode.Range(
          document.positionAt(match.start),
          document.positionAt(match.end)
        );
        infos.push(new vscode.ColorInformation(range, toColor(match)));
      }
      return infos;
    },

    provideColorPresentations(
      color: vscode.Color,
      context: { document: vscode.TextDocument; range: vscode.Range },
      token: vscode.CancellationToken
    ): vscode.ColorPresentation[] {
      if (token.isCancellationRequested) return [];
      const text = context.document.getText();
      const start = context.document.offsetAt(context.range.start);
      const end = context.document.offsetAt(context.range.end);
      const match = findMatchAt(text, start, end);
      if (match === undefined) return [];

      const value = newRgbValue(color);
      const presentation = new vscode.ColorPresentation('#' + toHex8(value));
      presentation.textEdit = new vscode.TextEdit(
        context.range,
        buildReplacement(match, value)
      );
      return [presentation];
    },
  };

  // registerColorProvider replaced registerDocumentColorProvider across VS Code
  // releases; accept both so the extension works on older and newer engines.
  const languagesApi = vscode.languages as unknown as {
    registerColorProvider?(
      selector: vscode.DocumentSelector,
      provider: vscode.DocumentColorProvider
    ): vscode.Disposable;
    registerDocumentColorProvider?(
      selector: vscode.DocumentSelector,
      provider: vscode.DocumentColorProvider
    ): vscode.Disposable;
  };
  const register =
    languagesApi.registerColorProvider ?? languagesApi.registerDocumentColorProvider;
  if (register === undefined) {
    throw new Error('Nim Color Preview: this VS Code version has no color provider API.');
  }

  context.subscriptions.push(
    register({ language: 'nim' }, provider)
  );
}

export function deactivate(): void {
  // No resources to release; registration lifecycle is owned by the context.
}