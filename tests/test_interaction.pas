unit test_interaction;

{$mode objfpc}{$H+}

interface

procedure RegisterInteractionTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_event,
  ftui_interaction;

procedure Test_HitTestBasic;
var R: TRect;
begin
  R := TRect.Make(5, 5, 10, 10);
  AssertTrue(HitTest(R, 5, 5), '(5,5) top-left');
  AssertTrue(HitTest(R, 14, 14), '(14,14) bottom-right');
  AssertFalse(HitTest(R, 4, 5), '(4,5) left of');
  AssertFalse(HitTest(R, 15, 5), '(15,5) right of');
  AssertFalse(HitTest(R, 5, 15), '(5,15) below');
end;

procedure Test_HitTestEvent;
var R: TRect; Ev: TMouseEvent;
begin
  R := TRect.Make(0, 0, 80, 24);
  Ev.X := 40; Ev.Y := 12;
  AssertTrue(HitTestEvent(R, Ev), 'center hit');
  Ev.X := 80; Ev.Y := 0;
  AssertFalse(HitTestEvent(R, Ev), 'right edge exclusive');
end;

procedure Test_HoverChangeDetection;
var R: TRect;
begin
  R := TRect.Make(10, 10, 20, 10);
  AssertEqInt(Ord(hcEntered), Ord(DetectHoverChange(R, 0, 0, 15, 15)), 'enter');
  AssertEqInt(Ord(hcLeft), Ord(DetectHoverChange(R, 15, 15, 0, 0)), 'leave');
  AssertEqInt(Ord(hcStay), Ord(DetectHoverChange(R, 15, 15, 16, 16)), 'stay');
  AssertEqInt(Ord(hcNone), Ord(DetectHoverChange(R, 0, 0, 1, 1)), 'none (both outside)');
end;

procedure Test_PointerCapture;
var Cap: TPointerCapture;
begin
  Cap.Release;
  AssertFalse(Cap.Active, 'initially inactive');
  Cap.Acquire(Pointer(42), mbLeft);
  AssertTrue(Cap.Active, 'active after acquire');
  AssertEqInt(42, IntPtr(Cap.Target), 'target');
  Cap.Release;
  AssertFalse(Cap.Active, 'inactive after release');
  AssertTrue(Cap.Target = nil, 'target nil after release');
end;

procedure Test_InteractionSession;
var Sess: TInteractionSession;
begin
  Sess.State := ssNone;
  AssertFalse(Sess.IsActive, 'not active initially');
  Sess.Begin_(Pointer(99));
  AssertTrue(Sess.IsActive, 'active after begin');
  AssertEqInt(99, IntPtr(Sess.Target), 'target');
  Sess.Commit;
  AssertFalse(Sess.IsActive, 'not active after commit');
  AssertEqInt(Ord(ssCommitted), Ord(Sess.State), 'committed');

  Sess.Begin_(Pointer(100));
  Sess.Cancel;
  AssertFalse(Sess.IsActive, 'not active after cancel');
  AssertEqInt(Ord(ssCancelled), Ord(Sess.State), 'cancelled');
end;

procedure Test_SessionCancelOnlyWhenActive;
var Sess: TInteractionSession;
begin
  Sess.State := ssNone;
  Sess.Cancel;
  AssertEqInt(Ord(ssNone), Ord(Sess.State), 'cancel on none = no-op');
  Sess.Begin_(nil);
  Sess.Commit;
  Sess.Cancel;
  AssertEqInt(Ord(ssCommitted), Ord(Sess.State), 'cancel after commit = no-op');
end;

procedure RegisterInteractionTests;
begin
  RegisterTest('interaction / HitTest basic',          @Test_HitTestBasic);
  RegisterTest('interaction / HitTestEvent',           @Test_HitTestEvent);
  RegisterTest('interaction / hover change detection', @Test_HoverChangeDetection);
  RegisterTest('interaction / pointer capture',        @Test_PointerCapture);
  RegisterTest('interaction / session lifecycle',      @Test_InteractionSession);
  RegisterTest('interaction / cancel only when active',@Test_SessionCancelOnlyWhenActive);
end;

end.
