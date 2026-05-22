unit ftui_task;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes;

const
  TASK_QUEUE_CAPACITY = 32;
  MAX_CONCURRENT_TASKS = 8;

type
  TTaskId = UInt32;

  TTaskStatus = (
    tsQueued,
    tsRunning,
    tsCompleted,
    tsFailed,
    tsCancelled
  );

  PCancelToken = ^TCancelToken;
  TCancelToken = record
    FCancelled: LongInt;
  end;

  PTaskContext = ^TTaskContext;
  TTaskContext = record
    Param: Pointer;
    ParamSize: UInt32;
    Cancel: PCancelToken;
  end;

  TTaskResult = record
    Data: Pointer;
    DataSize: UInt32;
    Error: ShortString;
    Status: TTaskStatus;
  end;

  TTaskFunc = function(const Ctx: TTaskContext): TTaskResult;

  TTaskSpec = record
    Func: TTaskFunc;
    Param: Pointer;
    ParamSize: UInt32;
    Name: ShortString;
  end;

  TCompletionSlot = record
    Id: TTaskId;
    Result: TTaskResult;
  end;

  TTaskManager = class;

  TTaskThread = class(TThread)
  private
    FId: TTaskId;
    FFunc: TTaskFunc;
    FContext: TTaskContext;
    FManager: TTaskManager;
    FDoneEvent: PRTLEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(AManager: TTaskManager; AId: TTaskId;
                       AFunc: TTaskFunc; const ACtx: TTaskContext);
    destructor Destroy; override;
  end;

  TActiveTask = record
    Id: TTaskId;
    Thread: TTaskThread;
    Cancel: TCancelToken;
    Status: TTaskStatus;
  end;

  TPendingTask = record
    Id: TTaskId;
    Func: TTaskFunc;
    ParamCopy: Pointer;
    ParamSize: UInt32;
  end;

  TTaskManager = class
  private
    FLock: TRTLCriticalSection;
    FCompletions: array[0..TASK_QUEUE_CAPACITY - 1] of TCompletionSlot;
    FCompHead: Integer;
    FCompTail: Integer;
    FCompCount: Integer;
    FActive: array[0..MAX_CONCURRENT_TASKS - 1] of TActiveTask;
    FActiveCount: Integer;
    FPending: array[0..TASK_QUEUE_CAPACITY - 1] of TPendingTask;
    FPendHead: Integer;
    FPendTail: Integer;
    FPendCount: Integer;
    FNextId: LongInt;
    FShuttingDown: Boolean;
    procedure LaunchInSlot(Slot: Integer; Id: TTaskId; Func: TTaskFunc;
                           Param: Pointer; ParamSize: UInt32);
    procedure ScheduleNext;
    function FindFreeSlot: Integer;
    function FindActiveById(Id: TTaskId): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Spawn(const Spec: TTaskSpec): TTaskId;
    function Poll(Id: TTaskId; out Res: TTaskResult): Boolean;
    function DrainCompleted(out Slots: array of TCompletionSlot;
                            MaxCount: Integer): Integer;
    procedure Cancel(Id: TTaskId);
    procedure ShutdownAndWait(TimeoutMs: UInt32);
    function ActiveCount: Integer; inline;
    function PendingCount: Integer; inline;
    procedure OnThreadComplete(Id: TTaskId; const Res: TTaskResult);
  end;

function IsCancelled(const Ctx: TTaskContext): Boolean; inline;
function MakeSpec(Func: TTaskFunc; Param: Pointer; ParamSize: UInt32;
                  const Name: ShortString): TTaskSpec;

implementation

function IsCancelled(const Ctx: TTaskContext): Boolean;
begin
  Result := InterlockedCompareExchange(Ctx.Cancel^.FCancelled, 0, 0) = 1;
end;

function MakeSpec(Func: TTaskFunc; Param: Pointer; ParamSize: UInt32;
                  const Name: ShortString): TTaskSpec;
begin
  Result.Func := Func;
  Result.Param := Param;
  Result.ParamSize := ParamSize;
  Result.Name := Name;
end;

{ TTaskThread }

constructor TTaskThread.Create(AManager: TTaskManager; AId: TTaskId;
                               AFunc: TTaskFunc; const ACtx: TTaskContext);
begin
  FreeOnTerminate := False;
  FManager := AManager;
  FId := AId;
  FFunc := AFunc;
  FContext := ACtx;
  FDoneEvent := RTLEventCreate;
  inherited Create(True);
end;

destructor TTaskThread.Destroy;
begin
  RTLEventDestroy(FDoneEvent);
  inherited;
end;

procedure TTaskThread.Execute;
var
  Res: TTaskResult;
begin
  try
    Res := FFunc(FContext);
  except
    on E: Exception do
    begin
      Res.Status := tsFailed;
      Res.Data := nil;
      Res.DataSize := 0;
      Res.Error := E.Message;
    end;
  end;
  if InterlockedCompareExchange(FContext.Cancel^.FCancelled, 0, 0) = 1 then
    Res.Status := tsCancelled;
  FManager.OnThreadComplete(FId, Res);
  if FContext.Param <> nil then
    FreeMem(FContext.Param);
  RTLEventSetEvent(FDoneEvent);
end;

{ TTaskManager }

constructor TTaskManager.Create;
var
  I: Integer;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FCompHead := 0;
  FCompTail := 0;
  FCompCount := 0;
  FActiveCount := 0;
  FPendHead := 0;
  FPendTail := 0;
  FPendCount := 0;
  FNextId := 0;
  FShuttingDown := False;
  for I := 0 to MAX_CONCURRENT_TASKS - 1 do
  begin
    FActive[I].Id := 0;
    FActive[I].Thread := nil;
    FActive[I].Status := tsQueued;
  end;
end;

{ PLACEHOLDER_IMPL2 }

destructor TTaskManager.Destroy;
begin
  ShutdownAndWait(2000);
  DoneCriticalSection(FLock);
  inherited;
end;

function TTaskManager.FindFreeSlot: Integer;
var
  I: Integer;
begin
  for I := 0 to MAX_CONCURRENT_TASKS - 1 do
    if FActive[I].Thread = nil then
      Exit(I);
  Result := -1;
end;

function TTaskManager.FindActiveById(Id: TTaskId): Integer;
var
  I: Integer;
begin
  for I := 0 to MAX_CONCURRENT_TASKS - 1 do
    if (FActive[I].Thread <> nil) and (FActive[I].Id = Id) then
      Exit(I);
  Result := -1;
end;

procedure TTaskManager.LaunchInSlot(Slot: Integer; Id: TTaskId;
  Func: TTaskFunc; Param: Pointer; ParamSize: UInt32);
var
  Ctx: TTaskContext;
begin
  FActive[Slot].Id := Id;
  FActive[Slot].Cancel.FCancelled := 0;
  FActive[Slot].Status := tsRunning;
  Inc(FActiveCount);
  Ctx.Param := Param;
  Ctx.ParamSize := ParamSize;
  Ctx.Cancel := @FActive[Slot].Cancel;
  FActive[Slot].Thread := TTaskThread.Create(Self, Id, Func, Ctx);
  FActive[Slot].Thread.Start;
end;

procedure TTaskManager.ScheduleNext;
var
  Slot, I, LaunchCount: Integer;
  P: TPendingTask;
  Ctx: TTaskContext;
  ToLaunch: array[0..MAX_CONCURRENT_TASKS - 1] of record
    Slot: Integer;
    Id: TTaskId;
    Func: TTaskFunc;
    Param: Pointer;
    ParamSize: UInt32;
  end;
begin
  LaunchCount := 0;
  EnterCriticalSection(FLock);
  try
    while (FPendCount > 0) and (FActiveCount < MAX_CONCURRENT_TASKS) do
    begin
      Slot := FindFreeSlot;
      if Slot < 0 then Break;
      P := FPending[FPendHead];
      FPendHead := (FPendHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FPendCount);
      FActive[Slot].Id := P.Id;
      FActive[Slot].Cancel.FCancelled := 0;
      FActive[Slot].Status := tsRunning;
      FActive[Slot].Thread := nil;
      Inc(FActiveCount);
      ToLaunch[LaunchCount].Slot := Slot;
      ToLaunch[LaunchCount].Id := P.Id;
      ToLaunch[LaunchCount].Func := P.Func;
      ToLaunch[LaunchCount].Param := P.ParamCopy;
      ToLaunch[LaunchCount].ParamSize := P.ParamSize;
      Inc(LaunchCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  for I := 0 to LaunchCount - 1 do
  begin
    Ctx.Param := ToLaunch[I].Param;
    Ctx.ParamSize := ToLaunch[I].ParamSize;
    Ctx.Cancel := @FActive[ToLaunch[I].Slot].Cancel;
    FActive[ToLaunch[I].Slot].Thread := TTaskThread.Create(Self, ToLaunch[I].Id, ToLaunch[I].Func, Ctx);
    FActive[ToLaunch[I].Slot].Thread.Start;
  end;
end;

function TTaskManager.Spawn(const Spec: TTaskSpec): TTaskId;
var
  Id: TTaskId;
  ParamCopy: Pointer;
  Slot: Integer;
  ShouldLaunch: Boolean;
  Ctx: TTaskContext;
begin
  Id := TTaskId(InterlockedIncrement(FNextId));
  ParamCopy := nil;
  if (Spec.Param <> nil) and (Spec.ParamSize > 0) then
  begin
    GetMem(ParamCopy, Spec.ParamSize);
    Move(Spec.Param^, ParamCopy^, Spec.ParamSize);
  end;

  ShouldLaunch := False;
  Slot := -1;
  EnterCriticalSection(FLock);
  try
    if FShuttingDown then
    begin
      if ParamCopy <> nil then FreeMem(ParamCopy);
      Result := 0;
      Exit;
    end;
    Slot := FindFreeSlot;
    if (Slot >= 0) and (FActiveCount < MAX_CONCURRENT_TASKS) then
    begin
      FActive[Slot].Id := Id;
      FActive[Slot].Cancel.FCancelled := 0;
      FActive[Slot].Status := tsRunning;
      FActive[Slot].Thread := nil;
      Inc(FActiveCount);
      ShouldLaunch := True;
    end
    else
    begin
      if FPendCount >= TASK_QUEUE_CAPACITY then
      begin
        if ParamCopy <> nil then FreeMem(ParamCopy);
        Result := 0;
        Exit;
      end;
      FPending[FPendTail].Id := Id;
      FPending[FPendTail].Func := Spec.Func;
      FPending[FPendTail].ParamCopy := ParamCopy;
      FPending[FPendTail].ParamSize := Spec.ParamSize;
      FPendTail := (FPendTail + 1) mod TASK_QUEUE_CAPACITY;
      Inc(FPendCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;

  if ShouldLaunch then
  begin
    Ctx.Param := ParamCopy;
    Ctx.ParamSize := Spec.ParamSize;
    Ctx.Cancel := @FActive[Slot].Cancel;
    FActive[Slot].Thread := TTaskThread.Create(Self, Id, Spec.Func, Ctx);
    FActive[Slot].Thread.Start;
  end;

  Result := Id;
end;

{ PLACEHOLDER_IMPL3 }

procedure TTaskManager.OnThreadComplete(Id: TTaskId; const Res: TTaskResult);
var
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    I := FindActiveById(Id);
    if I >= 0 then
    begin
      FActive[I].Thread := nil;
      FActive[I].Status := Res.Status;
      Dec(FActiveCount);
    end;
    if FCompCount < TASK_QUEUE_CAPACITY then
    begin
      FCompletions[FCompTail].Id := Id;
      FCompletions[FCompTail].Result := Res;
      FCompTail := (FCompTail + 1) mod TASK_QUEUE_CAPACITY;
      Inc(FCompCount);
    end
    else
    begin
      {$IFDEF DEBUG}
      Assert(False, 'ftui_task: completion queue full, result dropped');
      {$ENDIF}
      if Res.Data <> nil then
        FreeMem(Res.Data);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTaskManager.Poll(Id: TTaskId; out Res: TTaskResult): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  EnterCriticalSection(FLock);
  try
    J := FCompHead;
    for I := 0 to FCompCount - 1 do
    begin
      if FCompletions[J].Id = Id then
      begin
        Res := FCompletions[J].Result;
        Result := True;
        Exit;
      end;
      J := (J + 1) mod TASK_QUEUE_CAPACITY;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTaskManager.DrainCompleted(out Slots: array of TCompletionSlot;
                                      MaxCount: Integer): Integer;
var
  Count: Integer;
begin
  Count := 0;
  EnterCriticalSection(FLock);
  try
    while (FCompCount > 0) and (Count < MaxCount) do
    begin
      Slots[Count] := FCompletions[FCompHead];
      FCompHead := (FCompHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FCompCount);
      Inc(Count);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  if Count > 0 then
    ScheduleNext;
  Result := Count;
end;

procedure TTaskManager.Cancel(Id: TTaskId);
var
  I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    I := FindActiveById(Id);
    if I >= 0 then
      InterlockedExchange(FActive[I].Cancel.FCancelled, 1);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTaskManager.ShutdownAndWait(TimeoutMs: UInt32);
var
  I: Integer;
  Threads: array[0..MAX_CONCURRENT_TASKS - 1] of TTaskThread;
  ThreadCount: Integer;
begin
  ThreadCount := 0;
  EnterCriticalSection(FLock);
  try
    FShuttingDown := True;
    for I := 0 to MAX_CONCURRENT_TASKS - 1 do
    begin
      if FActive[I].Thread <> nil then
      begin
        InterlockedExchange(FActive[I].Cancel.FCancelled, 1);
        Threads[ThreadCount] := FActive[I].Thread;
        Inc(ThreadCount);
      end;
    end;
    for I := 0 to FPendCount - 1 do
    begin
      if FPending[(FPendHead + I) mod TASK_QUEUE_CAPACITY].ParamCopy <> nil then
        FreeMem(FPending[(FPendHead + I) mod TASK_QUEUE_CAPACITY].ParamCopy);
    end;
    FPendCount := 0;
  finally
    LeaveCriticalSection(FLock);
  end;

  for I := 0 to ThreadCount - 1 do
  begin
    RTLEventWaitFor(Threads[I].FDoneEvent, TimeoutMs);
    Threads[I].Free;
  end;

  EnterCriticalSection(FLock);
  try
    for I := 0 to MAX_CONCURRENT_TASKS - 1 do
      FActive[I].Thread := nil;
    FActiveCount := 0;
    while FCompCount > 0 do
    begin
      if FCompletions[FCompHead].Result.Data <> nil then
        FreeMem(FCompletions[FCompHead].Result.Data);
      FCompHead := (FCompHead + 1) mod TASK_QUEUE_CAPACITY;
      Dec(FCompCount);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTaskManager.ActiveCount: Integer;
begin
  Result := FActiveCount;
end;

function TTaskManager.PendingCount: Integer;
begin
  Result := FPendCount;
end;

end.
