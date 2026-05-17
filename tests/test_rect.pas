unit test_rect;

// Unit tests for ftui_rect. Registered with the global test runner via
// RegisterRectTests; the master tests/test_runner.lpr program calls
// RegisterRectTests and then RunAllTests.

{$mode objfpc}{$H+}

interface

procedure RegisterRectTests;

implementation

uses
  ftui_testkit,
  ftui_rect;

procedure Test_Make_AccessorsAndArea;
var
  R: TRect;
begin
  R := TRect.Make(2, 3, 10, 5);
  AssertEqInt(2, R.X, 'rect.X');
  AssertEqInt(3, R.Y, 'rect.Y');
  AssertEqInt(10, R.Width, 'rect.Width');
  AssertEqInt(5, R.Height, 'rect.Height');
  AssertEqInt(2, R.Left, 'rect.Left');
  AssertEqInt(12, R.Right, 'rect.Right (exclusive)');
  AssertEqInt(3, R.Top, 'rect.Top');
  AssertEqInt(8, R.Bottom, 'rect.Bottom (exclusive)');
  AssertEqInt(50, R.Area, 'rect.Area');
end;

procedure Test_AreaOverflowSafe;
var
  R: TRect;
begin
  // 65535 * 65535 = 4_294_836_225 — fits in LongWord (u32)
  R := TRect.Make(0, 0, 65535, 65535);
  AssertEqInt(LongWord(65535) * 65535, R.Area, 'huge rect area');
end;

procedure Test_IsEmpty;
begin
  AssertTrue (TRect.Make(0, 0, 0, 0).IsEmpty, 'empty 0x0');
  AssertTrue (TRect.Make(5, 5, 0, 10).IsEmpty, 'zero width');
  AssertTrue (TRect.Make(5, 5, 10, 0).IsEmpty, 'zero height');
  AssertFalse(TRect.Make(0, 0, 1, 1).IsEmpty, '1x1 not empty');
end;

procedure Test_Contains;
var
  R: TRect;
begin
  R := TRect.Make(2, 3, 10, 5);   // X: 2..11, Y: 3..7
  AssertTrue (R.Contains(PositionMake(2, 3)),  'top-left corner inclusive');
  AssertTrue (R.Contains(PositionMake(11, 7)), 'inside near bottom-right');
  AssertFalse(R.Contains(PositionMake(12, 7)), 'right edge exclusive');
  AssertFalse(R.Contains(PositionMake(11, 8)), 'bottom edge exclusive');
  AssertFalse(R.Contains(PositionMake(1, 3)),  'left of rect');
  AssertFalse(R.Contains(PositionMake(2, 2)),  'above rect');
end;

procedure Test_Intersects;
begin
  AssertTrue (TRect.Make(0, 0, 5, 5).Intersects(TRect.Make(3, 3, 5, 5)), 'overlap');
  AssertTrue (TRect.Make(0, 0, 5, 5).Intersects(TRect.Make(0, 0, 1, 1)), 'enclosed');
  AssertFalse(TRect.Make(0, 0, 5, 5).Intersects(TRect.Make(5, 0, 5, 5)), 'touching right edge');
  AssertFalse(TRect.Make(0, 0, 5, 5).Intersects(TRect.Make(0, 5, 5, 5)), 'touching bottom edge');
  AssertFalse(TRect.Make(0, 0, 5, 5).Intersects(TRect.Make(10, 10, 5, 5)), 'far apart');
end;

procedure Test_Intersection;
var
  R: TRect;
begin
  R := TRect.Make(0, 0, 10, 10).Intersection(TRect.Make(5, 5, 10, 10));
  AssertTrue(RectEquals(R, TRect.Make(5, 5, 5, 5)), 'overlap intersection');

  R := TRect.Make(0, 0, 5, 5).Intersection(TRect.Make(10, 10, 5, 5));
  AssertTrue(R.IsEmpty, 'disjoint -> empty');

  R := TRect.Make(2, 2, 6, 6).Intersection(TRect.Make(3, 3, 2, 2));
  AssertTrue(RectEquals(R, TRect.Make(3, 3, 2, 2)), 'enclosed -> inner');
end;

procedure Test_Union;
var
  R: TRect;
begin
  R := TRect.Make(0, 0, 5, 5).Union(TRect.Make(3, 3, 5, 5));
  AssertTrue(RectEquals(R, TRect.Make(0, 0, 8, 8)), 'overlap union');

  R := TRect.Make(0, 0, 5, 5).Union(TRect.Make(10, 10, 5, 5));
  AssertTrue(RectEquals(R, TRect.Make(0, 0, 15, 15)), 'disjoint bbox');

  R := TRect.Make(0, 0, 0, 0).Union(TRect.Make(2, 3, 4, 5));
  AssertTrue(RectEquals(R, TRect.Make(2, 3, 4, 5)), 'empty union right');

  R := TRect.Make(2, 3, 4, 5).Union(TRect.Make(0, 0, 0, 0));
  AssertTrue(RectEquals(R, TRect.Make(2, 3, 4, 5)), 'empty union left');
end;

procedure Test_Inner_Margin;
var
  R: TRect;
begin
  R := TRect.Make(0, 0, 10, 10).Inner(MarginMake(1, 1));
  AssertTrue(RectEquals(R, TRect.Make(1, 1, 8, 8)), 'inner margin 1');

  R := TRect.Make(0, 0, 10, 10).Inner(MarginMake(0, 2));
  AssertTrue(RectEquals(R, TRect.Make(0, 2, 10, 6)), 'vertical-only margin');

  R := TRect.Make(0, 0, 4, 4).Inner(MarginMake(2, 2));
  AssertTrue(R.IsEmpty, 'margin equal to half size collapses');

  R := TRect.Make(0, 0, 3, 3).Inner(MarginMake(5, 5));
  AssertTrue(R.IsEmpty, 'oversized margin -> empty');
end;

procedure Test_Equals;
begin
  AssertTrue (RectEquals(TRect.Make(1, 2, 3, 4), TRect.Make(1, 2, 3, 4)), 'eq same');
  AssertFalse(RectEquals(TRect.Make(1, 2, 3, 4), TRect.Make(1, 2, 3, 5)), 'eq diff height');
  AssertTrue (PositionEquals(PositionMake(1, 2), PositionMake(1, 2)), 'pos eq');
  AssertFalse(PositionEquals(PositionMake(1, 2), PositionMake(2, 1)), 'pos diff');
end;

procedure RegisterRectTests;
begin
  RegisterTest('rect / Make + accessors + area',  @Test_Make_AccessorsAndArea);
  RegisterTest('rect / Area is overflow-safe',    @Test_AreaOverflowSafe);
  RegisterTest('rect / IsEmpty',                  @Test_IsEmpty);
  RegisterTest('rect / Contains',                 @Test_Contains);
  RegisterTest('rect / Intersects',               @Test_Intersects);
  RegisterTest('rect / Intersection',             @Test_Intersection);
  RegisterTest('rect / Union',                    @Test_Union);
  RegisterTest('rect / Inner with TMargin',       @Test_Inner_Margin);
  RegisterTest('rect / Equals helpers',           @Test_Equals);
end;

end.
