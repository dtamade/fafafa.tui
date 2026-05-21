unit test_toast;

{$mode objfpc}{$H+}

interface

procedure RegisterToastTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_color,
  ftui_buffer,
  ftui_toast;

procedure Test_PushAndCount;
var TM: TToastManager;
begin
  TM := TToastManager.Create;
  AssertEqInt(0, TM.Count, 'empty initially');
  TM.Push('hello', tlInfo);
  AssertEqInt(1, TM.Count, 'one after push');
  TM.Push('world', tlError);
  AssertEqInt(2, TM.Count, 'two after second push');
  TM.Free;
end;

procedure Test_TickExpires;
var TM: TToastManager;
begin
  TM := TToastManager.Create;
  TM.DurationMs := 100;
  TM.Push('temp', tlInfo);
  AssertEqInt(1, TM.Count, 'one before tick');
  TM.Tick(50);
  AssertEqInt(1, TM.Count, 'still alive at 50ms');
  TM.Tick(60);
  AssertEqInt(0, TM.Count, 'expired after 110ms total');
  TM.Free;
end;

procedure Test_MaxVisible;
var TM: TToastManager; I: Integer;
begin
  TM := TToastManager.Create;
  TM.MaxVisible := 3;
  for I := 1 to 10 do
    TM.Push(Format('msg %d', [I]), tlInfo);
  AssertEqInt(10, TM.Count, 'all stored');
  AssertEqInt(3, TM.Visible, 'only 3 visible');
  TM.Free;
end;

procedure Test_RenderTopRight;
var
  TM: TToastManager;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 60, 10);
  Buf := TBuffer.CreateEmpty(Area);
  TM := TToastManager.Create;
  TM.Width := 20;
  TM.Position := tpTopRight;
  TM.Push('Alert!', tlError);
  TM.Render(Area, Buf);
  AssertTrue(Pos('Alert!', Buf.RowAsString(0)) > 30, 'toast near right edge');
  TM.Free;
  Buf.Free;
end;

procedure Test_RenderBottomCenter;
var
  TM: TToastManager;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 60, 10);
  Buf := TBuffer.CreateEmpty(Area);
  TM := TToastManager.Create;
  TM.Width := 20;
  TM.Position := tpBottomCenter;
  TM.Push('Done', tlSuccess);
  TM.Render(Area, Buf);
  AssertTrue(Pos('Done', Buf.RowAsString(9)) > 0, 'toast at bottom');
  TM.Free;
  Buf.Free;
end;

procedure Test_MultipleToasts;
var
  TM: TToastManager;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 60, 10);
  Buf := TBuffer.CreateEmpty(Area);
  TM := TToastManager.Create;
  TM.Width := 25;
  TM.Position := tpTopRight;
  TM.Push('First', tlInfo);
  TM.Push('Second', tlWarning);
  TM.Render(Area, Buf);
  AssertTrue(Pos('First', Buf.RowAsString(0)) > 0, 'first toast row 0');
  AssertTrue(Pos('Second', Buf.RowAsString(1)) > 0, 'second toast row 1');
  TM.Free;
  Buf.Free;
end;

procedure RegisterToastTests;
begin
  RegisterTest('toast / push and count',     @Test_PushAndCount);
  RegisterTest('toast / tick expires',       @Test_TickExpires);
  RegisterTest('toast / max visible',        @Test_MaxVisible);
  RegisterTest('toast / render top right',   @Test_RenderTopRight);
  RegisterTest('toast / render bottom center', @Test_RenderBottomCenter);
  RegisterTest('toast / multiple toasts',    @Test_MultipleToasts);
end;

end.
