unit test_buffer;

{$mode objfpc}{$H+}

interface

procedure RegisterBufferTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer;

procedure Test_EmptyConstructor;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    AssertEqInt(5, Buf.Width, 'width');
    AssertEqInt(3, Buf.Height, 'height');
    AssertEqInt(15, Buf.Length_, 'length = 15');
    AssertBufferEquals(Buf, [
      '     ',
      '     ',
      '     '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_FilledConstructor;
var
  Buf: TBuffer;
  C: TCell;
begin
  C := CellEmpty;
  CellSetSymbolAscii(C, '#');
  Buf := TBuffer.CreateFilled(TRect.Make(0, 0, 4, 2), C);
  try
    AssertBufferEquals(Buf, [
      '####',
      '####'
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_CellAtBoundsAndOffset;
var
  Buf: TBuffer;
  P: PCell;
begin
  // Non-zero origin — make sure index math respects Area.X/Y offset.
  Buf := TBuffer.CreateEmpty(TRect.Make(2, 3, 4, 4));
  try
    AssertTrue (Buf.CellAt(2, 3) <> nil, '(2,3) is the top-left cell');
    AssertTrue (Buf.CellAt(5, 6) <> nil, '(5,6) is in-bounds');
    AssertTrue (Buf.CellAt(1, 3) =  nil, 'left of area is nil');
    AssertTrue (Buf.CellAt(2, 2) =  nil, 'above area is nil');
    AssertTrue (Buf.CellAt(6, 3) =  nil, 'right of area is nil');
    AssertTrue (Buf.CellAt(2, 7) =  nil, 'below area is nil');

    P := Buf.CellAt(3, 4);
    CellSetSymbolAscii(P^, 'k');
    AssertEqInt(Ord('k'), Buf.CellAt(3, 4)^.Glyph.Bytes[0],
      'mutation through PCell visible later');
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStringBasic;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    Buf.SetString(0, 0, 'hello', TStyle.Default);
    AssertBufferEquals(Buf, [
      'hello     ',
      '          '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStringClipsAtRightEdge;
var
  Buf: TBuffer;
  Written: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    Written := Buf.SetString(3, 0, 'abcdef', TStyle.Default);
    AssertEqInt(3, Written, 'only 3 columns fit');
    AssertBufferEquals(Buf, [
      '   abc'
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStringNRespectsMax;
var
  Buf: TBuffer;
  Written: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    Written := Buf.SetStringN(0, 0, 'hello world', 5, TStyle.Default);
    AssertEqInt(5, Written, '5 columns');
    AssertBufferEquals(Buf, [
      'hello     '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStringDropsControlBytes;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    Buf.SetString(0, 0, 'a' + #9 + 'b' + #13 + 'c', TStyle.Default);
    AssertBufferEquals(Buf, [
      'abc   '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStringAppliesStyle;
var
  Buf: TBuffer;
  P: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    Buf.SetString(0, 0, 'OK', TStyle.Default.WithFg(clRed).WithModifier([mbBold]));
    P := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clRed, P^.Fg), '(0,0).fg = red');
    AssertTrue(mbBold in P^.Modifier, '(0,0).bold');
    P := Buf.CellAt(2, 0);
    AssertEqInt(Ord(ckReset), Ord(P^.Fg.Kind),
      'untouched cell still ckReset');
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStyleOverArea;
var
  Buf: TBuffer;
  P: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    Buf.SetStyle(TRect.Make(1, 1, 3, 1), TStyle.Default.WithBg(clBlue));

    P := Buf.CellAt(1, 1); AssertTrue(ColorEquals(clBlue, P^.Bg), '(1,1)');
    P := Buf.CellAt(3, 1); AssertTrue(ColorEquals(clBlue, P^.Bg), '(3,1)');
    P := Buf.CellAt(0, 1); AssertEqInt(Ord(ckReset), Ord(P^.Bg.Kind), '(0,1) outside');
    P := Buf.CellAt(4, 1); AssertEqInt(Ord(ckReset), Ord(P^.Bg.Kind), '(4,1) outside');
    P := Buf.CellAt(1, 0); AssertEqInt(Ord(ckReset), Ord(P^.Bg.Kind), '(1,0) above');
  finally
    Buf.Free;
  end;
end;

procedure Test_ResetRestoresAllEmpty;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    Buf.SetString(0, 0, 'noisy', TStyle.Default.WithFg(clRed));
    Buf.SetString(0, 1, 'data', TStyle.Default.WithBg(clGreen));
    Buf.Reset;
    AssertBufferEquals(Buf, [
      '    ',
      '    '
    ]);
    AssertTrue(ColorEquals(ResetColor, Buf.CellAt(0, 0)^.Fg), 'reset restores Fg');
  finally
    Buf.Free;
  end;
end;

procedure Test_ResizeShrinkAndGrowKeepsOverlap;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    Buf.SetString(0, 0, 'abcdef', TStyle.Default);
    Buf.SetString(0, 1, '123456', TStyle.Default);
    Buf.SetString(0, 2, 'XXXXXX', TStyle.Default);

    // Shrink: keep 4x2 from top-left.
    Buf.Resize(TRect.Make(0, 0, 4, 2));
    AssertBufferEquals(Buf, [
      'abcd',
      '1234'
    ]);

    // Grow: extend to 6x3, with new cells filled blank.
    Buf.Resize(TRect.Make(0, 0, 6, 3));
    AssertBufferEquals(Buf, [
      'abcd  ',
      '1234  ',
      '      '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_DiffEmitsOnlyChangedCells;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Prev.SetString(0, 0, 'hello', TStyle.Default);
    Curr.SetString(0, 0, 'hellp', TStyle.Default);     // last cell differs

    Prev.Diff(Curr, Patches);
    AssertEqInt(1, Length(Patches), 'one patch only');
    AssertEqInt(4, Patches[0].X, 'patch x = 4');
    AssertEqInt(0, Patches[0].Y, 'patch y = 0');
    AssertEqInt(Ord('p'), Patches[0].Cell.Glyph.Bytes[0], 'patch glyph');
  finally
    Curr.Free;
    Prev.Free;
  end;
end;

procedure Test_DiffEmitsZeroWhenIdentical;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    Prev.SetString(0, 0, 'wxyz', TStyle.Default);
    Curr.SetString(0, 0, 'wxyz', TStyle.Default);
    Prev.Diff(Curr, Patches);
    AssertEqInt(0, Length(Patches), 'identical buffers diff to nothing');
  finally
    Curr.Free;
    Prev.Free;
  end;
end;

procedure Test_DiffSkipFlagSuppressesEmission;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  P: PCell;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    Prev.SetString(0, 0, 'aaa', TStyle.Default);
    Curr.SetString(0, 0, 'bbb', TStyle.Default);

    P := Curr.CellAt(1, 0);
    P^.Skip := True;     // mark middle cell skip

    Prev.Diff(Curr, Patches);
    AssertEqInt(2, Length(Patches), 'skip suppresses one of three changes');
    AssertEqInt(0, Patches[0].X, 'first patch at x=0');
    AssertEqInt(2, Patches[1].X, 'second patch at x=2 (skipped middle)');
  finally
    Curr.Free;
    Prev.Free;
  end;
end;

procedure Test_DiffStyleOnlyChangeIsDetected;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    Prev.SetString(0, 0, 'abc', TStyle.Default);
    Curr.SetString(0, 0, 'abc', TStyle.Default.WithFg(clRed));
    Prev.Diff(Curr, Patches);
    AssertEqInt(3, Length(Patches), 'style change emits all 3 cells');
  finally
    Curr.Free;
    Prev.Free;
  end;
end;

procedure RegisterBufferTests;
begin
  RegisterTest('buffer / empty constructor 5x3',          @Test_EmptyConstructor);
  RegisterTest('buffer / filled constructor with #',      @Test_FilledConstructor);
  RegisterTest('buffer / CellAt bounds with offset Area', @Test_CellAtBoundsAndOffset);
  RegisterTest('buffer / SetString basic',                @Test_SetStringBasic);
  RegisterTest('buffer / SetString clips at right',       @Test_SetStringClipsAtRightEdge);
  RegisterTest('buffer / SetStringN respects max',        @Test_SetStringNRespectsMax);
  RegisterTest('buffer / SetString drops control bytes',  @Test_SetStringDropsControlBytes);
  RegisterTest('buffer / SetString applies style',        @Test_SetStringAppliesStyle);
  RegisterTest('buffer / SetStyle over area',             @Test_SetStyleOverArea);
  RegisterTest('buffer / Reset restores all empty',       @Test_ResetRestoresAllEmpty);
  RegisterTest('buffer / Resize shrink+grow keeps overlap', @Test_ResizeShrinkAndGrowKeepsOverlap);
  RegisterTest('buffer / Diff emits only changed cells',  @Test_DiffEmitsOnlyChangedCells);
  RegisterTest('buffer / Diff zero when identical',       @Test_DiffEmitsZeroWhenIdentical);
  RegisterTest('buffer / Diff skip flag suppresses',      @Test_DiffSkipFlagSuppressesEmission);
  RegisterTest('buffer / Diff style-only change detected',@Test_DiffStyleOnlyChangeIsDetected);
end;

end.
