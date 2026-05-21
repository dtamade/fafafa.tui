unit test_layout_dsl;

{$mode objfpc}{$H+}

interface

procedure RegisterLayoutDslTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_layout,
  ftui_layout_dsl;

procedure AssertConstraintEq(const Expected, Actual: TConstraint;
  const Ctx: AnsiString);
begin
  AssertEqInt(Ord(Expected.Kind), Ord(Actual.Kind), Ctx + ' Kind');
  AssertEqInt(Expected.Value, Actual.Value, Ctx + ' Value');
  AssertEqInt(Expected.Value2, Actual.Value2, Ctx + ' Value2');
end;

procedure Test_FixedEqualsLength;
begin
  AssertConstraintEq(LengthConstraint(10), Fixed(10), 'Fixed(10)');
  AssertConstraintEq(LengthConstraint(0), Fixed(0), 'Fixed(0)');
  AssertConstraintEq(LengthConstraint(255), Fixed(255), 'Fixed(255)');
end;

procedure Test_FlexEqualsFill;
begin
  AssertConstraintEq(FillConstraint(3), Flex(3), 'Flex(3)');
  AssertConstraintEq(FillConstraint(1), Flex(1), 'Flex(1)');
end;

procedure Test_FlexDefaultWeight;
begin
  AssertConstraintEq(FillConstraint(1), Flex(), 'Flex() default weight=1');
end;

procedure Test_PctEqualsPercentage;
begin
  AssertConstraintEq(PercentageConstraint(50), Pct(50), 'Pct(50)');
  AssertConstraintEq(PercentageConstraint(100), Pct(100), 'Pct(100)');
  AssertConstraintEq(PercentageConstraint(0), Pct(0), 'Pct(0)');
end;

procedure Test_AtLeastEqualsMin;
begin
  AssertConstraintEq(MinConstraint(5), AtLeast(5), 'AtLeast(5)');
  AssertConstraintEq(MinConstraint(0), AtLeast(0), 'AtLeast(0)');
end;

procedure Test_AtMostEqualsMax;
begin
  AssertConstraintEq(MaxConstraint(20), AtMost(20), 'AtMost(20)');
  AssertConstraintEq(MaxConstraint(0), AtMost(0), 'AtMost(0)');
end;

procedure Test_VEqualsVerticalSplit;
var
  Area: TRect;
  DslResult, DirectResult: TRectArray;
  I: Integer;
begin
  Area := TRect.Make(0, 0, 80, 24);
  DslResult := V(Area, [Fixed(3), Flex(1), Fixed(1)]);
  DirectResult := VerticalSplit(Area, [LengthConstraint(3), FillConstraint(1), LengthConstraint(1)]);
  AssertEqInt(Length(DirectResult), Length(DslResult), 'V slot count');
  for I := 0 to High(DslResult) do
  begin
    AssertEqInt(DirectResult[I].X, DslResult[I].X, Format('V slot %d X', [I]));
    AssertEqInt(DirectResult[I].Y, DslResult[I].Y, Format('V slot %d Y', [I]));
    AssertEqInt(DirectResult[I].Width, DslResult[I].Width, Format('V slot %d Width', [I]));
    AssertEqInt(DirectResult[I].Height, DslResult[I].Height, Format('V slot %d Height', [I]));
  end;
end;

procedure Test_HEqualsHorizontalSplit;
var
  Area: TRect;
  DslResult, DirectResult: TRectArray;
  I: Integer;
begin
  Area := TRect.Make(5, 2, 60, 10);
  DslResult := H(Area, [Pct(30), Flex(1), Fixed(10)]);
  DirectResult := HorizontalSplit(Area, [PercentageConstraint(30), FillConstraint(1), LengthConstraint(10)]);
  AssertEqInt(Length(DirectResult), Length(DslResult), 'H slot count');
  for I := 0 to High(DslResult) do
  begin
    AssertEqInt(DirectResult[I].X, DslResult[I].X, Format('H slot %d X', [I]));
    AssertEqInt(DirectResult[I].Y, DslResult[I].Y, Format('H slot %d Y', [I]));
    AssertEqInt(DirectResult[I].Width, DslResult[I].Width, Format('H slot %d Width', [I]));
    AssertEqInt(DirectResult[I].Height, DslResult[I].Height, Format('H slot %d Height', [I]));
  end;
end;

procedure RegisterLayoutDslTests;
begin
  RegisterTest('layout_dsl / Fixed equals LengthConstraint', @Test_FixedEqualsLength);
  RegisterTest('layout_dsl / Flex equals FillConstraint',    @Test_FlexEqualsFill);
  RegisterTest('layout_dsl / Flex default weight is 1',      @Test_FlexDefaultWeight);
  RegisterTest('layout_dsl / Pct equals PercentageConstraint', @Test_PctEqualsPercentage);
  RegisterTest('layout_dsl / AtLeast equals MinConstraint',  @Test_AtLeastEqualsMin);
  RegisterTest('layout_dsl / AtMost equals MaxConstraint',   @Test_AtMostEqualsMax);
  RegisterTest('layout_dsl / V equals VerticalSplit',        @Test_VEqualsVerticalSplit);
  RegisterTest('layout_dsl / H equals HorizontalSplit',      @Test_HEqualsHorizontalSplit);
end;

end.
