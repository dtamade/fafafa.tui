unit ftui_interaction;

// Interaction primitives: pointer capture, hover tracking, hit-test,
// and interaction session management.
//
// These are the building blocks tui-design needs for drag, hover,
// and Esc-cancel semantics.  They live in a single unit because
// they're tightly coupled (capture affects hover, session affects
// capture).

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}

interface

uses
  ftui_rect,
  ftui_event;

type
  THoverChange = (hcNone, hcEntered, hcLeft, hcStay);

  // Pointer capture: once set, all mouse events route to the
  // captured target until released.
  TPointerCapture = record
    Active: Boolean;
    Target: Pointer;       // opaque; consumer casts to their type
    Button: TMouseButton;  // which button initiated the capture
    procedure Acquire(ATarget: Pointer; AButton: TMouseButton);
    procedure Release;
  end;

  // Interaction session: represents one drag/stroke/rename/filter
  // from start to commit/cancel.  Esc triggers Cancel.
  TSessionState = (ssNone, ssActive, ssCommitted, ssCancelled);

  TInteractionSession = record
    State: TSessionState;
    Target: Pointer;
    procedure Begin_(ATarget: Pointer);
    procedure Commit;
    procedure Cancel;
    function IsActive: Boolean; inline;
  end;

// Hit-test: is a mouse position inside a rect?
function HitTest(const Area: TRect; X, Y: Word): Boolean; inline;
function HitTestEvent(const Area: TRect; const Ev: TMouseEvent): Boolean; inline;

// Hover change detection: compare previous and current mouse
// positions against a region.
function DetectHoverChange(const Area: TRect; PrevX, PrevY, CurrX, CurrY: Word): THoverChange;

implementation

{ TPointerCapture }

procedure TPointerCapture.Acquire(ATarget: Pointer; AButton: TMouseButton);
begin
  Active := True;
  Target := ATarget;
  Button := AButton;
end;

procedure TPointerCapture.Release;
begin
  Active := False;
  Target := nil;
  Button := mbNone;
end;

{ TInteractionSession }

procedure TInteractionSession.Begin_(ATarget: Pointer);
begin
  State := ssActive;
  Target := ATarget;
end;

procedure TInteractionSession.Commit;
begin
  if State = ssActive then
    State := ssCommitted;
end;

procedure TInteractionSession.Cancel;
begin
  if State = ssActive then
    State := ssCancelled;
end;

function TInteractionSession.IsActive: Boolean;
begin
  Result := State = ssActive;
end;

{ Hit-test }

function HitTest(const Area: TRect; X, Y: Word): Boolean;
begin
  Result := (X >= Area.X) and (X < Area.X + Area.Width) and
            (Y >= Area.Y) and (Y < Area.Y + Area.Height);
end;

function HitTestEvent(const Area: TRect; const Ev: TMouseEvent): Boolean;
begin
  Result := HitTest(Area, Ev.X, Ev.Y);
end;

function DetectHoverChange(const Area: TRect; PrevX, PrevY, CurrX, CurrY: Word): THoverChange;
var
  WasIn, IsIn: Boolean;
begin
  WasIn := HitTest(Area, PrevX, PrevY);
  IsIn  := HitTest(Area, CurrX, CurrY);
  if (not WasIn) and IsIn then Result := hcEntered
  else if WasIn and (not IsIn) then Result := hcLeft
  else if WasIn and IsIn then Result := hcStay
  else Result := hcNone;
end;

end.
