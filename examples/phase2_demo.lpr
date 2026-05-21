program phase2_demo;

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
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_event,
  ftui_terminal,
  ftui_tree,
  ftui_form,
  ftui_dialog,
  ftui_sparkline,
  ftui_canvas;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  TreeState: TTreeState;
  CB1, CB2, CB3: TCheckbox;
  Radio: TRadioGroup;
  ShowDialog: Boolean;
  DialogSel: Integer;
  SparkData: array[0..39] of Double;
  Tick: Integer;

procedure InitData;
var I: Integer;
begin
  for I := 0 to High(SparkData) do
    SparkData[I] := Sin(I * 0.3) * 50 + 50;
end;

procedure RenderFrame;
var
  Rows, LeftRight, LeftRows, RightRows: TRectArray;
  TreeArea, FormArea, SparkArea, CanvasArea, StatusArea: TRect;
  T: TTree;
  Spark: TSparkline;
  Canv: TCanvas;
  Dlg: TDialog;
  StatusText: AnsiString;
begin
  Frame := Term.BeginFrame;

  // Layout: main | status
  Rows := VerticalSplit(Frame.Area, [MinConstraint(0), LengthConstraint(1)]);
  StatusArea := Rows[1];

  // Main: left (tree + form) | right (sparkline + canvas)
  LeftRight := HorizontalSplit(Rows[0], [
    PercentageConstraint(50), MinConstraint(0)
  ]);

  // Left column: tree on top, form below
  LeftRows := VerticalSplit(LeftRight[0], [
    PercentageConstraint(60), MinConstraint(0)
  ]);
  TreeArea := LeftRows[0];
  FormArea := LeftRows[1];

  // Right column: sparkline on top, canvas below
  RightRows := VerticalSplit(LeftRight[1], [
    LengthConstraint(6), MinConstraint(0)
  ]);
  SparkArea := RightRows[0];
  CanvasArea := RightRows[1];

  // Tree
  T := TTree.Create([
    TTreeNode.Make('src').WithChildren([
      TTreeNode.Make('core').WithChildren([
        TTreeNode.Make('ftui_buffer.pas'),
        TTreeNode.Make('ftui_cell.pas'),
        TTreeNode.Make('ftui_color.pas')
      ]),
      TTreeNode.Make('widgets').WithChildren([
        TTreeNode.Make('ftui_table.pas'),
        TTreeNode.Make('ftui_tree.pas'),
        TTreeNode.Make('ftui_dialog.pas')
      ]),
      TTreeNode.Make('terminal').WithChildren([
        TTreeNode.Make('ftui_terminal.pas')
      ])
    ]),
    TTreeNode.Make('tests').WithChildren([
      TTreeNode.Make('test_runner.lpr')
    ]),
    TTreeNode.Make('examples').WithChildren([
      TTreeNode.Make('phase2_demo.lpr')
    ])
  ]).WithBlock(
    TBlock.Default.WithBorders(BordersAll).WithTitle(' File Tree ')
      .WithBorderStyle(TStyle.Default.WithFg(clCyan))
  ).WithHighlightStyle(TStyle.Default.WithBg(clBlue).WithFg(clWhite));
  T.RenderStateful(TreeArea, Frame.Buffer, TreeState);

  // Form controls
  Frame.Buffer.SetStyle(FormArea, TStyle.Default);
  TBlock.Default.WithBorders(BordersAll).WithTitle(' Options ')
    .WithBorderStyle(TStyle.Default.WithFg(clYellow))
    .Render(FormArea, Frame.Buffer);
  FormArea := TBlock.Default.WithBorders(BordersAll).Inner(FormArea);

  CB1.Render(TRect.Make(FormArea.X, FormArea.Y, FormArea.Width, 1), Frame.Buffer);
  CB2.Render(TRect.Make(FormArea.X, FormArea.Y + 1, FormArea.Width, 1), Frame.Buffer);
  CB3.Render(TRect.Make(FormArea.X, FormArea.Y + 2, FormArea.Width, 1), Frame.Buffer);
  if FormArea.Height > 4 then
    Radio.Render(TRect.Make(FormArea.X, FormArea.Y + 4, FormArea.Width, FormArea.Height - 4), Frame.Buffer);

  // Sparkline
  Spark := TSparkline.Create(SparkData)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' CPU Load ')
      .WithBorderStyle(TStyle.Default.WithFg(clGreen)))
    .WithStyle(TStyle.Default.WithFg(clGreen));
  Spark.Render(SparkArea, Frame.Buffer);

  // Canvas
  Canv := TCanvas.Create(CanvasArea.Width * 2, (CanvasArea.Height - 2) * 4);
  Canv.DrawRect(0, 0, Canv.Width - 1, Canv.Height - 1);
  Canv.DrawLine(0, 0, Canv.Width - 1, Canv.Height - 1);
  Canv.DrawLine(Canv.Width - 1, 0, 0, Canv.Height - 1);
  Canv.DrawCircle(Canv.Width div 2, Canv.Height div 2, Canv.Height div 3);

  TBlock.Default.WithBorders(BordersAll).WithTitle(' Canvas ')
    .WithBorderStyle(TStyle.Default.WithFg(clMagenta))
    .Render(CanvasArea, Frame.Buffer);
  Canv := Canv.WithStyle(TStyle.Default.WithFg(clLightCyan));
  Canv.Render(TBlock.Default.WithBorders(BordersAll).Inner(CanvasArea), Frame.Buffer);

  // Status bar
  StatusText := Format(' Tree:%d  Tick:%d  [t]oggle [1-3]check [r]adio [d]ialog [q]uit ',
    [TreeState.Selected, Tick]);
  Frame.Buffer.SetStringN(StatusArea.X, StatusArea.Y, StatusText,
    StatusArea.Width, TStyle.Default.WithBg(clBlue).WithFg(clWhite));

  // Dialog overlay
  if ShowDialog then
  begin
    Dlg := TDialog.Create('Confirm', 'Do you want to proceed?')
      .WithWidth(35).WithHeight(7)
      .WithButtons(['OK', 'Cancel'])
      .WithBorderStyle(TStyle.Default.WithFg(clLightRed))
      .WithActiveButtonStyle(TStyle.Default.WithModifier([mbReversed]).WithFg(clLightGreen));
    Dlg.SelectedButton := DialogSel;
    Dlg.Render(Frame.Area, Frame.Buffer);
  end;

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if ShowDialog then
  begin
    case K.Code of
      kcLeft: if DialogSel > 0 then Dec(DialogSel);
      kcRight: if DialogSel < 1 then Inc(DialogSel);
      kcEnter, kcEsc: ShowDialog := False;
    else end;
    Exit;
  end;

  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('1'): CB1.Toggle;
        Ord('2'): CB2.Toggle;
        Ord('3'): CB3.Toggle;
        Ord('r'): Radio.Select((Radio.Selected + 1) mod Length(Radio.Items));
        Ord('d'): begin ShowDialog := True; DialogSel := 0; end;
        Ord('t'), Ord(' '): TreeState.Toggle(TreeState.Selected);
      end;
    kcUp:
      if TreeState.Selected > 0 then Dec(TreeState.Selected);
    kcDown:
      if TreeState.Selected < TreeState.FlatCount - 1 then
        Inc(TreeState.Selected);
  else end;
end;

begin
  InitData;
  Term := TTerminal.Create;
  try
    TreeState := TTreeState.Empty;
    TreeState.EnsureSize(10);
    TreeState.Opened[0] := True;
    CB1 := TCheckbox.Create('Enable logging', True);
    CB2 := TCheckbox.Create('Dark mode', False);
    CB3 := TCheckbox.Create('Auto-save', True);
    Radio := TRadioGroup.Create(['Fast', 'Normal', 'Careful']);
    Radio.Selected := 1;
    ShowDialog := False;
    DialogSel := 0;
    Tick := 0;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      // Animate sparkline
      SparkData[Tick mod 40] := Sin(Tick * 0.15) * 40 + 50 + Random(10);
      RenderFrame;
      Ev := Term.PollEvent(100);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else end;
      Inc(Tick);
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
