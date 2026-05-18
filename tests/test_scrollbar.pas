unit test_scrollbar;

{$mode objfpc}{$H+}

interface

procedure RegisterScrollbarTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_scrollbar;

procedure Test_ThumbSizeProportional;
var S: TScrollbar;
begin
  S.TotalItems := 100;
  S.VisibleItems := 20;
  S.ScrollOffset := 0;
  // Track height 10: thumb = 20/100 * 10 = 2.
  AssertEqInt(2, S.ThumbSize(10), 'thumb size 20/100 of 10');
  // Track height 50: thumb = 20/100 * 50 = 10.
  AssertEqInt(10, S.ThumbSize(50), 'thumb size 20/100 of 50');
end;

procedure Test_ThumbSizeMinimum1;
var S: TScrollbar;
begin
  S.TotalItems := 1000;
  S.VisibleItems := 1;
  S.ScrollOffset := 0;
  // 1/1000 * 10 = 0 → clamped to 1.
  AssertEqInt(1, S.ThumbSize(10), 'minimum thumb size = 1');
end;

procedure Test_ThumbStartAtZero;
var S: TScrollbar;
begin
  S.TotalItems := 100;
  S.VisibleItems := 20;
  S.ScrollOffset := 0;
  AssertEqInt(0, S.ThumbStart(10), 'start at 0 when offset=0');
end;

procedure Test_ThumbStartAtEnd;
var S: TScrollbar;
begin
  S.TotalItems := 100;
  S.VisibleItems := 20;
  S.ScrollOffset := 80;   // max offset = 100-20 = 80
  // ThumbSize(10) = 2, available track = 10-2 = 8.
  // Start = 80 * 8 / 80 = 8.
  AssertEqInt(8, S.ThumbStart(10), 'start at end when offset=max');
end;

procedure Test_HitAtRegions;
var S: TScrollbar; Area: TRect;
begin
  S.TotalItems := 100;
  S.VisibleItems := 20;
  S.ScrollOffset := 40;   // mid-scroll
  Area := TRect.Make(0, 0, 1, 20);
  // ThumbSize(20) = 4, ThumbStart(20) = 40 * (20-4) / 80 = 8.
  AssertEqInt(Ord(shAbove), Ord(S.HitAt(Area, 5)), 'above thumb');
  AssertEqInt(Ord(shThumb), Ord(S.HitAt(Area, 9)), 'on thumb');
  AssertEqInt(Ord(shBelow), Ord(S.HitAt(Area, 15)), 'below thumb');
  AssertEqInt(Ord(shNone), Ord(S.HitAt(Area, 25)), 'outside track');
end;

procedure Test_OffsetFromDragY;
var S: TScrollbar; Area: TRect;
begin
  S.TotalItems := 100;
  S.VisibleItems := 20;
  S.ScrollOffset := 0;
  Area := TRect.Make(0, 0, 1, 20);
  // Drag to Y=0 → offset=0.
  AssertEqInt(0, S.OffsetFromDragY(Area, 0), 'drag top = 0');
  // Drag to Y=16 (available track = 20-4 = 16) → offset=80.
  AssertEqInt(80, S.OffsetFromDragY(Area, 16), 'drag bottom = max');
  // Drag to Y=8 → offset=40.
  AssertEqInt(40, S.OffsetFromDragY(Area, 8), 'drag mid = 40');
end;

procedure Test_PageUpDown;
var S: TScrollbar;
begin
  S.TotalItems := 50;
  S.VisibleItems := 10;
  S.ScrollOffset := 20;
  AssertEqInt(10, S.PageUp, 'page up from 20');
  AssertEqInt(30, S.PageDown, 'page down from 20');
  S.ScrollOffset := 5;
  AssertEqInt(0, S.PageUp, 'page up clamped to 0');
  S.ScrollOffset := 38;
  AssertEqInt(40, S.PageDown, 'page down clamped to max');
end;

procedure Test_Clamped;
var S: TScrollbar;
begin
  S.TotalItems := 50;
  S.VisibleItems := 10;
  S.ScrollOffset := -5;
  AssertEqInt(0, S.Clamped, 'clamp negative');
  S.ScrollOffset := 999;
  AssertEqInt(40, S.Clamped, 'clamp over max');
  S.ScrollOffset := 25;
  AssertEqInt(25, S.Clamped, 'valid stays');
end;

procedure RegisterScrollbarTests;
begin
  RegisterTest('scrollbar / thumb size proportional',  @Test_ThumbSizeProportional);
  RegisterTest('scrollbar / thumb size minimum 1',     @Test_ThumbSizeMinimum1);
  RegisterTest('scrollbar / thumb start at zero',      @Test_ThumbStartAtZero);
  RegisterTest('scrollbar / thumb start at end',       @Test_ThumbStartAtEnd);
  RegisterTest('scrollbar / hit-at regions',           @Test_HitAtRegions);
  RegisterTest('scrollbar / offset from drag Y',      @Test_OffsetFromDragY);
  RegisterTest('scrollbar / page up/down',             @Test_PageUpDown);
  RegisterTest('scrollbar / clamped',                  @Test_Clamped);
end;

end.
