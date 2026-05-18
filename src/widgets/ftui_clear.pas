unit ftui_clear;

// Clear — the simplest widget.  Resets every cell in `Area` to
// CellEmpty (a blank space with default colours and no modifier).
// Useful for popups that need to wipe the underlying frame before
// the popup body draws on top.
//
// ratatui's Clear is similarly tiny: it just iterates the area and
// resets cells.  We stay 1:1.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

uses
  ftui_rect,
  ftui_cell,
  ftui_buffer;

type
  TClear = record
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

function ClearWidget: TClear; inline;

implementation

procedure TClear.Render(const Area: TRect; ABuf: TBuffer);
var
  Clip: TRect;
  X, Y: Integer;
  CP: PCell;
begin
  Clip := ABuf.Area.Intersection(Area);
  if Clip.IsEmpty then Exit;
  for Y := Clip.Top to Clip.Bottom - 1 do
    for X := Clip.Left to Clip.Right - 1 do
    begin
      CP := ABuf.CellAt(X, Y);
      if CP <> nil then
        CP^ := CellEmpty;
    end;
end;

function ClearWidget: TClear;
begin
  // TClear has no state.  FillChar keeps the function-result-init
  // analyser happy without manufacturing fields just to silence it.
  FillChar(Result, SizeOf(Result), 0);
end;

end.
