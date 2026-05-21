program multi_screen_demo;

{$mode objfpc}{$H+}

uses
  ftui_app,
  ftui_screen,
  ftui_event,
  ftui_terminal,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_buffer,
  ftui_block,
  ftui_borders,
  ftui_layout,
  ftui_paragraph,
  ftui_table,
  ftui_list;

type
  TMultiScreenApp = class(TApp)
  private
    FStack: TScreenStack;
  protected
    procedure OnInit; override;
    procedure OnDestroy; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
    function IsQuitEvent(const Ev: TEvent): Boolean; override;
  end;

  TMenuScreen = class(TScreen)
  private
    FSelected: Integer;
  public
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

  TDetailScreen = class(TScreen)
  private
    FTitle: AnsiString;
    FContent: AnsiString;
  public
    constructor Create(const ATitle, AContent: AnsiString);
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

  TConfirmScreen = class(TScreen)
  private
    FYesSelected: Boolean;
  public
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

const
  ITEMS: array[0..3] of AnsiString = (
    'About fafafa.tui',
    'Architecture',
    'Performance',
    'Quit'
  );

  DETAILS: array[0..2] of AnsiString = (
    'fafafa.tui is a FreePascal TUI framework inspired by ratatui.'#10+
    'It uses immediate mode rendering with double-buffer diff.'#10+
    'Zero GC, zero allocation in the hot path, 2-second compile.',

    'Core: packed record cells, array-based buffer, ANSI backend.'#10+
    'Layout: constraint solver (Length/Min/Max/Percentage/Fill).'#10+
    'Input: full mouse protocol, Kitty keyboard, SIGWINCH.',

    'bench_diff: 919 us (target < 1000 us)'#10+
    'bench_layout: 0.43 us (target < 5 us)'#10+
    'bench_render: 121 us (target < 1000 us)'#10+
    'bench_mouse: 13 us (target < 500 us)'
  );

{ TMultiScreenApp }

procedure TMultiScreenApp.OnInit;
begin
  FStack := TScreenStack.Create;
  FStack.Push(TMenuScreen.Create);
end;

procedure TMultiScreenApp.OnDestroy;
begin
  FStack.Free;
end;

procedure TMultiScreenApp.Render(var Frame: TFrame);
begin
  FStack.Render(Frame.Area, Frame.Buffer);
end;

procedure TMultiScreenApp.HandleEvent(const Ev: TEvent);
begin
  FStack.HandleEvent(Ev);
  if FStack.QuitRequested then Quit;
end;

function TMultiScreenApp.IsQuitEvent(const Ev: TEvent): Boolean;
begin
  Result := False;
end;

{ TMenuScreen }

procedure TMenuScreen.Render(const Area: TRect; Buf: TBuffer);
var
  I, Y: Integer;
  Sty: TStyle;
  Inner: TRect;
begin
  TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Menu (Up/Down/Enter) ')
    .Render(Area, Buf);
  Inner := TRect.Make(Area.X + 2, Area.Y + 2, Area.Width - 4, Area.Height - 4);

  Y := Inner.Y;
  for I := 0 to High(ITEMS) do
  begin
    if Y >= Inner.Y + Inner.Height then Break;
    if I = FSelected then
      Sty := TStyle.Default.WithModifier([mbReversed])
    else
      Sty := TStyle.Default;
    Buf.SetStringN(Inner.X, Y, '  ' + ITEMS[I], Inner.Width, Sty);
    Inc(Y);
  end;

  if Y + 2 < Inner.Y + Inner.Height then
    Buf.SetStringN(Inner.X, Inner.Y + Inner.Height - 1,
      'Esc=Quit  Enter=Select', Inner.Width, TStyle.Default.WithFg(clDarkGray));
end;

procedure TMenuScreen.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcUp: if FSelected > 0 then Dec(FSelected);
    kcDown: if FSelected < High(ITEMS) then Inc(FSelected);
    kcEnter:
      if FSelected = 3 then
        Stack.Push(TConfirmScreen.Create)
      else
        Stack.Push(TDetailScreen.Create(ITEMS[FSelected], DETAILS[FSelected]));
    kcEsc:
      Stack.QuitRequested := True;
  end;
end;

{ TDetailScreen }

constructor TDetailScreen.Create(const ATitle, AContent: AnsiString);
begin
  inherited Create;
  FTitle := ATitle;
  FContent := AContent;
end;

procedure TDetailScreen.Render(const Area: TRect; Buf: TBuffer);
begin
  TParagraph.FromString(FContent)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' ' + FTitle + ' '))
    .Render(Area, Buf);
  Buf.SetStringN(Area.X + 2, Area.Y + Area.Height - 2,
    'Esc/Backspace = Back', Area.Width - 4, TStyle.Default.WithFg(clDarkGray));
end;

procedure TDetailScreen.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcEsc, kcBackspace:
    begin
      Stack.Pop.Free;
    end;
  end;
end;

{ TConfirmScreen }

procedure TConfirmScreen.Render(const Area: TRect; Buf: TBuffer);
var
  DlgW, DlgH, DlgX, DlgY: Integer;
  DlgArea: TRect;
  YesSty, NoSty: TStyle;
begin
  DlgW := 30;
  DlgH := 7;
  DlgX := Area.X + (Area.Width - DlgW) div 2;
  DlgY := Area.Y + (Area.Height - DlgH) div 2;
  DlgArea := TRect.Make(DlgX, DlgY, DlgW, DlgH);

  Buf.SetStyle(DlgArea, TStyle.Default);
  TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Quit? ')
    .Render(DlgArea, Buf);

  Buf.SetStringN(DlgX + 2, DlgY + 2, 'Are you sure?', DlgW - 4, TStyle.Default);

  if FYesSelected then
  begin
    YesSty := TStyle.Default.WithModifier([mbReversed]);
    NoSty := TStyle.Default;
  end
  else
  begin
    YesSty := TStyle.Default;
    NoSty := TStyle.Default.WithModifier([mbReversed]);
  end;

  Buf.SetStringN(DlgX + 5, DlgY + 4, ' Yes ', 5, YesSty);
  Buf.SetStringN(DlgX + 15, DlgY + 4, ' No ', 4, NoSty);
end;

procedure TConfirmScreen.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcLeft, kcRight:
      FYesSelected := not FYesSelected;
    kcEnter:
      if FYesSelected then
        Stack.QuitRequested := True
      else
        Stack.Pop.Free;
    kcEsc:
      Stack.Pop.Free;
  end;
end;

var App: TMultiScreenApp;
begin
  App := TMultiScreenApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
