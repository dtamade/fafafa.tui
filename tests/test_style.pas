unit test_style;

{$mode objfpc}{$H+}

interface

procedure RegisterStyleTests;

implementation

uses
  ftui_testkit,
  ftui_color,
  ftui_modifier,
  ftui_style;

procedure Test_DefaultIsAllUnsetEmpty;
var
  S: TStyle;
begin
  S := TStyle.Default;
  AssertEqInt(Ord(ckUnset), Ord(S.Fg.Kind),     'default Fg unset');
  AssertEqInt(Ord(ckUnset), Ord(S.Bg.Kind),     'default Bg unset');
  AssertEqInt(Ord(ckUnset), Ord(S.Ul.Kind),     'default Ul unset');
  AssertTrue(ModifierIsEmpty(S.AddMod),         'default AddMod empty');
  AssertTrue(ModifierIsEmpty(S.SubMod),         'default SubMod empty');
end;

procedure Test_StyleDefaultHelperMatchesClassMethod;
begin
  AssertTrue(StyleEquals(StyleDefault, TStyle.Default), 'helper = class method');
end;

procedure Test_WithFgBgUnderlineAreImmutable;
var
  Base, S: TStyle;
begin
  Base := TStyle.Default;
  S := Base.WithFg(clRed);
  AssertTrue(ColorEquals(clRed, S.Fg),                'WithFg sets Fg');
  AssertEqInt(Ord(ckUnset), Ord(Base.Fg.Kind),        'Base unchanged after WithFg');

  S := Base.WithBg(RgbColor(10, 20, 30));
  AssertTrue(ColorEquals(RgbColor(10, 20, 30), S.Bg), 'WithBg sets Bg');
  AssertEqInt(Ord(ckUnset), Ord(Base.Bg.Kind),        'Base.Bg unchanged');

  S := Base.WithUnderline(clCyan);
  AssertTrue(ColorEquals(clCyan, S.Ul),               'WithUnderline sets Ul');
end;

procedure Test_BuilderChaining;
var
  S: TStyle;
begin
  S := TStyle.Default
        .WithFg(clRed)
        .WithBg(clBlack)
        .WithUnderline(clCyan)
        .WithModifier([mbBold, mbItalic]);
  AssertTrue(ColorEquals(clRed,   S.Fg),  'chain: Fg');
  AssertTrue(ColorEquals(clBlack, S.Bg),  'chain: Bg');
  AssertTrue(ColorEquals(clCyan,  S.Ul),  'chain: Ul');
  AssertTrue(mbBold   in S.AddMod,        'chain: bold added');
  AssertTrue(mbItalic in S.AddMod,        'chain: italic added');
end;

procedure Test_WithModifierMovesBitFromSubToAdd;
var
  S: TStyle;
begin
  S := TStyle.Default.WithoutModifier([mbBold]);
  AssertTrue (mbBold in S.SubMod,  'after Without: bold in SubMod');
  AssertFalse(mbBold in S.AddMod,  'after Without: bold not in AddMod');

  S := S.WithModifier([mbBold]);
  AssertTrue (mbBold in S.AddMod,  'after Without then With: bold in AddMod');
  AssertFalse(mbBold in S.SubMod,  'after Without then With: bold removed from SubMod');
end;

procedure Test_WithoutModifierMovesBitFromAddToSub;
var
  S: TStyle;
begin
  S := TStyle.Default.WithModifier([mbBold]);
  AssertTrue (mbBold in S.AddMod,  'after With: bold in AddMod');
  AssertFalse(mbBold in S.SubMod,  'after With: bold not in SubMod');

  S := S.WithoutModifier([mbBold]);
  AssertFalse(mbBold in S.AddMod,  'after With then Without: bold removed from AddMod');
  AssertTrue (mbBold in S.SubMod,  'after With then Without: bold in SubMod');
end;

procedure Test_PatchColorOrSemantics;
var
  Base, P, R: TStyle;
begin
  // Other.X set -> Other wins.
  Base := TStyle.Default.WithFg(clRed).WithBg(clGreen);
  P    := TStyle.Default.WithFg(clBlue);
  R    := Base.Patch(P);
  AssertTrue(ColorEquals(clBlue,  R.Fg), 'patch Fg taken from Other when set');
  AssertTrue(ColorEquals(clGreen, R.Bg), 'patch Bg kept from Self when Other.Bg is unset');

  // Underline follows the same pattern.
  Base := TStyle.Default.WithUnderline(clYellow);
  P    := TStyle.Default;          // unset Ul -> keep self
  R    := Base.Patch(P);
  AssertTrue(ColorEquals(clYellow, R.Ul), 'patch Ul kept when Other.Ul unset');

  P := TStyle.Default.WithUnderline(clCyan);
  R := Base.Patch(P);
  AssertTrue(ColorEquals(clCyan, R.Ul),   'patch Ul replaced when Other.Ul set');
end;

procedure Test_PatchModifierBitDisjointInvariant;
var
  Base, P, R: TStyle;
begin
  // ratatui semantics:
  //   AddMod := (self.AddMod - other.SubMod) + other.AddMod
  //   SubMod := (self.SubMod - other.AddMod) + other.SubMod
  Base := TStyle.Default
            .WithModifier([mbBold, mbItalic])     // Add: {bold, italic}
            .WithoutModifier([mbDim]);             // Sub: {dim}

  P := TStyle.Default
            .WithoutModifier([mbBold])             // Other.Sub: {bold}
            .WithModifier([mbDim, mbReversed]);    // Other.Add: {dim, reversed}

  R := Base.Patch(P);

  // bold: was in self.Add, removed by other.Sub
  AssertFalse(mbBold in R.AddMod, 'bold cleared from AddMod (other.Sub wins)');
  AssertTrue (mbBold in R.SubMod, 'bold landed in SubMod');

  // italic: untouched in self.Add
  AssertTrue (mbItalic in R.AddMod, 'italic preserved in AddMod');
  AssertFalse(mbItalic in R.SubMod, 'italic not in SubMod');

  // dim: was in self.Sub, but other.Add overrides
  AssertTrue (mbDim in R.AddMod, 'dim moved into AddMod (other.Add wins)');
  AssertFalse(mbDim in R.SubMod, 'dim cleared from SubMod');

  // reversed: only in other.Add
  AssertTrue (mbReversed in R.AddMod, 'reversed added from Other');

  // Disjoint invariant: AddMod * SubMod = []
  AssertTrue(ModifierIsEmpty(R.AddMod * R.SubMod), 'AddMod and SubMod stay disjoint');
end;

procedure Test_PatchIdentityWithDefault;
var
  Base, R: TStyle;
begin
  Base := TStyle.Default
            .WithFg(clRed)
            .WithBg(clBlack)
            .WithModifier([mbBold]);
  R := Base.Patch(TStyle.Default);
  AssertTrue(StyleEquals(Base, R), 'patch with empty other is identity');
end;

procedure Test_StyleEqualsAndSize;
var
  A, B: TStyle;
begin
  A := TStyle.Default.WithFg(clRed);
  B := TStyle.Default.WithFg(clRed);
  AssertTrue(StyleEquals(A, B), 'same builder -> equal');

  B := B.WithModifier([mbBold]);
  AssertFalse(StyleEquals(A, B), 'modifier diff detected');

  // 3 * SizeOf(TColor)=4  +  2 * SizeOf(TModifier)=2  -> 16 bytes packed.
  AssertEqInt(16, SizeOf(TStyle), 'SizeOf(TStyle) = 16');
end;

procedure RegisterStyleTests;
begin
  RegisterTest('style / Default is all unset+empty',     @Test_DefaultIsAllUnsetEmpty);
  RegisterTest('style / StyleDefault matches class fn',  @Test_StyleDefaultHelperMatchesClassMethod);
  RegisterTest('style / WithFg/Bg/Underline immutable',  @Test_WithFgBgUnderlineAreImmutable);
  RegisterTest('style / builder chaining works',         @Test_BuilderChaining);
  RegisterTest('style / WithModifier moves Sub->Add',    @Test_WithModifierMovesBitFromSubToAdd);
  RegisterTest('style / WithoutModifier moves Add->Sub', @Test_WithoutModifierMovesBitFromAddToSub);
  RegisterTest('style / Patch color or-semantics',       @Test_PatchColorOrSemantics);
  RegisterTest('style / Patch modifier disjoint invariant', @Test_PatchModifierBitDisjointInvariant);
  RegisterTest('style / Patch with default is identity', @Test_PatchIdentityWithDefault);
  RegisterTest('style / StyleEquals + SizeOf=16',        @Test_StyleEqualsAndSize);
end;

end.
