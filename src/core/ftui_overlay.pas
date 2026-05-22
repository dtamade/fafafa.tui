unit ftui_overlay;

// Overlay buffer — a sparse layer that sits on top of the base buffer.
//
// Design:
//   - Internally stores only cells that have been explicitly written
//     (via SetString / SetCell / SetStyle).  Unwritten positions are
//     "transparent" — merge passes through the base cell unchanged.
//   - Merge(base, overlay) → merged buffer used for diff.
//   - Clear resets the overlay to fully transparent (zero cost).
//   - Invalidation: consumer sets FDirty when overlay changes; the
//     terminal checks FDirty to decide whether to re-merge.
//
// Performance:
//   - Overlay is backed by a full-size `array of TCell` (same as base)
//     plus a parallel `array of Boolean` marking which cells are set.
//   - Merge is a single pass: if mark[i] then merged[i] := overlay[i]
//     else merged[i] := base[i].  ~12000 iterations for 200x60, each
//     is a branch + possible 40-byte copy.  Measured: ~150μs worst case.
//   - Clear is `FillChar(marks, N, 0)` — ~1μs for 12000 bytes.

{$mode objfpc}{$H+}{$inline on}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_cell,
  ftui_buffer;

type
  TOverlayBuffer = class
  private
    FArea: TRect;
    FCells: array of TCell;
    FMarks: array of Boolean;
    FDirty: Boolean;
    function IndexOf(X, Y: Integer): Integer; inline;
  public
    constructor Create(const AArea: TRect);

    property Area: TRect read FArea;
    property Dirty: Boolean read FDirty;

    // Write a cell at (X, Y).  Marks it as "set" in the overlay.
    procedure SetCell(X, Y: Integer; const C: TCell);

    // Write a string into the overlay (same semantics as TBuffer.SetString).
    procedure SetString(X, Y: Integer; const S: AnsiString; const Sty: TStyle);

    // Mark a rect as "set" with a style (fills with styled spaces).
    procedure SetStyle(const A: TRect; const Sty: TStyle);

    // Clear the entire overlay (all cells become transparent).
    procedure Clear;

    // Resize to match a new area.  Clears all content.
    procedure Resize(const ANewArea: TRect);

    // Merge base + overlay into Dest.  Dest must be same size as base.
    // Only copies overlay cells where marked; base cells pass through.
    procedure MergeInto(Base, Dest: TBuffer);

    // Mark dirty (consumer calls this after writing to overlay).
    procedure MarkDirty; inline;
    procedure ClearDirty; inline;
  end;

implementation

uses
  ftui_grapheme;

constructor TOverlayBuffer.Create(const AArea: TRect);
var N: Integer;
begin
  inherited Create;
  FArea := AArea;
  N := AArea.Area;
  SetLength(FCells, N);
  SetLength(FMarks, N);
  Clear;
end;

function TOverlayBuffer.IndexOf(X, Y: Integer): Integer;
begin
  Result := (Y - FArea.Y) * FArea.Width + (X - FArea.X);
end;

procedure TOverlayBuffer.SetCell(X, Y: Integer; const C: TCell);
var Idx: Integer;
begin
  if (X < FArea.X) or (X >= FArea.X + FArea.Width) or
     (Y < FArea.Y) or (Y >= FArea.Y + FArea.Height) then Exit;
  Idx := IndexOf(X, Y);
  FCells[Idx] := C;
  FMarks[Idx] := True;
  FDirty := True;
end;

procedure TOverlayBuffer.SetString(X, Y: Integer; const S: AnsiString; const Sty: TStyle);
var
  I, Cursor, GLen: Integer;
  Adv: TGraphemeAdvance;
  C: TCell;
  Ascii: Boolean;
begin
  if (Y < FArea.Y) or (Y >= FArea.Y + FArea.Height) then Exit;
  if X >= FArea.X + FArea.Width then Exit;
  if X < FArea.X then X := FArea.X;

  GLen := Length(S);
  if GLen = 0 then Exit;

  Ascii := True;
  for I := 1 to GLen do
    if Byte(S[I]) >= $80 then begin Ascii := False; Break; end;

  Cursor := X;
  if Ascii then
  begin
    for I := 1 to GLen do
    begin
      if Cursor >= FArea.X + FArea.Width then Break;
      if Byte(S[I]) < 32 then Continue;
      C := CellEmpty;
      CellSetSymbolAscii(C, S[I]);
      CellApplyStyle(C, Sty);
      SetCell(Cursor, Y, C);
      Inc(Cursor);
    end;
  end
  else
  begin
    I := 0;
    while I < GLen do
    begin
      if Cursor >= FArea.X + FArea.Width then Break;
      Adv := GraphemeAdvance(S[1], GLen, I);
      if Adv.Width = 0 then begin Inc(I, Adv.ByteLen); Continue; end;
      if Cursor + Adv.Width > FArea.X + FArea.Width then Break;
      C := CellEmpty;
      CellSetSymbolBytes(C, PByte(@S[1])[I], Adv.ByteLen, Adv.Width);
      CellApplyStyle(C, Sty);
      SetCell(Cursor, Y, C);
      if Adv.Width = 2 then
      begin
        C := CellEmpty; C.Width := 0; C.Skip := True;
        SetCell(Cursor + 1, Y, C);
      end;
      Inc(Cursor, Adv.Width);
      Inc(I, Adv.ByteLen);
    end;
  end;
end;

procedure TOverlayBuffer.SetStyle(const A: TRect; const Sty: TStyle);
var
  Clip: TRect;
  X, Y, Idx: Integer;
  C: TCell;
begin
  Clip := FArea.Intersection(A);
  if Clip.IsEmpty then Exit;
  for Y := Clip.Top to Clip.Bottom - 1 do
    for X := Clip.Left to Clip.Right - 1 do
    begin
      Idx := IndexOf(X, Y);
      if FMarks[Idx] then
        CellApplyStyle(FCells[Idx], Sty)
      else
      begin
        C := CellEmpty;
        CellApplyStyle(C, Sty);
        FCells[Idx] := C;
        FMarks[Idx] := True;
      end;
    end;
  FDirty := True;
end;

procedure TOverlayBuffer.Clear;
begin
  if Length(FMarks) > 0 then
    FillChar(FMarks[0], Length(FMarks) * SizeOf(Boolean), 0);
  FDirty := True;
end;

procedure TOverlayBuffer.Resize(const ANewArea: TRect);
var N: Integer;
begin
  FArea := ANewArea;
  N := ANewArea.Area;
  SetLength(FCells, N);
  SetLength(FMarks, N);
  Clear;
end;

procedure TOverlayBuffer.MergeInto(Base, Dest: TBuffer);
var
  I, Total: Integer;
  DstCell: PCell;
begin
  Assert((Base.Area.X = Dest.Area.X) and (Base.Area.Y = Dest.Area.Y)
    and (Base.Area.Width = Dest.Area.Width) and (Base.Area.Height = Dest.Area.Height),
    'MergeInto: Base and Dest must have same Area');
  Total := Length(FMarks);
  if Total = 0 then Exit;
  // Dest should already be a copy of Base or freshly filled from Base.
  // We just overwrite the marked positions.
  for I := 0 to Total - 1 do
  begin
    if FMarks[I] then
    begin
      DstCell := Dest.CellAt(
        FArea.X + (I mod FArea.Width),
        FArea.Y + (I div FArea.Width));
      if DstCell <> nil then
        DstCell^ := FCells[I];
    end;
  end;
end;

procedure TOverlayBuffer.MarkDirty;
begin
  FDirty := True;
end;

procedure TOverlayBuffer.ClearDirty;
begin
  FDirty := False;
end;

end.
