unit ftui_event_loop;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

uses
  ftui_event;

type
  TTickHandler = procedure(TickCount: Integer);
  TEventHandler = procedure(const Ev: TEvent);
  TMessageHandler = procedure(Data: Pointer);
  TPollEventFunc = function(TimeoutMs: Integer): TEvent;

  PMessage = ^TMessage;
  TMessage = record
    Data: Pointer;
    Next: PMessage;
  end;

  TEventLoop = class
  private
    FRunning: Boolean;
    FTickIntervalMs: Integer;
    FTickCount: Integer;
    FOnTick: TTickHandler;
    FOnEvent: TEventHandler;
    FOnMessage: TMessageHandler;
    FMessageHead: PMessage;
    FMessageTail: PMessage;
  public
    constructor Create(TickIntervalMs: Integer);
    destructor Destroy; override;

    procedure PostMessage(Data: Pointer);
    procedure DrainMessages;
    function HasMessages: Boolean;

    property OnTick: TTickHandler read FOnTick write FOnTick;
    property OnEvent: TEventHandler read FOnEvent write FOnEvent;
    property OnMessage: TMessageHandler read FOnMessage write FOnMessage;
    property Running: Boolean read FRunning;
    property TickCount: Integer read FTickCount;
    property TickIntervalMs: Integer read FTickIntervalMs write FTickIntervalMs;

    procedure Start(PollEvent: TPollEventFunc);
    procedure Stop;
  end;

implementation

constructor TEventLoop.Create(TickIntervalMs: Integer);
begin
  inherited Create;
  FTickIntervalMs := TickIntervalMs;
  FTickCount := 0;
  FRunning := False;
  FOnTick := nil;
  FOnEvent := nil;
  FOnMessage := nil;
  FMessageHead := nil;
  FMessageTail := nil;
end;

destructor TEventLoop.Destroy;
var P, Next: PMessage;
begin
  P := FMessageHead;
  while P <> nil do
  begin
    Next := P^.Next;
    Dispose(P);
    P := Next;
  end;
  inherited;
end;

procedure TEventLoop.PostMessage(Data: Pointer);
var Msg: PMessage;
begin
  New(Msg);
  Msg^.Data := Data;
  Msg^.Next := nil;
  if FMessageTail <> nil then
    FMessageTail^.Next := Msg
  else
    FMessageHead := Msg;
  FMessageTail := Msg;
end;

procedure TEventLoop.DrainMessages;
var P, Next: PMessage;
begin
  P := FMessageHead;
  FMessageHead := nil;
  FMessageTail := nil;
  while P <> nil do
  begin
    Next := P^.Next;
    if Assigned(FOnMessage) then
      FOnMessage(P^.Data);
    Dispose(P);
    P := Next;
  end;
end;

function TEventLoop.HasMessages: Boolean;
begin
  Result := FMessageHead <> nil;
end;

procedure TEventLoop.Start(PollEvent: TPollEventFunc);
var Ev: TEvent;
begin
  FRunning := True;
  FTickCount := 0;
  while FRunning do
  begin
    Ev := PollEvent(FTickIntervalMs);

    if Ev.Kind <> evNone then
    begin
      if Assigned(FOnEvent) then
        FOnEvent(Ev);
    end
    else
    begin
      Inc(FTickCount);
      if Assigned(FOnTick) then
        FOnTick(FTickCount);
    end;

    DrainMessages;
  end;
end;

procedure TEventLoop.Stop;
begin
  FRunning := False;
end;

end.
