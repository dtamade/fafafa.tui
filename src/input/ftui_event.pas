unit ftui_event;

// Input event types — TTerminal.PollEvent produces these.
//
// Mouse model (stable contract):
//   mkDown / mkUp / mkMoved / mkDrag / mkScrollUp / mkScrollDown
//   All events carry 0-based cell coordinates, button, and modifiers.
//   Motion tracking (CSI ?1003h) is enabled automatically by TTerminal.
//
// Keyboard model:
//   17 KeyCodeKind values + UCS-4 codepoint for kcChar.
//   CSI u (kitty protocol) supported for Shift+Enter etc.
//
// Resize:
//   Delivered after SIGWINCH; buffers already resized by TTerminal.

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

  TMouseEventKind = (mkDown, mkUp, mkMoved, mkDrag, mkScrollUp, mkScrollDown);
  TMouseButton = (mbLeft, mbMiddle, mbRight, mbNone);

  TMouseEvent = packed record
    Kind: TMouseEventKind;
    Button: TMouseButton;
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
function MouseEvent(Kind: TMouseEventKind; Btn: TMouseButton; X, Y: Word; Mods: TKeyModifiers): TEvent;
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

function MouseEvent(Kind: TMouseEventKind; Btn: TMouseButton; X, Y: Word; Mods: TKeyModifiers): TEvent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := evMouse;
  Result.Mouse.Kind := Kind;
  Result.Mouse.Button := Btn;
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
