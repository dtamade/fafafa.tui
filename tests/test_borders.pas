unit test_borders;

{$mode objfpc}{$H+}

interface

procedure RegisterBordersTests;

implementation

uses
  ftui_testkit,
  ftui_borders,
  ftui_grapheme;

procedure AssertGlyph3Bytes(const G: AnsiString; const Name: AnsiString);
begin
  AssertEqInt(3, Length(G), Name + ' is 3 bytes');
end;

procedure AssertGlyphWidth1(const G: AnsiString; const Name: AnsiString);
var
  Adv: TGraphemeAdvance;
begin
  Adv := GraphemeAdvance(G[1], Length(G), 0);
  AssertEqInt(1, Adv.Width, Name + ' display width = 1');
end;

procedure AssertBorderSetComplete(const BS: TBorderSet; const Name: AnsiString);
begin
  AssertTrue(BS.Horizontal <> '', Name + '.Horizontal');
  AssertTrue(BS.Vertical <> '', Name + '.Vertical');
  AssertTrue(BS.TopLeft <> '', Name + '.TopLeft');
  AssertTrue(BS.TopRight <> '', Name + '.TopRight');
  AssertTrue(BS.BottomLeft <> '', Name + '.BottomLeft');
  AssertTrue(BS.BottomRight <> '', Name + '.BottomRight');
  AssertTrue(BS.LeftT <> '', Name + '.LeftT');
  AssertTrue(BS.RightT <> '', Name + '.RightT');
  AssertTrue(BS.TopT <> '', Name + '.TopT');
  AssertTrue(BS.BottomT <> '', Name + '.BottomT');
  AssertTrue(BS.Cross <> '', Name + '.Cross');
end;

procedure Test_PlainGlyphs3Bytes;
begin
  AssertGlyph3Bytes(BorderHorizontal, 'H');
  AssertGlyph3Bytes(BorderVertical, 'V');
  AssertGlyph3Bytes(BorderTopLeft, 'TL');
  AssertGlyph3Bytes(BorderTopRight, 'TR');
  AssertGlyph3Bytes(BorderBottomLeft, 'BL');
  AssertGlyph3Bytes(BorderBottomRight, 'BR');
end;

procedure Test_ConnectorGlyphs3Bytes;
begin
  AssertGlyph3Bytes(BorderLeftT, 'LeftT');
  AssertGlyph3Bytes(BorderRightT, 'RightT');
  AssertGlyph3Bytes(BorderTopT, 'TopT');
  AssertGlyph3Bytes(BorderBottomT, 'BottomT');
  AssertGlyph3Bytes(BorderCross, 'Cross');
end;

procedure Test_DoubleGlyphs3Bytes;
begin
  AssertGlyph3Bytes(BorderDoubleH, 'DH');
  AssertGlyph3Bytes(BorderDoubleV, 'DV');
  AssertGlyph3Bytes(BorderDoubleTL, 'DTL');
  AssertGlyph3Bytes(BorderDoubleTR, 'DTR');
  AssertGlyph3Bytes(BorderDoubleBL, 'DBL');
  AssertGlyph3Bytes(BorderDoubleBR, 'DBR');
end;

procedure Test_HeavyGlyphs3Bytes;
begin
  AssertGlyph3Bytes(BorderHeavyH, 'HH');
  AssertGlyph3Bytes(BorderHeavyV, 'HV');
  AssertGlyph3Bytes(BorderHeavyTL, 'HTL');
  AssertGlyph3Bytes(BorderHeavyTR, 'HTR');
  AssertGlyph3Bytes(BorderHeavyBL, 'HBL');
  AssertGlyph3Bytes(BorderHeavyBR, 'HBR');
end;

procedure Test_GlyphDisplayWidth;
begin
  AssertGlyphWidth1(BorderHorizontal, 'H');
  AssertGlyphWidth1(BorderVertical, 'V');
  AssertGlyphWidth1(BorderTopLeft, 'TL');
  AssertGlyphWidth1(BorderDoubleH, 'DH');
  AssertGlyphWidth1(BorderHeavyH, 'HH');
  AssertGlyphWidth1(BorderDashedH, 'DashH');
  AssertGlyphWidth1(BorderCross, 'Cross');
  AssertGlyphWidth1(BorderRoundedTL, 'RndTL');
end;

procedure Test_BorderSetPlainComplete;
begin
  AssertBorderSetComplete(BorderSetPlain, 'Plain');
end;

procedure Test_BorderSetRoundedComplete;
begin
  AssertBorderSetComplete(BorderSetRounded, 'Rounded');
end;

procedure Test_BorderSetDoubleComplete;
begin
  AssertBorderSetComplete(BorderSetDouble, 'Double');
end;

procedure Test_BorderSetHeavyComplete;
begin
  AssertBorderSetComplete(BorderSetHeavy, 'Heavy');
end;

procedure Test_BorderSetDashedComplete;
begin
  AssertBorderSetComplete(BorderSetDashed, 'Dashed');
end;

procedure Test_BordersAllContainsAllSides;
begin
  AssertTrue(bsTop in BordersAll, 'has top');
  AssertTrue(bsRight in BordersAll, 'has right');
  AssertTrue(bsBottom in BordersAll, 'has bottom');
  AssertTrue(bsLeft in BordersAll, 'has left');
end;

procedure Test_BordersNoneIsEmpty;
begin
  AssertTrue(BordersNone = [], 'none is empty');
end;

procedure RegisterBordersTests;
begin
  RegisterTest('borders / plain glyphs 3 bytes',    @Test_PlainGlyphs3Bytes);
  RegisterTest('borders / connector glyphs 3 bytes',@Test_ConnectorGlyphs3Bytes);
  RegisterTest('borders / double glyphs 3 bytes',   @Test_DoubleGlyphs3Bytes);
  RegisterTest('borders / heavy glyphs 3 bytes',    @Test_HeavyGlyphs3Bytes);
  RegisterTest('borders / glyph display width',     @Test_GlyphDisplayWidth);
  RegisterTest('borders / set plain complete',      @Test_BorderSetPlainComplete);
  RegisterTest('borders / set rounded complete',    @Test_BorderSetRoundedComplete);
  RegisterTest('borders / set double complete',     @Test_BorderSetDoubleComplete);
  RegisterTest('borders / set heavy complete',      @Test_BorderSetHeavyComplete);
  RegisterTest('borders / set dashed complete',     @Test_BorderSetDashedComplete);
  RegisterTest('borders / BordersAll has all',      @Test_BordersAllContainsAllSides);
  RegisterTest('borders / BordersNone is empty',    @Test_BordersNoneIsEmpty);
end;

end.
