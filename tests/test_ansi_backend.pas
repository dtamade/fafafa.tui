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

procedure RegisterAnsiBackendTests;
begin
  RegisterTest('backend / draw single ascii patch',     @Test_DrawSingleAsciiPatch);
  RegisterTest('backend / adjacent cells reuse cursor', @Test_AdjacentCellsReuseCursor);
  RegisterTest('backend / style cache minimises repeats',@Test_StyleCacheMinimisesRepeats);
  RegisterTest('backend / Flush(-1) returns False',     @Test_FlushWithFdMinusOneFails);
end;

end.
