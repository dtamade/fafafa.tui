unit test_virtual_list;

{$mode objfpc}{$H+}

interface

procedure RegisterVirtualListTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_buffer,
  ftui_virtual_list;

function TestProvider(Index: Integer): AnsiString;
begin
  Result := Format('Item %d', [Index]);
end;

procedure Test_CreateState;
var S: TVirtualListState;
begin
  S := TVirtualListState.Create(1000);
  AssertEqInt(1000, S.TotalItems, 'total');
  AssertEqInt(0, S.Selected, 'selected 0');
  AssertEqInt(0, S.Offset, 'offset 0');
end;

procedure Test_SelectNextPrev;
var S: TVirtualListState;
begin
  S := TVirtualListState.Create(10);
  S.SelectNext;
  AssertEqInt(1, S.Selected, 'next');
  S.SelectNext;
  AssertEqInt(2, S.Selected, 'next again');
  S.SelectPrev;
  AssertEqInt(1, S.Selected, 'prev');
  S.SelectFirst;
  AssertEqInt(0, S.Selected, 'first');
  S.SelectPrev;
  AssertEqInt(0, S.Selected, 'clamped at 0');
end;

procedure Test_SelectLast;
var S: TVirtualListState;
begin
  S := TVirtualListState.Create(100);
  S.SelectLast;
  AssertEqInt(99, S.Selected, 'last');
  S.SelectNext;
  AssertEqInt(99, S.Selected, 'clamped at last');
end;

procedure Test_PageDownUp;
var S: TVirtualListState;
begin
  S := TVirtualListState.Create(100);
  S.PageDown(10);
  AssertEqInt(10, S.Selected, 'page down');
  S.PageUp(10);
  AssertEqInt(0, S.Selected, 'page up');
  S.PageUp(10);
  AssertEqInt(0, S.Selected, 'clamped');
end;

procedure Test_RenderShowsItems;
var
  VL: TVirtualList;
  Buf: TBuffer;
  Area: TRect;
  State: TVirtualListState;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  VL := TVirtualList.Create(@TestProvider);
  State := TVirtualListState.Create(100);
  VL.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Item 0', Buf.RowAsString(0)) > 0, 'item 0 visible');
  AssertTrue(Pos('Item 4', Buf.RowAsString(4)) > 0, 'item 4 visible');
  Buf.Free;
end;

procedure Test_ScrollOnSelect;
var
  VL: TVirtualList;
  Buf: TBuffer;
  Area: TRect;
  State: TVirtualListState;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  VL := TVirtualList.Create(@TestProvider);
  State := TVirtualListState.Create(100);
  State.Selected := 50;
  VL.RenderStateful(Area, Buf, State);
  AssertTrue(State.Offset > 0, 'scrolled to show selected');
  AssertTrue(Pos('Item 50', Buf.RowAsString(State.Selected - State.Offset)) > 0, 'item 50 visible');
  Buf.Free;
end;

procedure Test_LargeDataset;
var
  VL: TVirtualList;
  Buf: TBuffer;
  Area: TRect;
  State: TVirtualListState;
begin
  Area := TRect.Make(0, 0, 30, 10);
  Buf := TBuffer.CreateEmpty(Area);
  VL := TVirtualList.Create(@TestProvider);
  State := TVirtualListState.Create(1000000);
  State.Selected := 999999;
  VL.RenderStateful(Area, Buf, State);
  AssertTrue(State.Offset > 0, 'scrolled for million items');
  AssertTrue(Pos('Item 999999', Buf.RowAsString(9)) > 0, 'last item visible');
  Buf.Free;
end;

procedure Test_ShowIndex;
var
  VL: TVirtualList;
  Buf: TBuffer;
  Area: TRect;
  State: TVirtualListState;
begin
  Area := TRect.Make(0, 0, 30, 3);
  Buf := TBuffer.CreateEmpty(Area);
  VL := TVirtualList.Create(@TestProvider).WithShowIndex(True);
  State := TVirtualListState.Create(50);
  VL.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('1', Buf.RowAsString(0)) > 0, 'index 1 shown');
  Buf.Free;
end;

procedure RegisterVirtualListTests;
begin
  RegisterTest('virtual_list / create state',     @Test_CreateState);
  RegisterTest('virtual_list / select next prev', @Test_SelectNextPrev);
  RegisterTest('virtual_list / select last',      @Test_SelectLast);
  RegisterTest('virtual_list / page down up',     @Test_PageDownUp);
  RegisterTest('virtual_list / render items',     @Test_RenderShowsItems);
  RegisterTest('virtual_list / scroll on select', @Test_ScrollOnSelect);
  RegisterTest('virtual_list / large dataset',    @Test_LargeDataset);
  RegisterTest('virtual_list / show index',       @Test_ShowIndex);
end;

end.
