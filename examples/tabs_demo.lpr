program tabs_demo;

// Tab bar demo: top row shows tabs rendered with Span styling (no
// Tabs widget needed), switching tabs changes the body content.
//
// Proves: manual Span-based tab rendering (how cli888 actually does
// it), per-tab state isolation, keyboard-driven tab switching (1-4
// number keys or ←/→).

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
  ftui_event,
  ftui_terminal;

const
  TAB_COUNT = 4;

var
  Term: TTerminal;
  ActiveTab: Integer;
  TabNames: array[0..TAB_COUNT - 1] of AnsiString;
  TabContents: array[0..TAB_COUNT - 1] of AnsiString;
  Frame: TFrame;
  Ev: TEvent;

procedure InitTabs;
begin
  TabNames[0] := ' Chat ';
  TabNames[1] := ' Files ';
  TabNames[2] := ' Search ';
  TabNames[3] := ' Settings ';

  TabContents[0] := 'Welcome to the Chat tab.' + #10 + #10 +
    'This is where messages would appear.' + #10 +
    'The streaming_demo shows how real-time' + #10 +
    'text rendering works in practice.';
  TabContents[1] := 'File browser tab.' + #10 + #10 +
    'The split_panels_demo shows a full' + #10 +
    'file browser with preview pane.' + #10 +
    'Tab switching is instant — no reload.';
  TabContents[2] := 'Search tab.' + #10 + #10 +
    'Imagine a search input here with' + #10 +
    'results appearing below as you type.' + #10 +
    'The editor_demo shows text input.';
  TabContents[3] := 'Settings tab.' + #10 + #10 +
    'Configuration options would go here.' + #10 +
    'Theme, keybindings, model selection...' + #10 + #10 +
    'Press 1-4 or ←/→ to switch tabs.' + #10 +
    'Press q to quit.';
end;

procedure RenderTabBar(const Area: TRect; Buf: TBuffer);
var
  I, X: Integer;
  ActiveSty, InactiveSty: TStyle;
  Sty: TStyle;
begin
  // Fill the tab bar background.
  Buf.SetStyle(Area, TStyle.Default.WithBg(clDarkGray));

  ActiveSty := TStyle.Default.WithBg(clBlack).WithFg(clWhite).WithModifier([mbBold]);
  InactiveSty := TStyle.Default.WithBg(clDarkGray).WithFg(clGray);

  X := Area.X;
  for I := 0 to TAB_COUNT - 1 do
  begin
    if I = ActiveTab then Sty := ActiveSty else Sty := InactiveSty;
    Buf.SetString(X, Area.Y, TabNames[I], Sty);
    Inc(X, Length(TabNames[I]));
    // Separator.
    if I < TAB_COUNT - 1 then
    begin
      Buf.SetString(X, Area.Y, '|', TStyle.Default.WithBg(clDarkGray).WithFg(clDarkGray));
      Inc(X);
    end;
  end;
end;

procedure RenderFrame;
var
  Rows: TRectArray;
  TabBarArea, BodyArea, HintArea: TRect;
  BodyBlock: TBlock;
  Content: TParagraph;
  Hint: TParagraph;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(1)
  ]);
  TabBarArea := Rows[0];
  BodyArea   := Rows[1];
  HintArea   := Rows[2];

  RenderTabBar(TabBarArea, Frame.Buffer);

  BodyBlock := TBlock.Default
                .WithBorders(BordersAll)
                .WithBorderStyle(TStyle.Default.WithFg(clDarkGray));
  Content := TParagraph.FromString(TabContents[ActiveTab])
              .WithBlock(BodyBlock)
              .WithWrap(WrapTrim)
              .WithStyle(TStyle.Default.WithFg(clWhite));
  Content.Render(BodyArea, Frame.Buffer);

  Hint := TParagraph.FromString(' 1-4 switch tab  ←/→ prev/next  q quit ')
            .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
  Hint.Render(HintArea, Frame.Buffer);

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('1'): ActiveTab := 0;
        Ord('2'): ActiveTab := 1;
        Ord('3'): ActiveTab := 2;
        Ord('4'): ActiveTab := 3;
      end;
    kcLeft:
      if ActiveTab > 0 then Dec(ActiveTab);
    kcRight:
      if ActiveTab < TAB_COUNT - 1 then Inc(ActiveTab);
    kcTab:
      ActiveTab := (ActiveTab + 1) mod TAB_COUNT;
  else
  end;
end;

begin
  InitTabs;
  ActiveTab := 0;

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else
      end;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
