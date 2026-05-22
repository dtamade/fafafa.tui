unit ftui_platform;

{$mode objfpc}{$H+}{$inline on}

interface

{$IFDEF MSWINDOWS}
uses Windows;
{$ELSE}
uses BaseUnix, termio;
{$ENDIF}

type
  TPlatformFd = {$IFDEF MSWINDOWS}THandle{$ELSE}cint{$ENDIF};

  TTermSize = record
    Cols, Rows: Word;
  end;

  {$IFDEF MSWINDOWS}
  TPlatformTermState = record
    InMode, OutMode: DWORD;
  end;
  {$ELSE}
  TPlatformTermState = record
    Saved: TermIOS;
  end;
  {$ENDIF}

const
  PLATFORM_STDIN:  TPlatformFd = 0;
  PLATFORM_STDOUT: TPlatformFd = 1;

function PlatformTickMs: QWord;
function PlatformIsTerminal(Fd: TPlatformFd): Boolean;
function PlatformGetTermSize(Fd: TPlatformFd; out Sz: TTermSize): Boolean;
function PlatformEnterRaw(Fd: TPlatformFd; out State: TPlatformTermState): Boolean;
function PlatformLeaveRaw(Fd: TPlatformFd; const State: TPlatformTermState): Boolean;
function PlatformRead(Fd: TPlatformFd; Buf: PByte; Count: Integer): Integer;
function PlatformWrite(Fd: TPlatformFd; Buf: PByte; Count: Integer): Boolean;
function PlatformWaitReadable(Fd: TPlatformFd; TimeoutMs: Integer): Boolean;
procedure PlatformHookResize;
procedure PlatformUnhookResize;
procedure PlatformHookTerminate;
procedure PlatformUnhookTerminate;
function PlatformConsumeResize: Boolean;
function PlatformConsumeTerminate: Boolean;

implementation

{$IFDEF MSWINDOWS}
  {$I ftui_platform_windows.inc}
{$ELSE}
  {$I ftui_platform_unix.inc}
{$ENDIF}

end.
