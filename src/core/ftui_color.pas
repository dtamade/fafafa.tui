unit ftui_color;

// 1:1 mapping of ratatui::style::Color into a 4-byte packed record.
//
// ckUnset / ckReset / ckIndexed / ckRgb cover the entire ratatui surface:
//
//   ckUnset   ── ratatui Option<Color>::None equivalent.  Patch sees this
//                as "fall through to the receiver's current value".
//   ckReset   ── ratatui Color::Reset.  Tells the backend to emit SGR 39/49
//                (default fg/bg) instead of any specific color.
//   ckIndexed ── 0..255.  The first 16 entries match ratatui's named
//                colors (clBlack..clWhite); 16..255 are 256-color palette.
//   ckRgb     ── 24-bit truecolor; backend emits SGR 38;2;r;g;b.
//
// All constructors return by value; the record is 4 bytes (1 + 3) and
// passes in a register on x86-64.  Hot paths must take TColor by value
// or `const` reference — never as `var` or via heap.

{$mode objfpc}{$H+}{$inline on}
{$packenum 1}        // enum fields take 1 byte (default is 4)

interface

type
  TColorKind = (ckUnset, ckReset, ckIndexed, ckRgb);

  TColor = packed record
    Kind: TColorKind;
    case Byte of
      0: (Index: Byte);             // ckIndexed
      1: (R, G, B: Byte);           // ckRgb
  end;

function UnsetColor: TColor; inline;
function ResetColor: TColor; inline;
function IndexedColor(I: Byte): TColor; inline;
function RgbColor(R, G, B: Byte): TColor; inline;

function ColorEquals(const A, B: TColor): Boolean; inline;
function ColorIsSet(const C: TColor): Boolean; inline;

const
  // Named colors map to indexed 0..15 — matches ratatui exactly.
  clBlack:        TColor = (Kind: ckIndexed; Index: 0);
  clRed:          TColor = (Kind: ckIndexed; Index: 1);
  clGreen:        TColor = (Kind: ckIndexed; Index: 2);
  clYellow:       TColor = (Kind: ckIndexed; Index: 3);
  clBlue:         TColor = (Kind: ckIndexed; Index: 4);
  clMagenta:      TColor = (Kind: ckIndexed; Index: 5);
  clCyan:         TColor = (Kind: ckIndexed; Index: 6);
  clGray:         TColor = (Kind: ckIndexed; Index: 7);
  clDarkGray:     TColor = (Kind: ckIndexed; Index: 8);
  clLightRed:     TColor = (Kind: ckIndexed; Index: 9);
  clLightGreen:   TColor = (Kind: ckIndexed; Index: 10);
  clLightYellow:  TColor = (Kind: ckIndexed; Index: 11);
  clLightBlue:    TColor = (Kind: ckIndexed; Index: 12);
  clLightMagenta: TColor = (Kind: ckIndexed; Index: 13);
  clLightCyan:    TColor = (Kind: ckIndexed; Index: 14);
  clWhite:        TColor = (Kind: ckIndexed; Index: 15);

implementation

function UnsetColor: TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckUnset;
end;

function ResetColor: TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckReset;
end;

function IndexedColor(I: Byte): TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckIndexed;
  Result.Index := I;
end;

function RgbColor(R, G, B: Byte): TColor;
begin
  Result.Kind := ckRgb;
  Result.R := R;
  Result.G := G;
  Result.B := B;
end;

function ColorEquals(const A, B: TColor): Boolean;
var
  PA, PB: PLongWord;
begin
  // packed record is 4 bytes — compare as a single LongWord.  This
  // sidesteps the kind dispatch entirely on the hot path.
  PA := @A;
  PB := @B;
  Result := PA^ = PB^;
end;

function ColorIsSet(const C: TColor): Boolean;
begin
  Result := C.Kind <> ckUnset;
end;

end.
