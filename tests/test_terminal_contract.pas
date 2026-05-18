unit test_terminal_contract;

// Contract tests for TTerminal main path behaviors.
// These test the PostProcessEvent logic and Esc resolution
// without requiring a real tty (they inject bytes directly
// into the parser to verify behavior).

{$mode objfpc}{$H+}

interface

procedure RegisterTerminalContractTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_event,
  ftui_input_parser,
  ftui_interaction;

// Simulate PostProcessEvent logic on a parsed event.
// This mirrors what TTerminal.PostProcessEvent does.
procedure SimulatePostProcess(var Ev: TEvent;
  var Capture: TPointerCapture; var Session: TInteractionSession;
  var PrevPos: TPosition);
begin
  case Ev.Kind of
    evMouse:
      begin
        PrevPos.X := Ev.Mouse.X;
        PrevPos.Y := Ev.Mouse.Y;
        if (Ev.Mouse.Kind = mkUp) and Capture.Active then
        begin
          if Session.IsActive then Session.Commit;
          Capture.Release;
        end;
      end;
    evKey:
      if (Ev.Key.Code = kcEsc) and Session.IsActive then
      begin
        Session.Cancel;
        Capture.Release;
      end;
  end;
end;

procedure Test_BareEscResolvesAfterTimeout;
var
  Ev: TEvent;
  Consumed: Integer;
  R: TParseResult;
  Buf: array[0..0] of Byte;
begin
  // With AtEOF=False, bare ESC returns NeedMore.
  Buf[0] := 27;
  R := ParseOne(Buf[0], 1, False, Ev, Consumed);
  AssertEqInt(Ord(prNeedMore), Ord(R), 'bare ESC + AtEOF=False -> NeedMore');

  // With AtEOF=True (simulating timeout), bare ESC resolves to kcEsc.
  R := ParseOne(Buf[0], 1, True, Ev, Consumed);
  AssertEqInt(Ord(prSuccess), Ord(R), 'bare ESC + AtEOF=True -> Success');
  AssertEqInt(Ord(kcEsc), Ord(Ev.Key.Code), 'resolves to kcEsc');
  AssertEqInt(1, Consumed, 'consumes 1 byte');
end;

procedure Test_EscCancelsActiveSession;
var
  Ev: TEvent;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
  Prev: TPosition;
begin
  Cap.Release;
  Sess.State := ssNone;
  Prev.X := 0; Prev.Y := 0;

  // Start a session + capture.
  Cap.Acquire(Pointer(1), mbLeft);
  Sess.Begin_(Pointer(1));
  AssertTrue(Sess.IsActive, 'session active');
  AssertTrue(Cap.Active, 'capture active');

  // Simulate Esc event.
  Ev := KeyCodeEvent(kcEsc, []);
  SimulatePostProcess(Ev, Cap, Sess, Prev);

  AssertFalse(Sess.IsActive, 'session cancelled by Esc');
  AssertEqInt(Ord(ssCancelled), Ord(Sess.State), 'state = cancelled');
  AssertFalse(Cap.Active, 'capture released by Esc');
end;

procedure Test_MouseUpAutoReleasesCapture;
var
  Ev: TEvent;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
  Prev: TPosition;
begin
  Cap.Release;
  Sess.State := ssNone;
  Prev.X := 0; Prev.Y := 0;

  Cap.Acquire(Pointer(2), mbLeft);
  Sess.Begin_(Pointer(2));

  // Simulate MouseUp.
  Ev := MouseEvent(mkUp, mbLeft, 10, 10, []);
  SimulatePostProcess(Ev, Cap, Sess, Prev);

  AssertFalse(Cap.Active, 'capture released on MouseUp');
  AssertEqInt(Ord(ssCommitted), Ord(Sess.State), 'session committed on MouseUp');
end;

procedure Test_PrevMousePosUpdatedOnMouseEvent;
var
  Ev: TEvent;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
  Prev: TPosition;
begin
  Cap.Release;
  Sess.State := ssNone;
  Prev.X := 5; Prev.Y := 5;

  Ev := MouseEvent(mkMoved, mbNone, 20, 15, []);
  SimulatePostProcess(Ev, Cap, Sess, Prev);

  AssertEqInt(20, Prev.X, 'PrevMousePos.X updated');
  AssertEqInt(15, Prev.Y, 'PrevMousePos.Y updated');
end;

procedure Test_EscWithoutSessionPassesThrough;
var
  Ev: TEvent;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
  Prev: TPosition;
begin
  Cap.Release;
  Sess.State := ssNone;
  Prev.X := 0; Prev.Y := 0;

  // No active session — Esc should not change anything.
  Ev := KeyCodeEvent(kcEsc, []);
  SimulatePostProcess(Ev, Cap, Sess, Prev);

  AssertEqInt(Ord(ssNone), Ord(Sess.State), 'session unchanged');
  AssertFalse(Cap.Active, 'capture still inactive');
  // Event kind unchanged — consumer gets kcEsc to handle (e.g. quit).
  AssertEqInt(Ord(kcEsc), Ord(Ev.Key.Code), 'event preserved');
end;

procedure Test_MouseUpWithoutCaptureIsNoop;
var
  Ev: TEvent;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
  Prev: TPosition;
begin
  Cap.Release;
  Sess.State := ssNone;
  Prev.X := 0; Prev.Y := 0;

  // MouseUp without capture — should just update PrevMousePos.
  Ev := MouseEvent(mkUp, mbLeft, 30, 20, []);
  SimulatePostProcess(Ev, Cap, Sess, Prev);

  AssertEqInt(30, Prev.X, 'PrevMousePos updated');
  AssertFalse(Cap.Active, 'capture still inactive');
  AssertEqInt(Ord(ssNone), Ord(Sess.State), 'session unchanged');
end;

procedure RegisterTerminalContractTests;
begin
  RegisterTest('contract / bare Esc resolves after timeout',    @Test_BareEscResolvesAfterTimeout);
  RegisterTest('contract / Esc cancels active session',         @Test_EscCancelsActiveSession);
  RegisterTest('contract / MouseUp auto-releases capture',      @Test_MouseUpAutoReleasesCapture);
  RegisterTest('contract / PrevMousePos updated on mouse event',@Test_PrevMousePosUpdatedOnMouseEvent);
  RegisterTest('contract / Esc without session passes through', @Test_EscWithoutSessionPassesThrough);
  RegisterTest('contract / MouseUp without capture is noop',    @Test_MouseUpWithoutCaptureIsNoop);
end;

end.
