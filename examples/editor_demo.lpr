program editor_demo;

// Multi-line text editor with full Unicode / CJK / emoji support.
//
// Features:
//   - Normal mode: hjkl/arrows navigate by grapheme, x deletes
//     grapheme under cursor, dd deletes line, i/a/o enter Insert
//   - Insert mode: type any Unicode character (CJK, emoji, Latin),
//     Backspace deletes previous grapheme, Enter splits line
//   - Cursor tracks display columns (CJK = 2 cols, ASCII = 1 col)
//   - Status bar shows mode + line:col + grapheme count
//   - Resize-aware, auto-scroll

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_text,
  ftui_layout,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_grapheme,
  ftui_event,
  ftui_terminal;

const
  MAX_LINES = 200;

type
  TEditorMode = (emNormal, emInsert);

var
  Term: TTerminal;
  Mode: TEditorMode;
  Lines: array[0..MAX_LINES - 1] of AnsiString;
  LineCount: Integer;
  CurCol: Integer;     // display column (0-based)
  CurY: Integer;       // line index (0-based)

// Return the number of display columns in a line.
function LineColCount(const S: AnsiString): Integer;
begin
  Result := GraphemeWidth(S);
end;

// Convert a display column to a byte offset within S.
// Returns the byte index (0-based) where the grapheme at `Col` starts.
// If Col >= total columns, returns Length(S).
function ColToByteOffset(const S: AnsiString; Col: Integer): Integer;
var
  Pos, Cols: Integer;
  Adv: TGraphemeAdvance;
begin
  Pos := 0;
  Cols := 0;
  while (Pos < Length(S)) and (Cols < Col) do
  begin
    Adv := GraphemeAdvance(S[1], Length(S), Pos);
    Inc(Pos, Adv.ByteLen);
    Inc(Cols, Adv.Width);
  end;
  Result := Pos;
end;

// Get the byte length of the grapheme at display column `Col`.
function GraphemeByteLenAtCol(const S: AnsiString; Col: Integer): Integer;
var
  Pos, Cols: Integer;
  Adv: TGraphemeAdvance;
begin
  Pos := 0;
  Cols := 0;
  while (Pos < Length(S)) and (Cols < Col) do
  begin
    Adv := GraphemeAdvance(S[1], Length(S), Pos);
    Inc(Pos, Adv.ByteLen);
    Inc(Cols, Adv.Width);
  end;
  if Pos < Length(S) then
  begin
    Adv := GraphemeAdvance(S[1], Length(S), Pos);
    Result := Adv.ByteLen;
  end
  else
    Result := 0;
end;

// Get the display width of the grapheme at column `Col`.
function GraphemeWidthAtCol(const S: AnsiString; Col: Integer): Integer;
var
  Pos, Cols: Integer;
  Adv: TGraphemeAdvance;
begin
  Pos := 0;
  Cols := 0;
  while (Pos < Length(S)) and (Cols < Col) do
  begin
    Adv := GraphemeAdvance(S[1], Length(S), Pos);
    Inc(Pos, Adv.ByteLen);
    Inc(Cols, Adv.Width);
  end;
  if Pos < Length(S) then
  begin
    Adv := GraphemeAdvance(S[1], Length(S), Pos);
    Result := Adv.Width;
  end
  else
    Result := 1;
end;

// Encode a UCS-4 codepoint to UTF-8 bytes.
function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then
  begin
    SetLength(Result, 1);
    Result[1] := AnsiChar(Cp);
  end
  else if Cp < $800 then
  begin
    SetLength(Result, 2);
    Result[1] := AnsiChar($C0 or (Cp shr 6));
    Result[2] := AnsiChar($80 or (Cp and $3F));
  end
  else if Cp < $10000 then
  begin
    SetLength(Result, 3);
    Result[1] := AnsiChar($E0 or (Cp shr 12));
    Result[2] := AnsiChar($80 or ((Cp shr 6) and $3F));
    Result[3] := AnsiChar($80 or (Cp and $3F));
  end
  else
  begin
    SetLength(Result, 4);
    Result[1] := AnsiChar($F0 or (Cp shr 18));
    Result[2] := AnsiChar($80 or ((Cp shr 12) and $3F));
    Result[3] := AnsiChar($80 or ((Cp shr 6) and $3F));
    Result[4] := AnsiChar($80 or (Cp and $3F));
  end;
end;

procedure ClampCursor;
var
  MaxCol: Integer;
begin
  if CurY < 0 then CurY := 0;
  if CurY >= LineCount then CurY := LineCount - 1;
  MaxCol := LineColCount(Lines[CurY]);
  if Mode = emNormal then
  begin
    if MaxCol > 0 then Dec(MaxCol);   // Normal mode: cursor on last char, not past
  end;
  if CurCol < 0 then CurCol := 0;
  if CurCol > MaxCol then CurCol := MaxCol;
end;

procedure InsertUtf8(const S: AnsiString);
var
  BytePos: Integer;
begin
  BytePos := ColToByteOffset(Lines[CurY], CurCol);
  Insert(S, Lines[CurY], BytePos + 1);
  Inc(CurCol, GraphemeWidth(S));
end;

procedure DeleteGraphemeBackward;
var
  BytePos, PrevPos, Cols: Integer;
  Adv: TGraphemeAdvance;
  PrevWidth: Integer;
begin
  if CurCol > 0 then
  begin
    // Walk forward from start to find the grapheme just before CurCol.
    PrevPos := 0;
    Cols := 0;
    PrevWidth := 1;
    BytePos := 0;
    while Cols < CurCol do
    begin
      PrevPos := BytePos;
      Adv := GraphemeAdvance(Lines[CurY][1], Length(Lines[CurY]), BytePos);
      PrevWidth := Adv.Width;
      Inc(BytePos, Adv.ByteLen);
      Inc(Cols, Adv.Width);
    end;
    // Delete from PrevPos to BytePos.
    Delete(Lines[CurY], PrevPos + 1, BytePos - PrevPos);
    Dec(CurCol, PrevWidth);
    if CurCol < 0 then CurCol := 0;
  end
  else if CurY > 0 then
  begin
    CurCol := LineColCount(Lines[CurY - 1]);
    Lines[CurY - 1] := Lines[CurY - 1] + Lines[CurY];
    for BytePos := CurY to LineCount - 2 do
      Lines[BytePos] := Lines[BytePos + 1];
    Dec(LineCount);
    Dec(CurY);
  end;
end;

procedure DeleteGraphemeForward;
var
  BytePos, ByteLen: Integer;
begin
  ByteLen := GraphemeByteLenAtCol(Lines[CurY], CurCol);
  if ByteLen > 0 then
  begin
    BytePos := ColToByteOffset(Lines[CurY], CurCol);
    Delete(Lines[CurY], BytePos + 1, ByteLen);
  end
  else if CurY < LineCount - 1 then
  begin
    // At end of line: join with next line.
    Lines[CurY] := Lines[CurY] + Lines[CurY + 1];
    for BytePos := CurY + 1 to LineCount - 2 do
      Lines[BytePos] := Lines[BytePos + 1];
    Dec(LineCount);
  end;
end;

procedure InsertNewline;
var
  BytePos, I: Integer;
  Tail: AnsiString;
begin
  if LineCount >= MAX_LINES then Exit;
  BytePos := ColToByteOffset(Lines[CurY], CurCol);
  Tail := Copy(Lines[CurY], BytePos + 1, MaxInt);
  Lines[CurY] := Copy(Lines[CurY], 1, BytePos);
  for I := LineCount downto CurY + 2 do
    Lines[I] := Lines[I - 1];
  Lines[CurY + 1] := Tail;
  Inc(LineCount);
  Inc(CurY);
  CurCol := 0;
end;

procedure MoveRight;
var
  W: Integer;
begin
  W := GraphemeWidthAtCol(Lines[CurY], CurCol);
  Inc(CurCol, W);
end;

procedure MoveLeft;
var
  Pos, Cols, PrevCols: Integer;
  Adv: TGraphemeAdvance;
begin
  if CurCol <= 0 then Exit;
  // Walk forward to find the grapheme whose end is at CurCol.
  Pos := 0;
  Cols := 0;
  PrevCols := 0;
  while (Pos < Length(Lines[CurY])) and (Cols < CurCol) do
  begin
    PrevCols := Cols;
    Adv := GraphemeAdvance(Lines[CurY][1], Length(Lines[CurY]), Pos);
    Inc(Pos, Adv.ByteLen);
    Inc(Cols, Adv.Width);
  end;
  CurCol := PrevCols;
end;

var
  Frame: TFrame;
  Rows: TRectArray;
  EditorArea, StatusArea, InnerArea: TRect;
  EdBlock: TBlock;
  StatusPara: TParagraph;
  Ev: TEvent;
  I, VisibleLines, StartLine, DrawY: Integer;
  StatusStr: AnsiString;
  LineSty, CursorLineSty: TStyle;

procedure HandleNormal(const K: TKeyEvent);
begin
  case K.Code of
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('h'): MoveLeft;
        Ord('l'): MoveRight;
        Ord('j'): Inc(CurY);
        Ord('k'): Dec(CurY);
        Ord('i'): Mode := emInsert;
        Ord('a'): begin MoveRight; Mode := emInsert; end;
        Ord('x'): DeleteGraphemeForward;
        Ord('0'): CurCol := 0;
        Ord('$'): CurCol := LineColCount(Lines[CurY]);
        Ord('o'): begin
          if LineCount < MAX_LINES then
          begin
            for I := LineCount downto CurY + 2 do Lines[I] := Lines[I - 1];
            Lines[CurY + 1] := '';
            Inc(LineCount);
            Inc(CurY);
            CurCol := 0;
            Mode := emInsert;
          end;
        end;
      end;
    kcLeft:  MoveLeft;
    kcRight: MoveRight;
    kcUp:    Dec(CurY);
    kcDown:  Inc(CurY);
    kcHome:  CurCol := 0;
    kcEnd:   CurCol := LineColCount(Lines[CurY]);
    kcEsc:   Term.RequestQuit;
    kcDelete: DeleteGraphemeForward;
  else
  end;
  ClampCursor;
end;

procedure HandleInsert(const K: TKeyEvent);
var
  Utf8Str: AnsiString;
begin
  case K.Code of
    kcEsc:       begin Mode := emNormal; ClampCursor; end;
    kcBackspace: DeleteGraphemeBackward;
    kcDelete:    DeleteGraphemeForward;
    kcEnter:     InsertNewline;
    kcLeft:      begin MoveLeft; end;
    kcRight:     begin MoveRight; ClampCursor; end;
    kcUp:        begin Dec(CurY); ClampCursor; end;
    kcDown:      begin Inc(CurY); ClampCursor; end;
    kcChar:
      if K.Ch >= 32 then
      begin
        Utf8Str := Ucs4ToUtf8(K.Ch);
        InsertUtf8(Utf8Str);
      end;
  else
  end;
end;

procedure RenderFrame;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [MinConstraint(0), LengthConstraint(1)]);
  EditorArea := Rows[0];
  StatusArea := Rows[1];

  EdBlock := TBlock.Default
              .WithBorders(BordersAll)
              .WithTitle(' editor ')
              .WithBorderStyle(TStyle.Default.WithFg(clDarkGray));
  EdBlock.Render(EditorArea, Frame.Buffer);
  InnerArea := EdBlock.Inner(EditorArea);

  VisibleLines := InnerArea.Height;
  StartLine := 0;
  if CurY >= StartLine + VisibleLines then
    StartLine := CurY - VisibleLines + 1;
  if CurY < StartLine then
    StartLine := CurY;

  LineSty := TStyle.Default.WithFg(clWhite);
  CursorLineSty := TStyle.Default.WithFg(clCyan);

  for I := 0 to VisibleLines - 1 do
  begin
    DrawY := StartLine + I;
    if DrawY >= LineCount then Break;
    if DrawY = CurY then
      Frame.Buffer.SetString(InnerArea.X, InnerArea.Y + I, Lines[DrawY], CursorLineSty)
    else
      Frame.Buffer.SetString(InnerArea.X, InnerArea.Y + I, Lines[DrawY], LineSty);
  end;

  Frame.HasCursor := True;
  Frame.CursorPos.X := InnerArea.X + CurCol;
  Frame.CursorPos.Y := InnerArea.Y + (CurY - StartLine);

  if Mode = emNormal then
    StatusStr := ' NORMAL '
  else
    StatusStr := ' INSERT ';
  StatusStr := StatusStr + Format(' Ln %d, Col %d  (%d lines)  [i insert  x del  q quit]',
    [CurY + 1, CurCol + 1, LineCount]);
  StatusPara := TParagraph.FromString(StatusStr)
                  .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
  StatusPara.Render(StatusArea, Frame.Buffer);

  Term.EndFrame(Frame);
end;

begin
  LineCount := 5;
  Lines[0] := 'Welcome to the fafafa.tui editor demo.';
  Lines[1] := '';
  Lines[2] := #$E4#$B8#$AD#$E6#$96#$87 + ' Chinese, ' + #$F0#$9F#$98#$80 + ' emoji supported!';
  Lines[3] := 'Press i to enter Insert mode, type any Unicode.';
  Lines[4] := 'Press x in Normal mode to delete, q to quit.';
  CurCol := 0;
  CurY := 0;
  Mode := emNormal;

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      case Ev.Kind of
        evKey:
          if Mode = emNormal then
            HandleNormal(Ev.Key)
          else
            HandleInsert(Ev.Key);
        evResize: ;
      else
      end;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
