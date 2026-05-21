unit test_layout;

{$mode objfpc}{$H+}

interface

procedure RegisterLayoutTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_layout;

// Helper that asserts a horizontal split produces these exact widths
// (heights all equal Area.Height, X positions stitch left-to-right).
procedure AssertHorizontalWidths(const Area: TRect;
  const Cs: array of TConstraint; const Widths: array of Integer;
  const Ctx: AnsiString);
var
  Got: TRectArray;
  I, Cursor: Integer;
begin
  Got := HorizontalSplit(Area, Cs);
  if Length(Got) <> Length(Widths) then
    AssertEqInt(Length(Widths), Length(Got), Ctx + ': slot count');
  Cursor := Area.X;
  for I := 0 to High(Widths) do
  begin
    AssertEqInt(Widths[I], Got[I].Width,
      Format('%s: slot %d width', [Ctx, I]));
    AssertEqInt(Cursor, Got[I].X,
      Format('%s: slot %d X', [Ctx, I]));
    AssertEqInt(Area.Y, Got[I].Y,
      Format('%s: slot %d Y = Area.Y', [Ctx, I]));
    AssertEqInt(Area.Height, Got[I].Height,
      Format('%s: slot %d height = Area.Height', [Ctx, I]));
    Inc(Cursor, Widths[I]);
  end;
end;

procedure AssertVerticalHeights(const Area: TRect;
  const Cs: array of TConstraint; const Heights: array of Integer;
  const Ctx: AnsiString);
var
  Got: TRectArray;
  I, Cursor: Integer;
begin
  Got := VerticalSplit(Area, Cs);
  if Length(Got) <> Length(Heights) then
    AssertEqInt(Length(Heights), Length(Got), Ctx + ': slot count');
  Cursor := Area.Y;
  for I := 0 to High(Heights) do
  begin
    AssertEqInt(Heights[I], Got[I].Height,
      Format('%s: slot %d height', [Ctx, I]));
    AssertEqInt(Cursor, Got[I].Y,
      Format('%s: slot %d Y', [Ctx, I]));
    AssertEqInt(Area.X, Got[I].X,
      Format('%s: slot %d X = Area.X', [Ctx, I]));
    AssertEqInt(Area.Width, Got[I].Width,
      Format('%s: slot %d width = Area.Width', [Ctx, I]));
    Inc(Cursor, Heights[I]);
  end;
end;

procedure Test_PureLengths;
begin
  AssertHorizontalWidths(TRect.Make(0, 0, 30, 5),
    [LengthConstraint(10), LengthConstraint(20)],
    [10, 20], 'two lengths exact fit');

  // Lengths totaling less than area: trailing length absorbs leftover.
  AssertHorizontalWidths(TRect.Make(0, 0, 30, 5),
    [LengthConstraint(5), LengthConstraint(5)],
    [5, 25], 'two lengths under-budget — last absorbs');

  // Lengths totaling more than area: each takes what it can; leftover negative.
  AssertHorizontalWidths(TRect.Make(0, 0, 10, 1),
    [LengthConstraint(5), LengthConstraint(8)],
    [5, 5], 'over-budget: first 5 then second clamped to remaining');
end;

procedure Test_PercentageOfTotal;
begin
  // 50% of 100 = 50; remaining 50 absorbed by trailing percentage.
  AssertHorizontalWidths(TRect.Make(0, 0, 100, 1),
    [PercentageConstraint(50), PercentageConstraint(50)],
    [50, 50], 'two halves');

  // 30% + 30% on 100 -> 30 + 70 (trailing absorbs).
  AssertHorizontalWidths(TRect.Make(0, 0, 100, 1),
    [PercentageConstraint(30), PercentageConstraint(30)],
    [30, 70], 'percentages under-budget');

  // 25% of 50 = 12 (floor), trailing absorbs.
  AssertHorizontalWidths(TRect.Make(0, 0, 50, 1),
    [PercentageConstraint(25), PercentageConstraint(25)],
    [12, 38], 'percentage floor + trailing absorb');
end;

procedure Test_LengthBeforePercentage;
begin
  // Length wins first: Length(10) takes 10, then 50% of original 30 = 15
  // (NOT 50% of remaining 20).  Trailing slot absorbs leftover 5.
  AssertHorizontalWidths(TRect.Make(0, 0, 30, 1),
    [LengthConstraint(10), PercentageConstraint(50)],
    [10, 20], 'length 10 then trailing percentage absorbs');

  // 25% of 100 = 25, length takes 50 — leftover 25 absorbed by the
  // last slot (Length here), making it [25, 75].
  AssertHorizontalWidths(TRect.Make(0, 0, 100, 1),
    [PercentageConstraint(25), LengthConstraint(50)],
    [25, 75], 'percentage 25 then length 50 — trailing length absorbs leftover 25');
end;

procedure Test_MinFillsRemainder;
begin
  // Length(3) + Min(0) on 20 -> 3, 17.
  AssertHorizontalWidths(TRect.Make(0, 0, 20, 1),
    [LengthConstraint(3), MinConstraint(0)],
    [3, 17], 'header + body fills');

  // Length(3) + Min(0) + Length(1) — typical chat layout
  // (statusbar / messages / inputbar pattern).
  AssertVerticalHeights(TRect.Make(0, 0, 1, 30),
    [LengthConstraint(3), MinConstraint(0), LengthConstraint(1)],
    [3, 26, 1], 'top header + center min + bottom statusbar');
end;

procedure Test_MultipleMinsSplitEvenly;
begin
  // Length(2) + Min(0) + Min(0) on 20 -> 2, 9, 9.
  AssertHorizontalWidths(TRect.Make(0, 0, 20, 1),
    [LengthConstraint(2), MinConstraint(0), MinConstraint(0)],
    [2, 9, 9], 'two mins split remaining evenly');

  // Three mins on 10 — fair share is 3, the trailing slot mops up
  // the remainder (consistent with the "trailing wins" rule).
  AssertHorizontalWidths(TRect.Make(0, 0, 10, 1),
    [MinConstraint(0), MinConstraint(0), MinConstraint(0)],
    [3, 3, 4], 'three mins: per=3, last absorbs leftover');
end;

procedure Test_MinHonoursFloor;
begin
  // Min(20) gets 20 even when the equal share would be smaller.
  AssertHorizontalWidths(TRect.Make(0, 0, 30, 1),
    [LengthConstraint(5), MinConstraint(20), MinConstraint(0)],
    [5, 20, 5], 'Min(20) floors at 20');
end;

procedure Test_PercentageLengthMinMix;
begin
  // 50, Length(5) Percentage(20)=10 (of original 50) Min(0)
  // After length 5 + percentage 10 -> remaining 35 -> Min gets 35.
  AssertHorizontalWidths(TRect.Make(0, 0, 50, 1),
    [LengthConstraint(5), PercentageConstraint(20), MinConstraint(0)],
    [5, 10, 35], 'length+pct+min mix');

  // Same but trailing slot is percentage — Min gets remaining, then
  // trailing percentage absorbs the residual… wait, residual is 0
  // here.  Verify trailing-Percentage path.
  AssertHorizontalWidths(TRect.Make(0, 0, 50, 1),
    [LengthConstraint(5), MinConstraint(10), PercentageConstraint(40)],
    [5, 25, 20], 'length+min+pct: pct of 50 = 20, length 5, min gets remaining 25');
end;

procedure Test_EmptyAreaProducesZeroSlots;
begin
  AssertHorizontalWidths(TRect.Make(0, 0, 0, 5),
    [LengthConstraint(10), MinConstraint(0)],
    [0, 0], 'zero-width area');

  AssertVerticalHeights(TRect.Make(0, 0, 5, 0),
    [LengthConstraint(2), MinConstraint(0)],
    [0, 0], 'zero-height area');
end;

procedure Test_NoConstraintsReturnsEmpty;
var
  Got: TRectArray;
begin
  Got := HorizontalSplit(TRect.Make(0, 0, 10, 1), []);
  AssertEqInt(0, Length(Got), 'empty constraint list');
end;

procedure Test_OffsetAreaPreservesOrigin;
var
  Got: TRectArray;
begin
  Got := HorizontalSplit(TRect.Make(7, 3, 20, 4),
    [LengthConstraint(5), MinConstraint(0)]);
  AssertEqInt(2, Length(Got), '2 slots');
  AssertEqInt(7,  Got[0].X, 'slot 0 X = Area.X');
  AssertEqInt(3,  Got[0].Y, 'slot 0 Y = Area.Y');
  AssertEqInt(12, Got[1].X, 'slot 1 X = 7 + 5');
  AssertEqInt(3,  Got[1].Y, 'slot 1 Y = Area.Y');
  AssertEqInt(15, Got[1].Width, 'slot 1 width = 20 - 5');
  AssertEqInt(4,  Got[1].Height, 'height = Area.Height');
end;

procedure Test_TLayoutBuilderEquivalentToHelpers;
var
  ViaLayout, ViaHelper: TRectArray;
  L: TLayout;
  Area: TRect;
  I: Integer;
begin
  Area := TRect.Make(0, 0, 80, 10);
  L := TLayout.Default
        .WithDirection(dirHorizontal)
        .WithConstraints([LengthConstraint(20), MinConstraint(0), LengthConstraint(20)]);
  ViaLayout := L.Split(Area);
  ViaHelper := HorizontalSplit(Area,
    [LengthConstraint(20), MinConstraint(0), LengthConstraint(20)]);
  AssertEqInt(Length(ViaHelper), Length(ViaLayout), 'same slot count');
  for I := 0 to High(ViaLayout) do
  begin
    AssertEqInt(ViaHelper[I].X, ViaLayout[I].X, Format('slot %d X', [I]));
    AssertEqInt(ViaHelper[I].Width, ViaLayout[I].Width, Format('slot %d W', [I]));
  end;
end;

procedure Test_MaxConstraint;
var R: TRectArray;
begin
  R := HorizontalSplit(TRect.Make(0, 0, 100, 1), [MaxConstraint(30), MaxConstraint(30)]);
  AssertEqInt(30, R[0].Width, 'first max capped at 30');
  AssertEqInt(30, R[1].Width, 'second max capped at 30');
end;

procedure Test_FillWeighted;
var R: TRectArray;
begin
  R := HorizontalSplit(TRect.Make(0, 0, 90, 1), [FillConstraint(1), FillConstraint(2)]);
  AssertEqInt(30, R[0].Width, 'weight 1 gets 30');
  AssertEqInt(60, R[1].Width, 'weight 2 gets 60');
end;

procedure Test_FillWithLength;
var R: TRectArray;
begin
  R := HorizontalSplit(TRect.Make(0, 0, 100, 1), [LengthConstraint(20), FillConstraint(1)]);
  AssertEqInt(20, R[0].Width, 'length takes 20');
  AssertEqInt(80, R[1].Width, 'fill takes remainder');
end;

procedure RegisterLayoutTests;
begin
  RegisterTest('layout / pure lengths',                @Test_PureLengths);
  RegisterTest('layout / percentage of original total',@Test_PercentageOfTotal);
  RegisterTest('layout / length passes before percentage', @Test_LengthBeforePercentage);
  RegisterTest('layout / Min fills remainder',         @Test_MinFillsRemainder);
  RegisterTest('layout / multiple Mins split evenly',  @Test_MultipleMinsSplitEvenly);
  RegisterTest('layout / Min honours floor',           @Test_MinHonoursFloor);
  RegisterTest('layout / length+percentage+min mix',   @Test_PercentageLengthMinMix);
  RegisterTest('layout / empty area -> zero-sized',    @Test_EmptyAreaProducesZeroSlots);
  RegisterTest('layout / no constraints -> empty',     @Test_NoConstraintsReturnsEmpty);
  RegisterTest('layout / offset area preserves origin',@Test_OffsetAreaPreservesOrigin);
  RegisterTest('layout / TLayout = helper functions',  @Test_TLayoutBuilderEquivalentToHelpers);
  RegisterTest('layout / max constraint',              @Test_MaxConstraint);
  RegisterTest('layout / fill weighted',               @Test_FillWeighted);
  RegisterTest('layout / fill with length',            @Test_FillWithLength);
end;

end.
