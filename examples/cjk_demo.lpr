program cjk_demo;

// CJK rendering demo — verifies wide-character alignment in a real terminal.
//
// Shows a Chinese chat interface with:
//   - CJK title bar
//   - Mixed Chinese/English message list
//   - Status bar with Chinese text
//   - Proper column alignment (each CJK char = 2 columns)
//
// Press q or Esc to quit. Arrow keys to navigate.

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
  ftui_event,
  ftui_terminal;

var
  Term: TTerminal;
  ListSt: TListState;
  Frame: TFrame;
  Rows: TRectArray;
  L: TList;
  Title: TParagraph;
  Status: TParagraph;
  MsgBlock: TBlock;
  Inner: TRect;

procedure Paint;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Buffer.Area, [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(1)
  ]);

  // Title bar
  Frame.Buffer.SetStyle(Rows[0], TStyle.Default.WithBg(clBlue).WithModifier([mbBold]));
  Title := TParagraph.FromText(TText.Raw(
    #$E2#$9A#$A1 + ' fafafa.tui ' + #$E4#$B8#$AD#$E6#$96#$87#$E6#$B8#$B2#$E6#$9F#$93#$E6#$BC#$94#$E7#$A4#$BA));
  Title.Render(Rows[0], Frame.Buffer);

  // Message list with block
  MsgBlock := TBlock.Default.WithBorders(BordersAll).WithTitle(
    #$E6#$B6#$88#$E6#$81#$AF#$E5#$88#$97#$E8#$A1#$A8);
  MsgBlock.Render(Rows[1], Frame.Buffer);
  Inner := MsgBlock.Inner(Rows[1]);

  L := TList.FromStrings([
    #$E4#$BD#$A0#$E5#$A5#$BD + ', world!',
    #$E6#$AC#$A2#$E8#$BF#$8E#$E4#$BD#$BF#$E7#$94#$A8 + ' fafafa.tui',
    'Hello, ' + #$E4#$B8#$96#$E7#$95#$8C + '!',
    #$E8#$BF#$99#$E6#$98#$AF#$E4#$B8#$80#$E4#$B8#$AA + ' TUI ' + #$E6#$B8#$B2#$E6#$9F#$93#$E5#$BA#$93,
    'Mixed: ABC' + #$E4#$B8#$AD#$E6#$96#$87 + 'DEF',
    #$E5#$8F#$8C#$E5#$AE#$BD#$E5#$AD#$97#$E7#$AC#$A6#$E5#$AF#$B9#$E9#$BD#$90#$E6#$B5#$8B#$E8#$AF#$95,
    #$E2#$94#$80#$E2#$94#$80#$E2#$94#$80 + ' ' + #$E5#$88#$86#$E9#$9A#$94#$E7#$BA#$BF + ' ' + #$E2#$94#$80#$E2#$94#$80#$E2#$94#$80,
    'Emoji: ' + #$F0#$9F#$8E#$89 + ' ' + #$F0#$9F#$9A#$80 + ' ' + #$F0#$9F#$92#$BB,
    #$E6#$8C#$89 + ' q ' + #$E6#$88#$96 + ' Esc ' + #$E9#$80#$80#$E5#$87#$BA
  ]);
  L := L.WithHighlightSymbol(#$E2#$96#$B6 + ' ');
  L := L.WithHighlightStyle(TStyle.Default.WithFg(clCyan).WithModifier([mbBold]));
  L.RenderStateful(Inner, Frame.Buffer, ListSt);

  // Status bar
  Frame.Buffer.SetStyle(Rows[2], TStyle.Default.WithBg(clDarkGray));
  Status := TParagraph.FromText(TText.Raw(
    #$E9#$80#$89#$E4#$B8#$AD + ': ' + IntToStr(ListSt.Selected) +
    ' | ' + #$E6#$96#$B9#$E5#$90#$91#$E9#$94#$AE#$E5#$AF#$BC#$E8#$88#$AA));
  Status.Render(Rows[2], Frame.Buffer);

  Term.EndFrame(Frame);
end;

procedure HandleEvent(const Ev: TEvent);
begin
  case Ev.Kind of
    evKey:
      case Ev.Key.Code of
        kcUp:   if ListSt.Selected > 0 then ListSt.Select(ListSt.Selected - 1);
        kcDown: if ListSt.Selected < 8 then ListSt.Select(ListSt.Selected + 1);
        else ;
      end;
    evMouse:
      case Ev.Mouse.Kind of
        mkScrollUp:
          if ListSt.Selected > 0 then ListSt.Select(ListSt.Selected - 1);
        mkScrollDown:
          if ListSt.Selected < 8 then ListSt.Select(ListSt.Selected + 1);
        else ;
      end;
    else ;
  end;
end;

var
  Ev: TEvent;
begin
  Term := TTerminal.Create;
  try
    Term.EnterTui;
    ListSt := TListState.Empty;
    ListSt.Select(0);

    Paint;
    while not Term.ShouldQuit do
    begin
      Ev := Term.PollEvent(-1);
      if (Ev.Kind = evKey) and ((Ev.Key.Code = kcEsc) or
         ((Ev.Key.Code = kcChar) and (Ev.Key.Ch = Ord('q')))) then
        Break;
      HandleEvent(Ev);
      Paint;
    end;

    Term.LeaveTui;
  finally
    Term.Free;
  end;
end.
