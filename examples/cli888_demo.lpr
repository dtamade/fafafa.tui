program cli888_demo;

// cli888-faithful TUI demo — bottom-pane architecture.
//
// Layout matches cli888 exactly:
//
//   ┌─ terminal ──────────────────────────────┐
//   │                                         │
//   │  Messages area (flex height)            │
//   │   > user message                        │
//   │   ◆ ai response                         │
//   │   ▸ tool call                           │
//   │                                         │
//   ╭─────────────────────────────────────────╮  <- bottom pane top border
//   │ [host: tool status / slash menu]        │  <- host surface (0-8 lines)
//   ├─────────────────────────────────────────┤  <- separator
//   │ > input text_                           │  <- input surface (1-4 lines)
//   ├─────────────────────────────────────────┤  <- separator
//   │ ~/projects/fafafa.tui   claude-opus-4-7 │  <- status surface line 1
//   │ Enter send  /cmds       State: Idle     │  <- status surface line 2
//   ╰─────────────────────────────────────────╯  <- bottom pane bottom border
//
// The bottom pane is a "box" with rounded corners.  Its height is
// dynamic: host surface expands when slash menu / tool status is
// active, input grows with multi-line content.  Messages area
// shrinks to accommodate.

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
  ftui_clear,
  ftui_grapheme,
  ftui_theme,
  ftui_event,
  ftui_terminal;

const
  MAX_MSGS = 300;
  SYM_USER   = '>';
  SYM_AI     = #$E2#$97#$86;       // ◆
  SYM_TOOL   = #$E2#$96#$B8;       // ▸
  SYM_SYSTEM = #$E2#$97#$8F;       // ●
  SYM_CHECK  = #$E2#$9C#$93;       // ✓
  SYM_THINK  = #$F0#$9F#$92#$AD;   // 💭
  PLACEHOLDER = 'Type a message... (/ for commands)';

  SPINNER: array[0..9] of AnsiString = (
    #$E2#$A0#$8B, #$E2#$A0#$99, #$E2#$A0#$B9, #$E2#$A0#$B8,
    #$E2#$A0#$BC, #$E2#$A0#$B4, #$E2#$A0#$A6, #$E2#$A0#$A7,
    #$E2#$A0#$87, #$E2#$A0#$8F);

  SLASH_CMDS: array[0..4, 0..1] of AnsiString = (
    ('help',    'Show available commands'),
    ('clear',   'Clear message history'),
    ('model',   'Switch AI model'),
    ('compact', 'Toggle compact mode'),
    ('quit',    'Exit cli888'));

  AI_RESPONSES: array[0..4] of AnsiString = (
    'I can help with that! Let me look into the codebase.',
    'Here''s what I found: the function is in `src/main.pas` at line 42.',
    'Sure, I''ll read that file.' + #10 + #10 + '```pascal' + #10 + 'program hello;' + #10 + 'begin' + #10 + '  WriteLn(''hello'');' + #10 + 'end.' + #10 + '```',
    #$E8#$BF#$99#$E6#$98#$AF#$E4#$B8#$AD#$E6#$96#$87 + ', with English and ' + #$F0#$9F#$98#$80 + '!',
    'Done! Summary:' + #10 + '  - Modified 3 files' + #10 + '  - Added 42 lines' + #10 + '  - All tests passing ' + SYM_CHECK);

type
  TMsgRole = (mrUser, mrAI, mrTool, mrSystem, mrThinking);
  TAppState = (asIdle, asThinking, asStreaming, asSlashMenu);

  TMsg = record
    Role: TMsgRole;
    Content: AnsiString;
    ToolDone: Boolean;
  end;

var
  Term: TTerminal;
  Theme: TTheme;
  Msgs: array[0..MAX_MSGS - 1] of TMsg;
  MsgCount: Integer;
  InputBuf: AnsiString;
  InputCurCol: Integer;
  State: TAppState;
  StreamIdx, StreamRevealed: Integer;
  StreamTarget: AnsiString;
  ThinkTick, SpinnerTick: Integer;
  ScrollOffset: Integer;
  ResponseIdx, TokenCount: Integer;
  ModelName, CwdPath: AnsiString;
  SlashMenuSel: Integer;
  SlashMenuFilter: AnsiString;
  ToolStatusLine: AnsiString;

// === Helpers ===

procedure AddMsg(Role: TMsgRole; const Content: AnsiString);
begin
  if MsgCount >= MAX_MSGS then Exit;
  Msgs[MsgCount].Role := Role;
  Msgs[MsgCount].Content := Content;
  Msgs[MsgCount].ToolDone := (Role = mrTool);
  Inc(MsgCount);
  ScrollOffset := 0;
end;

function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then begin SetLength(Result, 1); Result[1] := AnsiChar(Cp); end
  else if Cp < $800 then begin SetLength(Result, 2); Result[1] := AnsiChar($C0 or (Cp shr 6)); Result[2] := AnsiChar($80 or (Cp and $3F)); end
  else if Cp < $10000 then begin SetLength(Result, 3); Result[1] := AnsiChar($E0 or (Cp shr 12)); Result[2] := AnsiChar($80 or ((Cp shr 6) and $3F)); Result[3] := AnsiChar($80 or (Cp and $3F)); end
  else begin SetLength(Result, 4); Result[1] := AnsiChar($F0 or (Cp shr 18)); Result[2] := AnsiChar($80 or ((Cp shr 12) and $3F)); Result[3] := AnsiChar($80 or ((Cp shr 6) and $3F)); Result[4] := AnsiChar($80 or (Cp and $3F)); end;
end;

function ColToByteOfs(const S: AnsiString; Col: Integer): Integer;
var P, C: Integer; Adv: TGraphemeAdvance;
begin P := 0; C := 0; while (P < Length(S)) and (C < Col) do begin Adv := GraphemeAdvance(S[1], Length(S), P); Inc(P, Adv.ByteLen); Inc(C, Adv.Width); end; Result := P; end;

procedure InsertInput(Cp: LongWord);
var S: AnsiString; B: Integer;
begin S := Ucs4ToUtf8(Cp); B := ColToByteOfs(InputBuf, InputCurCol); Insert(S, InputBuf, B + 1); Inc(InputCurCol, GraphemeWidth(S)); end;

procedure BackspaceInput;
var C, PP, PW, BP: Integer; Adv: TGraphemeAdvance;
begin
  if InputCurCol <= 0 then Exit;
  C := 0; PP := 0; PW := 1; BP := 0;
  while C < InputCurCol do begin PP := BP; Adv := GraphemeAdvance(InputBuf[1], Length(InputBuf), BP); PW := Adv.Width; Inc(BP, Adv.ByteLen); Inc(C, Adv.Width); end;
  Delete(InputBuf, PP + 1, BP - PP); Dec(InputCurCol, PW);
  if InputCurCol < 0 then InputCurCol := 0;
end;

procedure StartResponse;
begin State := asThinking; ThinkTick := 0; ToolStatusLine := ''; AddMsg(mrThinking, 'Analyzing...'); end;

procedure AdvanceThinking;
begin
  Inc(ThinkTick); Inc(SpinnerTick);
  ToolStatusLine := SPINNER[SpinnerTick mod 10] + ' Thinking...';
  if ThinkTick >= 25 then begin
    Dec(MsgCount);
    if (ResponseIdx mod 2) = 0 then begin
      ToolStatusLine := SPINNER[SpinnerTick mod 10] + ' ' + SYM_TOOL + ' Read src/main.pas';
      AddMsg(mrTool, 'Read src/main.pas ' + SYM_CHECK);
    end;
    StreamTarget := AI_RESPONSES[ResponseIdx mod Length(AI_RESPONSES)];
    Inc(ResponseIdx); StreamRevealed := 0; StreamIdx := MsgCount;
    AddMsg(mrAI, ''); State := asStreaming;
    Inc(TokenCount, Length(StreamTarget) div 4);
    ToolStatusLine := SPINNER[SpinnerTick mod 10] + ' Streaming';
  end;
end;

procedure AdvanceStream;
begin
  Inc(SpinnerTick);
  ToolStatusLine := SPINNER[SpinnerTick mod 10] + ' Streaming';
  if StreamRevealed < Length(StreamTarget) then begin
    Inc(StreamRevealed);
    Msgs[StreamIdx].Content := Copy(StreamTarget, 1, StreamRevealed);
  end else begin State := asIdle; ToolStatusLine := ''; end;
end;

procedure SendMessage;
begin
  if Length(InputBuf) = 0 then Exit;
  AddMsg(mrUser, InputBuf);
  Inc(TokenCount, Length(InputBuf) div 4);
  if InputBuf = '/help' then AddMsg(mrSystem, 'Commands: /help /clear /model /compact /quit')
  else if InputBuf = '/clear' then MsgCount := 0
  else if InputBuf = '/quit' then Term.RequestQuit
  else StartResponse;
  InputBuf := ''; InputCurCol := 0;
end;

// === Rendering ===

procedure RenderSeparator(Buf: TBuffer; X, Y, W: Integer);
var I: Integer;
begin
  Buf.SetStringN(X, Y, BorderLeftT, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  for I := X + 1 to X + W - 2 do
    Buf.SetStringN(I, Y, BorderHorizontal, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  Buf.SetStringN(X + W - 1, Y, BorderRightT, 1, TStyle.Default.WithFg(Theme.BorderNormal));
end;

function RenderMessage(Buf: TBuffer; const M: TMsg; X, Y, W: Integer): Integer;
var
  Indicator: AnsiString;
  IndSty, ContentSty, BgSty: TStyle;
  I, ContentCol, SliceStart, LineCount_: Integer;
  Lines: array of AnsiString;
begin
  Result := 0;
  if W <= 4 then Exit;
  case M.Role of
    mrUser:    begin Indicator := ' ' + SYM_USER + ' '; IndSty := Theme.UserLabel; ContentSty := Theme.PrimaryText; BgSty := TStyle.Default.WithBg(Theme.BgPrimary); end;
    mrAI:      begin Indicator := ' ' + SYM_AI + ' '; IndSty := Theme.AiLabel; ContentSty := TStyle.Default.WithFg(Theme.FgPrimary); BgSty := TStyle.Default.WithBg(Theme.BgAiMsg); end;
    mrTool:    begin Indicator := '  ' + SYM_TOOL + ' '; IndSty := Theme.ToolLabel; ContentSty := TStyle.Default.WithFg(Theme.StatusSuccess); BgSty := TStyle.Default.WithBg(Theme.BgPrimary); end;
    mrSystem:  begin Indicator := ' ' + SYM_SYSTEM + ' '; IndSty := Theme.SystemLabel; ContentSty := TStyle.Default.WithFg(Theme.AccentBrand); BgSty := TStyle.Default.WithBg(Theme.BgSystem); end;
    mrThinking:begin Indicator := ' ' + SYM_THINK + ' '; IndSty := Theme.InfoLabel; ContentSty := Theme.MutedText; BgSty := TStyle.Default.WithBg(Theme.BgThinking); end;
  end;
  // AI top padding.
  if M.Role = mrAI then begin Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty); Inc(Y); Inc(Result); end;
  // Split content.
  LineCount_ := 1;
  for I := 1 to Length(M.Content) do if M.Content[I] = #10 then Inc(LineCount_);
  SetLength(Lines, LineCount_); LineCount_ := 0; SliceStart := 1;
  for I := 1 to Length(M.Content) do
    if M.Content[I] = #10 then begin Lines[LineCount_] := Copy(M.Content, SliceStart, I - SliceStart); Inc(LineCount_); SliceStart := I + 1; end;
  Lines[LineCount_] := Copy(M.Content, SliceStart, Length(M.Content) - SliceStart + 1); Inc(LineCount_);
  ContentCol := GraphemeWidth(Indicator);
  // First line.
  Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty);
  Buf.SetStringN(X, Y, Indicator, W, IndSty.Patch(BgSty));
  if LineCount_ > 0 then Buf.SetStringN(X + ContentCol, Y, Lines[0], W - ContentCol, ContentSty.Patch(BgSty));
  Inc(Y); Inc(Result);
  // Subsequent lines.
  for I := 1 to LineCount_ - 1 do begin
    Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty);
    Buf.SetStringN(X + ContentCol, Y, Lines[I], W - ContentCol, ContentSty.Patch(BgSty));
    Inc(Y); Inc(Result);
  end;
  // AI bottom padding.
  if M.Role = mrAI then begin Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty); Inc(Result); end;
end;

procedure RenderFrame;
var
  Frame: TFrame;
  MsgArea, BottomBox: TRect;
  HostHeight, InputHeight, StatusHeight, SepCount, BottomHeight: Integer;
  InnerX, InnerW, CurY, I, J, Y, RowsUsed: Integer;
  Sp, StatusLeft, StatusRight, HintLeft, StateRight: AnsiString;
begin
  Frame := Term.BeginFrame;
  Frame.Buffer.SetStyle(Frame.Area, TStyle.Default.WithBg(Theme.BgPrimary));

  // Calculate bottom pane height.
  HostHeight := 0;
  if Length(ToolStatusLine) > 0 then HostHeight := 1;
  if State = asSlashMenu then HostHeight := 5;
  InputHeight := 1;
  StatusHeight := 2;
  SepCount := 1 + Ord(HostHeight > 0);  // always input-status sep; host-input sep if host
  BottomHeight := 2 + HostHeight + SepCount + InputHeight + StatusHeight;  // 2 = top+bottom border

  MsgArea := TRect.Make(Frame.Area.X, Frame.Area.Y, Frame.Area.Width, Frame.Area.Height - BottomHeight);
  BottomBox := TRect.Make(Frame.Area.X, Frame.Area.Y + MsgArea.Height, Frame.Area.Width, BottomHeight);

  // === Messages ===
  Y := MsgArea.Y + MsgArea.Height;
  I := MsgCount - 1 + ScrollOffset;
  if I >= MsgCount then I := MsgCount - 1;
  while (I >= 0) and (Y > MsgArea.Y) do begin
    RowsUsed := 1;
    if Msgs[I].Role = mrAI then Inc(RowsUsed, 2);
    for J := 1 to Length(Msgs[I].Content) do if Msgs[I].Content[J] = #10 then Inc(RowsUsed);
    Dec(Y, RowsUsed); Dec(I);
  end;
  Inc(I); if Y < MsgArea.Y then Y := MsgArea.Y;
  while (I < MsgCount) and (Y < MsgArea.Y + MsgArea.Height) do begin
    RowsUsed := RenderMessage(Frame.Buffer, Msgs[I], MsgArea.X, Y, MsgArea.Width);
    Inc(Y, RowsUsed); Inc(I);
  end;
  // Welcome if empty.
  if MsgCount = 0 then begin
    Frame.Buffer.SetString(MsgArea.X + 2, MsgArea.Y + 1, 'Welcome to cli888', Theme.UserLabel);
    Frame.Buffer.SetString(MsgArea.X + 2, MsgArea.Y + 3, 'Type a message and press Enter.', Theme.SecondaryText);
    Frame.Buffer.SetString(MsgArea.X + 2, MsgArea.Y + 4, 'Try / for commands, Ctrl+P for palette.', Theme.SecondaryText);
  end;

  // === Bottom pane box ===
  InnerX := BottomBox.X + 1;
  InnerW := BottomBox.Width - 2;
  CurY := BottomBox.Y;

  // Top border: ╭─────╮
  Frame.Buffer.SetStringN(BottomBox.X, CurY, BorderRoundedTL, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  for I := 1 to Integer(BottomBox.Width) - 2 do
    Frame.Buffer.SetStringN(BottomBox.X + I, CurY, BorderHorizontal, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  Frame.Buffer.SetStringN(BottomBox.X + BottomBox.Width - 1, CurY, BorderRoundedTR, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  Inc(CurY);

  // Host surface (tool status / slash menu).
  if HostHeight > 0 then begin
    // Left/right vertical borders for host rows.
    for I := 0 to HostHeight - 1 do begin
      Frame.Buffer.SetStringN(BottomBox.X, CurY + I, BorderVertical, 1, TStyle.Default.WithFg(Theme.BorderNormal));
      Frame.Buffer.SetStringN(BottomBox.X + BottomBox.Width - 1, CurY + I, BorderVertical, 1, TStyle.Default.WithFg(Theme.BorderNormal));
    end;
    if State = asSlashMenu then begin
      // Render slash menu items.
      for I := 0 to 4 do begin
        if I = SlashMenuSel then
          Sp := ' ' + SYM_TOOL + ' '
        else
          Sp := '   ';
        Frame.Buffer.SetStringN(InnerX, CurY + I, Sp + SLASH_CMDS[I, 0], 14,
          TStyle.Default.WithFg(Theme.AccentTool).WithBg(Theme.BgInput));
        Frame.Buffer.SetStringN(InnerX + 14, CurY + I, SLASH_CMDS[I, 1], InnerW - 14,
          TStyle.Default.WithFg(Theme.FgSecondary).WithBg(Theme.BgInput));
      end;
    end else begin
      // Tool status line.
      Frame.Buffer.SetStringN(InnerX, CurY, ' ' + ToolStatusLine, InnerW,
        TStyle.Default.WithFg(Theme.StatusInfo).WithBg(Theme.BgInput));
    end;
    Inc(CurY, HostHeight);
    RenderSeparator(Frame.Buffer, BottomBox.X, CurY, BottomBox.Width);
    Inc(CurY);
  end;

  // Input surface.
  Frame.Buffer.SetStringN(BottomBox.X, CurY, BorderVertical, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  Frame.Buffer.SetStringN(BottomBox.X + BottomBox.Width - 1, CurY, BorderVertical, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  Frame.Buffer.SetStyle(TRect.Make(InnerX, CurY, InnerW, InputHeight), TStyle.Default.WithBg(Theme.BgInput));
  if Length(InputBuf) = 0 then
    Frame.Buffer.SetStringN(InnerX + 1, CurY, PLACEHOLDER, InnerW - 1, Theme.MutedText.Patch(TStyle.Default.WithBg(Theme.BgInput)))
  else
    Frame.Buffer.SetStringN(InnerX + 1, CurY, InputBuf, InnerW - 1, Theme.PrimaryText.Patch(TStyle.Default.WithBg(Theme.BgInput)));
  Frame.HasCursor := (State = asIdle) or (State = asSlashMenu);
  Frame.CursorPos.X := InnerX + 1 + InputCurCol;
  Frame.CursorPos.Y := CurY;
  Inc(CurY, InputHeight);

  // Separator before status.
  RenderSeparator(Frame.Buffer, BottomBox.X, CurY, BottomBox.Width);
  Inc(CurY);

  // Status surface (2 rows).
  for I := 0 to StatusHeight - 1 do begin
    Frame.Buffer.SetStringN(BottomBox.X, CurY + I, BorderVertical, 1, TStyle.Default.WithFg(Theme.BorderNormal));
    Frame.Buffer.SetStringN(BottomBox.X + BottomBox.Width - 1, CurY + I, BorderVertical, 1, TStyle.Default.WithFg(Theme.BorderNormal));
    Frame.Buffer.SetStyle(TRect.Make(InnerX, CurY + I, InnerW, 1), Theme.StatusBarStyle);
  end;
  // Row 1: CWD + model.
  StatusLeft := ' ' + CwdPath;
  StatusRight := ModelName + ' ';
  Frame.Buffer.SetStringN(InnerX, CurY, StatusLeft, InnerW, Theme.StatusBarStyle);
  Frame.Buffer.SetStringN(InnerX + InnerW - Length(StatusRight), CurY, StatusRight, Length(StatusRight),
    TStyle.Default.WithBg(Theme.BgSecondary).WithFg(Theme.FgPrimary).WithModifier([mbBold]));
  Inc(CurY);
  // Row 2: hints + state.
  HintLeft := ' Enter send  / cmds  Ctrl+C quit';
  case State of
    asIdle:      StateRight := 'Idle ';
    asThinking:  StateRight := SPINNER[SpinnerTick mod 10] + ' Thinking ';
    asStreaming: StateRight := SPINNER[SpinnerTick mod 10] + ' Streaming ';
    asSlashMenu: StateRight := '/ Menu ';
  end;
  Frame.Buffer.SetStringN(InnerX, CurY, HintLeft, InnerW, Theme.StatusBarStyle);
  Frame.Buffer.SetStringN(InnerX + InnerW - Length(StateRight), CurY, StateRight, Length(StateRight),
    TStyle.Default.WithBg(Theme.BgSecondary).WithFg(Theme.StatusInfo));
  Inc(CurY);

  // Bottom border: ╰─────╯
  Frame.Buffer.SetStringN(BottomBox.X, CurY, BorderRoundedBL, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  for I := 1 to Integer(BottomBox.Width) - 2 do
    Frame.Buffer.SetStringN(BottomBox.X + I, CurY, BorderHorizontal, 1, TStyle.Default.WithFg(Theme.BorderNormal));
  Frame.Buffer.SetStringN(BottomBox.X + BottomBox.Width - 1, CurY, BorderRoundedBR, 1, TStyle.Default.WithFg(Theme.BorderNormal));

  Term.EndFrame(Frame);
end;

// === Input handling ===

procedure HandleKey(const K: TKeyEvent);
begin
  if State = asSlashMenu then begin
    case K.Code of
      kcEsc: begin State := asIdle; InputBuf := ''; InputCurCol := 0; end;
      kcUp: if SlashMenuSel > 0 then Dec(SlashMenuSel);
      kcDown: if SlashMenuSel < 4 then Inc(SlashMenuSel);
      kcEnter: begin
        InputBuf := '/' + SLASH_CMDS[SlashMenuSel, 0];
        InputCurCol := GraphemeWidth(InputBuf);
        State := asIdle;
        SendMessage;
      end;
    else end;
    Exit;
  end;
  if (K.Code = kcChar) and (K.Ch = Ord('c')) and (kmCtrl in K.Modifiers) then begin Term.RequestQuit; Exit; end;
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcEnter: if State = asIdle then SendMessage;
    kcBackspace: if State = asIdle then begin
      BackspaceInput;
      if (Length(InputBuf) = 0) and (State = asSlashMenu) then State := asIdle;
    end;
    kcChar: if (State = asIdle) and (K.Ch >= 32) then begin
      InsertInput(K.Ch);
      // Trigger slash menu on '/'.
      if (InputBuf = '/') then begin State := asSlashMenu; SlashMenuSel := 0; end;
    end;
    kcLeft: if InputCurCol > 0 then Dec(InputCurCol);
    kcRight: if InputCurCol < GraphemeWidth(InputBuf) then Inc(InputCurCol);
    kcPageUp: Inc(ScrollOffset, 5);
    kcPageDown: begin Dec(ScrollOffset, 5); if ScrollOffset < 0 then ScrollOffset := 0; end;
    kcUp: Inc(ScrollOffset);
    kcDown: begin Dec(ScrollOffset); if ScrollOffset < 0 then ScrollOffset := 0; end;
  else end;
end;

// === Main ===

var
  Ev: TEvent;
begin
  Theme := ThemeDefaultDark;
  MsgCount := 0; InputBuf := ''; InputCurCol := 0;
  State := asIdle; ResponseIdx := 0; TokenCount := 0;
  ScrollOffset := 0; ThinkTick := 0; SpinnerTick := 0;
  SlashMenuSel := 0; SlashMenuFilter := '';
  ToolStatusLine := '';
  ModelName := 'claude-opus-4-7';
  CwdPath := '~/projects/fafafa.tui';

  AddMsg(mrSystem, 'Welcome to cli888. Type a message and press Enter.');

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do begin
      RenderFrame;
      case State of
        asThinking:  begin Ev := Term.PollEvent(80); AdvanceThinking; end;
        asStreaming: begin Ev := Term.PollEvent(12); AdvanceStream; end;
      else Ev := Term.PollEvent(-1);
      end;
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
        evMouse: case Ev.Mouse.Kind of
          mkScrollUp: Inc(ScrollOffset);
          mkScrollDown: begin Dec(ScrollOffset); if ScrollOffset < 0 then ScrollOffset := 0; end;
        else end;
      else end;
    end;
  finally
    Term.LeaveTui; Term.Free;
  end;
end.
