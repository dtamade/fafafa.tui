unit test_breadcrumb;
{$mode objfpc}{$H+}
interface
procedure RegisterBreadcrumbTests;
implementation
uses ftui_testkit, ftui_rect, ftui_style, ftui_buffer, ftui_breadcrumb;

procedure Test_Create;
var B: TBreadcrumb;
begin
  B := TBreadcrumb.Create(['Home', 'Settings', 'Theme']);
  AssertEqInt(3, Length(B.Items), '3 items');
  AssertEqInt(2, B.ActiveIndex, 'last active');
end;

procedure Test_TotalWidth;
var B: TBreadcrumb;
begin
  B := TBreadcrumb.Create(['A', 'B', 'C']).WithSeparator(' > ');
  AssertEqInt(9, B.TotalWidth, '3 chars + 2*3 sep');
end;

procedure Test_Render;
var B: TBreadcrumb; Buf: TBuffer; Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 1);
  Buf := TBuffer.CreateEmpty(Area);
  B := TBreadcrumb.Create(['Home', 'Docs']).WithSeparator(' / ');
  B.Render(Area, Buf);
  AssertTrue(Pos('Home', Buf.RowAsString(0)) > 0, 'Home visible');
  AssertTrue(Pos('Docs', Buf.RowAsString(0)) > 0, 'Docs visible');
  AssertTrue(Pos('/', Buf.RowAsString(0)) > 0, 'separator visible');
  Buf.Free;
end;

procedure RegisterBreadcrumbTests;
begin
  RegisterTest('breadcrumb / create',      @Test_Create);
  RegisterTest('breadcrumb / total width', @Test_TotalWidth);
  RegisterTest('breadcrumb / render',      @Test_Render);
end;
end.
