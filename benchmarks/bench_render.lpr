program bench_render;

// Performance benchmark: full widget render pipeline.
//
// Simulates a realistic cli888 frame: Block + List (20 items, one
// selected) + Paragraph status bar, on an 80x24 terminal.  Measures
// the complete path: widget.Render → buffer.Diff → backend.DrawPatches.
//
// 1000 frames, alternating selection to force diff work.

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
  ftui_paragraph,
  ftui_list,
  ftui_ansi_backend;

const
  WIDTH  = 80;
  HEIGHT = 24;
  FRAMES = 1000;
  ITEM_COUNT = 20;

var
  Prev, Curr, Tmp: TBuffer;
  Backend: TAnsiBackend;
  Patches: TDiffEntries;
  Items: array[0..ITEM_COUNT - 1] of AnsiString;
  ListSt: TListState;
  Frame, I: Integer;
  StartTick, EndTick: Int64;
  TotalMs, PerFrameUs: Double;
  TotalBytes: Int64;
  Rows: TRectArray;
  Title: TParagraph;
  Body: TList;
  Hint: TParagraph;

begin
  WriteLn('bench_render: ', WIDTH, 'x', HEIGHT, ', ', FRAMES, ' frames, ', ITEM_COUNT, ' list items');
  WriteLn;

  for I := 0 to ITEM_COUNT - 1 do
    Items[I] := Format('item %2d — some content here for row #%d', [I + 1, I + 1]);

  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, WIDTH, HEIGHT));
  Backend := TAnsiBackend.Create(-1);
  TotalBytes := 0;
  ListSt := TListState.Empty;
  ListSt.Select(0);

  StartTick := GetTickCount64;

  for Frame := 0 to FRAMES - 1 do
  begin
    Curr.Reset;

    // Move selection each frame to force diff changes.
    ListSt.Selected := Frame mod ITEM_COUNT;

    Rows := VerticalSplit(TRect.Make(0, 0, WIDTH, HEIGHT), [
      LengthConstraint(1),
      MinConstraint(0),
      LengthConstraint(1)
    ]);

    Title := TParagraph.FromString(' fafafa.tui bench ')
              .WithStyle(TStyle.Default.WithBg(clYellow).WithFg(clBlack))
              .WithAlignment(caCenter);
    Title.Render(Rows[0], Curr);

    Body := TList.FromStrings(Items)
              .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' messages '))
              .WithHighlightSymbol('> ')
              .WithHighlightStyle(TStyle.Default.WithBg(RgbColor(40, 40, 60)).WithFg(clCyan).WithModifier([mbBold]));
    Body.RenderStateful(Rows[1], Curr, ListSt);

    Hint := TParagraph.FromString(' status: running benchmark... ')
              .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
    Hint.Render(Rows[2], Curr);

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

  WriteLn(Format('total time:      %.1f ms', [TotalMs]));
  WriteLn(Format('per-frame:       %.1f us', [PerFrameUs]));
  WriteLn(Format('fps headroom:    %.0f', [1000000.0 / PerFrameUs]));
  WriteLn(Format('bytes/frame avg: %.0f', [TotalBytes / FRAMES]));
  WriteLn;

  if PerFrameUs < 1000.0 then
    WriteLn('PASS: frame time < 1ms')
  else
    WriteLn('FAIL: frame time >= 1ms');

  Curr.Free;
  Prev.Free;
  Backend.Free;
end.
