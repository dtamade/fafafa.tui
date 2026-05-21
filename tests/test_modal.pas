unit test_modal;

{$mode objfpc}{$H+}

interface

uses
  ftui_testkit;

procedure RegisterTests;

implementation

uses
  ftui_modal,
  ftui_rect,
  ftui_buffer;

procedure Test_ContentAreaFixed;
var
  M: TModal;
  Container, Content: TRect;
begin
  Container := TRect.Make(0, 0, 80, 24);
  M := TModal.Create.WithSize(40, 10);
  Content := M.ContentArea(Container);
  AssertEqInt(40, Content.Width, 'width');
  AssertEqInt(10, Content.Height, 'height');
  AssertEqInt(20, Content.X, 'centered X');
  AssertEqInt(7, Content.Y, 'centered Y');
end;

procedure Test_ContentAreaPercent;
var
  M: TModal;
  Container, Content: TRect;
begin
  Container := TRect.Make(0, 0, 100, 50);
  M := TModal.Create.WithSizePercent(50, 40);
  Content := M.ContentArea(Container);
  AssertEqInt(50, Content.Width, 'width 50%');
  AssertEqInt(20, Content.Height, 'height 40%');
end;

procedure Test_ContentAreaClamp;
var
  M: TModal;
  Container, Content: TRect;
begin
  Container := TRect.Make(0, 0, 20, 10);
  M := TModal.Create.WithSize(100, 50);
  Content := M.ContentArea(Container);
  AssertEqInt(20, Content.Width, 'clamped width');
  AssertEqInt(10, Content.Height, 'clamped height');
end;

procedure Test_HiddenNoRender;
var
  M: TModal;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  Buf := TBuffer.CreateEmpty(Area);
  M := TModal.Create;
  M.Visible := False;
  M.RenderBackground(Area, Buf);
  Buf.Free;
end;

procedure RegisterTests;
begin
  RegisterTest('modal / content area fixed', @Test_ContentAreaFixed);
  RegisterTest('modal / content area percent', @Test_ContentAreaPercent);
  RegisterTest('modal / content area clamp', @Test_ContentAreaClamp);
  RegisterTest('modal / hidden no render', @Test_HiddenNoRender);
end;

end.
