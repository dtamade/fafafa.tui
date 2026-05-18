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

procedure RegisterOverlayTests;
begin
  RegisterTest('overlay / empty merges as base',       @Test_EmptyOverlayMergesAsBase);
  RegisterTest('overlay / cell overrides base',        @Test_OverlayCellOverridesBase);
  RegisterTest('overlay / SetString',                  @Test_OverlaySetString);
  RegisterTest('overlay / Clear makes transparent',    @Test_OverlayClearMakesTransparent);
  RegisterTest('overlay / dirty flag',                 @Test_OverlayDirtyFlag);
end;

end.
