unit ftui_block;

// 1:1-ish port of ratatui Block, scoped to the cli888 surface.
//
// Supports:
//   - Borders: any subset of {top, right, bottom, left}
//     (cli888 uses ALL/BOTTOM/TOP/RIGHT, every combination tested)
//   - Single Title (left-aligned, drawn over the top edge)
//   - Three styles: Style (whole area), BorderStyle (border cells),
//     TitleStyle (title cells)
//   - Inner: shrinks Area by border bits
//
// Out of scope (cli888 uses 0 of each):
//   - BorderType (rounded/double/thick) — Plain only
//   - Padding — callers do their own with Rect.Inner
//   - title_alignment center/right — left only
//   - Multiple titles
//   - Title at bottom
//
// Render order matches ratatui exactly:
//   1. SetStyle over the full area (whole-block style)
//   2. Edges (top, bottom, left, right) with BorderStyle
//   3. Corners overwrite edge cells where two adjacent borders meet
//   4. Title strip on the top row, indented past left border if any

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_borders;

type
  TBlock = record
    Borders: TBorders;
    BorderSet_: TBorderSet;
    HasTitle: Boolean;
    Title: AnsiString;
    Style: TStyle;
    BorderStyle: TStyle;
    TitleStyle: TStyle;

    class function Default: TBlock; static;

    function WithBorders(B: TBorders): TBlock;
    function WithBorderSet(const BS: TBorderSet): TBlock;
    function WithTitle(const T: AnsiString): TBlock;
    function WithStyle(const S: TStyle): TBlock;
    function WithBorderStyle(const S: TStyle): TBlock;
    function WithTitleStyle(const S: TStyle): TBlock;

    procedure Render(const Area: TRect; ABuf: TBuffer);
    function Inner(const Area: TRect): TRect;
  end;

implementation

class function TBlock.Default: TBlock;
begin
  Result.Borders := [];
  Result.BorderSet_ := BorderSetPlain;
  Result.HasTitle := False;
  Result.Title := '';
  Result.Style := TStyle.Default;
  Result.BorderStyle := TStyle.Default;
  Result.TitleStyle := TStyle.Default;
end;

function TBlock.WithBorders(B: TBorders): TBlock;
begin
  Result := Self;
  Result.Borders := B;
end;

function TBlock.WithBorderSet(const BS: TBorderSet): TBlock;
begin
  Result := Self;
  Result.BorderSet_ := BS;
end;

function TBlock.WithTitle(const T: AnsiString): TBlock;
begin
  Result := Self;
  Result.HasTitle := True;
  Result.Title := T;
end;

function TBlock.WithStyle(const S: TStyle): TBlock;
begin
  Result := Self;
  Result.Style := S;
end;

function TBlock.WithBorderStyle(const S: TStyle): TBlock;
begin
  Result := Self;
  Result.BorderStyle := S;
end;

function TBlock.WithTitleStyle(const S: TStyle): TBlock;
begin
  Result := Self;
  Result.TitleStyle := S;
end;

// Helper: write `Glyph` (a multi-byte UTF-8 grapheme) into a single
// cell at (X,Y), then patch the given style onto it.  No-op if the
// position is outside the buffer's area.
procedure PaintGlyph(ABuf: TBuffer; X, Y: Integer; const Glyph: AnsiString;
  const Sty: TStyle); inline;
var
  CP: PCell;
begin
  CP := ABuf.CellAt(X, Y);
  if CP = nil then Exit;
  if Length(Glyph) > 0 then
    CellSetSymbolBytes(CP^, Glyph[1], Length(Glyph), 1);
  CellApplyStyle(CP^, Sty);
end;

procedure TBlock.Render(const Area: TRect; ABuf: TBuffer);
var
  Clip: TRect;
  X, Y, RightX, BottomY, TitleX, TitleMaxW: Integer;
begin
  Clip := ABuf.Area.Intersection(Area);
  if Clip.IsEmpty then Exit;

  // Step 1: paint the whole area with the block's base style.
  ABuf.SetStyle(Clip, Style);

  RightX := Clip.X + Clip.Width - 1;
  BottomY := Clip.Y + Clip.Height - 1;

  // Step 2: edges.
  if bsTop in Borders then
    for X := Clip.X to RightX do
      PaintGlyph(ABuf, X, Clip.Y, BorderSet_.Horizontal, BorderStyle);

  if bsBottom in Borders then
    for X := Clip.X to RightX do
      PaintGlyph(ABuf, X, BottomY, BorderSet_.Horizontal, BorderStyle);

  if bsLeft in Borders then
    for Y := Clip.Y to BottomY do
      PaintGlyph(ABuf, Clip.X, Y, BorderSet_.Vertical, BorderStyle);

  if bsRight in Borders then
    for Y := Clip.Y to BottomY do
      PaintGlyph(ABuf, RightX, Y, BorderSet_.Vertical, BorderStyle);

  // Step 3: corners.
  if (bsTop in Borders) and (bsLeft in Borders) then
    PaintGlyph(ABuf, Clip.X, Clip.Y, BorderSet_.TopLeft, BorderStyle);
  if (bsTop in Borders) and (bsRight in Borders) then
    PaintGlyph(ABuf, RightX, Clip.Y, BorderSet_.TopRight, BorderStyle);
  if (bsBottom in Borders) and (bsLeft in Borders) then
    PaintGlyph(ABuf, Clip.X, BottomY, BorderSet_.BottomLeft, BorderStyle);
  if (bsBottom in Borders) and (bsRight in Borders) then
    PaintGlyph(ABuf, RightX, BottomY, BorderSet_.BottomRight, BorderStyle);

  // Step 4: title.  Sits on the top row, indented one cell past a
  // left border if present.  Width clipped to remaining cells before
  // the right border.  ratatui draws title even if no top border;
  // we follow that — calling Inner correctly accounts for it via
  // the "any title at top" rule below.
  if HasTitle and (Length(Title) > 0) and (Clip.Height > 0) then
  begin
    if bsLeft in Borders then
      TitleX := Clip.X + 1
    else
      TitleX := Clip.X;
    TitleMaxW := Clip.Width;
    if bsLeft in Borders  then Dec(TitleMaxW);
    if bsRight in Borders then Dec(TitleMaxW);
    if TitleMaxW > 0 then
      ABuf.SetStringN(TitleX, Clip.Y, Title, TitleMaxW, TitleStyle);
  end;
end;

function TBlock.Inner(const Area: TRect): TRect;
var
  X, Y, W, H: Integer;
  TopShrink, BottomShrink: Integer;
begin
  X := Area.X;
  Y := Area.Y;
  W := Area.Width;
  H := Area.Height;

  TopShrink := 0;
  BottomShrink := 0;

  if bsLeft in Borders then
  begin
    Inc(X);
    Dec(W);
  end;
  if bsRight in Borders then
    Dec(W);

  if bsTop in Borders then TopShrink := 1;
  if bsBottom in Borders then BottomShrink := 1;

  // ratatui rule: a top title forces +1 vertical shrink even without
  // a top border.  Same for bottom titles, but we don't ship those.
  if HasTitle and (TopShrink = 0) then TopShrink := 1;

  Inc(Y, TopShrink);
  Dec(H, TopShrink + BottomShrink);

  if W < 0 then W := 0;
  if H < 0 then H := 0;

  Result := TRect.Make(X, Y, W, H);
end;

end.
