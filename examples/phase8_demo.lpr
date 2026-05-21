program phase8_demo;

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
  ftui_keybind,
  ftui_breadcrumb,
  ftui_timeline,
  ftui_kanban,
  ftui_diffview,
  ftui_notification_center;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Theme: TTheme;
  Spinner: TSpinner;
  KBState: TKanbanState;
  DiffState: TDiffViewState;
  NC: TNotificationCenter;
  NCState: TNotificationCenterState;
  Tick: Integer;

procedure RenderFrame;
var
  Rows, Cols: TRectArray;
  KB: TKanban;
  DV: TDiffView;
  TL: TTimeline;
  BC: TBreadcrumb;
begin
  Frame := Term.BeginFrame;
  Frame.Buffer.SetStyle(Frame.Area, Theme.Bg);

  Rows := V(Frame.Area, [Fixed(1), Flex(1), Fixed(1)]);

  // Top: Breadcrumb
  BC := TBreadcrumb.Create(['Home', 'Projects', 'fafafa.tui', 'Phase 8'])
    .WithSeparator(' > ')
    .WithStyle(Theme.Fg)
    .WithActiveStyle(Theme.Primary)
    .WithSepStyle(Theme.Muted);
  BC.Render(Rows[0], Frame.Buffer);

  // Middle: 3 columns
  Cols := H(Rows[1], [Flex(2), Flex(2), Fixed(20)]);

  // Left: Kanban
  KB := TKanban.Create([
    MakeColumn('Todo', [
      TKanbanCard.Make('Design API').WithTag('P0'),
      TKanbanCard.Make('Write tests'),
      TKanbanCard.Make('Add docs')
    ]),
    MakeColumn('Doing', [
      TKanbanCard.Make('Implement widgets').WithTag('P1')
    ]),
    MakeColumn('Done', [
      TKanbanCard.Make('Setup project'),
      TKanbanCard.Make('Core buffer'),
      TKanbanCard.Make('Layout system')
    ])
  ]).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Kanban ')
    .WithBorderStyle(Theme.Border))
  .WithHeaderStyle(TStyle.Default.WithFg(clCyan).WithModifier([mbBold]))
  .WithActiveCardStyle(Theme.Primary);
  KB.RenderStateful(Cols[0], Frame.Buffer, KBState);

  // Center: DiffView
  DV := TDiffView.FromUnifiedDiff(
    '--- a/main.pas' + #10 +
    '+++ b/main.pas' + #10 +
    '@@ -1,5 +1,6 @@' + #10 +
    ' program main;' + #10 +
    '-uses OldUnit;' + #10 +
    '+uses NewUnit;' + #10 +
    '+uses ExtraUnit;' + #10 +
    ' begin' + #10 +
    '   Run;' + #10 +
    ' end.'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Diff ')
    .WithBorderStyle(Theme.Border));
  DV.RenderStateful(Cols[1], Frame.Buffer, DiffState);

  // Right: Timeline
  TL := TTimeline.Create([
    TTimelineEvent.Make('v0.1', 'Init').WithStyle(TStyle.Default.WithFg(clGreen)),
    TTimelineEvent.Make('v0.5', 'Widgets'),
    TTimelineEvent.Make('v0.8', 'Phase 5'),
    TTimelineEvent.Make('v1.0', 'Release').WithStyle(TStyle.Default.WithFg(clYellow))
  ]).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Timeline ')
    .WithBorderStyle(Theme.Border));
  TL.Render(Cols[2], Frame.Buffer);

  // Bottom: status
  TParagraph.FromString(
    Format(' %s Phase 8 | h/l=kanban col | j/k=card | n=notify | q=quit ', [Spinner.Frame(Tick)])
  ).WithStyle(Theme.StatusBar)
  .Render(Rows[2], Frame.Buffer);

  // Notification center overlay
  NC.RenderStateful(Frame.Area, Frame.Buffer, NCState);

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('h'): KBState.MoveLeft;
        Ord('l'): KBState.MoveRight(3);
        Ord('j'): KBState.MoveDown(5);
        Ord('k'): KBState.MoveUp;
        Ord('n'):
        begin
          NC.Push(TNotification.Make(Format('Event at tick %d', [Tick]), nlInfo));
          NCState.Visible := not NCState.Visible;
        end;
      end;
    kcPageDown: DiffState.ScrollDown(3);
    kcPageUp: DiffState.ScrollUp(3);
  else end;
end;

begin
  Term := TTerminal.Create;
  NC := TNotificationCenter.Create;
  try
    Theme := TTheme.Nord;
    Spinner := TSpinner.Create(skBraille);
    KBState := TKanbanState.Empty;
    DiffState := TDiffViewState.Empty;
    NCState.Visible := False;
    NCState.Selected := 0;
    NCState.ScrollY := 0;
    NC.Width := 35;
    Tick := 0;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(100);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else end;
      Inc(Tick);
    end;
  finally
    Term.LeaveTui;
    NC.Free;
    Term.Free;
  end;
end.
