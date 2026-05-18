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

  // A set of 8 glyphs defining the visual appearance of a border.
  TBorderSet = record
    Horizontal: AnsiString;
    Vertical: AnsiString;
    TopLeft: AnsiString;
    TopRight: AnsiString;
    BottomLeft: AnsiString;
    BottomRight: AnsiString;
    // Connectors for internal separators (├ ┤ style).
    LeftT: AnsiString;
    RightT: AnsiString;
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

var
  // Pre-built border sets for convenience.
  BorderSetPlain: TBorderSet;
  BorderSetRounded: TBorderSet;

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

  BorderSetRounded.Horizontal  := BorderHorizontal;
  BorderSetRounded.Vertical    := BorderVertical;
  BorderSetRounded.TopLeft     := BorderRoundedTL;
  BorderSetRounded.TopRight    := BorderRoundedTR;
  BorderSetRounded.BottomLeft  := BorderRoundedBL;
  BorderSetRounded.BottomRight := BorderRoundedBR;
  BorderSetRounded.LeftT       := BorderLeftT;
  BorderSetRounded.RightT      := BorderRightT;

end.
