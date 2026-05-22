unit ftui_termios;

{$mode objfpc}{$H+}{$inline on}

interface

uses
  ftui_platform;

type
  TTermSize = ftui_platform.TTermSize;

function IsATerminal(Fd: TPlatformFd): Boolean; inline;
function EnterRawMode(Fd: TPlatformFd; out Saved: TPlatformTermState): Boolean; inline;
function LeaveRawMode(Fd: TPlatformFd; const Saved: TPlatformTermState): Boolean; inline;
function GetTerminalSize(Fd: TPlatformFd; out Out_: TTermSize): Boolean; inline;
function WaitForBytes(Fd: TPlatformFd; TimeoutMs: Integer): Boolean; inline;

implementation

function IsATerminal(Fd: TPlatformFd): Boolean;
begin
  Result := PlatformIsTerminal(Fd);
end;

function EnterRawMode(Fd: TPlatformFd; out Saved: TPlatformTermState): Boolean;
begin
  Result := PlatformEnterRaw(Fd, Saved);
end;

function LeaveRawMode(Fd: TPlatformFd; const Saved: TPlatformTermState): Boolean;
begin
  Result := PlatformLeaveRaw(Fd, Saved);
end;

function GetTerminalSize(Fd: TPlatformFd; out Out_: TTermSize): Boolean;
begin
  Result := PlatformGetTermSize(Fd, Out_);
end;

function WaitForBytes(Fd: TPlatformFd; TimeoutMs: Integer): Boolean;
begin
  Result := PlatformWaitReadable(Fd, TimeoutMs);
end;

end.
