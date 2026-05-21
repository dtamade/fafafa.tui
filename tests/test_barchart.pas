unit test_barchart;

{$mode objfpc}{$H+}

interface

procedure RegisterBarChartTests;

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
  ftui_barchart;

procedure Test_CreateWithData;
var
  Chart: TBarChart;
begin
  Chart := TBarChart.Create([
    TBarData.Make('A', 10.0),
    TBarData.Make('B', 20.0),
    TBarData.Make('C', 15.0)
  ]);
  AssertEqInt(3, Length(Chart.Bars), 'create: 3 bars');
  AssertEqStr('A', Chart.Bars[0].Label_, 'create: bar 0 label');
  AssertTrue(Abs(Chart.Bars[1].Value - 20.0) < 0.001, 'create: bar 1 value');
  AssertEqInt(3, Chart.BarWidth, 'create: default bar width');
  AssertEqInt(1, Chart.BarGap, 'create: default bar gap');
end;

procedure Test_AutoScaleFindsMax;
var
  Chart: TBarChart;
  Buf: TBuffer;
  CP: PCell;
begin
  // With auto-scale, the tallest bar (value=100) should fill the full height
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    Chart := TBarChart.Create([
      TBarData.Make('A', 50.0),
      TBarData.Make('B', 100.0)
    ]).WithShowValues(False).WithShowLabels(False);
    Chart.Render(Buf.Area, Buf);
    // Bar B at max should have full blocks at the bottom row
    // Bar B starts at x = 1*(3+1) = 4
    CP := Buf.CellAt(4, 4);
    AssertTrue(CP^.Glyph.Len = 3, 'auto-scale: bar B bottom has block char');
  finally
    Buf.Free;
  end;
end;

procedure Test_MaxValOverride;
var
  Chart: TBarChart;
begin
  Chart := TBarChart.Create([
    TBarData.Make('A', 50.0)
  ]).WithMax(200.0);
  AssertTrue(Abs(Chart.MaxVal - 200.0) < 0.001, 'max override: MaxVal = 200');
end;

procedure Test_RenderEmptyData;
var
  Buf: TBuffer;
  Chart: TBarChart;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    Chart := TBarChart.Create([]);
    Chart.Render(Buf.Area, Buf);
    // Should not crash; all cells remain spaces
    AssertTrue(True, 'empty data: no crash');
  finally
    Buf.Free;
  end;
end;

procedure Test_RenderProducesVisibleOutput;
var
  Buf: TBuffer;
  Chart: TBarChart;
  X, Y: Integer;
  CP: PCell;
  Found: Boolean;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 8));
  try
    Chart := TBarChart.Create([
      TBarData.Make('A', 10.0),
      TBarData.Make('B', 20.0),
      TBarData.Make('C', 15.0)
    ]);
    Chart.Render(Buf.Area, Buf);
    // At least one cell should be non-space
    Found := False;
    for Y := 0 to 7 do
      for X := 0 to 19 do
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

procedure Test_BarWidthRespected;
var
  Buf: TBuffer;
  Chart: TBarChart;
  CP: PCell;
  X: Integer;
  Count: Integer;
begin
  // Single bar with width=5, value at max -> full blocks across 5 columns
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    Chart := TBarChart.Create([
      TBarData.Make('X', 10.0)
    ]).WithBarWidth(5).WithShowValues(False).WithShowLabels(False);
    Chart.Render(Buf.Area, Buf);
    // Bottom row should have 5 consecutive block chars
    Count := 0;
    for X := 0 to 9 do
    begin
      CP := Buf.CellAt(X, 2);
      if (CP <> nil) and (CP^.Glyph.Len = 3) then
        Inc(Count);
    end;
    AssertTrue(Count >= 5, 'bar width: at least 5 block cells in bottom row');
  finally
    Buf.Free;
  end;
end;

procedure Test_LabelsShownWhenEnabled;
var
  Buf: TBuffer;
  Chart: TBarChart;
  Row: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    Chart := TBarChart.Create([
      TBarData.Make('Hi', 10.0)
    ]).WithShowLabels(True).WithShowValues(False).WithBarWidth(3);
    Chart.Render(Buf.Area, Buf);
    // Label row is the last row (y=4)
    Row := Buf.RowAsString(4);
    AssertTrue(Pos('Hi', Row) > 0, 'labels: "Hi" found in bottom row');
  finally
    Buf.Free;
  end;
end;

procedure Test_ValuesShownWhenEnabled;
var
  Buf: TBuffer;
  Chart: TBarChart;
  Row: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    Chart := TBarChart.Create([
      TBarData.Make('A', 42.0)
    ]).WithShowValues(True).WithShowLabels(False).WithBarWidth(3);
    Chart.Render(Buf.Area, Buf);
    // Value row is the first row (y=0)
    Row := Buf.RowAsString(0);
    AssertTrue(Pos('42', Row) > 0, 'values: "42" found in top row');
  finally
    Buf.Free;
  end;
end;

procedure RegisterBarChartTests;
begin
  RegisterTest('barchart / create with data',              @Test_CreateWithData);
  RegisterTest('barchart / auto-scale finds max',          @Test_AutoScaleFindsMax);
  RegisterTest('barchart / max val override',              @Test_MaxValOverride);
  RegisterTest('barchart / render empty data no crash',    @Test_RenderEmptyData);
  RegisterTest('barchart / render produces visible output',@Test_RenderProducesVisibleOutput);
  RegisterTest('barchart / bar width respected',           @Test_BarWidthRespected);
  RegisterTest('barchart / labels shown when enabled',     @Test_LabelsShownWhenEnabled);
  RegisterTest('barchart / values shown when enabled',     @Test_ValuesShownWhenEnabled);
end;

end.
