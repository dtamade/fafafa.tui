unit test_paragraph;

{$mode objfpc}{$H+}

interface

procedure RegisterParagraphTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_text,
  ftui_borders,
  ftui_block,
  ftui_paragraph;

procedure Test_LeftAlignedFitsInOneLine;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    P := TParagraph.FromString('hello');
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['hello     ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_TruncatesIfTooWideAndNoWrap;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    P := TParagraph.FromString('hello world');
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['hello']);
  finally
    Buf.Free;
  end;
end;

procedure Test_WrapTrim_BreaksAtWhitespace;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    P := TParagraph.FromString('hello big world').WithWrap(WrapTrim);
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'hello ',
      'big   ',
      'world '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_WrapTrim_HardBreaksOnLongerWord;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    P := TParagraph.FromString('elephant!').WithWrap(WrapTrim);
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'elep',
      'hant',
      '!   '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_WrapTrim_TrimsLeadingSpaceOnSecondLine;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    // 'aaa bbb' wrapped at width 5 should give ['aaa  ', 'bbb  '] —
    // the space following 'aaa' is consumed at the break, and we trim
    // any further leading whitespace on the next visual line.
    P := TParagraph.FromString('aaa bbb').WithWrap(WrapTrim);
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'aaa  ',
      'bbb  '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_AlignmentCenter;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 9, 1));
  try
    P := TParagraph.FromString('hi').WithAlignment(caCenter);
    P.Render(Buf.Area, Buf);
    // (9/2)-(2/2) = 4-1 = 3 -> 3 leading spaces.
    AssertBufferEquals(Buf, ['   hi    ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_AlignmentRight;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 9, 1));
  try
    P := TParagraph.FromString('hi').WithAlignment(caRight);
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['       hi']);
  finally
    Buf.Free;
  end;
end;

procedure Test_ScrollYSkipsLeadingLines;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
  try
    P := TParagraph.FromString('aa' + #10 + 'bb' + #10 + 'cc' + #10 + 'dd')
          .WithScrollY(2);
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'cc    ',
      'dd    '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_ParagraphInsideBlock;
var
  Buf: TBuffer;
  P: TParagraph;
const
  H = #$E2#$94#$80;
  V = #$E2#$94#$82;
  TL = #$E2#$94#$8C;
  TR = #$E2#$94#$90;
  BL = #$E2#$94#$94;
  BR = #$E2#$94#$98;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    P := TParagraph.FromString('hi')
          .WithBlock(TBlock.Default.WithBorders(BordersAll));
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + H + H + H + H + TR,
      V  + 'hi  ' + V,
      BL + H + H + H + H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_PerLineAlignmentOverridesParagraph;
var
  Buf: TBuffer;
  P: TParagraph;
  T: TText;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 9, 2));
  try
    T := TText.FromLines([
      TLine.FromString('a').WithAlignment(caRight),
      TLine.FromString('b')
    ]);
    P := TParagraph.FromText(T).WithAlignment(caCenter);
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      '        a',
      '    b    '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_StyleBgFillsArea;
var
  Buf: TBuffer;
  P: TParagraph;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    P := TParagraph.FromString('hi')
          .WithStyle(TStyle.Default.WithBg(clBlue));
    P.Render(Buf.Area, Buf);

    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clBlue, CP^.Bg), '(0,0) bg = blue');
    CP := Buf.CellAt(3, 0);
    AssertTrue(ColorEquals(clBlue, CP^.Bg), 'last cell bg = blue');
  finally
    Buf.Free;
  end;
end;

procedure RegisterParagraphTests;
begin
  RegisterTest('paragraph / left aligned fits one line',     @Test_LeftAlignedFitsInOneLine);
  RegisterTest('paragraph / truncates if too wide no wrap',  @Test_TruncatesIfTooWideAndNoWrap);
  RegisterTest('paragraph / wrap{trim} breaks at whitespace',@Test_WrapTrim_BreaksAtWhitespace);
  RegisterTest('paragraph / wrap{trim} hard-breaks long word',@Test_WrapTrim_HardBreaksOnLongerWord);
  RegisterTest('paragraph / wrap{trim} trims leading spaces',@Test_WrapTrim_TrimsLeadingSpaceOnSecondLine);
  RegisterTest('paragraph / alignment center',               @Test_AlignmentCenter);
  RegisterTest('paragraph / alignment right',                @Test_AlignmentRight);
  RegisterTest('paragraph / scrollY skips leading lines',    @Test_ScrollYSkipsLeadingLines);
  RegisterTest('paragraph / inside block',                   @Test_ParagraphInsideBlock);
  RegisterTest('paragraph / per-line alignment overrides',   @Test_PerLineAlignmentOverridesParagraph);
  RegisterTest('paragraph / style.bg fills area',            @Test_StyleBgFillsArea);
end;

end.
