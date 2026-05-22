unit ftui_paragraph;

// Paragraph widget — text + optional Block + optional Wrap{trim} +
// alignment + (vertical) scroll.
//
// Scope (matches cli888):
//   - Wrap{trim:true} — the only wrap mode cli888 uses (5 places)
//   - Alignment Left/Center/Right (cli888 uses Center 44, Left 7, Right 1)
//   - Scroll Y only (vertical paragraph scroll); horizontal scroll is
//     a LineTruncator concern we don't need
//   - Optional Block surround
//
// Out of scope:
//   - Wrap{trim:false}
//   - Horizontal scroll (LineTruncator)
//   - Word boundary heuristics beyond ASCII whitespace
//   - Per-Span alignment (Spans inherit Line's alignment)
//
// Word-wrapper algorithm (simplified):
//   - For each TLine in TText:
//       * Concatenate all spans' content into a flat byte string,
//         along with parallel per-byte styles
//       * If trim is on, drop leading whitespace from THIS rendered
//         line (matches ratatui WordWrapper trim behaviour)
//       * Walk forward, accumulating bytes into the current visual
//         line until either (a) adding the next word would overflow
//         AreaWidth, or (b) we hit end-of-input
//       * On overflow, break at the last whitespace boundary; the
//         word that didn't fit becomes the start of the next visual
//         line.  If a single word is wider than AreaWidth, hard-break
//         at AreaWidth (ratatui does the same — never lose content).
//   - Each emitted visual line is paired with the source TLine's
//     alignment (or paragraph alignment as fallback)
//
// Render sequence:
//   1. Apply Style to outer Area
//   2. If Block is set: Block.Render + shrink to Block.Inner
//   3. Apply Style to inner Area (matches ratatui re-application)
//   4. Wrap text -> list of (line bytes, line_width, alignment)
//   5. Skip first Scroll.Y wrapped lines, draw remaining within
//      inner.Height, with horizontal offset from get_line_offset

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
  ftui_grapheme,
  ftui_text,
  ftui_block;

type
  TWrap = packed record
    Trim: Boolean;
  end;

  TByteSpanIdx = array of Integer;

  TParagraph = record
    Text: TText;
    Style: TStyle;
    HasBlock: Boolean;
    Block: TBlock;
    HasWrap: Boolean;
    Wrap: TWrap;
    HasAlignment: Boolean;
    Alignment: TAlignment;
    ScrollY: Word;

    class function FromText(const T: TText): TParagraph; static;
    class function FromString(const S: AnsiString): TParagraph; static;

    function WithStyle(const S: TStyle): TParagraph;
    function WithBlock(const B: TBlock): TParagraph;
    function WithWrap(const W: TWrap): TParagraph;
    function WithAlignment(A: TAlignment): TParagraph;
    function WithScrollY(Y: Word): TParagraph;

    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

const
  WrapTrim: TWrap = (Trim: True);

implementation

{ TParagraph }

class function TParagraph.FromText(const T: TText): TParagraph;
begin
  Result.Text := T;
  Result.Style := TStyle.Default;
  Result.HasBlock := False;
  Result.Block := TBlock.Default;
  Result.HasWrap := False;
  Result.Wrap.Trim := False;
  Result.HasAlignment := False;
  Result.Alignment := caLeft;
  Result.ScrollY := 0;
end;

class function TParagraph.FromString(const S: AnsiString): TParagraph;
begin
  Result := FromText(TText.FromString(S));
end;

function TParagraph.WithStyle(const S: TStyle): TParagraph;
begin
  Result := Self;
  Result.Style := S;
end;

function TParagraph.WithBlock(const B: TBlock): TParagraph;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := B;
end;

function TParagraph.WithWrap(const W: TWrap): TParagraph;
begin
  Result := Self;
  Result.HasWrap := True;
  Result.Wrap := W;
end;

function TParagraph.WithAlignment(A: TAlignment): TParagraph;
begin
  Result := Self;
  Result.HasAlignment := True;
  Result.Alignment := A;
end;

function TParagraph.WithScrollY(Y: Word): TParagraph;
begin
  Result := Self;
  Result.ScrollY := Y;
end;

// X offset within `width` for an item of `item_w` cells.  Mirrors
// ratatui get_line_offset.
function GetLineOffset(ItemW, Width: Integer; A: TAlignment): Integer; inline;
begin
  case A of
    caCenter: Result := (Width div 2) - (ItemW div 2);
    caRight:  Result := Width - ItemW;
  else
    Result := 0;
  end;
  if Result < 0 then Result := 0;
end;

// Concatenate all spans of a Line into a flat byte string and a
// parallel array of per-byte indices into the spans array (so we can
// look up the right Style when emitting).  Cheap because byte counts
// are small (a single visual line worth of text).
procedure FlattenLine(const L: TLine;
  out Buf: AnsiString; var SpanByByte: TByteSpanIdx);
var
  I, J, Total, Pos: Integer;
begin
  Total := 0;
  for I := 0 to High(L.Spans) do
    Inc(Total, Length(L.Spans[I].Content));
  SetLength(Buf, Total);
  SetLength(SpanByByte, Total);
  Pos := 1;
  for I := 0 to High(L.Spans) do
  begin
    if Length(L.Spans[I].Content) > 0 then
    begin
      Move(L.Spans[I].Content[1], Buf[Pos], Length(L.Spans[I].Content));
      for J := 0 to Length(L.Spans[I].Content) - 1 do
        SpanByByte[Pos - 1 + J] := I;
      Inc(Pos, Length(L.Spans[I].Content));
    end;
  end;
end;

type
  // Internal: one wrapped (visual) line, ready to emit.  Stores the
  // source Line index so we can look up Spans / per-byte style at draw
  // time, plus the byte offset/length window into that line's
  // flattened buffer.
  TWrappedLine = record
    SrcLine: Integer;
    ByteStart, ByteEnd: Integer;     // half-open into flattened buf
    Alignment: TAlignment;
  end;

// Walk one source Line.  Append wrapped visual lines into Out_/OutCount.
// FlatBuf and SpanByByte come from FlattenLine.  Width is the available
// columns; Trim controls leading-whitespace trimming on wrap boundary.
procedure WrapOneLine(SrcIdx: Integer; const FlatBuf: AnsiString;
  Width: Integer; Trim: Boolean; LineAlign: TAlignment;
  var Out_: array of TWrappedLine; var OutCount: Integer);
var
  P, Total, LineStart, LineEnd: Integer;
  LastSpace: Integer;
  Ch: Byte;
begin
  Total := Length(FlatBuf);
  if Total = 0 then
  begin
    // Empty source line still produces one empty visual line.
    if OutCount < Length(Out_) then
    begin
      Out_[OutCount].SrcLine := SrcIdx;
      Out_[OutCount].ByteStart := 0;
      Out_[OutCount].ByteEnd := 0;
      Out_[OutCount].Alignment := LineAlign;
      Inc(OutCount);
    end;
    Exit;
  end;
  if Width <= 0 then Exit;

  P := 0;
  while P < Total do
  begin
    if Trim then
      while (P < Total) and (FlatBuf[P + 1] = ' ') do
        Inc(P);
    if P >= Total then Break;

    LineStart := P;
    LastSpace := -1;
    while (P < Total) and (P - LineStart < Width) do
    begin
      Ch := Byte(FlatBuf[P + 1]);
      if Ch = Ord(' ') then LastSpace := P;
      Inc(P);
    end;

    if P >= Total then
    begin
      LineEnd := P;
    end
    else if (LastSpace > LineStart) then
    begin
      // Break at the last whitespace within this window.
      LineEnd := LastSpace;
      P := LastSpace + 1;            // skip the space
    end
    else
    begin
      // Single word wider than Width — hard break at the column edge.
      LineEnd := P;
    end;

    if OutCount < Length(Out_) then
    begin
      Out_[OutCount].SrcLine := SrcIdx;
      Out_[OutCount].ByteStart := LineStart;
      Out_[OutCount].ByteEnd := LineEnd;
      Out_[OutCount].Alignment := LineAlign;
      Inc(OutCount);
    end;
  end;
end;

procedure TParagraph.Render(const Area: TRect; ABuf: TBuffer);
var
  Clip, Inner: TRect;
  I, J, Y, OutCount, MaxLines, Cap: Integer;
  EffectiveAlign: TAlignment;
  Wrapped: array of TWrappedLine;
  FlatBufs: array of AnsiString;
  SpanIdxArrays: array of TByteSpanIdx;
  LineW, OffsetX, X, ByteIdx, SpanIdx, NewSpanIdx: Integer;
  RowY: Integer;
  S: TStyle;
  SrcLine: Integer;
  WL: TWrappedLine;
  Adv: TGraphemeAdvance;
  CP: PCell;
begin
  Clip := ABuf.Area.Intersection(Area);
  if Clip.IsEmpty then Exit;

  // 1. Style over the full outer area.
  ABuf.SetStyle(Clip, Style);

  // 2. Block surround (if any) shrinks to inner.
  if HasBlock then
  begin
    Block.Render(Clip, ABuf);
    Inner := Block.Inner(Clip);
  end
  else
    Inner := Clip;

  if Inner.IsEmpty then Exit;
  if Inner.Width = 0 then Exit;
  ABuf.SetStyle(Inner, Style);

  // 3. Default alignment cascade.
  if HasAlignment then
    EffectiveAlign := Alignment
  else
    EffectiveAlign := caLeft;

  // 4. Flatten every source line once and wrap them.  Cap output count
  // at a sensible upper bound to bound the SetLength.
  Cap := 0;
  for I := 0 to High(Text.Lines) do
    Inc(Cap, (Text.Lines[I].Width div Inner.Width) + 2);
  if Cap < 1 then Cap := 1;

  SetLength(FlatBufs, Length(Text.Lines));
  SetLength(SpanIdxArrays, Length(Text.Lines));
  SetLength(Wrapped, Cap);
  OutCount := 0;

  for I := 0 to High(Text.Lines) do
  begin
    SetLength(SpanIdxArrays[I], 0);
    if Text.Lines[I].Width > 0 then
      SetLength(SpanIdxArrays[I], Text.Lines[I].Width);
    FlattenLine(Text.Lines[I], FlatBufs[I], SpanIdxArrays[I]);

    if Text.Lines[I].HasAlignment then
      EffectiveAlign := Text.Lines[I].Alignment
    else if HasAlignment then
      EffectiveAlign := Alignment
    else
      EffectiveAlign := caLeft;

    if HasWrap and Wrap.Trim then
      WrapOneLine(I, FlatBufs[I], Inner.Width, True, EffectiveAlign,
        Wrapped, OutCount)
    else
    begin
      // No wrap: emit the line as-is, truncated to Inner.Width at
      // draw time (we still record full byte range; the draw loop
      // will stop on overflow).
      if OutCount < Length(Wrapped) then
      begin
        Wrapped[OutCount].SrcLine := I;
        Wrapped[OutCount].ByteStart := 0;
        Wrapped[OutCount].ByteEnd := Length(FlatBufs[I]);
        Wrapped[OutCount].Alignment := EffectiveAlign;
        Inc(OutCount);
      end;
    end;
  end;

  // 5. Skip ScrollY visual lines, then emit up to Inner.Height.
  MaxLines := Inner.Height;
  Y := 0;
  for I := 0 to OutCount - 1 do
  begin
    if Y < ScrollY then
    begin
      Inc(Y);
      Continue;
    end;
    if (Y - ScrollY) >= MaxLines then Break;
    RowY := Inner.Y + (Y - ScrollY);

    WL := Wrapped[I];
    SrcLine := WL.SrcLine;

    // Calculate display width of this wrapped line
    LineW := GraphemeWidth(Copy(FlatBufs[SrcLine], WL.ByteStart + 1, WL.ByteEnd - WL.ByteStart));
    if LineW > Inner.Width then LineW := Inner.Width;
    OffsetX := GetLineOffset(LineW, Inner.Width, WL.Alignment);

    // Walk graphemes inside [ByteStart, ByteEnd), placing each into
    // the matching cell with the correct width and style.
    X := Inner.X + OffsetX;
    J := WL.ByteStart;
    SpanIdx := -1;
    S := TStyle.Default;
    while J < WL.ByteEnd do
    begin
      if X >= Inner.X + Inner.Width then Break;

      // Decode one grapheme
      Adv := GraphemeAdvance(FlatBufs[SrcLine][1], Length(FlatBufs[SrcLine]), J);

      // Determine span style (cache: only recompute when span changes)
      ByteIdx := J;
      if (ByteIdx >= 0) and (ByteIdx < Length(SpanIdxArrays[SrcLine])) then
        NewSpanIdx := SpanIdxArrays[SrcLine][ByteIdx]
      else
        NewSpanIdx := 0;
      if NewSpanIdx <> SpanIdx then
      begin
        SpanIdx := NewSpanIdx;
        S := Style.Patch(Text.Style);
        if SrcLine < Length(Text.Lines) then
          S := S.Patch(Text.Lines[SrcLine].Style);
        if (SpanIdx >= 0) and (SpanIdx < Length(Text.Lines[SrcLine].Spans)) then
          S := S.Patch(Text.Lines[SrcLine].Spans[SpanIdx].Style);
      end;

      CP := ABuf.CellAt(X, RowY);
      if CP <> nil then
      begin
        CellSetSymbolBytes(CP^, FlatBufs[SrcLine][J + 1], Adv.ByteLen, Adv.Width);
        CellApplyStyle(CP^, S);
      end;

      Inc(X, Adv.Width);
      Inc(J, Adv.ByteLen);
    end;

    Inc(Y);
  end;
end;

end.
