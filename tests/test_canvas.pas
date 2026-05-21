unit test_canvas;

{$mode objfpc}{$H+}

interface

procedure RegisterCanvasTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_canvas;

procedure Test_CreateSetsCorrectDimensions;
var
  C: TCanvas;
begin
  // 5 cells wide x 3 cells tall -> 10 dots wide x 12 dots tall
  C := TCanvas.Create(5, 3);
  AssertEqInt(10, C.Width, 'width = cellW * 2');
  AssertEqInt(12, C.Height, 'height = cellH * 4');
end;

procedure Test_SetDotGetDotRoundTrip;
var
  C: TCanvas;
begin
  C := TCanvas.Create(4, 2);
  AssertTrue(not C.GetDot(3, 5), 'initially unset');
  C.SetDot(3, 5);
  AssertTrue(C.GetDot(3, 5), 'set dot readable');
  AssertTrue(not C.GetDot(3, 4), 'adjacent dot still unset');
  AssertTrue(not C.GetDot(2, 5), 'adjacent dot still unset (x)');
end;

procedure Test_ClearDotWorks;
var
  C: TCanvas;
begin
  C := TCanvas.Create(4, 2);
  C.SetDot(1, 1);
  AssertTrue(C.GetDot(1, 1), 'dot set');
  C.ClearDot(1, 1);
  AssertTrue(not C.GetDot(1, 1), 'dot cleared');
end;

procedure Test_DrawLineHorizontal;
var
  C: TCanvas;
  X: Integer;
begin
  C := TCanvas.Create(4, 1);  // 8 dots wide, 4 dots tall
  C.DrawLine(0, 2, 7, 2);
  for X := 0 to 7 do
    AssertTrue(C.GetDot(X, 2), 'hline dot at x=' + IntToStr(X));
  // Dots above and below should be unset
  AssertTrue(not C.GetDot(0, 1), 'above hline unset');
  AssertTrue(not C.GetDot(0, 3), 'below hline unset');
end;

procedure Test_DrawLineVertical;
var
  C: TCanvas;
  Y: Integer;
begin
  C := TCanvas.Create(2, 2);  // 4 dots wide, 8 dots tall
  C.DrawLine(1, 0, 1, 7);
  for Y := 0 to 7 do
    AssertTrue(C.GetDot(1, Y), 'vline dot at y=' + IntToStr(Y));
  // Adjacent column should be unset
  AssertTrue(not C.GetDot(0, 0), 'left of vline unset');
  AssertTrue(not C.GetDot(2, 0), 'right of vline unset');
end;

procedure Test_DrawLineDiagonal;
var
  C: TCanvas;
begin
  C := TCanvas.Create(2, 2);  // 4x8 dots
  C.DrawLine(0, 0, 3, 3);
  // Bresenham diagonal: should hit (0,0), (1,1), (2,2), (3,3)
  AssertTrue(C.GetDot(0, 0), 'diag (0,0)');
  AssertTrue(C.GetDot(1, 1), 'diag (1,1)');
  AssertTrue(C.GetDot(2, 2), 'diag (2,2)');
  AssertTrue(C.GetDot(3, 3), 'diag (3,3)');
end;

procedure Test_DrawRectProducesOutline;
var
  C: TCanvas;
  X, Y: Integer;
begin
  C := TCanvas.Create(4, 2);  // 8x8 dots
  C.DrawRect(1, 1, 6, 6);
  // Top edge
  for X := 1 to 6 do
    AssertTrue(C.GetDot(X, 1), 'rect top at x=' + IntToStr(X));
  // Bottom edge
  for X := 1 to 6 do
    AssertTrue(C.GetDot(X, 6), 'rect bottom at x=' + IntToStr(X));
  // Left edge
  for Y := 1 to 6 do
    AssertTrue(C.GetDot(1, Y), 'rect left at y=' + IntToStr(Y));
  // Right edge
  for Y := 1 to 6 do
    AssertTrue(C.GetDot(6, Y), 'rect right at y=' + IntToStr(Y));
  // Interior should be empty
  AssertTrue(not C.GetDot(3, 3), 'rect interior empty');
  AssertTrue(not C.GetDot(4, 4), 'rect interior empty (2)');
end;

procedure Test_DrawCircleProducesApproxCircle;
var
  C: TCanvas;
  DotCount, X, Y: Integer;
begin
  C := TCanvas.Create(5, 3);  // 10x12 dots
  C.DrawCircle(5, 6, 4);
  // Count set dots - a circle of radius 4 should have roughly 24-28 dots
  DotCount := 0;
  for Y := 0 to C.Height - 1 do
    for X := 0 to C.Width - 1 do
      if C.GetDot(X, Y) then
        Inc(DotCount);
  AssertTrue(DotCount >= 16, 'circle has enough dots: ' + IntToStr(DotCount));
  AssertTrue(DotCount <= 40, 'circle not too many dots: ' + IntToStr(DotCount));
  // Check cardinal points
  AssertTrue(C.GetDot(5, 2), 'circle top');
  AssertTrue(C.GetDot(5, 10), 'circle bottom');
  AssertTrue(C.GetDot(1, 6), 'circle left');
  AssertTrue(C.GetDot(9, 6), 'circle right');
end;

procedure Test_RenderProducesBrailleChars;
var
  Buf: TBuffer;
  C: TCanvas;
  CP: PCell;
begin
  // Create a 1x1 cell canvas (2x4 dots), set one dot
  C := TCanvas.Create(1, 1);
  C.SetDot(0, 0);  // left col, row 0 -> bit $01 -> U+2801

  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    C.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'render: braille is 3 bytes');
    // U+2801 = E2 A0 81
    AssertTrue(CP^.Glyph.Bytes[0] = $E2, 'render: byte0 = E2');
    AssertTrue(CP^.Glyph.Bytes[1] = $A0, 'render: byte1 = A0');
    AssertTrue(CP^.Glyph.Bytes[2] = $81, 'render: byte2 = 81');
  finally
    Buf.Free;
  end;
end;

procedure Test_ClearResetsAllDots;
var
  C: TCanvas;
  X, Y: Integer;
  AnySet: Boolean;
begin
  C := TCanvas.Create(3, 2);
  C.DrawLine(0, 0, 5, 7);
  C.Clear;
  AnySet := False;
  for Y := 0 to C.Height - 1 do
    for X := 0 to C.Width - 1 do
      if C.GetDot(X, Y) then
        AnySet := True;
  AssertTrue(not AnySet, 'clear: no dots set');
end;

procedure Test_WithStyleApplied;
var
  Buf: TBuffer;
  C: TCanvas;
  CP: PCell;
begin
  C := TCanvas.Create(1, 1);
  C.SetDot(1, 1);
  C := C.WithStyle(TStyle.Default.WithFg(clCyan));

  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    C.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clCyan, CP^.Fg), 'withstyle: fg = cyan');
  finally
    Buf.Free;
  end;
end;

procedure Test_RenderMultipleDots;
var
  Buf: TBuffer;
  C: TCanvas;
  CP: PCell;
begin
  // Set dots at left-col row0 and right-col row2 in same cell
  // bit $01 (left,row0) + bit $20 (right,row2) = $21 -> U+2821
  C := TCanvas.Create(1, 1);
  C.SetDot(0, 0);  // left col, row 0 -> $01
  C.SetDot(1, 2);  // right col, row 2 -> $20

  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    C.Render(Buf.Area, Buf);
    CP := Buf.CellAt(0, 0);
    AssertTrue(CP^.Glyph.Len = 3, 'multi dots: 3 bytes');
    // U+2821 = E2 A0 A1
    AssertTrue(CP^.Glyph.Bytes[0] = $E2, 'multi dots: byte0');
    AssertTrue(CP^.Glyph.Bytes[1] = $A0, 'multi dots: byte1 = A0');
    AssertTrue(CP^.Glyph.Bytes[2] = $A1, 'multi dots: byte2 = A1');
  finally
    Buf.Free;
  end;
end;

procedure RegisterCanvasTests;
begin
  RegisterTest('canvas / create sets correct dimensions',    @Test_CreateSetsCorrectDimensions);
  RegisterTest('canvas / set/get dot round trip',            @Test_SetDotGetDotRoundTrip);
  RegisterTest('canvas / clear dot works',                   @Test_ClearDotWorks);
  RegisterTest('canvas / draw line horizontal',              @Test_DrawLineHorizontal);
  RegisterTest('canvas / draw line vertical',                @Test_DrawLineVertical);
  RegisterTest('canvas / draw line diagonal',                @Test_DrawLineDiagonal);
  RegisterTest('canvas / draw rect produces outline',        @Test_DrawRectProducesOutline);
  RegisterTest('canvas / draw circle produces approx circle',@Test_DrawCircleProducesApproxCircle);
  RegisterTest('canvas / render produces braille chars',     @Test_RenderProducesBrailleChars);
  RegisterTest('canvas / clear resets all dots',             @Test_ClearResetsAllDots);
  RegisterTest('canvas / with style applied',                @Test_WithStyleApplied);
  RegisterTest('canvas / render multiple dots in one cell',  @Test_RenderMultipleDots);
end;

end.
