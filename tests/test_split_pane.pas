unit test_split_pane;

{$mode objfpc}{$H+}

interface

procedure RegisterSplitPaneTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_event,
  ftui_split_pane;

procedure Test_HorizontalSplit50;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
  Ok: Boolean;
begin
  SP := TSplitPane.Horizontal;
  State := TSplitPaneState.Default;
  Ok := SP.Split(TRect.Make(0, 0, 41, 10), State, P1, P2, Div_);
  AssertTrue(Ok, 'split succeeds');
  AssertEqInt(20, P1.Width, 'pane1 width = 20');
  AssertEqInt(1, Div_.Width, 'divider width = 1');
  AssertEqInt(20, P2.Width, 'pane2 width = 20');
  AssertEqInt(10, P1.Height, 'pane1 full height');
end;

procedure Test_VerticalSplit50;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
  Ok: Boolean;
begin
  SP := TSplitPane.Vertical;
  State := TSplitPaneState.Default;
  Ok := SP.Split(TRect.Make(0, 0, 30, 21), State, P1, P2, Div_);
  AssertTrue(Ok, 'split succeeds');
  AssertEqInt(10, P1.Height, 'pane1 height = 10');
  AssertEqInt(1, Div_.Height, 'divider height = 1');
  AssertEqInt(10, P2.Height, 'pane2 height = 10');
  AssertEqInt(30, P1.Width, 'pane1 full width');
end;

procedure Test_MinSizeRespected;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
  Ok: Boolean;
begin
  SP := TSplitPane.Horizontal.WithMinSize1(10).WithMinSize2(10);
  State := TSplitPaneState.Default;
  State.Ratio := 0.1;
  Ok := SP.Split(TRect.Make(0, 0, 30, 5), State, P1, P2, Div_);
  AssertTrue(Ok, 'split succeeds');
  AssertTrue(P1.Width >= 10, 'pane1 >= min');
  AssertTrue(P2.Width >= 10, 'pane2 >= min');
end;

procedure Test_TooSmallFails;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
  Ok: Boolean;
begin
  SP := TSplitPane.Horizontal.WithMinSize1(10).WithMinSize2(10);
  State := TSplitPaneState.Default;
  Ok := SP.Split(TRect.Make(0, 0, 15, 5), State, P1, P2, Div_);
  AssertTrue(not Ok, 'too small: split fails');
end;

procedure Test_RatioClamp;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
begin
  SP := TSplitPane.Horizontal;
  State := TSplitPaneState.Default;
  State.Ratio := 2.0;
  SP.Split(TRect.Make(0, 0, 40, 5), State, P1, P2, Div_);
  AssertTrue(P2.Width >= SP.MinSize2, 'ratio > 1 clamped');
end;

procedure Test_MouseDrag;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  Area: TRect;
  M: TMouseEvent;
begin
  SP := TSplitPane.Horizontal;
  State := TSplitPaneState.Default;
  Area := TRect.Make(0, 0, 100, 10);

  M.Kind := mkDown;
  M.X := 50; M.Y := 5;
  SP.HandleMouse(Area, M, State);
  AssertTrue(State.Dragging, 'dragging started');

  M.Kind := mkDrag;
  M.X := 70; M.Y := 5;
  SP.HandleMouse(Area, M, State);
  AssertTrue(Abs(State.Ratio - 0.7) < 0.01, 'ratio updated to 0.7');

  M.Kind := mkUp;
  SP.HandleMouse(Area, M, State);
  AssertTrue(not State.Dragging, 'dragging stopped');
end;

procedure Test_RenderDivider;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 21, 3);
  Buf := TBuffer.CreateEmpty(Area);
  SP := TSplitPane.Horizontal;
  State := TSplitPaneState.Default;
  SP.Split(Area, State, P1, P2, Div_);
  SP.RenderDivider(Div_, Buf);
  AssertTrue(Div_.Width = 1, 'divider is 1 col');
  Buf.Free;
end;

procedure Test_NoDivider;
var
  SP: TSplitPane;
  State: TSplitPaneState;
  P1, P2, Div_: TRect;
begin
  SP := TSplitPane.Horizontal;
  SP.ShowDivider := False;
  State := TSplitPaneState.Default;
  SP.Split(TRect.Make(0, 0, 40, 5), State, P1, P2, Div_);
  AssertEqInt(20, P1.Width, 'no divider: pane1 = 20');
  AssertEqInt(20, P2.Width, 'no divider: pane2 = 20');
  AssertEqInt(0, Div_.Width, 'no divider: div width = 0');
end;

procedure RegisterSplitPaneTests;
begin
  RegisterTest('split_pane / horizontal 50%',    @Test_HorizontalSplit50);
  RegisterTest('split_pane / vertical 50%',      @Test_VerticalSplit50);
  RegisterTest('split_pane / min size respected', @Test_MinSizeRespected);
  RegisterTest('split_pane / too small fails',   @Test_TooSmallFails);
  RegisterTest('split_pane / ratio clamp',       @Test_RatioClamp);
  RegisterTest('split_pane / mouse drag',        @Test_MouseDrag);
  RegisterTest('split_pane / render divider',    @Test_RenderDivider);
  RegisterTest('split_pane / no divider',        @Test_NoDivider);
end;

end.
