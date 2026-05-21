unit test_event_loop;

{$mode objfpc}{$H+}

interface

procedure RegisterEventLoopTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_event,
  ftui_event_loop;

var
  GTickCount: Integer;
  GEventCount: Integer;
  GMsgCount: Integer;
  GStopAfter: Integer;
  GLoop: TEventLoop;

procedure TestTickHandler(TickCount: Integer);
begin
  Inc(GTickCount);
  if GTickCount >= GStopAfter then
    GLoop.Stop;
end;

procedure TestEventHandler(const Ev: TEvent);
begin
  Inc(GEventCount);
  if Ev.Kind = evKey then
    GLoop.Stop;
end;

procedure TestMsgHandler(Data: Pointer);
begin
  Inc(GMsgCount);
end;

function FakeNoPoll(TimeoutMs: Integer): TEvent;
begin
  Result.Kind := evNone;
end;

var
  FakeEventFired: Boolean;

function FakeKeyPoll(TimeoutMs: Integer): TEvent;
begin
  if not FakeEventFired then
  begin
    FakeEventFired := True;
    Result.Kind := evKey;
    Result.Key.Code := kcChar;
    Result.Key.Ch := Ord('x');
  end
  else
    Result.Kind := evNone;
end;

procedure Test_CreateAndDestroy;
var EL: TEventLoop;
begin
  EL := TEventLoop.Create(100);
  AssertEqInt(100, EL.TickIntervalMs, 'interval = 100');
  AssertTrue(not EL.Running, 'not running initially');
  EL.Free;
end;

procedure Test_TickFires;
begin
  GTickCount := 0;
  GStopAfter := 3;
  GLoop := TEventLoop.Create(0);
  GLoop.OnTick := @TestTickHandler;
  GLoop.Start(@FakeNoPoll);
  AssertEqInt(3, GTickCount, '3 ticks before stop');
  GLoop.Free;
end;

procedure Test_EventFires;
begin
  GEventCount := 0;
  FakeEventFired := False;
  GLoop := TEventLoop.Create(0);
  GLoop.OnEvent := @TestEventHandler;
  GLoop.Start(@FakeKeyPoll);
  AssertEqInt(1, GEventCount, '1 event received');
  GLoop.Free;
end;

procedure Test_PostMessage;
var EL: TEventLoop;
begin
  GMsgCount := 0;
  EL := TEventLoop.Create(100);
  EL.OnMessage := @TestMsgHandler;
  EL.PostMessage(nil);
  EL.PostMessage(nil);
  AssertTrue(EL.HasMessages, 'has messages');
  EL.DrainMessages;
  AssertEqInt(2, GMsgCount, '2 messages drained');
  AssertTrue(not EL.HasMessages, 'no messages after drain');
  EL.Free;
end;

procedure Test_StopEndsLoop;
begin
  GTickCount := 0;
  GStopAfter := 1;
  GLoop := TEventLoop.Create(0);
  GLoop.OnTick := @TestTickHandler;
  GLoop.Start(@FakeNoPoll);
  AssertTrue(not GLoop.Running, 'stopped');
  GLoop.Free;
end;

procedure RegisterEventLoopTests;
begin
  RegisterTest('event_loop / create and destroy', @Test_CreateAndDestroy);
  RegisterTest('event_loop / tick fires',         @Test_TickFires);
  RegisterTest('event_loop / event fires',        @Test_EventFires);
  RegisterTest('event_loop / post message',       @Test_PostMessage);
  RegisterTest('event_loop / stop ends loop',     @Test_StopEndsLoop);
end;

end.
