unit ftui_bytes;

// Append-only byte buffer + integer-to-ASCII writer.
//
// This is the workhorse on the rendering hot path: ANSI sequences for
// an entire frame are accreted into a single `array of Byte`, then
// flushed to the backend file descriptor in one syscall.  No
// IntToStr, no Format, no s := s + ... — every helper writes raw bytes.
//
// Capacity grows by doubling so amortised append is O(1).  The buffer
// owns its allocation; consumers do not free the bytes themselves.
// `Reset` keeps capacity (Length = 0; SetLength does not shrink).
//
// Pascal note: `array of Byte` is a managed dynamic array; FPC's
// SetLength does an in-place realloc when capacity grows past the
// current allocation, with copy semantics identical to a hand-rolled
// growable buffer.  That's good enough — we don't need a custom
// allocator here.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

type
  TByteBuilder = record
  private
    FData: array of Byte;
    FLen: Integer;
    procedure EnsureCapacity(MinCap: Integer);
  public
    procedure Reset; inline;
    function Length_: Integer; inline;
    function Capacity: Integer; inline;
    function Bytes: PByte; inline;        // points at FData[0]; only valid until next Append

    procedure AppendByte(B: Byte); inline;
    procedure AppendBytes(const Src; N: Integer);
    procedure AppendChar(C: AnsiChar); inline;
    procedure AppendString(const S: AnsiString); inline;
    procedure AppendUInt(N: LongWord);     // itoa, base 10, no leading zeros

    // Write the full payload to a Unix file descriptor, retrying on EINTR
    // and short writes.  Returns True iff every byte was written.
    function FlushTo(Fd: LongInt): Boolean;
  end;

// Returns a freshly zeroed TByteBuilder.  Use this at every site where
// a TByteBuilder is declared on the stack — it both makes the intent
// explicit and silences FPC's "managed local" uninitialised warning,
// which mis-fires on bare `var B: TByteBuilder` even though the RTL
// already nulls the dynamic-array field on entry.
function NewByteBuilder: TByteBuilder; inline;

implementation

uses
  BaseUnix;

{ TByteBuilder }

function NewByteBuilder: TByteBuilder;
begin
  Result.FLen := 0;
  Result.FData := nil;
end;

procedure TByteBuilder.EnsureCapacity(MinCap: Integer);
var
  Cap, NewCap: Integer;
begin
  Cap := System.Length(FData);
  if Cap >= MinCap then Exit;

  // Doubling growth — start at 64 to amortise small frames.
  if Cap = 0 then
    NewCap := 64
  else
    NewCap := Cap;
  while NewCap < MinCap do
    NewCap := NewCap * 2;
  SetLength(FData, NewCap);
end;

procedure TByteBuilder.Reset;
begin
  FLen := 0;
  // Capacity is preserved on purpose — frames are usually similar in
  // size, and reusing the allocation avoids realloc churn.
end;

function TByteBuilder.Length_: Integer;
begin
  Result := FLen;
end;

function TByteBuilder.Capacity: Integer;
begin
  Result := System.Length(FData);
end;

function TByteBuilder.Bytes: PByte;
begin
  if System.Length(FData) = 0 then
    Result := nil
  else
    Result := @FData[0];
end;

procedure TByteBuilder.AppendByte(B: Byte);
begin
  if FLen >= System.Length(FData) then
    EnsureCapacity(FLen + 1);
  FData[FLen] := B;
  Inc(FLen);
end;

procedure TByteBuilder.AppendBytes(const Src; N: Integer);
begin
  if N <= 0 then Exit;
  EnsureCapacity(FLen + N);
  Move(Src, FData[FLen], N);
  Inc(FLen, N);
end;

procedure TByteBuilder.AppendChar(C: AnsiChar);
begin
  AppendByte(Byte(C));
end;

procedure TByteBuilder.AppendString(const S: AnsiString);
var
  L: Integer;
  P: PByte;
begin
  L := System.Length(S);
  if L = 0 then Exit;
  EnsureCapacity(FLen + L);
  // Use Pointer(S) to get the start-of-data pointer; on FPC AnsiString
  // this is the first character byte.  Avoids the inlined-AppendString
  // edge case where `S[1]` did not survive the inlining.
  P := PByte(Pointer(S));
  Move(P^, FData[FLen], L);
  Inc(FLen, L);
end;

procedure TByteBuilder.AppendUInt(N: LongWord);
var
  Tmp: array[0..9] of Byte;     // LongWord max = 4294967295 = 10 digits
  Cnt: Integer;
  I: Integer;
begin
  if N = 0 then
  begin
    AppendByte(Ord('0'));
    Exit;
  end;

  FillChar(Tmp, SizeOf(Tmp), 0);
  Cnt := 0;
  while N > 0 do
  begin
    Tmp[Cnt] := Ord('0') + Byte(N mod 10);
    N := N div 10;
    Inc(Cnt);
  end;

  EnsureCapacity(FLen + Cnt);
  for I := Cnt - 1 downto 0 do
  begin
    FData[FLen] := Tmp[I];
    Inc(FLen);
  end;
end;

function TByteBuilder.FlushTo(Fd: LongInt): Boolean;
var
  Sent, Total, Wrote: Integer;
  P: PByte;
begin
  if FLen = 0 then Exit(True);
  Total := FLen;
  Sent := 0;
  P := @FData[0];
  while Sent < Total do
  begin
    Wrote := fpWrite(Fd, (P + Sent)^, Total - Sent);
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

end.
