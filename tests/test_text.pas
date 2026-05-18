unit test_text;

{$mode objfpc}{$H+}

interface

procedure RegisterTextTests;

implementation

uses
  ftui_testkit,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_text;

procedure Test_SpanRawAndStyled;
var
  S: TSpan;
begin
  S := TSpan.Raw('hello');
  AssertEqStr('hello', S.Content, 'raw content');
  AssertEqInt(5, S.Width, 'width = byte length');
  AssertEqInt(Ord(ckUnset), Ord(S.Style.Fg.Kind), 'raw uses default style');

  S := TSpan.Styled('hi', TStyle.Default.WithFg(clRed));
  AssertEqStr('hi', S.Content, 'styled content');
  AssertTrue(ColorEquals(clRed, S.Style.Fg), 'styled fg = red');
end;

procedure Test_SpanWithStyle;
var
  S: TSpan;
begin
  S := TSpan.Raw('x').WithStyle(TStyle.Default.WithModifier([mbBold]));
  AssertTrue(mbBold in S.Style.AddMod, 'WithStyle replaces style');
  AssertEqStr('x', S.Content, 'content preserved');
end;

procedure Test_LineFromStringHasOneSpan;
var
  L: TLine;
begin
  L := TLine.FromString('abc');
  AssertEqInt(1, Length(L.Spans), 'one span');
  AssertEqStr('abc', L.Spans[0].Content, 'span content');
  AssertEqInt(3, L.Width, 'line width');
  AssertFalse(L.HasAlignment, 'no alignment');
end;

procedure Test_LineFromSpansSumsWidth;
var
  L: TLine;
begin
  L := TLine.FromSpans([TSpan.Raw('ab'), TSpan.Raw('cd'), TSpan.Raw('ef')]);
  AssertEqInt(3, Length(L.Spans), 'three spans');
  AssertEqInt(6, L.Width, '2+2+2');
end;

procedure Test_LineWithStyleAndAlignment;
var
  L: TLine;
begin
  L := TLine.FromString('hi')
        .WithStyle(TStyle.Default.WithFg(clCyan))
        .WithAlignment(caCenter);
  AssertTrue(ColorEquals(clCyan, L.Style.Fg), 'fg cyan');
  AssertTrue(L.HasAlignment, 'alignment set');
  AssertEqInt(Ord(caCenter), Ord(L.Alignment), 'caCenter');
end;

procedure Test_TextEmpty;
var
  T: TText;
begin
  T := TText.Empty;
  AssertEqInt(0, T.Height, 'empty height');
  AssertEqInt(0, T.Width,  'empty width');
end;

procedure Test_TextFromSingleLine;
var
  T: TText;
begin
  T := TText.FromString('hello');
  AssertEqInt(1, T.Height, 'one line');
  AssertEqInt(5, T.Width,  'width = 5');
  AssertEqStr('hello', T.Lines[0].Spans[0].Content, 'content');
end;

procedure Test_TextSplitsOnLF;
var
  T: TText;
begin
  T := TText.FromString('aa' + #10 + 'bbbb' + #10 + 'ccc');
  AssertEqInt(3, T.Height, '3 lines');
  AssertEqInt(4, T.Width,  'max width = 4');
  AssertEqStr('aa',   T.Lines[0].Spans[0].Content, 'l0');
  AssertEqStr('bbbb', T.Lines[1].Spans[0].Content, 'l1');
  AssertEqStr('ccc',  T.Lines[2].Spans[0].Content, 'l2');
end;

procedure Test_TextHandlesCRLFAndTrailingLF;
var
  T: TText;
begin
  T := TText.FromString('first' + #13#10 + 'second' + #10);
  AssertEqInt(3, T.Height, 'CRLF + trailing LF -> 3 lines (last empty)');
  AssertEqStr('first',  T.Lines[0].Spans[0].Content, 'crlf trims CR');
  AssertEqStr('second', T.Lines[1].Spans[0].Content, 'second line');
  AssertEqStr('',       T.Lines[2].Spans[0].Content, 'trailing empty');
end;

procedure Test_TextFromLines;
var
  T: TText;
begin
  T := TText.FromLines([
    TLine.FromString('alpha'),
    TLine.FromString('beta')
  ]);
  AssertEqInt(2, T.Height, 'two lines');
  AssertEqInt(5, T.Width,  'max width');
end;

procedure Test_TextStyleAndAlignment;
var
  T: TText;
begin
  T := TText.FromString('center me')
        .WithStyle(TStyle.Default.WithModifier([mbBold]))
        .WithAlignment(caCenter);
  AssertTrue(mbBold in T.Style.AddMod, 'bold');
  AssertTrue(T.HasAlignment, 'alignment set');
  AssertEqInt(Ord(caCenter), Ord(T.Alignment), 'caCenter');
end;

procedure RegisterTextTests;
begin
  RegisterTest('text / Span Raw + Styled',           @Test_SpanRawAndStyled);
  RegisterTest('text / Span WithStyle',              @Test_SpanWithStyle);
  RegisterTest('text / Line.FromString single span', @Test_LineFromStringHasOneSpan);
  RegisterTest('text / Line.FromSpans sums width',   @Test_LineFromSpansSumsWidth);
  RegisterTest('text / Line WithStyle + Alignment',  @Test_LineWithStyleAndAlignment);
  RegisterTest('text / Text.Empty',                  @Test_TextEmpty);
  RegisterTest('text / Text from single line',      @Test_TextFromSingleLine);
  RegisterTest('text / Text splits on LF',           @Test_TextSplitsOnLF);
  RegisterTest('text / Text handles CRLF + trailing LF', @Test_TextHandlesCRLFAndTrailingLF);
  RegisterTest('text / Text from lines',             @Test_TextFromLines);
  RegisterTest('text / Text style + alignment',      @Test_TextStyleAndAlignment);
end;

end.
