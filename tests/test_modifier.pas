unit test_modifier;

{$mode objfpc}{$H+}

interface

procedure RegisterModifierTests;

implementation

uses
  ftui_testkit,
  ftui_modifier;

procedure Test_DefaultIsEmpty;
var
  M: TModifier;
begin
  M := [];
  AssertTrue(ModifierIsEmpty(M), 'empty literal is empty');
  AssertTrue(ModifierEquals(M, ModifierNone), '[] = ModifierNone');
end;

procedure Test_SingletonContains;
var
  M: TModifier;
begin
  M := [mbBold];
  AssertTrue(mbBold in M, 'bold in {bold}');
  AssertFalse(mbDim in M, 'dim not in {bold}');
  AssertFalse(ModifierIsEmpty(M), 'singleton is not empty');
end;

procedure Test_UnionAndDifference;
var
  A, B, C: TModifier;
begin
  A := [mbBold, mbItalic];
  B := [mbItalic, mbUnderlined];

  C := A + B;
  AssertTrue(mbBold in C,        'union: bold');
  AssertTrue(mbItalic in C,      'union: italic');
  AssertTrue(mbUnderlined in C,  'union: underlined');
  AssertFalse(mbDim in C,        'union: dim absent');

  C := A - B;
  AssertTrue(mbBold in C,        'diff a-b: bold');
  AssertFalse(mbItalic in C,     'diff a-b: italic removed');
  AssertFalse(mbUnderlined in C, 'diff a-b: underlined absent');

  C := B - A;
  AssertFalse(mbBold in C,       'diff b-a: bold absent');
  AssertFalse(mbItalic in C,     'diff b-a: italic removed');
  AssertTrue(mbUnderlined in C,  'diff b-a: underlined kept');
end;

procedure Test_IntersectionAndSymmetricDiff;
var
  A, B, C: TModifier;
begin
  A := [mbBold, mbItalic, mbDim];
  B := [mbItalic, mbDim, mbReversed];

  C := A * B;
  AssertEqInt(2, Ord(mbItalic in C) + Ord(mbDim in C), 'intersect has italic+dim');
  AssertFalse(mbBold in C,     'intersect no bold');
  AssertFalse(mbReversed in C, 'intersect no reversed');

  C := A >< B;     // symmetric difference
  AssertTrue(mbBold in C,      'symdiff: bold');
  AssertTrue(mbReversed in C,  'symdiff: reversed');
  AssertFalse(mbItalic in C,   'symdiff: italic dropped');
  AssertFalse(mbDim in C,      'symdiff: dim dropped');
end;

procedure Test_AllNineBitsExpressible;
var
  M: TModifier;
begin
  M := [
    mbBold, mbDim, mbItalic, mbUnderlined,
    mbSlowBlink, mbRapidBlink, mbReversed,
    mbHidden, mbCrossedOut
  ];
  AssertTrue(mbBold in M,        'bold');
  AssertTrue(mbDim in M,         'dim');
  AssertTrue(mbItalic in M,      'italic');
  AssertTrue(mbUnderlined in M,  'underlined');
  AssertTrue(mbSlowBlink in M,   'slow blink');
  AssertTrue(mbRapidBlink in M,  'rapid blink');
  AssertTrue(mbReversed in M,    'reversed');
  AssertTrue(mbHidden in M,      'hidden');
  AssertTrue(mbCrossedOut in M,  'crossed out');
end;

procedure Test_ModifierEqualsAcrossSizes;
begin
  AssertTrue (ModifierEquals([],            []),                  'empty = empty');
  AssertTrue (ModifierEquals([mbBold],      [mbBold]),            'singleton = singleton');
  AssertTrue (ModifierEquals([mbBold, mbDim], [mbDim, mbBold]),   'order does not matter');
  AssertFalse(ModifierEquals([mbBold],      []),                  'singleton <> empty');
  AssertFalse(ModifierEquals([mbBold],      [mbDim]),             'different singletons');
end;

procedure Test_PackedSetSizeAtMost2Bytes;
begin
  // 9 elements -> FPC packs into 16 bits -> SizeOf = 2 bytes.
  // This is the property that lets TStyle stay tiny.
  AssertEqInt(2, SizeOf(TModifier), 'SizeOf(TModifier) = 2');
end;

procedure RegisterModifierTests;
begin
  RegisterTest('modifier / [] is the default',                 @Test_DefaultIsEmpty);
  RegisterTest('modifier / singleton contains',                @Test_SingletonContains);
  RegisterTest('modifier / union and difference',              @Test_UnionAndDifference);
  RegisterTest('modifier / intersect and symmetric diff',      @Test_IntersectionAndSymmetricDiff);
  RegisterTest('modifier / all 9 bits are expressible',        @Test_AllNineBitsExpressible);
  RegisterTest('modifier / equality is order-independent',     @Test_ModifierEqualsAcrossSizes);
  RegisterTest('modifier / SizeOf(TModifier) = 2 (16-bit set)',@Test_PackedSetSizeAtMost2Bytes);
end;

end.
