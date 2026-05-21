unit ftui_screen;

{$mode objfpc}{$H+}{$inline on}

interface

uses
  ftui_rect,
  ftui_event,
  ftui_terminal,
  ftui_buffer;

type
  TScreenStack = class;

  TScreen = class
  private
    FStack: TScreenStack;
  public
    property Stack: TScreenStack read FStack write FStack;
    procedure Render(const Area: TRect; Buf: TBuffer); virtual; abstract;
    procedure HandleEvent(const Ev: TEvent); virtual;
    procedure OnEnter; virtual;
    procedure OnLeave; virtual;
  end;

  TScreenStack = class
  private
    FScreens: array of TScreen;
    FCount: Integer;
    FQuitRequested: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Push(AScreen: TScreen);
    function Pop: TScreen;
    procedure Replace(AScreen: TScreen);
    function Top: TScreen;
    function Count: Integer; inline;
    function IsEmpty: Boolean; inline;
    property QuitRequested: Boolean read FQuitRequested write FQuitRequested;
    procedure Render(const Area: TRect; Buf: TBuffer);
    procedure HandleEvent(const Ev: TEvent);
  end;

implementation

{ TScreen }

procedure TScreen.HandleEvent(const Ev: TEvent);
begin
end;

procedure TScreen.OnEnter;
begin
end;

procedure TScreen.OnLeave;
begin
end;

{ TScreenStack }

constructor TScreenStack.Create;
begin
  inherited Create;
  FCount := 0;
  FScreens := nil;
  FQuitRequested := False;
end;

destructor TScreenStack.Destroy;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    FScreens[I].Free;
  inherited;
end;

procedure TScreenStack.Push(AScreen: TScreen);
begin
  if FCount > 0 then
    FScreens[FCount - 1].OnLeave;
  Inc(FCount);
  if FCount > Length(FScreens) then
    SetLength(FScreens, FCount * 2);
  FScreens[FCount - 1] := AScreen;
  AScreen.FStack := Self;
  AScreen.OnEnter;
end;

function TScreenStack.Pop: TScreen;
begin
  Result := nil;
  if FCount = 0 then Exit;
  Result := FScreens[FCount - 1];
  Result.OnLeave;
  Dec(FCount);
  if FCount > 0 then
    FScreens[FCount - 1].OnEnter;
end;

procedure TScreenStack.Replace(AScreen: TScreen);
var Old: TScreen;
begin
  if FCount > 0 then
  begin
    Old := FScreens[FCount - 1];
    Old.OnLeave;
    Old.Free;
    FScreens[FCount - 1] := AScreen;
  end
  else
  begin
    Inc(FCount);
    if FCount > Length(FScreens) then
      SetLength(FScreens, FCount * 2);
    FScreens[FCount - 1] := AScreen;
  end;
  AScreen.FStack := Self;
  AScreen.OnEnter;
end;

function TScreenStack.Top: TScreen;
begin
  if FCount = 0 then
    Result := nil
  else
    Result := FScreens[FCount - 1];
end;

function TScreenStack.Count: Integer;
begin
  Result := FCount;
end;

function TScreenStack.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

procedure TScreenStack.Render(const Area: TRect; Buf: TBuffer);
begin
  if FCount > 0 then
    FScreens[FCount - 1].Render(Area, Buf);
end;

procedure TScreenStack.HandleEvent(const Ev: TEvent);
begin
  if FCount > 0 then
    FScreens[FCount - 1].HandleEvent(Ev);
end;

end.
