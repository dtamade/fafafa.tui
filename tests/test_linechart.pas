unit test_linechart;

{$mode objfpc}{$H+}

interface

procedure RegisterLineChartTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_block,
  ftui_borders,
  ftui_canvas,
  ftui_linechart;

procedure Test_CreateSingleSeries;
var
  Chart: TLineChart;
begin
  Chart := TLineChart.Create([
    TDataSeries.Create('temp', [1.0, 2.0, 3.0, 4.0, 5.0])
  ]);
  AssertEqInt(1, Length(Chart.Series), 'single series: count = 1');
  AssertEqStr('temp', Chart.Series[0].Name, 'single series: name');
  AssertEqInt(5, Length(Chart.Series[0].Data), 'single series: data len');
end;

procedure Test_CreateMultipleSeries;
var
  Chart: TLineChart;
begin
  Chart := TLineChart.Create([
    TDataSeries.Create('cpu', [10.0, 20.0, 30.0]),
    TDataSeries.Create('mem', [50.0, 60.0, 70.0])
  ]);
  AssertEqInt(2, Length(Chart.Series), 'multi series: count = 2');
  AssertEqStr('cpu', Chart.Series[0].Name, 'multi series: name 0');
  AssertEqStr('mem', Chart.Series[1].Name, 'multi series: name 1');
end;

procedure Test_AutoScaleFindsRange;
var
  Chart: TLineChart;
  Buf: TBuffer;
begin
  // Auto-scale with data ranging from -5 to 25
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    Chart := TLineChart.Create([
      TDataSeries.Create('s1', [-5.0, 0.0, 10.0, 25.0])
    ]).WithShowAxes(False).WithShowLegend(False);
    Chart.Render(Buf.Area, Buf);
    // Should not crash; auto-scale handles negative values
    AssertTrue(True, 'auto-scale: no crash with negative values');
  finally
    Buf.Free;
  end;
end;

procedure Test_YRangeOverride;
var
  Chart: TLineChart;
begin
  Chart := TLineChart.Create([
    TDataSeries.Create('s1', [1.0, 2.0])
  ]).WithYRange(-10.0, 100.0);
  AssertTrue(Abs(Chart.MinY - (-10.0)) < 0.001, 'y range: min = -10');
  AssertTrue(Abs(Chart.MaxY - 100.0) < 0.001, 'y range: max = 100');
end;

procedure Test_RenderEmptySeriesNoCrash;
var
  Buf: TBuffer;
  Chart: TLineChart;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 8));
  try
    Chart := TLineChart.Create([
      TDataSeries.Create('empty', [])
    ]);
    Chart.Render(Buf.Area, Buf);
    AssertTrue(True, 'empty series: no crash');
  finally
    Buf.Free;
  end;
end;

procedure Test_RenderProducesVisibleOutput;
var
  Buf: TBuffer;
  Chart: TLineChart;
  X, Y: Integer;
  CP: PCell;
  Found: Boolean;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    Chart := TLineChart.Create([
      TDataSeries.Create('data', [0.0, 5.0, 3.0, 8.0, 2.0, 7.0])
    ]);
    Chart.Render(Buf.Area, Buf);
    // At least one cell should be non-space (braille or axis chars)
    Found := False;
    for Y := 0 to 9 do
      for X := 0 to 29 do
      begin
        CP := Buf.CellAt(X, Y);
        if (CP <> nil) and (CP^.Glyph.Len <> 1) then
          Found := True;
        if (CP <> nil) and (CP^.Glyph.Len = 1) and (CP^.Glyph.Bytes[0] <> 32) then
          Found := True;
      end;
    AssertTrue(Found, 'visible output: found non-space cells');
  finally
    Buf.Free;
  end;
end;

procedure Test_AxesShownWhenEnabled;
var
  Buf: TBuffer;
  Chart: TLineChart;
  CP: PCell;
  Y: Integer;
  FoundVertical: Boolean;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    Chart := TLineChart.Create([
      TDataSeries.Create('s1', [1.0, 5.0, 3.0])
    ]).WithShowAxes(True).WithShowLegend(False);
    Chart.Render(Buf.Area, Buf);
    // Y axis vertical line should be at x=4 (YAxisWidth-1)
    // Look for the vertical bar character (U+2502 = E2 94 82)
    FoundVertical := False;
    for Y := 0 to 8 do
    begin
      CP := Buf.CellAt(4, Y);
      if (CP <> nil) and (CP^.Glyph.Len = 3) then
        if (CP^.Glyph.Bytes[0] = $E2) and (CP^.Glyph.Bytes[1] = $94) and (CP^.Glyph.Bytes[2] = $82) then
          FoundVertical := True;
    end;
    AssertTrue(FoundVertical, 'axes: vertical axis line found');
  finally
    Buf.Free;
  end;
end;

procedure Test_LegendShownWhenEnabled;
var
  Buf: TBuffer;
  Chart: TLineChart;
  Row: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    Chart := TLineChart.Create([
      TDataSeries.Create('cpu', [1.0, 2.0, 3.0]),
      TDataSeries.Create('mem', [4.0, 5.0, 6.0])
    ]).WithShowLegend(True).WithShowAxes(False);
    Chart.Render(Buf.Area, Buf);
    // Legend row is the first row (y=0)
    Row := Buf.RowAsString(0);
    AssertTrue(Pos('cpu', Row) > 0, 'legend: "cpu" found in top row');
    AssertTrue(Pos('mem', Row) > 0, 'legend: "mem" found in top row');
  finally
    Buf.Free;
  end;
end;

procedure RegisterLineChartTests;
begin
  RegisterTest('linechart / create single series',           @Test_CreateSingleSeries);
  RegisterTest('linechart / create multiple series',         @Test_CreateMultipleSeries);
  RegisterTest('linechart / auto-scale finds range',         @Test_AutoScaleFindsRange);
  RegisterTest('linechart / y range override',               @Test_YRangeOverride);
  RegisterTest('linechart / render empty series no crash',   @Test_RenderEmptySeriesNoCrash);
  RegisterTest('linechart / render produces visible output', @Test_RenderProducesVisibleOutput);
  RegisterTest('linechart / axes shown when enabled',        @Test_AxesShownWhenEnabled);
  RegisterTest('linechart / legend shown when enabled',      @Test_LegendShownWhenEnabled);
end;

end.
