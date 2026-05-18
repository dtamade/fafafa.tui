unit test_bytes;

{$mode objfpc}{$H+}

interface

procedure RegisterBytesTests;

implementation

uses
  ftui_testkit,
  ftui_bytes;

// Read back the builder as a byte-level AnsiString — only used inside
// tests, so the one-shot SetLength + Move is fine and matches the
// no-string-concat policy.
function BuilderAsString(var B: TByteBuilder): AnsiString;
begin
  if B.Length_ = 0 then Exit('');
  SetLength(Result, B.Length_);
  Move(B.Bytes^, Result[1], B.Length_);
end;

procedure Test_EmptyOnConstruction;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder;
  AssertEqInt(0, B.Length_, 'fresh length');
  AssertTrue(B.Bytes = nil, 'fresh bytes ptr is nil');
end;

procedure Test_AppendByteSequence;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder;
  B.AppendByte(Ord('a'));
  B.AppendByte(Ord('b'));
  B.AppendByte(Ord('c'));
  AssertEqInt(3, B.Length_, 'len 3');
  AssertEqStr('abc', BuilderAsString(B), 'abc');
end;

procedure Test_AppendBytesAndChar;
var
  B: TByteBuilder;
  Src: array[0..2] of Byte;
begin
  Src[0] := Ord('x');
  Src[1] := Ord('y');
  Src[2] := Ord('z');
  B := NewByteBuilder;
  B.AppendChar('-');
  B.AppendBytes(Src, 3);
  // Touch Src after the untyped-param call so FPC's dataflow sees it.
  AssertEqInt(Ord('z'), Src[2], 'src last byte unchanged');
  B.AppendChar('!');
  AssertEqStr('-xyz!', BuilderAsString(B), '-xyz!');
end;

procedure Test_AppendString;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder;
  B.AppendString('hello, world');
  AssertEqStr('hello, world', BuilderAsString(B), 'hello world');
end;

procedure Test_AppendUIntCornerCases;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder; B.AppendUInt(0);
  AssertEqStr('0', BuilderAsString(B), '0');

  B := NewByteBuilder; B.AppendUInt(7);
  AssertEqStr('7', BuilderAsString(B), '7');

  B := NewByteBuilder; B.AppendUInt(1234);
  AssertEqStr('1234', BuilderAsString(B), '1234');

  B := NewByteBuilder; B.AppendUInt(LongWord(High(LongWord)));
  AssertEqStr('4294967295', BuilderAsString(B), 'longword max');

  B := NewByteBuilder; B.AppendUInt(9);   AssertEqStr('9',  BuilderAsString(B), '9');
  B := NewByteBuilder; B.AppendUInt(10);  AssertEqStr('10', BuilderAsString(B), '10');
  B := NewByteBuilder; B.AppendUInt(99);  AssertEqStr('99', BuilderAsString(B), '99');
  B := NewByteBuilder; B.AppendUInt(100); AssertEqStr('100',BuilderAsString(B), '100');
end;

procedure Test_CapacityGrowsByDoubling;
var
  B: TByteBuilder;
  I, BeforeCap: Integer;
begin
  B := NewByteBuilder;
  AssertEqInt(0, B.Capacity, 'cap starts 0');
  B.AppendByte(1);
  AssertEqInt(64, B.Capacity, 'first append seeds cap=64');

  for I := 1 to 63 do B.AppendByte(2);
  AssertEqInt(64, B.Capacity, 'cap unchanged through 64 bytes');

  BeforeCap := B.Capacity;
  B.AppendByte(3);
  AssertEqInt(128, B.Capacity, 'doubled to 128');
  AssertTrue(B.Capacity = BeforeCap * 2, 'capacity exactly doubled');
end;

procedure Test_ResetPreservesCapacity;
var
  B: TByteBuilder;
  I: Integer;
begin
  B := NewByteBuilder;
  for I := 0 to 99 do B.AppendByte(Byte(I));
  AssertTrue(B.Capacity >= 100, 'cap >= 100 after fill');
  B.Reset;
  AssertEqInt(0, B.Length_, 'length 0 after reset');
  AssertTrue(B.Capacity >= 100, 'capacity still >= 100 after reset');
end;

procedure Test_BinaryBytesAreNotInterpreted;
var
  B: TByteBuilder;
  Src: array[0..2] of Byte;
begin
  Src[0] := 0;          // NUL
  Src[1] := 27;         // ESC
  Src[2] := 255;
  B := NewByteBuilder;
  B.AppendBytes(Src, 3);
  AssertEqInt(255, Src[2], 'src kept');
  AssertEqInt(3, B.Length_, 'len 3');
  AssertEqInt(0,   PByte(B.Bytes)[0], 'byte 0');
  AssertEqInt(27,  PByte(B.Bytes)[1], 'byte 1');
  AssertEqInt(255, PByte(B.Bytes)[2], 'byte 2');
end;

procedure RegisterBytesTests;
begin
  RegisterTest('bytes / empty on construction',     @Test_EmptyOnConstruction);
  RegisterTest('bytes / AppendByte sequence',       @Test_AppendByteSequence);
  RegisterTest('bytes / AppendBytes and AppendChar',@Test_AppendBytesAndChar);
  RegisterTest('bytes / AppendString',              @Test_AppendString);
  RegisterTest('bytes / AppendUInt corner cases',   @Test_AppendUIntCornerCases);
  RegisterTest('bytes / capacity doubling',         @Test_CapacityGrowsByDoubling);
  RegisterTest('bytes / Reset preserves capacity',  @Test_ResetPreservesCapacity);
  RegisterTest('bytes / binary bytes are kept raw', @Test_BinaryBytesAreNotInterpreted);
end;

end.
