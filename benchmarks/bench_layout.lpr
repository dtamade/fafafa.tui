program bench_layout;

// Performance benchmark: layout split solver throughput.
//
// Measures how fast VerticalSplit / HorizontalSplit resolve constraint
// lists into rect arrays.  cli888 calls split ~5-10 times per frame
// (one per nested layout region), so even 100μs per call would be
// invisible.  This benchmark exists to catch regressions, not to
// prove speed.
//
// Runs 100,000 iterations of a representative 3-constraint split.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_layout;

const
  ITERATIONS = 100000;

var
  Area: TRect;
  I: Integer;
  StartTick, EndTick: Int64;
  TotalMs, PerCallUs: Double;
  R: TRectArray;

begin
  WriteLn('bench_layout: ', ITERATIONS, ' iterations of VerticalSplit [Length(3), Min(0), Length(1)]');
  WriteLn;

  Area := TRect.Make(0, 0, 80, 24);

  StartTick := GetTickCount64;
  for I := 0 to ITERATIONS - 1 do
    R := VerticalSplit(Area, [LengthConstraint(3), MinConstraint(0), LengthConstraint(1)]);
  EndTick := GetTickCount64;

  TotalMs := (EndTick - StartTick);
  PerCallUs := (TotalMs * 1000.0) / ITERATIONS;

  WriteLn(Format('total time:   %.1f ms', [TotalMs]));
  WriteLn(Format('per-call:     %.3f us', [PerCallUs]));
  WriteLn(Format('calls/sec:    %.0f', [ITERATIONS / (TotalMs / 1000.0)]));
  WriteLn;

  if PerCallUs < 5.0 then
    WriteLn('PASS: per-call < 5us')
  else
    WriteLn('WARN: per-call >= 5us — check for regressions');

  // Prevent optimizer from eliding the loop.
  if Length(R) = 0 then WriteLn('(unreachable)');
end.
