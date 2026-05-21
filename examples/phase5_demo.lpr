program phase5_demo;

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
  ftui_event,
  ftui_terminal,
  ftui_theme,
  ftui_anim,
  ftui_statusbar,
  ftui_toast,
  ftui_textarea,
  ftui_barchart,
  ftui_linechart;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Theme: TTheme;
  Toasts: TToastManager;
  Spinner: TSpinner;
  TAState: TTextAreaState;
  Tick: Integer;

procedure RenderFrame;
var
  Rows, Cols: TRectArray;
  RightRows: TRectArray;
  EditorArea, RightArea, ToastContainer: TRect;
  TA: TTextArea;
  SB: TStatusBar;
begin
  Frame := Term.BeginFrame;
  Frame.Buffer.SetStyle(Frame.Area, Theme.Bg);

  // Layout: editor | right panel, status bar at bottom
  Rows := V(Frame.Area, [Flex(1), Fixed(1)]);

  Cols := H(Rows[0], [Flex(2), Flex(1)]);
  EditorArea := Cols[0];
  RightArea := Cols[1];

  // Text editor
  TA := TTextArea.Create(
    'unit hello;' + #10 +
    '' + #10 +
    '{$mode objfpc}{$H+}' + #10 +
    '' + #10 +
    'interface' + #10 +
    '' + #10 +
    'procedure SayHello;' + #10 +
    '' + #10 +
    'implementation' + #10 +
    '' + #10 +
    'procedure SayHello;' + #10 +
    'begin' + #10 +
    '  WriteLn(''Hello, fafafa.tui!'');' + #10 +
    'end;' + #10 +
    '' + #10 +
    'end.'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Editor ')
    .WithBorderStyle(Theme.BorderFocused))
  .WithStyle(Theme.Fg)
  .WithLineNumStyle(Theme.Muted);
  TA.RenderStateful(EditorArea, Frame.Buffer, TAState);

  // Right panel: split into chart + info
  RightRows := V(RightArea, [Flex(1), Fixed(8), Fixed(6)]);

  // Line chart at top-right
  TLineChart.Create([
    TDataSeries.Create('CPU', [20, 45, 30, 60, 80, 55, 70, 40 + (Tick mod 20)]),
    TDataSeries.Create('Mem', [50, 52, 55, 53, 58, 60, 57, 55 + (Tick mod 10)])
  ]).WithShowAxes(True)
  .WithShowLegend(True)
  .WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' LineChart ')
    .WithBorderStyle(Theme.Border))
  .WithStyle(Theme.Fg)
  .Render(RightRows[0], Frame.Buffer);

  // Bar chart in middle-right
  TBarChart.Create([
    TBarData.Make('Mon', 12),
    TBarData.Make('Tue', 28),
    TBarData.Make('Wed', 18),
    TBarData.Make('Thu', 35),
    TBarData.Make('Fri', 22)
  ]).WithShowLabels(True)
  .WithShowValues(True)
  .WithBarWidth(3)
  .WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' BarChart ')
    .WithBorderStyle(Theme.Border))
  .WithStyle(Theme.Fg)
  .Render(RightRows[1], Frame.Buffer);

  // Info panel at bottom-right
  TParagraph.FromString(
    Format('%s Phase 5', [Spinner.Frame(Tick)]) + #10 +
    'n/e/s/w=toast q=quit'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Keys ')
    .WithBorderStyle(Theme.Border))
  .WithStyle(Theme.Fg)
  .Render(RightRows[2], Frame.Buffer);

  // Status bar
  SB := TStatusBar.Default
    .WithStyle(Theme.StatusBar)
    .WithLeft([
      TStatusSegment.Make(' NORMAL ').WithStyle(Theme.Primary),
      TStatusSegment.Make(Format(' Ln %d Col %d ', [TAState.CursorRow + 1, TAState.CursorCol + 1]))
    ])
    .WithCenter([TStatusSegment.Make(' fafafa.tui ')])
    .WithRight([
      TStatusSegment.Make(Format(' %d toasts ', [Toasts.Count])),
      TStatusSegment.Make(' UTF-8 ')
    ]);
  SB.Render(Rows[1], Frame.Buffer);

  // Toast overlay
  ToastContainer := Frame.Area;
  Toasts.Render(ToastContainer, Frame.Buffer);

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('n'): Toasts.Push(Format('Info at tick %d', [Tick]), tlInfo);
        Ord('e'): Toasts.Push('Something went wrong!', tlError);
        Ord('s'): Toasts.Push('File saved', tlSuccess);
        Ord('w'): Toasts.Push('Low disk space', tlWarning);
      end;
    kcUp:
      if TAState.CursorRow > 0 then Dec(TAState.CursorRow);
    kcDown:
      Inc(TAState.CursorRow);
    kcLeft:
      if TAState.CursorCol > 0 then Dec(TAState.CursorCol);
    kcRight:
      Inc(TAState.CursorCol);
  else end;
end;

begin
  Term := TTerminal.Create;
  Toasts := TToastManager.Create;
  try
    Theme := TTheme.Nord;
    Spinner := TSpinner.Create(skBraille);
    TAState := TTextAreaState.Empty;
    Tick := 0;
    Toasts.DurationMs := 2000;
    Toasts.Position := tpTopRight;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      Toasts.Tick(100);
      RenderFrame;
      Ev := Term.PollEvent(100);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else end;
      Inc(Tick);
    end;
  finally
    Term.LeaveTui;
    Toasts.Free;
    Term.Free;
  end;
end.
