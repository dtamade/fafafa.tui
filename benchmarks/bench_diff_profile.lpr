program bench_diff_profile;

// Profiling variant: measures fill / diff / draw separately.

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
  T0, T1, T2, T3: Int64;
  FillMs, DiffMs, DrawMs: Double;
  CP, Base: PCell;
  Sty: TStyle;
  Ch: Byte;

begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Backend := TAnsiBackend.Create(-1);

  for Y := 0 to HEIGHT - 1 do
    for X := 0 to WIDTH - 1 do
    begin
      CP := Prev.ContentPtr + (Y * WIDTH + X);
      CellSetSymbolAscii(CP^, AnsiChar(Ord('A') + ((X + Y) mod 26)));
    end;

  FillMs := 0; DiffMs := 0; DrawMs := 0;

  for Frame := 0 to FRAMES - 1 do
  begin
    // Phase 1: Fill
    T0 := GetTickCount64;
    Sty := TStyle.Default.WithFg(IndexedColor(Byte(Frame mod 7) + 1));
    Ch := Byte(Ord('a') + (Frame mod 26));
    Base := Curr.ContentPtr;
    for Y := 0 to HEIGHT - 1 do
      for X := 0 to WIDTH - 1 do
      begin
        CP := Base + (Y * WIDTH + X);
        CellSetSymbolAscii(CP^, AnsiChar(Ch));
        CellApplyStyle(CP^, Sty);
        if ((X xor Y xor Frame) and 3) = 0 then
        begin
          CellSetSymbolAscii(CP^, AnsiChar(Ord('A') + ((X + Y) mod 26)));
          CellApplyStyle(CP^, TStyle.Default);
        end;
      end;
    T1 := GetTickCount64;

    // Phase 2: Diff
    Prev.Diff(Curr, Patches);
    T2 := GetTickCount64;

    // Phase 3: Draw
    Backend.DrawPatches(Patches);
    Backend.DiscardPending;
    T3 := GetTickCount64;

    FillMs := FillMs + (T1 - T0);
    DiffMs := DiffMs + (T2 - T1);
    DrawMs := DrawMs + (T3 - T2);

    Tmp := Prev; Prev := Curr; Curr := Tmp;
    Curr.Reset;
  end;

  WriteLn(Format('Fill:  %.1f ms total, %.1f us/frame', [FillMs, FillMs * 1000 / FRAMES]));
  WriteLn(Format('Diff:  %.1f ms total, %.1f us/frame', [DiffMs, DiffMs * 1000 / FRAMES]));
  WriteLn(Format('Draw:  %.1f ms total, %.1f us/frame', [DrawMs, DrawMs * 1000 / FRAMES]));
  WriteLn(Format('Total: %.1f ms, %.1f us/frame', [FillMs + DiffMs + DrawMs, (FillMs + DiffMs + DrawMs) * 1000 / FRAMES]));

  Curr.Free; Prev.Free; Backend.Free;
end.
