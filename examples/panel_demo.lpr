program panel_demo;

{$mode objfpc}{$H+}

uses
  ftui_app,
  ftui_event,
  ftui_terminal,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_buffer,
  ftui_block,
  ftui_borders,
  ftui_layout,
  ftui_panel,
  ftui_paragraph,
  ftui_list,
  ftui_gauge,
  ftui_sparkline,
  ftui_table;

type
  TPanelDemoApp = class(TApp)
  private
    FSelected: Integer;
    FTableState: TTableState;
    FTick: Integer;
    FSparkData: array[0..39] of Double;
  protected
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure OnInit; override;
    procedure OnTick; override;
  end;

procedure TPanelDemoApp.OnInit;
var I: Integer;
begin
  FSelected := 0;
  FTableState := TTableState.Empty;
  FTick := 0;
  for I := 0 to High(FSparkData) do
    FSparkData[I] := 0;
  TickInterval := 200;
end;

procedure TPanelDemoApp.OnTick;
var I: Integer;
begin
  Inc(FTick);
  for I := 0 to High(FSparkData) - 1 do
    FSparkData[I] := FSparkData[I + 1];
  FSparkData[High(FSparkData)] := 20 + Random(60);
end;

procedure TPanelDemoApp.Render(var Frame: TFrame);
var
  Panel: TPanel;
  G: TPanelGrid;
  SidebarArea, HeaderArea, ContentArea, StatusArea: TRect;
  ListItems: array[0..7] of TListItem;
  ListState: TListState;
  Cols: array[0..2] of TTableColumn;
  Rows: array[0..4] of TTableRow;
  S: string[8];
begin
  // Single panel: 2 cols × 3 rows
  // H-separators only in column 1 (right side)
  Panel := TPanel.Create(
    [LengthConstraint(24), MinConstraint(0)],
    [LengthConstraint(1), MinConstraint(0), LengthConstraint(1)]
  ).WithBorderSet(BorderSetRounded)
   .WithBorderStyle(TStyle.Default.WithFg(clCyan))
   .WithHSepStartCol(1);

  G := Panel.Render(Frame.Area, Frame.Buffer);

  // Left sidebar spans all 3 rows visually (no H-sep in col 0)
  SidebarArea := TRect.Make(
    PanelCell(G, 0, 0).X, PanelCell(G, 0, 0).Y,
    PanelCell(G, 0, 0).Width,
    PanelCell(G, 0, 2).Y + PanelCell(G, 0, 2).Height - PanelCell(G, 0, 0).Y);
  HeaderArea  := PanelCell(G, 1, 0);
  ContentArea := PanelCell(G, 1, 1);
  StatusArea  := PanelCell(G, 1, 2);

  // === Left sidebar: navigation list ===
  ListItems[0] := TListItem.FromString(' Dashboard');
  ListItems[1] := TListItem.FromString(' Processes');
  ListItems[2] := TListItem.FromString(' Network');
  ListItems[3] := TListItem.FromString(' Storage');
  ListItems[4] := TListItem.FromString(' Logs');
  ListItems[5] := TListItem.FromString(' Settings');
  ListItems[6] := TListItem.FromString(' Help');
  ListItems[7] := TListItem.FromString(' About');

  ListState := TListState.Empty;
  ListState.Select(FSelected);
  TList.Create(ListItems)
    .WithStyle(TStyle.Default)
    .WithHighlightStyle(TStyle.Default.WithFg(clBlack).WithBg(clCyan))
    .RenderStateful(SidebarArea, Frame.Buffer, ListState);

  // === Header: title ===
  TParagraph.FromString(' Panel Demo - System Monitor')
    .WithStyle(TStyle.Default.WithFg(clYellow).WithModifier([mbBold]))
    .Render(HeaderArea, Frame.Buffer);

  // === Content: table + sparkline ===
  if ContentArea.Height > 8 then
  begin
    Cols[0] := TTableColumn.Make('PID', LengthConstraint(8));
    Cols[1] := TTableColumn.Make('Name', MinConstraint(12));
    Cols[2] := TTableColumn.Make('CPU%', LengthConstraint(8)).WithAlign(caRight);

    Rows[0] := TTableRow.Make(['1234', 'fpc', '12.3']);
    Rows[1] := TTableRow.Make(['5678', 'panel_demo', '8.1']);
    Rows[2] := TTableRow.Make(['9012', 'Xorg', '5.4']);
    Rows[3] := TTableRow.Make(['3456', 'bash', '0.2']);
    Rows[4] := TTableRow.Make(['7890', 'tmux', '0.1']);

    TTable.Create(Cols)
      .WithRows(Rows)
      .WithStyle(TStyle.Default)
      .WithHeaderStyle(TStyle.Default.WithModifier([mbBold]))
      .WithHighlightStyle(TStyle.Default.WithBg(IndexedColor(236)))
      .RenderStateful(
        TRect.Make(ContentArea.X, ContentArea.Y, ContentArea.Width, ContentArea.Height - 4),
        Frame.Buffer, FTableState);

    TSparkline.Create(FSparkData)
      .WithStyle(TStyle.Default.WithFg(clGreen))
      .Render(
        TRect.Make(ContentArea.X, ContentArea.Y + ContentArea.Height - 4, ContentArea.Width, 3),
        Frame.Buffer);
  end;

  // === Status bar ===
  Str(FTick, S);
  TParagraph.FromString(' Tick: ' + S + '  |  q=quit  j/k=navigate')
    .WithStyle(TStyle.Default.WithFg(clDarkGray))
    .Render(StatusArea, Frame.Buffer);
end;

procedure TPanelDemoApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcChar:
      case Ev.Key.Ch of
        Ord('q'), Ord('Q'): Quit;
        Ord('j'): if FSelected < 7 then Inc(FSelected);
        Ord('k'): if FSelected > 0 then Dec(FSelected);
      end;
    kcDown: if FSelected < 7 then Inc(FSelected);
    kcUp: if FSelected > 0 then Dec(FSelected);
  end;
end;

var App: TPanelDemoApp;
begin
  Randomize;
  App := TPanelDemoApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
