program canvas_overlay_demo;

// tui-design migration acceptance demo.  Proves 4 things:
//
//   1. Moved updates hover/cursor in real time.
//   2. Drag only updates the overlay (preview), not the base.
//   3. Leaving the canvas clears the preview immediately.
//   4. Esc cancels the current session and restores pre-session state.
//
// Interaction:
//   - Move mouse over the canvas: cursor marker follows in real time.
//   - Click and drag: draws a line preview on the overlay only.
//   - Release: commits the line to the base (document).
//   - Move outside canvas: preview clears instantly.
//   - During drag, press Esc: cancels the line, overlay clears,
//     no change to base.
//   - q quits.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_overlay,
  ftui_layout,
  ftui_borders,
  ftui_block,
  ftui_interaction,
  ftui_event,
  ftui_terminal;

const
  CANVAS_CHAR = '.';
  PREVIEW_CHAR = '*';
  COMMIT_CHAR = '#';

var
  Term: TTerminal;
  BaseCanvas: TBuffer;
  Overlay: TOverlayBuffer;
  Capture: TPointerCapture;
  Session: TInteractionSession;
  LastMouseX, LastMouseY: Word;
  DragStartX, DragStartY: Integer;
  CanvasArea: TRect;

procedure InitCanvas;
var X, Y: Integer;
begin
  for Y := CanvasArea.Y to CanvasArea.Y + CanvasArea.Height - 1 do
    for X := CanvasArea.X to CanvasArea.X + CanvasArea.Width - 1 do
      BaseCanvas.SetString(X, Y, CANVAS_CHAR, TStyle.Default.WithFg(clDarkGray));
end;

procedure DrawLinePreview(X0, Y0, X1, Y1: Integer);
var
  DX, DY, Steps, I, X, Y: Integer;
begin
  Overlay.Clear;
  DX := X1 - X0;
  DY := Y1 - Y0;
  Steps := Abs(DX);
  if Abs(DY) > Steps then Steps := Abs(DY);
  if Steps = 0 then Steps := 1;
  for I := 0 to Steps do
  begin
    X := X0 + (DX * I) div Steps;
    Y := Y0 + (DY * I) div Steps;
    Overlay.SetString(X, Y, PREVIEW_CHAR, TStyle.Default.WithFg(clCyan).WithModifier([mbBold]));
  end;
end;

procedure CommitLine(X0, Y0, X1, Y1: Integer);
var
  DX, DY, Steps, I, X, Y: Integer;
begin
  DX := X1 - X0;
  DY := Y1 - Y0;
  Steps := Abs(DX);
  if Abs(DY) > Steps then Steps := Abs(DY);
  if Steps = 0 then Steps := 1;
  for I := 0 to Steps do
  begin
    X := X0 + (DX * I) div Steps;
    Y := Y0 + (DY * I) div Steps;
    BaseCanvas.SetString(X, Y, COMMIT_CHAR, TStyle.Default.WithFg(clGreen).WithModifier([mbBold]));
  end;
end;

procedure RenderFrame;
var
  Frame: TFrame;
  Rows: TRectArray;
  StatusArea: TRect;
  StatusStr: AnsiString;
  X, Y: Integer;
  P, Src: PCell;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [MinConstraint(0), LengthConstraint(1)]);
  CanvasArea := Rows[0];
  StatusArea := Rows[1];

  // Copy base canvas into frame buffer.
  for Y := CanvasArea.Y to CanvasArea.Y + CanvasArea.Height - 1 do
    for X := CanvasArea.X to CanvasArea.X + CanvasArea.Width - 1 do
    begin
      Src := BaseCanvas.CellAt(X, Y);
      P := Frame.Buffer.CellAt(X, Y);
      if (Src <> nil) and (P <> nil) then P^ := Src^;
    end;

  // Merge overlay on top.
  Overlay.MergeInto(BaseCanvas, Frame.Buffer);

  // Status bar.
  if Session.IsActive then
    StatusStr := ' DRAGGING — Esc cancel, release commit '
  else if Capture.Active then
    StatusStr := ' CAPTURED '
  else
    StatusStr := ' Move mouse over canvas | Click+drag to draw line | Esc cancel | q quit ';
  Frame.Buffer.SetStringN(StatusArea.X, StatusArea.Y, StatusStr, StatusArea.Width,
    TStyle.Default.WithFg(clDarkGray));

  // Show cursor position.
  if HitTest(CanvasArea, LastMouseX, LastMouseY) then
    Frame.Buffer.SetStringN(StatusArea.X + StatusArea.Width - 12, StatusArea.Y,
      Format('(%d,%d)', [LastMouseX, LastMouseY]), 12, TStyle.Default.WithFg(clCyan));

  Term.EndFrame(Frame);
end;

procedure HandleMouse(const M: TMouseEvent);
var HC: THoverChange;
begin
  LastMouseX := M.X; LastMouseY := M.Y;
  HC := DetectHoverChange(CanvasArea, Term.PrevMousePos.X, Term.PrevMousePos.Y, M.X, M.Y);

  case M.Kind of
    mkMoved:
      begin
        // Point 1: Moved updates hover/cursor in real time.
        Overlay.Clear;
        if HitTest(CanvasArea, M.X, M.Y) then
          Overlay.SetString(M.X, M.Y, '+', TStyle.Default.WithFg(clYellow))
        else if HC = hcLeft then
          // Point 3: Leaving canvas clears preview immediately.
          Overlay.Clear;
      end;
    mkDown:
      if (M.Button = mbLeft) and HitTest(CanvasArea, M.X, M.Y) then
      begin
        Capture.Acquire(nil, mbLeft);
        Session.Begin_(nil);
        DragStartX := M.X;
        DragStartY := M.Y;
      end;
    mkDrag:
      if Session.IsActive then
        // Point 2: Drag only updates overlay (preview), not base.
        DrawLinePreview(DragStartX, DragStartY, M.X, M.Y);
    mkUp:
      if Session.IsActive then
      begin
        // Commit the line to base.
        CommitLine(DragStartX, DragStartY, M.X, M.Y);
        Session.Commit;
        Capture.Release;
        Overlay.Clear;
      end;
  else
  end;

  LastMouseX := M.X;
  LastMouseY := M.Y;
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc:
      if Session.IsActive then
      begin
        // Point 4: Esc cancels session, restores pre-session state.
        Session.Cancel;
        Capture.Release;
        Overlay.Clear;
      end
      else
        Term.RequestQuit;
    kcChar:
      if K.Ch = Ord('q') then Term.RequestQuit;
  else
  end;
end;

var
  Ev: TEvent;
begin
  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;

    CanvasArea := TRect.Make(0, 0, Term.Area.Width, Term.Area.Height - 1);
    BaseCanvas := TBuffer.CreateEmpty(Term.Area);
    Overlay := TOverlayBuffer.Create(Term.Area);
    Capture.Release;
    Session.State := ssNone;
    DragStartX := 0; DragStartY := 0;

    InitCanvas;

    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
        evMouse: HandleMouse(Ev.Mouse);
        evResize: begin
          CanvasArea := TRect.Make(0, 0, Term.Area.Width, Term.Area.Height - 1);
          BaseCanvas.Resize(Term.Area);
          Overlay.Resize(Term.Area);
          InitCanvas;
        end;
      else
      end;
    end;
  finally
    Overlay.Free;
    BaseCanvas.Free;
    Term.LeaveTui;
    Term.Free;
  end;
end.
