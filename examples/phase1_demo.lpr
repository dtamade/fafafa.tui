program phase1_demo;

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
  ftui_terminal,
  ftui_focus,
  ftui_table,
  ftui_gauge,
  ftui_tabs;

var
  Term: TTerminal;
  FM: TFocusManager;
  Frame: TFrame;
  Ev: TEvent;
  TabState: TTabsState;
  TableState: TTableState;
  Progress: Double;
  Tick: Integer;

procedure RenderFrame;
var
  Rows, Cols: TRectArray;
  TabArea, MainArea, StatusArea: TRect;
  LeftArea, RightArea: TRect;
  TableArea, GaugeArea: TRect;
  Tb: TTable;
  G: TGauge;
  Tabs: TTabs;
  InfoBlock: TBlock;
  Info: TParagraph;
  StatusText: AnsiString;
begin
  Frame := Term.BeginFrame;
  FM.BeginFrame;

  // Top-level layout: tabs | main | status
  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(1)
  ]);
  TabArea := Rows[0];
  MainArea := Rows[1];
  StatusArea := Rows[2];

  // Tabs at top
  Tabs := TTabs.Create(['Table', 'Progress', 'Info'])
    .WithActiveStyle(TStyle.Default.WithFg(clWhite).WithModifier([mbBold]))
    .WithInactiveStyle(TStyle.Default.WithFg(clGray));
  Tabs.RenderStateful(TabArea, Frame.Buffer, TabState);

  // Main area split: left (table) | right (gauge + info)
  Cols := HorizontalSplit(MainArea, [
    PercentageConstraint(60),
    MinConstraint(0)
  ]);
  LeftArea := Cols[0];
  RightArea := Cols[1];

  // Right side: gauge on top, info below
  Rows := VerticalSplit(RightArea, [
    LengthConstraint(3),
    MinConstraint(0)
  ]);
  GaugeArea := Rows[0];
  TableArea := LeftArea;

  // Register focus areas
  FM.RegisterWithId(1, TableArea);
  FM.RegisterWithId(2, GaugeArea);

  // Render table
  Tb := TTable.Create([
    TTableColumn.Make('PID', LengthConstraint(6)),
    TTableColumn.Make('Name', MinConstraint(0)),
    TTableColumn.Make('CPU%', LengthConstraint(6)).WithAlign(caRight),
    TTableColumn.Make('Mem', LengthConstraint(8)).WithAlign(caRight)
  ]).WithRows([
    TTableRow.Make(['1', 'systemd', '0.1', '12 MB']),
    TTableRow.Make(['42', 'fpc', '15.3', '256 MB']),
    TTableRow.Make(['99', 'vim', '2.1', '48 MB']),
    TTableRow.Make(['128', 'htop', '0.8', '16 MB']),
    TTableRow.Make(['256', 'bash', '0.0', '8 MB']),
    TTableRow.Make(['512', 'sshd', '0.2', '24 MB']),
    TTableRow.Make(['1024', 'nginx', '1.5', '64 MB']),
    TTableRow.Make(['2048', 'postgres', '8.7', '512 MB'])
  ]).WithBlock(
    TBlock.Default.WithBorders(BordersAll).WithTitle(' Processes ')
      .WithBorderStyle(TStyle.Default.WithFg(clCyan))
  ).WithHighlightStyle(
    TStyle.Default.WithBg(clBlue).WithFg(clWhite)
  ).WithHeaderStyle(
    TStyle.Default.WithFg(clYellow).WithModifier([mbBold])
  );
  Tb.RenderStateful(TableArea, Frame.Buffer, TableState);

  // Render gauge
  G := TGauge.Default
    .WithRatio(Progress)
    .WithLabel(Format('%d%%', [Round(Progress * 100)]))
    .WithFilledStyle(TStyle.Default.WithFg(clGreen).WithBg(clBlack))
    .WithEmptyStyle(TStyle.Default.WithFg(clDarkGray).WithBg(clBlack));

  InfoBlock := TBlock.Default.WithBorders(BordersAll).WithTitle(' Build ')
    .WithBorderStyle(TStyle.Default.WithFg(clGreen));
  InfoBlock.Render(GaugeArea, Frame.Buffer);
  G.Render(InfoBlock.Inner(GaugeArea), Frame.Buffer);

  // Info panel below gauge
  Info := TParagraph.FromString(
    'Phase 1 Demo' + #10 +
    '  Focus: ' + IntToStr(FM.FocusedId) + #10 +
    '  Tab: ' + IntToStr(TabState.Selected) + #10 +
    '  Tick: ' + IntToStr(Tick) + #10 + #10 +
    'Keys:' + #10 +
    '  Tab     - switch focus' + #10 +
    '  Up/Down - scroll table' + #10 +
    '  1/2/3   - switch tab' + #10 +
    '  Space   - advance progress' + #10 +
    '  q       - quit'
  ).WithBlock(
    TBlock.Default.WithBorders(BordersAll).WithTitle(' Help ')
      .WithBorderStyle(TStyle.Default.WithFg(clMagenta))
  ).WithStyle(TStyle.Default.WithFg(clWhite));
  Info.Render(Rows[1], Frame.Buffer);

  // Status bar
  StatusText := Format(' focus:%d  tab:%d  progress:%.0f%%  rows:%d ',
    [FM.FocusedId, TabState.Selected, Progress * 100, 8]);
  Frame.Buffer.SetStringN(StatusArea.X, StatusArea.Y, StatusText,
    StatusArea.Width, TStyle.Default.WithBg(clBlue).WithFg(clWhite));

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if FM.HandleKey(K) then Exit;
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('1'): TabState.Selected := 0;
        Ord('2'): TabState.Selected := 1;
        Ord('3'): TabState.Selected := 2;
        Ord(' '):
        begin
          Progress := Progress + 0.05;
          if Progress > 1.0 then Progress := 0.0;
        end;
      end;
    kcUp:
      if TableState.Selected > 0 then
      begin
        TableState.HasSelection := True;
        Dec(TableState.Selected);
      end;
    kcDown:
    begin
      TableState.HasSelection := True;
      if TableState.Selected < 7 then
        Inc(TableState.Selected);
    end;
  else
  end;
end;

begin
  Term := TTerminal.Create;
  FM := TFocusManager.Create;
  try
    TabState.Selected := 0;
    TableState := TTableState.Empty;
    TableState.Select(0);
    Progress := 0.35;
    Tick := 0;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else
      end;
      Inc(Tick);
    end;
  finally
    Term.LeaveTui;
    FM.Free;
    Term.Free;
  end;
end.
