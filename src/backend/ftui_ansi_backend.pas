unit ftui_ansi_backend;

// Concrete ANSI backend.  Translates a TDiffEntries into ANSI byte
// sequences and flushes them to a Unix file descriptor.
//
// This is the only place per-frame ANSI bytes are assembled.  All work
// goes through a TByteBuilder owned by the backend instance, which is
// reused frame-to-frame to avoid realloc churn.
//
// Style minimisation: the backend remembers the last-emitted style
// across calls and emits SGR 0 + only the deltas needed.  For now the
// minimisation is intentionally conservative: any change in any field
// triggers a full reset followed by re-application of the new style,
// matching ratatui's CrosstermBackend default behaviour.  M2/M3 may
// optimise this further once a benchmark proves it pays off.
//
// IBackend interface lives in M1 alongside TestBackend.  Until then,
// callers depend on this concrete class directly.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_bytes,
  ftui_ansi;

type
  TAnsiBackend = class
  private
    FFd: LongInt;
    FOut: TByteBuilder;
    FLastFg, FLastBg, FLastUl: TColor;
    FLastMod: TModifier;
    FLastInit: Boolean;
    procedure ApplyCellStyle(const C: TCell);
  public
    constructor Create(AFd: LongInt);

    // Reset the cached SGR state — call after EnterAlternate / before
    // the first frame to make sure the next ApplyCellStyle emits a
    // full SGR sequence regardless of FLast*.
    procedure ResetStyleCache;

    // Buffer-level helpers.  These DO NOT flush; call Flush at the end.
    procedure HideCursor;
    procedure ShowCursor;
    procedure ClearScreen;
    procedure EnterAlternate;
    procedure LeaveAlternate;
    procedure MoveTo(X, Y: Word);

    // Translate Patches into ANSI bytes.  Patches are assumed to be
    // ordered by (Y, X) — the buffer Diff produces them in row-major
    // order so adjacent cells in the same row reuse the cursor without
    // emitting another MoveTo.
    procedure DrawPatches(const Patches: TDiffEntries);

    // Flush the byte buffer to the fd in one syscall (or a few, on
    // EINTR / partial writes).  Returns False if the write ultimately
    // failed; callers can decide whether that's fatal.
    function Flush: Boolean;

    // For test backends and unit tests — peek at the unflushed bytes.
    function PendingLength: Integer; inline;
    function PendingBytes: PByte; inline;
    procedure DiscardPending; inline;
  end;

implementation

{ TAnsiBackend }

constructor TAnsiBackend.Create(AFd: LongInt);
begin
  inherited Create;
  FFd := AFd;
  FOut.Reset;
  ResetStyleCache;
end;

procedure TAnsiBackend.ResetStyleCache;
begin
  FLastFg := UnsetColor;
  FLastBg := UnsetColor;
  FLastUl := UnsetColor;
  FLastMod := [];
  FLastInit := False;
end;

procedure TAnsiBackend.HideCursor;     begin AnsiHideCursor(FOut); end;
procedure TAnsiBackend.ShowCursor;     begin AnsiShowCursor(FOut); end;
procedure TAnsiBackend.ClearScreen;    begin AnsiClearScreen(FOut); end;
procedure TAnsiBackend.EnterAlternate;
begin
  AnsiEnterAltScreen(FOut);
  ResetStyleCache;
end;
procedure TAnsiBackend.LeaveAlternate;
begin
  AnsiSgrReset(FOut);
  AnsiLeaveAltScreen(FOut);
  ResetStyleCache;
end;
procedure TAnsiBackend.MoveTo(X, Y: Word);
begin
  AnsiMoveTo(FOut, X, Y);
end;

procedure TAnsiBackend.ApplyCellStyle(const C: TCell);
var
  Changed: Boolean;
begin
  // Fast path: compare style fields inline.  We check Modifier first
  // (2 bytes, cheapest) then colors (4 bytes each via LongWord cast).
  // This is faster than CompareByte (FPC RTL function call overhead)
  // and faster than 5 separate ColorEquals calls.
  if FLastInit then
    Changed := (C.Modifier <> FLastMod) or
               (not ColorEquals(C.Fg, FLastFg)) or
               (not ColorEquals(C.Bg, FLastBg)) or
               (not ColorEquals(C.Ul, FLastUl))
  else
    Changed := True;
  if not Changed then Exit;

  AnsiSgrReset(FOut);
  if (C.Fg.Kind = ckIndexed) or (C.Fg.Kind = ckRgb) then AnsiSgrFg(FOut, C.Fg);
  if (C.Bg.Kind = ckIndexed) or (C.Bg.Kind = ckRgb) then AnsiSgrBg(FOut, C.Bg);
  AnsiSgrModifierAdd(FOut, C.Modifier);

  FLastFg := C.Fg;
  FLastBg := C.Bg;
  FLastUl := C.Ul;
  FLastMod := C.Modifier;
  FLastInit := True;
end;

procedure TAnsiBackend.DrawPatches(const Patches: TDiffEntries);
var
  I: Integer;
  CurX, CurY: Integer;
  GlyphLen: Integer;
begin
  CurX := -1;
  CurY := -1;
  for I := 0 to High(Patches) do
  begin
    // Move to the patch's coordinates if we're not already there.
    if (Patches[I].X <> CurX) or (Patches[I].Y <> CurY) then
    begin
      AnsiMoveTo(FOut, Patches[I].X, Patches[I].Y);
      CurX := Patches[I].X;
      CurY := Patches[I].Y;
    end;

    ApplyCellStyle(Patches[I].Cell);

    GlyphLen := Patches[I].Cell.Glyph.Len;
    if GlyphLen = 0 then
    begin
      // Empty glyph -> emit a single space so the cell visually clears.
      FOut.AppendByte(Ord(' '));
    end
    else
      FOut.AppendBytes(Patches[I].Cell.Glyph.Bytes[0], GlyphLen);

    Inc(CurX);    // we just wrote one column; cursor advanced
    // M0: width=1 only.  M2 will inc by Cell.Width here.
  end;
end;

function TAnsiBackend.Flush: Boolean;
begin
  Result := FOut.FlushTo(FFd);
  FOut.Reset;
end;

function TAnsiBackend.PendingLength: Integer;
begin
  Result := FOut.Length_;
end;

function TAnsiBackend.PendingBytes: PByte;
begin
  Result := FOut.Bytes;
end;

procedure TAnsiBackend.DiscardPending;
begin
  FOut.Reset;
  ResetStyleCache;
end;

end.
