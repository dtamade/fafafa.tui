unit test_list;

{$mode objfpc}{$H+}

interface

procedure RegisterListTests;

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
  ftui_list;

procedure Test_RendersThreeItemsLeftAligned;
var
  Buf: TBuffer;
  L: TList;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 4));
  try
    L := TList.FromStrings(['alpha', 'beta', 'gamma']);
    L.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'alpha   ',
      'beta    ',
      'gamma   ',
      '        '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_TruncatesItemsWiderThanArea;
var
  Buf: TBuffer;
  L: TList;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    L := TList.FromStrings(['hello world', 'short']);
    L.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      'hell',
      'shor'
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_HighlightSymbolGutterShownOnlyForSelected;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 3));
  try
    L := TList.FromStrings(['a', 'b', 'c']).WithHighlightSymbol('> ');
    S := TListState.Empty;
    S.Select(1);
    L.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, [
      '  a     ',
      '> b     ',
      '  c     '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_HighlightStyleAppliedToSelectedRowOnly;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    L := TList.FromStrings(['x', 'y'])
          .WithHighlightStyle(TStyle.Default.WithBg(clCyan));
    S := TListState.Empty;
    S.Select(0);
    L.RenderStateful(Buf.Area, Buf, S);

    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clCyan, CP^.Bg), 'selected row bg = cyan');
    CP := Buf.CellAt(0, 1);
    AssertEqInt(Ord(ckReset), Ord(CP^.Bg.Kind), 'unselected row bg untouched');
  finally
    Buf.Free;
  end;
end;

procedure Test_NoSelectionLeavesGutterOff;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
  try
    L := TList.FromStrings(['a', 'b']).WithHighlightSymbol('> ');
    S := TListState.Empty;     // no selection
    L.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, [
      'a     ',
      'b     '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_ScrollWhenSelectionPastEnd;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
  try
    L := TList.FromStrings(['a', 'b', 'c', 'd', 'e']);
    S := TListState.Empty;
    S.Select(4);
    L.RenderStateful(Buf.Area, Buf, S);
    AssertEqInt(3, S.Offset, 'offset moved to 3 to keep last visible');
    AssertBufferEquals(Buf, [
      'd     ',
      'e     '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_ScrollWhenSelectionBeforeStart;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
  try
    L := TList.FromStrings(['a', 'b', 'c', 'd', 'e']);
    S := TListState.Empty;
    S.Offset := 3;
    S.Select(0);
    L.RenderStateful(Buf.Area, Buf, S);
    AssertEqInt(0, S.Offset, 'offset rolled back to 0');
    AssertBufferEquals(Buf, [
      'a     ',
      'b     '
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_EmptyListClearsSelection;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    L := TList.FromStrings([]);
    S := TListState.Empty;
    S.Select(2);
    L.RenderStateful(Buf.Area, Buf, S);
    AssertFalse(S.HasSelection, 'empty list clears selection');
    AssertBufferEquals(Buf, ['    ', '    ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_ListInsideBlock;
var
  Buf: TBuffer;
  L: TList;
const
  H = #$E2#$94#$80;
  V = #$E2#$94#$82;
  TL = #$E2#$94#$8C;
  TR = #$E2#$94#$90;
  BL = #$E2#$94#$94;
  BR = #$E2#$94#$98;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 7, 4));
  try
    L := TList.FromStrings(['foo', 'bar'])
          .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle('lst'));
    L.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, [
      TL + 'lst' + H + H + TR,
      V + 'foo  ' + V,
      V + 'bar  ' + V,
      BL + H + H + H + H + H + BR
    ]);
  finally
    Buf.Free;
  end;
end;

procedure Test_OutOfBoundsSelectionClampsToLast;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    L := TList.FromStrings(['a', 'b']);
    S := TListState.Empty;
    S.Select(99);
    L.RenderStateful(Buf.Area, Buf, S);
    AssertEqInt(1, S.Selected, 'selected clamped to last index');
  finally
    Buf.Free;
  end;
end;

procedure Test_SingleItemList;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    L := TList.FromStrings(['only']);
    S := TListState.Empty;
    S.HasSelection := True;
    S.Selected := 0;
    L.RenderStateful(Buf.Area, Buf, S);
    AssertEqInt(0, S.Selected, 'selected stays 0');
    AssertEqInt(0, S.Offset, 'offset stays 0');
  finally
    Buf.Free;
  end;
end;

procedure Test_ZeroHeightNoCrash;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 0));
  try
    L := TList.FromStrings(['a', 'b', 'c']);
    S := TListState.Empty;
    S.HasSelection := True;
    S.Selected := 1;
    L.RenderStateful(Buf.Area, Buf, S);
    AssertTrue(True, 'no crash on zero height');
  finally
    Buf.Free;
  end;
end;

procedure Test_ScrollDownThenUp;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 3));
  try
    L := TList.FromStrings(['a', 'b', 'c', 'd', 'e']);
    S := TListState.Empty;
    S.HasSelection := True;
    S.Selected := 4;
    L.RenderStateful(Buf.Area, Buf, S);
    AssertTrue(S.Offset > 0, 'scrolled down');
    S.Selected := 0;
    L.RenderStateful(Buf.Area, Buf, S);
    AssertEqInt(0, S.Offset, 'scrolled back to top');
  finally
    Buf.Free;
  end;
end;

procedure Test_MidScrollOffsetStable;
var
  Buf: TBuffer;
  L: TList;
  S: TListState;
  PrevOffset: Integer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 3));
  try
    L := TList.FromStrings(['a', 'b', 'c', 'd', 'e']);
    S := TListState.Empty;
    S.HasSelection := True;
    S.Selected := 3;
    L.RenderStateful(Buf.Area, Buf, S);
    PrevOffset := S.Offset;
    S.Selected := 2;
    L.RenderStateful(Buf.Area, Buf, S);
    AssertTrue(S.Offset <= PrevOffset, 'offset does not increase when moving up within window');
  finally
    Buf.Free;
  end;
end;

procedure RegisterListTests;
begin
  RegisterTest('list / renders three items left-aligned',   @Test_RendersThreeItemsLeftAligned);
  RegisterTest('list / truncates items wider than area',     @Test_TruncatesItemsWiderThanArea);
  RegisterTest('list / highlight symbol in gutter only',     @Test_HighlightSymbolGutterShownOnlyForSelected);
  RegisterTest('list / highlight style on selected row',     @Test_HighlightStyleAppliedToSelectedRowOnly);
  RegisterTest('list / no selection -> no gutter',           @Test_NoSelectionLeavesGutterOff);
  RegisterTest('list / scroll when selection past end',      @Test_ScrollWhenSelectionPastEnd);
  RegisterTest('list / scroll when selection before start',  @Test_ScrollWhenSelectionBeforeStart);
  RegisterTest('list / empty list clears selection',         @Test_EmptyListClearsSelection);
  RegisterTest('list / inside block with title',             @Test_ListInsideBlock);
  RegisterTest('list / out-of-bounds selection clamps',      @Test_OutOfBoundsSelectionClampsToLast);
  RegisterTest('list / single item',                         @Test_SingleItemList);
  RegisterTest('list / zero height no crash',                @Test_ZeroHeightNoCrash);
  RegisterTest('list / scroll down then up',                 @Test_ScrollDownThenUp);
  RegisterTest('list / mid scroll offset stable',            @Test_MidScrollOffsetStable);
end;

end.
