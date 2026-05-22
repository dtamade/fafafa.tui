unit test_task;

{$mode objfpc}{$H+}

interface

procedure RegisterTaskTests;

implementation

uses
  SysUtils, Classes,
  ftui_testkit,
  ftui_task,
  ftui_loading;

function SimpleReturnTask(const Ctx: TTaskContext): TTaskResult;
var
  P: PInteger;
begin
  GetMem(P, SizeOf(Integer));
  P^ := 42;
  Result.Data := P;
  Result.DataSize := SizeOf(Integer);
  Result.Error := '';
  Result.Status := tsCompleted;
end;

function ParamEchoTask(const Ctx: TTaskContext): TTaskResult;
var
  P: PInteger;
  V: Integer;
begin
  V := PInteger(Ctx.Param)^;
  GetMem(P, SizeOf(Integer));
  P^ := V * 2;
  Result.Data := P;
  Result.DataSize := SizeOf(Integer);
  Result.Error := '';
  Result.Status := tsCompleted;
end;

function SlowCancellableTask(const Ctx: TTaskContext): TTaskResult;
var
  I: Integer;
begin
  for I := 0 to 999 do
  begin
    if IsCancelled(Ctx) then
    begin
      Result.Status := tsCancelled;
      Result.Data := nil;
      Result.DataSize := 0;
      Result.Error := '';
      Exit;
    end;
    Sleep(1);
  end;
  Result.Status := tsCompleted;
  Result.Data := nil;
  Result.DataSize := 0;
  Result.Error := '';
end;

function FailingTask(const Ctx: TTaskContext): TTaskResult;
begin
  raise Exception.Create('test error');
  Result.Status := tsCompleted;
end;

procedure Test_SpawnAndPoll;
var
  Mgr: TTaskManager;
  Id: TTaskId;
  Res: TTaskResult;
  Spec: TTaskSpec;
  I: Integer;
begin
  Mgr := TTaskManager.Create;
  try
    Spec := MakeSpec(@SimpleReturnTask, nil, 0, 'simple');
    Id := Mgr.Spawn(Spec);
    AssertTrue(Id > 0, 'Spawn returns valid Id');
    for I := 0 to 999 do
    begin
      if Mgr.Poll(Id, Res) then Break;
      Sleep(1);
    end;
    AssertTrue(Mgr.Poll(Id, Res), 'Task completed');
    AssertTrue(Res.Status = tsCompleted, 'Status is completed');
    AssertEqInt(42, PInteger(Res.Data)^, 'Result data = 42');
    FreeMem(Res.Data);
  finally
    Mgr.Free;
  end;
end;

procedure Test_ParamCopy;
var
  Mgr: TTaskManager;
  Id: TTaskId;
  Res: TTaskResult;
  Spec: TTaskSpec;
  Param: Integer;
  I: Integer;
begin
  Mgr := TTaskManager.Create;
  try
    Param := 21;
    Spec := MakeSpec(@ParamEchoTask, @Param, SizeOf(Param), 'echo');
    Id := Mgr.Spawn(Spec);
    Param := 999;
    for I := 0 to 999 do
    begin
      if Mgr.Poll(Id, Res) then Break;
      Sleep(1);
    end;
    AssertTrue(Mgr.Poll(Id, Res), 'Task completed');
    AssertEqInt(42, PInteger(Res.Data)^, 'Param was copied (21*2=42 not 999*2)');
    FreeMem(Res.Data);
  finally
    Mgr.Free;
  end;
end;

procedure Test_Cancel;
var
  Mgr: TTaskManager;
  Id: TTaskId;
  Res: TTaskResult;
  Spec: TTaskSpec;
  I: Integer;
begin
  Mgr := TTaskManager.Create;
  try
    Spec := MakeSpec(@SlowCancellableTask, nil, 0, 'slow');
    Id := Mgr.Spawn(Spec);
    Sleep(20);
    Mgr.Cancel(Id);
    for I := 0 to 999 do
    begin
      if Mgr.Poll(Id, Res) then Break;
      Sleep(1);
    end;
    AssertTrue(Mgr.Poll(Id, Res), 'Cancelled task completed');
    AssertTrue(Res.Status = tsCancelled, 'Status is cancelled');
  finally
    Mgr.Free;
  end;
end;

procedure Test_ExceptionPropagation;
var
  Mgr: TTaskManager;
  Id: TTaskId;
  Res: TTaskResult;
  Spec: TTaskSpec;
  I: Integer;
begin
  Mgr := TTaskManager.Create;
  try
    Spec := MakeSpec(@FailingTask, nil, 0, 'fail');
    Id := Mgr.Spawn(Spec);
    for I := 0 to 999 do
    begin
      if Mgr.Poll(Id, Res) then Break;
      Sleep(1);
    end;
    AssertTrue(Mgr.Poll(Id, Res), 'Failed task completed');
    AssertTrue(Res.Status = tsFailed, 'Status is failed');
    AssertTrue(Pos('test error', Res.Error) > 0, 'Error message propagated');
  finally
    Mgr.Free;
  end;
end;

procedure Test_DrainCompleted;
var
  Mgr: TTaskManager;
  Slots: array[0..31] of TCompletionSlot;
  Spec: TTaskSpec;
  N, I: Integer;
begin
  Mgr := TTaskManager.Create;
  try
    for I := 0 to 3 do
    begin
      Spec := MakeSpec(@SimpleReturnTask, nil, 0, 'batch');
      Mgr.Spawn(Spec);
    end;
    Sleep(100);
    N := Mgr.DrainCompleted(Slots, 32);
    AssertTrue(N = 4, 'Drained 4 completions');
    for I := 0 to N - 1 do
    begin
      AssertTrue(Slots[I].Result.Status = tsCompleted, 'All completed');
      FreeMem(Slots[I].Result.Data);
    end;
  finally
    Mgr.Free;
  end;
end;

procedure Test_LoadingGroupPhases;
var
  G: TLoadingGroup;
  Slots: array[0..0] of TCompletionSlot;
begin
  G := TLoadingGroup.Empty;
  AssertTrue(G.AllDone, 'Empty group is all done');

  G.Start(0, 1, 1000);
  AssertTrue(G.GetPhase(0) = lpLoading, 'Phase is loading after start');
  AssertTrue(G.AnyLoading, 'AnyLoading is true');
  AssertFalse(G.AllDone, 'Not all done while loading');

  Slots[0].Id := 1;
  Slots[0].Result.Status := tsCompleted;
  Slots[0].Result.Data := nil;
  Slots[0].Result.DataSize := 0;
  Slots[0].Result.Error := '';
  G.Update(Slots, 1);
  AssertTrue(G.GetPhase(0) = lpSuccess, 'Phase is success after completion');
  AssertTrue(G.AllDone, 'All done after completion');
end;

procedure Test_LoadingGroupError;
var
  G: TLoadingGroup;
  Slots: array[0..0] of TCompletionSlot;
begin
  G := TLoadingGroup.Empty;
  G.Start(0, 5, 2000);

  Slots[0].Id := 5;
  Slots[0].Result.Status := tsFailed;
  Slots[0].Result.Data := nil;
  Slots[0].Result.DataSize := 0;
  Slots[0].Result.Error := 'network timeout';
  G.Update(Slots, 1);
  AssertTrue(G.GetPhase(0) = lpError, 'Phase is error after failure');
  AssertTrue(G.AnyError, 'AnyError is true');
  AssertTrue(Pos('network', G.Items[0].Error) > 0, 'Error message stored');
end;

procedure Test_MakeSpec;
var
  Spec: TTaskSpec;
  Param: Integer;
begin
  Param := 7;
  Spec := MakeSpec(@SimpleReturnTask, @Param, SizeOf(Param), 'test');
  AssertTrue(Spec.Func = @SimpleReturnTask, 'Func assigned');
  AssertTrue(Spec.Param = @Param, 'Param pointer');
  AssertEqInt(4, Integer(Spec.ParamSize), 'ParamSize = 4');
  AssertEqStr('test', Spec.Name, 'Name assigned');
end;

procedure RegisterTaskTests;
begin
  RegisterTest('task / Spawn and Poll',        @Test_SpawnAndPoll);
  RegisterTest('task / Param copy safety',     @Test_ParamCopy);
  RegisterTest('task / Cancel',                @Test_Cancel);
  RegisterTest('task / Exception propagation', @Test_ExceptionPropagation);
  RegisterTest('task / DrainCompleted batch',  @Test_DrainCompleted);
  RegisterTest('task / LoadingGroup phases',   @Test_LoadingGroupPhases);
  RegisterTest('task / LoadingGroup error',    @Test_LoadingGroupError);
  RegisterTest('task / MakeSpec helper',       @Test_MakeSpec);
end;

end.
