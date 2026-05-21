unit ftui_keybind;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_event;

type
  TKeybindMode = (kmNormal, kmInsert, kmVisual, kmCommand);

  TKeybindAction = procedure;

  TKeybinding = record
    Mode: TKeybindMode;
    Code: TKeyCodeKind;
    Ch: Byte;
    Shift: Boolean;
    Ctrl: Boolean;
    Alt: Boolean;
    Action: TKeybindAction;
    Description: AnsiString;
  end;

  TKeybindManager = class
  private
    FBindings: array of TKeybinding;
    FMode: TKeybindMode;
    FCount: Integer;
  public
    constructor Create;
    procedure SetMode(M: TKeybindMode);
    function Mode: TKeybindMode; inline;
    procedure Bind(AMode: TKeybindMode; ACode: TKeyCodeKind; ACh: Byte;
      AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindChar(AMode: TKeybindMode; Ch: Char;
      AAction: TKeybindAction; const ADesc: AnsiString);
    procedure BindKey(AMode: TKeybindMode; ACode: TKeyCodeKind;
      AAction: TKeybindAction; const ADesc: AnsiString);
    function HandleKey(const K: TKeyEvent): Boolean;
    function BindingCount: Integer; inline;
    function GetBinding(I: Integer): TKeybinding;
    function HelpText: AnsiString;
  end;

implementation

uses
  SysUtils;

constructor TKeybindManager.Create;
begin
  inherited Create;
  FBindings := nil;
  FMode := kmNormal;
  FCount := 0;
end;

procedure TKeybindManager.SetMode(M: TKeybindMode);
begin
  FMode := M;
end;

function TKeybindManager.Mode: TKeybindMode;
begin
  Result := FMode;
end;

procedure TKeybindManager.Bind(AMode: TKeybindMode; ACode: TKeyCodeKind; ACh: Byte;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Inc(FCount);
  SetLength(FBindings, FCount);
  FBindings[FCount - 1].Mode := AMode;
  FBindings[FCount - 1].Code := ACode;
  FBindings[FCount - 1].Ch := ACh;
  FBindings[FCount - 1].Shift := False;
  FBindings[FCount - 1].Ctrl := False;
  FBindings[FCount - 1].Alt := False;
  FBindings[FCount - 1].Action := AAction;
  FBindings[FCount - 1].Description := ADesc;
end;

procedure TKeybindManager.BindChar(AMode: TKeybindMode; Ch: Char;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Bind(AMode, kcChar, Ord(Ch), AAction, ADesc);
end;

procedure TKeybindManager.BindKey(AMode: TKeybindMode; ACode: TKeyCodeKind;
  AAction: TKeybindAction; const ADesc: AnsiString);
begin
  Bind(AMode, ACode, 0, AAction, ADesc);
end;

function TKeybindManager.HandleKey(const K: TKeyEvent): Boolean;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    if FBindings[I].Mode <> FMode then Continue;
    if FBindings[I].Code <> K.Code then Continue;
    if (FBindings[I].Code = kcChar) and (FBindings[I].Ch <> K.Ch) then Continue;
    if Assigned(FBindings[I].Action) then
      FBindings[I].Action();
    Exit(True);
  end;
  Result := False;
end;

function TKeybindManager.BindingCount: Integer;
begin
  Result := FCount;
end;

function TKeybindManager.GetBinding(I: Integer): TKeybinding;
begin
  Result := FBindings[I];
end;

function TKeybindManager.HelpText: AnsiString;
var
  I: Integer;
  ModeStr, KeyStr: AnsiString;
begin
  Result := '';
  for I := 0 to FCount - 1 do
  begin
    case FBindings[I].Mode of
      kmNormal: ModeStr := 'N';
      kmInsert: ModeStr := 'I';
      kmVisual: ModeStr := 'V';
      kmCommand: ModeStr := 'C';
    end;

    if FBindings[I].Code = kcChar then
      KeyStr := Chr(FBindings[I].Ch)
    else
      case FBindings[I].Code of
        kcEnter: KeyStr := 'Enter';
        kcEsc: KeyStr := 'Esc';
        kcBackspace: KeyStr := 'BS';
        kcTab: KeyStr := 'Tab';
        kcUp: KeyStr := 'Up';
        kcDown: KeyStr := 'Down';
        kcLeft: KeyStr := 'Left';
        kcRight: KeyStr := 'Right';
      else
        KeyStr := '?';
      end;

    Result := Result + Format('[%s] %-8s %s', [ModeStr, KeyStr, FBindings[I].Description]);
    if I < FCount - 1 then Result := Result + #10;
  end;
end;

end.
