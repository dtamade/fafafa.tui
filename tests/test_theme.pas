unit test_theme;

{$mode objfpc}{$H+}

interface

procedure RegisterThemeTests;

implementation

uses
  ftui_testkit,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_theme;

procedure Test_DarkThemeBgColor;
var
  T: TTheme;
begin
  T := TTheme.Dark;
  AssertTrue(ColorEquals(clBlack, T.Bg.Bg), 'Dark.Bg has black background');
end;

procedure Test_LightThemeFgColor;
var
  T: TTheme;
begin
  T := TTheme.Light;
  AssertTrue(ColorEquals(clBlack, T.Fg.Fg), 'Light.Fg has black foreground');
end;

procedure Test_NordUsesRgbColors;
var
  T: TTheme;
begin
  T := TTheme.Nord;
  AssertEqInt(Ord(ckRgb), Ord(T.Bg.Bg.Kind), 'Nord.Bg uses RGB');
  AssertEqInt(46, T.Bg.Bg.R, 'Nord.Bg.R');
  AssertEqInt(52, T.Bg.Bg.G, 'Nord.Bg.G');
  AssertEqInt(64, T.Bg.Bg.B, 'Nord.Bg.B');
end;

procedure Test_DraculaUsesRgbColors;
var
  T: TTheme;
begin
  T := TTheme.Dracula;
  AssertEqInt(Ord(ckRgb), Ord(T.Bg.Bg.Kind), 'Dracula.Bg uses RGB');
  AssertEqInt(40, T.Bg.Bg.R, 'Dracula.Bg.R');
  AssertEqInt(42, T.Bg.Bg.G, 'Dracula.Bg.G');
  AssertEqInt(54, T.Bg.Bg.B, 'Dracula.Bg.B');
end;

procedure Test_AllThemesHaveNonDefaultHighlight;
var
  D, L, N, Dr: TTheme;
  Def: TStyle;
begin
  D := TTheme.Dark;
  L := TTheme.Light;
  N := TTheme.Nord;
  Dr := TTheme.Dracula;
  Def := TStyle.Default;
  AssertFalse(StyleEquals(Def, D.Highlight), 'Dark.Highlight not default');
  AssertFalse(StyleEquals(Def, L.Highlight), 'Light.Highlight not default');
  AssertFalse(StyleEquals(Def, N.Highlight), 'Nord.Highlight not default');
  AssertFalse(StyleEquals(Def, Dr.Highlight), 'Dracula.Highlight not default');
end;

procedure Test_AllThemesDistinctPrimarySecondary;
var
  D, L, N, Dr: TTheme;
begin
  D := TTheme.Dark;
  L := TTheme.Light;
  N := TTheme.Nord;
  Dr := TTheme.Dracula;
  AssertFalse(StyleEquals(D.Primary, D.Secondary), 'Dark Primary <> Secondary');
  AssertFalse(StyleEquals(L.Primary, L.Secondary), 'Light Primary <> Secondary');
  AssertFalse(StyleEquals(N.Primary, N.Secondary), 'Nord Primary <> Secondary');
  AssertFalse(StyleEquals(Dr.Primary, Dr.Secondary), 'Dracula Primary <> Secondary');
end;

procedure Test_ThemeStyleCanBePatched;
var
  T: TTheme;
  Base, Result_: TStyle;
begin
  T := TTheme.Dark;
  Base := TStyle.Default.WithFg(clWhite);
  Result_ := Base.Patch(T.Error_);
  AssertTrue(ColorEquals(clRed, Result_.Fg), 'Patched style has error fg');
end;

procedure Test_BorderVsBorderFocusedDifferent;
var
  D, L, N, Dr: TTheme;
begin
  D := TTheme.Dark;
  L := TTheme.Light;
  N := TTheme.Nord;
  Dr := TTheme.Dracula;
  AssertFalse(StyleEquals(D.Border, D.BorderFocused), 'Dark Border <> BorderFocused');
  AssertFalse(StyleEquals(L.Border, L.BorderFocused), 'Light Border <> BorderFocused');
  AssertFalse(StyleEquals(N.Border, N.BorderFocused), 'Nord Border <> BorderFocused');
  AssertFalse(StyleEquals(Dr.Border, Dr.BorderFocused), 'Dracula Border <> BorderFocused');
end;

procedure Test_DarkThemeSuccessIsGreen;
var
  T: TTheme;
begin
  T := TTheme.Dark;
  AssertTrue(ColorEquals(clGreen, T.Success.Fg), 'Dark.Success.Fg is green');
end;

procedure Test_DraculaErrorColor;
var
  T: TTheme;
begin
  T := TTheme.Dracula;
  AssertEqInt(Ord(ckRgb), Ord(T.Error_.Fg.Kind), 'Dracula.Error uses RGB');
  AssertEqInt(255, T.Error_.Fg.R, 'Dracula.Error.R = 255');
  AssertEqInt(85, T.Error_.Fg.G, 'Dracula.Error.G = 85');
  AssertEqInt(85, T.Error_.Fg.B, 'Dracula.Error.B = 85');
end;

procedure RegisterThemeTests;
begin
  RegisterTest('theme / Dark bg color',                    @Test_DarkThemeBgColor);
  RegisterTest('theme / Light fg color',                   @Test_LightThemeFgColor);
  RegisterTest('theme / Nord uses RGB colors',             @Test_NordUsesRgbColors);
  RegisterTest('theme / Dracula uses RGB colors',          @Test_DraculaUsesRgbColors);
  RegisterTest('theme / all themes non-default Highlight', @Test_AllThemesHaveNonDefaultHighlight);
  RegisterTest('theme / distinct Primary vs Secondary',    @Test_AllThemesDistinctPrimarySecondary);
  RegisterTest('theme / style can be patched',             @Test_ThemeStyleCanBePatched);
  RegisterTest('theme / Border vs BorderFocused differ',   @Test_BorderVsBorderFocusedDifferent);
  RegisterTest('theme / Dark success is green',            @Test_DarkThemeSuccessIsGreen);
  RegisterTest('theme / Dracula error color',              @Test_DraculaErrorColor);
end;

end.
