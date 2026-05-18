unit ftui_event;

// Input event types — what InputParser produces and Terminal hands
// back from PollEvent.
//
// Scope (matches cli888):
//   - Key events: printable chars + Esc/Enter/Tab/BackTab/Backspace/
//     Delete/arrows/Home/End/PageUp/PageDown/Insert/F1..F12
//   - Mouse: scroll wheel up/down + single left click (cli888 uses
//     ScrollUp 7, ScrollDown 5, LeftDown 1)
//   - Resize: terminal size changed (delivered after SIGWINCH)
//
// Out of scope (cli888 uses 0):
//   - Bracketed paste (TEventKind would need evPaste)
//   - Focus events (gain/lost)
//   - Kitty keyboard protocol (key release, repeat, super-modifiers)
//   - Mouse drag, hover, middle/right click
//
// All payload records are `packed record` so the union variant
// dispatch costs one byte and the whole TEvent passes by register.

{$mode objfpc}{$H+}{$inline on}
{$packenum 1}
{$packset 2}

interface

type
  TEventKind = (evNone, evKey, evMouse, evResize);

  TKeyCodeKind = (
    kcChar, kcEnter, kcEsc, kcTab, kcBackTab, kcBackspace, kcDelete,
    kcLeft, kcRight, kcUp, kcDown,
    kcHome, kcEnd, kcPageUp, kcPageDown,
    kcInsert, kcF
  );

  TKeyModifier = (kmCtrl, kmAlt, kmShift);
  TKeyModifiers = set of TKeyModifier;

  TKeyEvent = packed record
    Code: TKeyCodeKind;
    Ch: LongWord;          // for kcChar (UCS-4 codepoint)
    F: Byte;               // for kcF: 1..12
    Modifiers: TKeyModifiers;
  end;

  TMouseEventKind = (mkScrollUp, mkScrollDown, mkLeftDown);
  TMouseEvent = packed record
    Kind: TMouseEventKind;
    X, Y: Word;
    Modifiers: TKeyModifiers;
  end;

  TResizeEvent = packed record
    Width, Height: Word;
  end;

  TEvent = record
    Kind: TEventKind;
    case Byte of
      0: (Key: TKeyEvent);
      1: (Mouse: TMouseEvent);
      2: (Resize: TResizeEvent);
  end;

function NoneEvent: TEvent; inline;
function KeyCharEvent(Ch: LongWord; Mods: TKeyModifiers): TEvent;
function KeyCodeEvent(Code: TKeyCodeKind; Mods: TKeyModifiers): TEvent;
function KeyFunctionEvent(F: Byte; Mods: TKeyModifiers): TEvent;
function MouseEvent(Kind: TMouseEventKind; X, Y: Word; Mods: TKeyModifiers): TEvent;
function ResizeEvent(W, H: Word): TEvent;

implementation

function NoneEvent: TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evNone;
end;

function KeyCharEvent(Ch: LongWord; Mods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evKey;
  Result.Key.Code := kcChar;
  Result.Key.Ch := Ch;
  Result.Key.Modifiers := Mods;
end;

function KeyCodeEvent(Code: TKeyCodeKind; Mods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evKey;
  Result.Key.Code := Code;
  Result.Key.Modifiers := Mods;
end;

function KeyFunctionEvent(F: Byte; Mods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evKey;
  Result.Key.Code := kcF;
  Result.Key.F := F;
  Result.Key.Modifiers := Mods;
end;

function MouseEvent(Kind: TMouseEventKind; X, Y: Word; Mods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evMouse;
  Result.Mouse.Kind := Kind;
  Result.Mouse.X := X;
  Result.Mouse.Y := Y;
  Result.Mouse.Modifiers := Mods;
end;

function ResizeEvent(W, H: Word): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evResize;
  Result.Resize.Width := W;
  Result.Resize.Height := H;
end;

end.
