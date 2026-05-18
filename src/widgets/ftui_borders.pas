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

const
  BordersNone: TBorders = [];
  BordersAll : TBorders = [bsTop, bsRight, bsBottom, bsLeft];

  // Plain border glyphs (single-line box drawing).  Each is one
  // grapheme of 3 UTF-8 bytes.  Stored as constant AnsiStrings so
  // they pass straight into Buffer.SetString or CellSetSymbolBytes.
  BorderHorizontal: AnsiString = #$E2#$94#$80;   // ─
  BorderVertical:   AnsiString = #$E2#$94#$82;   // │
  BorderTopLeft:    AnsiString = #$E2#$94#$8C;   // ┌
  BorderTopRight:   AnsiString = #$E2#$94#$90;   // ┐
  BorderBottomLeft: AnsiString = #$E2#$94#$94;   // └
  BorderBottomRight:AnsiString = #$E2#$94#$98;   // ┘

implementation

end.
