unit test_terminal;

{$mode objfpc}{$H+}

interface

procedure RegisterTerminalTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer;

procedure Test_DiffEmptyBuffersNoCrash;
var
  A, B: TBuffer;
  Patches: TDiffEntries;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    A.Diff(B, Patches);
    AssertEqInt(0, Length(Patches), 'empty buffers: zero patches');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure Test_DiffIdenticalBuffersZeroPatches;
var
  A, B: TBuffer;
  Patches: TDiffEntries;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    A.SetString(0, 0, 'hello', TStyle.Default);
    B.SetString(0, 0, 'hello', TStyle.Default);
    A.Diff(B, Patches);
    AssertEqInt(0, Length(Patches), 'identical content: zero patches');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure Test_DiffDifferentContentProducesPatches;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    Prev.SetString(0, 0, 'aaaa', TStyle.Default);
    Curr.SetString(0, 0, 'bbbb', TStyle.Default);
    Prev.Diff(Curr, Patches);
    AssertTrue(Length(Patches) > 0, 'different content: has patches');
    AssertTrue(Length(Patches) <= 4, 'different content: at most 4 changed cells');
  finally
    Prev.Free;
    Curr.Free;
  end;
end;

procedure Test_DiffIntoReusesArray;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  Count1, Count2: Integer;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    SetLength(Patches, 0);
    Curr.SetString(0, 0, 'hello', TStyle.Default);
    Count1 := Prev.DiffInto(Curr, Patches);
    AssertTrue(Count1 > 0, 'diffinto frame1: has patches');
    AssertTrue(Length(Patches) >= Count1, 'diffinto frame1: array grew');

    Prev.SetString(0, 0, 'hello', TStyle.Default);
    Count2 := Prev.DiffInto(Curr, Patches);
    AssertEqInt(0, Count2, 'diffinto frame2: identical = zero patches');
  finally
    Prev.Free;
    Curr.Free;
  end;
end;

procedure Test_DiffSizeMismatchFullRedraw;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    Prev.Diff(Curr, Patches);
    AssertEqInt(20 * 5, Length(Patches), 'size mismatch: full redraw');
  finally
    Prev.Free;
    Curr.Free;
  end;
end;

procedure Test_ResizeKeepsOverlap;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    Buf.SetString(2, 1, 'XY', TStyle.Default);
    Buf.Resize(TRect.Make(0, 0, 20, 10));
    AssertEqInt(20, Buf.Width, 'resize: new width');
    AssertEqInt(10, Buf.Height, 'resize: new height');
    CP := Buf.CellAt(2, 1);
    AssertTrue(CP <> nil, 'resize: overlap cell exists');
    AssertTrue(CP^.Glyph.Bytes[0] = Ord('X'), 'resize: overlap content preserved');
  finally
    Buf.Free;
  end;
end;

procedure Test_ResizeShrinkClips;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    Buf.SetString(8, 4, 'Z', TStyle.Default);
    Buf.Resize(TRect.Make(0, 0, 5, 3));
    AssertEqInt(5, Buf.Width, 'shrink: new width');
    AssertEqInt(3, Buf.Height, 'shrink: new height');
    CP := Buf.CellAt(8, 4);
    AssertTrue(CP = nil, 'shrink: old cell out of bounds');
  finally
    Buf.Free;
  end;
end;

procedure Test_ResetForcesFullDiff;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Prev.Reset;
    Curr.SetString(0, 0, ' ', TStyle.Default);
    Prev.Diff(Curr, Patches);
    AssertTrue(Length(Patches) > 0, 'reset prev: forces diff even for spaces');
  finally
    Prev.Free;
    Curr.Free;
  end;
end;

procedure Test_DiffWideCellSkipsTrailing;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  I: Integer;
  HasSkip: Boolean;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    // Write a CJK character (width=2) at position 0
    Curr.SetString(0, 0, #$E4#$B8#$AD, TStyle.Default); // 中 (U+4E2D)
    Prev.Diff(Curr, Patches);
    // Should produce patch for the leading cell but NOT the trailing (skip) cell
    HasSkip := False;
    for I := 0 to High(Patches) do
      if Patches[I].Cell.Skip then HasSkip := True;
    AssertFalse(HasSkip, 'wide char: no skip cells in patches');
  finally
    Prev.Free;
    Curr.Free;
  end;
end;

procedure Test_MultiFrameDiffCorrectness;
var
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  Count: Integer;
  Tmp: TBuffer;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    SetLength(Patches, 0);

    // Frame 1: write "AAA"
    Curr.Reset;
    Curr.SetString(0, 0, 'AAA', TStyle.Default);
    Count := Prev.DiffInto(Curr, Patches);
    AssertTrue(Count > 0, 'frame1: has patches');

    // Swap
    Tmp := Prev; Prev := Curr; Curr := Tmp;

    // Frame 2: write "ABA" (only middle changed)
    Curr.Reset;
    Curr.SetString(0, 0, 'ABA', TStyle.Default);
    Count := Prev.DiffInto(Curr, Patches);
    AssertTrue(Count >= 1, 'frame2: at least 1 patch for B');
    AssertTrue(Count <= 3, 'frame2: at most 3 patches');

    // Swap
    Tmp := Prev; Prev := Curr; Curr := Tmp;

    // Frame 3: identical to frame 2
    Curr.Reset;
    Curr.SetString(0, 0, 'ABA', TStyle.Default);
    Count := Prev.DiffInto(Curr, Patches);
    AssertEqInt(0, Count, 'frame3: no change = zero patches');
  finally
    Prev.Free;
    Curr.Free;
  end;
end;

procedure Test_ContentPtrNilOnEmpty;
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    AssertTrue(Buf.ContentPtr = nil, 'empty buffer: ContentPtr = nil');
  finally
    Buf.Free;
  end;
end;

procedure Test_SetStringBeyondAreaNoOp;
var
  Buf: TBuffer;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Buf.SetString(0, 5, 'out of bounds', TStyle.Default);
    CP := Buf.CellAt(0, 5);
    AssertTrue(CP = nil, 'write beyond area: no crash, cell nil');
  finally
    Buf.Free;
  end;
end;

procedure Test_DiffIntoEmptyBufferNoCrash;
var
  A, B: TBuffer;
  Patches: TDiffEntries;
  Count: Integer;
begin
  A := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  B := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    SetLength(Patches, 0);
    Count := A.DiffInto(B, Patches);
    AssertEqInt(0, Count, 'diffinto empty: zero patches');
  finally
    A.Free;
    B.Free;
  end;
end;

procedure RegisterTerminalTests;
begin
  RegisterTest('terminal / diff empty buffers no crash',       @Test_DiffEmptyBuffersNoCrash);
  RegisterTest('terminal / diff identical zero patches',       @Test_DiffIdenticalBuffersZeroPatches);
  RegisterTest('terminal / diff different produces patches',   @Test_DiffDifferentContentProducesPatches);
  RegisterTest('terminal / diffinto reuses array',             @Test_DiffIntoReusesArray);
  RegisterTest('terminal / diff size mismatch full redraw',    @Test_DiffSizeMismatchFullRedraw);
  RegisterTest('terminal / resize keeps overlap',              @Test_ResizeKeepsOverlap);
  RegisterTest('terminal / resize shrink clips',               @Test_ResizeShrinkClips);
  RegisterTest('terminal / reset forces full diff',            @Test_ResetForcesFullDiff);
  RegisterTest('terminal / diff wide cell skips trailing',     @Test_DiffWideCellSkipsTrailing);
  RegisterTest('terminal / multi-frame diff correctness',      @Test_MultiFrameDiffCorrectness);
  RegisterTest('terminal / contentptr nil on empty',           @Test_ContentPtrNilOnEmpty);
  RegisterTest('terminal / setstring beyond area no-op',       @Test_SetStringBeyondAreaNoOp);
  RegisterTest('terminal / diffinto empty no crash',           @Test_DiffIntoEmptyBufferNoCrash);
end;

end.
