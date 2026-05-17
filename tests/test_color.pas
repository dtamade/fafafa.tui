unit test_color;

{$mode objfpc}{$H+}

interface

procedure RegisterColorTests;

implementation

uses
  ftui_testkit,
  ftui_color;

procedure Test_UnsetIsTheDefault;
var
  C: TColor;
begin
  C := UnsetColor;
  AssertEqInt(Ord(ckUnset), Ord(C.Kind), 'unset.Kind');
  AssertFalse(ColorIsSet(C), 'ColorIsSet(unset) is False');
end;

procedure Test_ResetDistinctFromUnset;
var
  U, R: TColor;
begin
  U := UnsetColor;
  R := ResetColor;
  AssertEqInt(Ord(ckReset), Ord(R.Kind), 'reset.Kind');
  AssertTrue(ColorIsSet(R), 'ColorIsSet(reset) is True (Reset is "explicitly default")');
  AssertFalse(ColorEquals(U, R), 'unset <> reset');
end;

procedure Test_IndexedColorsRoundTrip;
var
  C: TColor;
  I: Integer;
begin
  for I := 0 to 255 do
  begin
    C := IndexedColor(I);
    AssertEqInt(Ord(ckIndexed), Ord(C.Kind), 'indexed.Kind');
    AssertEqInt(I, C.Index, 'indexed.Index round-trip');
  end;
end;

procedure Test_RgbColorRoundTrip;
var
  C: TColor;
begin
  C := RgbColor(10, 20, 30);
  AssertEqInt(Ord(ckRgb), Ord(C.Kind), 'rgb.Kind');
  AssertEqInt(10, C.R, 'rgb.R');
  AssertEqInt(20, C.G, 'rgb.G');
  AssertEqInt(30, C.B, 'rgb.B');

  C := RgbColor(0, 0, 0);
  AssertEqInt(0, C.R + C.G + C.B, 'rgb black');

  C := RgbColor(255, 255, 255);
  AssertEqInt(765, C.R + C.G + C.B, 'rgb white');
end;

procedure Test_NamedColorsMapToIndexed_0_to_15;
begin
  AssertEqInt(0,  clBlack.Index,        'clBlack=0');
  AssertEqInt(1,  clRed.Index,          'clRed=1');
  AssertEqInt(2,  clGreen.Index,        'clGreen=2');
  AssertEqInt(3,  clYellow.Index,       'clYellow=3');
  AssertEqInt(4,  clBlue.Index,         'clBlue=4');
  AssertEqInt(5,  clMagenta.Index,      'clMagenta=5');
  AssertEqInt(6,  clCyan.Index,         'clCyan=6');
  AssertEqInt(7,  clGray.Index,         'clGray=7');
  AssertEqInt(8,  clDarkGray.Index,     'clDarkGray=8');
  AssertEqInt(9,  clLightRed.Index,     'clLightRed=9');
  AssertEqInt(10, clLightGreen.Index,   'clLightGreen=10');
  AssertEqInt(11, clLightYellow.Index,  'clLightYellow=11');
  AssertEqInt(12, clLightBlue.Index,    'clLightBlue=12');
  AssertEqInt(13, clLightMagenta.Index, 'clLightMagenta=13');
  AssertEqInt(14, clLightCyan.Index,    'clLightCyan=14');
  AssertEqInt(15, clWhite.Index,        'clWhite=15');

  AssertEqInt(Ord(ckIndexed), Ord(clRed.Kind), 'named is ckIndexed');
end;

procedure Test_ColorEqualsDistinguishesAllKinds;
begin
  // Same kind, same payload
  AssertTrue(ColorEquals(UnsetColor, UnsetColor),         'unset = unset');
  AssertTrue(ColorEquals(ResetColor, ResetColor),         'reset = reset');
  AssertTrue(ColorEquals(IndexedColor(5), IndexedColor(5)), 'idx 5 = idx 5');
  AssertTrue(ColorEquals(RgbColor(1,2,3), RgbColor(1,2,3)), 'rgb same');

  // Different kinds
  AssertFalse(ColorEquals(UnsetColor,        ResetColor),         'unset <> reset');
  AssertFalse(ColorEquals(IndexedColor(0),   ResetColor),         'idx 0 <> reset');
  AssertFalse(ColorEquals(IndexedColor(1),   RgbColor(1,1,1)),    'idx 1 <> rgb 1,1,1');

  // Same kind, different payload
  AssertFalse(ColorEquals(IndexedColor(5),   IndexedColor(6)),    'idx 5 <> idx 6');
  AssertFalse(ColorEquals(RgbColor(1,2,3),   RgbColor(1,2,4)),    'rgb b mismatch');
  AssertFalse(ColorEquals(RgbColor(0,0,0),   RgbColor(1,0,0)),    'rgb r mismatch');
end;

procedure Test_NamedColorsCompareEqualToIndexedBuilders;
begin
  AssertTrue(ColorEquals(clRed,    IndexedColor(1)),  'clRed = IndexedColor(1)');
  AssertTrue(ColorEquals(clCyan,   IndexedColor(6)),  'clCyan = IndexedColor(6)');
  AssertTrue(ColorEquals(clWhite,  IndexedColor(15)), 'clWhite = IndexedColor(15)');
end;

procedure Test_PackedRecordSizeIs4Bytes;
begin
  // ckUnset/ckReset/ckIndexed/ckRgb -> 1 byte enum, plus the 3-byte
  // case-record union (R/G/B occupy {Index} the same memory as R).
  // packed record promises no padding.
  AssertEqInt(4, SizeOf(TColor), 'SizeOf(TColor)');
end;

procedure RegisterColorTests;
begin
  RegisterTest('color / Unset is the default sentinel',     @Test_UnsetIsTheDefault);
  RegisterTest('color / Reset distinct from Unset',         @Test_ResetDistinctFromUnset);
  RegisterTest('color / IndexedColor 0..255 round-trip',    @Test_IndexedColorsRoundTrip);
  RegisterTest('color / RgbColor field round-trip',         @Test_RgbColorRoundTrip);
  RegisterTest('color / 16 named colors map to indexed 0..15', @Test_NamedColorsMapToIndexed_0_to_15);
  RegisterTest('color / ColorEquals across all kinds',      @Test_ColorEqualsDistinguishesAllKinds);
  RegisterTest('color / clRed = IndexedColor(1) etc',       @Test_NamedColorsCompareEqualToIndexedBuilders);
  RegisterTest('color / packed record is 4 bytes',          @Test_PackedRecordSizeIs4Bytes);
end;

end.
