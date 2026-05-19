program bench_diff_profile;

// Profiling variant: measures fill / diff / draw separately at multiple
// change rates to reflect real-world terminal usage patterns.

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
  TOTAL_CELLS = WIDTH * HEIGHT;
  FRAMES = 1000;

procedure RunScattered(const Tag: AnsiString; ChangePercent: Integer);
var
  Prev, Curr, Tmp: TBuffer;
  Backend: TAnsiBackend;
  Patches: TDiffEntries;
  Frame, X, Y: Integer;
  T0, T1, T2, T3: Int64;
  FillMs, DiffMs, DrawMs: Double;
  CP, Base, PrevBase: PCell;
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
    T0 := GetTickCount64;
    Sty := TStyle.Default.WithFg(IndexedColor(Byte(Frame mod 7) + 1));
    Ch := Byte(Ord('a') + (Frame mod 26));
    Base := Curr.ContentPtr;
    PrevBase := Prev.ContentPtr;
    for Y := 0 to HEIGHT - 1 do
      for X := 0 to WIDTH - 1 do
      begin
        CP := Base + (Y * WIDTH + X);
        if ((X * 7 + Y * 13 + Frame * 3) mod 100) < ChangePercent then
        begin
          CellSetSymbolAscii(CP^, AnsiChar(Ch));
          CellApplyStyle(CP^, Sty);
        end
        else
          CP^ := (PrevBase + (Y * WIDTH + X))^;
      end;
    T1 := GetTickCount64;

    Prev.Diff(Curr, Patches);
    T2 := GetTickCount64;

    Backend.DrawPatches(Patches);
    Backend.DiscardPending;
    T3 := GetTickCount64;

    FillMs := FillMs + (T1 - T0);
    DiffMs := DiffMs + (T2 - T1);
    DrawMs := DrawMs + (T3 - T2);

    Tmp := Prev; Prev := Curr; Curr := Tmp;
    Curr.Reset;
  end;

  WriteLn(Format('  [%s] %d%% scattered (%d cells/frame):', [Tag, ChangePercent, TOTAL_CELLS * ChangePercent div 100]));
  WriteLn(Format('    Fill:  %6.1f us/frame', [FillMs * 1000 / FRAMES]));
  WriteLn(Format('    Diff:  %6.1f us/frame', [DiffMs * 1000 / FRAMES]));
  WriteLn(Format('    Draw:  %6.1f us/frame', [DrawMs * 1000 / FRAMES]));
  WriteLn(Format('    Total: %6.1f us/frame', [(FillMs + DiffMs + DrawMs) * 1000 / FRAMES]));
  WriteLn;

  Curr.Free; Prev.Free; Backend.Free;
end;

procedure RunClustered(const Tag: AnsiString; DirtyRows: Integer);
var
  Prev, Curr, Tmp: TBuffer;
  Backend: TAnsiBackend;
  Patches: TDiffEntries;
  Frame, X, Y: Integer;
  T0, T1, T2, T3: Int64;
  FillMs, DiffMs, DrawMs: Double;
  CP, Base, PrevBase: PCell;
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
    T0 := GetTickCount64;
    Sty := TStyle.Default.WithFg(IndexedColor(Byte(Frame mod 7) + 1));
    Ch := Byte(Ord('a') + (Frame mod 26));
    Base := Curr.ContentPtr;
    PrevBase := Prev.ContentPtr;
    for Y := 0 to HEIGHT - 1 do
      for X := 0 to WIDTH - 1 do
      begin
        CP := Base + (Y * WIDTH + X);
        if Y < DirtyRows then
        begin
          CellSetSymbolAscii(CP^, AnsiChar(Ch));
          CellApplyStyle(CP^, Sty);
        end
        else
          CP^ := (PrevBase + (Y * WIDTH + X))^;
      end;
    T1 := GetTickCount64;

    Prev.Diff(Curr, Patches);
    T2 := GetTickCount64;

    Backend.DrawPatches(Patches);
    Backend.DiscardPending;
    T3 := GetTickCount64;

    FillMs := FillMs + (T1 - T0);
    DiffMs := DiffMs + (T2 - T1);
    DrawMs := DrawMs + (T3 - T2);

    Tmp := Prev; Prev := Curr; Curr := Tmp;
    Curr.Reset;
  end;

  WriteLn(Format('  [%s] %d/%d rows dirty (clustered):', [Tag, DirtyRows, HEIGHT]));
  WriteLn(Format('    Fill:  %6.1f us/frame', [FillMs * 1000 / FRAMES]));
  WriteLn(Format('    Diff:  %6.1f us/frame', [DiffMs * 1000 / FRAMES]));
  WriteLn(Format('    Draw:  %6.1f us/frame', [DrawMs * 1000 / FRAMES]));
  WriteLn(Format('    Total: %6.1f us/frame', [(FillMs + DiffMs + DrawMs) * 1000 / FRAMES]));
  WriteLn;

  Curr.Free; Prev.Free; Backend.Free;
end;

begin
  WriteLn('=== Diff Profile (200x60, 1000 frames) ===');
  WriteLn;
  WriteLn('--- Scattered changes ---');
  RunScattered('5pct', 5);
  RunScattered('25pct', 25);
  RunScattered('75pct', 75);
  WriteLn('--- Clustered changes (real-world) ---');
  RunClustered('2rows', 2);
  RunClustered('5rows', 5);
  RunClustered('15rows', 15);
end.
