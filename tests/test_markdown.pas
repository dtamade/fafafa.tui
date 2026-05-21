unit test_markdown;

{$mode objfpc}{$H+}

interface

procedure RegisterMarkdownTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_markdown;

procedure Test_ParseH1;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('# Hello');
  AssertEqInt(1, Length(Lines), '1 line');
  AssertTrue(Lines[0].Kind = mlH1, 'H1');
  AssertEqStr('Hello', Lines[0].Text, 'text');
end;

procedure Test_ParseH2H3;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('## Sub' + #10 + '### Sub2');
  AssertTrue(Lines[0].Kind = mlH2, 'H2');
  AssertTrue(Lines[1].Kind = mlH3, 'H3');
end;

procedure Test_ParseBullet;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('- item1' + #10 + '* item2');
  AssertTrue(Lines[0].Kind = mlBullet, 'dash bullet');
  AssertTrue(Lines[1].Kind = mlBullet, 'star bullet');
  AssertEqStr('item1', Lines[0].Text, 'text1');
end;

procedure Test_ParseCodeBlock;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('```' + #10 + 'code here' + #10 + '```');
  AssertEqInt(1, Length(Lines), '1 code line');
  AssertTrue(Lines[0].Kind = mlCodeBlock, 'code block');
  AssertEqStr('code here', Lines[0].Text, 'code text');
end;

procedure Test_ParseHRule;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('---');
  AssertEqInt(1, Length(Lines), '1 line');
  AssertTrue(Lines[0].Kind = mlHRule, 'hrule');
end;

procedure Test_ParseNormal;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('just text');
  AssertTrue(Lines[0].Kind = mlNormal, 'normal');
  AssertEqStr('just text', Lines[0].Text, 'text');
end;

procedure Test_ParseMultiline;
var Lines: TMdLineArray;
begin
  Lines := ParseMarkdownLines('# Title' + #10 + '' + #10 + 'Body text' + #10 + '- item');
  AssertTrue(Length(Lines) >= 3, 'multiple lines');
  AssertTrue(Lines[0].Kind = mlH1, 'first is H1');
end;

procedure Test_RenderShowsContent;
var
  MD: TMarkdown;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 5);
  Buf := TBuffer.CreateEmpty(Area);
  MD := TMarkdown.Create('# Hello' + #10 + 'World');
  MD.Render(Area, Buf);
  AssertTrue(Pos('Hello', Buf.RowAsString(0)) > 0, 'H1 visible');
  AssertTrue(Pos('World', Buf.RowAsString(1)) > 0, 'body visible');
  Buf.Free;
end;

procedure Test_RenderBullets;
var
  MD: TMarkdown;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 3);
  Buf := TBuffer.CreateEmpty(Area);
  MD := TMarkdown.Create('- first' + #10 + '- second');
  MD.Render(Area, Buf);
  AssertTrue(Pos('first', Buf.RowAsString(0)) > 0, 'bullet 1');
  AssertTrue(Pos('second', Buf.RowAsString(1)) > 0, 'bullet 2');
  Buf.Free;
end;

procedure Test_EmptySource;
var
  MD: TMarkdown;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 5);
  Buf := TBuffer.CreateEmpty(Area);
  MD := TMarkdown.Create('');
  MD.Render(Area, Buf);
  AssertTrue(True, 'no crash on empty');
  Buf.Free;
end;

procedure RegisterMarkdownTests;
begin
  RegisterTest('markdown / parse H1',          @Test_ParseH1);
  RegisterTest('markdown / parse H2 H3',       @Test_ParseH2H3);
  RegisterTest('markdown / parse bullet',      @Test_ParseBullet);
  RegisterTest('markdown / parse code block',  @Test_ParseCodeBlock);
  RegisterTest('markdown / parse hrule',       @Test_ParseHRule);
  RegisterTest('markdown / parse normal',      @Test_ParseNormal);
  RegisterTest('markdown / parse multiline',   @Test_ParseMultiline);
  RegisterTest('markdown / render content',    @Test_RenderShowsContent);
  RegisterTest('markdown / render bullets',    @Test_RenderBullets);
  RegisterTest('markdown / empty source',      @Test_EmptySource);
end;

end.
