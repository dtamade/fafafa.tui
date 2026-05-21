program phase4_demo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_layout,
  ftui_layout_dsl,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_event,
  ftui_terminal,
  ftui_theme,
  ftui_anim,
  ftui_split_pane,
  ftui_menu,
  ftui_gauge;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Theme: TTheme;
  ThemeIdx: Integer;
  Spinner: TSpinner;
  Trans: TTransition;
  SplitState: TSplitPaneState;
  MenuState: TMenuState;
  ShowMenu: Boolean;
  Tick: Integer;

procedure RenderFrame;
var
  SP: TSplitPane;
  P1, P2, Div_: TRect;
  M: TMenu;
  G: TGauge;
  InfoText: AnsiString;
  ThemeNames: array[0..3] of AnsiString;
begin
  Frame := Term.BeginFrame;

  ThemeNames[0] := 'Dark';
  ThemeNames[1] := 'Light';
  ThemeNames[2] := 'Nord';
  ThemeNames[3] := 'Dracula';

  // Apply theme background
  Frame.Buffer.SetStyle(Frame.Area, Theme.Bg);

  // Split pane divides the screen
  SP := TSplitPane.Horizontal
    .WithDividerStyle(Theme.Border)
    .WithMinSize1(15).WithMinSize2(15);

  if not SP.Split(Frame.Area, SplitState, P1, P2, Div_) then
  begin
    Term.EndFrame(Frame);
    Exit;
  end;
  SP.RenderDivider(Div_, Frame.Buffer);

  // Left pane: info + animation
  TParagraph.FromString(
    Format('%s Theme: %s', [Spinner.Frame(Tick), ThemeNames[ThemeIdx]]) + #10 + #10 +
    Format('Transition: %.1f%%', [Trans.Value * 100]) + #10 +
    Format('Split ratio: %.0f%%', [SplitState.Ratio * 100]) + #10 + #10 +
    'Keys:' + #10 +
    '  t - cycle theme' + #10 +
    '  m - toggle menu' + #10 +
    '  Space - restart anim' + #10 +
    '  Left/Right - resize' + #10 +
    '  q - quit'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Phase 4 ')
    .WithBorderStyle(Theme.BorderFocused))
  .WithStyle(Theme.Fg)
  .Render(P1, Frame.Buffer);

  // Right pane: gauge showing transition + menu
  InfoText := 'Animation progress:';
  TParagraph.FromString(InfoText)
    .WithStyle(Theme.Fg)
    .Render(TRect.Make(P2.X + 1, P2.Y + 1, P2.Width - 2, 1), Frame.Buffer);

  G := TGauge.Default
    .WithRatio(Trans.Value)
    .WithLabel(Format('%.0f%%', [Trans.Value * 100]))
    .WithFilledStyle(Theme.Primary)
    .WithEmptyStyle(Theme.Muted);
  G.Render(TRect.Make(P2.X + 1, P2.Y + 3, P2.Width - 2, 1), Frame.Buffer);

  // Menu overlay
  if ShowMenu then
  begin
    M := TMenu.Create([
      TMenuItem.Action('New File').WithShortcut('Ctrl+N'),
      TMenuItem.Action('Open').WithShortcut('Ctrl+O'),
      TMenuItem.Action('Save').WithShortcut('Ctrl+S'),
      TMenuItem.Separator,
      TMenuItem.Action('Settings'),
      TMenuItem.Separator,
      TMenuItem.Action('Quit').WithShortcut('Ctrl+Q')
    ]).WithWidth(25)
    .WithStyle(Theme.Bg)
    .WithHighlightStyle(Theme.Highlight);
    M.RenderStateful(TRect.Make(P2.X + 2, P2.Y + 5, 25, 10), Frame.Buffer, MenuState);
  end;

  Term.EndFrame(Frame);
end;

procedure CycleTheme;
begin
  ThemeIdx := (ThemeIdx + 1) mod 4;
  case ThemeIdx of
    0: Theme := TTheme.Dark;
    1: Theme := TTheme.Light;
    2: Theme := TTheme.Nord;
    3: Theme := TTheme.Dracula;
  end;
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if ShowMenu then
  begin
    case K.Code of
      kcUp: TMenu.Create([
        TMenuItem.Action('New File'),
        TMenuItem.Action('Open'),
        TMenuItem.Action('Save'),
        TMenuItem.Separator,
        TMenuItem.Action('Settings'),
        TMenuItem.Separator,
        TMenuItem.Action('Quit')
      ]).MoveUp(MenuState);
      kcDown: TMenu.Create([
        TMenuItem.Action('New File'),
        TMenuItem.Action('Open'),
        TMenuItem.Action('Save'),
        TMenuItem.Separator,
        TMenuItem.Action('Settings'),
        TMenuItem.Separator,
        TMenuItem.Action('Quit')
      ]).MoveDown(MenuState);
      kcEsc, kcEnter: ShowMenu := False;
      kcChar: if K.Ch = Ord('m') then ShowMenu := False;
    else end;
    Exit;
  end;

  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('t'): CycleTheme;
        Ord('m'): begin ShowMenu := True; MenuState := TMenuState.Default; end;
        Ord(' '): Trans.Reset;
      end;
    kcLeft:
      if SplitState.Ratio > 0.1 then
        SplitState.Ratio := SplitState.Ratio - 0.05;
    kcRight:
      if SplitState.Ratio < 0.9 then
        SplitState.Ratio := SplitState.Ratio + 0.05;
  else end;
end;

begin
  Term := TTerminal.Create;
  try
    Theme := TTheme.Dark;
    ThemeIdx := 0;
    Spinner := TSpinner.Create(skBraille);
    Trans := TTransition.Create(0.0, 1.0, 3000);
    SplitState := TSplitPaneState.Default;
    MenuState := TMenuState.Default;
    ShowMenu := False;
    Tick := 0;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      Trans.Advance(100);
      RenderFrame;
      Ev := Term.PollEvent(100);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else end;
      Inc(Tick);
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
