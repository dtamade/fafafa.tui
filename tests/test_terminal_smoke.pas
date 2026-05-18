unit test_terminal_smoke;

// Light-touch tests for ftui_terminal: just exercise construction
// and Area without actually entering raw mode (the test runner
// doesn't have a controlling tty).  EnterTui's tty / termios paths
// are covered by the full_demo example running interactively.

{$mode objfpc}{$H+}

interface

procedure RegisterTerminalSmokeTests;

implementation

uses
  ftui_testkit,
  ftui_terminal;

procedure Test_ConstructAndDestruct;
var
  T: TTerminal;
begin
  T := TTerminal.Create;
  try
    AssertFalse(T.ShouldQuit, 'fresh terminal should not be quitting');
    T.RequestQuit;
    AssertTrue(T.ShouldQuit, 'after RequestQuit -> quitting');
  finally
    T.Free;
  end;
end;

procedure RegisterTerminalSmokeTests;
begin
  RegisterTest('terminal / construct + ShouldQuit toggles', @Test_ConstructAndDestruct);
end;

end.
