program popup_demo;

// Popup / overlay demo: a background List with a centered modal
// dialog that appears on Enter and dismisses on Esc/Enter.
//
// Proves: Clear widget erasing underlying content, layered rendering
// (background draws first, popup draws on top), centered Rect
// computation, focus trapping in modal state.

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
  ftui_clear,
  ftui_event,
  ftui_terminal;

const
  ITEM_COUNT = 15;

var
  Term: TTerminal;
  Items: array[0..ITEM_COUNT - 1] of AnsiString;
  ListSt: TListState;
  ShowPopup: Boolean;
  PopupMsg: AnsiString;
  Frame: TFrame;
  Ev: TEvent;
  I: Integer;

function CenteredRect(Outer: TRect; W, H: Word): TRect;
var
  X, Y: Integer;
begin
  X := Outer.X + (Outer.Width - W) div 2;
  Y := Outer.Y + (Outer.Height - H) div 2;
  if X < Outer.X then X := Outer.X;
  if Y < Outer.Y then Y := Outer.Y;
  Result := TRect.Make(X, Y, W, H);
end;

procedure RenderFrame;
var
  Rows: TRectArray;
  TitleArea, BodyArea, HintArea: TRect;
  Title, Hint: TParagraph;
  Body: TList;
  PopupArea: TRect;
  PopupBlock: TBlock;
  PopupContent: TParagraph;
  C: TClear;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1), MinConstraint(0), LengthConstraint(1)
  ]);
  TitleArea := Rows[0];
  BodyArea  := Rows[1];
  HintArea  := Rows[2];

  Title := TParagraph.FromString(' popup demo ')
            .WithStyle(TStyle.Default.WithBg(clYellow).WithFg(clBlack))
            .WithAlignment(caCenter);
  Title.Render(TitleArea, Frame.Buffer);

  Body := TList.FromStrings(Items)
            .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' items '))
            .WithHighlightSymbol('> ')
            .WithHighlightStyle(TStyle.Default.WithBg(RgbColor(40, 40, 60)).WithFg(clCyan).WithModifier([mbBold]));
  Body.RenderStateful(BodyArea, Frame.Buffer, ListSt);

  Hint := TParagraph.FromString(' Enter open popup  ↑↓ navigate  q quit ')
            .WithStyle(TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
  Hint.Render(HintArea, Frame.Buffer);

  // Popup overlay.
  if ShowPopup then
  begin
    PopupArea := CenteredRect(Frame.Area, 40, 7);

    // Clear the area underneath so the popup doesn't blend with the list.
    C := ClearWidget;
    C.Render(PopupArea, Frame.Buffer);

    PopupBlock := TBlock.Default
                    .WithBorders(BordersAll)
                    .WithTitle(' info ')
                    .WithBorderStyle(TStyle.Default.WithFg(clYellow).WithModifier([mbBold]))
                    .WithStyle(TStyle.Default.WithBg(RgbColor(20, 20, 40)));
    PopupContent := TParagraph.FromString(PopupMsg)
                      .WithBlock(PopupBlock)
                      .WithAlignment(caCenter)
                      .WithStyle(TStyle.Default.WithFg(clWhite).WithBg(RgbColor(20, 20, 40)));
    PopupContent.Render(PopupArea, Frame.Buffer);
  end;

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if ShowPopup then
  begin
    case K.Code of
      kcEsc, kcEnter: ShowPopup := False;
    else
    end;
    Exit;
  end;

  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('j'): Inc(ListSt.Selected);
        Ord('k'): Dec(ListSt.Selected);
      end;
    kcUp:    Dec(ListSt.Selected);
    kcDown:  Inc(ListSt.Selected);
    kcEnter:
      begin
        PopupMsg := 'You selected:' + #10 + #10 + '  ' + Items[ListSt.Selected] + #10 + #10 + 'Press Enter or Esc to close.';
        ShowPopup := True;
      end;
  else
  end;
  if ListSt.Selected < 0 then ListSt.Selected := 0;
  if ListSt.Selected >= ITEM_COUNT then ListSt.Selected := ITEM_COUNT - 1;
end;

begin
  for I := 0 to ITEM_COUNT - 1 do
    Items[I] := Format('Item #%d — double click or press Enter', [I + 1]);
  ListSt := TListState.Empty;
  ListSt.Select(0);
  ShowPopup := False;

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
