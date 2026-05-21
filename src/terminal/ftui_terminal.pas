unit ftui_terminal;

// TTerminal — owns the backend, the prev/curr double buffers, the
// input queue, and the termios captured on EnterRawMode.  Frame
// lifecycle:
//
//   F := Term.BeginFrame;
//   ... paint widgets into F.Buffer ...
//   Term.EndFrame(F);   // diffs against prev, flushes, swaps
//
// Event loop:
//
//   while not Term.ShouldQuit do
//   begin
//     ... draw a frame ...
//     case Term.PollEvent(TimeoutMs).Kind of
//       evKey   : ...
//       evMouse : ...
//       evResize: Term.HandleResize(...);   // already updated buffers
//       evNone  : ...    // timeout, no input
//     end;
//   end;
//
// SIGWINCH:
//   The signal handler bumps a global flag; PollEvent picks it up
//   and synthesises an evResize *after* querying the new size and
//   resizing prev/curr.  That keeps the consumer's first redraw
//   from racing with the size change.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  BaseUnix,
  termio,
  ftui_rect,
  ftui_buffer,
  ftui_overlay,
  ftui_event,
  ftui_input_parser,
  ftui_interaction,
  ftui_ansi_backend,
  ftui_termios;

const
  STDIN_FD  = 0;
  STDOUT_FD = 1;

type
  // The "frame in progress" handed to the consumer between
  // BeginFrame and EndFrame.  Just a window into the terminal's
  // current buffer + cursor state.  Fields are public; widgets
  // call Buffer.SetString / Render directly.
  TFrame = record
    Buffer: TBuffer;           // base buffer — write document/UI here
    Overlay: TOverlayBuffer;   // overlay — write preview/cursor here
    Area: TRect;
    HasCursor: Boolean;
    CursorPos: TPosition;
  end;

  TTerminal = class
  private
    FBackend: TAnsiBackend;
    FPrev, FCurr, FMerged: TBuffer;
    FOverlay: TOverlayBuffer;
    FFrame: TFrame;
    FPatches: TDiffEntries;
    FInRawMode: Boolean;
    FSavedTermios: TermIOS;
    FInputQueue: array of Byte;
    FInputLen: Integer;
    FShouldQuit: Boolean;
    FCapture: TPointerCapture;
    FSession: TInteractionSession;
    FPrevMousePos: TPosition;
    FLastMousePos: TPosition;  // staging: updated in PostProcess, promoted to Prev at next PollEvent start
    FHasMouseTracking: Boolean;
    FHasTruecolor: Boolean;
    FHasKittyKeyboard: Boolean;
    function ReadAvailableBytes: Integer;
    procedure CheckSignals(out ResizeOut: TEvent; out HasResize: Boolean);
    procedure ResizeBuffersTo(W, H: Word);
    procedure DetectCapabilities;
  public
    procedure PostProcessEvent(var Ev: TEvent);  // test seam only — not part of consumer contract
    procedure PromoteMousePos;  // test seam only — not part of consumer contract
    constructor Create;
    destructor Destroy; override;

    // Switch into the rendering mode: capture termios, enter raw
    // mode, alt screen, hide cursor, prime buffer to current size.
    // Returns False if stdin / stdout aren't a tty.
    function EnterTui: Boolean;

    // Restore everything: leave alt screen, show cursor, restore
    // termios.  Always safe to call (no-op if not currently in TUI).
    procedure LeaveTui;

    // Frame lifecycle.
    function BeginFrame: TFrame;
    procedure EndFrame(const F: TFrame);

    // Block up to TimeoutMs waiting for a single event.  Negative
    // TimeoutMs blocks forever.  Returns evNone on timeout.
    function PollEvent(TimeoutMs: Integer): TEvent;

    // External request that the next ShouldQuit returns True.
    procedure RequestQuit; inline;
    function  ShouldQuit: Boolean; inline;

    // The "current" rect, updated on resize.
    function Area: TRect;

    // Pointer capture and interaction session (stable contract).
    property Capture: TPointerCapture read FCapture write FCapture;
    property Session: TInteractionSession read FSession write FSession;
    property PrevMousePos: TPosition read FPrevMousePos write FPrevMousePos;

    // Capability detection (stable contract).
    property HasMouseTracking: Boolean read FHasMouseTracking;
    property HasTruecolor: Boolean read FHasTruecolor;
    property HasKittyKeyboard: Boolean read FHasKittyKeyboard;
  end;

implementation

uses
  SysUtils,
  ftui_cell;

// SIGWINCH flag.  Module-global because the signal handler needs C
// linkage and can't capture context.  Single TTerminal at a time is
// the assumed contract — fafafa.tui is process-scoped.
var
  GResizePending: Boolean = False;
  GTermPending: Boolean = False;
  GSigwinchHooked: Boolean = False;
  GSigtermHooked: Boolean = False;
  GSavedSigwinch: SigActionRec;
  GSavedSigterm: SigActionRec;

procedure FtuiSigwinchHandler(Sig: cint); cdecl;
begin
  GResizePending := True;
end;

procedure FtuiSigtermHandler(Sig: cint); cdecl;
begin
  GTermPending := True;
end;

procedure HookSigwinch;
var
  Act: SigActionRec;
begin
  if GSigwinchHooked then Exit;
  FillChar(Act, SizeOf(Act), 0);
  Act.sa_handler := SigActionHandler(@FtuiSigwinchHandler);
  fpSigEmptySet(Act.sa_mask);
  Act.sa_flags := SA_RESTART;
  fpSigAction(SIGWINCH, @Act, @GSavedSigwinch);
  GSigwinchHooked := True;
end;

procedure HookSigterm;
var
  Act: SigActionRec;
begin
  if GSigtermHooked then Exit;
  FillChar(Act, SizeOf(Act), 0);
  Act.sa_handler := SigActionHandler(@FtuiSigtermHandler);
  fpSigEmptySet(Act.sa_mask);
  Act.sa_flags := 0;
  fpSigAction(SIGTERM, @Act, @GSavedSigterm);
  GSigtermHooked := True;
end;

procedure UnhookSigwinch;
begin
  if not GSigwinchHooked then Exit;
  fpSigAction(SIGWINCH, @GSavedSigwinch, nil);
  GSigwinchHooked := False;
end;

procedure UnhookSigterm;
begin
  if not GSigtermHooked then Exit;
  fpSigAction(SIGTERM, @GSavedSigterm, nil);
  GSigtermHooked := False;
end;

{ TTerminal }

constructor TTerminal.Create;
begin
  inherited Create;
  FBackend := nil;
  FPrev := nil;
  FCurr := nil;
  FMerged := nil;
  FOverlay := nil;
  FInRawMode := False;
  FShouldQuit := False;
  FInputLen := 0;
  FCapture.Release;
  FSession.State := ssNone;
  FHasMouseTracking := False;
  FHasTruecolor := False;
  FHasKittyKeyboard := False;
  SetLength(FInputQueue, 256);
end;

destructor TTerminal.Destroy;
begin
  LeaveTui;
  FOverlay.Free;
  FMerged.Free;
  FCurr.Free;
  FPrev.Free;
  FBackend.Free;
  inherited;
end;

function TTerminal.EnterTui: Boolean;
var
  Sz: TTermSize;
begin
  Result := False;
  if FInRawMode then Exit(True);

  if not GetTerminalSize(STDOUT_FD, Sz) then
  begin
    Sz.Cols := 80;
    Sz.Rows := 24;
  end;

  if not IsATerminal(STDOUT_FD) then Exit;
  if not EnterRawMode(STDIN_FD, FSavedTermios) then Exit;
  FInRawMode := True;

  HookSigwinch;
  HookSigterm;

  FBackend := TAnsiBackend.Create(STDOUT_FD);
  FBackend.EnterAlternate;
  FBackend.HideCursor;
  FBackend.ClearScreen;
  FBackend.Flush;

  FPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, Sz.Cols, Sz.Rows));
  FCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, Sz.Cols, Sz.Rows));
  FMerged := TBuffer.CreateEmpty(TRect.Make(0, 0, Sz.Cols, Sz.Rows));
  FOverlay := TOverlayBuffer.Create(TRect.Make(0, 0, Sz.Cols, Sz.Rows));
  DetectCapabilities;
  FHasMouseTracking := True;
  Result := True;
end;

procedure TTerminal.LeaveTui;
begin
  if not FInRawMode then Exit;

  if FBackend <> nil then
  begin
    FBackend.LeaveAlternate;
    FBackend.ShowCursor;
    FBackend.Flush;
    FBackend.Free;
    FBackend := nil;
  end;
  if FOverlay <> nil then begin FOverlay.Free; FOverlay := nil; end;
  if FMerged <> nil then begin FMerged.Free; FMerged := nil; end;
  if FCurr <> nil then begin FCurr.Free; FCurr := nil; end;
  if FPrev <> nil then begin FPrev.Free; FPrev := nil; end;

  LeaveRawMode(STDIN_FD, FSavedTermios);
  UnhookSigwinch;
  UnhookSigterm;
  FInRawMode := False;
end;

function TTerminal.BeginFrame: TFrame;
begin
  FCurr.Reset;
  FOverlay.Clear;
  FFrame.Buffer := FCurr;
  FFrame.Overlay := FOverlay;
  FFrame.Area := FCurr.Area;
  FFrame.HasCursor := False;
  FFrame.CursorPos.X := 0;
  FFrame.CursorPos.Y := 0;
  Result := FFrame;
end;

procedure TTerminal.EndFrame(const F: TFrame);
var
  PatchCount: Integer;
  Tmp: TBuffer;
begin
  // Copy base buffer into merged, then apply overlay on top.
  FMerged.Reset;
  if FCurr.Length_ > 0 then
    Move(FCurr.ContentPtr^, FMerged.ContentPtr^, FCurr.Length_ * SizeOf(TCell));
  FOverlay.MergeInto(FCurr, FMerged);
  PatchCount := FPrev.DiffInto(FMerged, FPatches);
  FBackend.DrawPatchesN(FPatches, PatchCount);
  if F.HasCursor then
  begin
    FBackend.ShowCursor;
    FBackend.MoveTo(F.CursorPos.X, F.CursorPos.Y);
  end
  else
    FBackend.HideCursor;
  FBackend.Flush;

  // Swap prev/curr — next frame paints onto the old prev (cheap),
  // and the now-old curr becomes the reference for the diff.
  Tmp := FPrev;
  FPrev := FCurr;
  FCurr := Tmp;
end;

procedure TTerminal.RequestQuit;
begin
  FShouldQuit := True;
end;

function TTerminal.ShouldQuit: Boolean;
begin
  Result := FShouldQuit;
end;

function TTerminal.Area: TRect;
begin
  if FCurr <> nil then Result := FCurr.Area else Result := TRect.Make(0, 0, 0, 0);
end;

procedure TTerminal.DetectCapabilities;
var CT, TP: AnsiString;
begin
  CT := GetEnvironmentVariable('COLORTERM');
  TP := GetEnvironmentVariable('TERM_PROGRAM');
  FHasTruecolor := (CT = 'truecolor') or (CT = '24bit');
  FHasKittyKeyboard := (Pos('kitty', TP) > 0) or (Pos('WezTerm', TP) > 0) or (Pos('ghostty', TP) > 0);
end;

procedure TTerminal.ResizeBuffersTo(W, H: Word);
begin
  if FPrev <> nil then FPrev.Resize(TRect.Make(0, 0, W, H));
  if FCurr <> nil then FCurr.Resize(TRect.Make(0, 0, W, H));
  if FMerged <> nil then FMerged.Resize(TRect.Make(0, 0, W, H));
  if FOverlay <> nil then FOverlay.Resize(TRect.Make(0, 0, W, H));
  // Force every cell to redraw on the next EndFrame.  Simplest way:
  // dirty FPrev so diff produces patches for everything.
  if FPrev <> nil then FPrev.Reset;
  if FBackend <> nil then FBackend.ResetStyleCache;
end;

procedure TTerminal.CheckSignals(out ResizeOut: TEvent; out HasResize: Boolean);
var
  Sz: TTermSize;
begin
  HasResize := False;
  if GTermPending then
  begin
    GTermPending := False;
    RequestQuit;
  end;
  if not GResizePending then Exit;
  GResizePending := False;
  if not GetTerminalSize(STDOUT_FD, Sz) then Exit;
  ResizeBuffersTo(Sz.Cols, Sz.Rows);
  ResizeOut := ResizeEvent(Sz.Cols, Sz.Rows);
  HasResize := True;
end;

function TTerminal.ReadAvailableBytes: Integer;
var
  Capacity, Got: Integer;
begin
  Result := 0;
  Capacity := Length(FInputQueue) - FInputLen;
  if Capacity < 64 then
  begin
    SetLength(FInputQueue, Length(FInputQueue) * 2);
    Capacity := Length(FInputQueue) - FInputLen;
  end;
  Got := fpRead(STDIN_FD, FInputQueue[FInputLen], Capacity);
  if Got > 0 then
  begin
    Inc(FInputLen, Got);
    Result := Got;
  end;
end;


// Post-process a successfully parsed event: update PrevMousePos,
// handle Esc-cancel-session, auto-release capture on MouseUp.
procedure TTerminal.PromoteMousePos;
begin
  FPrevMousePos := FLastMousePos;
end;

procedure TTerminal.PostProcessEvent(var Ev: TEvent);
begin
  case Ev.Kind of
    evNone, evResize: ;
    evMouse:
      begin
        // Stage current coords into FLastMousePos.  The actual promotion
        // to FPrevMousePos happens at the START of the next PollEvent call.
        // This ensures that when the consumer reads Term.PrevMousePos after
        // PollEvent returns, it sees the PREVIOUS event's coords — not the
        // current one.  Consumer uses PrevMousePos + Event.Mouse.X/Y for
        // DetectHoverChange (enter/leave detection).
        FLastMousePos.X := Ev.Mouse.X;
        FLastMousePos.Y := Ev.Mouse.Y;
        // Auto-release capture on MouseUp.
        if (Ev.Mouse.Kind = mkUp) and FCapture.Active then
        begin
          if FSession.IsActive then FSession.Commit;
          FCapture.Release;
        end;
      end;
    evKey:
      // Esc cancels active session + releases capture.
      if (Ev.Key.Code = kcEsc) and FSession.IsActive then
      begin
        FSession.Cancel;
        FCapture.Release;
      end;
  end;
end;

function TTerminal.PollEvent(TimeoutMs: Integer): TEvent;
var
  Consumed: Integer;
  R: TParseResult;
  HasResize: Boolean;
  Resz: TEvent;
  ParsedBytes: Integer;
begin
  // Promote last mouse coords to PrevMousePos at the start of each poll.
  // This ensures that when the consumer reads PrevMousePos after PollEvent
  // returns, it sees the PREVIOUS event's coords (not the current one).
  FPrevMousePos := FLastMousePos;
  Result := NoneEvent;

  // 1. Drain pending bytes already in the queue first — typing fast
  // produces multiple events per poll.
  if FInputLen > 0 then
  begin
    R := ParseOne(FInputQueue[0], FInputLen, False, Result, Consumed);
    if R = prSuccess then
    begin
      // Shift queue.
      ParsedBytes := Consumed;
      if ParsedBytes < FInputLen then
        Move(FInputQueue[ParsedBytes], FInputQueue[0], FInputLen - ParsedBytes);
      Dec(FInputLen, ParsedBytes);
      PostProcessEvent(Result);
      Exit;
    end
    else if R = prInvalid then
    begin
      // Drop one byte and try again next call.
      Move(FInputQueue[1], FInputQueue[0], FInputLen - 1);
      Dec(FInputLen);
      Exit(NoneEvent);
    end;
    // prNeedMore: fall through to wait for more bytes.
    // Use a short timeout (50ms) so bare ESC resolves quickly,
    // even when the caller passed TimeoutMs = -1 (infinite).
    if not WaitForBytes(STDIN_FD, 50) then
    begin
      // No new bytes within 50ms — treat pending as complete (AtEOF).
      R := ParseOne(FInputQueue[0], FInputLen, True, Result, Consumed);
      if R = prSuccess then
      begin
        ParsedBytes := Consumed;
        if ParsedBytes < FInputLen then
          Move(FInputQueue[ParsedBytes], FInputQueue[0], FInputLen - ParsedBytes);
        Dec(FInputLen, ParsedBytes);
        PostProcessEvent(Result);
        Exit;
      end;
      // Still invalid/needmore — drop and continue.
      if FInputLen > 0 then begin
        Move(FInputQueue[1], FInputQueue[0], FInputLen - 1);
        Dec(FInputLen);
      end;
      Exit(NoneEvent);
    end;
    // Got new bytes — read them and retry parse below.
    if ReadAvailableBytes > 0 then
    begin
      R := ParseOne(FInputQueue[0], FInputLen, False, Result, Consumed);
      if R = prSuccess then
      begin
        ParsedBytes := Consumed;
        if ParsedBytes < FInputLen then
          Move(FInputQueue[ParsedBytes], FInputQueue[0], FInputLen - ParsedBytes);
        Dec(FInputLen, ParsedBytes);
        PostProcessEvent(Result);
        Exit;
      end;
    end;
    Exit(NoneEvent);
  end;

  CheckSignals(Resz, HasResize);
  if HasResize then Exit(Resz);

  // 2. Wait for new bytes (no pending — use caller's timeout).
  if not WaitForBytes(STDIN_FD, TimeoutMs) then
  begin
    CheckSignals(Resz, HasResize);
    if HasResize then Exit(Resz);
    // Timeout with pending bytes (e.g. bare ESC): retry with AtEOF=True
    // so a lone ESC resolves to kcEsc instead of staying as NeedMore.
    if FInputLen > 0 then
    begin
      R := ParseOne(FInputQueue[0], FInputLen, True, Result, Consumed);
      if R = prSuccess then
      begin
        ParsedBytes := Consumed;
        if ParsedBytes < FInputLen then
          Move(FInputQueue[ParsedBytes], FInputQueue[0], FInputLen - ParsedBytes);
        Dec(FInputLen, ParsedBytes);
        PostProcessEvent(Result);
        Exit;
      end;
    end;
    Exit;
  end;

  if ReadAvailableBytes <= 0 then Exit;

  // Try parse again.  If still NeedMore (e.g. partial CSI), report
  // none and let the next poll round it out.
  R := ParseOne(FInputQueue[0], FInputLen, False, Result, Consumed);
  if R = prSuccess then
  begin
    ParsedBytes := Consumed;
    if ParsedBytes < FInputLen then
      Move(FInputQueue[ParsedBytes], FInputQueue[0], FInputLen - ParsedBytes);
    Dec(FInputLen, ParsedBytes);
    PostProcessEvent(Result);
    Exit;
  end
  else if R = prInvalid then
  begin
    Move(FInputQueue[1], FInputQueue[0], FInputLen - 1);
    Dec(FInputLen);
    Exit(NoneEvent);
  end;

  Result := NoneEvent;
end;

end.
