unit test_block;

{$mode objfpc}{$H+}

interface

procedure RegisterBlockTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_borders,
  ftui_block;

const
  H = #$E2#$94#$80;   // ─
  V = #$E2#$94#$82;   // │
  TL = #$E2#$94#$8C;  // ┌
  TR = #$E2#$94#$90;  // ┐
  BL = #$E2#$94#$94;  // └
  BR = #$E2#$94#$98;  // ┘

procedure Test_NoBordersNoTitleIsBlank;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    B := TBlock.Default;
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['    ', '    ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_AllBordersDrawsRectangle;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll);
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + H + H + TR,
      V  + ' ' + ' ' + V,
      BL + H + H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_PartialBordersBottomOnly;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    B := TBlock.Default.WithBorders([bsBottom]);
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      '    ',
      '    ',
      H + H + H + H
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_PartialBordersTopAndLeft;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    // No corner glyphs because top+left only triggers ONE corner.
    B := TBlock.Default.WithBorders([bsTop, bsLeft]);
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + H + H + H,
      V  + '   ',
      V  + '   '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_TitleOnTopBorder;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('Hi');
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + 'Hi' + H + H + H + H + H + H + TR,
      V  + '        ' + V,
      BL + H + H + H + H + H + H + H + H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_TitleClippedAtRightBorder;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('TooLongTitle');
    B.Render(Buf.Area, Buf);
    // Inner width is 6 - 2 = 4, so 'TooL' fits and the rest is clipped.
    AssertBufferEquals(Buf, [
      TL + 'TooL' + TR,
      V  + '    ' + V,
      BL + H + H + H + H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_TitleWithoutLeftBorder;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
  try
    B := TBlock.Default.WithBorders([bsTop]).WithTitle('Hi');
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'Hi' + H + H + H + H,
      '      '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_InnerSubtractsBorders;
var
  B: TBlock;
  R: TRect;
begin
  B := TBlock.Default.WithBorders(BordersAll);
  R := B.Inner(TRect.Make(2, 3, 10, 5));
  AssertEqInt(3,  R.X, 'inner.X = Area.X + 1');
  AssertEqInt(4,  R.Y, 'inner.Y');
  AssertEqInt(8,  R.Width,  'inner.Width = 10 - 2');
  AssertEqInt(3,  R.Height, 'inner.Height = 5 - 2');

  B := TBlock.Default.WithBorders([bsTop, bsBottom]);
  R := B.Inner(TRect.Make(0, 0, 5, 5));
  AssertEqInt(0, R.X, 'no left border -> X unchanged');
  AssertEqInt(1, R.Y, 'top border -> Y+1');
  AssertEqInt(5, R.Width, 'no horiz borders -> width unchanged');
  AssertEqInt(3, R.Height, 'top+bottom -> height-2');

  B := TBlock.Default;
  R := B.Inner(TRect.Make(2, 2, 4, 4));
  AssertTrue(RectEquals(R, TRect.Make(2, 2, 4, 4)),
    'no borders, no title -> Area unchanged');
end;

procedure Test_InnerWithTitleNoTopBorder;
var
  B: TBlock;
  R: TRect;
begin
  B := TBlock.Default.WithTitle('hi');
  R := B.Inner(TRect.Make(0, 0, 5, 5));
  AssertEqInt(1, R.Y, 'title forces +1 vertical shrink');
  AssertEqInt(4, R.Height, '5-1 from title');
end;

procedure Test_InnerSaturatesOnTinyArea;
var
  B: TBlock;
  R: TRect;
begin
  B := TBlock.Default.WithBorders(BordersAll);
  R := B.Inner(TRect.Make(0, 0, 1, 1));
  AssertEqInt(0, R.Width,  'tiny area -> 0 width inner');
  AssertEqInt(0, R.Height, 'tiny area -> 0 height inner');
end;

procedure Test_BlockStyleAppliesBeforeBorders;
var
  Buf: TBuffer;
  B: TBlock;
  P: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 3));
  try
    B := TBlock.Default
          .WithBorders(BordersAll)
          .WithStyle(TStyle.Default.WithBg(clBlue))
          .WithBorderStyle(TStyle.Default.WithFg(clRed));
    B.Render(Buf.Area, Buf);

    // Center cell has block style (bg=blue, no fg).
    P := Buf.CellAt(1, 1);
    AssertTrue(ColorEquals(clBlue, P^.Bg), 'center.bg = blue');
    AssertEqInt(Ord(ckReset), Ord(P^.Fg.Kind), 'center.fg untouched');

    // Border cell has both styles patched on (bg=blue from area, fg=red from border).
    P := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clBlue, P^.Bg), 'corner.bg = blue (from area style)');
    AssertTrue(ColorEquals(clRed,  P^.Fg), 'corner.fg = red (from border style)');
  finally
    Buf.Free;
  end;
end;

procedure RegisterBlockTests;
begin
  RegisterTest('block / no borders no title is blank',     @Test_NoBordersNoTitleIsBlank);
  RegisterTest('block / Borders::ALL draws rectangle',     @Test_AllBordersDrawsRectangle);
  RegisterTest('block / partial borders bottom only',      @Test_PartialBordersBottomOnly);
  RegisterTest('block / partial borders top+left',         @Test_PartialBordersTopAndLeft);
  RegisterTest('block / title on top border',              @Test_TitleOnTopBorder);
  RegisterTest('block / title clipped at right border',    @Test_TitleClippedAtRightBorder);
  RegisterTest('block / title without left border',        @Test_TitleWithoutLeftBorder);
  RegisterTest('block / Inner subtracts borders',          @Test_InnerSubtractsBorders);
  RegisterTest('block / Inner with title no top border',   @Test_InnerWithTitleNoTopBorder);
  RegisterTest('block / Inner saturates on tiny area',     @Test_InnerSaturatesOnTinyArea);
  RegisterTest('block / style + borderStyle layering',     @Test_BlockStyleAppliesBeforeBorders);
end;

end.
