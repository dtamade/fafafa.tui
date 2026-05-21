unit ftui_app;

{$mode objfpc}{$H+}{$inline on}

interface

uses
  ftui_rect,
  ftui_event,
  ftui_terminal,
  ftui_focus,
  ftui_frame_budget;

type
  TApp = class;

  TAppRenderProc = procedure(App: TApp; var Frame: TFrame) of object;
  TAppEventProc  = procedure(App: TApp; const Ev: TEvent) of object;
  TAppTickProc   = procedure(App: TApp; TickCount: Integer) of object;

  TApp = class
  private
    FTerminal: TTerminal;
    FFocus: TFocusManager;
    FBudget: TFrameBudget;
    FUseFocus: Boolean;
    FUseBudget: Boolean;
    FTickInterval: Integer;
    FTickCount: Integer;
    FShouldQuit: Boolean;
    FOnRender: TAppRenderProc;
    FOnEvent: TAppEventProc;
    FOnTick: TAppTickProc;
  protected
    procedure Render(var Frame: TFrame); virtual;
    procedure HandleEvent(const Ev: TEvent); virtual;
    procedure OnTick; virtual;
    procedure OnInit; virtual;
    procedure OnDestroy; virtual;
    function IsQuitEvent(const Ev: TEvent): Boolean; virtual;
    function DoEnterTui: Boolean; virtual;
    procedure DoLeaveTui; virtual;
    function DoPollEvent: TEvent; virtual;
    function DoBeginFrame: TFrame; virtual;
    procedure DoEndFrame(const F: TFrame); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
    procedure Quit;
    procedure EnableFocus;
    procedure EnableBudget(BudgetMs: Double);
    property Terminal: TTerminal read FTerminal;
    property Focus: TFocusManager read FFocus;
    property Budget: TFrameBudget read FBudget;
    property TickInterval: Integer read FTickInterval write FTickInterval;
    property TickCount: Integer read FTickCount;
    property OnRenderCb: TAppRenderProc read FOnRender write FOnRender;
    property OnEventCb: TAppEventProc read FOnEvent write FOnEvent;
    property OnTickCb: TAppTickProc read FOnTick write FOnTick;
  end;

implementation

constructor TApp.Create;
begin
  inherited Create;
  FTerminal := TTerminal.Create;
  FFocus := nil;
  FUseFocus := False;
  FUseBudget := False;
  FTickInterval := -1;
  FTickCount := 0;
  FShouldQuit := False;
  FOnRender := nil;
  FOnEvent := nil;
  FOnTick := nil;
end;

destructor TApp.Destroy;
begin
  FFocus.Free;
  FTerminal.Free;
  inherited;
end;

procedure TApp.EnableFocus;
begin
  if FFocus = nil then
    FFocus := TFocusManager.Create;
  FUseFocus := True;
end;

procedure TApp.EnableBudget(BudgetMs: Double);
begin
  FBudget := TFrameBudget.Create(BudgetMs);
  FUseBudget := True;
end;

procedure TApp.Quit;
begin
  FShouldQuit := True;
  FTerminal.RequestQuit;
end;

function TApp.DoEnterTui: Boolean;
begin
  Result := FTerminal.EnterTui;
end;

procedure TApp.DoLeaveTui;
begin
  FTerminal.LeaveTui;
end;

function TApp.DoPollEvent: TEvent;
begin
  Result := FTerminal.PollEvent(FTickInterval);
end;

function TApp.DoBeginFrame: TFrame;
begin
  Result := FTerminal.BeginFrame;
end;

procedure TApp.DoEndFrame(const F: TFrame);
begin
  FTerminal.EndFrame(F);
end;

procedure TApp.Run;
var
  Frame: TFrame;
  Ev: TEvent;
begin
  if not DoEnterTui then
  begin
    WriteLn(StdErr, 'ftui: not a terminal');
    Halt(1);
  end;
  try
    OnInit;
    while not FShouldQuit do
    begin
      if FUseBudget then FBudget.BeginFrame;
      if FUseFocus then FFocus.BeginFrame;
      Frame := DoBeginFrame;
      if Assigned(FOnRender) then
        FOnRender(Self, Frame)
      else
        Render(Frame);
      DoEndFrame(Frame);
      if FUseBudget then FBudget.EndFrame;
      Ev := DoPollEvent;
      if Ev.Kind = evNone then
      begin
        Inc(FTickCount);
        if Assigned(FOnTick) then
          FOnTick(Self, FTickCount)
        else
          OnTick;
      end
      else
      begin
        if IsQuitEvent(Ev) then
          FShouldQuit := True
        else if Assigned(FOnEvent) then
          FOnEvent(Self, Ev)
        else
          HandleEvent(Ev);
      end;
    end;
  finally
    OnDestroy;
    DoLeaveTui;
  end;
end;

function TApp.IsQuitEvent(const Ev: TEvent): Boolean;
begin
  Result := False;
  if Ev.Kind <> evKey then Exit;
  if not (kmCtrl in Ev.Key.Modifiers) then Exit;
  if Ev.Key.Code <> kcChar then Exit;
  Result := (Ev.Key.Ch = Ord('c')) or (Ev.Key.Ch = Ord('C'))
         or (Ev.Key.Ch = Ord('q')) or (Ev.Key.Ch = Ord('Q'));
end;

procedure TApp.Render(var Frame: TFrame); begin end;
procedure TApp.HandleEvent(const Ev: TEvent); begin end;
procedure TApp.OnTick; begin end;
procedure TApp.OnInit; begin end;
procedure TApp.OnDestroy; begin end;

end.