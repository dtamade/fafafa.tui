program input_editor_demo;

// Interactive demo for TInputEditor enhanced features:
//   - Selection (Shift+arrows, Ctrl+A)
//   - Clipboard (Ctrl+C/X/V)
//   - Undo/Redo (Ctrl+Z/Y)
//   - Word movement (Ctrl+Left/Right)
//   - Delete line (Ctrl+D)
//   - Selection highlighting with custom style

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
  ftui_input_editor,
  ftui_event,
  ftui_terminal;

var
  Term: TTerminal;
  Editor: TInputEditor;
  StatusMsg: AnsiString;
  StatusTick: Integer;

procedure ShowStatus(const Msg: AnsiString);
begin
  StatusMsg := Msg;
  StatusTick := 30;
end;

procedure RenderFrame;
var
  Frame: TFrame;
  Rows: TRectArray;
  EditorArea, StatusArea, HelpArea, InnerArea: TRect;
  EdBlock: TBlock;
  TextSty, PlaceholderSty, SelectionSty: TStyle;
  StatusStr, HelpStr: AnsiString;
  CurPos: TPosition;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [
    MinConstraint(0),
    LengthConstraint(1),
    LengthConstraint(3)
  ]);
  EditorArea := Rows[0];
  StatusArea := Rows[1];
  HelpArea := Rows[2];
  EdBlock := TBlock.Default
              .WithBorders(BordersAll)
              .WithTitle(' Input Editor Demo ')
              .WithBorderStyle(TStyle.Default.WithFg(clCyan));
  EdBlock.Render(EditorArea, Frame.Buffer);
  InnerArea := EdBlock.Inner(EditorArea);

  TextSty := TStyle.Default.WithFg(clWhite);
  PlaceholderSty := TStyle.Default.WithFg(clDarkGray).WithModifier([mbItalic]);
  SelectionSty := TStyle.Default.WithBg(clBlue).WithFg(clWhite);

  Editor.Render(InnerArea, Frame.Buffer, TextSty, PlaceholderSty, SelectionSty,
    'Type here... (Ctrl+A select all, Ctrl+C copy, Ctrl+V paste)');

  CurPos := Editor.CursorScreenPos(InnerArea);
  Frame.HasCursor := True;
  Frame.CursorPos := CurPos;

  // Status bar
  if StatusTick > 0 then
    StatusStr := ' ' + StatusMsg
  else
    StatusStr := Format(' Ln %d  Col %d  Lines %d  |  %s',
      [CurPos.Y - InnerArea.Y + 1 + Editor.ScrollRow,
       CurPos.X - InnerArea.X + 1,
       Editor.LineCount,
       BoolToStr(Editor.IsEmpty, 'empty', IntToStr(Length(Editor.Content)) + ' bytes')]);
  Frame.Buffer.SetStringN(StatusArea.X, StatusArea.Y, StatusStr, StatusArea.Width,
    TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));

  // Help area
  HelpStr := ' Shift+Arrows: select | Ctrl+A: all | Ctrl+C/X/V: copy/cut/paste';
  Frame.Buffer.SetStringN(HelpArea.X, HelpArea.Y, HelpStr, HelpArea.Width,
    TStyle.Default.WithFg(clDarkGray));
  HelpStr := ' Ctrl+Z: undo | Ctrl+Y: redo | Ctrl+Left/Right: word | Ctrl+D: del line';
  Frame.Buffer.SetStringN(HelpArea.X, HelpArea.Y + 1, HelpStr, HelpArea.Width,
    TStyle.Default.WithFg(clDarkGray));
  HelpStr := ' Shift+Enter: newline | Esc: quit';
  Frame.Buffer.SetStringN(HelpArea.X, HelpArea.Y + 2, HelpStr, HelpArea.Width,
    TStyle.Default.WithFg(clDarkGray));

  Term.EndFrame(Frame);
end;

var
  Ev: TEvent;
begin
  Editor := TInputEditor.CreateWithMaxLines(50);
  StatusMsg := '';
  StatusTick := 0;

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      if StatusTick > 0 then Dec(StatusTick);
      case Ev.Kind of
        evKey:
        begin
          if Ev.Key.Code = kcEsc then
            Term.RequestQuit
          else if (Ev.Key.Code = kcEnter) and not (kmShift in Ev.Key.Modifiers) and not (kmAlt in Ev.Key.Modifiers) then
            ShowStatus('Enter pressed (would send). Use Shift+Enter for newline.')
          else
            Editor.HandleKey(Ev.Key);
        end;
        evResize: ;
      else
      end;
    end;
  finally
    Term.LeaveTui; Term.Free; Editor.Free;
  end;
end.
