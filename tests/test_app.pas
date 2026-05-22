unit test_app;

{$mode objfpc}{$H+}

interface

uses
  ftui_testkit;

procedure RegisterTests;

implementation

uses
  ftui_app,
  ftui_event,
  ftui_terminal,
  ftui_rect,
  ftui_buffer,
  ftui_overlay,
  ftui_focus;

type
  TTestApp = class(TApp)
  private
    FEvents: array of TEvent;
    FEventIdx: Integer;
    FBuf: TBuffer;
    FOverlayBuf: TOverlayBuffer;
  public
    RenderCount: Integer;
    TickCount_: Integer;
    LastEvent: TEvent;
    InitCalled: Boolean;
    DestroyCalled: Boolean;
    constructor Create(const AEvents: array of TEvent);
    destructor Destroy; override;
  protected
    function DoEnterTui: Boolean; override;
    procedure DoLeaveTui; override;
    function DoBeginFrame: TFrame; override;
    procedure DoEndFrame(const F: TFrame); override;
    function DoPollEvent: TEvent; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure OnTick; override;
    procedure OnInit; override;
    procedure OnDestroy; override;
  end;

constructor TTestApp.Create(const AEvents: array of TEvent);
var I: Integer;
begin
  inherited Create;
  SetLength(FEvents, Length(AEvents));
  for I := 0 to High(AEvents) do
    FEvents[I] := AEvents[I];
  FEventIdx := 0;
  RenderCount := 0;
  TickCount_ := 0;
  InitCalled := False;
  DestroyCalled := False;
  FBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 80, 24));
  FOverlayBuf := TOverlayBuffer.Create(TRect.Make(0, 0, 80, 24));
end;

destructor TTestApp.Destroy;
begin
  FBuf.Free;
  FOverlayBuf.Free;
  inherited;
end;

function TTestApp.DoEnterTui: Boolean;
begin
  Result := True;
end;

procedure TTestApp.DoLeaveTui;
begin
end;

function TTestApp.DoBeginFrame: TFrame;
begin
  FBuf.Reset;
  Result.Buffer := FBuf;
  Result.Overlay := FOverlayBuf;
  Result.Area := FBuf.Area;
  Result.HasCursor := False;
  Result.CursorPos.X := 0;
  Result.CursorPos.Y := 0;
end;

procedure TTestApp.DoEndFrame(const F: TFrame);
begin
end;

function TTestApp.DoPollEvent: TEvent;
begin
  if FEventIdx < Length(FEvents) then
  begin
    Result := FEvents[FEventIdx];
    Inc(FEventIdx);
  end
  else
    Result := KeyCharEvent(Ord('q'), [kmCtrl]);
end;

procedure TTestApp.Render(var Frame: TFrame);
begin
  Inc(RenderCount);
end;

procedure TTestApp.HandleEvent(const Ev: TEvent);
begin
  LastEvent := Ev;
end;

procedure TTestApp.OnTick;
begin
  Inc(TickCount_);
end;

procedure TTestApp.OnInit;
begin
  InitCalled := True;
end;

procedure TTestApp.OnDestroy;
begin
  DestroyCalled := True;
end;

{ --- Tests --- }

procedure Test_QuitOnCtrlC;
var App: TTestApp;
begin
  App := TTestApp.Create([KeyCharEvent(Ord('c'), [kmCtrl])]);
  try
    App.Run;
    AssertTrue(App.RenderCount >= 1, 'should exit after Ctrl+C');
  finally
    App.Free;
  end;
end;

procedure Test_QuitOnCtrlQ;
var App: TTestApp;
begin
  App := TTestApp.Create([KeyCharEvent(Ord('q'), [kmCtrl])]);
  try
    App.Run;
    AssertTrue(App.RenderCount >= 1, 'should exit after Ctrl+Q');
  finally
    App.Free;
  end;
end;

procedure Test_RenderCalled;
var App: TTestApp;
begin
  App := TTestApp.Create([
    KeyCharEvent(Ord('a'), []),
    KeyCharEvent(Ord('q'), [kmCtrl])
  ]);
  try
    App.Run;
    AssertTrue(App.RenderCount >= 2, 'render called multiple times');
  finally
    App.Free;
  end;
end;

procedure Test_HandleEventDispatched;
var App: TTestApp;
begin
  App := TTestApp.Create([
    KeyCharEvent(Ord('x'), []),
    KeyCharEvent(Ord('q'), [kmCtrl])
  ]);
  try
    App.Run;
    AssertEqInt(Ord('x'), Integer(App.LastEvent.Key.Ch), 'event dispatched');
  finally
    App.Free;
  end;
end;

procedure Test_TickFires;
var App: TTestApp;
begin
  App := TTestApp.Create([NoneEvent, NoneEvent, KeyCharEvent(Ord('q'), [kmCtrl])]);
  try
    App.TickInterval := 0;
    App.Run;
    AssertTrue(App.TickCount_ >= 2, 'tick fired');
  finally
    App.Free;
  end;
end;

type
  TCbHelper = class
    Called: Boolean;
    procedure DoRender(App: TApp; var Frame: TFrame);
  end;

procedure TCbHelper.DoRender(App: TApp; var Frame: TFrame);
begin
  Called := True;
end;

procedure Test_CallbackOverridesVirtual;
var
  App: TTestApp;
  H: TCbHelper;
begin
  H := TCbHelper.Create;
  H.Called := False;
  App := TTestApp.Create([KeyCharEvent(Ord('q'), [kmCtrl])]);
  try
    App.OnRenderCb := @H.DoRender;
    App.Run;
    AssertTrue(H.Called, 'callback called');
    AssertEqInt(0, App.RenderCount, 'virtual not called');
  finally
    App.Free;
    H.Free;
  end;
end;

procedure Test_FocusEnabled;
var App: TTestApp;
begin
  App := TTestApp.Create([KeyCharEvent(Ord('q'), [kmCtrl])]);
  try
    App.EnableFocus;
    AssertTrue(App.Focus <> nil, 'focus not nil');
    App.Run;
  finally
    App.Free;
  end;
end;

type
  TEscQuitApp = class(TTestApp)
  protected
    function IsQuitEvent(const Ev: TEvent): Boolean; override;
  end;

function TEscQuitApp.IsQuitEvent(const Ev: TEvent): Boolean;
begin
  Result := (Ev.Kind = evKey) and (Ev.Key.Code = kcEsc);
end;

procedure Test_IsQuitEventOverridable;
var App: TEscQuitApp;
begin
  App := TEscQuitApp.Create([
    KeyCharEvent(Ord('q'), [kmCtrl]),
    KeyCodeEvent(kcEsc, [])
  ]);
  try
    App.Run;
    AssertEqInt(Ord('q'), Integer(App.LastEvent.Key.Ch), 'Ctrl+Q did not quit (dispatched as event)');
    AssertTrue(App.RenderCount >= 2, 'render called at least twice');
  finally
    App.Free;
  end;
end;

procedure Test_InitAndDestroyCalled;
var App: TTestApp;
begin
  App := TTestApp.Create([KeyCharEvent(Ord('q'), [kmCtrl])]);
  try
    App.Run;
    AssertTrue(App.InitCalled, 'OnInit called');
    AssertTrue(App.DestroyCalled, 'OnDestroy called');
  finally
    App.Free;
  end;
end;

procedure Test_MultipleFramesRenderSequence;
var App: TTestApp;
begin
  App := TTestApp.Create([KeyCharEvent(Ord('a'), []), KeyCharEvent(Ord('b'), []), KeyCharEvent(Ord('c'), [kmCtrl])]);
  try
    App.Run;
    AssertTrue(App.RenderCount >= 3, 'render called at least 3 times');
  finally
    App.Free;
  end;
end;

procedure Test_ElapsedMsAfterRun;
var App: TTestApp;
begin
  App := TTestApp.Create([NoneEvent, KeyCharEvent(Ord('c'), [kmCtrl])]);
  try
    App.Run;
    AssertTrue(App.ElapsedMs >= 0, 'ElapsedMs non-negative after run');
  finally
    App.Free;
  end;
end;

procedure Test_TickCountIncrements;
var App: TTestApp;
begin
  App := TTestApp.Create([NoneEvent, NoneEvent, NoneEvent, KeyCharEvent(Ord('c'), [kmCtrl])]);
  try
    App.Run;
    AssertTrue(App.TickCount_ >= 3, 'tick count >= 3 after 3 none events');
  finally
    App.Free;
  end;
end;

procedure RegisterTests;
begin
  RegisterTest('app / quit on ctrl+c', @Test_QuitOnCtrlC);
  RegisterTest('app / quit on ctrl+q', @Test_QuitOnCtrlQ);
  RegisterTest('app / render called', @Test_RenderCalled);
  RegisterTest('app / handle event dispatched', @Test_HandleEventDispatched);
  RegisterTest('app / tick fires', @Test_TickFires);
  RegisterTest('app / callback overrides virtual', @Test_CallbackOverridesVirtual);
  RegisterTest('app / focus enabled', @Test_FocusEnabled);
  RegisterTest('app / IsQuitEvent overridable', @Test_IsQuitEventOverridable);
  RegisterTest('app / init and destroy called', @Test_InitAndDestroyCalled);
  RegisterTest('app / multiple frames render', @Test_MultipleFramesRenderSequence);
  RegisterTest('app / elapsed ms after run', @Test_ElapsedMsAfterRun);
  RegisterTest('app / tick count increments', @Test_TickCountIncrements);
end;

end.
