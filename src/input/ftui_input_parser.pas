unit ftui_input_parser;

// Byte stream -> TEvent.  Pure function over a byte buffer; no IO.
//
// Every call to ParseOne tries to consume the prefix of `Buf` and
// produce one TEvent.  Three outcomes:
//
//   prSuccess : Out_ holds an event, Consumed = bytes consumed
//   prNeedMore: input is a prefix of a longer sequence (e.g. ESC
//               with no follow-up yet) — caller must read more
//               bytes and call again
//   prInvalid : input doesn't match any recognised pattern;
//               caller should drop one byte and try again
//
// Pattern coverage (matches cli888 surface):
//   - Printable ASCII / control bytes -> kcChar, kcEnter, kcTab,
//     kcBackspace, ctrl-letter combinations
//   - ESC alone (with caller-provided "no more bytes" hint) -> kcEsc
//   - ESC <ch>      -> Alt + kcChar(ch) or Alt + kcEnter etc.
//   - CSI A/B/C/D   -> Up/Down/Right/Left arrows
//   - CSI H/F       -> Home/End
//   - CSI 1~..6~    -> Home/Insert/Delete/End/PageUp/PageDown
//   - CSI 11..15~ etc -> F1..F12
//   - CSI Z         -> BackTab (Shift-Tab)
//   - CSI 1;<mods> letter -> arrows / Home / End with modifiers
//   - SS3 P/Q/R/S   -> F1..F4 (legacy)
//   - SGR mouse "ESC[<b;x;yM" / "m" -> mkScrollUp/Down/LeftDown
//
// Out of scope:
//   - Bracketed paste (CSI 200~ / 201~)
//   - Focus events (CSI I / O)
//   - Kitty keyboard protocol CSI u
//   - X10 / X11 mouse encodings (only modern SGR)
//   - UTF-8 multibyte character decoding (M1 ASCII; M2.1 will widen)

{$mode objfpc}{$H+}{$inline on}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_event;

type
  TParseResult = (prSuccess, prNeedMore, prInvalid);

// Parse one event from Buf[0..Len-1].
// AtEOF tells the parser that no more bytes will arrive; this
// changes the bare-ESC handling — without AtEOF a lone ESC is
// prNeedMore (it might be the start of a CSI), with AtEOF it
// resolves to kcEsc.
function ParseOne(const Buf; Len: Integer; AtEOF: Boolean;
  out Out_: TEvent; out Consumed: Integer): TParseResult;

implementation

// Read byte at index I from Buf (treated as PByte).
function ByteAt(const Buf; I: Integer): Byte; inline;
begin
  Result := PByte(@Buf)[I];
end;

// Parse a decimal number starting at Pos within Buf[0..Len-1].
// Returns the parsed value via Value, advances Pos past the digits.
// Returns False if no digit at the position.
function ParseDecimal(const Buf; Len: Integer; var Pos: Integer;
  out Value: Integer): Boolean;
var
  B: Byte;
begin
  Result := False;
  Value := 0;
  while Pos < Len do
  begin
    B := ByteAt(Buf, Pos);
    if (B < Ord('0')) or (B > Ord('9')) then Break;
    Value := Value * 10 + Integer(B - Ord('0'));
    Inc(Pos);
    Result := True;
  end;
end;

// xterm-style modifier byte:
//   1 = none
//   2 = shift
//   3 = alt
//   4 = shift+alt
//   5 = ctrl
//   6 = shift+ctrl
//   7 = alt+ctrl
//   8 = shift+alt+ctrl
function ModsFromByte(M: Integer): TKeyModifiers;
begin
  Result := [];
  if M < 2 then Exit;
  Dec(M);
  if (M and 1) <> 0 then Include(Result, kmShift);
  if (M and 2) <> 0 then Include(Result, kmAlt);
  if (M and 4) <> 0 then Include(Result, kmCtrl);
end;

// Parse a CSI body starting after `ESC [`.  Buf[0..Len-1] is the
// whole input including the leading ESC; Body starts at index 2.
// Returns prSuccess + number of bytes consumed (including ESC[ and
// the final letter), prNeedMore if the body is not yet complete,
// or prInvalid for unrecognised forms.
function ParseCSI(const Buf; Len: Integer;
  out Out_: TEvent; out Consumed: Integer): TParseResult;
var
  Pos: Integer;
  Param1, Param2, Param3, B: Integer;
  HaveP1, HaveP2: Boolean;
  Mods: TKeyModifiers;
  Final: Byte;
  IsRelease: Boolean;
begin
  Out_ := NoneEvent;
  Consumed := 0;
  Pos := 2;     // skip ESC [

  // Detect SGR mouse: ESC [ < ...
  if (Pos < Len) and (ByteAt(Buf, Pos) = Ord('<')) then
  begin
    Inc(Pos);
    if not ParseDecimal(Buf, Len, Pos, Param1) then Exit(prNeedMore);
    if (Pos >= Len) or (ByteAt(Buf, Pos) <> Ord(';')) then Exit(prNeedMore);
    Inc(Pos);
    if not ParseDecimal(Buf, Len, Pos, Param2) then Exit(prNeedMore);
    if (Pos >= Len) or (ByteAt(Buf, Pos) <> Ord(';')) then Exit(prNeedMore);
    Inc(Pos);
    if not ParseDecimal(Buf, Len, Pos, Param3) then Exit(prNeedMore);
    if Pos >= Len then Exit(prNeedMore);
    Final := ByteAt(Buf, Pos);
    if (Final <> Ord('M')) and (Final <> Ord('m')) then Exit(prInvalid);
    Inc(Pos);
    IsRelease := Final = Ord('m');
    Consumed := Pos;
    // Mouse button encoding:
    //   0   = left, 1 = middle, 2 = right
    //   64  = scroll up, 65 = scroll down
    //   bit 4 (16) = ctrl, bit 3 (8) = alt, bit 2 (4) = shift
    Mods := [];
    if (Param1 and 4)  <> 0 then Include(Mods, kmShift);
    if (Param1 and 8)  <> 0 then Include(Mods, kmAlt);
    if (Param1 and 16) <> 0 then Include(Mods, kmCtrl);
    case Param1 and not 28 of           // mask out modifier bits
      64: Out_ := MouseEvent(mkScrollUp,   Word(Param2 - 1), Word(Param3 - 1), Mods);
      65: Out_ := MouseEvent(mkScrollDown, Word(Param2 - 1), Word(Param3 - 1), Mods);
      0:
        if IsRelease then
          Exit(prInvalid)               // we don't model release events
        else
          Out_ := MouseEvent(mkLeftDown, Word(Param2 - 1), Word(Param3 - 1), Mods);
    else
      Exit(prInvalid);
    end;
    Result := prSuccess;
    Exit;
  end;

  // CSI Z = BackTab (Shift-Tab) — special, no parameters.
  if (Pos < Len) and (ByteAt(Buf, Pos) = Ord('Z')) then
  begin
    Out_ := KeyCodeEvent(kcBackTab, []);
    Consumed := Pos + 1;
    Exit(prSuccess);
  end;

  // Parse `Param1[;Param2]` then a final letter.  Param1 defaults
  // to 1 when missing (matches xterm behaviour).
  HaveP1 := ParseDecimal(Buf, Len, Pos, Param1);
  if not HaveP1 then Param1 := 1;

  HaveP2 := False;
  Param2 := 1;
  if (Pos < Len) and (ByteAt(Buf, Pos) = Ord(';')) then
  begin
    Inc(Pos);
    HaveP2 := ParseDecimal(Buf, Len, Pos, Param2);
    if not HaveP2 then Exit(prNeedMore);
  end;

  if Pos >= Len then Exit(prNeedMore);
  Final := ByteAt(Buf, Pos);
  Inc(Pos);
  Consumed := Pos;
  Mods := ModsFromByte(Param2);

  case Final of
    Ord('A'): Out_ := KeyCodeEvent(kcUp,    Mods);
    Ord('B'): Out_ := KeyCodeEvent(kcDown,  Mods);
    Ord('C'): Out_ := KeyCodeEvent(kcRight, Mods);
    Ord('D'): Out_ := KeyCodeEvent(kcLeft,  Mods);
    Ord('H'): Out_ := KeyCodeEvent(kcHome,  Mods);
    Ord('F'): Out_ := KeyCodeEvent(kcEnd,   Mods);
    Ord('~'):
      case Param1 of
        1, 7: Out_ := KeyCodeEvent(kcHome, Mods);
        2:    Out_ := KeyCodeEvent(kcInsert, Mods);
        3:    Out_ := KeyCodeEvent(kcDelete, Mods);
        4, 8: Out_ := KeyCodeEvent(kcEnd, Mods);
        5:    Out_ := KeyCodeEvent(kcPageUp, Mods);
        6:    Out_ := KeyCodeEvent(kcPageDown, Mods);
        11..15:
          begin
            B := Param1 - 10;        // 11..15 -> F1..F5
            Out_ := KeyFunctionEvent(B, Mods);
          end;
        17..21:
          begin
            B := Param1 - 11;        // 17..21 -> F6..F10
            Out_ := KeyFunctionEvent(B, Mods);
          end;
        23, 24:
          begin
            B := Param1 - 12;        // 23,24 -> F11,F12
            Out_ := KeyFunctionEvent(B, Mods);
          end;
      else
        Exit(prInvalid);
      end;
  else
    Exit(prInvalid);
  end;

  Result := prSuccess;
end;

// Parse SS3 sequence: ESC O <letter> -> F1..F4 legacy.
function ParseSS3(const Buf; Len: Integer;
  out Out_: TEvent; out Consumed: Integer): TParseResult;
var
  B: Byte;
begin
  Out_ := NoneEvent;
  Consumed := 0;
  if Len < 3 then Exit(prNeedMore);
  B := ByteAt(Buf, 2);
  case B of
    Ord('P'): Out_ := KeyFunctionEvent(1, []);
    Ord('Q'): Out_ := KeyFunctionEvent(2, []);
    Ord('R'): Out_ := KeyFunctionEvent(3, []);
    Ord('S'): Out_ := KeyFunctionEvent(4, []);
    Ord('H'): Out_ := KeyCodeEvent(kcHome, []);
    Ord('F'): Out_ := KeyCodeEvent(kcEnd, []);
  else
    Exit(prInvalid);
  end;
  Consumed := 3;
  Result := prSuccess;
end;

// Translate a single byte read directly (not part of an escape) into
// an event.  Returns prInvalid if the byte doesn't map to anything
// — caller drops it.
function ParseSingleByte(B: Byte; out Out_: TEvent): TParseResult;
begin
  Out_ := NoneEvent;
  case B of
    9:        Out_ := KeyCodeEvent(kcTab, []);
    10, 13:   Out_ := KeyCodeEvent(kcEnter, []);
    127, 8:   Out_ := KeyCodeEvent(kcBackspace, []);
    32..126:
      Out_ := KeyCharEvent(B, []);
    1..7, 11..12, 14..26, 28..31:
      // Ctrl-A..G/K..L/N..Z/\..^/_  — Ctrl + lowercase letter.
      // Ctrl-A is byte 1, Ctrl-Z is 26.  Ctrl-Space is 0 (NUL) but
      // we don't surface that.
      Out_ := KeyCharEvent(LongWord(B + Ord('a') - 1), [kmCtrl]);
  else
    Exit(prInvalid);
  end;
  Result := prSuccess;
end;

function ParseOne(const Buf; Len: Integer; AtEOF: Boolean;
  out Out_: TEvent; out Consumed: Integer): TParseResult;
var
  B0, B1: Byte;
  R: TParseResult;
begin
  Out_ := NoneEvent;
  Consumed := 0;
  if Len <= 0 then Exit(prNeedMore);

  B0 := ByteAt(Buf, 0);
  if B0 <> 27 then
  begin
    Consumed := 1;
    Exit(ParseSingleByte(B0, Out_));
  end;

  // ESC sequences.
  if Len = 1 then
  begin
    if AtEOF then
    begin
      Out_ := KeyCodeEvent(kcEsc, []);
      Consumed := 1;
      Exit(prSuccess);
    end;
    Exit(prNeedMore);
  end;

  B1 := ByteAt(Buf, 1);
  case B1 of
    Ord('['):
      Exit(ParseCSI(Buf, Len, Out_, Consumed));
    Ord('O'):
      Exit(ParseSS3(Buf, Len, Out_, Consumed));
    27:
      begin
        // ESC ESC -> bare ESC + reparse remainder on next call.
        Out_ := KeyCodeEvent(kcEsc, []);
        Consumed := 1;
        Exit(prSuccess);
      end;
  else
    // ESC <byte> -> Alt-modified version of <byte>.
    R := ParseSingleByte(B1, Out_);
    if R = prSuccess then
    begin
      // Add Alt to the modifier set.
      if Out_.Kind = evKey then
        Include(Out_.Key.Modifiers, kmAlt);
      Consumed := 2;
      Exit(prSuccess);
    end;
    Exit(prInvalid);
  end;
end;

end.
