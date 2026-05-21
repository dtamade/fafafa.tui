unit test_clipboard;

{$mode objfpc}{$H+}

interface

procedure RegisterClipboardTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_clipboard;

procedure Test_DetectReturnsValidMethod;
var
  Cb: TClipboard;
begin
  Cb := TClipboard.Detect;
  AssertTrue((Cb.Method = cmOSC52) or (Cb.Method = cmExternal) or
             (Cb.Method = cmNone),
             'Detect returns a valid TClipboardMethod');
end;

procedure Test_OSC52PrefixSuffix;
var
  Cb: TClipboard;
  Seq: AnsiString;
begin
  Cb.Method := cmOSC52;
  Seq := Cb.GetOSC52Copy('test');
  // Must start with ESC ] 52 ; c ;
  AssertTrue(Pos(#27']52;c;', Seq) = 1, 'OSC52 starts with ESC]52;c;');
  // Must end with ESC backslash
  AssertTrue((Length(Seq) >= 2) and
             (Seq[Length(Seq) - 1] = #27) and (Seq[Length(Seq)] = '\'),
             'OSC52 ends with ESC\');
end;

procedure Test_OSC52Base64Hello;
var
  Cb: TClipboard;
  Seq: AnsiString;
begin
  Cb.Method := cmOSC52;
  Seq := Cb.GetOSC52Copy('hello');
  // 'hello' base64 = 'aGVsbG8='
  // Full sequence: ESC]52;c;aGVsbG8=ESC\
  AssertEqStr(#27']52;c;aGVsbG8=' + #27'\', Seq, 'OSC52 hello encoding');
end;

procedure Test_OSC52EmptyString;
var
  Cb: TClipboard;
  Seq: AnsiString;
begin
  Cb.Method := cmOSC52;
  Seq := Cb.GetOSC52Copy('');
  // Empty base64 is empty string
  AssertEqStr(#27']52;c;' + #27'\', Seq, 'OSC52 empty string');
end;

procedure Test_OSC52LongString;
var
  Cb: TClipboard;
  Seq, LongStr: AnsiString;
  I: Integer;
begin
  Cb.Method := cmOSC52;
  // Build a 1000-char string
  SetLength(LongStr, 1000);
  for I := 1 to 1000 do
    LongStr[I] := Chr(65 + (I mod 26));
  // Should not crash
  Seq := Cb.GetOSC52Copy(LongStr);
  AssertTrue(Length(Seq) > 0, 'long string produces non-empty sequence');
  AssertTrue(Pos(#27']52;c;', Seq) = 1, 'long string has correct prefix');
  AssertTrue((Seq[Length(Seq) - 1] = #27) and (Seq[Length(Seq)] = '\'),
             'long string has correct suffix');
end;

procedure Test_OSC52Base64Padding;
var
  Cb: TClipboard;
  Seq: AnsiString;
begin
  Cb.Method := cmOSC52;
  // 'a' base64 = 'YQ=='
  Seq := Cb.GetOSC52Copy('a');
  AssertEqStr(#27']52;c;YQ==' + #27'\', Seq, 'OSC52 single char (2 pad)');
  // 'ab' base64 = 'YWI='
  Seq := Cb.GetOSC52Copy('ab');
  AssertEqStr(#27']52;c;YWI=' + #27'\', Seq, 'OSC52 two chars (1 pad)');
  // 'abc' base64 = 'YWJj'
  Seq := Cb.GetOSC52Copy('abc');
  AssertEqStr(#27']52;c;YWJj' + #27'\', Seq, 'OSC52 three chars (no pad)');
end;

procedure RegisterClipboardTests;
begin
  RegisterTest('clipboard / detect returns valid method', @Test_DetectReturnsValidMethod);
  RegisterTest('clipboard / osc52 prefix and suffix',    @Test_OSC52PrefixSuffix);
  RegisterTest('clipboard / osc52 base64 hello',         @Test_OSC52Base64Hello);
  RegisterTest('clipboard / osc52 empty string',         @Test_OSC52EmptyString);
  RegisterTest('clipboard / osc52 long string',          @Test_OSC52LongString);
  RegisterTest('clipboard / osc52 base64 padding',       @Test_OSC52Base64Padding);
end;

end.
