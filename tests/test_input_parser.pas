unit test_input_parser;

{$mode objfpc}{$H+}

interface

procedure RegisterInputParserTests;

implementation

uses
  ftui_testkit,
  ftui_event,
  ftui_input_parser;

// Wrap a literal byte sequence into an input buffer for ParseOne.
// Tests are written as concrete byte arrays; AtEOF defaults to True so
// "what would happen if no more bytes ever arrive" is the dominant
// scenario (matches how test code typically wants to think).
function Parse(const Bytes: array of Byte; AtEOF: Boolean;
  out Ev: TEvent): Integer;
var
  R: TParseResult;
  Tmp: array of Byte;
  Consumed: Integer;
begin
  SetLength(Tmp, Length(Bytes));
  if Length(Bytes) > 0 then
    Move(Bytes[0], Tmp[0], Length(Bytes));
  if Length(Bytes) = 0 then
    R := ParseOne(Tmp, 0, AtEOF, Ev, Consumed)
  else
    R := ParseOne(Tmp[0], Length(Bytes), AtEOF, Ev, Consumed);
  case R of
    prSuccess:  Result := Consumed;
    prNeedMore: Result := -1;
    prInvalid:  Result := -2;
  end;
end;

procedure ExpectChar(const Bytes: array of Byte; ExpectedCh: LongWord;
  ExpectedMods: TKeyModifiers; ExpectedConsumed: Integer; const Ctx: AnsiString);
var
  Ev: TEvent;
  C: Integer;
begin
  C := Parse(Bytes, True, Ev);
  AssertEqInt(ExpectedConsumed, C, Ctx + ' consumed');
  AssertEqInt(Ord(evKey), Ord(Ev.Kind), Ctx + ' kind = key');
  AssertEqInt(Ord(kcChar), Ord(Ev.Key.Code), Ctx + ' code = char');
  AssertEqInt(LongInt(ExpectedCh), LongInt(Ev.Key.Ch), Ctx + ' ch');
  AssertTrue(Ev.Key.Modifiers = ExpectedMods, Ctx + ' modifiers');
end;

procedure ExpectKeyCode(const Bytes: array of Byte; ExpectedCode: TKeyCodeKind;
  ExpectedMods: TKeyModifiers; ExpectedConsumed: Integer; const Ctx: AnsiString);
var
  Ev: TEvent;
  C: Integer;
begin
  C := Parse(Bytes, True, Ev);
  AssertEqInt(ExpectedConsumed, C, Ctx + ' consumed');
  AssertEqInt(Ord(evKey), Ord(Ev.Kind), Ctx + ' kind = key');
  AssertEqInt(Ord(ExpectedCode), Ord(Ev.Key.Code), Ctx + ' code');
  AssertTrue(Ev.Key.Modifiers = ExpectedMods, Ctx + ' modifiers');
end;

procedure ExpectFunctionKey(const Bytes: array of Byte; F: Byte;
  ExpectedConsumed: Integer; const Ctx: AnsiString);
var
  Ev: TEvent;
  C: Integer;
begin
  C := Parse(Bytes, True, Ev);
  AssertEqInt(ExpectedConsumed, C, Ctx + ' consumed');
  AssertEqInt(Ord(kcF), Ord(Ev.Key.Code), Ctx + ' code = F');
  AssertEqInt(F, Ev.Key.F, Ctx + ' f-number');
end;

procedure ExpectMouse(const Bytes: array of Byte; Kind: TMouseEventKind;
  X, Y: Word; ExpectedConsumed: Integer; const Ctx: AnsiString);
var
  Ev: TEvent;
  C: Integer;
begin
  C := Parse(Bytes, True, Ev);
  AssertEqInt(ExpectedConsumed, C, Ctx + ' consumed');
  AssertEqInt(Ord(evMouse), Ord(Ev.Kind), Ctx + ' kind = mouse');
  AssertEqInt(Ord(Kind), Ord(Ev.Mouse.Kind), Ctx + ' mouse kind');
  AssertEqInt(X, Ev.Mouse.X, Ctx + ' mouse x');
  AssertEqInt(Y, Ev.Mouse.Y, Ctx + ' mouse y');
end;

procedure Test_PrintableAscii;
begin
  ExpectChar([Ord('a')], Ord('a'), [], 1, 'a');
  ExpectChar([Ord('Z')], Ord('Z'), [], 1, 'Z');
  ExpectChar([Ord('1')], Ord('1'), [], 1, '1');
  ExpectChar([Ord(' ')], Ord(' '), [], 1, 'space');
  ExpectChar([126],      126,      [], 1, 'tilde');
end;

procedure Test_ControlBytes;
begin
  ExpectKeyCode([13],  kcEnter,     [], 1, 'CR -> Enter');
  ExpectKeyCode([10],  kcEnter,     [], 1, 'LF -> Enter');
  ExpectKeyCode([9],   kcTab,       [], 1, 'TAB');
  ExpectKeyCode([127], kcBackspace, [], 1, 'DEL byte -> backspace');
  ExpectKeyCode([8],   kcBackspace, [], 1, 'BS byte -> backspace');
end;

procedure Test_CtrlLetters;
begin
  // Ctrl-A = 1, Ctrl-X = 24, Ctrl-Z = 26.
  ExpectChar([1],  Ord('a'), [kmCtrl], 1, 'ctrl-a');
  ExpectChar([24], Ord('x'), [kmCtrl], 1, 'ctrl-x');
  ExpectChar([26], Ord('z'), [kmCtrl], 1, 'ctrl-z');
  // Ctrl-C is byte 3.
  ExpectChar([3],  Ord('c'), [kmCtrl], 1, 'ctrl-c');
end;

procedure Test_BareEscWithEOF;
begin
  ExpectKeyCode([27], kcEsc, [], 1, 'bare ESC at EOF');
end;

procedure Test_BareEscNeedsMoreWithoutEOF;
var
  Ev: TEvent;
  Bytes: array[0..0] of Byte;
  R: TParseResult;
  Consumed: Integer;
begin
  Bytes[0] := 27;
  R := ParseOne(Bytes[0], 1, False, Ev, Consumed);
  AssertEqInt(27, Bytes[0], 'sanity: bytes preserved');
  AssertEqInt(Ord(prNeedMore), Ord(R), 'bare ESC without EOF -> NeedMore');
end;

procedure Test_AltCharacter;
begin
  // ESC + 'a' -> Alt-a
  ExpectChar([27, Ord('a')], Ord('a'), [kmAlt], 2, 'alt-a');
  ExpectChar([27, Ord('Z')], Ord('Z'), [kmAlt], 2, 'alt-Z');
end;

procedure Test_AltEnter;
begin
  ExpectKeyCode([27, 13], kcEnter, [kmAlt], 2, 'alt-enter');
end;

procedure Test_DoubleEsc;
begin
  // ESC ESC -> bare ESC + leftover (consumed = 1 only).
  ExpectKeyCode([27, 27], kcEsc, [], 1, 'ESC ESC consumes one ESC');
end;

procedure Test_ArrowKeys;
begin
  ExpectKeyCode([27, Ord('['), Ord('A')], kcUp,    [], 3, 'CSI A = Up');
  ExpectKeyCode([27, Ord('['), Ord('B')], kcDown,  [], 3, 'CSI B = Down');
  ExpectKeyCode([27, Ord('['), Ord('C')], kcRight, [], 3, 'CSI C = Right');
  ExpectKeyCode([27, Ord('['), Ord('D')], kcLeft,  [], 3, 'CSI D = Left');
end;

procedure Test_CsiHomeEnd;
begin
  ExpectKeyCode([27, Ord('['), Ord('H')], kcHome, [], 3, 'CSI H');
  ExpectKeyCode([27, Ord('['), Ord('F')], kcEnd,  [], 3, 'CSI F');
end;

procedure Test_CsiTilde_PgUpDownDelete;
begin
  ExpectKeyCode([27, Ord('['), Ord('5'), Ord('~')], kcPageUp,   [], 4, 'CSI 5~');
  ExpectKeyCode([27, Ord('['), Ord('6'), Ord('~')], kcPageDown, [], 4, 'CSI 6~');
  ExpectKeyCode([27, Ord('['), Ord('3'), Ord('~')], kcDelete,   [], 4, 'CSI 3~');
  ExpectKeyCode([27, Ord('['), Ord('2'), Ord('~')], kcInsert,   [], 4, 'CSI 2~');
  ExpectKeyCode([27, Ord('['), Ord('1'), Ord('~')], kcHome,     [], 4, 'CSI 1~ = Home');
  ExpectKeyCode([27, Ord('['), Ord('4'), Ord('~')], kcEnd,      [], 4, 'CSI 4~ = End');
end;

procedure Test_CsiZ_BackTab;
begin
  ExpectKeyCode([27, Ord('['), Ord('Z')], kcBackTab, [], 3, 'CSI Z = BackTab');
end;

procedure Test_CsiArrowsWithModifiers;
begin
  // CSI 1;2A = Shift-Up, 1;5A = Ctrl-Up, 1;3A = Alt-Up
  ExpectKeyCode([27, Ord('['), Ord('1'), Ord(';'), Ord('2'), Ord('A')],
    kcUp, [kmShift], 6, 'CSI 1;2A');
  ExpectKeyCode([27, Ord('['), Ord('1'), Ord(';'), Ord('5'), Ord('A')],
    kcUp, [kmCtrl], 6, 'CSI 1;5A');
  ExpectKeyCode([27, Ord('['), Ord('1'), Ord(';'), Ord('3'), Ord('A')],
    kcUp, [kmAlt], 6, 'CSI 1;3A');
end;

procedure Test_FunctionKeys;
begin
  // CSI 11~ = F1, CSI 12~ = F2, ..., CSI 15~ = F5
  ExpectFunctionKey([27, Ord('['), Ord('1'), Ord('1'), Ord('~')], 1, 5, 'F1 via CSI 11~');
  ExpectFunctionKey([27, Ord('['), Ord('1'), Ord('5'), Ord('~')], 5, 5, 'F5 via CSI 15~');
  // CSI 17~ = F6, 21~ = F10
  ExpectFunctionKey([27, Ord('['), Ord('1'), Ord('7'), Ord('~')], 6, 5, 'F6 via CSI 17~');
  ExpectFunctionKey([27, Ord('['), Ord('2'), Ord('1'), Ord('~')], 10, 5, 'F10 via CSI 21~');
  // CSI 23~ = F11, 24~ = F12
  ExpectFunctionKey([27, Ord('['), Ord('2'), Ord('3'), Ord('~')], 11, 5, 'F11 via CSI 23~');
  ExpectFunctionKey([27, Ord('['), Ord('2'), Ord('4'), Ord('~')], 12, 5, 'F12 via CSI 24~');
end;

procedure Test_SS3FunctionKeys;
begin
  ExpectFunctionKey([27, Ord('O'), Ord('P')], 1, 3, 'SS3 P = F1');
  ExpectFunctionKey([27, Ord('O'), Ord('Q')], 2, 3, 'SS3 Q = F2');
  ExpectFunctionKey([27, Ord('O'), Ord('R')], 3, 3, 'SS3 R = F3');
  ExpectFunctionKey([27, Ord('O'), Ord('S')], 4, 3, 'SS3 S = F4');
end;

procedure Test_MouseScroll;
begin
  // SGR mouse: ESC [ < <btn> ; <x> ; <y> M
  // btn = 64 -> ScrollUp, btn = 65 -> ScrollDown
  ExpectMouse([27, Ord('['), Ord('<'), Ord('6'), Ord('4'), Ord(';'),
               Ord('1'), Ord('0'), Ord(';'), Ord('5'), Ord('M')],
              mkScrollUp, 9, 4, 11, 'SGR scroll up at (10,5) -> (9,4) 0-based');

  ExpectMouse([27, Ord('['), Ord('<'), Ord('6'), Ord('5'), Ord(';'),
               Ord('1'), Ord(';'), Ord('1'), Ord('M')],
              mkScrollDown, 0, 0, 10, 'SGR scroll down at (1,1) -> (0,0)');
end;

procedure Test_MouseLeftDown;
begin
  // btn=0 with M (press) -> mkDown
  ExpectMouse([27, Ord('['), Ord('<'), Ord('0'), Ord(';'),
               Ord('5'), Ord(';'), Ord('3'), Ord('M')],
              mkDown, 4, 2, 9, 'SGR left down at (5,3) -> (4,2)');
end;

procedure Test_MouseLeftUp;
begin
  // btn=0 with 'm' (release) -> mkUp
  ExpectMouse([27, Ord('['), Ord('<'), Ord('0'), Ord(';'),
               Ord('1'), Ord('0'), Ord(';'), Ord('7'), Ord('m')],
              mkUp, 9, 6, 10, 'SGR left up at (10,7) -> (9,6)');
end;

procedure Test_MouseMoved;
begin
  // btn=35 (32+3) with M -> motion, button bits=3 -> no button -> mkMoved
  ExpectMouse([27, Ord('['), Ord('<'), Ord('3'), Ord('5'), Ord(';'),
               Ord('2'), Ord('0'), Ord(';'), Ord('1'), Ord('5'), Ord('M')],
              mkMoved, 19, 14, 12, 'SGR moved at (20,15) -> (19,14)');
end;

procedure Test_MouseDragLeft;
begin
  // btn=32 (32+0) with M -> motion, button bits=0 -> left drag -> mkDrag
  ExpectMouse([27, Ord('['), Ord('<'), Ord('3'), Ord('2'), Ord(';'),
               Ord('5'), Ord(';'), Ord('5'), Ord('M')],
              mkDrag, 4, 4, 10, 'SGR left drag at (5,5) -> (4,4)');
end;

procedure Test_MouseMiddleDown;
begin
  // btn=1 with M -> middle press
  ExpectMouse([27, Ord('['), Ord('<'), Ord('1'), Ord(';'),
               Ord('3'), Ord(';'), Ord('3'), Ord('M')],
              mkDown, 2, 2, 9, 'SGR middle down at (3,3) -> (2,2)');
end;

procedure Test_MouseRightUp;
begin
  // btn=2 with 'm' -> right release
  ExpectMouse([27, Ord('['), Ord('<'), Ord('2'), Ord(';'),
               Ord('1'), Ord(';'), Ord('1'), Ord('m')],
              mkUp, 0, 0, 9, 'SGR right up at (1,1) -> (0,0)');
end;

procedure Test_PartialCsiNeedsMore;
var
  Ev: TEvent;
  Bytes: array[0..1] of Byte;
  R: TParseResult;
  Consumed: Integer;
begin
  // ESC [ alone is incomplete.
  Bytes[0] := 27; Bytes[1] := Ord('[');
  R := ParseOne(Bytes[0], 2, False, Ev, Consumed);
  AssertEqInt(27, Bytes[0], 'sanity: bytes[0]');
  AssertEqInt(Ord(prNeedMore), Ord(R), 'ESC[ alone -> NeedMore');
end;

procedure Test_InvalidCsiBody;
var
  Ev: TEvent;
  Bytes: array[0..2] of Byte;
  R: TParseResult;
  Consumed: Integer;
begin
  // CSI X (no such pattern) -> Invalid
  Bytes[0] := 27; Bytes[1] := Ord('['); Bytes[2] := Ord('X');
  R := ParseOne(Bytes[0], 3, True, Ev, Consumed);
  AssertEqInt(Ord('X'), Bytes[2], 'sanity: bytes[2]');
  AssertEqInt(Ord(prInvalid), Ord(R), 'CSI X -> Invalid');
end;

procedure Test_AdjacentEventsConsumeOnlyFirst;
var
  Ev: TEvent;
  Bytes: array[0..1] of Byte;
  R: TParseResult;
  Consumed: Integer;
begin
  Bytes[0] := Ord('a');
  Bytes[1] := Ord('b');
  R := ParseOne(Bytes[0], 2, True, Ev, Consumed);
  AssertEqInt(Ord('b'), Bytes[1], 'sanity: bytes[1]');
  AssertEqInt(Ord(prSuccess), Ord(R), 'a then b — first parse succeeds');
  AssertEqInt(1, Consumed, 'consumed = 1');
  AssertEqInt(Ord('a'), LongInt(Ev.Key.Ch), 'first char = a');
end;

procedure RegisterInputParserTests;
begin
  RegisterTest('input / printable ASCII',                @Test_PrintableAscii);
  RegisterTest('input / control bytes (Enter/Tab/BS)',    @Test_ControlBytes);
  RegisterTest('input / Ctrl-letter combinations',        @Test_CtrlLetters);
  RegisterTest('input / bare ESC at EOF',                 @Test_BareEscWithEOF);
  RegisterTest('input / bare ESC w/o EOF -> NeedMore',    @Test_BareEscNeedsMoreWithoutEOF);
  RegisterTest('input / Alt + char',                      @Test_AltCharacter);
  RegisterTest('input / Alt + Enter',                     @Test_AltEnter);
  RegisterTest('input / ESC ESC consumes one ESC',        @Test_DoubleEsc);
  RegisterTest('input / arrow keys',                      @Test_ArrowKeys);
  RegisterTest('input / CSI Home/End',                    @Test_CsiHomeEnd);
  RegisterTest('input / CSI ~ Page/Delete/Insert/Home/End',@Test_CsiTilde_PgUpDownDelete);
  RegisterTest('input / CSI Z = BackTab',                 @Test_CsiZ_BackTab);
  RegisterTest('input / arrows with modifiers',           @Test_CsiArrowsWithModifiers);
  RegisterTest('input / function keys via CSI ~',         @Test_FunctionKeys);
  RegisterTest('input / SS3 F1..F4',                      @Test_SS3FunctionKeys);
  RegisterTest('input / mouse scroll up/down',            @Test_MouseScroll);
  RegisterTest('input / mouse left-down',                 @Test_MouseLeftDown);
  RegisterTest('input / mouse left-up',                   @Test_MouseLeftUp);
  RegisterTest('input / mouse moved (no button)',         @Test_MouseMoved);
  RegisterTest('input / mouse drag left',                 @Test_MouseDragLeft);
  RegisterTest('input / mouse middle-down',               @Test_MouseMiddleDown);
  RegisterTest('input / mouse right-up',                  @Test_MouseRightUp);
  RegisterTest('input / partial CSI -> NeedMore',         @Test_PartialCsiNeedsMore);
  RegisterTest('input / unknown CSI body -> Invalid',     @Test_InvalidCsiBody);
  RegisterTest('input / adjacent events consume only first', @Test_AdjacentEventsConsumeOnlyFirst);
end;

end.
