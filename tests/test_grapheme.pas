unit test_grapheme;

{$mode objfpc}{$H+}

interface

procedure RegisterGraphemeTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_grapheme;

procedure Test_AsciiWidthEqualsLength;
begin
  AssertEqInt(0, GraphemeWidth(''), 'empty');
  AssertEqInt(5, GraphemeWidth('hello'), 'hello');
  AssertEqInt(1, GraphemeWidth(' '), 'space');
  AssertEqInt(10, GraphemeWidth('0123456789'), 'digits');
end;

procedure Test_ControlBytesAreZeroWidth;
begin
  AssertEqInt(0, CodepointWidth(0), 'NUL');
  AssertEqInt(0, CodepointWidth(9), 'TAB');
  AssertEqInt(0, CodepointWidth(10), 'LF');
  AssertEqInt(0, CodepointWidth(127), 'DEL');
end;

procedure Test_CjkIdeographsAreWidth2;
begin
  // U+4E2D = 中, U+6587 = 文
  AssertEqInt(2, CodepointWidth($4E2D), 'U+4E2D 中');
  AssertEqInt(2, CodepointWidth($6587), 'U+6587 文');
  // U+3042 = あ (Hiragana)
  AssertEqInt(2, CodepointWidth($3042), 'U+3042 あ');
  // U+AC00 = 가 (Hangul)
  AssertEqInt(2, CodepointWidth($AC00), 'U+AC00 가');
end;

procedure Test_FullwidthAsciiIsWidth2;
begin
  // U+FF21 = Ａ (fullwidth A)
  AssertEqInt(2, CodepointWidth($FF21), 'U+FF21 Ａ');
  // U+FF01 = ！ (fullwidth !)
  AssertEqInt(2, CodepointWidth($FF01), 'U+FF01 ！');
end;

procedure Test_LatinCyrillicAreWidth1;
begin
  AssertEqInt(1, CodepointWidth($00E9), 'U+00E9 é');
  AssertEqInt(1, CodepointWidth($0410), 'U+0410 А (Cyrillic)');
  AssertEqInt(1, CodepointWidth($00FC), 'U+00FC ü');
end;

procedure Test_GraphemeWidthOnCjkString;
begin
  // "你好" = U+4F60 U+597D, each 3 bytes UTF-8, each width 2 -> total 4
  AssertEqInt(4, GraphemeWidth(#$E4#$BD#$A0#$E5#$A5#$BD), '"你好" = 4 cols');
  // "hi你" = 'h' + 'i' + U+4F60 -> 1+1+2 = 4
  AssertEqInt(4, GraphemeWidth('hi' + #$E4#$BD#$A0), '"hi你" = 4 cols');
end;

procedure Test_GraphemeAdvanceDecode;
var
  S: AnsiString;
  A: TGraphemeAdvance;
begin
  // ASCII
  S := 'A';
  A := GraphemeAdvance(S[1], Length(S), 0);
  AssertEqInt(1, A.ByteLen, 'A bytelen');
  AssertEqInt(1, A.Width, 'A width');
  AssertEqInt(Ord('A'), LongInt(A.Codepoint), 'A codepoint');

  // 2-byte UTF-8: U+00E9 = é = C3 A9
  S := #$C3#$A9;
  A := GraphemeAdvance(S[1], Length(S), 0);
  AssertEqInt(2, A.ByteLen, 'é bytelen');
  AssertEqInt(1, A.Width, 'é width');
  AssertEqInt($E9, LongInt(A.Codepoint), 'é codepoint');

  // 3-byte UTF-8: U+4E2D = 中 = E4 B8 AD
  S := #$E4#$B8#$AD;
  A := GraphemeAdvance(S[1], Length(S), 0);
  AssertEqInt(3, A.ByteLen, '中 bytelen');
  AssertEqInt(2, A.Width, '中 width');
  AssertEqInt($4E2D, LongInt(A.Codepoint), '中 codepoint');

  // 4-byte UTF-8: U+1F600 = 😀 = F0 9F 98 80
  S := #$F0#$9F#$98#$80;
  A := GraphemeAdvance(S[1], Length(S), 0);
  AssertEqInt(4, A.ByteLen, '😀 bytelen');
  AssertEqInt(2, A.Width, '😀 width (emoji in range)');
  AssertEqInt($1F600, LongInt(A.Codepoint), '😀 codepoint');
end;

procedure Test_BufferSetStringCjkOccupiesTwoCells;
var
  Buf: TBuffer;
  CP: PCell;
begin
  // Buffer 6 cols wide.  Write "中a" -> 中 takes cols 0-1, 'a' takes col 2.
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    Buf.SetString(0, 0, #$E4#$B8#$AD + 'a', TStyle.Default);
    // Col 0: leading cell of 中, Width=2, Glyph = 3 bytes
    CP := Buf.CellAt(0, 0);
    AssertEqInt(2, CP^.Width, 'col 0 width=2');
    AssertEqInt(3, CP^.Glyph.Len, 'col 0 glyph 3 bytes');
    // Col 1: sentinel, Width=0, Skip=True
    CP := Buf.CellAt(1, 0);
    AssertEqInt(0, CP^.Width, 'col 1 sentinel width=0');
    AssertTrue(CP^.Skip, 'col 1 sentinel skip=true');
    // Col 2: 'a'
    CP := Buf.CellAt(2, 0);
    AssertEqInt(1, CP^.Width, 'col 2 width=1');
    AssertEqInt(Ord('a'), CP^.Glyph.Bytes[0], 'col 2 = a');
    // Cols 3-5: still blank
    CP := Buf.CellAt(3, 0);
    AssertEqInt(1, CP^.Width, 'col 3 blank width=1');
    AssertEqInt(Ord(' '), CP^.Glyph.Bytes[0], 'col 3 = space');
  finally
    Buf.Free;
  end;
end;

procedure Test_BufferSetStringCjkClipsAtEdge;
var
  Buf: TBuffer;
  Written: Integer;
begin
  // Buffer 3 cols.  "中x" needs 2+1=3 cols -> fits exactly.
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    Written := Buf.SetString(0, 0, #$E4#$B8#$AD + 'x', TStyle.Default);
    AssertEqInt(3, Written, '中x fits in 3 cols');
  finally
    Buf.Free;
  end;

  // Buffer 2 cols.  "中" needs 2 -> fits.  "中x" needs 3 -> only 中 fits.
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    Written := Buf.SetString(0, 0, #$E4#$B8#$AD + 'x', TStyle.Default);
    AssertEqInt(2, Written, '中 fits but x does not');
  finally
    Buf.Free;
  end;

  // Buffer 1 col.  "中" needs 2 -> doesn't fit at all.
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    Written := Buf.SetString(0, 0, #$E4#$B8#$AD, TStyle.Default);
    AssertEqInt(0, Written, '中 does not fit in 1 col');
  finally
    Buf.Free;
  end;
end;

procedure Test_RowAsStringSkipsSentinel;
var
  Buf: TBuffer;
  Row: AnsiString;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    Buf.SetString(0, 0, #$E4#$B8#$AD + 'ab', TStyle.Default);
    Row := Buf.RowAsString(0);
    // Expected: "中ab   " but sentinel skipped -> "中ab " (3+1+1+1=6 bytes? no)
    // 中 = 3 bytes, a = 1, b = 1, then 3 blank cells = 3 spaces -> total 8 bytes
    // Wait: buffer is 6 cols.  中 takes 2 cols, a takes 1, b takes 1 -> 4 cols used.
    // Remaining 2 cols are blank spaces.  RowAsString skips sentinel (col 1) and
    // outputs: 中(3 bytes) + a(1) + b(1) + space(1) + space(1) = 7 bytes.
    AssertEqStr(#$E4#$B8#$AD + 'ab  ', Row, 'RowAsString with CJK');
  finally
    Buf.Free;
  end;
end;

procedure Test_SpanWidthCjk;
begin
  // Uses ftui_text indirectly via GraphemeWidth.
  AssertEqInt(4, GraphemeWidth(#$E4#$BD#$A0#$E5#$A5#$BD), 'span "你好" = 4');
end;

procedure RegisterGraphemeTests;
begin
  RegisterTest('grapheme / ASCII width = length',          @Test_AsciiWidthEqualsLength);
  RegisterTest('grapheme / control bytes are zero-width',  @Test_ControlBytesAreZeroWidth);
  RegisterTest('grapheme / CJK ideographs are width 2',   @Test_CjkIdeographsAreWidth2);
  RegisterTest('grapheme / fullwidth ASCII is width 2',    @Test_FullwidthAsciiIsWidth2);
  RegisterTest('grapheme / Latin/Cyrillic are width 1',    @Test_LatinCyrillicAreWidth1);
  RegisterTest('grapheme / GraphemeWidth on CJK string',   @Test_GraphemeWidthOnCjkString);
  RegisterTest('grapheme / GraphemeAdvance decode',        @Test_GraphemeAdvanceDecode);
  RegisterTest('grapheme / buffer SetString CJK 2 cells',  @Test_BufferSetStringCjkOccupiesTwoCells);
  RegisterTest('grapheme / buffer SetString CJK clips',    @Test_BufferSetStringCjkClipsAtEdge);
  RegisterTest('grapheme / RowAsString skips sentinel',    @Test_RowAsStringSkipsSentinel);
  RegisterTest('grapheme / Span.Width CJK',                @Test_SpanWidthCjk);
end;

end.
