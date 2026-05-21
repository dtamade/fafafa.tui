unit ftui_syntax;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_style,
  ftui_color,
  ftui_modifier;

type
  TTokenKind = (tkNormal, tkKeyword, tkString, tkComment, tkNumber, tkDirective, tkSymbol);

  TToken = record
    Start: Integer;
    Len: Integer;
    Kind: TTokenKind;
  end;

  TTokenArray = array of TToken;

  TSyntaxTheme = record
    Normal: TStyle;
    Keyword: TStyle;
    Str: TStyle;
    Comment: TStyle;
    Number: TStyle;
    Directive: TStyle;
    Symbol: TStyle;

    class function Default: TSyntaxTheme; static;
    class function Nord: TSyntaxTheme; static;
    function StyleFor(Kind: TTokenKind): TStyle;
  end;

function TokenizePascal(const Line: AnsiString): TTokenArray;
function IsPascalKeyword(const W: AnsiString): Boolean;

implementation

uses
  SysUtils;

const
  PascalKeywords: array[0..61] of AnsiString = (
    'and', 'array', 'as', 'asm', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'div', 'do', 'downto', 'else', 'end',
    'except', 'exports', 'file', 'finalization', 'finally', 'for',
    'function', 'goto', 'if', 'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library',
    'mod', 'nil', 'not', 'object', 'of', 'operator', 'or', 'packed',
    'procedure', 'program', 'property', 'raise', 'record', 'repeat',
    'result', 'set', 'shl', 'shr', 'then', 'to', 'try', 'type',
    'unit', 'until', 'uses', 'var', 'while', 'with', 'xor'
  );

function IsPascalKeyword(const W: AnsiString): Boolean;
var
  Lo: AnsiString;
  I: Integer;
begin
  Lo := LowerCase(W);
  for I := Low(PascalKeywords) to High(PascalKeywords) do
    if PascalKeywords[I] = Lo then Exit(True);
  Result := False;
end;

function IsAlpha(C: Char): Boolean; inline;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '_']);
end;

function IsAlNum(C: Char): Boolean; inline;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsDigit(C: Char): Boolean; inline;
begin
  Result := C in ['0'..'9'];
end;

function TokenizePascal(const Line: AnsiString): TTokenArray;
var
  Tokens: array of TToken;
  Count, I, Start, Len: Integer;
  Word: AnsiString;

  procedure AddToken(AStart, ALen: Integer; AKind: TTokenKind);
  begin
    Inc(Count);
    SetLength(Tokens, Count);
    Tokens[Count - 1].Start := AStart;
    Tokens[Count - 1].Len := ALen;
    Tokens[Count - 1].Kind := AKind;
  end;

begin
  Count := 0;
  Tokens := nil;
  Len := Length(Line);
  I := 1;

  while I <= Len do
  begin
    // Whitespace
    if Line[I] = ' ' then
    begin
      Start := I;
      while (I <= Len) and (Line[I] = ' ') do Inc(I);
      AddToken(Start, I - Start, tkNormal);
    end
    // Directive {$...}
    else if (Line[I] = '{') and (I < Len) and (Line[I + 1] = '$') then
    begin
      Start := I;
      while (I <= Len) and (Line[I] <> '}') do Inc(I);
      if I <= Len then Inc(I);
      AddToken(Start, I - Start, tkDirective);
    end
    // Comment { }
    else if Line[I] = '{' then
    begin
      Start := I;
      while (I <= Len) and (Line[I] <> '}') do Inc(I);
      if I <= Len then Inc(I);
      AddToken(Start, I - Start, tkComment);
    end
    // Line comment //
    else if (Line[I] = '/') and (I < Len) and (Line[I + 1] = '/') then
    begin
      AddToken(I, Len - I + 1, tkComment);
      I := Len + 1;
    end
    // String literal
    else if Line[I] = '''' then
    begin
      Start := I;
      Inc(I);
      while I <= Len do
      begin
        if Line[I] = '''' then
        begin
          Inc(I);
          if (I <= Len) and (Line[I] = '''') then
            Inc(I)
          else
            Break;
        end
        else
          Inc(I);
      end;
      AddToken(Start, I - Start, tkString);
    end
    // Number
    else if IsDigit(Line[I]) or ((Line[I] = '$') and (I < Len) and (Line[I+1] in ['0'..'9','A'..'F','a'..'f'])) then
    begin
      Start := I;
      if Line[I] = '$' then
      begin
        Inc(I);
        while (I <= Len) and (Line[I] in ['0'..'9', 'A'..'F', 'a'..'f']) do Inc(I);
      end
      else
      begin
        while (I <= Len) and (IsDigit(Line[I]) or (Line[I] = '.')) do Inc(I);
      end;
      AddToken(Start, I - Start, tkNumber);
    end
    // Identifier or keyword
    else if IsAlpha(Line[I]) then
    begin
      Start := I;
      while (I <= Len) and IsAlNum(Line[I]) do Inc(I);
      Word := Copy(Line, Start, I - Start);
      if IsPascalKeyword(Word) then
        AddToken(Start, I - Start, tkKeyword)
      else
        AddToken(Start, I - Start, tkNormal);
    end
    // Symbol
    else
    begin
      AddToken(I, 1, tkSymbol);
      Inc(I);
    end;
  end;

  Result := Tokens;
end;

{ TSyntaxTheme }

class function TSyntaxTheme.Default: TSyntaxTheme;
begin
  Result.Normal := TStyle.Default;
  Result.Keyword := TStyle.Default.WithFg(clYellow).WithModifier([mbBold]);
  Result.Str := TStyle.Default.WithFg(clGreen);
  Result.Comment := TStyle.Default.WithFg(clDarkGray);
  Result.Number := TStyle.Default.WithFg(clCyan);
  Result.Directive := TStyle.Default.WithFg(clMagenta);
  Result.Symbol := TStyle.Default.WithFg(clWhite);
end;

class function TSyntaxTheme.Nord: TSyntaxTheme;
begin
  Result.Normal := TStyle.Default.WithFg(RgbColor(216, 222, 233));
  Result.Keyword := TStyle.Default.WithFg(RgbColor(129, 161, 193)).WithModifier([mbBold]);
  Result.Str := TStyle.Default.WithFg(RgbColor(163, 190, 140));
  Result.Comment := TStyle.Default.WithFg(RgbColor(76, 86, 106));
  Result.Number := TStyle.Default.WithFg(RgbColor(180, 142, 173));
  Result.Directive := TStyle.Default.WithFg(RgbColor(235, 203, 139));
  Result.Symbol := TStyle.Default.WithFg(RgbColor(236, 239, 244));
end;

function TSyntaxTheme.StyleFor(Kind: TTokenKind): TStyle;
begin
  case Kind of
    tkKeyword: Result := Keyword;
    tkString: Result := Str;
    tkComment: Result := Comment;
    tkNumber: Result := Number;
    tkDirective: Result := Directive;
    tkSymbol: Result := Symbol;
  else
    Result := Normal;
  end;
end;

end.
