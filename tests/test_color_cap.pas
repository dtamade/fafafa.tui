unit test_color_cap;

{$mode objfpc}{$H+}

interface

procedure RegisterColorCapTests;

implementation

uses
  ftui_testkit,
  ftui_color,
  ftui_color_cap;

procedure Test_TrueColorPassthrough;
var C, R: TColor;
begin
  C := RgbColor(100, 150, 200);
  R := ResolveColor(C, ccTrueColor);
  AssertTrue(ColorEquals(C, R), 'truecolor passes through');
end;

procedure Test_RgbTo256;
var C, R: TColor;
begin
  C := RgbColor(0, 0, 0);
  R := ResolveColor(C, cc256);
  AssertTrue(R.Kind = ckIndexed, 'becomes indexed');
  AssertTrue(R.Index >= 16, 'maps to 256 palette');
end;

procedure Test_RgbTo16;
var C, R: TColor;
begin
  C := RgbColor(255, 0, 0);
  R := ResolveColor(C, cc16);
  AssertTrue(R.Kind = ckIndexed, 'becomes indexed');
  AssertTrue(R.Index < 16, 'maps to 16 palette');
end;

procedure Test_MonoBecomesReset;
var C, R: TColor;
begin
  C := RgbColor(128, 64, 200);
  R := ResolveColor(C, ccMono);
  AssertTrue(R.Kind = ckReset, 'mono degrades to reset');
end;

procedure Test_Indexed16Passthrough;
var C, R: TColor;
begin
  C := IndexedColor(5);
  R := ResolveColor(C, cc16);
  AssertTrue(ColorEquals(C, R), 'indexed <16 passes through in cc16');
end;

procedure Test_Indexed256To16;
var C, R: TColor;
begin
  C := IndexedColor(196);
  R := ResolveColor(C, cc16);
  AssertTrue(R.Kind = ckIndexed, 'still indexed');
  AssertTrue(R.Index < 16, 'degraded to 16-color');
end;

procedure Test_UnsetPassthrough;
var C, R: TColor;
begin
  C := UnsetColor;
  R := ResolveColor(C, ccMono);
  AssertTrue(R.Kind = ckUnset, 'unset passes through');
end;

procedure Test_DetectReturnsValid;
var Cap: TColorCapability;
begin
  Cap := DetectColorCapability;
  AssertTrue((Cap >= ccMono) and (Cap <= ccTrueColor), 'valid capability');
end;

procedure RegisterColorCapTests;
begin
  RegisterTest('color_cap / truecolor passthrough', @Test_TrueColorPassthrough);
  RegisterTest('color_cap / rgb to 256',            @Test_RgbTo256);
  RegisterTest('color_cap / rgb to 16',             @Test_RgbTo16);
  RegisterTest('color_cap / mono becomes reset',    @Test_MonoBecomesReset);
  RegisterTest('color_cap / indexed 16 passthrough',@Test_Indexed16Passthrough);
  RegisterTest('color_cap / indexed 256 to 16',     @Test_Indexed256To16);
  RegisterTest('color_cap / unset passthrough',     @Test_UnsetPassthrough);
  RegisterTest('color_cap / detect returns valid',  @Test_DetectReturnsValid);
end;

end.
