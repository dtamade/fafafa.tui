unit ftui_buffer;

// 1:1 mapping of ratatui::buffer::Buffer.
//
// Storage: `array of TCell` indexed `(Y - Area.Y) * Area.Width + (X - Area.X)`.
// One contiguous allocation, no nested arrays, no per-row allocation.
// Hot paths (CellAt, SetString, Diff) walk the array linearly and
// dereference cells through `PCell` pointers — zero copying, zero
// allocation per cell.
//
// Diff matches ratatui 0.29 exactly (see Diff implementation comments):
// two counters `ToSkip` and `Invalidated` propagate wide-glyph state
// across columns so the renderer never emits the trailing column of a
// width-2 grapheme.

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
  ftui_grapheme;

type
  TDiffEntry = packed record
    X, Y: Word;
    Cell: TCell;
  end;
  TDiffEntries = array of TDiffEntry;

  TBufferLines = array of AnsiString;

  TBuffer = class
  private
    FArea: TRect;
    FContent: array of TCell;
    function IndexOfPos(X, Y: Integer): Integer; inline;
  public
    constructor CreateEmpty(const AArea: TRect);
    constructor CreateFilled(const AArea: TRect; const C: TCell);

    property Area: TRect read FArea;
    function Width: Word; inline;
    function Height: Word; inline;
    function Length_: Integer; inline;       // count of cells
    function ContentPtr: PCell; inline;

    // Read/write access by position.  Returns nil if (X,Y) is outside Area.
    function CellAt(X, Y: Integer): PCell;

    // Write a UTF-8 / ASCII string starting at (X,Y), bounded by area
    // right edge and an optional MaxWidth (in columns).  Style is
    // applied to every written cell via CellApplyStyle.  Returns the
    // number of columns actually written (callers rarely care).
    //
    // M0 limitation: each byte is treated as a single-column ASCII
    // character.  Wide-char handling lands in M2 alongside utf8proc.
    function SetString(X, Y: Integer; const S: AnsiString;
      const Sty: TStyle): Integer;
    function SetStringN(X, Y: Integer; const S: AnsiString; MaxWidth: Integer;
      const Sty: TStyle): Integer;

    // Apply a style to every cell within the intersection of A and Area.
    procedure SetStyle(const A: TRect; const Sty: TStyle);

    // Reset every cell to CellEmpty.
    procedure Reset;

    // Resize so the underlying area becomes ANewArea.  Cells inside the
    // overlap are kept; the rest is filled with CellEmpty.
    procedure Resize(const ANewArea: TRect);

    // Compute the diff between Self (previous) and Next (current).
    // Output is an append-only Patches array suitable for an ANSI
    // backend to play back.  Allocations: a single SetLength on the
    // output array.
    procedure Diff(const Next: TBuffer; out Patches: TDiffEntries);

    // Like Diff but reuses the Patches array across calls (only grows,
    // never shrinks).  Returns the number of valid entries.  Hot-path
    // callers should prefer this to avoid per-frame allocation.
    function DiffInto(const Next: TBuffer; var Patches: TDiffEntries): Integer;

    // Test helpers — never call from production code.
    function RowAsString(Y: Integer): AnsiString;
    function AsLines: TBufferLines;
  end;

implementation

{ TBuffer }

constructor TBuffer.CreateEmpty(const AArea: TRect);
begin
  inherited Create;
  FArea := AArea;
  SetLength(FContent, AArea.Area);
  Reset;
end;

constructor TBuffer.CreateFilled(const AArea: TRect; const C: TCell);
var
  I, Total: Integer;
begin
  inherited Create;
  FArea := AArea;
  Total := AArea.Area;
  SetLength(FContent, Total);
  for I := 0 to Total - 1 do
    FContent[I] := C;
end;

function TBuffer.Width: Word;
begin
  Result := FArea.Width;
end;

function TBuffer.Height: Word;
begin
  Result := FArea.Height;
end;

function TBuffer.Length_: Integer;
begin
  Result := System.Length(FContent);
end;

function TBuffer.ContentPtr: PCell;
begin
  if System.Length(FContent) = 0 then
    Result := nil
  else
    Result := @FContent[0];
end;

function TBuffer.IndexOfPos(X, Y: Integer): Integer;
begin
  // Caller is responsible for the bounds check.  This is the inner
  // hot-path helper; we do not pay for an `if` on every read.
  Result := (Y - FArea.Y) * FArea.Width + (X - FArea.X);
end;

function TBuffer.CellAt(X, Y: Integer): PCell;
begin
  if (X < FArea.X) or (X >= FArea.X + FArea.Width) or
     (Y < FArea.Y) or (Y >= FArea.Y + FArea.Height) then
    Exit(nil);
  Result := @FContent[IndexOfPos(X, Y)];
end;

function TBuffer.SetString(X, Y: Integer; const S: AnsiString;
  const Sty: TStyle): Integer;
begin
  Result := SetStringN(X, Y, S, MaxInt, Sty);
end;

function TBuffer.SetStringN(X, Y: Integer; const S: AnsiString;
  MaxWidth: Integer; const Sty: TStyle): Integer;
var
  Right, Remaining, I, Cursor, GLen: Integer;
  CP: PCell;
  Adv: TGraphemeAdvance;
  Ascii: Boolean;
  B: Byte;
begin
  Result := 0;
  if (Y < FArea.Y) or (Y >= FArea.Y + FArea.Height) then Exit;
  if X >= FArea.X + FArea.Width then Exit;
  if X < FArea.X then X := FArea.X;

  Right := FArea.X + FArea.Width;
  Remaining := Right - X;
  if Remaining > MaxWidth then Remaining := MaxWidth;
  if Remaining <= 0 then Exit;
  GLen := System.Length(S);
  if GLen = 0 then Exit;

  // Hot ASCII path — most cli888 strings (status bars, English UI)
  // are pure ASCII, so we keep the byte-loop intact for them.
  Ascii := True;
  for I := 1 to GLen do
    if Byte(S[I]) >= $80 then
    begin
      Ascii := False;
      Break;
    end;

  Cursor := X;
  if Ascii then
  begin
    for I := 1 to GLen do
    begin
      if Remaining = 0 then Break;
      B := Byte(S[I]);
      if B < 32 then Continue;        // drop controls (ratatui parity)
      CP := @FContent[IndexOfPos(Cursor, Y)];
      CellSetSymbolAscii(CP^, S[I]);
      CellApplyStyle(CP^, Sty);
      Inc(Cursor);
      Inc(Result);
      Dec(Remaining);
    end;
    Exit;
  end;

  // UTF-8 grapheme path.  Decode codepoint by codepoint.  A width-2
  // cluster occupies two cells: the leading cell carries the glyph
  // bytes and Width=2; the trailing cell is reset to CellEmpty with
  // Width=0 and Skip=True so the diff/render layer knows to leave it
  // alone.
  I := 0;
  while I < GLen do
  begin
    if Remaining = 0 then Break;
    Adv := GraphemeAdvance(S[1], GLen, I);

    // Drop ASCII controls; treat zero-width codepoints as advance-only.
    if Adv.Width = 0 then
    begin
      Inc(I, Adv.ByteLen);
      Continue;
    end;

    if Adv.Width > Remaining then Break;   // not enough room for wide glyph

    CP := @FContent[IndexOfPos(Cursor, Y)];
    CellSetSymbolBytes(CP^, PByte(@S[1])[I], Adv.ByteLen, Adv.Width);
    CellApplyStyle(CP^, Sty);

    if Adv.Width = 2 then
    begin
      // Reset the trailing cell so the previous content doesn't bleed
      // through; mark it skip so backends drop it from the patch list.
      CP := @FContent[IndexOfPos(Cursor + 1, Y)];
      CellReset(CP^);
      CP^.Width := 0;
      CP^.Skip := True;
    end;

    Inc(Cursor, Adv.Width);
    Inc(Result, Adv.Width);
    Dec(Remaining, Adv.Width);
    Inc(I, Adv.ByteLen);
  end;
end;

procedure TBuffer.SetStyle(const A: TRect; const Sty: TStyle);
var
  Clip: TRect;
  X, Y: Integer;
  CP: PCell;
begin
  Clip := FArea.Intersection(A);
  if Clip.IsEmpty then Exit;
  for Y := Clip.Top to Clip.Bottom - 1 do
    for X := Clip.Left to Clip.Right - 1 do
    begin
      CP := @FContent[IndexOfPos(X, Y)];
      CellApplyStyle(CP^, Sty);
    end;
end;

procedure TBuffer.Reset;
var
  I, Total: Integer;
  Dirty: TCell;
begin
  Total := System.Length(FContent);
  if Total = 0 then Exit;
  // Use a cell that differs from CellEmpty so Diff always produces patches
  // after a reset (e.g. after terminal resize).
  Dirty := CellEmpty;
  Dirty.Glyph.Len := 0;  // impossible in normal rendering → guarantees diff
  FContent[0] := Dirty;
  I := 1;
  while I + I <= Total do
  begin
    Move(FContent[0], FContent[I], I * SizeOf(TCell));
    I := I + I;
  end;
  if I < Total then
    Move(FContent[0], FContent[I], (Total - I) * SizeOf(TCell));
end;

procedure TBuffer.Resize(const ANewArea: TRect);
var
  Old: array of TCell;
  OldArea: TRect;
  X, Y, Idx: Integer;
  Src: PCell;
begin
  if RectEquals(ANewArea, FArea) then Exit;

  Old := FContent;
  OldArea := FArea;

  FArea := ANewArea;
  SetLength(FContent, ANewArea.Area);
  // Fill new buffer first.
  for Idx := 0 to System.Length(FContent) - 1 do
    FContent[Idx] := CellEmpty;

  // Copy overlap from Old.
  for Y := OldArea.Top to OldArea.Bottom - 1 do
    for X := OldArea.Left to OldArea.Right - 1 do
    begin
      if (X < ANewArea.X) or (X >= ANewArea.X + ANewArea.Width) then Continue;
      if (Y < ANewArea.Y) or (Y >= ANewArea.Y + ANewArea.Height) then Continue;
      Src := @Old[(Y - OldArea.Y) * OldArea.Width + (X - OldArea.X)];
      FContent[(Y - ANewArea.Y) * ANewArea.Width + (X - ANewArea.X)] := Src^;
    end;
end;

procedure TBuffer.Diff(const Next: TBuffer; out Patches: TDiffEntries);
var
  Total, I, OutCount, AffectedWidth: Integer;
  ToSkip, Invalidated: Integer;
  Prev, Curr: PCell;
  PrevBase, CurrBase: PCell;
  PrevRow, CurrRow: PCell;
  Differs: Boolean;
  PosX, PosY: Word;
  W, Row, Col, RowBytes: Integer;
{$PUSH}{$R-}{$Q-}
begin
  if (System.Length(FContent) = 0) or (System.Length(Next.FContent) = 0) then
  begin
    SetLength(Patches, 0);
    Exit;
  end;

  if (Next.FArea.Width <> FArea.Width) or
     (Next.FArea.Height <> FArea.Height) then
  begin
    Total := System.Length(Next.FContent);
    SetLength(Patches, Total);
    PosX := Next.FArea.X;
    PosY := Next.FArea.Y;
    W := Next.FArea.Width;
    for I := 0 to Total - 1 do
    begin
      Patches[I].X := PosX;
      Patches[I].Y := PosY;
      Patches[I].Cell := Next.FContent[I];
      Inc(PosX);
      if PosX >= Next.FArea.X + W then
      begin
        PosX := Next.FArea.X;
        Inc(PosY);
      end;
    end;
    Exit;
  end;

  Total := System.Length(FContent);
  SetLength(Patches, Total);
  OutCount := 0;
  ToSkip := 0;
  Invalidated := 0;
  W := FArea.Width;
  RowBytes := W * SizeOf(TCell);
  PrevBase := @FContent[0];
  CurrBase := @Next.FContent[0];

  for Row := 0 to FArea.Height - 1 do
  begin
    PrevRow := PrevBase + (Row * W);
    CurrRow := CurrBase + (Row * W);

    if (Invalidated = 0) and (ToSkip = 0) and
       (CompareByte(PrevRow^, CurrRow^, RowBytes) = 0) then
      Continue;

    PosY := FArea.Y + Row;
    for Col := 0 to W - 1 do
    begin
      PosX := FArea.X + Col;
      Prev := PrevRow + Col;
      Curr := CurrRow + Col;

      Differs := (PQWord(Prev)[0] <> PQWord(Curr)[0]) or
                 (PQWord(Prev)[1] <> PQWord(Curr)[1]) or
                 (PQWord(Prev)[2] <> PQWord(Curr)[2]) or
                 (PQWord(Prev)[3] <> PQWord(Curr)[3]) or
                 (PQWord(Prev)[4] <> PQWord(Curr)[4]);

      if (not Curr^.Skip) and (Differs or (Invalidated > 0)) and (ToSkip = 0) then
      begin
        Patches[OutCount].X := PosX;
        Patches[OutCount].Y := PosY;
        Patches[OutCount].Cell := Curr^;
        Inc(OutCount);
      end;

      if ToSkip > 0 then
        Dec(ToSkip)
      else
        ToSkip := Curr^.Width - 1;
      if ToSkip < 0 then ToSkip := 0;

      AffectedWidth := Curr^.Width;
      if Prev^.Width > AffectedWidth then AffectedWidth := Prev^.Width;
      if AffectedWidth > Invalidated then Invalidated := AffectedWidth;
      if Invalidated > 0 then Dec(Invalidated);
    end;
  end;

  SetLength(Patches, OutCount);
{$POP}
end;

function TBuffer.DiffInto(const Next: TBuffer; var Patches: TDiffEntries): Integer;
var
  Total, OutCount, AffectedWidth: Integer;
  ToSkip, Invalidated: Integer;
  Prev, Curr: PCell;
  PrevBase, CurrBase: PCell;
  PrevRow, CurrRow: PCell;
  Differs: Boolean;
  PosX, PosY: Word;
  W, Row, Col, RowBytes: Integer;
{$PUSH}{$R-}{$Q-}
begin
  if (System.Length(FContent) = 0) or (System.Length(Next.FContent) = 0) then
  begin
    Result := 0;
    Exit;
  end;

  Total := System.Length(FContent);
  if (Next.FArea.Width <> FArea.Width) or
     (Next.FArea.Height <> FArea.Height) then
    Total := System.Length(Next.FContent);

  if System.Length(Patches) < Total then
    SetLength(Patches, Total);

  if (Next.FArea.Width <> FArea.Width) or
     (Next.FArea.Height <> FArea.Height) then
  begin
    PosX := Next.FArea.X;
    PosY := Next.FArea.Y;
    W := Next.FArea.Width;
    for Col := 0 to Total - 1 do
    begin
      Patches[Col].X := PosX;
      Patches[Col].Y := PosY;
      Patches[Col].Cell := Next.FContent[Col];
      Inc(PosX);
      if PosX >= Next.FArea.X + W then
      begin
        PosX := Next.FArea.X;
        Inc(PosY);
      end;
    end;
    Result := Total;
    Exit;
  end;

  OutCount := 0;
  ToSkip := 0;
  Invalidated := 0;
  W := FArea.Width;
  RowBytes := W * SizeOf(TCell);
  PrevBase := @FContent[0];
  CurrBase := @Next.FContent[0];

  for Row := 0 to FArea.Height - 1 do
  begin
    PrevRow := PrevBase + (Row * W);
    CurrRow := CurrBase + (Row * W);

    if (Invalidated = 0) and (ToSkip = 0) and
       (CompareByte(PrevRow^, CurrRow^, RowBytes) = 0) then
      Continue;

    PosY := FArea.Y + Row;
    for Col := 0 to W - 1 do
    begin
      PosX := FArea.X + Col;
      Prev := PrevRow + Col;
      Curr := CurrRow + Col;

      Differs := (PQWord(Prev)[0] <> PQWord(Curr)[0]) or
                 (PQWord(Prev)[1] <> PQWord(Curr)[1]) or
                 (PQWord(Prev)[2] <> PQWord(Curr)[2]) or
                 (PQWord(Prev)[3] <> PQWord(Curr)[3]) or
                 (PQWord(Prev)[4] <> PQWord(Curr)[4]);

      if (not Curr^.Skip) and (Differs or (Invalidated > 0)) and (ToSkip = 0) then
      begin
        Patches[OutCount].X := PosX;
        Patches[OutCount].Y := PosY;
        Patches[OutCount].Cell := Curr^;
        Inc(OutCount);
      end;

      if ToSkip > 0 then
        Dec(ToSkip)
      else
        ToSkip := Curr^.Width - 1;
      if ToSkip < 0 then ToSkip := 0;

      AffectedWidth := Curr^.Width;
      if Prev^.Width > AffectedWidth then AffectedWidth := Prev^.Width;
      if AffectedWidth > Invalidated then Invalidated := AffectedWidth;
      if Invalidated > 0 then Dec(Invalidated);
    end;
  end;

  Result := OutCount;
{$POP}
end;

function TBuffer.RowAsString(Y: Integer): AnsiString;
var
  X, Idx, OutByte, GlyphLen, TotalBytes: Integer;
  CP: PCell;
begin
  if (Y < FArea.Y) or (Y >= FArea.Y + FArea.Height) then Exit('');

  // Two-pass: first measure, then materialize once.  No s := s + ...
  // string concatenation, even on this cold/diagnostic path, so the
  // pattern stays exemplary for code-review.  Width=0 sentinel cells
  // (the trailing column of a CJK / wide grapheme) are skipped — the
  // leading cell already supplies the multi-byte glyph.
  TotalBytes := 0;
  for X := FArea.X to FArea.X + FArea.Width - 1 do
  begin
    Idx := IndexOfPos(X, Y);
    CP := @FContent[Idx];
    if CP^.Width = 0 then
      Continue                          // CJK trailing sentinel
    else if CP^.Glyph.Len = 0 then
      Inc(TotalBytes)                   // empty cell renders as one space
    else
      Inc(TotalBytes, CP^.Glyph.Len);
  end;

  SetLength(Result, TotalBytes);
  OutByte := 1;                          // AnsiString is 1-indexed
  for X := FArea.X to FArea.X + FArea.Width - 1 do
  begin
    Idx := IndexOfPos(X, Y);
    CP := @FContent[Idx];
    if CP^.Width = 0 then
      Continue;
    GlyphLen := CP^.Glyph.Len;
    if GlyphLen = 0 then
    begin
      Result[OutByte] := ' ';
      Inc(OutByte);
    end
    else
    begin
      Move(CP^.Glyph.Bytes[0], Result[OutByte], GlyphLen);
      Inc(OutByte, GlyphLen);
    end;
  end;
end;

function TBuffer.AsLines: TBufferLines;
var
  Y: Integer;
begin
  SetLength(Result, FArea.Height);
  for Y := 0 to FArea.Height - 1 do
    Result[Y] := RowAsString(FArea.Y + Y);
end;

end.
