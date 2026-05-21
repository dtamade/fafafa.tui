unit test_syntax;

{$mode objfpc}{$H+}

interface

procedure RegisterSyntaxTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_style,
  ftui_syntax;

procedure Test_KeywordDetection;
begin
  AssertTrue(IsPascalKeyword('begin'), 'begin is keyword');
  AssertTrue(IsPascalKeyword('Begin'), 'Begin case insensitive');
  AssertTrue(IsPascalKeyword('END'), 'END uppercase');
  AssertTrue(not IsPascalKeyword('hello'), 'hello not keyword');
  AssertTrue(not IsPascalKeyword(''), 'empty not keyword');
end;

procedure Test_TokenizeSimple;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('begin end');
  AssertTrue(Length(Tokens) >= 3, 'at least 3 tokens');
  AssertTrue(Tokens[0].Kind = tkKeyword, 'begin is keyword');
  AssertTrue(Tokens[2].Kind = tkKeyword, 'end is keyword');
end;

procedure Test_TokenizeString;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('x := ''hello''');
  AssertTrue(Length(Tokens) >= 3, 'tokens present');
  AssertTrue(Tokens[Length(Tokens) - 1].Kind = tkString, 'string token');
end;

procedure Test_TokenizeComment;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('x := 1; // comment');
  AssertTrue(Tokens[Length(Tokens) - 1].Kind = tkComment, 'line comment');
end;

procedure Test_TokenizeBraceComment;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('{this is a comment}');
  AssertEqInt(1, Length(Tokens), 'single comment token');
  AssertTrue(Tokens[0].Kind = tkComment, 'brace comment');
end;

procedure Test_TokenizeDirective;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('{$mode objfpc}');
  AssertEqInt(1, Length(Tokens), 'single directive token');
  AssertTrue(Tokens[0].Kind = tkDirective, 'directive');
end;

procedure Test_TokenizeNumber;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('x := 42');
  AssertTrue(Tokens[Length(Tokens) - 1].Kind = tkNumber, 'number token');
end;

procedure Test_TokenizeHexNumber;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('$FF');
  AssertTrue(Tokens[0].Kind = tkNumber, 'hex number');
end;

procedure Test_TokenizeSymbols;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal(':=');
  AssertTrue(Tokens[0].Kind = tkSymbol, 'colon symbol');
  AssertTrue(Tokens[1].Kind = tkSymbol, 'equals symbol');
end;

procedure Test_SyntaxThemeDefault;
var T: TSyntaxTheme;
begin
  T := TSyntaxTheme.Default;
  AssertTrue(T.StyleFor(tkKeyword).Fg.Kind <> T.StyleFor(tkNormal).Fg.Kind,
    'keyword differs from normal');
end;

procedure Test_SyntaxThemeNord;
var T: TSyntaxTheme;
begin
  T := TSyntaxTheme.Nord;
  AssertTrue(T.Keyword.Fg.R <> T.Comment.Fg.R,
    'nord keyword differs from comment');
end;

procedure Test_EmptyLine;
var Tokens: TTokenArray;
begin
  Tokens := TokenizePascal('');
  AssertEqInt(0, Length(Tokens), 'no tokens for empty');
end;

procedure RegisterSyntaxTests;
begin
  RegisterTest('syntax / keyword detection',   @Test_KeywordDetection);
  RegisterTest('syntax / tokenize simple',     @Test_TokenizeSimple);
  RegisterTest('syntax / tokenize string',     @Test_TokenizeString);
  RegisterTest('syntax / tokenize comment',    @Test_TokenizeComment);
  RegisterTest('syntax / tokenize brace',      @Test_TokenizeBraceComment);
  RegisterTest('syntax / tokenize directive',  @Test_TokenizeDirective);
  RegisterTest('syntax / tokenize number',     @Test_TokenizeNumber);
  RegisterTest('syntax / tokenize hex',        @Test_TokenizeHexNumber);
  RegisterTest('syntax / tokenize symbols',    @Test_TokenizeSymbols);
  RegisterTest('syntax / theme default',       @Test_SyntaxThemeDefault);
  RegisterTest('syntax / theme nord',          @Test_SyntaxThemeNord);
  RegisterTest('syntax / empty line',          @Test_EmptyLine);
end;

end.
