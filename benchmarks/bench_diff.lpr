program bench_diff;

// Performance benchmark: 200x60 full-screen diff + ANSI generation.
//
// Measures the hot path that runs every frame in a real TUI app:
//   1. Fill Curr buffer with random-ish content (simulates a full redraw)
//   2. Diff against Prev
//   3. Generate ANSI byte stream via TAnsiBackend (without flushing)
//   4. Swap buffers
//
// Reports: total time, per-frame time, fps, bytes generated per frame.
// Target: frame time < 1ms (= >1000 fps headroom on 200x60).

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_ansi_backend;

const
  WIDTH  = 200;
  HEIGHT = 60;
  FRAMES = 1000;

var
  Prev, Curr, Tmp: TBuffer;
  Backend: TAnsiBackend;
  Patches: TDiffEntries;
  Frame, X, Y: Integer;
  StartTick, EndTick, Freq: Int64;
  TotalMs, PerFrameUs: Double;
  TotalBytes: Int64;
  CP: PCell;
  Sty: TStyle;
  Ch: Byte;

begin
  WriteLn('bench_diff: ', WIDTH, 'x', HEIGHT, ' full-screen, ', FRAMES, ' frames');
  WriteLn;

  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Backend := TAnsiBackend.Create(-1);   // fd=-1: no actual IO
  TotalBytes := 0;

  // Warm up: fill Prev with something so the first diff isn't trivially "all changed".
  for Y := 0 to HEIGHT - 1 do
    for X := 0 to WIDTH - 1 do
    begin
      CP := Prev.ContentPtr + (Y * WIDTH + X);
      CellSetSymbolAscii(CP^, AnsiChar(Ord('A') + ((X + Y) mod 26)));
    end;

  // Benchmark loop.
  Freq := 0;
  {$IFDEF LINUX}
  // Use clock_gettime for nanosecond precision.
  {$ENDIF}
  StartTick := GetTickCount64;

  for Frame := 0 to FRAMES - 1 do
  begin
    // Simulate a full redraw: every cell gets a "new" character + style.
    // We vary by frame index so the diff actually has work to do.
    Sty := TStyle.Default.WithFg(IndexedColor(Byte(Frame mod 7) + 1));
    Ch := Byte(Ord('a') + (Frame mod 26));
    for Y := 0 to HEIGHT - 1 do
      for X := 0 to WIDTH - 1 do
      begin
        CP := Curr.ContentPtr + (Y * WIDTH + X);
        CellSetSymbolAscii(CP^, AnsiChar(Ch));
        CellApplyStyle(CP^, Sty);
        // Vary some cells to make diff non-trivial but not 100% changed.
        if ((X xor Y xor Frame) and 3) = 0 then
        begin
          CellSetSymbolAscii(CP^, AnsiChar(Ord('A') + ((X + Y) mod 26)));
          CellApplyStyle(CP^, TStyle.Default);
        end;
      end;

    // Diff.
    Prev.Diff(Curr, Patches);

    // Generate ANSI (no flush).
    Backend.DrawPatches(Patches);
    Inc(TotalBytes, Backend.PendingLength);
    Backend.DiscardPending;

    // Swap.
    Tmp := Prev;
    Prev := Curr;
    Curr := Tmp;
    Curr.Reset;
  end;

  EndTick := GetTickCount64;
  TotalMs := (EndTick - StartTick);
  PerFrameUs := (TotalMs * 1000.0) / FRAMES;

  WriteLn(Format('total time:      %.1f ms', [TotalMs]));
  WriteLn(Format('per-frame:       %.1f us', [PerFrameUs]));
  WriteLn(Format('fps headroom:    %.0f', [1000000.0 / PerFrameUs]));
  WriteLn(Format('bytes/frame avg: %.0f', [TotalBytes / FRAMES]));
  WriteLn(Format('total bytes:     %d', [TotalBytes]));
  WriteLn;

  if PerFrameUs < 1000.0 then
    WriteLn('PASS: frame time < 1ms')
  else
    WriteLn('FAIL: frame time >= 1ms — needs optimization');

  Curr.Free;
  Prev.Free;
  Backend.Free;
end.
