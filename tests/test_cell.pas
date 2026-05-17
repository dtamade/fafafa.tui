unit test_cell;

{$mode objfpc}{$H+}

interface

procedure RegisterCellTests;

implementation

uses
  ftui_testkit,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell;

procedure Test_CellEmptyIsBlankWithReset;
var
  C: TCell;
begin
  C := CellEmpty;
  AssertEqInt(1,  C.Glyph.Len, 'empty.glyph.len');
  AssertEqInt(32, C.Glyph.Bytes[0], 'empty.glyph[0] = space');
  AssertEqInt(Ord(ckReset), Ord(C.Fg.Kind), 'empty.fg = ckReset');
  AssertEqInt(Ord(ckReset), Ord(C.Bg.Kind), 'empty.bg = ckReset');
  AssertEqInt(Ord(ckReset), Ord(C.Ul.Kind), 'empty.ul = ckReset');
  AssertTrue(ModifierIsEmpty(C.Modifier),   'empty.mod = []');
  AssertEqInt(1, C.Width, 'empty.width = 1');
  AssertFalse(C.Skip, 'empty.skip = false');
end;

procedure Test_ResetRestoresEmpty;
var
  C: TCell;
begin
  C := CellEmpty;
  CellSetSymbolAscii(C, 'X');
  CellApplyStyle(C, TStyle.Default.WithFg(clRed).WithModifier([mbBold]));
  C.Skip := True;

  CellReset(C);
  AssertTrue(CellEquals(CellEmpty, C), 'reset restores CellEmpty bit-for-bit');
end;

procedure Test_SetSymbolAsciiBasic;
var
  C: TCell;
begin
  C := CellEmpty;
  CellSetSymbolAscii(C, 'A');
  AssertEqInt(1, C.Glyph.Len, 'glyph.len for A');
  AssertEqInt(Ord('A'), C.Glyph.Bytes[0], 'glyph[0] for A');
  AssertEqInt(1, C.Width, 'width = 1');
  AssertEqStr('A', CellGlyphAsString(C), 'glyph as string');
end;

procedure Test_SetSymbolBytesTruncatesAt23Bytes;
var
  C: TCell;
  Long: array[0..29] of Byte;
  I: Integer;
begin
  for I := 0 to 29 do
    Long[I] := Byte('a') + (I mod 26);
  C := CellEmpty;
  CellSetSymbolBytes(C, Long, 30, 1);
  AssertEqInt(23, C.Glyph.Len, 'len truncated to inline cap');
  AssertEqInt(Long[0],  C.Glyph.Bytes[0],  'first byte preserved');
  AssertEqInt(Long[22], C.Glyph.Bytes[22], 'last preserved byte');
end;

procedure Test_ApplyStyleOverridesOnlySetFields;
var
  C: TCell;
  S: TStyle;
begin
  C := CellEmpty;
  S := TStyle.Default.WithFg(clRed).WithModifier([mbBold]);
  CellApplyStyle(C, S);
  AssertTrue(ColorEquals(clRed, C.Fg), 'fg taken from style');
  AssertEqInt(Ord(ckReset), Ord(C.Bg.Kind), 'bg untouched (style.bg unset)');
  AssertTrue(mbBold in C.Modifier, 'bold added');

  // Patching with a SubMod-only style removes a bit, leaves others alone.
  S := TStyle.Default.WithoutModifier([mbBold]);
  CellApplyStyle(C, S);
  AssertFalse(mbBold in C.Modifier, 'bold removed via SubMod');
end;

procedure Test_CellEqualsDeep;
var
  A, B: TCell;
begin
  A := CellEmpty;
  B := CellEmpty;
  AssertTrue(CellEquals(A, B), 'two empty cells equal');

  CellSetSymbolAscii(B, 'x');
  AssertFalse(CellEquals(A, B), 'glyph diff -> not equal');

  CellSetSymbolAscii(A, 'x');
  AssertTrue(CellEquals(A, B), 'same glyph -> equal');

  CellApplyStyle(A, TStyle.Default.WithFg(clRed));
  AssertFalse(CellEquals(A, B), 'fg diff -> not equal');

  CellApplyStyle(B, TStyle.Default.WithFg(clRed));
  AssertTrue(CellEquals(A, B), 're-equal after both red');

  A.Skip := True;
  AssertFalse(CellEquals(A, B), 'skip diff -> not equal');
end;

procedure Test_CellSizeMatchesPackedExpectation;
begin
  // 24-byte glyph + 3*4-byte color + 2-byte modifier + 1 width + 1 skip
  // = 24 + 12 + 2 + 1 + 1 = 40, but packed records lay out without
  // padding, so this is exactly 40.  Lock the number so silent layout
  // changes (e.g. someone adds a field) trip the test.
  AssertEqInt(40, SizeOf(TCell), 'SizeOf(TCell) = 40');
end;

procedure RegisterCellTests;
begin
  RegisterTest('cell / CellEmpty is blank+reset',          @Test_CellEmptyIsBlankWithReset);
  RegisterTest('cell / Reset restores CellEmpty',          @Test_ResetRestoresEmpty);
  RegisterTest('cell / SetSymbolAscii basic',              @Test_SetSymbolAsciiBasic);
  RegisterTest('cell / SetSymbolBytes truncates at 23',    @Test_SetSymbolBytesTruncatesAt23Bytes);
  RegisterTest('cell / ApplyStyle overrides only set',     @Test_ApplyStyleOverridesOnlySetFields);
  RegisterTest('cell / CellEquals deep comparison',        @Test_CellEqualsDeep);
  RegisterTest('cell / SizeOf(TCell) = 40 packed',         @Test_CellSizeMatchesPackedExpectation);
end;

end.
