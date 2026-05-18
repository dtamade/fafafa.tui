program editor_demo;

// Minimal multi-line text editor proving fafafa.tui can handle
// character-level input, cursor positioning, and mode switching.
//
// Features:
//   - Normal mode: hjkl navigation, i to enter Insert, q to quit
//   - Insert mode: type characters, Backspace deletes, Esc returns
//     to Normal
//   - Visible cursor (blinking bar in Insert, steady block in Normal)
//   - Status bar shows mode + cursor position
//   - Bordered editing area with title
//   - Resize-aware

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
  ftui_event,
  ftui_terminal;

const
  MAX_LINES = 100;

type
  TEditorMode = (emNormal, emInsert);

var
  Term: TTerminal;
  Mode: TEditorMode;
  Lines: array[0..MAX_LINES - 1] of AnsiString;
  LineCount: Integer;
  CurX, CurY: Integer;
  Frame: TFrame;
  Rows: TRectArray;
  EditorArea, StatusArea, InnerArea: TRect;
  EdBlock: TBlock;
  StatusPara: TParagraph;
  Ev: TEvent;
  I, VisibleLines, StartLine, DrawY: Integer;
  StatusStr: AnsiString;

procedure ClampCursor;
begin
  if CurY < 0 then CurY := 0;
  if CurY >= LineCount then CurY := LineCount - 1;
  if CurX < 0 then CurX := 0;
  if CurX > Length(Lines[CurY]) then CurX := Length(Lines[CurY]);
end;

procedure InsertChar(Ch: AnsiChar);
begin
  Insert(Ch, Lines[CurY], CurX + 1);
  Inc(CurX);
end;

procedure DeleteChar;
begin
  if CurX > 0 then
  begin
    Delete(Lines[CurY], CurX, 1);
    Dec(CurX);
  end
  else if CurY > 0 then
  begin
    CurX := Length(Lines[CurY - 1]);
    Lines[CurY - 1] := Lines[CurY - 1] + Lines[CurY];
    for I := CurY to LineCount - 2 do
      Lines[I] := Lines[I + 1];
    Dec(LineCount);
    Dec(CurY);
  end;
end;

procedure InsertNewline;
var
  Tail: AnsiString;
begin
  if LineCount >= MAX_LINES then Exit;
  Tail := Copy(Lines[CurY], CurX + 1, MaxInt);
  Lines[CurY] := Copy(Lines[CurY], 1, CurX);
  for I := LineCount downto CurY + 2 do
    Lines[I] := Lines[I - 1];
  Lines[CurY + 1] := Tail;
  Inc(LineCount);
  Inc(CurY);
  CurX := 0;
end;

procedure HandleNormal(const K: TKeyEvent);
begin
  case K.Code of
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('h'): Dec(CurX);
        Ord('l'): Inc(CurX);
        Ord('j'): Inc(CurY);
        Ord('k'): Dec(CurY);
        Ord('i'): Mode := emInsert;
        Ord('a'): begin Inc(CurX); Mode := emInsert; end;
        Ord('o'): begin
          if LineCount < MAX_LINES then
          begin
            for I := LineCount downto CurY + 2 do Lines[I] := Lines[I - 1];
            Lines[CurY + 1] := '';
            Inc(LineCount);
            Inc(CurY);
            CurX := 0;
            Mode := emInsert;
          end;
        end;
        Ord('0'): CurX := 0;
        Ord('$'): CurX := Length(Lines[CurY]);
      end;
    kcLeft:  Dec(CurX);
    kcRight: Inc(CurX);
    kcUp:    Dec(CurY);
    kcDown:  Inc(CurY);
    kcHome:  CurX := 0;
    kcEnd:   CurX := Length(Lines[CurY]);
    kcEsc:   Term.RequestQuit;
  else
  end;
  ClampCursor;
end;

procedure HandleInsert(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc:       Mode := emNormal;
    kcBackspace: DeleteChar;
    kcEnter:     InsertNewline;
    kcLeft:      begin Dec(CurX); ClampCursor; end;
    kcRight:     begin Inc(CurX); ClampCursor; end;
    kcUp:        begin Dec(CurY); ClampCursor; end;
    kcDown:      begin Inc(CurY); ClampCursor; end;
    kcChar:
      if (K.Ch >= 32) and (K.Ch < 127) then
        InsertChar(AnsiChar(K.Ch));
  else
  end;
  ClampCursor;
end;

procedure RenderFrame;
var
  LineSty, CursorLineSty: TStyle;
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

  // Cursor position.
  Frame.HasCursor := True;
  Frame.CursorPos.X := InnerArea.X + CurX;
  Frame.CursorPos.Y := InnerArea.Y + (CurY - StartLine);

  // Status bar.
  if Mode = emNormal then
    StatusStr := ' NORMAL '
  else
    StatusStr := ' INSERT ';
  StatusStr := StatusStr + Format(' Ln %d, Col %d  (%d lines)  [q quit, i insert]',
    [CurY + 1, CurX + 1, LineCount]);
  StatusPara := TParagraph.FromString(StatusStr)
                  .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
  StatusPara.Render(StatusArea, Frame.Buffer);

  Term.EndFrame(Frame);
end;

begin
  LineCount := 5;
  Lines[0] := 'Welcome to the fafafa.tui editor demo.';
  Lines[1] := '';
  Lines[2] := 'Press i to enter Insert mode, type text.';
  Lines[3] := 'Press Esc to return to Normal mode.';
  Lines[4] := 'Press q in Normal mode to quit.';
  CurX := 0;
  CurY := 0;
  Mode := emNormal;

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then
    begin
      WriteLn('not a tty');
      Halt(1);
    end;

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
