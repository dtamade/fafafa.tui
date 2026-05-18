unit test_ansi;

{$mode objfpc}{$H+}

interface

procedure RegisterAnsiTests;

implementation

uses
  ftui_testkit,
  ftui_color,
  ftui_modifier,
  ftui_bytes,
  ftui_ansi;

function BuilderAsString(var B: TByteBuilder): AnsiString;
begin
  if B.Length_ = 0 then Exit('');
  SetLength(Result, B.Length_);
  Move(B.Bytes^, Result[1], B.Length_);
end;

procedure Test_HideShowCursor;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder; AnsiHideCursor(B);
  AssertEqStr(#27'[?25l', BuilderAsString(B), 'hide cursor');

  B := NewByteBuilder; AnsiShowCursor(B);
  AssertEqStr(#27'[?25h', BuilderAsString(B), 'show cursor');
end;

procedure Test_MoveTo_OneBasedOnWire;
var
  B: TByteBuilder;
begin
  // Input is 0-based; ANSI expects 1-based row;col -> CSI 1;1H for (0,0).
  B := NewByteBuilder; AnsiMoveTo(B, 0, 0);
  AssertEqStr(#27'[1;1H', BuilderAsString(B), '(0,0) -> CSI 1;1H');

  B := NewByteBuilder; AnsiMoveTo(B, 19, 4);
  AssertEqStr(#27'[5;20H', BuilderAsString(B), '(19,4) -> CSI 5;20H');
end;

procedure Test_AltScreenAndClear;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder; AnsiEnterAltScreen(B);
  AssertEqStr(#27'[?1049h', BuilderAsString(B), 'enter alt screen');

  B := NewByteBuilder; AnsiLeaveAltScreen(B);
  AssertEqStr(#27'[?1049l', BuilderAsString(B), 'leave alt screen');

  B := NewByteBuilder; AnsiClearScreen(B);
  AssertEqStr(#27'[2J', BuilderAsString(B), 'clear screen');
end;

procedure Test_SgrReset;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder; AnsiSgrReset(B);
  AssertEqStr(#27'[0m', BuilderAsString(B), 'SGR 0');
end;

procedure Test_SgrFg_Indexed;
var
  B: TByteBuilder;
begin
  // Named 0..7 map to SGR 30..37.
  B := NewByteBuilder; AnsiSgrFg(B, IndexedColor(0));
  AssertEqStr(#27'[30m', BuilderAsString(B), 'idx 0 -> 30');
  B := NewByteBuilder; AnsiSgrFg(B, IndexedColor(7));
  AssertEqStr(#27'[37m', BuilderAsString(B), 'idx 7 -> 37');

  // Named 8..15 map to bright 90..97.
  B := NewByteBuilder; AnsiSgrFg(B, IndexedColor(8));
  AssertEqStr(#27'[90m', BuilderAsString(B), 'idx 8 -> 90');
  B := NewByteBuilder; AnsiSgrFg(B, IndexedColor(15));
  AssertEqStr(#27'[97m', BuilderAsString(B), 'idx 15 -> 97');

  // 16+ uses xterm 256-color escape: SGR 38;5;N.
  B := NewByteBuilder; AnsiSgrFg(B, IndexedColor(16));
  AssertEqStr(#27'[38;5;16m', BuilderAsString(B), 'idx 16 -> 38;5;16');
  B := NewByteBuilder; AnsiSgrFg(B, IndexedColor(255));
  AssertEqStr(#27'[38;5;255m', BuilderAsString(B), 'idx 255 -> 38;5;255');
end;

procedure Test_SgrFg_RgbAndReset;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder; AnsiSgrFg(B, RgbColor(10, 20, 30));
  AssertEqStr(#27'[38;2;10;20;30m', BuilderAsString(B), 'rgb');

  B := NewByteBuilder; AnsiSgrFg(B, ResetColor);
  AssertEqStr(#27'[39m', BuilderAsString(B), 'fg reset = SGR 39');

  B := NewByteBuilder; AnsiSgrFg(B, UnsetColor);
  AssertEqInt(0, B.Length_, 'unset is no-op');
end;

procedure Test_SgrBg_Mirror;
var
  B: TByteBuilder;
begin
  B := NewByteBuilder; AnsiSgrBg(B, IndexedColor(0));
  AssertEqStr(#27'[40m', BuilderAsString(B), 'bg idx 0 -> 40');
  B := NewByteBuilder; AnsiSgrBg(B, IndexedColor(8));
  AssertEqStr(#27'[100m', BuilderAsString(B), 'bg idx 8 -> 100');
  B := NewByteBuilder; AnsiSgrBg(B, RgbColor(255, 0, 0));
  AssertEqStr(#27'[48;2;255;0;0m', BuilderAsString(B), 'bg rgb');
  B := NewByteBuilder; AnsiSgrBg(B, ResetColor);
  AssertEqStr(#27'[49m', BuilderAsString(B), 'bg reset = SGR 49');
end;

procedure Test_SgrModifierAdd_AllBits;
var
  B: TByteBuilder;
  M: TModifier;
  Bit: TModifierBit;
  Expected: array[TModifierBit] of AnsiString;
begin
  Expected[mbBold]        := #27'[1m';
  Expected[mbDim]         := #27'[2m';
  Expected[mbItalic]      := #27'[3m';
  Expected[mbUnderlined]  := #27'[4m';
  Expected[mbSlowBlink]   := #27'[5m';
  Expected[mbRapidBlink]  := #27'[6m';
  Expected[mbReversed]    := #27'[7m';
  Expected[mbHidden]      := #27'[8m';
  Expected[mbCrossedOut]  := #27'[9m';

  for Bit := Low(TModifierBit) to High(TModifierBit) do
  begin
    B := NewByteBuilder;
    M := [Bit];
    AnsiSgrModifierAdd(B, M);
    AssertEqStr(Expected[Bit], BuilderAsString(B), 'set ' + Expected[Bit]);
  end;
end;

procedure Test_SgrModifierClear_SharedCodes;
var
  B: TByteBuilder;
begin
  // Bold and dim share clear code 22.
  B := NewByteBuilder; AnsiSgrModifierClear(B, [mbBold]);
  AssertEqStr(#27'[22m', BuilderAsString(B), 'clear bold = 22');
  B := NewByteBuilder; AnsiSgrModifierClear(B, [mbDim]);
  AssertEqStr(#27'[22m', BuilderAsString(B), 'clear dim = 22');

  // Both blinks share 25.
  B := NewByteBuilder; AnsiSgrModifierClear(B, [mbSlowBlink]);
  AssertEqStr(#27'[25m', BuilderAsString(B), 'clear slow blink = 25');
  B := NewByteBuilder; AnsiSgrModifierClear(B, [mbRapidBlink]);
  AssertEqStr(#27'[25m', BuilderAsString(B), 'clear rapid blink = 25');

  // Each unique code.
  B := NewByteBuilder; AnsiSgrModifierClear(B, [mbItalic]);
  AssertEqStr(#27'[23m', BuilderAsString(B), 'clear italic = 23');
  B := NewByteBuilder; AnsiSgrModifierClear(B, [mbCrossedOut]);
  AssertEqStr(#27'[29m', BuilderAsString(B), 'clear crossed out = 29');
end;

procedure RegisterAnsiTests;
begin
  RegisterTest('ansi / hide+show cursor',           @Test_HideShowCursor);
  RegisterTest('ansi / MoveTo is 1-based on wire',  @Test_MoveTo_OneBasedOnWire);
  RegisterTest('ansi / alt screen + clear',         @Test_AltScreenAndClear);
  RegisterTest('ansi / SGR reset',                  @Test_SgrReset);
  RegisterTest('ansi / SGR fg indexed (named/256)', @Test_SgrFg_Indexed);
  RegisterTest('ansi / SGR fg rgb + reset + unset', @Test_SgrFg_RgbAndReset);
  RegisterTest('ansi / SGR bg mirrors fg shape',    @Test_SgrBg_Mirror);
  RegisterTest('ansi / SGR modifier add all bits',  @Test_SgrModifierAdd_AllBits);
  RegisterTest('ansi / SGR modifier clear codes',   @Test_SgrModifierClear_SharedCodes);
end;

end.
