unit ftui_borders;

// Border-side flags + the box-drawing glyphs used by TBlock.
//
// ratatui exposes BorderType { Plain, Rounded, Double, Thick, Quadrant* }.
// fafafa.tui ships only Plain — cli888 uses BorderType in zero places,
// and shipping more here would just expand the test surface.
//
// Box-drawing characters are 3-byte UTF-8 (U+2500 range), well within
// the 23-byte inline glyph budget of TCell.  No heap allocation.

{$mode objfpc}{$H+}{$inline on}
{$packset 1}

interface

type
  TBorderSide = (bsTop, bsRight, bsBottom, bsLeft);
  TBorders = set of TBorderSide;

  // A set of 11 glyphs defining the visual appearance of a border.
  TBorderSet = record
    Horizontal: AnsiString;
    Vertical: AnsiString;
    TopLeft: AnsiString;
    TopRight: AnsiString;
    BottomLeft: AnsiString;
    BottomRight: AnsiString;
    LeftT: AnsiString;
    RightT: AnsiString;
    TopT: AnsiString;
    BottomT: AnsiString;
    Cross: AnsiString;
  end;

const
  BordersNone: TBorders = [];
  BordersAll : TBorders = [bsTop, bsRight, bsBottom, bsLeft];

  // Plain border glyphs (single-line box drawing).
  BorderHorizontal: AnsiString = #$E2#$94#$80;   // ─
  BorderVertical:   AnsiString = #$E2#$94#$82;   // │
  BorderTopLeft:    AnsiString = #$E2#$94#$8C;   // ┌
  BorderTopRight:   AnsiString = #$E2#$94#$90;   // ┐
  BorderBottomLeft: AnsiString = #$E2#$94#$94;   // └
  BorderBottomRight:AnsiString = #$E2#$94#$98;   // ┘

  // Rounded border glyphs (cli888 default for input/panels).
  BorderRoundedTL:  AnsiString = #$E2#$95#$AD;   // ╭
  BorderRoundedTR:  AnsiString = #$E2#$95#$AE;   // ╮
  BorderRoundedBL:  AnsiString = #$E2#$95#$B0;   // ╰
  BorderRoundedBR:  AnsiString = #$E2#$95#$AF;   // ╯

  // Connector glyphs for internal separators.
  BorderLeftT:      AnsiString = #$E2#$94#$9C;   // ├
  BorderRightT:     AnsiString = #$E2#$94#$A4;   // ┤
  BorderTopT:       AnsiString = #$E2#$94#$AC;   // ┬
  BorderBottomT:    AnsiString = #$E2#$94#$B4;   // ┴
  BorderCross:      AnsiString = #$E2#$94#$BC;   // ┼

  // Double line glyphs.
  BorderDoubleH:    AnsiString = #$E2#$95#$90;   // ═
  BorderDoubleV:    AnsiString = #$E2#$95#$91;   // ║
  BorderDoubleTL:   AnsiString = #$E2#$95#$94;   // ╔
  BorderDoubleTR:   AnsiString = #$E2#$95#$97;   // ╗
  BorderDoubleBL:   AnsiString = #$E2#$95#$9A;   // ╚
  BorderDoubleBR:   AnsiString = #$E2#$95#$9D;   // ╝
  BorderDoubleLT:   AnsiString = #$E2#$95#$A0;   // ╠
  BorderDoubleRT:   AnsiString = #$E2#$95#$A3;   // ╣
  BorderDoubleTT:   AnsiString = #$E2#$95#$A6;   // ╦
  BorderDoubleBT:   AnsiString = #$E2#$95#$A9;   // ╩
  BorderDoubleCross:AnsiString = #$E2#$95#$AC;   // ╬

  // Heavy line glyphs.
  BorderHeavyH:     AnsiString = #$E2#$94#$81;   // ━
  BorderHeavyV:     AnsiString = #$E2#$94#$83;   // ┃
  BorderHeavyTL:    AnsiString = #$E2#$94#$8F;   // ┏
  BorderHeavyTR:    AnsiString = #$E2#$94#$93;   // ┓
  BorderHeavyBL:    AnsiString = #$E2#$94#$97;   // ┗
  BorderHeavyBR:    AnsiString = #$E2#$94#$9B;   // ┛
  BorderHeavyLT:    AnsiString = #$E2#$94#$A3;   // ┣
  BorderHeavyRT:    AnsiString = #$E2#$94#$AB;   // ┫
  BorderHeavyTT:    AnsiString = #$E2#$94#$B3;   // ┳
  BorderHeavyBT:    AnsiString = #$E2#$94#$BB;   // ┻
  BorderHeavyCross: AnsiString = #$E2#$95#$8B;   // ╋

  // Dashed line glyphs.
  BorderDashedH:    AnsiString = #$E2#$94#$84;   // ┄
  BorderDashedV:    AnsiString = #$E2#$94#$86;   // ┆

var
  BorderSetPlain: TBorderSet;
  BorderSetRounded: TBorderSet;
  BorderSetDouble: TBorderSet;
  BorderSetHeavy: TBorderSet;
  BorderSetDashed: TBorderSet;

implementation

initialization
  BorderSetPlain.Horizontal  := BorderHorizontal;
  BorderSetPlain.Vertical    := BorderVertical;
  BorderSetPlain.TopLeft     := BorderTopLeft;
  BorderSetPlain.TopRight    := BorderTopRight;
  BorderSetPlain.BottomLeft  := BorderBottomLeft;
  BorderSetPlain.BottomRight := BorderBottomRight;
  BorderSetPlain.LeftT       := BorderLeftT;
  BorderSetPlain.RightT      := BorderRightT;
  BorderSetPlain.TopT        := BorderTopT;
  BorderSetPlain.BottomT     := BorderBottomT;
  BorderSetPlain.Cross       := BorderCross;

  BorderSetRounded.Horizontal  := BorderHorizontal;
  BorderSetRounded.Vertical    := BorderVertical;
  BorderSetRounded.TopLeft     := BorderRoundedTL;
  BorderSetRounded.TopRight    := BorderRoundedTR;
  BorderSetRounded.BottomLeft  := BorderRoundedBL;
  BorderSetRounded.BottomRight := BorderRoundedBR;
  BorderSetRounded.LeftT       := BorderLeftT;
  BorderSetRounded.RightT      := BorderRightT;
  BorderSetRounded.TopT        := BorderTopT;
  BorderSetRounded.BottomT     := BorderBottomT;
  BorderSetRounded.Cross       := BorderCross;

  BorderSetDouble.Horizontal  := BorderDoubleH;
  BorderSetDouble.Vertical    := BorderDoubleV;
  BorderSetDouble.TopLeft     := BorderDoubleTL;
  BorderSetDouble.TopRight    := BorderDoubleTR;
  BorderSetDouble.BottomLeft  := BorderDoubleBL;
  BorderSetDouble.BottomRight := BorderDoubleBR;
  BorderSetDouble.LeftT       := BorderDoubleLT;
  BorderSetDouble.RightT      := BorderDoubleRT;
  BorderSetDouble.TopT        := BorderDoubleTT;
  BorderSetDouble.BottomT     := BorderDoubleBT;
  BorderSetDouble.Cross       := BorderDoubleCross;

  BorderSetHeavy.Horizontal  := BorderHeavyH;
  BorderSetHeavy.Vertical    := BorderHeavyV;
  BorderSetHeavy.TopLeft     := BorderHeavyTL;
  BorderSetHeavy.TopRight    := BorderHeavyTR;
  BorderSetHeavy.BottomLeft  := BorderHeavyBL;
  BorderSetHeavy.BottomRight := BorderHeavyBR;
  BorderSetHeavy.LeftT       := BorderHeavyLT;
  BorderSetHeavy.RightT      := BorderHeavyRT;
  BorderSetHeavy.TopT        := BorderHeavyTT;
  BorderSetHeavy.BottomT     := BorderHeavyBT;
  BorderSetHeavy.Cross       := BorderHeavyCross;

  BorderSetDashed.Horizontal  := BorderDashedH;
  BorderSetDashed.Vertical    := BorderDashedV;
  BorderSetDashed.TopLeft     := BorderTopLeft;
  BorderSetDashed.TopRight    := BorderTopRight;
  BorderSetDashed.BottomLeft  := BorderBottomLeft;
  BorderSetDashed.BottomRight := BorderBottomRight;
  BorderSetDashed.LeftT       := BorderLeftT;
  BorderSetDashed.RightT      := BorderRightT;
  BorderSetDashed.TopT        := BorderTopT;
  BorderSetDashed.BottomT     := BorderBottomT;
  BorderSetDashed.Cross       := BorderCross;

end.
