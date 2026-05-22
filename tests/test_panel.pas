unit test_panel;
{$mode objfpc}{$H+}
interface
procedure RegisterPanelTests;
implementation
uses ftui_testkit, ftui_rect, ftui_style, ftui_color, ftui_modifier, ftui_cell, ftui_buffer, ftui_borders, ftui_layout, ftui_panel;

procedure Test_BasicLayout;
var P: TPanel; G: TPanelGrid; C: TRect;
begin
  P := TPanel.Create(
    [LengthConstraint(10), MinConstraint(0)],
    [MinConstraint(0)]
  );
  G := P.Layout(TRect.Make(0, 0, 40, 10));
  AssertEqInt(2, G.ColCount, 'col count');
  AssertEqInt(1, G.RowCount, 'row count');
  C := PanelCell(G, 0, 0);
  AssertEqInt(10, C.Width, 'left col width');
  C := PanelCell(G, 1, 0);
  AssertTrue(C.Width > 0, 'right col has width');
end;

procedure Test_RenderDrawsBorders;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; Row0: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  P := TPanel.Create(
    [LengthConstraint(8), MinConstraint(0)],
    [MinConstraint(0)]
  );
  G := P.Render(TRect.Make(0, 0, 20, 5), Buf);
  Row0 := Buf.RowAsString(0);
  AssertTrue(Pos(BorderTopLeft, Row0) > 0, 'top-left corner');
  AssertTrue(Pos(BorderTopRight, Row0) > 0, 'top-right corner');
  AssertTrue(Pos(BorderTopT, Row0) > 0, 'top-T junction');
  Buf.Free;
end;

procedure Test_InnerHOnly;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; SepRow: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 7));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(2), MinConstraint(0)]
  ).WithEdges(PanelEdgesInner);
  G := P.Render(TRect.Make(0, 0, 20, 7), Buf);
  SepRow := Buf.RowAsString(G.RowOffsets[1] - 1);
  AssertTrue(Pos(BorderHorizontal, SepRow) > 0, 'inner-H line drawn');
  AssertTrue(Pos(BorderTopLeft, Buf.RowAsString(0)) = 0, 'no outer frame');
  Buf.Free;
end;

procedure Test_EdgesNone;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; Row0: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithEdges(PanelEdgesNone);
  G := P.Render(TRect.Make(0, 0, 20, 5), Buf);
  Row0 := Buf.RowAsString(0);
  AssertTrue(Pos(BorderTopLeft, Row0) = 0, 'no border when edges=none');
  Buf.Free;
end;

procedure Test_CellAreaCorrect;
var P: TPanel; G: TPanelGrid; C0, C1: TRect;
begin
  P := TPanel.Create(
    [LengthConstraint(5), LengthConstraint(5)],
    [LengthConstraint(3), LengthConstraint(3)]
  );
  G := P.Layout(TRect.Make(0, 0, 13, 9));
  C0 := PanelCell(G, 0, 0);
  C1 := PanelCell(G, 1, 1);
  AssertEqInt(5, C0.Width, 'cell(0,0) width');
  AssertEqInt(3, C0.Height, 'cell(0,0) height');
  AssertEqInt(5, C1.Width, 'cell(1,1) width');
  AssertEqInt(3, C1.Height, 'cell(1,1) height');
end;

procedure Test_DoubleAndHeavyBorders;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; Row0: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithBorderSet(BorderSetDouble);
  G := P.Render(TRect.Make(0, 0, 20, 5), Buf);
  Row0 := Buf.RowAsString(0);
  AssertTrue(Pos(BorderDoubleTL, Row0) > 0, 'double top-left');
  AssertTrue(Pos(BorderDoubleTT, Row0) > 0, 'double top-T');
  Buf.Free;
end;

procedure Test_EmptyAreaNoCrash;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  P := TPanel.Create([MinConstraint(0)], [MinConstraint(0)]);
  G := P.Render(TRect.Make(0, 0, 0, 0), Buf);
  AssertTrue(True, 'empty area: no crash');
  Buf.Free;
end;

procedure Test_NestedPanel;
var Outer, Inner: TPanel; OG, IG: TPanelGrid; Buf: TBuffer;
    RightArea, InnerCell: TRect;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 12));
  Outer := TPanel.Create(
    [LengthConstraint(15), MinConstraint(0)],
    [MinConstraint(0)]
  );
  OG := Outer.Render(TRect.Make(0, 0, 40, 12), Buf);
  RightArea := PanelCell(OG, 1, 0);

  Inner := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(2), MinConstraint(0), LengthConstraint(1)]
  ).WithEdges(PanelEdgesInner);
  IG := Inner.Render(RightArea, Buf);

  InnerCell := PanelCell(IG, 0, 1);
  AssertTrue(InnerCell.Width > 0, 'nested middle cell has width');
  AssertTrue(InnerCell.Height > 0, 'nested middle cell has height');
  Buf.Free;
end;

procedure Test_CrossJunction;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; PC: PCell;
    SepX, SepY: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 15, 9));
  P := TPanel.Create(
    [LengthConstraint(5), MinConstraint(0)],
    [LengthConstraint(3), MinConstraint(0)]
  );
  G := P.Render(TRect.Make(0, 0, 15, 9), Buf);
  SepX := G.ColOffsets[1] - 1;
  SepY := G.RowOffsets[1] - 1;
  PC := Buf.CellAt(SepX, SepY);
  AssertTrue(PC <> nil, 'cross cell exists');
  AssertTrue(PC^.Glyph.Len > 0, 'cross cell has glyph');
  Buf.Free;
end;

procedure Test_OffsetArea;
var P: TPanel; G: TPanelGrid; C: TRect;
begin
  P := TPanel.Create(
    [LengthConstraint(5), MinConstraint(0)],
    [MinConstraint(0)]
  );
  G := P.Layout(TRect.Make(10, 5, 20, 8));
  C := PanelCell(G, 0, 0);
  AssertEqInt(11, C.X, 'offset area: cell X starts after left border');
  AssertEqInt(6, C.Y, 'offset area: cell Y starts after top border');
  AssertEqInt(5, C.Width, 'offset area: left col width');
end;

procedure Test_SingleColNoInnerV;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; Row0: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 15, 5));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(1), MinConstraint(0)]
  );
  G := P.Render(TRect.Make(0, 0, 15, 5), Buf);
  Row0 := Buf.RowAsString(0);
  AssertTrue(Pos(BorderTopT, Row0) = 0, 'single col: no top-T');
  Buf.Free;
end;

procedure Test_MinimalArea;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 3));
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0), MinConstraint(0)]
  );
  G := P.Render(TRect.Make(0, 0, 3, 3), Buf);
  AssertTrue(True, 'minimal 3x3 area: no crash');
  Buf.Free;
end;

procedure Test_PercentageConstraint;
var P: TPanel; G: TPanelGrid; C0, C1: TRect;
begin
  P := TPanel.Create(
    [PercentageConstraint(30), PercentageConstraint(70)],
    [MinConstraint(0)]
  );
  G := P.Layout(TRect.Make(0, 0, 33, 5));
  C0 := PanelCell(G, 0, 0);
  C1 := PanelCell(G, 1, 0);
  AssertTrue(C0.Width >= 8, 'pct: left col ~30%');
  AssertTrue(C1.Width >= 18, 'pct: right col ~70%');
end;

procedure Test_InnerLineFillsFullWidth;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
    SepY, X: Integer; PC: PCell; Count: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(1), MinConstraint(0)]
  ).WithEdges(PanelEdgesInner);
  G := P.Render(TRect.Make(0, 0, 10, 5), Buf);
  SepY := G.RowOffsets[1] - 1;
  Count := 0;
  for X := 0 to 9 do
  begin
    PC := Buf.CellAt(X, SepY);
    if (PC <> nil) and (PC^.Glyph.Len > 0) then Inc(Count);
  end;
  AssertEqInt(10, Count, 'inner-H fills full width when no outer frame');
  Buf.Free;
end;

procedure Test_VSepStartRow;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
    DivX: Integer; PC: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  P := TPanel.Create(
    [LengthConstraint(10), MinConstraint(0)],
    [LengthConstraint(2), MinConstraint(0)]
  ).WithVSepStartRow(1);
  G := P.Render(TRect.Make(0, 0, 30, 10), Buf);
  DivX := G.ColOffsets[1] - 1;
  // Row 0 area: divider should NOT be drawn (above start row)
  PC := Buf.CellAt(DivX, 1);
  AssertTrue((PC = nil) or (PC^.Glyph.Len = 0) or (CellGlyphAsString(PC^) <> BorderVertical),
    'VSepStartRow: no V-line in row 0');
  // Below start row: divider should be drawn
  PC := Buf.CellAt(DivX, G.RowOffsets[1]);
  AssertTrue((PC <> nil) and (PC^.Glyph.Len > 0), 'VSepStartRow: V-line in row 1');
  Buf.Free;
end;

procedure Test_HSepVisible;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
    Sep0Y, Sep1Y, X: Integer; PC: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(2), LengthConstraint(2), MinConstraint(0)]
  ).WithHSepVisible(1, False);
  G := P.Render(TRect.Make(0, 0, 20, 10), Buf);
  Sep0Y := G.RowOffsets[1] - 1;
  Sep1Y := G.RowOffsets[2] - 1;
  // First separator should be visible
  PC := Buf.CellAt(5, Sep0Y);
  AssertTrue((PC <> nil) and (PC^.Glyph.Len > 0), 'HSep 0 visible');
  // Second separator should be hidden
  PC := Buf.CellAt(5, Sep1Y);
  AssertTrue((PC = nil) or (PC^.Glyph.Len = 0), 'HSep 1 hidden');
  Buf.Free;
end;

procedure Test_PanelCellSpan;
var P: TPanel; G: TPanelGrid; Span: TRect;
begin
  P := TPanel.Create(
    [LengthConstraint(10), MinConstraint(0)],
    [LengthConstraint(3), LengthConstraint(3), MinConstraint(0)]
  );
  G := P.Layout(TRect.Make(0, 0, 30, 12));
  Span := PanelCellSpan(G, 0, 0, 1, 3);
  AssertEqInt(PanelCell(G, 0, 0).X, Span.X, 'span X');
  AssertEqInt(PanelCell(G, 0, 0).Y, Span.Y, 'span Y');
  AssertEqInt(10, Span.Width, 'span width = col width');
  AssertTrue(Span.Height > PanelCell(G, 0, 0).Height, 'span height > single cell');
end;

procedure Test_HSepTitle;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
    SepY: Integer; Row: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 8));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(2), MinConstraint(0)]
  ).WithHSepTitle(0, ' Files ');
  G := P.Render(TRect.Make(0, 0, 40, 8), Buf);
  SepY := G.RowOffsets[1] - 1;
  Row := Buf.RowAsString(SepY);
  AssertTrue(Pos('Files', Row) > 0, 'title on separator');
  Buf.Free;
end;

procedure Test_MixedBorderSet;
var P: TPanel; G: TPanelGrid; Buf: TBuffer;
    Row0, SepRow: AnsiString; SepY: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 8));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(2), MinConstraint(0)]
  ).WithBorderSet(BorderSetRounded)
   .WithSepSet(BorderSetPlain);
  G := P.Render(TRect.Make(0, 0, 30, 8), Buf);
  Row0 := Buf.RowAsString(0);
  AssertTrue(Pos(BorderRoundedTL, Row0) > 0, 'outer uses rounded');
  SepY := G.RowOffsets[1] - 1;
  SepRow := Buf.RowAsString(SepY);
  AssertTrue(Pos(BorderHorizontal, SepRow) > 0, 'sep uses plain');
  Buf.Free;
end;

procedure Test_FactorySidebar;
var P: TPanel; G: TPanelGrid;
begin
  P := TPanel.Sidebar(20);
  G := P.Layout(TRect.Make(0, 0, 60, 20));
  AssertEqInt(2, G.ColCount, 'sidebar: 2 cols');
  AssertEqInt(1, G.RowCount, 'sidebar: 1 row');
  AssertEqInt(20, PanelCell(G, 0, 0).Width, 'sidebar: left width');
end;

procedure Test_FactoryGrid;
var P: TPanel; G: TPanelGrid;
begin
  P := TPanel.Grid(3, 2);
  G := P.Layout(TRect.Make(0, 0, 40, 20));
  AssertEqInt(3, G.ColCount, 'grid: 3 cols');
  AssertEqInt(2, G.RowCount, 'grid: 2 rows');
end;

procedure Test_Focus;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; PC: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  P := TPanel.Create(
    [LengthConstraint(10), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithFocus(1, 0).WithFocusStyle(TStyle.Default.WithFg(clGreen));
  G := P.Render(TRect.Make(0, 0, 30, 10), Buf);
  PC := Buf.CellAt(PanelCell(G, 1, 0).X, 0);
  AssertTrue((PC <> nil) and (PC^.Glyph.Len > 0), 'focus: top edge redrawn');
  Buf.Free;
end;

procedure Test_Padding;
var P: TPanel; G: TPanelGrid; R, Padded: TRect;
begin
  P := TPanel.Create(
    [MinConstraint(0)],
    [MinConstraint(0)]
  ).WithPadding(1);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  R := PanelCell(G, 0, 0);
  Padded := PanelCellPadded(P, G, 0, 0);
  AssertEqInt(R.X + 1, Padded.X, 'padded X');
  AssertEqInt(R.Y + 1, Padded.Y, 'padded Y');
  AssertEqInt(Integer(R.Width) - 2, Integer(Padded.Width), 'padded width');
  AssertEqInt(Integer(R.Height) - 2, Integer(Padded.Height), 'padded height');
end;

procedure Test_MinWidth;
var P: TPanel; G: TPanelGrid;
begin
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithMinWidth(0, 8);
  G := P.Layout(TRect.Make(0, 0, 20, 5));
  AssertTrue(PanelCell(G, 0, 0).Width >= 8, 'min width enforced on col 0');
end;

procedure Test_Debug;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; Row: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithDebug(True);
  G := P.Render(TRect.Make(0, 0, 20, 5), Buf);
  Row := Buf.RowAsString(PanelCell(G, 0, 0).Y);
  AssertTrue(Pos('0,0', Row) > 0, 'debug: shows 0,0');
  Row := Buf.RowAsString(PanelCell(G, 1, 0).Y);
  AssertTrue(Pos('1,0', Row) > 0, 'debug: shows 1,0');
  Buf.Free;
end;

procedure Test_HitTestSep;
var P: TPanel; G: TPanelGrid; Hit: TSepHit;
begin
  P := TPanel.Create(
    [LengthConstraint(10), MinConstraint(0)],
    [LengthConstraint(3), MinConstraint(0)]
  );
  G := P.Layout(TRect.Make(0, 0, 30, 10));
  Hit := PanelHitTestSep(G, G.ColOffsets[1] - 1, 5);
  AssertTrue(Hit.Found, 'hit: found vsep');
  AssertFalse(Hit.IsHorizontal, 'hit: is vertical');
  AssertEqInt(0, Hit.SepIndex, 'hit: sep index 0');
  Hit := PanelHitTestSep(G, 5, G.RowOffsets[1] - 1);
  AssertTrue(Hit.Found, 'hit: found hsep');
  AssertTrue(Hit.IsHorizontal, 'hit: is horizontal');
end;

procedure Test_DashedBorder;
var P: TPanel; G: TPanelGrid; Buf: TBuffer; SepRow: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 6));
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(2), MinConstraint(0)]
  ).WithSepSet(BorderSetDashed);
  G := P.Render(TRect.Make(0, 0, 20, 6), Buf);
  SepRow := Buf.RowAsString(G.RowOffsets[1] - 1);
  AssertTrue(Pos(BorderDashedH, SepRow) > 0, 'dashed H-sep');
  Buf.Free;
end;

procedure Test_CellPaddingOverride;
var P: TPanel; G: TPanelGrid; R, Padded: TRect;
begin
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithPadding(2).WithCellPadding(1, 0, 1);
  G := P.Layout(TRect.Make(0, 0, 30, 10));
  Padded := PanelCellPadded(P, G, 0, 0);
  R := PanelCell(G, 0, 0);
  AssertEqInt(R.X + 2, Padded.X, 'global padding=2 on cell(0,0)');
  Padded := PanelCellPadded(P, G, 1, 0);
  R := PanelCell(G, 1, 0);
  AssertEqInt(R.X + 1, Padded.X, 'cell padding=1 overrides global on cell(1,0)');
end;

procedure Test_MinHeightEnforced;
var P: TPanel; G: TPanelGrid;
begin
  P := TPanel.Create(
    [MinConstraint(0)],
    [MinConstraint(0), MinConstraint(0)]
  ).WithMinHeight(0, 5);
  G := P.Layout(TRect.Make(0, 0, 20, 12));
  AssertTrue(PanelCell(G, 0, 0).Height >= 5, 'min height enforced');
end;

procedure Test_ColWeight;
var P: TPanel; G: TPanelGrid; W0, W1: Integer;
begin
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithColWeight(0, 1).WithColWeight(1, 2).WithColWeight(2, 1);
  G := P.Layout(TRect.Make(0, 0, 42, 5));
  W0 := PanelCell(G, 0, 0).Width;
  W1 := PanelCell(G, 1, 0).Width;
  AssertTrue(W1 > W0, 'col weight 2 > weight 1');
end;

procedure Test_RowWeight;
var P: TPanel; G: TPanelGrid; H0, H1: Integer;
begin
  P := TPanel.Create(
    [MinConstraint(0)],
    [MinConstraint(0), MinConstraint(0)]
  ).WithRowWeight(0, 1).WithRowWeight(1, 3);
  G := P.Layout(TRect.Make(0, 0, 20, 22));
  H0 := PanelCell(G, 0, 0).Height;
  H1 := PanelCell(G, 0, 1).Height;
  AssertTrue(H1 > H0, 'row weight 3 > weight 1');
end;

procedure Test_SpanWithHiddenSep;
var P: TPanel; G: TPanelGrid; Span: TRect;
begin
  P := TPanel.Create(
    [MinConstraint(0)],
    [LengthConstraint(3), LengthConstraint(3), MinConstraint(0)]
  ).WithHSepVisible(0, False);
  G := P.Layout(TRect.Make(0, 0, 20, 12));
  Span := PanelCellSpan(G, 0, 0, 1, 2);
  // Hidden sep still reserves space (layout stability), so span includes it
  AssertEqInt(PanelCell(G, 0, 0).Height + PanelCell(G, 0, 1).Height + 1,
    Span.Height, 'span includes hidden sep space');
end;

procedure Test_MinWidthOverflow;
var P: TPanel; G: TPanelGrid; TotalW: Integer;
begin
  P := TPanel.Create(
    [MinConstraint(0), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithMinWidth(0, 15).WithMinWidth(1, 15);
  G := P.Layout(TRect.Make(0, 0, 20, 5));
  TotalW := PanelCell(G, 0, 0).Width + PanelCell(G, 1, 0).Width;
  AssertTrue(TotalW <= 18, 'min width overflow clamped to available');
end;

procedure RegisterPanelTests;
begin
  RegisterTest('panel / basic layout',        @Test_BasicLayout);
  RegisterTest('panel / render draws borders', @Test_RenderDrawsBorders);
  RegisterTest('panel / inner-H only',        @Test_InnerHOnly);
  RegisterTest('panel / edges none',          @Test_EdgesNone);
  RegisterTest('panel / cell area correct',   @Test_CellAreaCorrect);
  RegisterTest('panel / double+heavy borders', @Test_DoubleAndHeavyBorders);
  RegisterTest('panel / empty area no crash', @Test_EmptyAreaNoCrash);
  RegisterTest('panel / nested panel',        @Test_NestedPanel);
  RegisterTest('panel / cross junction',      @Test_CrossJunction);
  RegisterTest('panel / offset area',         @Test_OffsetArea);
  RegisterTest('panel / single col no inner-V', @Test_SingleColNoInnerV);
  RegisterTest('panel / minimal area',        @Test_MinimalArea);
  RegisterTest('panel / percentage constraint', @Test_PercentageConstraint);
  RegisterTest('panel / inner line full width', @Test_InnerLineFillsFullWidth);
  RegisterTest('panel / VSepStartRow',        @Test_VSepStartRow);
  RegisterTest('panel / HSep visible',        @Test_HSepVisible);
  RegisterTest('panel / PanelCellSpan',       @Test_PanelCellSpan);
  RegisterTest('panel / HSep title',          @Test_HSepTitle);
  RegisterTest('panel / mixed border set',    @Test_MixedBorderSet);
  RegisterTest('panel / factory sidebar',     @Test_FactorySidebar);
  RegisterTest('panel / factory grid',        @Test_FactoryGrid);
  RegisterTest('panel / focus highlight',     @Test_Focus);
  RegisterTest('panel / padding',             @Test_Padding);
  RegisterTest('panel / min width',           @Test_MinWidth);
  RegisterTest('panel / debug mode',          @Test_Debug);
  RegisterTest('panel / hit test sep',        @Test_HitTestSep);
  RegisterTest('panel / dashed border',       @Test_DashedBorder);
  RegisterTest('panel / cell padding override', @Test_CellPaddingOverride);
  RegisterTest('panel / min height enforced', @Test_MinHeightEnforced);
  RegisterTest('panel / col weight',          @Test_ColWeight);
  RegisterTest('panel / row weight',          @Test_RowWeight);
  RegisterTest('panel / span with hidden sep', @Test_SpanWithHiddenSep);
  RegisterTest('panel / min width overflow',  @Test_MinWidthOverflow);
end;
end.
