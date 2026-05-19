program bench_mouse_move;

// Performance benchmark: mouse move hot path.
//
// Simulates 1000 consecutive mouse-moved events, each triggering:
//   1. ParseOne (decode SGR sequence)
//   2. DetectHoverChange (hit-test prev vs curr)
//   3. Overlay.Clear + Overlay.SetString (update preview)
//   4. Overlay.MergeInto (merge into dest buffer)
//
// This is the exact hot path tui-design's canvas will exercise on
// every mouse move.  Target: < 500μs per event (2000 fps headroom).

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_overlay,
  ftui_event,
  ftui_input_parser,
  ftui_interaction;

const
  EVENTS = 1000;
  WIDTH  = 80;
  HEIGHT = 24;

var
  Base, Dest: TBuffer;
  Ov: TOverlayBuffer;
  CanvasArea: TRect;
  PrevX, PrevY: Word;
  I: Integer;
  StartTick, EndTick: Int64;
  TotalMs, PerEventUs: Double;
  // Synthetic SGR moved sequence: ESC [ < 35 ; X ; Y M
  Seq: array[0..15] of Byte;
  SeqLen: Integer;
  Ev: TEvent;
  Consumed: Integer;
  HC: THoverChange;

procedure BuildMovedSeq(X, Y: Integer);
var S: AnsiString;
begin
  // ESC [ < 35 ; X ; Y M
  S := #27'[<35;' + IntToStr(X) + ';' + IntToStr(Y) + 'M';
  SeqLen := Length(S);
  Move(S[1], Seq[0], SeqLen);
end;

begin
  WriteLn('bench_mouse_move: ', EVENTS, ' consecutive moved events on ', WIDTH, 'x', HEIGHT);
  WriteLn;

  Base := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Dest := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Ov := TOverlayBuffer.Create(TRect.Make(0, 0, WIDTH, HEIGHT));
  CanvasArea := TRect.Make(5, 2, 60, 18);
  PrevX := 10; PrevY := 5;
  SeqLen := 0;
  FillChar(Seq, SizeOf(Seq), 0);

  // Fill base with something.
  Base.SetString(0, 0, 'canvas base content here', TStyle.Default);

  StartTick := GetTickCount64;

  for I := 0 to EVENTS - 1 do
  begin
    // 1. Parse a moved event.
    BuildMovedSeq(10 + (I mod 50), 5 + (I mod 15));
    ParseOne(Seq[0], SeqLen, True, Ev, Consumed);

    // 2. Detect hover change.
    HC := DetectHoverChange(CanvasArea, PrevX, PrevY, Ev.Mouse.X, Ev.Mouse.Y);
    PrevX := Ev.Mouse.X;
    PrevY := Ev.Mouse.Y;

    // 3. Update overlay (clear old preview, draw new).
    Ov.Clear;
    if HC <> hcLeft then
      Ov.SetString(Ev.Mouse.X, Ev.Mouse.Y, '+', TStyle.Default.WithFg(clCyan));

    // 4. Merge overlay into dest.
    // First copy base to dest (simulates frame start).
    Move(Base.CellAt(0, 0)^, Dest.CellAt(0, 0)^, WIDTH * HEIGHT * SizeOf(TCell));
    Ov.MergeInto(Base, Dest);
  end;

  EndTick := GetTickCount64;
  TotalMs := (EndTick - StartTick);
  if TotalMs < 1 then TotalMs := 1;
  PerEventUs := (TotalMs * 1000.0) / EVENTS;

  WriteLn(Format('total time:      %.1f ms', [TotalMs]));
  WriteLn(Format('per-event:       %.1f us', [PerEventUs]));
  WriteLn(Format('events/sec:      %.0f', [1000000.0 / PerEventUs]));
  WriteLn;

  if PerEventUs < 500.0 then
    WriteLn('PASS: per-event < 500us (2000+ fps headroom)')
  else
    WriteLn('FAIL: per-event >= 500us — needs optimization');

  Ov.Free; Dest.Free; Base.Free;
end.
