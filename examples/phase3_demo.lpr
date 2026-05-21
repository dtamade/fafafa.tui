program phase3_demo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_layout,
  ftui_layout_dsl,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_gauge,
  ftui_event,
  ftui_terminal,
  ftui_frame_budget,
  ftui_clipboard;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Budget: TFrameBudget;
  Clip: TClipboard;
  Tick: Integer;
  SpinIdx: Integer;
  ClipContent: AnsiString;

const
  SPINNER: array[0..3] of Char = ('|', '/', '-', '\');

procedure RenderFrame;
var
  Rows, Cols: TRectArray;
  BudgetArea, ClipArea, InfoArea, StatusArea: TRect;
  G: TGauge;
  BudgetText, ClipText, InfoText: AnsiString;
begin
  Budget.BeginFrame;
  Frame := Term.BeginFrame;

  // Use DSL for layout
  Rows := V(Frame.Area, [Flex(1), Fixed(1)]);
  StatusArea := Rows[1];

  Cols := H(Rows[0], [Pct(50), Flex(1)]);

  // Left: budget stats + gauge
  Rows := V(Cols[0], [Fixed(8), Flex(1)]);
  BudgetArea := Rows[0];
  ClipArea := Rows[1];

  // Right: info
  InfoArea := Cols[1];

  // Frame budget panel
  BudgetText := Format(
    'Frames: %d' + #10 +
    'Avg:    %.2f ms' + #10 +
    'Min:    %.2f ms' + #10 +
    'Max:    %.2f ms' + #10 +
    'Last:   %.2f ms' + #10 +
    'Over:   %d (%.1f%%)',
    [Budget.Stats.FrameCount, Budget.Stats.AvgMs,
     Budget.Stats.MinMs, Budget.Stats.MaxMs,
     Budget.Stats.LastMs, Budget.Stats.OverBudgetCount,
     Budget.Stats.OverBudgetPct]);
  TParagraph.FromString(BudgetText)
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Frame Budget (16ms) ')
      .WithBorderStyle(TStyle.Default.WithFg(clGreen)))
    .WithStyle(TStyle.Default.WithFg(clWhite))
    .Render(BudgetArea, Frame.Buffer);

  // Clipboard panel
  ClipText := 'Method: ';
  case Clip.Method of
    cmOSC52: ClipText := ClipText + 'OSC 52';
    cmExternal: ClipText := ClipText + 'External (' + Clip.ExternalTool + ')';
    cmNone: ClipText := ClipText + 'None';
  end;
  ClipText := ClipText + #10 + #10 + 'Content: ' + ClipContent;
  ClipText := ClipText + #10 + #10 + '[c] copy  [v] paste  [x] clear';
  TParagraph.FromString(ClipText)
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Clipboard ')
      .WithBorderStyle(TStyle.Default.WithFg(clCyan)))
    .WithStyle(TStyle.Default.WithFg(clWhite))
    .Render(ClipArea, Frame.Buffer);

  // Info panel with Layout DSL showcase
  InfoText :=
    'Phase 3 Features:' + #10 + #10 +
    '1. Frame Budget System' + #10 +
    '   - Per-frame timing' + #10 +
    '   - Auto-degrade on overrun' + #10 + #10 +
    '2. Event Loop + Ticker' + #10 +
    '   - Timer-based polling' + #10 +
    '   - Message queue' + #10 + #10 +
    '3. OS Clipboard' + #10 +
    '   - OSC 52 (SSH-safe)' + #10 +
    '   - xclip/xsel/pbcopy' + #10 + #10 +
    '4. Layout DSL' + #10 +
    '   - V([Flex(1), Fixed(1)])' + #10 +
    '   - H([Pct(50), Flex(1)])' + #10 + #10 +
    Format('Spinner: %s  Tick: %d', [SPINNER[SpinIdx], Tick]);
  TParagraph.FromString(InfoText)
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Info ')
      .WithBorderStyle(TStyle.Default.WithFg(clMagenta)))
    .WithStyle(TStyle.Default.WithFg(clWhite))
    .Render(InfoArea, Frame.Buffer);

  // Status bar with gauge showing frame budget usage
  G := TGauge.Default
    .WithRatio(Budget.Stats.LastMs / Budget.BudgetMs)
    .WithLabel(Format('%.1fms / %.0fms', [Budget.Stats.LastMs, Budget.BudgetMs]))
    .WithFilledStyle(TStyle.Default.WithFg(clGreen).WithBg(clBlack))
    .WithEmptyStyle(TStyle.Default.WithFg(clDarkGray).WithBg(clBlack));
  G.Render(StatusArea, Frame.Buffer);

  Term.EndFrame(Frame);
  Budget.EndFrame;
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('c'):
        begin
          ClipContent := Format('Copied at tick %d', [Tick]);
          Clip.Copy(ClipContent);
        end;
        Ord('v'):
          ClipContent := Clip.Paste;
        Ord('x'):
          ClipContent := '';
      end;
  else end;
end;

begin
  Term := TTerminal.Create;
  try
    Budget := TFrameBudget.Create(16.0);
    Clip := TClipboard.Detect;
    ClipContent := '';
    Tick := 0;
    SpinIdx := 0;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(100);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else end;
      Inc(Tick);
      SpinIdx := Tick mod 4;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
