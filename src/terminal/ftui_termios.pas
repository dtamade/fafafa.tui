unit ftui_termios;

// Minimal terminal-control surface needed by TTerminal.
//
//   - EnterRawMode / LeaveRawMode: flip cflags so reads return per
//     byte without line buffering, control chars don't generate
//     signals, echo is off.  termios state is captured on enter and
//     restored on leave.
//   - GetTerminalSize: ioctl TIOCGWINSZ to fetch (cols, rows)
//   - WaitForBytes: poll(stdin) up to TimeoutMs, returning whether
//     bytes are ready (we don't read here; caller does fpread).
//
// All Linux-only for M3.  The unit is the only place tying the rest
// of fafafa.tui to BaseUnix; if a future port to Windows / BSD
// needs different syscalls, only this file changes.

{$mode objfpc}{$H+}{$inline on}

interface

uses
  BaseUnix,
  termio;

type
  TTermSize = record
    Cols, Rows: Word;
  end;

// Returns True iff Fd refers to a terminal (vs a pipe / file).
function IsATerminal(Fd: cint): Boolean; inline;

// Capture current termios into Saved, then put Fd into raw mode.
// Returns False on failure (Fd not a tty, ioctl failed).
function EnterRawMode(Fd: cint; out Saved: TermIOS): Boolean;

// Restore Fd to the captured Saved termios.
function LeaveRawMode(Fd: cint; const Saved: TermIOS): Boolean;

// Query terminal cell dimensions via TIOCGWINSZ.  Returns False on
// failure; Out_ unchanged.
function GetTerminalSize(Fd: cint; out Out_: TTermSize): Boolean;

// Block up to TimeoutMs waiting for at least one byte to be readable
// from Fd.  Negative TimeoutMs blocks forever.  Returns True on
// readable, False on timeout / error.  EINTR is retried.
function WaitForBytes(Fd: cint; TimeoutMs: Integer): Boolean;

implementation

const
  // ioctl request to get window size.  Defined in <sys/ioctl.h> as
  // TIOCGWINSZ = 0x5413 on Linux.
  FTUI_TIOCGWINSZ = $5413;

type
  // Linux struct winsize (sys/ioctl.h).  4 unsigned shorts.
  TWinSize = record
    ws_row: Word;
    ws_col: Word;
    ws_xpixel: Word;
    ws_ypixel: Word;
  end;

function IsATerminal(Fd: cint): Boolean;
begin
  Result := IsATTY(Fd) = 1;
end;

function EnterRawMode(Fd: cint; out Saved: TermIOS): Boolean;
var
  Raw: TermIOS;
begin
  Result := False;
  FillChar(Saved, SizeOf(Saved), 0);
  if not IsATerminal(Fd) then Exit;
  if TCGetAttr(Fd, Saved) <> 0 then Exit;

  Raw := Saved;

  // Match cfmakeraw():
  //   iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON)
  //   oflag &= ~OPOST
  //   lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN)
  //   cflag &= ~(CSIZE | PARENB)
  //   cflag |= CS8
  Raw.c_iflag := Raw.c_iflag and (not (IGNBRK or BRKINT or PARMRK or ISTRIP
                                        or INLCR or IGNCR or ICRNL or IXON));
  Raw.c_oflag := Raw.c_oflag and (not OPOST);
  Raw.c_lflag := Raw.c_lflag and (not (ECHO or ECHONL or ICANON or ISIG or IEXTEN));
  Raw.c_cflag := Raw.c_cflag and (not (CSIZE or PARENB));
  Raw.c_cflag := Raw.c_cflag or CS8;

  // VMIN=0 + VTIME=0: read returns 0 if no data is ready (we use
  // poll + fpread to control blocking).  This means we never block
  // inside read itself; PollEvent is the single blocking point.
  Raw.c_cc[VMIN]  := 0;
  Raw.c_cc[VTIME] := 0;

  Result := TCSetAttr(Fd, TCSANOW, Raw) = 0;
end;

function LeaveRawMode(Fd: cint; const Saved: TermIOS): Boolean;
begin
  Result := TCSetAttr(Fd, TCSANOW, Saved) = 0;
end;

function GetTerminalSize(Fd: cint; out Out_: TTermSize): Boolean;
var
  WS: TWinSize;
begin
  Result := False;
  FillChar(WS, SizeOf(WS), 0);
  if fpioctl(Fd, FTUI_TIOCGWINSZ, @WS) <> 0 then Exit;
  if (WS.ws_col = 0) or (WS.ws_row = 0) then Exit;
  Out_.Cols := WS.ws_col;
  Out_.Rows := WS.ws_row;
  Result := True;
end;

function WaitForBytes(Fd: cint; TimeoutMs: Integer): Boolean;
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

end.
