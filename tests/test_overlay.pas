unit test_overlay;

{$mode objfpc}{$H+}

interface

procedure RegisterOverlayTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_overlay;

procedure Test_EmptyOverlayMergesAsBase;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 5, 2));
  try
    Base.SetString(0, 0, 'hello', TStyle.Default);
    // Copy base into dest manually.
    Dest.SetString(0, 0, 'hello', TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertBufferEquals(Dest, ['hello', '     ']);
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlayCellOverridesBase;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
  C: TCell;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 5, 1));
  try
    Base.SetString(0, 0, 'aaaaa', TStyle.Default);
    Dest.SetString(0, 0, 'aaaaa', TStyle.Default);
    // Write 'X' at position 2 in overlay.
    C := CellEmpty;
    CellSetSymbolAscii(C, 'X');
    Ov.SetCell(2, 0, C);
    Ov.MergeInto(Base, Dest);
    AssertBufferEquals(Dest, ['aaXaa']);
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlaySetString;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 8, 1));
  try
    Base.SetString(0, 0, '........', TStyle.Default);
    Dest.SetString(0, 0, '........', TStyle.Default);
    Ov.SetString(2, 0, 'hi', TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertBufferEquals(Dest, ['..hi....']);
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlayClearMakesTransparent;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
  C: TCell;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    Base.SetString(0, 0, 'base', TStyle.Default);
    C := CellEmpty; CellSetSymbolAscii(C, 'Z');
    Ov.SetCell(0, 0, C);
    Ov.Clear;
    // After clear, overlay is transparent — merge should show base.
    Dest.SetString(0, 0, 'base', TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertBufferEquals(Dest, ['base']);
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlayDirtyFlag;
var
  Ov: TOverlayBuffer;
  C: TCell;
begin
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 3));
  try
    Ov.ClearDirty;
    AssertFalse(Ov.Dirty, 'not dirty after ClearDirty');
    C := CellEmpty;
    Ov.SetCell(1, 1, C);
    AssertTrue(Ov.Dirty, 'dirty after SetCell');
    Ov.ClearDirty;
    AssertFalse(Ov.Dirty, 'not dirty after second ClearDirty');
  finally
    Ov.Free;
  end;
end;

procedure Test_OverlaySetStringCJK;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 8, 1));
  try
    Base.SetString(0, 0, '........', TStyle.Default);
    Dest.SetString(0, 0, '........', TStyle.Default);
    Ov.SetString(1, 0, #$E4#$BD#$A0#$E5#$A5#$BD, TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertBufferEquals(Dest, ['.'+#$E4#$BD#$A0+#$E5#$A5#$BD+'...']);
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlayNonZeroOrigin;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
  C: TCell;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  Ov := TOverlayBuffer.Create(TRect.Make(3, 2, 4, 2));
  try
    Base.SetString(0, 0, '..........', TStyle.Default);
    Base.SetString(0, 2, '..........', TStyle.Default);
    Dest.SetString(0, 0, '..........', TStyle.Default);
    Dest.SetString(0, 2, '..........', TStyle.Default);
    C := CellEmpty;
    CellSetSymbolAscii(C, 'X');
    Ov.SetCell(4, 2, C);
    Ov.MergeInto(Base, Dest);
    AssertEqStr('X', CellGlyphAsString(Dest.CellAt(4, 2)^), 'overlay at (4,2)');
    AssertEqStr('.', CellGlyphAsString(Dest.CellAt(2, 2)^), 'base preserved at (2,2)');
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlaySetCellOutOfBounds;
var
  Ov: TOverlayBuffer;
  C: TCell;
begin
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 3));
  try
    Ov.ClearDirty;
    C := CellEmpty;
    CellSetSymbolAscii(C, 'X');
    Ov.SetCell(-1, 0, C);
    Ov.SetCell(0, -1, C);
    Ov.SetCell(5, 0, C);
    Ov.SetCell(0, 5, C);
    AssertFalse(Ov.Dirty, 'out of bounds writes do not mark dirty');
  finally
    Ov.Free;
  end;
end;

procedure Test_OverlayResizeClearsContent;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
begin
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    Ov.SetString(0, 0, 'test', TStyle.Default);
    Ov.Resize(TRect.Make(0, 0, 6, 2));
    Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
    Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
    Base.SetString(0, 0, 'aaaaaa', TStyle.Default);
    Dest.SetString(0, 0, 'aaaaaa', TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertBufferEquals(Dest, ['aaaaaa', '      ']);
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlaySetStyleOnEmpty;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
  St: TStyle;
  P: PCell;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    Base.SetString(0, 0, 'abcd', TStyle.Default);
    Dest.SetString(0, 0, 'abcd', TStyle.Default);
    St := TStyle.Default.WithFg(RgbColor(255, 0, 0));
    Ov.SetStyle(TRect.Make(1, 0, 2, 1), St);
    Ov.MergeInto(Base, Dest);
    P := Dest.CellAt(1, 0);
    AssertTrue(P <> nil, 'cell exists');
    AssertTrue(ColorEquals(P^.Fg, RgbColor(255, 0, 0)), 'fg is red');
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlayCJKClippedAtEdge;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 5, 1));
  try
    Base.SetString(0, 0, '.....', TStyle.Default);
    Dest.SetString(0, 0, '.....', TStyle.Default);
    Ov.SetString(4, 0, #$E4#$BD#$A0, TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertEqStr('.', CellGlyphAsString(Dest.CellAt(4, 0)^), 'CJK clipped at edge');
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure Test_OverlayMergePreservesUnmarked;
var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
begin
  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, 5, 1));
  try
    Base.SetString(0, 0, 'hello', TStyle.Default);
    Dest.SetString(0, 0, 'hello', TStyle.Default);
    Ov.SetString(0, 0, 'X', TStyle.Default);
    Ov.MergeInto(Base, Dest);
    AssertEqStr('e', CellGlyphAsString(Dest.CellAt(1, 0)^), 'unmarked cell preserved');
    AssertEqStr('X', CellGlyphAsString(Dest.CellAt(0, 0)^), 'marked cell overwritten');
  finally
    Ov.Free; Dest.Free; Base.Free;
  end;
end;

procedure RegisterOverlayTests;
begin
  RegisterTest('overlay / empty merges as base',       @Test_EmptyOverlayMergesAsBase);
  RegisterTest('overlay / cell overrides base',        @Test_OverlayCellOverridesBase);
  RegisterTest('overlay / SetString',                  @Test_OverlaySetString);
  RegisterTest('overlay / Clear makes transparent',    @Test_OverlayClearMakesTransparent);
  RegisterTest('overlay / dirty flag',                 @Test_OverlayDirtyFlag);
  RegisterTest('overlay / CJK double width',           @Test_OverlaySetStringCJK);
  RegisterTest('overlay / non-zero origin',            @Test_OverlayNonZeroOrigin);
  RegisterTest('overlay / SetCell out of bounds',      @Test_OverlaySetCellOutOfBounds);
  RegisterTest('overlay / Resize clears content',      @Test_OverlayResizeClearsContent);
  RegisterTest('overlay / SetStyle on empty',          @Test_OverlaySetStyleOnEmpty);
  RegisterTest('overlay / CJK clipped at edge',        @Test_OverlayCJKClippedAtEdge);
  RegisterTest('overlay / merge preserves unmarked',   @Test_OverlayMergePreservesUnmarked);
end;

end.
