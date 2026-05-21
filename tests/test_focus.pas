unit test_focus;

{$mode objfpc}{$H+}

interface

procedure RegisterFocusTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_event,
  ftui_focus;

procedure Test_EmptyManager;
var FM: TFocusManager;
begin
  FM := TFocusManager.Create;
  try
    AssertEqInt(0, FM.Count_, 'empty');
    AssertTrue(FM.FocusedId = FOCUS_NONE, 'no focus');
  finally FM.Free; end;
end;

procedure Test_RegisterAutoFocusFirst;
var FM: TFocusManager; Id: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    Id := FM.Register(TRect.Make(0, 0, 10, 3));
    AssertTrue(FM.IsFocused(Id), 'first registered gets focus');
    AssertEqInt(1, FM.Count_, 'count 1');
  finally FM.Free; end;
end;

procedure Test_TabCycles;
var FM: TFocusManager; A, B, C: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    A := FM.Register(TRect.Make(0, 0, 10, 1));
    B := FM.Register(TRect.Make(0, 2, 10, 1));
    C := FM.Register(TRect.Make(0, 4, 10, 1));
    AssertTrue(FM.IsFocused(A), 'starts at A');
    FM.Navigate(fnNext);
    AssertTrue(FM.IsFocused(B), 'tab to B');
    FM.Navigate(fnNext);
    AssertTrue(FM.IsFocused(C), 'tab to C');
    FM.Navigate(fnNext);
    AssertTrue(FM.IsFocused(A), 'wraps to A');
  finally FM.Free; end;
end;

procedure Test_ShiftTabReverse;
var FM: TFocusManager; A, B, C: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    A := FM.Register(TRect.Make(0, 0, 10, 1));
    B := FM.Register(TRect.Make(0, 2, 10, 1));
    C := FM.Register(TRect.Make(0, 4, 10, 1));
    FM.Navigate(fnPrev);
    AssertTrue(FM.IsFocused(C), 'shift+tab wraps to C');
    FM.Navigate(fnPrev);
    AssertTrue(FM.IsFocused(B), 'shift+tab to B');
  finally FM.Free; end;
end;

procedure Test_SpatialNavDown;
var FM: TFocusManager; Top, Bot: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    Top := FM.Register(TRect.Make(0, 0, 10, 2));
    Bot := FM.Register(TRect.Make(0, 5, 10, 2));
    AssertTrue(FM.IsFocused(Top), 'starts at top');
    FM.Navigate(fnDown);
    AssertTrue(FM.IsFocused(Bot), 'down goes to bot');
    FM.Navigate(fnUp);
    AssertTrue(FM.IsFocused(Top), 'up goes back to top');
  finally FM.Free; end;
end;

procedure Test_SpatialNavLeftRight;
var FM: TFocusManager; L, R: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    L := FM.Register(TRect.Make(0, 0, 5, 3));
    R := FM.Register(TRect.Make(10, 0, 5, 3));
    AssertTrue(FM.IsFocused(L), 'starts at left');
    FM.Navigate(fnRight);
    AssertTrue(FM.IsFocused(R), 'right goes to R');
    FM.Navigate(fnLeft);
    AssertTrue(FM.IsFocused(L), 'left goes back to L');
  finally FM.Free; end;
end;
procedure Test_FocusOn;
var FM: TFocusManager; A, B: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    A := FM.Register(TRect.Make(0, 0, 10, 1));
    B := FM.Register(TRect.Make(0, 2, 10, 1));
    FM.FocusOn(B);
    AssertTrue(FM.IsFocused(B), 'focused on B');
    AssertTrue(not FM.IsFocused(A), 'A not focused');
  finally FM.Free; end;
end;

procedure Test_HandleKeyTab;
var FM: TFocusManager; A, B: TFocusId;
    Consumed: Boolean;
begin
  FM := TFocusManager.Create;
  try
    A := FM.Register(TRect.Make(0, 0, 10, 1));
    B := FM.Register(TRect.Make(0, 2, 10, 1));
    Consumed := FM.HandleKey(KeyCodeEvent(kcTab, []).Key);
    AssertTrue(Consumed, 'tab consumed');
    AssertTrue(FM.IsFocused(B), 'tab moved to B');
    Consumed := FM.HandleKey(KeyCodeEvent(kcTab, [kmShift]).Key);
    AssertTrue(Consumed, 'shift+tab consumed');
    AssertTrue(FM.IsFocused(A), 'shift+tab back to A');
  finally FM.Free; end;
end;

procedure Test_BeginFrameClears;
var FM: TFocusManager; A: TFocusId;
begin
  FM := TFocusManager.Create;
  try
    A := FM.Register(TRect.Make(0, 0, 10, 1));
    AssertEqInt(1, FM.Count_, 'has 1');
    FM.BeginFrame;
    AssertEqInt(0, FM.Count_, 'cleared after BeginFrame');
    AssertTrue(FM.FocusedId = A, 'focus preserved across frames');
  finally FM.Free; end;
end;

procedure RegisterFocusTests;
begin
  RegisterTest('focus / empty manager',          @Test_EmptyManager);
  RegisterTest('focus / register auto-focus',    @Test_RegisterAutoFocusFirst);
  RegisterTest('focus / tab cycles',             @Test_TabCycles);
  RegisterTest('focus / shift+tab reverse',      @Test_ShiftTabReverse);
  RegisterTest('focus / spatial nav down/up',    @Test_SpatialNavDown);
  RegisterTest('focus / spatial nav left/right', @Test_SpatialNavLeftRight);
  RegisterTest('focus / focus on',               @Test_FocusOn);
  RegisterTest('focus / handle key tab',         @Test_HandleKeyTab);
  RegisterTest('focus / begin frame clears',     @Test_BeginFrameClears);
end;

end.
