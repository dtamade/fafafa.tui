unit test_select;

{$mode objfpc}{$H+}

interface

uses
  ftui_testkit;

procedure RegisterTests;

implementation

uses
  ftui_select,
  ftui_rect,
  ftui_buffer;

procedure Test_EmptyState;
var State: TSelectState;
begin
  State := TSelectState.Empty;
  AssertEqInt(-1, State.Selected, 'no selection');
  AssertFalse(State.Open, 'closed');
end;

procedure Test_ToggleOpen;
var State: TSelectState;
begin
  State := TSelectState.Empty;
  State.Toggle;
  AssertTrue(State.Open, 'opened');
  State.Toggle;
  AssertFalse(State.Open, 'closed again');
end;

procedure Test_MoveAndConfirm;
var State: TSelectState;
begin
  State := TSelectState.Empty;
  State.Toggle;
  State.MoveDown(3);
  State.MoveDown(3);
  AssertEqInt(2, State.HighlightIdx, 'moved to 2');
  State.MoveDown(3);
  AssertEqInt(2, State.HighlightIdx, 'clamped at max');
  State.Confirm;
  AssertEqInt(2, State.Selected, 'confirmed');
  AssertFalse(State.Open, 'closed after confirm');
end;

procedure Test_RenderClosed;
var
  Sel: TSelect;
  State: TSelectState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 10);
  Buf := TBuffer.CreateEmpty(Area);
  Sel := TSelect.Create(['Red', 'Green', 'Blue']);
  State := TSelectState.Empty;
  Sel.RenderStateful(Area, Buf, State);
  Buf.Free;
end;

procedure Test_RenderOpen;
var
  Sel: TSelect;
  State: TSelectState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 10);
  Buf := TBuffer.CreateEmpty(Area);
  Sel := TSelect.Create(['Red', 'Green', 'Blue']);
  State := TSelectState.Empty;
  State.Toggle;
  Sel.RenderStateful(Area, Buf, State);
  Buf.Free;
end;

procedure RegisterTests;
begin
  RegisterTest('select / empty state', @Test_EmptyState);
  RegisterTest('select / toggle open', @Test_ToggleOpen);
  RegisterTest('select / move and confirm', @Test_MoveAndConfirm);
  RegisterTest('select / render closed', @Test_RenderClosed);
  RegisterTest('select / render open', @Test_RenderOpen);
end;

end.
