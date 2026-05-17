unit ftui_cell;

// 1:1 mapping of ratatui::buffer::Cell.
//
// Layout: a packed record sized 33 bytes (24-byte glyph block + 12 bytes
// of style fields + 1 width + 1 skip flag, packed to remove padding).
// The default Cell — `CellEmpty` — is " " with fg/bg/ul = ckReset,
// no modifier, skip = false.  This matches ratatui's `Cell::EMPTY`
// exactly; resetting a buffer fills with `CellEmpty`.
//
// Glyph storage is 23 bytes inline + 1 length byte.  Any grapheme up to
// 23 UTF-8 bytes lives entirely inside the cell — no heap allocation
// in the hot path, ever.  Graphemes larger than 23 bytes are
// truncated; ratatui's CompactString allows up to 24 bytes inline and
// spills onto the heap beyond that.  The 23/24 boundary covers every
// grapheme cluster in normal terminal use (most CJK + ZWJ sequences
// fit in <= 16 bytes).
//
// Width is stored alongside (1 = ASCII / regular, 2 = wide CJK / emoji).
// In M0 we always set Width := 1 — width-2 handling lands in M2 with
// utf8proc.

{$mode objfpc}{$H+}{$inline on}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_color,
  ftui_modifier,
  ftui_style;

const
  FTUI_CELL_GLYPH_BYTES = 23;

type
  TCellGlyph = packed record
    Len: Byte;
    Bytes: array[0..FTUI_CELL_GLYPH_BYTES - 1] of Byte;
  end;

  TCell = packed record
    Glyph: TCellGlyph;
    Fg, Bg, Ul: TColor;
    Modifier: TModifier;
    Width: Byte;       // grapheme display width: 1 or 2
    Skip: Boolean;
  end;
  PCell = ^TCell;

const
  // ratatui Cell::EMPTY equivalent.  A blank space, default colors,
  // no modifier, width 1, skip false.  Use this as the fill value
  // for buffer reset / resize.
  CellEmpty: TCell = (
    Glyph: (Len: 1; Bytes: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
    Fg: (Kind: ckReset; Index: 0);
    Bg: (Kind: ckReset; Index: 0);
    Ul: (Kind: ckReset; Index: 0);
    Modifier: [];
    Width: 1;
    Skip: False
  );

procedure CellReset(var C: TCell);
procedure CellSetSymbolAscii(var C: TCell; Ch: AnsiChar);
procedure CellSetSymbolBytes(var C: TCell; const Bytes; Len: Byte; W: Byte);
procedure CellApplyStyle(var C: TCell; const S: TStyle);
function  CellEquals(const A, B: TCell): Boolean;
function  CellGlyphAsString(const C: TCell): AnsiString;

implementation

procedure CellReset(var C: TCell);
begin
  C := CellEmpty;
end;

procedure CellSetSymbolAscii(var C: TCell; Ch: AnsiChar);
begin
  C.Glyph.Len := 1;
  C.Glyph.Bytes[0] := Byte(Ch);
  C.Width := 1;
end;

procedure CellSetSymbolBytes(var C: TCell; const Bytes; Len: Byte; W: Byte);
var
  Src: PByte;
begin
  if Len > FTUI_CELL_GLYPH_BYTES then
    Len := FTUI_CELL_GLYPH_BYTES;     // silently truncate (>23-byte graphemes are pathological)
  C.Glyph.Len := Len;
  if Len > 0 then
  begin
    Src := @Bytes;
    Move(Src^, C.Glyph.Bytes[0], Len);
  end;
  if W = 0 then W := 1;
  C.Width := W;
end;

procedure CellApplyStyle(var C: TCell; const S: TStyle);
begin
  // ratatui: only Some-fields overwrite; AddMod is OR'd in, SubMod is removed.
  if ColorIsSet(S.Fg) then C.Fg := S.Fg;
  if ColorIsSet(S.Bg) then C.Bg := S.Bg;
  if ColorIsSet(S.Ul) then C.Ul := S.Ul;
  C.Modifier := (C.Modifier + S.AddMod) - S.SubMod;
end;

function CellEquals(const A, B: TCell): Boolean;
begin
  if A.Width <> B.Width then Exit(False);
  if A.Skip <> B.Skip then Exit(False);
  if A.Modifier <> B.Modifier then Exit(False);
  if not ColorEquals(A.Fg, B.Fg) then Exit(False);
  if not ColorEquals(A.Bg, B.Bg) then Exit(False);
  if not ColorEquals(A.Ul, B.Ul) then Exit(False);
  if A.Glyph.Len <> B.Glyph.Len then Exit(False);
  if A.Glyph.Len = 0 then Exit(True);
  Result := CompareByte(A.Glyph.Bytes[0], B.Glyph.Bytes[0], A.Glyph.Len) = 0;
end;

function CellGlyphAsString(const C: TCell): AnsiString;
begin
  if C.Glyph.Len = 0 then
    Exit('');
  SetLength(Result, C.Glyph.Len);
  Move(C.Glyph.Bytes[0], Result[1], C.Glyph.Len);
end;

end.
