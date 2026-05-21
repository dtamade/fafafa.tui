unit test_tooltip;

{$mode objfpc}{$H+}

interface

procedure RegisterTooltipTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_tooltip;

procedure Test_CreateTooltip;
var T: TTooltip;
begin
  T := TTooltip.Create('Hello');
  AssertEqStr('Hello', T.Text, 'text set');
  AssertTrue(T.Position = ttpAbove, 'default above');
end;

procedure Test_RenderAbove;
var
  T: TTooltip;
  Buf: TBuffer;
  Anchor, Bounds: TRect;
begin
  Bounds := TRect.Make(0, 0, 40, 20);
  Buf := TBuffer.CreateEmpty(Bounds);
  Anchor := TRect.Make(5, 10, 10, 1);
  T := TTooltip.Create('Tip!').WithPosition(ttpAbove);
  T.Render(Anchor, Bounds, Buf);
  AssertTrue(Pos('Tip!', Buf.RowAsString(8)) > 0, 'tooltip above anchor');
  Buf.Free;
end;

procedure Test_RenderBelow;
var
  T: TTooltip;
  Buf: TBuffer;
  Anchor, Bounds: TRect;
begin
  Bounds := TRect.Make(0, 0, 40, 20);
  Buf := TBuffer.CreateEmpty(Bounds);
  Anchor := TRect.Make(5, 5, 10, 1);
  T := TTooltip.Create('Below').WithPosition(ttpBelow);
  T.Render(Anchor, Bounds, Buf);
  AssertTrue(Pos('Below', Buf.RowAsString(7)) > 0, 'tooltip below anchor');
  Buf.Free;
end;

procedure Test_RenderRight;
var
  T: TTooltip;
  Buf: TBuffer;
  Anchor, Bounds: TRect;
begin
  Bounds := TRect.Make(0, 0, 50, 20);
  Buf := TBuffer.CreateEmpty(Bounds);
  Anchor := TRect.Make(5, 5, 3, 1);
  T := TTooltip.Create('Right').WithPosition(ttpRight);
  T.Render(Anchor, Bounds, Buf);
  AssertTrue(Pos('Right', Buf.RowAsString(6)) > 0, 'tooltip right of anchor');
  Buf.Free;
end;

procedure Test_ClampToBounds;
var
  T: TTooltip;
  Buf: TBuffer;
  Anchor, Bounds: TRect;
begin
  Bounds := TRect.Make(0, 0, 20, 10);
  Buf := TBuffer.CreateEmpty(Bounds);
  Anchor := TRect.Make(0, 0, 5, 1);
  T := TTooltip.Create('Clamped').WithPosition(ttpAbove);
  T.Render(Anchor, Bounds, Buf);
  // Should clamp Y to 0 since above would be negative
  AssertTrue(Pos('Clamped', Buf.RowAsString(1)) > 0, 'clamped to bounds');
  Buf.Free;
end;

procedure Test_EmptyTextNoop;
var
  T: TTooltip;
  Buf: TBuffer;
  Anchor, Bounds: TRect;
begin
  Bounds := TRect.Make(0, 0, 40, 20);
  Buf := TBuffer.CreateEmpty(Bounds);
  Anchor := TRect.Make(5, 5, 5, 1);
  T := TTooltip.Create('');
  T.Render(Anchor, Bounds, Buf);
  AssertTrue(True, 'no crash on empty');
  Buf.Free;
end;

procedure Test_MaxWidth;
var T: TTooltip;
begin
  T := TTooltip.Create('A very long tooltip text that exceeds max width').WithMaxWidth(20);
  AssertEqInt(20, T.MaxWidth, 'max width set');
end;

procedure RegisterTooltipTests;
begin
  RegisterTest('tooltip / create',         @Test_CreateTooltip);
  RegisterTest('tooltip / render above',   @Test_RenderAbove);
  RegisterTest('tooltip / render below',   @Test_RenderBelow);
  RegisterTest('tooltip / render right',   @Test_RenderRight);
  RegisterTest('tooltip / clamp bounds',   @Test_ClampToBounds);
  RegisterTest('tooltip / empty noop',     @Test_EmptyTextNoop);
  RegisterTest('tooltip / max width',      @Test_MaxWidth);
end;

end.
