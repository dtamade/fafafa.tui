program bench_fullscreen;

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
  ftui_list,
  ftui_table,
  ftui_panel,
  ftui_sparkline,
  ftui_ansi_backend;

const
  WIDTH  = 200;
  HEIGHT = 60;
  FRAMES = 1000;

var
  Prev, Curr, Tmp: TBuffer;
  Backend: TAnsiBackend;
  Patches: TDiffEntries;
  Frame, I: Integer;
  StartTick, EndTick: Int64;
  TotalMs, PerFrameUs: Double;
  Panel: TPanel;
  G: TPanelGrid;
  ListItems: array[0..19] of TListItem;
  ListSt: TListState;
  Cols: array[0..2] of TTableColumn;
  Rows: array[0..9] of TTableRow;
  TableSt: TTableState;
  SparkData: array[0..39] of Double;
  Area: TRect;

begin
  Area := TRect.Make(0, 0, WIDTH, HEIGHT);
  Prev := TBuffer.CreateEmpty(Area);
  Curr := TBuffer.CreateEmpty(Area);
  Backend := TAnsiBackend.Create(-1);

  for I := 0 to 19 do
    ListItems[I] := TListItem.FromString('Item ' + IntToStr(I + 1));
  for I := 0 to 39 do
    SparkData[I] := 10 + (I mod 20) * 3.5;

  Cols[0] := TTableColumn.Make('PID', LengthConstraint(8));
  Cols[1] := TTableColumn.Make('Name', MinConstraint(12));
  Cols[2] := TTableColumn.Make('CPU%', LengthConstraint(8));
  for I := 0 to 9 do
    Rows[I] := TTableRow.Make([IntToStr(1000 + I), 'process_' + IntToStr(I), IntToStr(I * 3)]);

  TableSt := TTableState.Empty;

  StartTick := GetTickCount64;

  for Frame := 0 to FRAMES - 1 do
  begin
    Curr.Reset;

    Panel := TPanel.Create(
      [LengthConstraint(30), MinConstraint(0)],
      [LengthConstraint(1), MinConstraint(0), LengthConstraint(1)]
    ).WithBorderSet(BorderSetRounded)
     .WithHSepStartCol(1)
     .WithFocus(1, 1);

    G := Panel.Render(Area, Curr);

    ListSt := TListState.Empty;
    ListSt.Select(Frame mod 20);
    TList.Create(ListItems)
      .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]))
      .RenderStateful(PanelCellSpan(G, 0, 0, 1, 3), Curr, ListSt);

    TParagraph.FromString(' Fullscreen Bench')
      .WithStyle(TStyle.Default.WithFg(clYellow))
      .Render(PanelCell(G, 1, 0), Curr);

    TTable.Create(Cols)
      .WithRows(Rows)
      .WithHeaderStyle(TStyle.Default.WithModifier([mbBold]))
      .RenderStateful(
        TRect.Make(PanelCell(G, 1, 1).X, PanelCell(G, 1, 1).Y,
          PanelCell(G, 1, 1).Width, PanelCell(G, 1, 1).Height - 5),
        Curr, TableSt);

    TSparkline.Create(SparkData)
      .WithStyle(TStyle.Default.WithFg(clGreen))
      .Render(
        TRect.Make(PanelCell(G, 1, 1).X,
          PanelCell(G, 1, 1).Y + PanelCell(G, 1, 1).Height - 4,
          PanelCell(G, 1, 1).Width, 4),
        Curr);

    TParagraph.FromString(' Frame ' + IntToStr(Frame))
      .Render(PanelCell(G, 1, 2), Curr);

    Prev.Diff(Curr, Patches);
    Backend.DrawPatches(Patches);
    Backend.DiscardPending;

    Tmp := Prev;
    Prev := Curr;
    Curr := Tmp;
  end;

  EndTick := GetTickCount64;
  TotalMs := EndTick - StartTick;
  PerFrameUs := (TotalMs / FRAMES) * 1000;

  WriteLn('bench_fullscreen (', WIDTH, 'x', HEIGHT, ', ', FRAMES, ' frames)');
  WriteLn('  total: ', TotalMs:0:1, ' ms');
  WriteLn('  per frame: ', PerFrameUs:0:1, ' us');
  WriteLn('  target: < 2000 us/frame');
  if PerFrameUs < 2000 then
    WriteLn('  PASS')
  else
    WriteLn('  FAIL (too slow)');

  Prev.Free;
  Curr.Free;
  Backend.Free;
end.
