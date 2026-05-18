program chat_mock;

// fafafa.tui M2 visual smoke: the cli888-shaped chat skeleton.
//
// Layout:
//   ┌────────── title bar ──────────┐    Length 1
//   │                               │
//   │  message list (Block + List)  │    Min  0
//   │                               │
//   ├ ────────────────────────────── ┤
//   │  input box (Block)            │    Length 3
//   │                               │
//   ├ ────────────────────────────── ┤
//   │  status bar (Paragraph)       │    Length 1
//   └───────────────────────────────┘
//
// All widgets compose the way cli888 already does in Rust: build
// region rects with VerticalSplit, then render Block/List/Paragraph
// into each region.  No interactivity yet — the program paints one
// frame, holds 800 ms, and leaves.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_buffer,
  ftui_text,
  ftui_layout,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_list,
  ftui_ansi_backend;

const
  STDOUT = 1;
  AREA_W = 70;
  AREA_H = 20;

var
  Backend: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  Rows: TRectArray;
  TitleArea, MessagesArea, InputArea, StatusArea: TRect;
  TitlePara: TParagraph;
  Messages: TList;
  MsgState: TListState;
  InputBlock: TBlock;
  Hint: TParagraph;

begin
  Backend := TAnsiBackend.Create(STDOUT);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, AREA_W, AREA_H));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, AREA_W, AREA_H));
  try
    Backend.EnterAlternate;
    Backend.HideCursor;
    Backend.ClearScreen;
    Backend.Flush;

    Rows := VerticalSplit(Curr.Area, [
      LengthConstraint(1),    // title bar
      MinConstraint(0),       // message list (with its own Block)
      LengthConstraint(3),    // input box
      LengthConstraint(1)     // status bar
    ]);
    TitleArea    := Rows[0];
    MessagesArea := Rows[1];
    InputArea    := Rows[2];
    StatusArea   := Rows[3];

    // Title bar — yellow background, centered title.
    TitlePara := TParagraph.FromString(' fafafa.tui chat (M2 mock) ')
                  .WithStyle(TStyle.Default.WithBg(clYellow).WithFg(clBlack))
                  .WithAlignment(caCenter);
    TitlePara.Render(TitleArea, Curr);

    // Messages list — bordered Block with three demo messages and the
    // middle one selected.
    MsgState := TListState.Empty;
    MsgState.Select(1);
    Messages := TList.FromStrings([
        'user> hello there',
        'ai>   hi! how can i help?',
        'user> can you summarise this file?',
        'ai>   sure — paste the content',
        'user> (pasted content...)'
      ])
      .WithBlock(TBlock.Default
                  .WithBorders(BordersAll)
                  .WithTitle(' messages '))
      .WithHighlightSymbol('> ')
      .WithHighlightStyle(TStyle.Default.WithBg(RgbColor(40, 40, 60)).WithFg(clCyan).WithModifier([mbBold]));
    Messages.RenderStateful(MessagesArea, Curr, MsgState);

    // Input box — bordered, blank inside.
    InputBlock := TBlock.Default
                    .WithBorders(BordersAll)
                    .WithTitle(' input ')
                    .WithBorderStyle(TStyle.Default.WithFg(clDarkGray));
    InputBlock.Render(InputArea, Curr);
    Curr.SetString(InputArea.X + 2, InputArea.Y + 1,
                   '> _',
                   TStyle.Default.WithFg(clWhite));

    // Status bar — gray, left aligned.
    Hint := TParagraph.FromString(' Tab next  Enter send  Ctrl-c quit ')
              .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
    Hint.Render(StatusArea, Curr);

    Prev.Diff(Curr, Patches);
    Backend.DrawPatches(Patches);
    Backend.Flush;

    Sleep(800);

    Backend.LeaveAlternate;
    Backend.ShowCursor;
    Backend.Flush;
  finally
    Curr.Free;
    Prev.Free;
    Backend.Free;
  end;
end.
