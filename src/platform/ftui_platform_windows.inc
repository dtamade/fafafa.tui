{ ftui_platform_windows.inc — Windows implementation (VT mode) }
{ Requires Windows 10 1903+ with ENABLE_VIRTUAL_TERMINAL_INPUT support }

const
  ENABLE_VIRTUAL_TERMINAL_INPUT      = $0200;
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
  DISABLE_NEWLINE_AUTO_RETURN        = $0008;

var
  GResizePending: LongInt = 0;
  GTermPending: LongInt = 0;
  GLastCols, GLastRows: Word;

function PlatformTickMs: QWord;
begin
  Result := GetTickCount64;
end;

function PlatformIsTerminal(Fd: TPlatformFd): Boolean;
var
  Mode: DWORD;
begin
  Mode := 0;
  Result := GetConsoleMode(Fd, Mode);
end;

function PlatformGetTermSize(Fd: TPlatformFd; out Sz: TTermSize): Boolean;
var
  Info: CONSOLE_SCREEN_BUFFER_INFO;
  hOut: THandle;
begin
  Result := False;
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if not GetConsoleScreenBufferInfo(hOut, Info) then Exit;
  Sz.Cols := Info.srWindow.Right - Info.srWindow.Left + 1;
  Sz.Rows := Info.srWindow.Bottom - Info.srWindow.Top + 1;
  Result := (Sz.Cols > 0) and (Sz.Rows > 0);
end;

function PlatformEnterRaw(Fd: TPlatformFd; out State: TPlatformTermState): Boolean;
var
  hIn, hOut: THandle;
begin
  Result := False;
  hIn := GetStdHandle(STD_INPUT_HANDLE);
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if not GetConsoleMode(hIn, State.InMode) then Exit;
  if not GetConsoleMode(hOut, State.OutMode) then Exit;
  if not SetConsoleMode(hIn, ENABLE_VIRTUAL_TERMINAL_INPUT) then Exit;
  if not SetConsoleMode(hOut,
    ENABLE_PROCESSED_OUTPUT or ENABLE_VIRTUAL_TERMINAL_PROCESSING or
    DISABLE_NEWLINE_AUTO_RETURN) then Exit;
  Result := True;
end;

function PlatformLeaveRaw(Fd: TPlatformFd; const State: TPlatformTermState): Boolean;
var
  hIn, hOut: THandle;
begin
  hIn := GetStdHandle(STD_INPUT_HANDLE);
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleMode(hIn, State.InMode);
  SetConsoleMode(hOut, State.OutMode);
  Result := True;
end;

function PlatformRead(Fd: TPlatformFd; Buf: PByte; Count: Integer): Integer;
var
  hIn: THandle;
  BytesRead: DWORD;
begin
  hIn := GetStdHandle(STD_INPUT_HANDLE);
  BytesRead := 0;
  if ReadFile(hIn, Buf^, DWORD(Count), BytesRead, nil) then
    Result := Integer(BytesRead)
  else
    Result := -1;
end;

function PlatformWrite(Fd: TPlatformFd; Buf: PByte; Count: Integer): Boolean;
var
  hOut: THandle;
  Written: DWORD;
  Sent: Integer;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  Sent := 0;
  while Sent < Count do
  begin
    Written := 0;
    if not WriteFile(hOut, (Buf + Sent)^, DWORD(Count - Sent), Written, nil) then
      Exit(False);
    if Written = 0 then Exit(False);
    Inc(Sent, Integer(Written));
  end;
  Result := True;
end;

function PlatformWaitReadable(Fd: TPlatformFd; TimeoutMs: Integer): Boolean;
var
  hIn: THandle;
  WaitMs: DWORD;
  Ret: DWORD;
  Sz: TTermSize;
begin
  hIn := GetStdHandle(STD_INPUT_HANDLE);
  if TimeoutMs < 0 then WaitMs := INFINITE else WaitMs := DWORD(TimeoutMs);
  Ret := WaitForSingleObject(hIn, WaitMs);
  if PlatformGetTermSize(Fd, Sz) then
  begin
    if (Sz.Cols <> GLastCols) or (Sz.Rows <> GLastRows) then
    begin
      GLastCols := Sz.Cols;
      GLastRows := Sz.Rows;
      InterlockedExchange(GResizePending, 1);
    end;
  end;
  Result := (Ret = WAIT_OBJECT_0);
end;

procedure PlatformHookResize;
var
  Sz: TTermSize;
begin
  if PlatformGetTermSize(0, Sz) then
  begin
    GLastCols := Sz.Cols;
    GLastRows := Sz.Rows;
  end;
end;

procedure PlatformUnhookResize;
begin
end;

function CtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  case dwCtrlType of
    CTRL_C_EVENT, CTRL_CLOSE_EVENT, CTRL_BREAK_EVENT:
      InterlockedExchange(GTermPending, 1);
  end;
  Result := True;
end;

procedure PlatformHookTerminate;
begin
  SetConsoleCtrlHandler(@CtrlHandler, True);
end;

procedure PlatformUnhookTerminate;
begin
  SetConsoleCtrlHandler(@CtrlHandler, False);
end;

function PlatformConsumeResize: Boolean;
begin
  Result := InterlockedExchange(GResizePending, 0) <> 0;
end;

function PlatformConsumeTerminate: Boolean;
begin
  Result := InterlockedExchange(GTermPending, 0) <> 0;
end;
