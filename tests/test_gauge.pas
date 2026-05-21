unit test_gauge;

{$mode objfpc}{$H+}

interface

procedure RegisterGaugeTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_gauge;

const
  BLOCK_FULL = #$E2#$96#$88;

procedure Test_DefaultCreatesValidGauge;
var
  G: TGauge;
begin
  G := TGauge.Default;
  AssertTrue(G.Ratio = 0.0, 'default ratio is 0');
  AssertEqStr('', G.Label_, 'default label is empty');
end;

procedure Test_RatioZeroAllEmpty;
var
  Buf: TBuffer;
  G: TGauge;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default.WithRatio(0.0);
    G.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['          ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_RatioOneAllFilled;
var
  Buf: TBuffer;
  G: TGauge;
  Expected: AnsiString;
  I: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    G := TGauge.Default.WithRatio(1.0);
    G.Render(Buf.Area, Buf);
    Expected := '';
    for I := 1 to 5 do
      Expected := Expected + BLOCK_FULL;
    AssertBufferEquals(Buf, [Expected]);
  finally
    Buf.Free;
  end;
end;

procedure Test_RatioHalfOnWidth10;
var
  Buf: TBuffer;
  G: TGauge;
  Expected: AnsiString;
  I: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default.WithRatio(0.5);
    G.Render(Buf.Area, Buf);
    Expected := '';
    for I := 1 to 5 do
      Expected := Expected + BLOCK_FULL;
    // Remaining 5 columns are spaces
    Expected := Expected + '     ';
    AssertBufferEquals(Buf, [Expected]);
  finally
    Buf.Free;
  end;
end;

procedure Test_FilledStyleApplied;
var
  Buf: TBuffer;
  G: TGauge;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    G := TGauge.Default
          .WithRatio(1.0)
          .WithFilledStyle(TStyle.Default.WithFg(clGreen));
    G.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clGreen, CP^.Fg), 'filled cell fg = green');
  finally
    Buf.Free;
  end;
end;

procedure Test_EmptyStyleApplied;
var
  Buf: TBuffer;
  G: TGauge;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    G := TGauge.Default
          .WithRatio(0.0)
          .WithEmptyStyle(TStyle.Default.WithBg(clRed));
    G.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clRed, CP^.Bg), 'empty cell bg = red');
  finally
    Buf.Free;
  end;
end;

procedure Test_LabelCentered;
var
  Buf: TBuffer;
  G: TGauge;
  Row: AnsiString;
begin
  // Width 10, ratio 0.0, label '45%' (3 chars) -> centered at col 3..5
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default
          .WithRatio(0.0)
          .WithLabel('45%');
    G.Render(Buf.Area, Buf);
    Row := Buf.RowAsString(0);
    // Label should be at position 3 (centered: (10-3)/2 = 3)
    AssertEqStr('   45%    ', Row, 'label centered in bar');
  finally
    Buf.Free;
  end;
end;

procedure Test_RatioClampedAboveOne;
var
  G: TGauge;
begin
  G := TGauge.Default.WithRatio(1.5);
  AssertTrue(G.Ratio = 1.0, 'ratio clamped to 1.0');
end;

procedure Test_RatioClampedBelowZero;
var
  G: TGauge;
begin
  G := TGauge.Default.WithRatio(-0.5);
  AssertTrue(G.Ratio = 0.0, 'ratio clamped to 0.0');
end;

procedure Test_ThresholdPicksHighestMatch;
var
  Buf: TBuffer;
  G: TGauge;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default
          .WithRatio(0.95)
          .WithThreshold(0.0, TStyle.Default.WithFg(clGreen))
          .WithThreshold(0.7, TStyle.Default.WithFg(clYellow))
          .WithThreshold(0.9, TStyle.Default.WithFg(clRed));
    G.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clRed, CP^.Fg), 'threshold 0.95 -> red');
  finally
    Buf.Free;
  end;
end;

procedure Test_ThresholdMidRange;
var
  Buf: TBuffer;
  G: TGauge;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default
          .WithRatio(0.75)
          .WithThreshold(0.0, TStyle.Default.WithFg(clGreen))
          .WithThreshold(0.7, TStyle.Default.WithFg(clYellow))
          .WithThreshold(0.9, TStyle.Default.WithFg(clRed));
    G.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clYellow, CP^.Fg), 'threshold 0.75 -> yellow');
  finally
    Buf.Free;
  end;
end;

procedure Test_ThresholdOrderIndependent;
var
  Buf: TBuffer;
  G: TGauge;
  CP: PCell;
begin
  // Add thresholds in reverse order — should still work
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default
          .WithRatio(0.95)
          .WithThreshold(0.9, TStyle.Default.WithFg(clRed))
          .WithThreshold(0.0, TStyle.Default.WithFg(clGreen))
          .WithThreshold(0.7, TStyle.Default.WithFg(clYellow));
    G.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clRed, CP^.Fg), 'reverse order: 0.95 -> red');
  finally
    Buf.Free;
  end;
end;

procedure Test_ThresholdFallbackToFilledStyle;
var
  Buf: TBuffer;
  G: TGauge;
  CP: PCell;
begin
  // No thresholds match (ratio below all limits) -> use FilledStyle
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    G := TGauge.Default
          .WithRatio(0.5)
          .WithFilledStyle(TStyle.Default.WithFg(clCyan))
          .WithThreshold(0.7, TStyle.Default.WithFg(clYellow))
          .WithThreshold(0.9, TStyle.Default.WithFg(clRed));
    G.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clCyan, CP^.Fg), 'below all thresholds -> FilledStyle');
  finally
    Buf.Free;
  end;
end;

procedure RegisterGaugeTests;
begin
  RegisterTest('gauge / default creates valid gauge',     @Test_DefaultCreatesValidGauge);
  RegisterTest('gauge / ratio 0.0 = all empty',          @Test_RatioZeroAllEmpty);
  RegisterTest('gauge / ratio 1.0 = all filled',         @Test_RatioOneAllFilled);
  RegisterTest('gauge / ratio 0.5 on width 10',          @Test_RatioHalfOnWidth10);
  RegisterTest('gauge / filled style applied',           @Test_FilledStyleApplied);
  RegisterTest('gauge / empty style applied',            @Test_EmptyStyleApplied);
  RegisterTest('gauge / label centered',                 @Test_LabelCentered);
  RegisterTest('gauge / ratio clamped above 1.0',        @Test_RatioClampedAboveOne);
  RegisterTest('gauge / ratio clamped below 0.0',        @Test_RatioClampedBelowZero);
  RegisterTest('gauge / threshold picks highest match',  @Test_ThresholdPicksHighestMatch);
  RegisterTest('gauge / threshold mid range',            @Test_ThresholdMidRange);
  RegisterTest('gauge / threshold order independent',    @Test_ThresholdOrderIndependent);
  RegisterTest('gauge / threshold fallback to filled',   @Test_ThresholdFallbackToFilledStyle);
end;

end.
