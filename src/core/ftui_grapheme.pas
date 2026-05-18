unit ftui_grapheme;

// UTF-8 decoder + East Asian Width table.  Zero external deps —
// the width table is a static array of (lo, hi) ranges drawn from
// Unicode Standard Annex #11 (Wide + Fullwidth categories) plus
// the Miscellaneous Symbols / Emoji blocks cli888 actually uses.
//
// What we cover:
//   - Codepoints in any of the listed Wide ranges -> width 2
//   - Everything else (including ASCII, Latin, Cyrillic, etc.)
//                                                  -> width 1
//   - Control bytes 0..31 / 127                    -> width 0
//
// What we DON'T cover (deliberate, M2.1 scope):
//   - Grapheme clustering: multi-codepoint clusters (ZWJ emoji,
//     family emoji, combining diacritics) are decoded codepoint by
//     codepoint and each gets its own width / cell.  Looks fine for
//     CJK + simple emoji; complex ZWJ sequences may render poorly.
//   - Variation selectors (U+FE0F).
//   - Combining marks (Mn / Me / Mc) folded into the preceding cell.
//
// API:
//   - GraphemeAdvance(buf, len) decodes one UTF-8 codepoint, returns
//     the byte length consumed and the column width.
//   - GraphemeWidth(s) sums widths over an entire byte string.

{$mode objfpc}{$H+}{$inline on}

interface

type
  TGraphemeAdvance = record
    ByteLen: Integer;     // 1..4, or 1 on invalid (skip the byte)
    Width:   Integer;     // 0/1/2
    Codepoint: LongWord;  // decoded UCS-4, or replacement (0xFFFD) on invalid
  end;

// Decode the next UTF-8 codepoint at Buf+Offset.  Buf is treated as
// PByte; Len is total bytes available; Offset is the starting byte.
// Returns Advance with the decoded codepoint, byte length consumed,
// and East Asian Width in columns.  On invalid bytes returns
// ByteLen=1, Width=1, Codepoint=$FFFD so callers can keep advancing.
function GraphemeAdvance(const Buf; Len, Offset: Integer): TGraphemeAdvance;

// Width sum over an AnsiString.  ASCII fast path: if every byte is
// < 128, returns Length(S).  Otherwise walks via GraphemeAdvance.
function GraphemeWidth(const S: AnsiString): Integer;

// Just the column width for one decoded codepoint.  Public for tests.
function CodepointWidth(Cp: LongWord): Integer; inline;

implementation

type
  TWideRange = record
    Lo, Hi: LongWord;
  end;

const
  // East Asian Wide + Fullwidth ranges, sorted by Lo.  Compact subset
  // covering CJK + Hangul + Hiragana/Katakana + fullwidth ASCII +
  // Misc Symbols + Emoji blocks cli888 typically renders.  Sourced
  // from Unicode 15.0 EastAsianWidth.txt (W and F entries) and
  // Miscellaneous Symbols (often width-2 in practice).
  Ranges: array[0..30] of TWideRange = (
    // CJK Symbols and Punctuation through CJK Strokes
    (Lo: $1100; Hi: $115F),  // Hangul Jamo
    (Lo: $231A; Hi: $231B),  // ⌚ ⌛
    (Lo: $2329; Hi: $232A),  // 〈 〉
    (Lo: $23E9; Hi: $23EC),  // ⏩ ⏬
    (Lo: $23F0; Hi: $23F0),  // ⏰
    (Lo: $23F3; Hi: $23F3),  // ⏳
    (Lo: $25FD; Hi: $25FE),  // ◽ ◾
    (Lo: $2614; Hi: $2615),  // ☔ ☕
    (Lo: $2648; Hi: $2653),  // zodiac
    (Lo: $267F; Hi: $267F),  // ♿
    (Lo: $2693; Hi: $2693),  // ⚓
    (Lo: $26A1; Hi: $26A1),  // ⚡
    (Lo: $26AA; Hi: $26AB),  // ⚪ ⚫
    (Lo: $26BD; Hi: $26BE),  // ⚽ ⚾
    (Lo: $26C4; Hi: $26C5),  // ⛄ ⛅
    (Lo: $26CE; Hi: $26CE),  // ⛎
    (Lo: $26D4; Hi: $26D4),  // ⛔
    (Lo: $26EA; Hi: $26EA),  // ⛪
    (Lo: $2700; Hi: $27BF),  // Dingbats / Misc Symbols (covers many emoji)
    (Lo: $2E80; Hi: $303E),  // CJK Radicals + Symbols + Punctuation
    (Lo: $3041; Hi: $33FF),  // Hiragana / Katakana / Bopomofo / Compat
    (Lo: $3400; Hi: $4DBF),  // CJK Unified Ideographs Extension A
    (Lo: $4E00; Hi: $9FFF),  // CJK Unified Ideographs
    (Lo: $A000; Hi: $A4CF),  // Yi Syllables / Yi Radicals
    (Lo: $AC00; Hi: $D7A3),  // Hangul Syllables
    (Lo: $F900; Hi: $FAFF),  // CJK Compatibility Ideographs
    (Lo: $FE30; Hi: $FE4F),  // CJK Compatibility Forms
    (Lo: $FF00; Hi: $FF60),  // Fullwidth ASCII / Halfwidth Forms
    (Lo: $FFE0; Hi: $FFE6),  // Fullwidth signs (¥ ₩ etc.)
    (Lo: $1F300; Hi: $1FAFF),// Misc Symbols & Pictographs / Emoji
    (Lo: $20000; Hi: $3FFFD) // CJK Extension B/C/D/E/F/G + Compat Supplement
  );

function CodepointWidth(Cp: LongWord): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  // Control bytes — zero columns.  Render layer paints them as space.
  if (Cp < 32) or (Cp = 127) then Exit(0);

  // ASCII / Latin fast path: anything below the smallest wide range.
  if Cp < $1100 then Exit(1);

  // Binary search the static range table.
  Lo := 0;
  Hi := High(Ranges);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) shr 1;
    if Cp < Ranges[Mid].Lo then
      Hi := Mid - 1
    else if Cp > Ranges[Mid].Hi then
      Lo := Mid + 1
    else
      Exit(2);
  end;
  Result := 1;
end;

function GraphemeAdvance(const Buf; Len, Offset: Integer): TGraphemeAdvance;
var
  P: PByte;
  B0, B1, B2, B3: Byte;
  Cp: LongWord;
  Need: Integer;
begin
  Result.ByteLen := 1;
  Result.Width := 1;
  Result.Codepoint := $FFFD;

  if Offset >= Len then Exit;

  P := PByte(@Buf);
  B0 := P[Offset];

  // ASCII fast path.
  if B0 < $80 then
  begin
    Result.Codepoint := B0;
    Result.Width := CodepointWidth(B0);
    Exit;
  end;

  // Determine the encoding length from B0.
  if      (B0 and $E0) = $C0 then Need := 2
  else if (B0 and $F0) = $E0 then Need := 3
  else if (B0 and $F8) = $F0 then Need := 4
  else
  begin
    // Continuation byte at the start, or 5/6-byte form (illegal in
    // modern UTF-8).  Skip 1 byte, report replacement.
    Exit;
  end;

  if Offset + Need > Len then Exit;     // truncated; skip 1 byte

  case Need of
    2:
      begin
        B1 := P[Offset + 1];
        if (B1 and $C0) <> $80 then Exit;
        Cp := (LongWord(B0 and $1F) shl 6) or LongWord(B1 and $3F);
        if Cp < $80 then Exit;          // overlong; reject
      end;
    3:
      begin
        B1 := P[Offset + 1];
        B2 := P[Offset + 2];
        if ((B1 and $C0) <> $80) or ((B2 and $C0) <> $80) then Exit;
        Cp := (LongWord(B0 and $0F) shl 12) or
              (LongWord(B1 and $3F) shl 6)  or
              LongWord(B2 and $3F);
        if Cp < $800 then Exit;         // overlong
        if (Cp >= $D800) and (Cp <= $DFFF) then Exit;  // surrogate
      end;
    4:
      begin
        B1 := P[Offset + 1];
        B2 := P[Offset + 2];
        B3 := P[Offset + 3];
        if ((B1 and $C0) <> $80) or ((B2 and $C0) <> $80) or
           ((B3 and $C0) <> $80) then Exit;
        Cp := (LongWord(B0 and $07) shl 18) or
              (LongWord(B1 and $3F) shl 12) or
              (LongWord(B2 and $3F) shl 6)  or
              LongWord(B3 and $3F);
        if Cp < $10000 then Exit;       // overlong
        if Cp > $10FFFF then Exit;      // out of range
      end;
  else
    Exit;
  end;

  Result.ByteLen := Need;
  Result.Codepoint := Cp;
  Result.Width := CodepointWidth(Cp);
end;

function GraphemeWidth(const S: AnsiString): Integer;
var
  I, L, Total: Integer;
  AllAscii: Boolean;
  Adv: TGraphemeAdvance;
begin
  L := Length(S);
  if L = 0 then Exit(0);

  // Hot ASCII path: skim once to see if any byte has the high bit
  // set.  If not, return Length immediately and avoid the per-byte
  // case dispatch.
  AllAscii := True;
  for I := 1 to L do
    if Byte(S[I]) >= $80 then
    begin
      AllAscii := False;
      Break;
    end;
  if AllAscii then Exit(L);

  Total := 0;
  I := 0;
  while I < L do
  begin
    Adv := GraphemeAdvance(S[1], L, I);
    Inc(Total, Adv.Width);
    Inc(I, Adv.ByteLen);
  end;
  Result := Total;
end;

end.
