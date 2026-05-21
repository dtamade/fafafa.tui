program sysmon;

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_app,
  ftui_event,
  ftui_terminal,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_buffer,
  ftui_block,
  ftui_borders,
  ftui_layout,
  ftui_tabs,
  ftui_table,
  ftui_gauge,
  ftui_sparkline,
  ftui_format,
  ftui_paragraph;

const
  TICK_MS = 1000;
  MAX_PROCS = 50;
  CPU_HISTORY = 120;

type
  TCpuSample = record
    User, Nice, System_, Idle, IOWait, IRQ, SoftIRQ: Int64;
  end;

  TNetSample = record
    RxBytes, TxBytes: Int64;
  end;

  TProcInfo = record
    PID: Integer;
    Name: AnsiString;
    State: AnsiChar;
    RSS: Int64;
    CPUPct: Double;
  end;

  TSysmonApp = class(TApp)
  private
    FTabState: TTabsState;
    FTableState: TTableState;
    FPrevCpu: TCpuSample;
    FCpuPct: Double;
    FCpuHistory: array[0..CPU_HISTORY-1] of Double;
    FCpuHistLen: Integer;
    FMemTotal, FMemUsed: Int64;
    FLoadAvg: AnsiString;
    FUptime: AnsiString;
    FHostname: AnsiString;
    FKernel: AnsiString;
    FProcs: array of TProcInfo;
    FProcCount: Integer;
    FPrevNet: TNetSample;
    FNetRx, FNetTx: Int64;
    FNetRxHist: array[0..CPU_HISTORY-1] of Double;
    FNetTxHist: array[0..CPU_HISTORY-1] of Double;
    FNetHistLen: Integer;
    procedure ReadCpu;
    procedure ReadMem;
    procedure ReadProcs;
    procedure ReadNet;
    procedure ReadLoadAvg;
    procedure ReadSysInfo;
    procedure RenderOverview(const Area: TRect; Buf: TBuffer);
    procedure RenderProcesses(const Area: TRect; Buf: TBuffer);
    procedure RenderNetwork(const Area: TRect; Buf: TBuffer);
  protected
    procedure OnInit; override;
    procedure OnTick; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

{ /proc readers }

function ReadFileStr(const Path: AnsiString): AnsiString;
var F: TextFile; S, Line: AnsiString;
begin
  S := '';
  AssignFile(F, Path);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then begin Result := ''; Exit; end;
  while not EOF(F) do
  begin
    ReadLn(F, Line);
    S := S + Line + #10;
  end;
  CloseFile(F);
  Result := S;
end;

function ParseInt(const S: AnsiString; var Pos: Integer): Int64;
var Neg: Boolean;
begin
  Result := 0;
  while (Pos <= Length(S)) and (S[Pos] = ' ') do Inc(Pos);
  Neg := (Pos <= Length(S)) and (S[Pos] = '-');
  if Neg then Inc(Pos);
  while (Pos <= Length(S)) and (S[Pos] in ['0'..'9']) do
  begin
    Result := Result * 10 + Ord(S[Pos]) - Ord('0');
    Inc(Pos);
  end;
  if Neg then Result := -Result;
  while (Pos <= Length(S)) and (S[Pos] = ' ') do Inc(Pos);
end;

procedure TSysmonApp.ReadCpu;
var
  S: AnsiString;
  P: Integer;
  Cur: TCpuSample;
  TotalDiff, IdleDiff: Int64;
begin
  S := ReadFileStr('/proc/stat');
  if S = '' then Exit;
  P := 5; // skip "cpu "
  Cur.User := ParseInt(S, P);
  Cur.Nice := ParseInt(S, P);
  Cur.System_ := ParseInt(S, P);
  Cur.Idle := ParseInt(S, P);
  Cur.IOWait := ParseInt(S, P);
  Cur.IRQ := ParseInt(S, P);
  Cur.SoftIRQ := ParseInt(S, P);

  TotalDiff := (Cur.User + Cur.Nice + Cur.System_ + Cur.Idle + Cur.IOWait + Cur.IRQ + Cur.SoftIRQ)
             - (FPrevCpu.User + FPrevCpu.Nice + FPrevCpu.System_ + FPrevCpu.Idle + FPrevCpu.IOWait + FPrevCpu.IRQ + FPrevCpu.SoftIRQ);
  IdleDiff := (Cur.Idle + Cur.IOWait) - (FPrevCpu.Idle + FPrevCpu.IOWait);

  if TotalDiff > 0 then
    FCpuPct := 1.0 - (IdleDiff / TotalDiff)
  else
    FCpuPct := 0;

  if FCpuHistLen < CPU_HISTORY then
  begin
    FCpuHistory[FCpuHistLen] := FCpuPct;
    Inc(FCpuHistLen);
  end
  else
  begin
    Move(FCpuHistory[1], FCpuHistory[0], (CPU_HISTORY - 1) * SizeOf(Double));
    FCpuHistory[CPU_HISTORY - 1] := FCpuPct;
  end;

  FPrevCpu := Cur;
end;

procedure TSysmonApp.ReadMem;
var
  S: AnsiString;
  P, LineStart: Integer;
  MemFree, Buffers, Cached: Int64;
begin
  S := ReadFileStr('/proc/meminfo');
  if S = '' then Exit;
  FMemTotal := 0; MemFree := 0; Buffers := 0; Cached := 0;
  P := 1;
  while P <= Length(S) do
  begin
    LineStart := P;
    while (P <= Length(S)) and (S[P] <> #10) do Inc(P);
    if Copy(S, LineStart, 9) = 'MemTotal:' then
    begin P := LineStart + 9; FMemTotal := ParseInt(S, P); end
    else if Copy(S, LineStart, 8) = 'MemFree:' then
    begin P := LineStart + 8; MemFree := ParseInt(S, P); end
    else if Copy(S, LineStart, 8) = 'Buffers:' then
    begin P := LineStart + 8; Buffers := ParseInt(S, P); end
    else if Copy(S, LineStart, 7) = 'Cached:' then
    begin P := LineStart + 7; Cached := ParseInt(S, P); end;
    while (P <= Length(S)) and (S[P] <> #10) do Inc(P);
    Inc(P);
  end;
  FMemUsed := FMemTotal - MemFree - Buffers - Cached;
  if FMemUsed < 0 then FMemUsed := 0;
end;

procedure TSysmonApp.ReadLoadAvg;
var S: AnsiString;
begin
  S := ReadFileStr('/proc/loadavg');
  if Length(S) > 0 then
    FLoadAvg := Copy(S, 1, Pos(' ', S + ' ') - 1 + 10);
  while (Length(FLoadAvg) > 0) and (FLoadAvg[Length(FLoadAvg)] in [#10, #13]) do
    SetLength(FLoadAvg, Length(FLoadAvg) - 1);
end;

procedure TSysmonApp.ReadSysInfo;
var S: AnsiString; P: Integer; Secs, Mins, Hrs, Days: Int64;
begin
  S := ReadFileStr('/proc/sys/kernel/hostname');
  while (Length(S) > 0) and (S[Length(S)] in [#10, #13]) do
    SetLength(S, Length(S) - 1);
  FHostname := S;

  S := ReadFileStr('/proc/sys/kernel/osrelease');
  while (Length(S) > 0) and (S[Length(S)] in [#10, #13]) do
    SetLength(S, Length(S) - 1);
  FKernel := S;

  S := ReadFileStr('/proc/uptime');
  P := 1;
  Secs := ParseInt(S, P);
  Days := Secs div 86400;
  Hrs := (Secs mod 86400) div 3600;
  Mins := (Secs mod 3600) div 60;
  if Days > 0 then
    FUptime := IntToStr(Days) + 'd ' + IntToStr(Hrs) + 'h ' + IntToStr(Mins) + 'm'
  else if Hrs > 0 then
    FUptime := IntToStr(Hrs) + 'h ' + IntToStr(Mins) + 'm'
  else
    FUptime := IntToStr(Mins) + 'm';
end;

procedure TSysmonApp.ReadProcs;
var
  SR: TSearchRec;
  PID, P: Integer;
  S, Name: AnsiString;
  RSS: Int64;
  St: AnsiChar;
  I, J: Integer;
  Tmp: TProcInfo;
begin
  FProcCount := 0;
  SetLength(FProcs, MAX_PROCS);
  if FindFirst('/proc/[0-9]*', faDirectory, SR) = 0 then
  begin
    repeat
      Val(SR.Name, PID, P);
      if P <> 0 then Continue;
      S := ReadFileStr('/proc/' + SR.Name + '/stat');
      if S = '' then Continue;
      P := Pos('(', S);
      if P = 0 then Continue;
      Name := '';
      Inc(P);
      while (P <= Length(S)) and (S[P] <> ')') do
      begin
        Name := Name + S[P];
        Inc(P);
      end;
      Inc(P);
      while (P <= Length(S)) and (S[P] = ' ') do Inc(P);
      if P <= Length(S) then St := S[P] else St := '?';
      Inc(P);
      RSS := 0;
      S := ReadFileStr('/proc/' + SR.Name + '/statm');
      if S <> '' then
      begin
        P := 1;
        ParseInt(S, P);
        RSS := ParseInt(S, P);
        RSS := RSS * 4;
      end;

      if FProcCount < MAX_PROCS then
      begin
        FProcs[FProcCount].PID := PID;
        FProcs[FProcCount].Name := Name;
        FProcs[FProcCount].State := St;
        FProcs[FProcCount].RSS := RSS;
        FProcs[FProcCount].CPUPct := 0;
        Inc(FProcCount);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  // Sort by RSS descending (insertion sort, N <= 50)
  for I := 1 to FProcCount - 1 do
  begin
    Tmp := FProcs[I];
    J := I - 1;
    while (J >= 0) and (FProcs[J].RSS < Tmp.RSS) do
    begin
      FProcs[J + 1] := FProcs[J];
      Dec(J);
    end;
    FProcs[J + 1] := Tmp;
  end;
end;

procedure TSysmonApp.ReadNet;
var
  S: AnsiString;
  P, FieldIdx: Integer;
  RxTotal, TxTotal, Val_: Int64;
begin
  S := ReadFileStr('/proc/net/dev');
  if S = '' then Exit;
  RxTotal := 0;
  TxTotal := 0;
  P := 1;
  // Skip 2 header lines
  while (P <= Length(S)) and (S[P] <> #10) do Inc(P); Inc(P);
  while (P <= Length(S)) and (S[P] <> #10) do Inc(P); Inc(P);
  // Parse each interface line
  while P <= Length(S) do
  begin
    while (P <= Length(S)) and (S[P] <> ':') and (S[P] <> #10) do Inc(P);
    if (P > Length(S)) or (S[P] = #10) then begin Inc(P); Continue; end;
    Inc(P); // skip ':'
    // Fields: rx_bytes rx_packets ... (8 fields) tx_bytes tx_packets ... (8 fields)
    for FieldIdx := 1 to 16 do
    begin
      Val_ := ParseInt(S, P);
      if FieldIdx = 1 then Inc(RxTotal, Val_);
      if FieldIdx = 9 then Inc(TxTotal, Val_);
    end;
    while (P <= Length(S)) and (S[P] <> #10) do Inc(P);
    Inc(P);
  end;

  if FPrevNet.RxBytes > 0 then
  begin
    FNetRx := RxTotal - FPrevNet.RxBytes;
    FNetTx := TxTotal - FPrevNet.TxBytes;
    if FNetHistLen < CPU_HISTORY then
    begin
      FNetRxHist[FNetHistLen] := FNetRx / 1024;
      FNetTxHist[FNetHistLen] := FNetTx / 1024;
      Inc(FNetHistLen);
    end
    else
    begin
      Move(FNetRxHist[1], FNetRxHist[0], (CPU_HISTORY - 1) * SizeOf(Double));
      Move(FNetTxHist[1], FNetTxHist[0], (CPU_HISTORY - 1) * SizeOf(Double));
      FNetRxHist[CPU_HISTORY - 1] := FNetRx / 1024;
      FNetTxHist[CPU_HISTORY - 1] := FNetTx / 1024;
    end;
  end;
  FPrevNet.RxBytes := RxTotal;
  FPrevNet.TxBytes := TxTotal;
end;

{ App lifecycle }

procedure TSysmonApp.OnInit;
var I: Integer;
begin
  TickInterval := TICK_MS;
  FTabState.Selected := 0;
  FTableState := TTableState.Empty;
  FTableState.HasSelection := True;
  FPrevNet.RxBytes := 0;
  FPrevNet.TxBytes := 0;
  FNetRx := 0;
  FNetTx := 0;
  FCpuHistLen := 0;
  FNetHistLen := 0;
  for I := 0 to CPU_HISTORY - 1 do
  begin
    FCpuHistory[I] := 0.0;
    FNetRxHist[I] := 0.0;
    FNetTxHist[I] := 0.0;
  end;
  ReadSysInfo;
  ReadCpu;
  ReadMem;
  ReadProcs;
  ReadNet;
  ReadLoadAvg;
end;

procedure TSysmonApp.OnTick;
begin
  ReadCpu;
  ReadMem;
  ReadProcs;
  ReadNet;
  ReadLoadAvg;
  ReadSysInfo;
end;

procedure TSysmonApp.Render(var Frame: TFrame);
var Rows: TRectArray;
begin
  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1), FillConstraint(1), LengthConstraint(1)
  ]);
  TTabs.Create(['Overview', 'Processes', 'Network'])
    .WithActiveStyle(TStyle.Default.WithModifier([mbBold, mbReversed]))
    .WithInactiveStyle(TStyle.Default)
    .RenderStateful(Rows[0], Frame.Buffer, FTabState);
  case FTabState.Selected of
    0: RenderOverview(Rows[1], Frame.Buffer);
    1: RenderProcesses(Rows[1], Frame.Buffer);
    2: RenderNetwork(Rows[1], Frame.Buffer);
  end;
  TParagraph.FromString(' Tab/Shift+Tab: switch  Up/Down: navigate  q: quit')
    .WithStyle(TStyle.Default.WithModifier([mbReversed]))
    .Render(Rows[2], Frame.Buffer);
end;

procedure TSysmonApp.RenderOverview(const Area: TRect; Buf: TBuffer);
var
  Panels: TRectArray;
  CpuStr: string[16];
  MemStr: AnsiString;
  MemPct: Double;
  HistData: array of Double;
  I: Integer;
  GreenSty, YellowSty, RedSty: TStyle;
begin
  Panels := VerticalSplit(Area, [
    LengthConstraint(3), LengthConstraint(3), LengthConstraint(5), FillConstraint(1)
  ]);

  GreenSty := TStyle.Default.WithFg(IndexedColor(2));
  YellowSty := TStyle.Default.WithFg(IndexedColor(3));
  RedSty := TStyle.Default.WithFg(IndexedColor(1));

  Str(Round(FCpuPct * 100):3, CpuStr);
  TGauge.Default.WithRatio(FCpuPct).WithLabel(CpuStr + '%')
    .WithThreshold(0.0, GreenSty)
    .WithThreshold(0.7, YellowSty)
    .WithThreshold(0.9, RedSty)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' CPU '))
    .Render(Panels[0], Buf);

  if FMemTotal > 0 then
    MemPct := FMemUsed / FMemTotal
  else
    MemPct := 0;
  MemStr := FormatBytesKB(FMemUsed);
  TGauge.Default.WithRatio(MemPct).WithLabel(MemStr)
    .WithThreshold(0.0, GreenSty)
    .WithThreshold(0.7, YellowSty)
    .WithThreshold(0.9, RedSty)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Memory '))
    .Render(Panels[1], Buf);

  SetLength(HistData, FCpuHistLen);
  for I := 0 to FCpuHistLen - 1 do
    HistData[I] := FCpuHistory[I];
  TSparkline.Create(HistData)
    .WithMax(1.0)
    .WithStyle(GreenSty)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' CPU History '))
    .Render(Panels[2], Buf);

  TParagraph.FromString(
    'Host:   ' + FHostname + #10 +
    'Kernel: ' + FKernel + #10 +
    'Uptime: ' + FUptime + #10 +
    'Load:   ' + FLoadAvg + #10 +
    'Procs:  ' + IntToStr(FProcCount)
  )
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' System '))
    .Render(Panels[3], Buf);
end;

procedure TSysmonApp.RenderProcesses(const Area: TRect; Buf: TBuffer);
var
  Tbl: TTable;
  Rows: array of TTableRow;
  I, N: Integer;
begin
  N := FProcCount;
  if N > Area.Height - 3 then N := Area.Height - 3;
  if N < 0 then N := 0;
  SetLength(Rows, N);
  for I := 0 to N - 1 do
    Rows[I] := TTableRow.Make([
      IntToStr(FProcs[I].PID),
      FProcs[I].Name,
      FProcs[I].State,
      FormatBytesKB(FProcs[I].RSS)
    ]);
  Tbl := TTable.Create([
    TTableColumn.Make('PID', LengthConstraint(8)).WithAlign(caRight),
    TTableColumn.Make('Name', FillConstraint(2)),
    TTableColumn.Make('S', LengthConstraint(3)),
    TTableColumn.Make('RSS', LengthConstraint(12)).WithAlign(caRight)
  ])
    .WithRows(Rows)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Processes (by RSS) '))
    .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]));
  Tbl.RenderStateful(Area, Buf, FTableState);
end;

procedure TSysmonApp.RenderNetwork(const Area: TRect; Buf: TBuffer);
var
  Panels: TRectArray;
  RxData, TxData: array of Double;
  I: Integer;
  RxStr, TxStr: AnsiString;
begin
  Panels := VerticalSplit(Area, [
    LengthConstraint(3), FillConstraint(1), FillConstraint(1)
  ]);

  RxStr := FormatBytes(FNetRx);
  TxStr := FormatBytes(FNetTx);
  TParagraph.FromString(
    'RX: ' + RxStr + '/s    TX: ' + TxStr + '/s'
  )
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' Current '))
    .Render(Panels[0], Buf);

  SetLength(RxData, FNetHistLen);
  for I := 0 to FNetHistLen - 1 do
    RxData[I] := FNetRxHist[I];
  TSparkline.Create(RxData)
    .WithStyle(TStyle.Default.WithFg(IndexedColor(6)))
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' RX History (KB/s) '))
    .Render(Panels[1], Buf);

  SetLength(TxData, FNetHistLen);
  for I := 0 to FNetHistLen - 1 do
    TxData[I] := FNetTxHist[I];
  TSparkline.Create(TxData)
    .WithStyle(TStyle.Default.WithFg(IndexedColor(5)))
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' TX History (KB/s) '))
    .Render(Panels[2], Buf);
end;

procedure TSysmonApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcTab: FTabState.Selected := (FTabState.Selected + 1) mod 3;
    kcBackTab: FTabState.Selected := (FTabState.Selected + 2) mod 3;
    kcUp:
      if (FTabState.Selected = 1) and (FTableState.Selected > 0) then
        Dec(FTableState.Selected);
    kcDown:
      if FTabState.Selected = 1 then
        Inc(FTableState.Selected);
    kcChar:
      if Ev.Key.Ch = Ord('q') then Quit;
  end;
end;

var App: TSysmonApp;
begin
  App := TSysmonApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.


