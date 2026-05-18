unit ftui_test_backend;

// In-memory backend for unit / integration tests.  Same interface
// shape as TAnsiBackend (DrawPatches / Flush / cursor + screen
// helpers), but instead of writing ANSI bytes the patches are applied
// to an internal TBuffer that tests can inspect via AsLines.
//
// Why this exists:
//   - Widget tests want to assert on the rendered buffer content, not
//     on the ANSI byte stream — comparing byte-for-byte ANSI breaks
//     when a backend optimisation changes (`SGR cache`, cursor merge,
//     etc.).  TestBackend gives us the *result* of the rendering.
//   - It also lets terminal-loop tests run without a real fd.
//
// IBackend interface comes in M3 when both backends share a contract.
// For now both classes expose the methods Frame needs by convention.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}

interface

uses
  ftui_rect,
  ftui_cell,
  ftui_buffer;

type
  TTestBackend = class
  private
    FBuffer: TBuffer;
    FCursorVisible: Boolean;
    FCursorX, FCursorY: Word;
    FOnAlternate: Boolean;
  public
    constructor Create(const Area: TRect);
    destructor Destroy; override;

    // The "result" surface tests inspect.  Owned by the backend.
    property Buffer: TBuffer read FBuffer;
    property CursorVisible: Boolean read FCursorVisible;
    property CursorX: Word read FCursorX;
    property CursorY: Word read FCursorY;
    property OnAlternate: Boolean read FOnAlternate;

    // Apply patches to the internal buffer.  Equivalent of
    // TAnsiBackend.DrawPatches without the ANSI emission.
    procedure DrawPatches(const Patches: TDiffEntries);

    // Conformance with TAnsiBackend's screen / cursor surface.
    procedure HideCursor; inline;
    procedure ShowCursor; inline;
    procedure ClearScreen;
    procedure EnterAlternate; inline;
    procedure LeaveAlternate; inline;
    procedure MoveTo(X, Y: Word); inline;

    // No-op: there's nothing to flush.  Returns True so callers don't
    // need to special-case the test backend.
    function Flush: Boolean; inline;

    // Test-only convenience: empty the buffer, reset cursor + alt
    // tracking.  Useful when re-running a render in a single test.
    procedure ResetState;
  end;

implementation

{ TTestBackend }

constructor TTestBackend.Create(const Area: TRect);
begin
  inherited Create;
  FBuffer := TBuffer.CreateEmpty(Area);
  FCursorVisible := True;
  FCursorX := 0;
  FCursorY := 0;
  FOnAlternate := False;
end;

destructor TTestBackend.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TTestBackend.DrawPatches(const Patches: TDiffEntries);
var
  I: Integer;
  CP: PCell;
begin
  for I := 0 to System.High(Patches) do
  begin
    CP := FBuffer.CellAt(Patches[I].X, Patches[I].Y);
    if CP <> nil then
      CP^ := Patches[I].Cell;
  end;
  if System.Length(Patches) > 0 then
  begin
    FCursorX := Patches[System.High(Patches)].X + 1;
    FCursorY := Patches[System.High(Patches)].Y;
  end;
end;

procedure TTestBackend.HideCursor;     begin FCursorVisible := False; end;
procedure TTestBackend.ShowCursor;     begin FCursorVisible := True;  end;
procedure TTestBackend.EnterAlternate; begin FOnAlternate := True;    end;
procedure TTestBackend.LeaveAlternate; begin FOnAlternate := False;   end;
procedure TTestBackend.MoveTo(X, Y: Word);
begin
  FCursorX := X;
  FCursorY := Y;
end;

procedure TTestBackend.ClearScreen;
begin
  FBuffer.Reset;
end;

function TTestBackend.Flush: Boolean;
begin
  Result := True;
end;

procedure TTestBackend.ResetState;
begin
  FBuffer.Reset;
  FCursorVisible := True;
  FCursorX := 0;
  FCursorY := 0;
  FOnAlternate := False;
end;

end.
