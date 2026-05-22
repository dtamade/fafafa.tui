{ ftui_platform_unix.inc — Unix shared implementation (Linux + macOS + FreeBSD) }

{$IFDEF LINUX}
uses Linux;
{$ELSE}
uses Unix;
{$ENDIF}

const
  {$IFDEF LINUX}
  FTUI_TIOCGWINSZ = $5413;
  {$ELSE}
  FTUI_TIOCGWINSZ = $40087468;
  {$ENDIF}

type
  TWinSize = record
    ws_row: Word;
    ws_col: Word;
    ws_xpixel: Word;
    ws_ypixel: Word;
  end;

var
  GResizePending: LongInt = 0;
  GTermPending: LongInt = 0;
  GSavedSigwinch: SigActionRec;
  GSavedSigterm: SigActionRec;

function PlatformTickMs: QWord;
{$IFDEF LINUX}
var
  ts: TimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @ts);
  Result := QWord(ts.tv_sec) * 1000 + QWord(ts.tv_nsec) div 1000000;
end;
{$ELSE}
var
  tp: TTimeVal;
begin
  fpgettimeofday(@tp, nil);
  Result := QWord(tp.tv_sec) * 1000 + QWord(tp.tv_usec) div 1000;
end;
{$ENDIF}

function PlatformIsTerminal(Fd: TPlatformFd): Boolean;
begin
  Result := IsATTY(Fd) = 1;
end;

function PlatformGetTermSize(Fd: TPlatformFd; out Sz: TTermSize): Boolean;
var
  WS: TWinSize;
begin
  Result := False;
  FillChar(WS, SizeOf(WS), 0);
  if fpioctl(Fd, FTUI_TIOCGWINSZ, @WS) <> 0 then Exit;
  if (WS.ws_col = 0) or (WS.ws_row = 0) then Exit;
  Sz.Cols := WS.ws_col;
  Sz.Rows := WS.ws_row;
  Result := True;
end;

function PlatformEnterRaw(Fd: TPlatformFd; out State: TPlatformTermState): Boolean;
var
  Raw: TermIOS;
begin
  Result := False;
  FillChar(State, SizeOf(State), 0);
  if not PlatformIsTerminal(Fd) then Exit;
  if TCGetAttr(Fd, State.Saved) <> 0 then Exit;
  Raw := State.Saved;
  Raw.c_iflag := Raw.c_iflag and (not (IGNBRK or BRKINT or PARMRK or ISTRIP
                                        or INLCR or IGNCR or ICRNL or IXON));
  Raw.c_oflag := Raw.c_oflag and (not OPOST);
  Raw.c_lflag := Raw.c_lflag and (not (ECHO or ECHONL or ICANON or ISIG or IEXTEN));
  Raw.c_cflag := Raw.c_cflag and (not (CSIZE or PARENB));
  Raw.c_cflag := Raw.c_cflag or CS8;
  Raw.c_cc[VMIN] := 0;
  Raw.c_cc[VTIME] := 0;
  Result := TCSetAttr(Fd, TCSANOW, Raw) = 0;
end;

function PlatformLeaveRaw(Fd: TPlatformFd; const State: TPlatformTermState): Boolean;
begin
  Result := TCSetAttr(Fd, TCSANOW, State.Saved) = 0;
end;

function PlatformRead(Fd: TPlatformFd; Buf: PByte; Count: Integer): Integer;
var
  Rc: TSSize;
begin
  repeat
    Rc := fpRead(Fd, Buf^, Count);
  until (Rc >= 0) or (fpGetErrno <> ESysEINTR);
  Result := Integer(Rc);
end;

function PlatformWrite(Fd: TPlatformFd; Buf: PByte; Count: Integer): Boolean;
var
  Sent, Wrote: Integer;
begin
  Sent := 0;
  while Sent < Count do
  begin
    Wrote := Integer(fpWrite(Fd, (Buf + Sent)^, Count - Sent));
    if Wrote < 0 then
    begin
      if fpGetErrno = ESysEINTR then Continue;
      Exit(False);
    end;
    if Wrote = 0 then Exit(False);
    Inc(Sent, Wrote);
  end;
  Result := True;
end;

function PlatformWaitReadable(Fd: TPlatformFd; TimeoutMs: Integer): Boolean;
var
  Pfd: TPollFd;
  Rc: cint;
begin
  Pfd.fd := Fd;
  Pfd.events := POLLIN;
  Pfd.revents := 0;
  repeat
    Rc := fpPoll(@Pfd, 1, TimeoutMs);
  until (Rc >= 0) or (fpGetErrno <> ESysEINTR);
  if Rc <= 0 then Exit(False);
  Result := (Pfd.revents and POLLIN) <> 0;
end;

procedure SigwinchHandler(Sig: cint); cdecl;
begin
  InterlockedExchange(GResizePending, 1);
end;

procedure SigtermHandler(Sig: cint); cdecl;
begin
  InterlockedExchange(GTermPending, 1);
end;

procedure PlatformHookResize;
var
  Act: SigActionRec;
begin
  FillChar(Act, SizeOf(Act), 0);
  Act.sa_handler := SigActionHandler(@SigwinchHandler);
  fpSigAction(SIGWINCH, @Act, @GSavedSigwinch);
end;

procedure PlatformUnhookResize;
begin
  fpSigAction(SIGWINCH, @GSavedSigwinch, nil);
end;

procedure PlatformHookTerminate;
var
  Act: SigActionRec;
begin
  FillChar(Act, SizeOf(Act), 0);
  Act.sa_handler := SigActionHandler(@SigtermHandler);
  fpSigAction(SIGTERM, @Act, @GSavedSigterm);
end;

procedure PlatformUnhookTerminate;
begin
  fpSigAction(SIGTERM, @GSavedSigterm, nil);
end;

function PlatformConsumeResize: Boolean;
begin
  Result := InterlockedExchange(GResizePending, 0) <> 0;
end;

function PlatformConsumeTerminate: Boolean;
begin
  Result := InterlockedExchange(GTermPending, 0) <> 0;
end;
