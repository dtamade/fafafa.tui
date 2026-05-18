program full_demo;

// fafafa.tui M3 interactive smoke.
//
// Renders a chat-mock-style layout that responds to input:
//   - ↑ / ↓ / k / j   : move selection
//   - Enter           : "select" (records into status bar)
//   - PgUp / PgDn     : page-by-list-height
//   - Home / End      : first / last
//   - Mouse wheel     : scroll selection
//   - q / Esc         : quit
//   - terminal resize : entire frame redraws on the new dimensions
//
// One TTerminal instance owns everything.  The main loop is:
//   while not term.ShouldQuit:
//     paint()
//     ev := term.PollEvent(-1)        # block forever for next event
//     handle(ev)

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

const
  ItemCount = 20;

var
  Term: TTerminal;
  Items: array[0..ItemCount - 1] of AnsiString;
  ListSt: TListState;
  StatusText: AnsiString;
  I: Integer;
  Frame: TFrame;
  Rows: TRectArray;
  TitleArea, BodyArea, HintArea: TRect;
  Title: TParagraph;
  Body: TList;
  Hint: TParagraph;
  PageHeight: Integer;
  Ev: TEvent;

procedure ClampSelection;
begin
  if not ListSt.HasSelection then ListSt.Select(0);
  if ListSt.Selected < 0 then ListSt.Selected := 0;
  if ListSt.Selected > ItemCount - 1 then ListSt.Selected := ItemCount - 1;
end;

procedure SetStatus(const S: AnsiString);
begin
  StatusText := S;
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('k'):           ListSt.Selected := ListSt.Selected - 1;
        Ord('j'):           ListSt.Selected := ListSt.Selected + 1;
        Ord('g'):           ListSt.Selected := 0;
        Ord('G'):           ListSt.Selected := ItemCount - 1;
      end;
    kcUp:       ListSt.Selected := ListSt.Selected - 1;
    kcDown:     ListSt.Selected := ListSt.Selected + 1;
    kcHome:     ListSt.Selected := 0;
    kcEnd:      ListSt.Selected := ItemCount - 1;
    kcPageUp:   ListSt.Selected := ListSt.Selected - PageHeight;
    kcPageDown: ListSt.Selected := ListSt.Selected + PageHeight;
    kcEnter:    SetStatus('selected: ' + Items[ListSt.Selected]);
  else
    // ignore Tab / BackTab / Backspace / Delete / Insert / F-keys —
    // not bound in this demo.
  end;
  ClampSelection;
end;

procedure HandleMouse(const M: TMouseEvent);
begin
  case M.Kind of
    mkScrollUp:   ListSt.Selected := ListSt.Selected - 1;
    mkScrollDown: ListSt.Selected := ListSt.Selected + 1;
    mkDown:   SetStatus(Format('clicked at (%d,%d)', [M.X, M.Y]));
  else
  end;
  ClampSelection;
end;

procedure RenderFrame;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(1)
  ]);
  TitleArea := Rows[0];
  BodyArea  := Rows[1];
  HintArea  := Rows[2];

  Title := TParagraph.FromString(' fafafa.tui — interactive demo ')
            .WithStyle(TStyle.Default.WithBg(clYellow).WithFg(clBlack))
            .WithAlignment(caCenter);
  Title.Render(TitleArea, Frame.Buffer);

  Body := TList.FromStrings(Items)
            .WithBlock(TBlock.Default
                        .WithBorders(BordersAll)
                        .WithTitle(' messages '))
            .WithHighlightSymbol('> ')
            .WithHighlightStyle(TStyle.Default
                                  .WithBg(RgbColor(40, 40, 60))
                                  .WithFg(clCyan)
                                  .WithModifier([mbBold]));
  Body.RenderStateful(BodyArea, Frame.Buffer, ListSt);

  // Page height = inner area height.  Lock it for PgUp/PgDn arithmetic.
  PageHeight := BodyArea.Height - 2;        // -2 for top+bottom border
  if PageHeight < 1 then PageHeight := 1;

  Hint := TParagraph.FromString(' ' + StatusText + '   [↑/↓ k/j move  Enter select  q quit] ')
            .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
  Hint.Render(HintArea, Frame.Buffer);

  Term.EndFrame(Frame);
end;

begin
  for I := 0 to ItemCount - 1 do
    Items[I] := Format('item %2d — content for row #%d', [I + 1, I + 1]);

  ListSt := TListState.Empty;
  ListSt.Select(0);
  StatusText := 'ready';

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then
    begin
      WriteLn('not a tty — full_demo needs an interactive terminal.');
      Halt(1);
    end;

    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      case Ev.Kind of
        evKey:    HandleKey(Ev.Key);
        evMouse:  HandleMouse(Ev.Mouse);
        evResize: ;     // PollEvent already resized buffers; just redraw
        evNone:   ;     // shouldn't happen with -1 timeout
      end;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
