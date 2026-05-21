program gallery_demo;

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
  ftui_tabs,
  ftui_table,
  ftui_tree,
  ftui_barchart,
  ftui_input,
  ftui_calendar,
  ftui_kanban,
  ftui_paragraph;

type
  TGalleryApp = class(TApp)
  private
    FTabState: TTabsState;
    FTableState: TTableState;
    FTreeState: TTreeState;
    FInputState: TInputState;
    FCalState: TCalendarState;
    FKanbanState: TKanbanState;
    procedure RenderTabs(var Frame: TFrame);
    procedure RenderTablePage(const Area: TRect; Buf: TBuffer);
    procedure RenderTreePage(const Area: TRect; Buf: TBuffer);
    procedure RenderChartPage(const Area: TRect; Buf: TBuffer);
    procedure RenderInputPage(const Area: TRect; Buf: TBuffer);
    procedure RenderCalendarPage(const Area: TRect; Buf: TBuffer);
    procedure RenderKanbanPage(const Area: TRect; Buf: TBuffer);
  protected
    procedure OnInit; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure TGalleryApp.OnInit;
begin
  FTabState.Selected := 0;
  FTableState := TTableState.Empty;
  FTreeState := TTreeState.Empty;
  FInputState := TInputState.Empty;
  FCalState := TCalendarState.Make(2026, 5, 20);
  FKanbanState := TKanbanState.Empty;
end;

procedure TGalleryApp.Render(var Frame: TFrame);
var
  Rows: TRectArray;
begin
  Rows := VerticalSplit(Frame.Area, [LengthConstraint(1), FillConstraint(1)]);
  RenderTabs(Frame);
  case FTabState.Selected of
    0: RenderTablePage(Rows[1], Frame.Buffer);
    1: RenderTreePage(Rows[1], Frame.Buffer);
    2: RenderChartPage(Rows[1], Frame.Buffer);
    3: RenderInputPage(Rows[1], Frame.Buffer);
    4: RenderCalendarPage(Rows[1], Frame.Buffer);
    5: RenderKanbanPage(Rows[1], Frame.Buffer);
  end;
end;

procedure TGalleryApp.RenderTabs(var Frame: TFrame);
var
  TabArea: TRect;
  T: TTabs;
begin
  TabArea := TRect.Make(Frame.Area.X, Frame.Area.Y, Frame.Area.Width, 1);
  T := TTabs.Create(['Table', 'Tree', 'Chart', 'Input', 'Calendar', 'Kanban'])
    .WithActiveStyle(TStyle.Default.WithModifier([mbBold, mbReversed]))
    .WithInactiveStyle(TStyle.Default);
  T.RenderStateful(TabArea, Frame.Buffer, FTabState);
end;

procedure TGalleryApp.RenderTablePage(const Area: TRect; Buf: TBuffer);
var Tbl: TTable;
begin
  Tbl := TTable.Create([
    TTableColumn.Make('Name', FillConstraint(2)),
    TTableColumn.Make('Language', FillConstraint(1)),
    TTableColumn.Make('Stars', LengthConstraint(8))
  ])
  .WithRows([
    TTableRow.Make(['ratatui', 'Rust', '12.5k']),
    TTableRow.Make(['bubbletea', 'Go', '28.1k']),
    TTableRow.Make(['fafafa.tui', 'Pascal', '0.1k']),
    TTableRow.Make(['tview', 'Go', '10.2k']),
    TTableRow.Make(['cursive', 'Rust', '4.1k']),
    TTableRow.Make(['ncurses', 'C', '1.8k']),
    TTableRow.Make(['blessed', 'JS', '11.3k'])
  ])
  .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' TUI Frameworks '))
  .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]));
  Tbl.RenderStateful(Area, Buf, FTableState);
end;

procedure TGalleryApp.RenderTreePage(const Area: TRect; Buf: TBuffer);
var Tr: TTree;
begin
  Tr := TTree.Create([
    TTreeNode.Make('src').WithChildren([
      TTreeNode.Make('ftui_app.pas'),
      TTreeNode.Make('ftui_terminal.pas'),
      TTreeNode.Make('widgets').WithChildren([
        TTreeNode.Make('ftui_table.pas'),
        TTreeNode.Make('ftui_tree.pas'),
        TTreeNode.Make('ftui_kanban.pas')
      ])
    ]),
    TTreeNode.Make('tests').WithChildren([
      TTreeNode.Make('test_app.pas'),
      TTreeNode.Make('test_table.pas')
    ]),
    TTreeNode.Make('Makefile')
  ])
  .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Project '))
  .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]));
  Tr.RenderStateful(Area, Buf, FTreeState);
end;

procedure TGalleryApp.RenderChartPage(const Area: TRect; Buf: TBuffer);
var BC: TBarChart;
begin
  BC := TBarChart.Create([
    TBarData.Make('diff', 943),
    TBarData.Make('layout', 38),
    TBarData.Make('input', 4),
    TBarData.Make('render', 129),
    TBarData.Make('mouse', 14)
  ])
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Performance (us) '))
    .WithBarWidth(8)
    .WithBarGap(2);
  BC.Render(Area, Buf);
end;

procedure TGalleryApp.RenderInputPage(const Area: TRect; Buf: TBuffer);
var
  Inp: TInput;
  InpArea: TRect;
begin
  InpArea := TRect.Make(Area.X + 2, Area.Y + 2, Area.Width - 4, 3);
  Inp := TInput.Default
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Search '))
    .WithPlaceholder('Type something...');
  Inp.RenderStateful(InpArea, Buf, FInputState);
end;

procedure TGalleryApp.RenderCalendarPage(const Area: TRect; Buf: TBuffer);
var Cal: TCalendar;
begin
  Cal := TCalendar.Default
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Calendar '))
    .WithSelectedStyle(TStyle.Default.WithModifier([mbReversed]))
    .WithTodayStyle(TStyle.Default.WithFg(clCyan).WithModifier([mbBold]));
  Cal.RenderStateful(Area, Buf, FCalState);
end;

procedure TGalleryApp.RenderKanbanPage(const Area: TRect; Buf: TBuffer);
var KB: TKanban;
begin
  KB := TKanban.Create([
    MakeColumn('Todo', [
      TKanbanCard.Make('Design TApp API'),
      TKanbanCard.Make('Write tests')
    ]),
    MakeColumn('In Progress', [
      TKanbanCard.Make('Gallery demo').WithTag('WIP')
    ]),
    MakeColumn('Done', [
      TKanbanCard.Make('Focus manager'),
      TKanbanCard.Make('Table widget'),
      TKanbanCard.Make('Tree widget')
    ])
  ])
  .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Kanban '))
  .WithActiveCardStyle(TStyle.Default.WithModifier([mbReversed]));
  KB.RenderStateful(Area, Buf, FKanbanState);
end;

procedure TGalleryApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcTab:
    begin
      FTabState.Selected := (FTabState.Selected + 1) mod 6;
    end;
    kcBackTab:
    begin
      FTabState.Selected := (FTabState.Selected + 5) mod 6;
    end;
    kcUp:
      case FTabState.Selected of
        0: if FTableState.Selected > 0 then Dec(FTableState.Selected);
        1: if FTreeState.Selected > 0 then Dec(FTreeState.Selected);
        4: FCalState.PrevDay;
        5: FKanbanState.MoveUp;
      end;
    kcDown:
      case FTabState.Selected of
        0: Inc(FTableState.Selected);
        1: Inc(FTreeState.Selected);
        4: FCalState.NextDay;
        5: FKanbanState.MoveDown(3);
      end;
    kcLeft:
      case FTabState.Selected of
        5: FKanbanState.MoveLeft;
      end;
    kcRight:
      case FTabState.Selected of
        5: FKanbanState.MoveRight(3);
      end;
    kcEnter:
      case FTabState.Selected of
        1: FTreeState.Toggle(FTreeState.Selected);
      end;
    kcChar:
      case FTabState.Selected of
        3: FInputState.InsertChar(Chr(Ev.Key.Ch));
      end;
    kcBackspace:
      case FTabState.Selected of
        3: FInputState.DeleteBack;
      end;
  end;
end;

var App: TGalleryApp;
begin
  App := TGalleryApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
