program streaming_demo;

// Simulates LLM streaming output: characters appear one by one in a
// scrolling Paragraph, auto-scrolling to keep the latest text visible.
// Proves fafafa.tui can handle real-time incremental rendering at
// high refresh rates without flicker or allocation churn.
//
// The "stream" is a pre-baked string revealed character by character
// with a 20ms delay between chars (simulating ~50 tokens/sec).
// Press q or Esc to quit early.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_buffer,
  ftui_text,
  ftui_layout,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_event,
  ftui_terminal;

const
  STREAM_TEXT =
    'Hello! I''m a simulated AI assistant streaming my response ' +
    'character by character into a fafafa.tui Paragraph widget. ' +
    'This demonstrates that the TUI framework can handle real-time ' +
    'incremental text rendering without flicker, without allocation ' +
    'churn, and without dropping frames.' + #10 + #10 +
    'The key insight is that each frame only diffs the cells that ' +
    'actually changed — so appending one character to a long paragraph ' +
    'only emits a handful of ANSI bytes to the terminal, not the ' +
    'entire screen.' + #10 + #10 +
    'Technical details:' + #10 +
    '  - Buffer: 200x60 cell array, packed records' + #10 +
    '  - Diff: dual-counter algorithm (ratatui-faithful)' + #10 +
    '  - Backend: style-cached ANSI byte builder' + #10 +
    '  - Frame time: ~191us on 80x24 (5000+ fps headroom)' + #10 + #10 +
    'Stream complete. Press q to exit.';

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Rows: TRectArray;
  TitleArea, BodyArea, StatusArea: TRect;
  Title, Status: TParagraph;
  Body: TParagraph;
  BodyBlock: TBlock;
  Revealed: Integer;
  VisibleText: AnsiString;
  TotalChars: Integer;
  ScrollY: Integer;
  InnerH: Integer;

procedure RenderFrame;
var
  TextHeight: Integer;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(1)
  ]);
  TitleArea := Rows[0];
  BodyArea  := Rows[1];
  StatusArea := Rows[2];

  Title := TParagraph.FromString(' streaming demo — AI response simulation ')
            .WithStyle(TStyle.Default.WithBg(clYellow).WithFg(clBlack))
            .WithAlignment(caCenter);
  Title.Render(TitleArea, Frame.Buffer);

  VisibleText := Copy(STREAM_TEXT, 1, Revealed);
  BodyBlock := TBlock.Default
                .WithBorders(BordersAll)
                .WithTitle(' response ')
                .WithBorderStyle(TStyle.Default.WithFg(clDarkGray));
  InnerH := BodyArea.Height - 2;

  // Auto-scroll: count lines in visible text, scroll if exceeds inner height.
  TextHeight := 1;
  for ScrollY := 1 to Length(VisibleText) do
    if VisibleText[ScrollY] = #10 then Inc(TextHeight);
  if TextHeight > InnerH then
    ScrollY := TextHeight - InnerH
  else
    ScrollY := 0;

  Body := TParagraph.FromString(VisibleText)
            .WithBlock(BodyBlock)
            .WithWrap(WrapTrim)
            .WithScrollY(ScrollY)
            .WithStyle(TStyle.Default.WithFg(clGreen));
  Body.Render(BodyArea, Frame.Buffer);

  Status := TParagraph.FromString(Format(' chars: %d/%d  [q quit]', [Revealed, TotalChars]))
              .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
  Status.Render(StatusArea, Frame.Buffer);

  Term.EndFrame(Frame);
end;

begin
  TotalChars := Length(STREAM_TEXT);
  Revealed := 0;

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;

    while not Term.ShouldQuit do
    begin
      // Advance the stream by one character per iteration.
      if Revealed < TotalChars then
        Inc(Revealed);

      RenderFrame;

      // Poll with 20ms timeout — gives ~50 chars/sec streaming speed.
      // If user presses a key during the timeout, we handle it immediately.
      Ev := Term.PollEvent(20);
      case Ev.Kind of
        evKey:
          case Ev.Key.Code of
            kcEsc: Term.RequestQuit;
            kcChar:
              if (Ev.Key.Ch = Ord('q')) or (Ev.Key.Ch = Ord('Q')) then
                Term.RequestQuit;
          else
          end;
      else
      end;

      // If stream is complete, switch to blocking wait.
      if Revealed >= TotalChars then
      begin
        RenderFrame;
        repeat
          Ev := Term.PollEvent(-1);
        until (Ev.Kind = evKey) and
              ((Ev.Key.Code = kcEsc) or
               ((Ev.Key.Code = kcChar) and ((Ev.Key.Ch = Ord('q')) or (Ev.Key.Ch = Ord('Q')))));
        Term.RequestQuit;
      end;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
