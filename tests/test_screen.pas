unit test_screen;

{$mode objfpc}{$H+}

interface

uses
  ftui_testkit;

procedure RegisterTests;

implementation

uses
  ftui_screen,
  ftui_event,
  ftui_rect,
  ftui_buffer;

type
  TCountScreen = class(TScreen)
  public
    RenderCount: Integer;
    EventCount: Integer;
    EnterCount: Integer;
    LeaveCount: Integer;
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure OnEnter; override;
    procedure OnLeave; override;
  end;

procedure TCountScreen.Render(const Area: TRect; Buf: TBuffer);
begin
  Inc(RenderCount);
end;

procedure TCountScreen.HandleEvent(const Ev: TEvent);
begin
  Inc(EventCount);
end;

procedure TCountScreen.OnEnter;
begin
  Inc(EnterCount);
end;

procedure TCountScreen.OnLeave;
begin
  Inc(LeaveCount);
end;

procedure Test_PushAndTop;
var
  Stack: TScreenStack;
  S: TCountScreen;
begin
  Stack := TScreenStack.Create;
  try
    S := TCountScreen.Create;
    Stack.Push(S);
    AssertTrue(Stack.Top = S, 'top is pushed screen');
    AssertEqInt(1, Stack.Count, 'count is 1');
    AssertEqInt(1, S.EnterCount, 'OnEnter called');
  finally
    Stack.Free;
  end;
end;

procedure Test_Pop;
var
  Stack: TScreenStack;
  S1, S2, Popped: TCountScreen;
begin
  Stack := TScreenStack.Create;
  try
    S1 := TCountScreen.Create;
    S2 := TCountScreen.Create;
    Stack.Push(S1);
    Stack.Push(S2);
    AssertEqInt(1, S1.LeaveCount, 'S1 OnLeave on push S2');
    Popped := TCountScreen(Stack.Pop);
    AssertTrue(Popped = S2, 'popped is S2');
    AssertEqInt(1, S2.LeaveCount, 'S2 OnLeave on pop');
    AssertEqInt(2, S1.EnterCount, 'S1 OnEnter again');
    AssertTrue(Stack.Top = S1, 'top is S1');
    Popped.Free;
  finally
    Stack.Free;
  end;
end;

procedure Test_Replace;
var
  Stack: TScreenStack;
  S1, S2: TCountScreen;
begin
  Stack := TScreenStack.Create;
  try
    S1 := TCountScreen.Create;
    S2 := TCountScreen.Create;
    Stack.Push(S1);
    Stack.Replace(S2);
    AssertTrue(Stack.Top = S2, 'top is S2 after replace');
    AssertEqInt(1, Stack.Count, 'count still 1');
    AssertEqInt(1, S2.EnterCount, 'S2 OnEnter');
  finally
    Stack.Free;
  end;
end;

procedure Test_RenderDelegatesToTop;
var
  Stack: TScreenStack;
  S1, S2: TCountScreen;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 10, 5);
  Buf := TBuffer.CreateEmpty(Area);
  Stack := TScreenStack.Create;
  try
    S1 := TCountScreen.Create;
    S2 := TCountScreen.Create;
    Stack.Push(S1);
    Stack.Push(S2);
    Stack.Render(Area, Buf);
    AssertEqInt(0, S1.RenderCount, 'S1 not rendered');
    AssertEqInt(1, S2.RenderCount, 'S2 rendered');
  finally
    Stack.Free;
    Buf.Free;
  end;
end;

procedure Test_HandleEventDelegatesToTop;
var
  Stack: TScreenStack;
  S1, S2: TCountScreen;
begin
  Stack := TScreenStack.Create;
  try
    S1 := TCountScreen.Create;
    S2 := TCountScreen.Create;
    Stack.Push(S1);
    Stack.Push(S2);
    Stack.HandleEvent(KeyCharEvent(Ord('a'), []));
    AssertEqInt(0, S1.EventCount, 'S1 no event');
    AssertEqInt(1, S2.EventCount, 'S2 got event');
  finally
    Stack.Free;
  end;
end;

procedure Test_EmptyStack;
var Stack: TScreenStack;
begin
  Stack := TScreenStack.Create;
  try
    AssertTrue(Stack.IsEmpty, 'empty');
    AssertTrue(Stack.Top = nil, 'top nil');
    AssertEqInt(0, Stack.Count, 'count 0');
  finally
    Stack.Free;
  end;
end;

procedure RegisterTests;
begin
  RegisterTest('screen / push and top', @Test_PushAndTop);
  RegisterTest('screen / pop', @Test_Pop);
  RegisterTest('screen / replace', @Test_Replace);
  RegisterTest('screen / render delegates to top', @Test_RenderDelegatesToTop);
  RegisterTest('screen / handle event delegates to top', @Test_HandleEventDelegatesToTop);
  RegisterTest('screen / empty stack', @Test_EmptyStack);
end;

end.
