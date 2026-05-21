unit test_notification_center;
{$mode objfpc}{$H+}
interface
procedure RegisterNotificationCenterTests;
implementation
uses ftui_testkit, ftui_rect, ftui_style, ftui_buffer, ftui_notification_center;

procedure Test_PushAndCount;
var NC: TNotificationCenter;
begin
  NC := TNotificationCenter.Create;
  AssertEqInt(0, NC.Count, 'empty');
  NC.Push(TNotification.Make('Hello', nlInfo));
  AssertEqInt(1, NC.Count, 'one');
  NC.Push(TNotification.Make('Error', nlError));
  AssertEqInt(2, NC.Count, 'two');
  NC.Free;
end;

procedure Test_UnreadCount;
var NC: TNotificationCenter;
begin
  NC := TNotificationCenter.Create;
  NC.Push(TNotification.Make('A', nlInfo));
  NC.Push(TNotification.Make('B', nlWarning));
  AssertEqInt(2, NC.UnreadCount, 'all unread');
  NC.MarkRead(0);
  AssertEqInt(1, NC.UnreadCount, 'one unread');
  NC.MarkAllRead;
  AssertEqInt(0, NC.UnreadCount, 'none unread');
  NC.Free;
end;

procedure Test_Clear;
var NC: TNotificationCenter;
begin
  NC := TNotificationCenter.Create;
  NC.Push(TNotification.Make('X', nlSuccess));
  NC.Clear;
  AssertEqInt(0, NC.Count, 'cleared');
  NC.Free;
end;

procedure Test_RenderWhenVisible;
var
  NC: TNotificationCenter;
  Buf: TBuffer;
  Area: TRect;
  State: TNotificationCenterState;
begin
  Area := TRect.Make(0, 0, 50, 10);
  Buf := TBuffer.CreateEmpty(Area);
  NC := TNotificationCenter.Create;
  NC.Width := 30;
  NC.Push(TNotification.Make('Alert!', nlError));
  State.Visible := True;
  State.Selected := 0;
  State.ScrollY := 0;
  NC.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Alert!', Buf.RowAsString(1)) > 0, 'notification visible');
  NC.Free;
  Buf.Free;
end;

procedure Test_HiddenNoop;
var
  NC: TNotificationCenter;
  Buf: TBuffer;
  Area: TRect;
  State: TNotificationCenterState;
begin
  Area := TRect.Make(0, 0, 50, 10);
  Buf := TBuffer.CreateEmpty(Area);
  NC := TNotificationCenter.Create;
  NC.Push(TNotification.Make('Hidden', nlInfo));
  State.Visible := False;
  State.Selected := 0;
  State.ScrollY := 0;
  NC.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Hidden', Buf.RowAsString(1)) = 0, 'not rendered when hidden');
  NC.Free;
  Buf.Free;
end;

procedure RegisterNotificationCenterTests;
begin
  RegisterTest('notif_center / push and count', @Test_PushAndCount);
  RegisterTest('notif_center / unread count',   @Test_UnreadCount);
  RegisterTest('notif_center / clear',          @Test_Clear);
  RegisterTest('notif_center / render visible', @Test_RenderWhenVisible);
  RegisterTest('notif_center / hidden noop',    @Test_HiddenNoop);
end;
end.
