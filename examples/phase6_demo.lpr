program phase6_demo;

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
  ftui_grid,
  ftui_input,
  ftui_scrollview,
  ftui_calendar,
  ftui_progress_group,
  ftui_image;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Theme: TTheme;
  Spinner: TSpinner;
  InputState: TInputState;
  CalState: TCalendarState;
  ScrollState: TScrollViewState;
  Tick: Integer;

procedure RenderFrame;
var
  G: TGridResult;
  SV: TScrollView;
  Cal: TCalendar;
  Inp: TInput;
  PG: TProgressGroup;
  Img: TImage;
  ImgData: TImageData;
  I, X, Y: Integer;
begin
  Frame := Term.BeginFrame;
  Frame.Buffer.SetStyle(Frame.Area, Theme.Bg);

  // 2x3 grid layout
  G := Grid(Frame.Area,
    [Fixed(3), Flex(1), Fixed(1)],
    [Flex(1), Fixed(24), Flex(1)]
  );

  // Top-left: Input field
  Inp := TInput.Default
    .WithPlaceholder('Type something...')
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Input ')
      .WithBorderStyle(Theme.BorderFocused))
    .WithStyle(Theme.Fg);
  Inp.RenderStateful(G.Cell(0, 0), Frame.Buffer, InputState);

  // Top-center: Spinner + info
  TParagraph.FromString(
    Format('%s Phase 6 Demo', [Spinner.Frame(Tick)])
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Info ')
    .WithBorderStyle(Theme.Border))
  .WithStyle(Theme.Fg)
  .Render(G.Cell(0, 1), Frame.Buffer);

  // Top-right: Image (half-block)
  ImgData := TImageData.Create(20, 10);
  for Y := 0 to 9 do
    for X := 0 to 19 do
      ImgData.SetPixel(X, Y,
        Byte((X * 12 + Tick * 3) mod 256),
        Byte((Y * 25) mod 256),
        Byte(128));
  Img := TImage.Create(ImgData).WithProtocol(ipHalfBlock);
  Img.Render(G.Cell(0, 2), Frame.Buffer);

  // Middle-left: ScrollView with progress group
  SV := TScrollView.Default
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Progress ')
      .WithBorderStyle(Theme.Border));
  ScrollState.ContentHeight := 8;
  SV.RenderFrame(G.Cell(1, 0), Frame.Buffer, ScrollState);
  PG := TProgressGroup.Create([
    TProgressItem.Make('Build  ', (Tick mod 100) / 100.0),
    TProgressItem.Make('Test   ', ((Tick + 30) mod 100) / 100.0),
    TProgressItem.Make('Deploy ', ((Tick + 60) mod 100) / 100.0),
    TProgressItem.Make('Verify ', ((Tick + 80) mod 100) / 100.0)
  ]).WithShowPercent(True);
  PG.Render(SV.ContentArea(G.Cell(1, 0)), Frame.Buffer);

  // Middle-center: Calendar
  Cal := TCalendar.Default
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Calendar ')
      .WithBorderStyle(Theme.Border))
    .WithSelectedStyle(Theme.Primary);
  Cal.RenderStateful(G.Cell(1, 1), Frame.Buffer, CalState);

  // Middle-right: Keys help
  TParagraph.FromString(
    'Keys:' + #10 +
    '  Tab - switch focus' + #10 +
    '  h/l - prev/next month' + #10 +
    '  j/k - prev/next day' + #10 +
    '  PgUp/Dn - scroll' + #10 +
    '  q - quit'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Help ')
    .WithBorderStyle(Theme.Border))
  .WithStyle(Theme.Fg)
  .Render(G.Cell(1, 2), Frame.Buffer);

  // Bottom row: status
  TParagraph.FromString(
    Format(' Grid(3x3) | Input: "%s" | Cal: %d/%d/%d | Scroll: %d | Tick: %d ',
      [InputState.Text, CalState.Year, CalState.Month, CalState.SelectedDay,
       ScrollState.OffsetY, Tick])
  ).WithStyle(Theme.StatusBar)
  .Render(G.Cell(2, 0), Frame.Buffer);

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('h'): CalState.PrevMonth;
        Ord('l'): CalState.NextMonth;
        Ord('j'): CalState.NextDay;
        Ord('k'): CalState.PrevDay;
        else InputState.InsertChar(Chr(K.Ch));
      end;
    kcBackspace: InputState.DeleteBack;
    kcDelete: InputState.DeleteForward;
    kcLeft: InputState.MoveLeft;
    kcRight: InputState.MoveRight;
    kcHome: InputState.MoveHome;
    kcEnd: InputState.MoveEnd;
    kcPageUp: ScrollState.PageUp(5);
    kcPageDown: ScrollState.PageDown(5);
  else end;
end;

begin
  Term := TTerminal.Create;
  try
    Theme := TTheme.Nord;
    Spinner := TSpinner.Create(skBraille);
    InputState := TInputState.Empty;
    CalState := TCalendarState.Today;
    ScrollState := TScrollViewState.Empty;
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
    Term.Free;
  end;
end.
