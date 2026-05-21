unit test_ansi_backend;

{$mode objfpc}{$H+}

interface

procedure RegisterAnsiBackendTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_ansi_backend;

function PendingAsString(B: TAnsiBackend): AnsiString;
begin
  if B.PendingLength = 0 then Exit('');
  SetLength(Result, B.PendingLength);
  Move(B.PendingBytes^, Result[1], B.PendingLength);
end;

procedure Test_DrawSingleAsciiPatch;
var
  Be: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Be := TAnsiBackend.Create(-1);                       // -1: not flushed in tests
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Curr.SetString(2, 0, 'X', TStyle.Default);
    Prev.Diff(Curr, Patches);
    AssertEqInt(1, Length(Patches), 'one patch');

    Be.DrawPatches(Patches);
    // Expect: MoveTo(2,0) -> SGR reset -> 'X'
    // (SGR comes because fg/bg are ckReset in CellEmpty -> gets emitted
    // as a default-everything reset.)
    AssertEqStr(#27'[1;3H' + #27'[0m' + 'X',
      PendingAsString(Be), 'move + sgr-reset + glyph');
  finally
    Curr.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure Test_AdjacentCellsReuseCursor;
var
  Be: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  S: AnsiString;
  CountMoveTo: Integer;
  I: Integer;
begin
  Be := TAnsiBackend.Create(-1);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    Curr.SetString(0, 0, 'abcdef', TStyle.Default);
    Prev.Diff(Curr, Patches);
    AssertEqInt(6, Length(Patches), 'six adjacent patches');

    Be.DrawPatches(Patches);
    S := PendingAsString(Be);

    // Should contain exactly one CSI moveto sequence (#27 '[' digits ';' digits 'H'),
    // since cells are adjacent.  Count by looking for 'H' preceded by ';' digits.
    CountMoveTo := 0;
    for I := 1 to Length(S) - 1 do
      if (S[I] = ';') and (Pos('H', Copy(S, I, 6)) > 0) then
        Inc(CountMoveTo);
    AssertEqInt(1, CountMoveTo, 'only one MoveTo for adjacent run');
  finally
    Curr.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure Test_StyleCacheMinimisesRepeats;
var
  Be: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  S: AnsiString;
  ResetCount, I: Integer;
begin
  Be := TAnsiBackend.Create(-1);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    Curr.SetString(0, 0, 'aaaa', TStyle.Default.WithFg(clRed));
    Prev.Diff(Curr, Patches);
    AssertEqInt(4, Length(Patches), 'four patches');

    Be.DrawPatches(Patches);
    S := PendingAsString(Be);

    // SGR reset (#27 '[' '0' 'm') must appear exactly once across the
    // whole run — same style for all 4 cells.
    ResetCount := 0;
    for I := 1 to Length(S) - 3 do
      if Copy(S, I, 4) = #27'[0m' then
        Inc(ResetCount);
    AssertEqInt(1, ResetCount, 'SGR 0 emitted only once for identical run');
  finally
    Curr.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure Test_FlushWithFdMinusOneFails;
var
  Be: TAnsiBackend;
  Ok: Boolean;
begin
  Be := TAnsiBackend.Create(-1);
  try
    Be.HideCursor;
    AssertTrue(Be.PendingLength > 0, 'have pending bytes');
    Ok := Be.Flush;
    AssertFalse(Ok, 'flush to fd=-1 returns False');
    AssertEqInt(0, Be.PendingLength, 'buffer reset after flush attempt');
  finally
    Be.Free;
  end;
end;

procedure Test_ColorChangeEmitsNewSgr;
var
  Be: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  S: AnsiString;
  ResetCount, I: Integer;
begin
  Be := TAnsiBackend.Create(-1);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    Curr.SetString(0, 0, 'A', TStyle.Default.WithFg(clRed));
    Curr.SetString(1, 0, 'B', TStyle.Default.WithFg(clGreen));
    Prev.Diff(Curr, Patches);
    Be.DrawPatches(Patches);
    S := PendingAsString(Be);
    ResetCount := 0;
    for I := 1 to Length(S) - 3 do
      if Copy(S, I, 4) = #27'[0m' then
        Inc(ResetCount);
    AssertEqInt(2, ResetCount, 'color change: two SGR resets');
  finally
    Curr.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure Test_ModifierEmitted;
var
  Be: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  S: AnsiString;
begin
  Be := TAnsiBackend.Create(-1);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    Curr.SetString(0, 0, 'B', TStyle.Default.WithModifier([mbBold]));
    Prev.Diff(Curr, Patches);
    Be.DrawPatches(Patches);
    S := PendingAsString(Be);
    AssertTrue(Pos(#27'[1m', S) > 0, 'bold modifier: SGR 1 emitted');
  finally
    Curr.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure Test_EmptyPatchesNoCrash;
var
  Be: TAnsiBackend;
  Patches: TDiffEntries;
begin
  Be := TAnsiBackend.Create(-1);
  try
    SetLength(Patches, 0);
    Be.DrawPatches(Patches);
    AssertEqInt(0, Be.PendingLength, 'empty patches: nothing emitted');
  finally
    Be.Free;
  end;
end;

procedure Test_NonAdjacentCellsEmitMoveTo;
var
  Be: TAnsiBackend;
  Patches: TDiffEntries;
  S: AnsiString;
  MoveCount, I: Integer;
begin
  Be := TAnsiBackend.Create(-1);
  try
    SetLength(Patches, 2);
    Patches[0].X := 0; Patches[0].Y := 0;
    Patches[0].Cell := CellEmpty;
    Patches[0].Cell.Glyph.Len := 1;
    Patches[0].Cell.Glyph.Bytes[0] := Ord('A');
    Patches[1].X := 5; Patches[1].Y := 2;
    Patches[1].Cell := CellEmpty;
    Patches[1].Cell.Glyph.Len := 1;
    Patches[1].Cell.Glyph.Bytes[0] := Ord('B');
    Be.DrawPatches(Patches);
    S := PendingAsString(Be);
    MoveCount := 0;
    for I := 1 to Length(S) - 1 do
      if S[I] = 'H' then Inc(MoveCount);
    AssertEqInt(2, MoveCount, 'non-adjacent: two MoveTo sequences');
  finally
    Be.Free;
  end;
end;

procedure Test_DiscardPendingClearsBuffer;
var
  Be: TAnsiBackend;
begin
  Be := TAnsiBackend.Create(-1);
  try
    Be.HideCursor;
    AssertTrue(Be.PendingLength > 0, 'has pending');
    Be.DiscardPending;
    AssertEqInt(0, Be.PendingLength, 'discard: buffer empty');
  finally
    Be.Free;
  end;
end;

procedure RegisterAnsiBackendTests;
begin
  RegisterTest('backend / draw single ascii patch',     @Test_DrawSingleAsciiPatch);
  RegisterTest('backend / adjacent cells reuse cursor', @Test_AdjacentCellsReuseCursor);
  RegisterTest('backend / style cache minimises repeats',@Test_StyleCacheMinimisesRepeats);
  RegisterTest('backend / Flush(-1) returns False',     @Test_FlushWithFdMinusOneFails);
  RegisterTest('backend / color change emits new sgr',  @Test_ColorChangeEmitsNewSgr);
  RegisterTest('backend / modifier emitted',            @Test_ModifierEmitted);
  RegisterTest('backend / empty patches no crash',      @Test_EmptyPatchesNoCrash);
  RegisterTest('backend / non-adjacent emit moveto',    @Test_NonAdjacentCellsEmitMoveTo);
  RegisterTest('backend / discard pending clears',      @Test_DiscardPendingClearsBuffer);
end;

end.
