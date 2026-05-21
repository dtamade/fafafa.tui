unit test_kanban;
{$mode objfpc}{$H+}
interface
procedure RegisterKanbanTests;
implementation
uses ftui_testkit, ftui_rect, ftui_style, ftui_buffer, ftui_kanban;

procedure Test_CreateColumn;
var Col: TKanbanColumn;
begin
  Col := MakeColumn('Todo', [TKanbanCard.Make('Task 1'), TKanbanCard.Make('Task 2')]);
  AssertEqStr('Todo', Col.Title, 'title');
  AssertEqInt(2, Length(Col.Cards), '2 cards');
end;

procedure Test_StateNavigation;
var S: TKanbanState;
begin
  S := TKanbanState.Empty;
  S.MoveRight(3);
  AssertEqInt(1, S.ActiveCol, 'moved right');
  S.MoveDown(5);
  AssertEqInt(1, S.ActiveCard, 'moved down');
  S.MoveUp;
  AssertEqInt(0, S.ActiveCard, 'moved up');
  S.MoveLeft;
  AssertEqInt(0, S.ActiveCol, 'moved left');
end;

procedure Test_RenderShowsColumns;
var KB: TKanban; Buf: TBuffer; Area: TRect; State: TKanbanState;
begin
  Area := TRect.Make(0, 0, 60, 10);
  Buf := TBuffer.CreateEmpty(Area);
  KB := TKanban.Create([
    MakeColumn('Todo', [TKanbanCard.Make('A')]),
    MakeColumn('Done', [TKanbanCard.Make('B')])
  ]);
  State := TKanbanState.Empty;
  KB.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Todo', Buf.RowAsString(0)) > 0, 'Todo header');
  AssertTrue(Pos('Done', Buf.RowAsString(0)) > 0, 'Done header');
  Buf.Free;
end;

procedure Test_CardWithTag;
var C: TKanbanCard;
begin
  C := TKanbanCard.Make('Fix bug').WithTag('P1');
  AssertEqStr('P1', C.Tag, 'tag set');
end;

procedure RegisterKanbanTests;
begin
  RegisterTest('kanban / create column',    @Test_CreateColumn);
  RegisterTest('kanban / state navigation', @Test_StateNavigation);
  RegisterTest('kanban / render columns',   @Test_RenderShowsColumns);
  RegisterTest('kanban / card with tag',    @Test_CardWithTag);
end;
end.
