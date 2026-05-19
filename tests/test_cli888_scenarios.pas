unit test_cli888_scenarios;

{$mode objfpc}{$H+}

interface

procedure RegisterCli888ScenarioTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_borders,
  ftui_block,
  ftui_text,
  ftui_paragraph,
  ftui_list,
  ftui_layout,
  ftui_clear;

const
  H  = #$E2#$94#$80;  // ─
  V  = #$E2#$94#$82;  // │
  TL = #$E2#$94#$8C;  // ┌
  TR = #$E2#$94#$90;  // ┐
  BL = #$E2#$94#$94;  // └
  BR = #$E2#$94#$98;  // ┘

// --- Group 1: Title bar scenarios (cli888 top bar) ---

procedure Test_TitleBarCentered;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    B := TBlock.Default.WithTitle('cli888');
    B.Render(TRect.Make(0, 0, 20, 1), Buf);
    AssertEqStr('cli888              ', Buf.RowAsString(0), 'title row');
  finally
    Buf.Free;
  end;
end;

procedure Test_TitleBarWithBorders;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('Chat');
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + 'Chat' + H + H + H + H + H + H + TR,
      V + '          ' + V,
      BL + H+H+H+H+H+H+H+H+H+H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_TitleBarFullWidth;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('LongTi');
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + 'LongTi' + TR,
      V + '      ' + V,
      BL + H+H+H+H+H+H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

// --- Group 2: Message list scenarios ---

procedure Test_MessageListSingleItem;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    L := TList.FromStrings(['Hello']);
    St := TListState.Empty;
    L.RenderStateful(Buf.Area, Buf, St);
    AssertEqStr('Hello     ', Buf.RowAsString(0), 'single item');
  finally
    Buf.Free;
  end;
end;

procedure Test_MessageListThreeItems;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    L := TList.FromStrings(['Msg 1', 'Msg 2', 'Msg 3']);
    St := TListState.Empty;
    L.RenderStateful(Buf.Area, Buf, St);
    AssertEqStr('Msg 1     ', Buf.RowAsString(0), 'row 0');
    AssertEqStr('Msg 2     ', Buf.RowAsString(1), 'row 1');
    AssertEqStr('Msg 3     ', Buf.RowAsString(2), 'row 2');
  finally
    Buf.Free;
  end;
end;

procedure Test_MessageListHighlightFirst;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    L := TList.FromStrings(['Alpha', 'Beta', 'Gamma']);
    L := L.WithHighlightSymbol('> ').WithHighlightStyle(TStyle.Default.WithFg(clYellow));
    St := TListState.Empty;
    St.Select(0);
    L.RenderStateful(Buf.Area, Buf, St);
    AssertEqStr('> Alpha   ', Buf.RowAsString(0), 'highlighted row');
    AssertEqStr('  Beta    ', Buf.RowAsString(1), 'normal row');
    CP := Buf.CellAt(2, 0);
    Assert_(CP^.Fg.Kind = ckIndexed, 'highlight fg is indexed');
    AssertEqInt(3, CP^.Fg.Index, 'highlight fg is yellow');
  finally
    Buf.Free;
  end;
end;

procedure Test_MessageListHighlightMiddle;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    L := TList.FromStrings(['A', 'B', 'C']);
    L := L.WithHighlightSymbol('> ');
    St := TListState.Empty;
    St.Select(1);
    L.RenderStateful(Buf.Area, Buf, St);
    AssertEqStr('  A       ', Buf.RowAsString(0), 'row 0');
    AssertEqStr('> B       ', Buf.RowAsString(1), 'row 1 highlighted');
    AssertEqStr('  C       ', Buf.RowAsString(2), 'row 2');
  finally
    Buf.Free;
  end;
end;

procedure Test_MessageListScrollDown;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    L := TList.FromStrings(['One', 'Two', 'Three', 'Four']);
    L := L.WithHighlightSymbol('> ');
    St := TListState.Empty;
    St.Select(2);
    L.RenderStateful(Buf.Area, Buf, St);
    AssertEqStr('  Two     ', Buf.RowAsString(0), 'scrolled row 0');
    AssertEqStr('> Three   ', Buf.RowAsString(1), 'scrolled row 1');
  finally
    Buf.Free;
  end;
end;

procedure Test_MessageListScrollToEnd;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    L := TList.FromStrings(['A', 'B', 'C', 'D', 'E']);
    L := L.WithHighlightSymbol('> ');
    St := TListState.Empty;
    St.Select(4);
    L.RenderStateful(Buf.Area, Buf, St);
    AssertEqStr('  D       ', Buf.RowAsString(0), 'second to last');
    AssertEqStr('> E       ', Buf.RowAsString(1), 'last item');
  finally
    Buf.Free;
  end;
end;

// --- Group 3: Paragraph / message content ---

procedure Test_ParagraphSingleLine;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 15, 1));
  try
    P := TParagraph.FromText(TText.Raw('Hello world'));
    P.Render(Buf.Area, Buf);
    AssertEqStr('Hello world    ', Buf.RowAsString(0), 'single line');
  finally
    Buf.Free;
  end;
end;

procedure Test_ParagraphWordWrap;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    P := TParagraph.FromText(TText.Raw('Hello beautiful world'));
    P := P.WithWrap(WrapTrim);
    P.Render(Buf.Area, Buf);
    AssertEqStr('Hello     ', Buf.RowAsString(0), 'wrap line 1');
    AssertEqStr('beautiful ', Buf.RowAsString(1), 'wrap line 2');
    AssertEqStr('world     ', Buf.RowAsString(2), 'wrap line 3');
  finally
    Buf.Free;
  end;
end;

procedure Test_ParagraphScrollY;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    P := TParagraph.FromText(TText.Raw('Line1'#10'Line2'#10'Line3'#10'Line4'));
    P := P.WithScrollY(1);
    P.Render(Buf.Area, Buf);
    AssertEqStr('Line2     ', Buf.RowAsString(0), 'scrolled line 1');
    AssertEqStr('Line3     ', Buf.RowAsString(1), 'scrolled line 2');
  finally
    Buf.Free;
  end;
end;

procedure Test_ParagraphEmpty;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    P := TParagraph.FromText(TText.Raw(''));
    P.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['     ', '     ']);
  finally
    Buf.Free;
  end;
end;

// --- Group 4: Layout split scenarios ---

procedure Test_LayoutVertical3Rows;
var
  Rects: array of TRect;
begin
  Rects := VerticalSplit(TRect.Make(0, 0, 20, 6), [
    LengthConstraint(2),
    LengthConstraint(2),
    LengthConstraint(2)
  ]);
  AssertEqInt(3, Length(Rects), 'count');
  AssertEqInt(0, Rects[0].Y, 'r0.y');
  AssertEqInt(2, Rects[0].Height, 'r0.h');
  AssertEqInt(2, Rects[1].Y, 'r1.y');
  AssertEqInt(4, Rects[2].Y, 'r2.y');
end;

procedure Test_LayoutHorizontal3Cols;
var
  Rects: array of TRect;
begin
  Rects := HorizontalSplit(TRect.Make(0, 0, 30, 10), [
    LengthConstraint(10),
    LengthConstraint(10),
    LengthConstraint(10)
  ]);
  AssertEqInt(3, Length(Rects), 'count');
  AssertEqInt(0, Rects[0].X, 'r0.x');
  AssertEqInt(10, Rects[0].Width, 'r0.w');
  AssertEqInt(10, Rects[1].X, 'r1.x');
  AssertEqInt(20, Rects[2].X, 'r2.x');
end;

procedure Test_LayoutPercentageSplit;
var
  Rects: array of TRect;
begin
  Rects := VerticalSplit(TRect.Make(0, 0, 80, 24), [
    PercentageConstraint(10),
    PercentageConstraint(80),
    PercentageConstraint(10)
  ]);
  AssertEqInt(3, Length(Rects), 'count');
  AssertEqInt(2, Rects[0].Height, '10% of 24');
  AssertTrue(Rects[1].Height >= 19, '80% of 24 >= 19');
  AssertEqInt(24, Rects[0].Height + Rects[1].Height + Rects[2].Height, 'sum = 24');
end;

procedure Test_LayoutCli888MainSplit;
var
  Rects: array of TRect;
begin
  Rects := VerticalSplit(TRect.Make(0, 0, 80, 24), [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(3),
    LengthConstraint(1)
  ]);
  AssertEqInt(4, Length(Rects), 'count');
  AssertEqInt(1, Rects[0].Height, 'title bar');
  AssertTrue(Rects[1].Height >= 19, 'message area');
  AssertEqInt(3, Rects[2].Height, 'input box');
  AssertEqInt(1, Rects[3].Height, 'status bar');
  AssertEqInt(24, Rects[0].Height + Rects[1].Height + Rects[2].Height + Rects[3].Height, 'sum');
end;

// --- Group 5: Status bar scenarios ---

procedure Test_StatusBarLeftAligned;
var
  Buf: TBuffer;
  Sty: TStyle;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    Sty := TStyle.Default.WithBg(clGray);
    Buf.SetStyle(Buf.Area, Sty);
    Buf.SetString(0, 0, 'Ready', Sty);
    AssertEqStr('Ready               ', Buf.RowAsString(0), 'status left');
  finally
    Buf.Free;
  end;
end;

procedure Test_StatusBarRightAligned;
var
  Buf: TBuffer;
  Sty: TStyle;
  Text: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    Sty := TStyle.Default.WithBg(clGray);
    Buf.SetStyle(Buf.Area, Sty);
    Text := '12:34';
    Buf.SetString(20 - Length(Text), 0, Text, Sty);
    AssertEqStr('               12:34', Buf.RowAsString(0), 'status right');
  finally
    Buf.Free;
  end;
end;

procedure Test_StatusBarBothEnds;
var
  Buf: TBuffer;
  Sty: TStyle;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    Sty := TStyle.Default.WithBg(clDarkGray);
    Buf.SetStyle(Buf.Area, Sty);
    Buf.SetString(0, 0, 'Mode:N', Sty);
    Buf.SetString(16, 0, 'L:42', Sty);
    AssertEqStr('Mode:N          L:42', Buf.RowAsString(0), 'both ends');
  finally
    Buf.Free;
  end;
end;

// --- Group 6: Block + Paragraph composite (message bubble) ---

procedure Test_MessageBubble;
var
  Buf: TBuffer;
  B: TBlock;
  P: TParagraph;
  Inner: TRect;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 14, 4));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('You');
    B.Render(Buf.Area, Buf);
    Inner := B.Inner(Buf.Area);
    P := TParagraph.FromText(TText.Raw('Hi there'));
    P.Render(Inner, Buf);
    AssertBufferEquals(Buf, [
      TL + 'You' + H+H+H+H+H+H+H+H+H + TR,
      V + 'Hi there    ' + V,
      V + '            ' + V,
      BL + H+H+H+H+H+H+H+H+H+H+H+H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_MessageBubbleWrapped;
var
  Buf: TBuffer;
  B: TBlock;
  P: TParagraph;
  Inner: TRect;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    B := TBlock.Default.WithBorders(BordersAll);
    B.Render(Buf.Area, Buf);
    Inner := B.Inner(Buf.Area);
    P := TParagraph.FromText(TText.Raw('Hello world foo'));
    P := P.WithWrap(WrapTrim);
    P.Render(Inner, Buf);
    AssertBufferEquals(Buf, [
      TL + H+H+H+H+H+H+H+H + TR,
      V + 'Hello   ' + V,
      V + 'world   ' + V,
      V + 'foo     ' + V,
      BL + H+H+H+H+H+H+H+H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

// --- Group 7: Input box scenarios ---

procedure Test_InputBoxEmpty;
var
  Buf: TBuffer;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('Input');
    B.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + 'Input' + H+H+H+H+H+H+H+H+H+H+H+H+H + TR,
      V + '                  ' + V,
      BL + H+H+H+H+H+H+H+H+H+H+H+H+H+H+H+H+H+H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_InputBoxWithText;
var
  Buf: TBuffer;
  B: TBlock;
  Inner: TRect;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 3));
  try
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('Input');
    B.Render(Buf.Area, Buf);
    Inner := B.Inner(Buf.Area);
    Buf.SetString(Inner.X, Inner.Y, 'hello', TStyle.Default);
    AssertEqStr(V + 'hello             ' + V, Buf.RowAsString(1), 'input content');
  finally
    Buf.Free;
  end;
end;

// --- Group 8: Clear widget ---

procedure Test_ClearFillsArea;
var
  Buf: TBuffer;
  C: TClear;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    Buf.SetString(0, 0, 'XXXXX', TStyle.Default);
    Buf.SetString(0, 1, 'XXXXX', TStyle.Default);
    Buf.SetString(0, 2, 'XXXXX', TStyle.Default);
    C := ClearWidget;
    C.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['     ', '     ', '     ']);
  finally
    Buf.Free;
  end;
end;

// --- Group 9: Buffer operations (cli888 render patterns) ---

procedure Test_BufferSetStringClipsRight;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Buf.SetString(0, 0, 'Hello World', TStyle.Default);
    AssertEqStr('Hello', Buf.RowAsString(0), 'clipped');
  finally
    Buf.Free;
  end;
end;

procedure Test_BufferSetStringNMaxWidth;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    Buf.SetStringN(0, 0, 'Hello World', 5, TStyle.Default);
    AssertEqStr('Hello               ', Buf.RowAsString(0), 'maxwidth');
  finally
    Buf.Free;
  end;
end;

procedure Test_BufferSetStyleRegion;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    Buf.SetStyle(TRect.Make(2, 1, 4, 1), TStyle.Default.WithFg(clRed));
    CP := Buf.CellAt(0, 1);
    Assert_(CP^.Fg.Kind = ckReset, 'outside region');
    CP := Buf.CellAt(2, 1);
    AssertEqInt(1, CP^.Fg.Index, 'inside region red');
    CP := Buf.CellAt(5, 1);
    AssertEqInt(1, CP^.Fg.Index, 'inside region end');
    CP := Buf.CellAt(6, 1);
    Assert_(CP^.Fg.Kind = ckReset, 'after region');
  finally
    Buf.Free;
  end;
end;

procedure Test_BufferDiffIdenticalIsEmpty;
var
  A, B: TBuffer;
  Patches: TDiffEntries;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    A.Diff(B, Patches);
    AssertEqInt(0, Length(Patches), 'no diff');
  finally
    A.Free; B.Free;
  end;
end;

procedure Test_BufferDiffSingleCellChange;
var
  A, B: TBuffer;
  Patches: TDiffEntries;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    B.SetString(2, 1, 'X', TStyle.Default);
    A.Diff(B, Patches);
    AssertEqInt(1, Length(Patches), 'one patch');
    AssertEqInt(2, Patches[0].X, 'patch x');
    AssertEqInt(1, Patches[0].Y, 'patch y');
  finally
    A.Free; B.Free;
  end;
end;

procedure Test_BufferDiffFullRowChange;
var
  A, B: TBuffer;
  Patches: TDiffEntries;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    B.SetString(0, 1, 'ABCDE', TStyle.Default);
    A.Diff(B, Patches);
    AssertEqInt(5, Length(Patches), 'full row');
  finally
    A.Free; B.Free;
  end;
end;

// --- Group 10: Composite cli888 screen layout ---

procedure Test_Cli888FullScreenLayout;
var
  Buf: TBuffer;
  Rects: array of TRect;
  B: TBlock;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    Rects := VerticalSplit(Buf.Area, [
      LengthConstraint(1),
      MinConstraint(0),
      LengthConstraint(3),
      LengthConstraint(1)
    ]);
    Buf.SetString(0, Rects[0].Y, 'cli888 Chat', TStyle.Default.WithBg(clYellow));
    B := TBlock.Default.WithBorders(BordersAll);
    B.Render(Rects[2], Buf);
    Buf.SetString(0, Rects[3].Y, 'Ready', TStyle.Default.WithBg(clGray));
    L := TList.FromStrings(['Hello', 'World', 'Test']);
    L := L.WithHighlightSymbol('> ');
    St := TListState.Empty;
    St.Select(0);
    L.RenderStateful(Rects[1], Buf, St);
    AssertTrue(Buf.RowAsString(0) <> '', 'title rendered');
    AssertTrue(Buf.RowAsString(Rects[3].Y) <> '', 'status rendered');
  finally
    Buf.Free;
  end;
end;

procedure Test_Cli888SplitPanels;
var
  Buf: TBuffer;
  Cols: array of TRect;
  B: TBlock;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    Cols := HorizontalSplit(Buf.Area, [
      LengthConstraint(10),
      LengthConstraint(10)
    ]);
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('L');
    B.Render(Cols[0], Buf);
    B := TBlock.Default.WithBorders(BordersAll).WithTitle('R');
    B.Render(Cols[1], Buf);
    AssertEqInt(0, Cols[0].X, 'left panel x');
    AssertEqInt(10, Cols[1].X, 'right panel x');
  finally
    Buf.Free;
  end;
end;

// --- Group 11: Style application patterns ---

procedure Test_StyleFgOnlyApplied;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Buf.SetString(0, 0, 'Hello', TStyle.Default.WithFg(clGreen));
    CP := Buf.CellAt(0, 0);
    AssertEqInt(2, CP^.Fg.Index, 'green fg');
    Assert_(CP^.Bg.Kind = ckReset, 'bg unchanged');
  finally
    Buf.Free;
  end;
end;

procedure Test_StyleBgOnlyApplied;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Buf.SetString(0, 0, 'Hello', TStyle.Default.WithBg(clBlue));
    CP := Buf.CellAt(0, 0);
    Assert_(CP^.Fg.Kind = ckReset, 'fg unchanged');
    AssertEqInt(4, CP^.Bg.Index, 'blue bg');
  finally
    Buf.Free;
  end;
end;

procedure Test_StyleBoldModifier;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Buf.SetString(0, 0, 'Bold', TStyle.Default.WithModifier([mbBold]));
    CP := Buf.CellAt(0, 0);
    Assert_(mbBold in CP^.Modifier, 'bold set');
    Assert_(not (mbItalic in CP^.Modifier), 'italic not set');
  finally
    Buf.Free;
  end;
end;

procedure Test_StyleOverwrite;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Buf.SetString(0, 0, 'A', TStyle.Default.WithFg(clRed));
    Buf.SetString(0, 0, 'B', TStyle.Default.WithFg(clGreen));
    CP := Buf.CellAt(0, 0);
    AssertEqInt(2, CP^.Fg.Index, 'overwritten to green');
    AssertEqStr('B', CellGlyphAsString(CP^), 'glyph overwritten');
  finally
    Buf.Free;
  end;
end;

// --- Group 12: Edge cases ---

procedure Test_ZeroWidthArea;
var
  Rects: array of TRect;
begin
  Rects := VerticalSplit(TRect.Make(0, 0, 0, 0), [LengthConstraint(1)]);
  AssertEqInt(1, Length(Rects), 'still returns 1 rect');
  AssertEqInt(0, Rects[0].Height, 'zero height');
end;

procedure Test_SingleCellBuffer;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    Buf.SetString(0, 0, 'X', TStyle.Default);
    AssertEqStr('X', Buf.RowAsString(0), 'single cell');
  finally
    Buf.Free;
  end;
end;

procedure Test_BufferResetClearsContent;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Buf.SetString(0, 0, 'Hello', TStyle.Default);
    Buf.Reset;
    AssertEqStr('     ', Buf.RowAsString(0), 'reset to spaces');
  finally
    Buf.Free;
  end;
end;

procedure Test_ListEmptyItems;
var
  Buf: TBuffer;
  L: TList;
  St: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    L := TList.FromStrings([]);
    St := TListState.Empty;
    L.RenderStateful(Buf.Area, Buf, St);
    AssertBufferEquals(Buf, ['          ', '          ', '          ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_ParagraphLongWordHardBreak;
var
  Buf: TBuffer;
  P: TParagraph;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    P := TParagraph.FromText(TText.Raw('ABCDEFGH'));
    P := P.WithWrap(WrapTrim);
    P.Render(Buf.Area, Buf);
    AssertEqStr('ABCDE', Buf.RowAsString(0), 'hard break line 1');
    AssertEqStr('FGH  ', Buf.RowAsString(1), 'hard break line 2');
  finally
    Buf.Free;
  end;
end;

// --- Group 13: Block inner area calculations ---

procedure Test_BlockInnerAllBorders;
var
  B: TBlock;
  Inner: TRect;
begin
  B := TBlock.Default.WithBorders(BordersAll);
  Inner := B.Inner(TRect.Make(0, 0, 10, 5));
  AssertEqInt(1, Inner.X, 'inner x');
  AssertEqInt(1, Inner.Y, 'inner y');
  AssertEqInt(8, Inner.Width, 'inner w');
  AssertEqInt(3, Inner.Height, 'inner h');
end;

procedure Test_BlockInnerNoBorders;
var
  B: TBlock;
  Inner: TRect;
begin
  B := TBlock.Default;
  Inner := B.Inner(TRect.Make(0, 0, 10, 5));
  AssertEqInt(0, Inner.X, 'inner x');
  AssertEqInt(0, Inner.Y, 'inner y');
  AssertEqInt(10, Inner.Width, 'inner w');
  AssertEqInt(5, Inner.Height, 'inner h');
end;

procedure Test_BlockInnerTopBorderOnly;
var
  B: TBlock;
  Inner: TRect;
begin
  B := TBlock.Default.WithBorders([bsTop]);
  Inner := B.Inner(TRect.Make(0, 0, 10, 5));
  AssertEqInt(0, Inner.X, 'inner x');
  AssertEqInt(1, Inner.Y, 'inner y');
  AssertEqInt(10, Inner.Width, 'inner w');
  AssertEqInt(4, Inner.Height, 'inner h');
end;

procedure Test_BlockInnerWithTitle;
var
  B: TBlock;
  Inner: TRect;
begin
  B := TBlock.Default.WithTitle('T');
  Inner := B.Inner(TRect.Make(0, 0, 10, 5));
  AssertEqInt(0, Inner.X, 'inner x');
  AssertEqInt(1, Inner.Y, 'title forces +1 y');
  AssertEqInt(10, Inner.Width, 'inner w');
  AssertEqInt(4, Inner.Height, 'inner h');
end;

// --- Group 14: Multi-style rendering ---

procedure Test_MultiColorRow;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    Buf.SetString(0, 0, 'AB', TStyle.Default.WithFg(clRed));
    Buf.SetString(2, 0, 'CD', TStyle.Default.WithFg(clGreen));
    Buf.SetString(4, 0, 'EF', TStyle.Default.WithFg(clBlue));
    CP := Buf.CellAt(0, 0);
    AssertEqInt(1, CP^.Fg.Index, 'red');
    CP := Buf.CellAt(2, 0);
    AssertEqInt(2, CP^.Fg.Index, 'green');
    CP := Buf.CellAt(4, 0);
    AssertEqInt(4, CP^.Fg.Index, 'blue');
    AssertEqStr('ABCDEF', Buf.RowAsString(0), 'content');
  finally
    Buf.Free;
  end;
end;

procedure Test_OverlappingSetString;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    Buf.SetString(0, 0, 'AAAAAAAAAA', TStyle.Default);
    Buf.SetString(3, 0, 'BBB', TStyle.Default);
    AssertEqStr('AAABBBAAAA', Buf.RowAsString(0), 'overlap');
  finally
    Buf.Free;
  end;
end;

// --- Group 15: ContentPtr usage (hot path pattern) ---

procedure Test_ContentPtrDirectAccess;
var
  Buf: TBuffer;
  Base: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Base := Buf.ContentPtr;
    CellSetSymbolAscii((Base + 0)^, 'A');
    CellSetSymbolAscii((Base + 4)^, 'E');
    CellSetSymbolAscii((Base + 5)^, 'F');
    AssertEqStr('A   E', Buf.RowAsString(0), 'row 0');
    AssertEqStr('F    ', Buf.RowAsString(1), 'row 1');
  finally
    Buf.Free;
  end;
end;

procedure Test_ContentPtrFullRow;
var
  Buf: TBuffer;
  Base: PCell;
  I: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Base := Buf.ContentPtr;
    for I := 0 to 4 do
      CellSetSymbolAscii((Base + I)^, AnsiChar(Ord('A') + I));
    AssertEqStr('ABCDE', Buf.RowAsString(0), 'full row via ptr');
  finally
    Buf.Free;
  end;
end;

// --- Registration ---

procedure RegisterCli888ScenarioTests;
begin
  RegisterTest('cli888 / title bar centered', @Test_TitleBarCentered);
  RegisterTest('cli888 / title bar with borders', @Test_TitleBarWithBorders);
  RegisterTest('cli888 / title bar full width', @Test_TitleBarFullWidth);
  RegisterTest('cli888 / message list single item', @Test_MessageListSingleItem);
  RegisterTest('cli888 / message list three items', @Test_MessageListThreeItems);
  RegisterTest('cli888 / message list highlight first', @Test_MessageListHighlightFirst);
  RegisterTest('cli888 / message list highlight middle', @Test_MessageListHighlightMiddle);
  RegisterTest('cli888 / message list scroll down', @Test_MessageListScrollDown);
  RegisterTest('cli888 / message list scroll to end', @Test_MessageListScrollToEnd);
  RegisterTest('cli888 / paragraph single line', @Test_ParagraphSingleLine);
  RegisterTest('cli888 / paragraph word wrap', @Test_ParagraphWordWrap);
  RegisterTest('cli888 / paragraph scroll Y', @Test_ParagraphScrollY);
  RegisterTest('cli888 / paragraph empty', @Test_ParagraphEmpty);
  RegisterTest('cli888 / layout vertical 3 rows', @Test_LayoutVertical3Rows);
  RegisterTest('cli888 / layout horizontal 3 cols', @Test_LayoutHorizontal3Cols);
  RegisterTest('cli888 / layout percentage split', @Test_LayoutPercentageSplit);
  RegisterTest('cli888 / layout main split', @Test_LayoutCli888MainSplit);
  RegisterTest('cli888 / status bar left', @Test_StatusBarLeftAligned);
  RegisterTest('cli888 / status bar right', @Test_StatusBarRightAligned);
  RegisterTest('cli888 / status bar both ends', @Test_StatusBarBothEnds);
  RegisterTest('cli888 / message bubble', @Test_MessageBubble);
  RegisterTest('cli888 / message bubble wrapped', @Test_MessageBubbleWrapped);
  RegisterTest('cli888 / input box empty', @Test_InputBoxEmpty);
  RegisterTest('cli888 / input box with text', @Test_InputBoxWithText);
  RegisterTest('cli888 / clear fills area', @Test_ClearFillsArea);
  RegisterTest('cli888 / buffer clips right', @Test_BufferSetStringClipsRight);
  RegisterTest('cli888 / buffer maxwidth', @Test_BufferSetStringNMaxWidth);
  RegisterTest('cli888 / buffer set style region', @Test_BufferSetStyleRegion);
  RegisterTest('cli888 / buffer diff identical', @Test_BufferDiffIdenticalIsEmpty);
  RegisterTest('cli888 / buffer diff single cell', @Test_BufferDiffSingleCellChange);
  RegisterTest('cli888 / buffer diff full row', @Test_BufferDiffFullRowChange);
  RegisterTest('cli888 / full screen layout', @Test_Cli888FullScreenLayout);
  RegisterTest('cli888 / split panels', @Test_Cli888SplitPanels);
  RegisterTest('cli888 / style fg only', @Test_StyleFgOnlyApplied);
  RegisterTest('cli888 / style bg only', @Test_StyleBgOnlyApplied);
  RegisterTest('cli888 / style bold modifier', @Test_StyleBoldModifier);
  RegisterTest('cli888 / style overwrite', @Test_StyleOverwrite);
  RegisterTest('cli888 / zero width area', @Test_ZeroWidthArea);
  RegisterTest('cli888 / single cell buffer', @Test_SingleCellBuffer);
  RegisterTest('cli888 / buffer reset', @Test_BufferResetClearsContent);
  RegisterTest('cli888 / list empty items', @Test_ListEmptyItems);
  RegisterTest('cli888 / paragraph hard break', @Test_ParagraphLongWordHardBreak);
  RegisterTest('cli888 / block inner all borders', @Test_BlockInnerAllBorders);
  RegisterTest('cli888 / block inner no borders', @Test_BlockInnerNoBorders);
  RegisterTest('cli888 / block inner top only', @Test_BlockInnerTopBorderOnly);
  RegisterTest('cli888 / block inner with title', @Test_BlockInnerWithTitle);
  RegisterTest('cli888 / multi color row', @Test_MultiColorRow);
  RegisterTest('cli888 / overlapping set string', @Test_OverlappingSetString);
  RegisterTest('cli888 / content ptr direct', @Test_ContentPtrDirectAccess);
  RegisterTest('cli888 / content ptr full row', @Test_ContentPtrFullRow);
end;

end.
