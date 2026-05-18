program bench_input;

// Performance benchmark: input parser throughput.
//
// Feeds 100,000 synthetic ESC sequences through ParseOne and measures
// events/sec.  The mix is representative of fast typing + arrow keys +
// occasional mouse scroll.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_event,
  ftui_input_parser;

const
  EVENTS = 100000;

type
  TSeqEntry = record
    Bytes: array[0..7] of Byte;
    Len: Integer;
  end;

const
  SEQ_COUNT = 8;
  Sequences: array[0..SEQ_COUNT - 1] of TSeqEntry = (
    (Bytes: (Ord('a'), 0, 0, 0, 0, 0, 0, 0); Len: 1),                     // printable
    (Bytes: (27, Ord('['), Ord('A'), 0, 0, 0, 0, 0); Len: 3),              // Up
    (Bytes: (27, Ord('['), Ord('B'), 0, 0, 0, 0, 0); Len: 3),              // Down
    (Bytes: (13, 0, 0, 0, 0, 0, 0, 0); Len: 1),                            // Enter
    (Bytes: (27, Ord('a'), 0, 0, 0, 0, 0, 0); Len: 2),                     // Alt-a
    (Bytes: (27, Ord('['), Ord('5'), Ord('~'), 0, 0, 0, 0); Len: 4),       // PgUp
    (Bytes: (27, Ord('['), Ord('<'), Ord('6'), Ord('4'), Ord(';'), Ord('1'), Ord(';')); Len: 8),  // partial SGR (will need more)
    (Bytes: (9, 0, 0, 0, 0, 0, 0, 0); Len: 1)                              // Tab
  );

var
  I, Consumed, SuccessCount: Integer;
  Ev: TEvent;
  R: TParseResult;
  StartTick, EndTick: Int64;
  TotalMs, PerEventNs: Double;
  Seq: TSeqEntry;

begin
  WriteLn('bench_input: ', EVENTS, ' parse attempts from ', SEQ_COUNT, ' sequence types');
  WriteLn;

  SuccessCount := 0;
  StartTick := GetTickCount64;

  for I := 0 to EVENTS - 1 do
  begin
    Seq := Sequences[I mod SEQ_COUNT];
    R := ParseOne(Seq.Bytes[0], Seq.Len, True, Ev, Consumed);
    if R = prSuccess then Inc(SuccessCount);
  end;

  EndTick := GetTickCount64;
  TotalMs := (EndTick - StartTick);
  if TotalMs < 1 then TotalMs := 1;
  PerEventNs := (TotalMs * 1000000.0) / EVENTS;

  WriteLn(Format('total time:      %.1f ms', [TotalMs]));
  WriteLn(Format('per-event:       %.1f ns', [PerEventNs]));
  WriteLn(Format('events/sec:      %.0f M', [EVENTS / (TotalMs / 1000.0) / 1000000.0]));
  WriteLn(Format('success rate:    %d / %d (%.1f%%)', [SuccessCount, EVENTS, SuccessCount * 100.0 / EVENTS]));
  WriteLn;

  if PerEventNs < 1000.0 then
    WriteLn('PASS: per-event < 1us')
  else
    WriteLn('WARN: per-event >= 1us');
end.
