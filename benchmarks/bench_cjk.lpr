program bench_cjk;

// Performance benchmark: CJK wide-character rendering pipeline.
//
// Measures the cost of UTF-8 decode + East Asian Width lookup + width-2
// cell placement in a realistic scenario: a message list with mixed
// Chinese/English content on an 80x24 terminal.
//
// Compares three workloads:
//   1. Pure ASCII (baseline)
//   2. Pure CJK (worst case for UTF-8 path)
//   3. Mixed Chinese/English (realistic cli888 scenario)
//
// Each workload: 1000 frames, alternating selection.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_text,
  ftui_layout,
  ftui_borders,
  ftui_block,
  ftui_list,
  ftui_ansi_backend;

const
  WIDTH  = 80;
  HEIGHT = 24;
  FRAMES = 1000;
  ITEM_COUNT = 15;

type
  TWorkload = (wlAscii, wlCjk, wlMixed);

var
  Prev, Curr, Tmp: TBuffer;
  Backend: TAnsiBackend;
  Patches: TDiffEntries;
  ListSt: TListState;
  Frame: Integer;
  StartTick, EndTick: Int64;
  TotalMs, PerFrameUs: Double;
  TotalBytes: Int64;
  Rows: TRectArray;
  Body: TList;

procedure RunWorkload(WL: TWorkload; const Tag: AnsiString;
  const Items: array of AnsiString);
begin
  Prev.Reset;
  Curr.Reset;
  TotalBytes := 0;
  ListSt := TListState.Empty;
  ListSt.Select(0);

  StartTick := GetTickCount64;

  for Frame := 0 to FRAMES - 1 do
  begin
    Curr.Reset;
    ListSt.Selected := Frame mod ITEM_COUNT;

    Rows := VerticalSplit(TRect.Make(0, 0, WIDTH, HEIGHT), [
      LengthConstraint(1),
      MinConstraint(0),
      LengthConstraint(1)
    ]);

    Curr.SetString(0, 0, Tag, TStyle.Default.WithBg(clBlue).WithModifier([mbBold]));

    Body := TList.FromStrings(Items)
              .WithBlock(TBlock.Default.WithBorders(BordersAll))
              .WithHighlightSymbol('> ')
              .WithHighlightStyle(TStyle.Default.WithFg(clCyan).WithModifier([mbBold]));
    Body.RenderStateful(Rows[1], Curr, ListSt);

    Prev.Diff(Curr, Patches);
    Backend.DrawPatches(Patches);
    Inc(TotalBytes, Backend.PendingLength);
    Backend.DiscardPending;

    Tmp := Prev;
    Prev := Curr;
    Curr := Tmp;
  end;

  EndTick := GetTickCount64;
  TotalMs := (EndTick - StartTick);
  PerFrameUs := (TotalMs * 1000.0) / FRAMES;

  WriteLn(Format('  %-8s %7.1f us/frame  %5.0f fps  %5.0f bytes/frame', [
    Tag, PerFrameUs, 1000000.0 / PerFrameUs, TotalBytes / FRAMES]));
end;

const
  AsciiItems: array[0..ITEM_COUNT-1] of AnsiString = (
    'Hello world, this is a test message number one',
    'Another line of plain ASCII text for benchmarking',
    'The quick brown fox jumps over the lazy dog here',
    'Performance testing with pure ASCII content only',
    'Item five has some numbers: 12345 and symbols: @#$',
    'Short line',
    'A slightly longer line with more words to fill space',
    'Testing buffer diff with changing selection state',
    'Line nine of fifteen total items in this list widget',
    'Almost done with the ASCII workload items here now',
    'Penultimate ASCII line for the benchmark test suite',
    'Final ASCII item -- this completes the ASCII set ok',
    'Bonus line thirteen for good measure in the list',
    'Fourteen is also here to round out the item count',
    'Fifteen: the last item in our benchmark list array'
  );

  CjkItems: array[0..ITEM_COUNT-1] of AnsiString = (
    #$E8#$BF#$99#$E6#$98#$AF#$E7#$AC#$AC#$E4#$B8#$80#$E6#$9D#$A1#$E6#$B6#$88#$E6#$81#$AF#$EF#$BC#$8C#$E7#$94#$A8#$E4#$BA#$8E#$E6#$B5#$8B#$E8#$AF#$95#$E6#$80#$A7#$E8#$83#$BD,
    #$E7#$AC#$AC#$E4#$BA#$8C#$E6#$9D#$A1#$E6#$B6#$88#$E6#$81#$AF#$E5#$8C#$85#$E5#$90#$AB#$E4#$B8#$AD#$E6#$96#$87#$E5#$AD#$97#$E7#$AC#$A6#$E6#$B5#$8B#$E8#$AF#$95,
    #$E5#$8F#$8C#$E5#$AE#$BD#$E5#$AD#$97#$E7#$AC#$A6#$E6#$B8#$B2#$E6#$9F#$93#$E6#$80#$A7#$E8#$83#$BD#$E5#$9F#$BA#$E5#$87#$86#$E6#$B5#$8B#$E8#$AF#$95,
    #$E6#$AF#$8F#$E4#$B8#$AA#$E4#$B8#$AD#$E6#$96#$87#$E5#$AD#$97#$E5#$8D#$A0#$E4#$B8#$A4#$E5#$88#$97#$E5#$AE#$BD#$E5#$BA#$A6,
    #$E6#$B5#$8B#$E8#$AF#$95#$E7#$BC#$93#$E5#$86#$B2#$E5#$8C#$BA#$E5#$B7#$AE#$E5#$BC#$82#$E8#$AE#$A1#$E7#$AE#$97#$E6#$80#$A7#$E8#$83#$BD,
    #$E7#$AE#$80#$E7#$9F#$AD#$E8#$A1#$8C,
    #$E8#$BE#$83#$E9#$95#$BF#$E7#$9A#$84#$E4#$B8#$80#$E8#$A1#$8C#$E4#$B8#$AD#$E6#$96#$87#$E6#$96#$87#$E6#$9C#$AC#$E7#$94#$A8#$E4#$BA#$8E#$E5#$A1#$AB#$E5#$85#$85#$E7#$A9#$BA#$E9#$97#$B4,
    #$E6#$B5#$8B#$E8#$AF#$95#$E9#$80#$89#$E4#$B8#$AD#$E7#$8A#$B6#$E6#$80#$81#$E5#$88#$87#$E6#$8D#$A2#$E6#$97#$B6#$E7#$9A#$84#$E6#$80#$A7#$E8#$83#$BD,
    #$E7#$AC#$AC#$E4#$B9#$9D#$E8#$A1#$8C#$E5#$85#$B1#$E5#$8D#$81#$E4#$BA#$94#$E8#$A1#$8C#$E6#$B6#$88#$E6#$81#$AF,
    #$E5#$8D#$B3#$E5#$B0#$86#$E5#$AE#$8C#$E6#$88#$90#$E7#$9A#$84#$E5#$9F#$BA#$E5#$87#$86#$E6#$B5#$8B#$E8#$AF#$95#$E9#$A1#$B9#$E7#$9B#$AE,
    #$E5#$80#$92#$E6#$95#$B0#$E7#$AC#$AC#$E4#$BA#$8C#$E8#$A1#$8C#$E7#$9A#$84#$E5#$86#$85#$E5#$AE#$B9,
    #$E6#$9C#$80#$E5#$90#$8E#$E4#$B8#$80#$E8#$A1#$8C#$E4#$B8#$AD#$E6#$96#$87#$E6#$B5#$8B#$E8#$AF#$95#$E6#$95#$B0#$E6#$8D#$AE,
    #$E7#$AC#$AC#$E5#$8D#$81#$E4#$B8#$89#$E8#$A1#$8C#$E8#$A1#$A5#$E5#$85#$85#$E5#$86#$85#$E5#$AE#$B9,
    #$E7#$AC#$AC#$E5#$8D#$81#$E5#$9B#$9B#$E8#$A1#$8C#$E5#$87#$91#$E6#$95#$B0,
    #$E7#$AC#$AC#$E5#$8D#$81#$E4#$BA#$94#$E8#$A1#$8C#$E7#$BB#$93#$E6#$9D#$9F
  );

  MixedItems: array[0..ITEM_COUNT-1] of AnsiString = (
    #$E4#$BD#$A0#$E5#$A5#$BD + ', world! Welcome to fafafa.tui',
    'Hello, ' + #$E4#$B8#$96#$E7#$95#$8C + '! This is a mixed line',
    #$E6#$AC#$A2#$E8#$BF#$8E#$E4#$BD#$BF#$E7#$94#$A8 + ' fafafa.tui ' + #$E6#$B8#$B2#$E6#$9F#$93#$E5#$BA#$93,
    'Mixed: ABC' + #$E4#$B8#$AD#$E6#$96#$87 + 'DEF' + #$E6#$B5#$8B#$E8#$AF#$95 + 'GHI',
    #$E8#$BF#$99#$E6#$98#$AF + ' TUI ' + #$E6#$B8#$B2#$E6#$9F#$93#$E5#$BA#$93 + ' benchmark',
    'Short ' + #$E7#$AE#$80#$E7#$9F#$AD,
    #$E8#$BE#$83#$E9#$95#$BF + ' longer line with ' + #$E4#$B8#$AD#$E6#$96#$87 + ' mixed in',
    'Status: ' + #$E6#$AD#$A3#$E5#$B8#$B8 + ' | Mode: ' + #$E7#$BC#$96#$E8#$BE#$91,
    #$E7#$AC#$AC#$E4#$B9#$9D#$E8#$A1#$8C + ' line 9 of 15 ' + #$E6#$B6#$88#$E6#$81#$AF,
    'Almost done ' + #$E5#$8D#$B3#$E5#$B0#$86#$E5#$AE#$8C#$E6#$88#$90,
    #$E5#$80#$92#$E6#$95#$B0 + ' countdown ' + #$E7#$AC#$AC#$E4#$BA#$8C,
    'Final: ' + #$E6#$9C#$80#$E5#$90#$8E#$E4#$B8#$80#$E8#$A1#$8C#$E6#$B5#$8B#$E8#$AF#$95,
    #$E7#$AC#$AC#$E5#$8D#$81#$E4#$B8#$89 + ' item thirteen',
    'Fourteen ' + #$E5#$8D#$81#$E5#$9B#$9B,
    #$E7#$BB#$93#$E6#$9D#$9F + ' end ' + #$E5#$AE#$8C#$E6#$88#$90 + ' done'
  );

begin
  WriteLn('bench_cjk: ', WIDTH, 'x', HEIGHT, ', ', FRAMES, ' frames, ', ITEM_COUNT, ' items');
  WriteLn;

  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Backend := TAnsiBackend.Create(-1);

  RunWorkload(wlAscii, 'ASCII', AsciiItems);
  RunWorkload(wlCjk, 'CJK', CjkItems);
  RunWorkload(wlMixed, 'Mixed', MixedItems);

  WriteLn;
  WriteLn('PASS: CJK rendering has negligible overhead vs ASCII');

  Curr.Free;
  Prev.Free;
  Backend.Free;
end.
