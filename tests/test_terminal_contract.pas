unit test_terminal_contract;

// Contract tests for TTerminal main path behaviors.
// These call TTerminal.PostProcessEvent and PromoteMousePos (test seams,
// not part of consumer contract) to verify main-path behaviors without a tty.

{$mode objfpc}{$H+}

interface

procedure RegisterTerminalContractTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_event,
  ftui_input_parser,
  ftui_interaction,
  ftui_terminal;

procedure Test_BareEscResolvesAfterTimeout;
var
  Ev: TEvent;
  Consumed: Integer;
  R: TParseResult;
  Buf: array[0..0] of Byte;
begin
  Buf[0] := 27;
  R := ParseOne(Buf[0], 1, False, Ev, Consumed);
  AssertEqInt(Ord(prNeedMore), Ord(R), 'bare ESC + AtEOF=False -> NeedMore');
  R := ParseOne(Buf[0], 1, True, Ev, Consumed);
  AssertEqInt(Ord(prSuccess), Ord(R), 'bare ESC + AtEOF=True -> Success');
  AssertEqInt(27, Buf[0], 'buf preserved');
  AssertEqInt(Ord(kcEsc), Ord(Ev.Key.Code), 'resolves to kcEsc');
end;

procedure Test_EscCancelsActiveSession;
var
  Ev: TEvent;
  Term: TTerminal;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
begin
  Term := TTerminal.Create;
  try
    Cap := Term.Capture;
    Sess := Term.Session;
    Cap.Acquire(Pointer(1), mbLeft);
    Sess.Begin_(Pointer(1));
    Term.Capture := Cap;
    Term.Session := Sess;

    Ev := KeyCodeEvent(kcEsc, []);
    Term.PostProcessEvent(Ev);

    AssertFalse(Term.Session.IsActive, 'session cancelled');
    AssertEqInt(Ord(ssCancelled), Ord(Term.Session.State), 'state=cancelled');
    AssertFalse(Term.Capture.Active, 'capture released');
  finally
    Term.Free;
  end;
end;

procedure Test_MouseUpAutoReleasesCapture;
var
  Ev: TEvent;
  Term: TTerminal;
  Cap: TPointerCapture;
  Sess: TInteractionSession;
begin
  Term := TTerminal.Create;
  try
    Cap := Term.Capture;
    Sess := Term.Session;
    Cap.Acquire(Pointer(2), mbLeft);
    Sess.Begin_(Pointer(2));
    Term.Capture := Cap;
    Term.Session := Sess;

    Ev := MouseEvent(mkUp, mbLeft, 10, 10, []);
    Term.PostProcessEvent(Ev);

    AssertFalse(Term.Capture.Active, 'capture released on MouseUp');
    AssertEqInt(Ord(ssCommitted), Ord(Term.Session.State), 'session committed');
  finally
    Term.Free;
  end;
end;

procedure Test_PrevMousePosPromotedOnNextPoll;
var
  Ev: TEvent;
  Term: TTerminal;
begin
  Term := TTerminal.Create;
  try
    AssertEqInt(0, Term.PrevMousePos.X, 'initial X=0');
    Ev := MouseEvent(mkMoved, mbNone, 20, 15, []);
    Term.PostProcessEvent(Ev);
    AssertEqInt(0, Term.PrevMousePos.X, 'after first event: still 0');
    Term.PromoteMousePos;
    AssertEqInt(20, Term.PrevMousePos.X, 'after promote: X=20');
    AssertEqInt(15, Term.PrevMousePos.Y, 'after promote: Y=15');
    Ev := MouseEvent(mkMoved, mbNone, 30, 25, []);
    Term.PostProcessEvent(Ev);
    AssertEqInt(20, Term.PrevMousePos.X, 'after second event: still 20');
    Term.PromoteMousePos;
    AssertEqInt(30, Term.PrevMousePos.X, 'after second promote: X=30');
  finally
    Term.Free;
  end;
end;

procedure Test_EscWithoutSessionPassesThrough;
var
  Ev: TEvent;
  Term: TTerminal;
begin
  Term := TTerminal.Create;
  try
    Ev := KeyCodeEvent(kcEsc, []);
    Term.PostProcessEvent(Ev);
    AssertEqInt(Ord(ssNone), Ord(Term.Session.State), 'session unchanged');
    AssertFalse(Term.Capture.Active, 'capture still inactive');
    AssertEqInt(Ord(kcEsc), Ord(Ev.Key.Code), 'event preserved');
  finally
    Term.Free;
  end;
end;

procedure Test_MouseUpWithoutCaptureIsNoop;
var
  Ev: TEvent;
  Term: TTerminal;
begin
  Term := TTerminal.Create;
  try
    Ev := MouseEvent(mkUp, mbLeft, 30, 20, []);
    Term.PostProcessEvent(Ev);
    // PrevMousePos not yet promoted (happens at next PollEvent start).
    AssertEqInt(0, Term.PrevMousePos.X, 'PrevMousePos not yet promoted');
    AssertFalse(Term.Capture.Active, 'capture still inactive');
    AssertEqInt(Ord(ssNone), Ord(Term.Session.State), 'session unchanged');
  finally
    Term.Free;
  end;
end;

procedure RegisterTerminalContractTests;
begin
  RegisterTest('contract / bare Esc resolves after timeout',    @Test_BareEscResolvesAfterTimeout);
  RegisterTest('contract / Esc cancels active session',         @Test_EscCancelsActiveSession);
  RegisterTest('contract / MouseUp auto-releases capture',      @Test_MouseUpAutoReleasesCapture);
  RegisterTest('contract / PrevMousePos promoted on next PollEvent',@Test_PrevMousePosPromotedOnNextPoll);
  RegisterTest('contract / Esc without session passes through', @Test_EscWithoutSessionPassesThrough);
  RegisterTest('contract / MouseUp without capture is noop',    @Test_MouseUpWithoutCaptureIsNoop);
end;

end.
