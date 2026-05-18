unit test_test_backend;

{$mode objfpc}{$H+}

interface

procedure RegisterTestBackendTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_buffer,
  ftui_test_backend;

procedure Test_InitialStateAndDefaults;
var
  Be: TTestBackend;
begin
  Be := TTestBackend.Create(TRect.Make(0, 0, 4, 2));
  try
    AssertTrue(Be.CursorVisible, 'cursor visible by default');
    AssertEqInt(0, Be.CursorX, 'cursor x');
    AssertEqInt(0, Be.CursorY, 'cursor y');
    AssertFalse(Be.OnAlternate, 'not on alt screen');
    AssertEqInt(4, Be.Buffer.Width, 'buffer width');
    AssertEqInt(2, Be.Buffer.Height, 'buffer height');
    AssertBufferEquals(Be.Buffer, ['    ', '    ']);
  finally
    Be.Free;
  end;
end;

procedure Test_DrawPatchesAppliesToBuffer;
var
  Be: TTestBackend;
  Prev, Next: TBuffer;
  Patches: TDiffEntries;
begin
  Be := TTestBackend.Create(TRect.Make(0, 0, 5, 1));
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  Next := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    Next.SetString(0, 0, 'hi', TStyle.Default.WithFg(clRed));
    Prev.Diff(Next, Patches);
    Be.DrawPatches(Patches);

    AssertBufferEquals(Be.Buffer, ['hi   ']);
    AssertEqInt(2, Be.CursorX, 'cursor advanced past last write');
  finally
    Next.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure Test_CursorAndAltScreenStateTracked;
var
  Be: TTestBackend;
begin
  Be := TTestBackend.Create(TRect.Make(0, 0, 3, 3));
  try
    Be.HideCursor;
    AssertFalse(Be.CursorVisible, 'hidden');

    Be.MoveTo(2, 1);
    AssertEqInt(2, Be.CursorX, 'cx');
    AssertEqInt(1, Be.CursorY, 'cy');

    Be.ShowCursor;
    AssertTrue(Be.CursorVisible, 'shown');

    Be.EnterAlternate;
    AssertTrue(Be.OnAlternate, 'on alt');
    Be.LeaveAlternate;
    AssertFalse(Be.OnAlternate, 'off alt');

    AssertTrue(Be.Flush, 'flush always succeeds for test backend');
  finally
    Be.Free;
  end;
end;

procedure Test_ClearScreenWipesBuffer;
var
  Be: TTestBackend;
  Prev, Next: TBuffer;
  Patches: TDiffEntries;
begin
  Be := TTestBackend.Create(TRect.Make(0, 0, 3, 1));
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  Next := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    Next.SetString(0, 0, 'abc', TStyle.Default);
    Prev.Diff(Next, Patches);
    Be.DrawPatches(Patches);
    AssertBufferEquals(Be.Buffer, ['abc']);

    Be.ClearScreen;
    AssertBufferEquals(Be.Buffer, ['   ']);
  finally
    Next.Free;
    Prev.Free;
    Be.Free;
  end;
end;

procedure RegisterTestBackendTests;
begin
  RegisterTest('test_backend / initial state',         @Test_InitialStateAndDefaults);
  RegisterTest('test_backend / DrawPatches applies',   @Test_DrawPatchesAppliesToBuffer);
  RegisterTest('test_backend / cursor + alt tracked',  @Test_CursorAndAltScreenStateTracked);
  RegisterTest('test_backend / ClearScreen wipes',     @Test_ClearScreenWipesBuffer);
end;

end.
