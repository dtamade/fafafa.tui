unit test_sparkline;

{$mode objfpc}{$H+}

interface

procedure RegisterSparklineTests;

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
  ftui_sparkline;

procedure Test_EmptyDataRendersNothing;
var
  Buf: TBuffer;
  Sp: TSparkline;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    Sp := TSparkline.Create([]);
    Sp.Render(Buf.Area, Buf);
    // All cells should remain as spaces
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 1, 'empty data: cell is single byte');
    AssertTrue(CP^.Glyph.Bytes[0] = 32, 'empty data: cell is space');
  finally
    Buf.Free;
  end;
end;

procedure Test_SingleValueRendersDot;
var
  Buf: TBuffer;
  Sp: TSparkline;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Sp := TSparkline.Create([1.0]);
    Sp.Render(Buf.Area, Buf);
    // Single value with max=auto(1.0), height=1 cell (4 dot rows)
    // Value 1.0 scaled to top row -> dot at (0, 0) in dot space
    // That maps to cell (0,0), left col, row 0 -> bit $01
    // Braille U+2801
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'single value: glyph is 3 bytes');
    // U+2801 = E2 A0 81
    AssertTrue(CP^.Glyph.Bytes[0] = $E2, 'single value: byte0 = E2');
    AssertTrue(CP^.Glyph.Bytes[1] = $A0, 'single value: byte1 = A0');
    AssertTrue(CP^.Glyph.Bytes[2] = $81, 'single value: byte2 = 81');
  finally
    Buf.Free;
  end;
end;

procedure Test_AllSameValuesRenderMiddle;
var
  Buf: TBuffer;
  Sp: TSparkline;
  CP: PCell;
  Col: Integer;
  HasContent: Boolean;
begin
  // All same values: each point maps to same Y position
  // With height=2 cells (8 dot rows), value/max = 1.0 -> top row
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    Sp := TSparkline.Create([5.0, 5.0, 5.0, 5.0]);
    Sp.Render(Buf.Area, Buf);
    // All values equal max, so they map to dot row 0 (top)
    // 4 data points -> dot cols 0..3 -> cells (0,0) and (1,0)
    // Cell (0,0): left col row0 + right col row0 = $01 or $08 = $09
    // U+2809 = E2 A0 89
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'same vals: cell(0,0) has braille');
    AssertTrue(CP^.Glyph.Bytes[0] = $E2, 'same vals: byte0');
    AssertTrue(CP^.Glyph.Bytes[1] = $A0, 'same vals: byte1');
    AssertTrue(CP^.Glyph.Bytes[2] = $89, 'same vals: byte2 = 89');
    // Cell (1,0) should also have content
    CP := Buf.CellAt(1, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'same vals: cell(1,0) has braille');
  finally
    Buf.Free;
  end;
end;

procedure Test_MaxOverrideWorks;
var
  Buf: TBuffer;
  Sp: TSparkline;
  CP: PCell;
begin
  // With max=10, value 5 should be at middle height
  // Height=1 cell (4 dot rows), value 5/10 = 0.5
  // ScaledY = round(0.5 * 3) = round(1.5) = 2 (from bottom)
  // DotRow from top = 3 - 2 = 1
  // Cell (0,0), left col, row 1 -> bit $02
  // U+2802 = E2 A0 82
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Sp := TSparkline.Create([5.0]).WithMax(10.0);
    Sp.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'max override: glyph is 3 bytes');
    AssertTrue(CP^.Glyph.Bytes[0] = $E2, 'max override: byte0');
    AssertTrue(CP^.Glyph.Bytes[1] = $A0, 'max override: byte1');
    AssertTrue(CP^.Glyph.Bytes[2] = $82, 'max override: byte2 = 82');
  finally
    Buf.Free;
  end;
end;

procedure Test_DataLongerThanWidthShowsTail;
var
  Buf: TBuffer;
  Sp: TSparkline;
  CP: PCell;
begin
  // Width=2 cells -> 4 dot columns. Data has 6 points -> show last 4.
  // Data: [1, 2, 3, 4, 5, 6], max=6, show [3,4,5,6]
  // Height=1 (4 dot rows)
  // Point 3: scaled = round((3/6)*3) = round(1.5) = 2, dotRow=3-2=1
  //   -> cell(0,0) left col row1 = $02
  // Point 4: scaled = round((4/6)*3) = round(2.0) = 2, dotRow=3-2=1
  //   -> cell(0,0) right col row1 = $10
  // Cell(0,0) = $02 or $10 = $12 -> U+2812 = E2 A0 92
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    Sp := TSparkline.Create([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
    Sp.Render(Buf.Area, Buf);
    // First cell should have content (not empty)
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'tail: cell(0,0) has braille');
    // Second cell should also have content
    CP := Buf.CellAt(1, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'tail: cell(1,0) has braille');
  finally
    Buf.Free;
  end;
end;

procedure Test_StyleIsApplied;
var
  Buf: TBuffer;
  Sp: TSparkline;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Sp := TSparkline.Create([1.0])
            .WithStyle(TStyle.Default.WithFg(clGreen));
    Sp.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clGreen, CP^.Fg), 'style: fg = green');
  finally
    Buf.Free;
  end;
end;

procedure Test_AreaHeightAffectsResolution;
var
  Buf1, Buf2: TBuffer;
  Sp: TSparkline;
  CP1, CP2: PCell;
begin
  // Same data rendered in height=1 vs height=2 should produce different
  // braille patterns due to different dot-row resolution
  Buf1 := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Buf2 := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Sp := TSparkline.Create([0.0, 5.0, 10.0]).WithMax(10.0);
    Sp.Render(Buf1.Area, Buf1);

    Sp := TSparkline.Create([0.0, 5.0, 10.0]).WithMax(10.0);
    Sp.Render(Buf2.Area, Buf2);

    // In height=1, all dots are in row 0 cells
    // In height=2, dots span rows 0 and 1
    // The value 0.0 maps to bottom: height=1 -> dotRow=3, height=2 -> dotRow=7
    // For height=1: cell(0,0) row3 left = $40
    // For height=2: cell(0,1) row3 left = $40
    CP1 := Buf1.CellAt(0, 0);
    CP2 := Buf2.CellAt(0, 1);
    // Both should have the bottom dot, but in different cell rows
    AssertTrue(CP1^.Glyph.Len = 3, 'height1: cell(0,0) has braille');
    AssertTrue(CP2^.Glyph.Len = 3, 'height2: cell(0,1) has braille');
  finally
    Buf1.Free;
    Buf2.Free;
  end;
end;

procedure Test_EmptyAreaRendersNothing;
var
  Buf: TBuffer;
  Sp: TSparkline;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    Sp := TSparkline.Create([1.0, 2.0, 3.0]);
    // Should not crash
    Sp.Render(Buf.Area, Buf);
    AssertTrue(True, 'empty area: no crash');
  finally
    Buf.Free;
  end;
end;

procedure RegisterSparklineTests;
begin
  RegisterTest('sparkline / empty data renders nothing',       @Test_EmptyDataRendersNothing);
  RegisterTest('sparkline / single value renders dot',         @Test_SingleValueRendersDot);
  RegisterTest('sparkline / all same values render top',       @Test_AllSameValuesRenderMiddle);
  RegisterTest('sparkline / max override works',               @Test_MaxOverrideWorks);
  RegisterTest('sparkline / data longer than width shows tail',@Test_DataLongerThanWidthShowsTail);
  RegisterTest('sparkline / style is applied',                 @Test_StyleIsApplied);
  RegisterTest('sparkline / area height affects resolution',   @Test_AreaHeightAffectsResolution);
  RegisterTest('sparkline / empty area renders nothing',       @Test_EmptyAreaRendersNothing);
end;

end.
