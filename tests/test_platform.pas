unit test_platform;

{$mode objfpc}{$H+}

interface

procedure RegisterPlatformTests;

implementation

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  ftui_testkit,
  ftui_platform;

procedure Test_TickMsMonotonic;
var
  T1, T2: QWord;
begin
  T1 := PlatformTickMs;
  T2 := PlatformTickMs;
  AssertTrue(T2 >= T1, 'tick is monotonic');
end;

procedure Test_TickMsNonZero;
begin
  AssertTrue(PlatformTickMs > 0, 'tick is non-zero');
end;

{$IFDEF UNIX}
procedure Test_ReadWritePipe;
var
  Fds: array[0..1] of cint;
  WBuf: array[0..3] of Byte;
  RBuf: array[0..15] of Byte;
  N: Integer;
begin
  AssertTrue(fpPipe(Fds) = 0, 'pipe created');
  WBuf[0] := 72; WBuf[1] := 101; WBuf[2] := 108; WBuf[3] := 108;
  AssertTrue(PlatformWrite(Fds[1], @WBuf[0], 4), 'write 4 bytes');
  FillChar(RBuf, SizeOf(RBuf), 0);
  N := PlatformRead(Fds[0], @RBuf[0], 16);
  AssertEqInt(4, N, 'read 4 bytes');
  AssertEqInt(72, RBuf[0], 'byte H');
  AssertEqInt(101, RBuf[1], 'byte e');
  fpClose(Fds[0]);
  fpClose(Fds[1]);
end;

procedure Test_WaitReadableTimeout;
var
  Fds: array[0..1] of cint;
begin
  AssertTrue(fpPipe(Fds) = 0, 'pipe created');
  AssertFalse(PlatformWaitReadable(Fds[0], 1), 'empty pipe times out');
  fpClose(Fds[0]);
  fpClose(Fds[1]);
end;

procedure Test_WaitReadableReady;
var
  Fds: array[0..1] of cint;
  B: Byte;
begin
  AssertTrue(fpPipe(Fds) = 0, 'pipe created');
  B := 42;
  fpWrite(Fds[1], B, 1);
  AssertTrue(PlatformWaitReadable(Fds[0], 100), 'pipe with data is ready');
  fpClose(Fds[0]);
  fpClose(Fds[1]);
end;

procedure Test_IsTerminalOnPipe;
var
  Fds: array[0..1] of cint;
begin
  AssertTrue(fpPipe(Fds) = 0, 'pipe created');
  AssertFalse(PlatformIsTerminal(Fds[0]), 'pipe is not a terminal');
  fpClose(Fds[0]);
  fpClose(Fds[1]);
end;
{$ENDIF}

procedure Test_WriteInvalidFd;
var
  Buf: array[0..3] of Byte;
begin
  Buf[0] := 65;
  AssertFalse(PlatformWrite(TPlatformFd(-1), @Buf[0], 1), 'write to -1 fails');
end;

procedure Test_ConsumeResizeInitialFalse;
begin
  AssertFalse(PlatformConsumeResize, 'no pending resize initially');
end;

procedure RegisterPlatformTests;
begin
  RegisterTest('platform / tick monotonic',       @Test_TickMsMonotonic);
  RegisterTest('platform / tick non-zero',        @Test_TickMsNonZero);
  {$IFDEF UNIX}
  RegisterTest('platform / read write pipe',      @Test_ReadWritePipe);
  RegisterTest('platform / wait readable timeout',@Test_WaitReadableTimeout);
  RegisterTest('platform / wait readable ready',  @Test_WaitReadableReady);
  RegisterTest('platform / is terminal on pipe',  @Test_IsTerminalOnPipe);
  {$ENDIF}
  RegisterTest('platform / write invalid fd',     @Test_WriteInvalidFd);
  RegisterTest('platform / consume resize init',  @Test_ConsumeResizeInitialFalse);
end;

end.
