unit ftui_ansi;

// ANSI escape-sequence emitters that write directly into a TByteBuilder.
//
// Every helper here translates a ratatui-shaped concept into the bytes
// a real terminal expects, taking the destination buffer by `var` so
// the bytes land in the per-frame builder without any intermediate
// AnsiString.  The emitters are deliberately granular: backends pick
// the ones they need and combine them.
//
// Reference: ECMA-48 / ANSI X3.64 + xterm CSI extensions for 256-color
// (`\x1b[38;5;N`) and truecolor (`\x1b[38;2;R;G;B`) SGR.

{$mode objfpc}{$H+}{$inline on}

interface

uses
  ftui_color,
  ftui_modifier,
  ftui_bytes;

// Cursor + screen primitives.  X/Y are 1-based for the wire (ratatui's
// 0-based positions get +1 inside MoveTo).
procedure AnsiHideCursor      (var B: TByteBuilder); inline;
procedure AnsiShowCursor      (var B: TByteBuilder); inline;
procedure AnsiMoveTo          (var B: TByteBuilder; X, Y: Word); // 0-based in
procedure AnsiClearScreen     (var B: TByteBuilder); inline;
procedure AnsiEnterAltScreen  (var B: TByteBuilder); inline;
procedure AnsiLeaveAltScreen  (var B: TByteBuilder); inline;
procedure AnsiEnableMouseTracking(var B: TByteBuilder);
procedure AnsiDisableMouseTracking(var B: TByteBuilder);

// Style emitters.  Each one writes a fully-formed SGR sequence and
// resets nothing; backends are expected to call AnsiSgrReset between
// runs that change incompatible attributes.
procedure AnsiSgrReset        (var B: TByteBuilder); inline;
procedure AnsiSgrFg           (var B: TByteBuilder; const C: TColor);
procedure AnsiSgrBg           (var B: TByteBuilder; const C: TColor);
procedure AnsiSgrModifierAdd  (var B: TByteBuilder; M: TModifier);
procedure AnsiSgrModifierClear(var B: TByteBuilder; M: TModifier);

implementation

{ Cursor + screen }

procedure AnsiHideCursor(var B: TByteBuilder);
begin
  // CSI ? 25 l
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?')); B.AppendByte(Ord('2')); B.AppendByte(Ord('5'));
  B.AppendByte(Ord('l'));
end;

procedure AnsiShowCursor(var B: TByteBuilder);
begin
  // CSI ? 25 h
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?')); B.AppendByte(Ord('2')); B.AppendByte(Ord('5'));
  B.AppendByte(Ord('h'));
end;

procedure AnsiMoveTo(var B: TByteBuilder; X, Y: Word);
begin
  // CSI <row> ; <col> H — note that wire is 1-based.
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendUInt(LongWord(Y) + 1);
  B.AppendByte(Ord(';'));
  B.AppendUInt(LongWord(X) + 1);
  B.AppendByte(Ord('H'));
end;

procedure AnsiClearScreen(var B: TByteBuilder);
begin
  // CSI 2 J
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('2')); B.AppendByte(Ord('J'));
end;

procedure AnsiEnterAltScreen(var B: TByteBuilder);
begin
  // CSI ? 1049 h
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?'));
  B.AppendByte(Ord('1')); B.AppendByte(Ord('0')); B.AppendByte(Ord('4')); B.AppendByte(Ord('9'));
  B.AppendByte(Ord('h'));
end;

procedure AnsiLeaveAltScreen(var B: TByteBuilder);
begin
  // CSI ? 1049 l
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?'));
  B.AppendByte(Ord('1')); B.AppendByte(Ord('0')); B.AppendByte(Ord('4')); B.AppendByte(Ord('9'));
  B.AppendByte(Ord('l'));
end;

procedure AnsiEnableMouseTracking(var B: TByteBuilder);
begin
  // CSI ?1003h = any-event tracking (reports move even without button)
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?')); B.AppendByte(Ord('1')); B.AppendByte(Ord('0')); B.AppendByte(Ord('0')); B.AppendByte(Ord('3'));
  B.AppendByte(Ord('h'));
  // CSI ?1006h = SGR encoding (supports coordinates > 223)
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?')); B.AppendByte(Ord('1')); B.AppendByte(Ord('0')); B.AppendByte(Ord('0')); B.AppendByte(Ord('6'));
  B.AppendByte(Ord('h'));
end;

procedure AnsiDisableMouseTracking(var B: TByteBuilder);
begin
  // CSI ?1003l + CSI ?1006l
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?')); B.AppendByte(Ord('1')); B.AppendByte(Ord('0')); B.AppendByte(Ord('0')); B.AppendByte(Ord('3'));
  B.AppendByte(Ord('l'));
  B.AppendByte(27); B.AppendByte(Ord('['));
  B.AppendByte(Ord('?')); B.AppendByte(Ord('1')); B.AppendByte(Ord('0')); B.AppendByte(Ord('0')); B.AppendByte(Ord('6'));
  B.AppendByte(Ord('l'));
end;

{ SGR helpers }

const
  CSI_SGR_RESET: array[0..3] of Byte = (27, Ord('['), Ord('0'), Ord('m'));

procedure AnsiSgrReset(var B: TByteBuilder);
begin
  B.AppendBytes(CSI_SGR_RESET[0], 4);
end;

// Internal: emit a "named or indexed" foreground.
//
//   Named 0..7  -> SGR 30..37
//   Named 8..15 -> SGR 90..97  (bright versions)
//   Indexed >=16 -> SGR 38;5;N
procedure EmitIndexedFg(var B: TByteBuilder; Idx: Byte); inline;
var
  Buf: array[0..4] of Byte;
begin
  Buf[0] := 27;
  Buf[1] := Ord('[');
  if Idx < 8 then
  begin
    Buf[2] := Ord('3');
    Buf[3] := Ord('0') + Idx;
    Buf[4] := Ord('m');
    B.AppendBytes(Buf[0], 5);
  end
  else if Idx < 16 then
  begin
    Buf[2] := Ord('9');
    Buf[3] := Ord('0') + (Idx - 8);
    Buf[4] := Ord('m');
    B.AppendBytes(Buf[0], 5);
  end
  else
  begin
    B.AppendBytes(Buf[0], 2);
    B.AppendByte(Ord('3')); B.AppendByte(Ord('8'));
    B.AppendByte(Ord(';')); B.AppendByte(Ord('5')); B.AppendByte(Ord(';'));
    B.AppendUInt(Idx);
    B.AppendByte(Ord('m'));
  end;
end;

procedure EmitIndexedBg(var B: TByteBuilder; Idx: Byte); inline;
var
  Buf: array[0..5] of Byte;
begin
  Buf[0] := 27;
  Buf[1] := Ord('[');
  if Idx < 8 then
  begin
    Buf[2] := Ord('4');
    Buf[3] := Ord('0') + Idx;
    Buf[4] := Ord('m');
    B.AppendBytes(Buf[0], 5);
  end
  else if Idx < 16 then
  begin
    Buf[2] := Ord('1'); Buf[3] := Ord('0'); Buf[4] := Ord('0') + (Idx - 8);
    Buf[5] := Ord('m');
    B.AppendBytes(Buf[0], 6);
  end
  else
  begin
    B.AppendBytes(Buf[0], 2);
    B.AppendByte(Ord('4')); B.AppendByte(Ord('8'));
    B.AppendByte(Ord(';')); B.AppendByte(Ord('5')); B.AppendByte(Ord(';'));
    B.AppendUInt(Idx);
    B.AppendByte(Ord('m'));
  end;
end;

procedure AnsiSgrFg(var B: TByteBuilder; const C: TColor);
begin
  case C.Kind of
    ckUnset: ;     // intentionally no-op — caller should not request
    ckReset:
      begin
        // SGR 39 = default foreground
        B.AppendByte(27); B.AppendByte(Ord('['));
        B.AppendByte(Ord('3')); B.AppendByte(Ord('9'));
        B.AppendByte(Ord('m'));
      end;
    ckIndexed:
      EmitIndexedFg(B, C.Index);
    ckRgb:
      begin
        B.AppendByte(27); B.AppendByte(Ord('['));
        B.AppendByte(Ord('3')); B.AppendByte(Ord('8'));
        B.AppendByte(Ord(';')); B.AppendByte(Ord('2')); B.AppendByte(Ord(';'));
        B.AppendUInt(C.R); B.AppendByte(Ord(';'));
        B.AppendUInt(C.G); B.AppendByte(Ord(';'));
        B.AppendUInt(C.B);
        B.AppendByte(Ord('m'));
      end;
  end;
end;

procedure AnsiSgrBg(var B: TByteBuilder; const C: TColor);
begin
  case C.Kind of
    ckUnset: ;
    ckReset:
      begin
        // SGR 49 = default background
        B.AppendByte(27); B.AppendByte(Ord('['));
        B.AppendByte(Ord('4')); B.AppendByte(Ord('9'));
        B.AppendByte(Ord('m'));
      end;
    ckIndexed:
      EmitIndexedBg(B, C.Index);
    ckRgb:
      begin
        B.AppendByte(27); B.AppendByte(Ord('['));
        B.AppendByte(Ord('4')); B.AppendByte(Ord('8'));
        B.AppendByte(Ord(';')); B.AppendByte(Ord('2')); B.AppendByte(Ord(';'));
        B.AppendUInt(C.R); B.AppendByte(Ord(';'));
        B.AppendUInt(C.G); B.AppendByte(Ord(';'));
        B.AppendUInt(C.B);
        B.AppendByte(Ord('m'));
      end;
  end;
end;

// ratatui modifier bit -> SGR set parameter (bold=1, dim=2, italic=3, ...)
function SgrSet(Bit: TModifierBit): Byte; inline;
begin
  Result := 0;
  case Bit of
    mbBold:        Result := 1;
    mbDim:         Result := 2;
    mbItalic:      Result := 3;
    mbUnderlined:  Result := 4;
    mbSlowBlink:   Result := 5;
    mbRapidBlink:  Result := 6;
    mbReversed:    Result := 7;
    mbHidden:      Result := 8;
    mbCrossedOut:  Result := 9;
  end;
end;

// SGR clear codes per attribute.  bold and dim share SGR 22, the rest
// have their own (italic=23, underline=24, blink=25, reverse=27, hidden=28,
// crossed-out=29).
function SgrClear(Bit: TModifierBit): Byte; inline;
begin
  Result := 0;
  case Bit of
    mbBold, mbDim:               Result := 22;
    mbItalic:                    Result := 23;
    mbUnderlined:                Result := 24;
    mbSlowBlink, mbRapidBlink:   Result := 25;
    mbReversed:                  Result := 27;
    mbHidden:                    Result := 28;
    mbCrossedOut:                Result := 29;
  end;
end;

procedure AnsiSgrModifierAdd(var B: TByteBuilder; M: TModifier);
var
  Bit: TModifierBit;
  Code: Byte;
begin
  for Bit := Low(TModifierBit) to High(TModifierBit) do
    if Bit in M then
    begin
      Code := SgrSet(Bit);
      B.AppendByte(27); B.AppendByte(Ord('['));
      B.AppendUInt(Code);
      B.AppendByte(Ord('m'));
    end;
end;

procedure AnsiSgrModifierClear(var B: TByteBuilder; M: TModifier);
var
  Bit: TModifierBit;
  Code: Byte;
begin
  for Bit := Low(TModifierBit) to High(TModifierBit) do
    if Bit in M then
    begin
      Code := SgrClear(Bit);
      B.AppendByte(27); B.AppendByte(Ord('['));
      B.AppendUInt(Code);
      B.AppendByte(Ord('m'));
    end;
end;

end.
