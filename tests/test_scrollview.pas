unit test_scrollview;

{$mode objfpc}{$H+}

interface

procedure RegisterScrollViewTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_scrollview;

procedure Test_EmptyState;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  AssertEqInt(0, S.OffsetY, 'offset 0');
  AssertEqInt(0, S.ContentHeight, 'content 0');
end;

procedure Test_ScrollUpDown;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 100;
  S.ScrollDown(5);
  AssertEqInt(5, S.OffsetY, 'scrolled down 5');
  S.ScrollUp(3);
  AssertEqInt(2, S.OffsetY, 'scrolled up 3');
  S.ScrollUp(10);
  AssertEqInt(0, S.OffsetY, 'clamped at 0');
end;

procedure Test_PageUpDown;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 100;
  S.PageDown(10);
  AssertEqInt(10, S.OffsetY, 'page down');
  S.PageUp(10);
  AssertEqInt(0, S.OffsetY, 'page up');
end;

procedure Test_ScrollToTopBottom;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 50;
  S.OffsetY := 10;
  S.ScrollToTop;
  AssertEqInt(0, S.OffsetY, 'top');
  S.ScrollToBottom(20);
  AssertEqInt(30, S.OffsetY, 'bottom = 50-20');
end;

procedure Test_EnsureVisible;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 100;
  S.OffsetY := 0;
  S.EnsureVisible(25, 10);
  AssertEqInt(16, S.OffsetY, 'scrolled to show row 25');
  S.EnsureVisible(5, 10);
  AssertEqInt(5, S.OffsetY, 'scrolled up to show row 5');
end;

procedure Test_ContentArea;
var
  SV: TScrollView;
  Area, CA: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  SV := TScrollView.Default.WithShowScrollbar(True);
  CA := SV.ContentArea(Area);
  AssertEqInt(39, CA.Width, 'content width minus scrollbar');
  AssertEqInt(20, CA.Height, 'full height');
end;

procedure Test_ContentAreaNoScrollbar;
var
  SV: TScrollView;
  Area, CA: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  SV := TScrollView.Default.WithShowScrollbar(False);
  CA := SV.ContentArea(Area);
  AssertEqInt(40, CA.Width, 'full width without scrollbar');
end;

procedure Test_RenderScrollbar;
var
  SV: TScrollView;
  Buf: TBuffer;
  Area: TRect;
  State: TScrollViewState;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 20, 10);
  Buf := TBuffer.CreateEmpty(Area);
  SV := TScrollView.Default;
  State := TScrollViewState.Empty;
  State.ContentHeight := 30;
  State.OffsetY := 0;
  SV.RenderFrame(Area, Buf, State);
  Row := Buf.RowAsString(0);
  AssertTrue(Length(Row) > 0, 'scrollbar rendered');
  Buf.Free;
end;

procedure Test_ClampOffset;
var
  SV: TScrollView;
  Buf: TBuffer;
  Area: TRect;
  State: TScrollViewState;
begin
  Area := TRect.Make(0, 0, 20, 10);
  Buf := TBuffer.CreateEmpty(Area);
  SV := TScrollView.Default;
  State := TScrollViewState.Empty;
  State.ContentHeight := 15;
  State.OffsetY := 999;
  SV.RenderFrame(Area, Buf, State);
  AssertEqInt(5, State.OffsetY, 'clamped to max offset');
  Buf.Free;
end;

procedure RegisterScrollViewTests;
begin
  RegisterTest('scrollview / empty state',          @Test_EmptyState);
  RegisterTest('scrollview / scroll up down',       @Test_ScrollUpDown);
  RegisterTest('scrollview / page up down',         @Test_PageUpDown);
  RegisterTest('scrollview / scroll to top bottom', @Test_ScrollToTopBottom);
  RegisterTest('scrollview / ensure visible',       @Test_EnsureVisible);
  RegisterTest('scrollview / content area',         @Test_ContentArea);
  RegisterTest('scrollview / content area no sb',   @Test_ContentAreaNoScrollbar);
  RegisterTest('scrollview / render scrollbar',     @Test_RenderScrollbar);
  RegisterTest('scrollview / clamp offset',         @Test_ClampOffset);
end;

end.
