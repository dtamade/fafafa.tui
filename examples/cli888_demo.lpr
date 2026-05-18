program cli888_demo;

// cli888-faithful TUI demo.  Pixel-perfect reproduction of the real
// cli888 chat interface based on source analysis of:
//   - src/tui/chat/theme/presets.rs (DefaultDark RGB values)
//   - src/tui/chat/theme/symbols.rs (indicators: > ◆ ▸ ●)
//   - src/tui/chat/message/{user,assistant,tool,thinking}.rs
//   - src/tui/chat/layout/{status_bar,bottom_pane,borders}.rs
//   - src/tui/chat/widgets/{input_box,message_list,spinner}.rs
//
// Layout (top to bottom):
//   [messages area]     — flex, direct buffer paint, per-role styling
//   [input box]         — rounded border, dynamic height, placeholder
//   [status row 1]      — CWD left, model right
//   [status row 2]      — hints left, state+spinner right

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

  // cli888 symbols (from theme/symbols.rs).
  SYM_USER    = '>';                           // user indicator
  SYM_AI      = #$E2#$97#$86;                 // ◆
  SYM_TOOL    = #$E2#$96#$B8;                 // ▸
  SYM_SYSTEM  = #$E2#$97#$8F;                 // ●
  SYM_CHECK   = #$E2#$9C#$93;                 // ✓
  SYM_CROSS   = #$E2#$9C#$97;                 // ✗
  SYM_THINK   = #$F0#$9F#$92#$AD;             // 💭

  // Spinner frames (10-frame braille, 80ms interval).
  SPINNER: array[0..9] of AnsiString = (
    #$E2#$A0#$8B, #$E2#$A0#$99, #$E2#$A0#$B9, #$E2#$A0#$B8,
    #$E2#$A0#$BC, #$E2#$A0#$B4, #$E2#$A0#$A6, #$E2#$A0#$A7,
    #$E2#$A0#$87, #$E2#$A0#$8F
  );

  AI_RESPONSES: array[0..4] of AnsiString = (
    'I can help with that! Let me look into the codebase and find what you need.',
    'Here''s what I found: the function is defined in `src/main.pas` at line 42. It takes two parameters and returns an integer result.',
    'Sure, I''ll read that file for you.' + #10 + #10 + '```pascal' + #10 + 'program hello;' + #10 + 'begin' + #10 + '  WriteLn(''hello world'');' + #10 + 'end.' + #10 + '```' + #10 + #10 + 'The file is 4 lines long.',
    #$E8#$BF#$99#$E6#$98#$AF#$E4#$B8#$AD#$E6#$96#$87#$E5#$9B#$9E#$E5#$A4#$8D + ', mixed with English and emoji ' + #$F0#$9F#$98#$80 + '!',
    'Done! Here''s a summary:' + #10 + '  - Modified 3 files' + #10 + '  - Added 42 lines' + #10 + '  - Removed 7 lines' + #10 + '  - All tests passing ' + SYM_CHECK
  );

type
  TMsgRole = (mrUser, mrAI, mrTool, mrSystem, mrThinking);
  TAppState = (asIdle, asThinking, asStreaming, asPalette);

  TMsg = record
    Role: TMsgRole;
    Content: AnsiString;
    ToolName: AnsiString;
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
  ThinkTick: Integer;
  SpinnerTick: Integer;
  ScrollOffset: Integer;
  ResponseIdx: Integer;
  TokenCount: Integer;
  ModelName, CwdPath: AnsiString;

procedure AddMsg(Role: TMsgRole; const Content: AnsiString; const Tool: AnsiString = '');
begin
  if MsgCount >= MAX_MSGS then Exit;
  Msgs[MsgCount].Role := Role;
  Msgs[MsgCount].Content := Content;
  Msgs[MsgCount].ToolName := Tool;
  Msgs[MsgCount].ToolDone := False;
  Inc(MsgCount);
  ScrollOffset := 0;
end;

procedure StartResponse;
begin
  State := asThinking;
  ThinkTick := 0;
  AddMsg(mrThinking, 'Analyzing request...');
end;

procedure AdvanceThinking;
begin
  Inc(ThinkTick);
  Inc(SpinnerTick);
  if ThinkTick >= 30 then
  begin
    // Remove thinking message.
    Dec(MsgCount);
    // Simulate tool call every other response.
    if (ResponseIdx mod 2) = 0 then
    begin
      AddMsg(mrTool, 'Read src/main.pas (4 lines)', 'Read');
      Msgs[MsgCount - 1].ToolDone := True;
    end;
    StreamTarget := AI_RESPONSES[ResponseIdx mod Length(AI_RESPONSES)];
    Inc(ResponseIdx);
    StreamRevealed := 0;
    StreamIdx := MsgCount;
    AddMsg(mrAI, '');
    State := asStreaming;
    Inc(TokenCount, Length(StreamTarget) div 4);
  end;
end;

procedure AdvanceStream;
begin
  Inc(SpinnerTick);
  if StreamRevealed < Length(StreamTarget) then
  begin
    Inc(StreamRevealed);
    Msgs[StreamIdx].Content := Copy(StreamTarget, 1, StreamRevealed);
  end
  else
    State := asIdle;
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
begin
  P := 0; C := 0;
  while (P < Length(S)) and (C < Col) do begin Adv := GraphemeAdvance(S[1], Length(S), P); Inc(P, Adv.ByteLen); Inc(C, Adv.Width); end;
  Result := P;
end;

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

procedure SendMessage;
begin
  if Length(InputBuf) = 0 then Exit;
  AddMsg(mrUser, InputBuf);
  Inc(TokenCount, Length(InputBuf) div 4);
  if InputBuf = '/help' then AddMsg(mrSystem, 'Commands: /help /clear /quit  |  Ctrl+P palette  |  Ctrl+C quit')
  else if InputBuf = '/clear' then MsgCount := 0
  else if InputBuf = '/quit' then Term.RequestQuit
  else StartResponse;
  InputBuf := ''; InputCurCol := 0;
end;

// Render one message line into the buffer at (X, Y) with full width W.
// Returns the number of rows consumed (1 for single-line, more for wrapped AI).
function RenderMessage(Buf: TBuffer; const M: TMsg; X, Y, W: Integer): Integer;
var
  Indicator: AnsiString;
  IndSty, ContentSty, BgSty: TStyle;
  I, ContentStart, SliceStart: Integer;
  Lines: array of AnsiString;
  LineCount_: Integer;
begin
  Result := 0;
  if W <= 4 then Exit;

  case M.Role of
    mrUser: begin
      Indicator := ' ' + SYM_USER + ' ';
      IndSty := Theme.UserLabel;
      ContentSty := Theme.PrimaryText;
      BgSty := TStyle.Default.WithBg(Theme.BgPrimary);
    end;
    mrAI: begin
      Indicator := ' ' + SYM_AI + ' ';
      IndSty := Theme.AiLabel;
      ContentSty := TStyle.Default.WithFg(Theme.FgPrimary);
      BgSty := TStyle.Default.WithBg(Theme.BgAiMsg);
    end;
    mrTool: begin
      Indicator := '  ' + SYM_TOOL + ' ';
      IndSty := Theme.ToolLabel;
      if M.ToolDone then
        ContentSty := TStyle.Default.WithFg(Theme.StatusSuccess)
      else
        ContentSty := TStyle.Default.WithFg(Theme.AccentTool);
      BgSty := TStyle.Default.WithBg(Theme.BgPrimary);
    end;
    mrSystem: begin
      Indicator := ' ' + SYM_SYSTEM + ' ';
      IndSty := Theme.SystemLabel;
      ContentSty := TStyle.Default.WithFg(Theme.AccentBrand);
      BgSty := TStyle.Default.WithBg(Theme.BgSystem);
    end;
    mrThinking: begin
      Indicator := ' ' + SYM_THINK + ' ';
      IndSty := Theme.InfoLabel;
      ContentSty := Theme.MutedText;
      BgSty := TStyle.Default.WithBg(Theme.BgThinking);
    end;
  end;

  // AI messages get a background color block + padding.
  if M.Role = mrAI then
  begin
    // Top padding line.
    Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty);
    Inc(Y);
    Inc(Result);
  end;

  // Paint background for the indicator line.
  Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty);
  // Indicator.
  Buf.SetStringN(X, Y, Indicator, W, IndSty.Patch(BgSty));
  // Content on same line after indicator.
  ContentStart := GraphemeWidth(Indicator);

  // Split content by LF for multi-line messages.
  // Two-pass: count lines, then Copy slices (no char-by-char concat).
  LineCount_ := 1;
  for I := 1 to Length(M.Content) do
    if M.Content[I] = #10 then Inc(LineCount_);
  SetLength(Lines, LineCount_);
  LineCount_ := 0;
  SliceStart := 1;
  for I := 1 to Length(M.Content) do
  begin
    if M.Content[I] = #10 then
    begin
      Lines[LineCount_] := Copy(M.Content, SliceStart, I - SliceStart);
      Inc(LineCount_);
      SliceStart := I + 1;
    end;
  end;
  Lines[LineCount_] := Copy(M.Content, SliceStart, Length(M.Content) - SliceStart + 1);
  Inc(LineCount_);

  // Recalculate ContentStart as the display-column offset for content.
  ContentStart := GraphemeWidth(Indicator);

  // First line on the indicator row.
  if LineCount_ > 0 then
    Buf.SetStringN(X + ContentStart, Y, Lines[0], W - ContentStart, ContentSty.Patch(BgSty));
  Inc(Y);
  Inc(Result);

  // Subsequent lines indented to align under content (3 spaces for AI).
  for I := 1 to LineCount_ - 1 do
  begin
    Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty);
    Buf.SetStringN(X + ContentStart, Y, Lines[I], W - ContentStart, ContentSty.Patch(BgSty));
    Inc(Y);
    Inc(Result);
  end;

  // AI bottom padding.
  if M.Role = mrAI then
  begin
    Buf.SetStyle(TRect.Make(X, Y, W, 1), BgSty);
    Inc(Result);
  end;
end;

procedure RenderFrame;
var
  Frame: TFrame;
  Rows: TRectArray;
  MsgArea, InputArea, Status1Area, Status2Area: TRect;
  InputBlock: TBlock;
  InputInner: TRect;
  I, Y, J, RowsUsed, TotalRows: Integer;
  StatusLeft, StatusRight, HintLeft, StateRight: AnsiString;
  Sp: AnsiString;
  PopupArea: TRect;
  C: TClear;
  PopupBlock: TBlock;
  PopupPara: TParagraph;
begin
  Frame := Term.BeginFrame;

  // Fill entire frame with primary background.
  Frame.Buffer.SetStyle(Frame.Area, TStyle.Default.WithBg(Theme.BgPrimary));

  Rows := VerticalSplit(Frame.Area, [
    MinConstraint(0),
    LengthConstraint(3),
    LengthConstraint(1),
    LengthConstraint(1)
  ]);
  MsgArea     := Rows[0];
  InputArea   := Rows[1];
  Status1Area := Rows[2];
  Status2Area := Rows[3];

  // === Messages area ===
  // Calculate total visual rows needed (for scroll).
  TotalRows := 0;
  for I := 0 to MsgCount - 1 do
  begin
    Inc(TotalRows);  // at least 1 row per message
    if Msgs[I].Role = mrAI then Inc(TotalRows, 2);  // padding
    // Count LF in content for multi-line.
    for Y := 1 to Length(Msgs[I].Content) do
      if Msgs[I].Content[Y] = #10 then Inc(TotalRows);
  end;

  // Render messages bottom-up (newest at bottom of area).
  Y := MsgArea.Y + MsgArea.Height;
  // Walk backwards to find which messages fit.
  I := MsgCount - 1 + ScrollOffset;
  if I >= MsgCount then I := MsgCount - 1;
  while (I >= 0) and (Y > MsgArea.Y) do
  begin
    RowsUsed := 1;
    if Msgs[I].Role = mrAI then Inc(RowsUsed, 2);
    for J := 1 to Length(Msgs[I].Content) do
      if Msgs[I].Content[J] = #10 then Inc(RowsUsed);
    Dec(Y, RowsUsed);
    Dec(I);
  end;
  Inc(I);
  if Y < MsgArea.Y then Y := MsgArea.Y;

  // Now render forward from I.
  while (I < MsgCount) and (Y < MsgArea.Y + MsgArea.Height) do
  begin
    RowsUsed := RenderMessage(Frame.Buffer, Msgs[I], MsgArea.X, Y, MsgArea.Width);
    Inc(Y, RowsUsed);
    Inc(I);
  end;

  // === Input box (rounded border) ===
  InputBlock := TBlock.Default
    .WithBorders(BordersAll)
    .WithBorderSet(BorderSetRounded)
    .WithTitle(' ' + SYM_USER + ' ')
    .WithTitleStyle(Theme.UserLabel)
    .WithStyle(TStyle.Default.WithBg(Theme.BgInput));
  if State = asIdle then
    InputBlock := InputBlock.WithBorderStyle(Theme.InputBorderFocused)
  else
    InputBlock := InputBlock.WithBorderStyle(Theme.InputBorderBlurred);
  InputBlock.Render(InputArea, Frame.Buffer);
  InputInner := InputBlock.Inner(InputArea);

  if Length(InputBuf) = 0 then
    // Placeholder.
    Frame.Buffer.SetStringN(InputInner.X, InputInner.Y, 'Type a message...', InputInner.Width, Theme.MutedText.Patch(TStyle.Default.WithBg(Theme.BgInput)))
  else
    Frame.Buffer.SetStringN(InputInner.X, InputInner.Y, InputBuf, InputInner.Width, Theme.PrimaryText.Patch(TStyle.Default.WithBg(Theme.BgInput)));

  Frame.HasCursor := (State = asIdle);
  Frame.CursorPos.X := InputInner.X + InputCurCol;
  Frame.CursorPos.Y := InputInner.Y;

  // === Status row 1: CWD + model ===
  Frame.Buffer.SetStyle(Status1Area, Theme.StatusBarStyle);
  StatusLeft := ' ' + CwdPath;
  StatusRight := ModelName + ' ';
  Frame.Buffer.SetStringN(Status1Area.X, Status1Area.Y, StatusLeft, Status1Area.Width, Theme.StatusBarStyle);
  Frame.Buffer.SetStringN(
    Status1Area.X + Integer(Status1Area.Width) - Length(StatusRight),
    Status1Area.Y, StatusRight, Length(StatusRight),
    TStyle.Default.WithBg(Theme.BgSecondary).WithFg(Theme.FgPrimary).WithModifier([mbBold]));

  // === Status row 2: hints + state ===
  Frame.Buffer.SetStyle(Status2Area, Theme.StatusBarStyle);
  HintLeft := ' Enter send  /commands  Ctrl+C quit';
  case State of
    asIdle:     StateRight := 'State: Idle ';
    asThinking: begin Sp := SPINNER[SpinnerTick mod 10]; StateRight := Sp + ' Thinking... '; end;
    asStreaming: begin Sp := SPINNER[SpinnerTick mod 10]; StateRight := Sp + ' Streaming '; end;
    asPalette:  StateRight := 'State: Palette ';
  end;
  Frame.Buffer.SetStringN(Status2Area.X, Status2Area.Y, HintLeft, Status2Area.Width, Theme.StatusBarStyle);
  Frame.Buffer.SetStringN(
    Status2Area.X + Integer(Status2Area.Width) - Length(StateRight),
    Status2Area.Y, StateRight, Length(StateRight),
    TStyle.Default.WithBg(Theme.BgSecondary).WithFg(Theme.StatusInfo));

  // === Command palette popup ===
  if State = asPalette then
  begin
    PopupArea := TRect.Make(
      Frame.Area.X + (Frame.Area.Width - 50) div 2,
      Frame.Area.Y + (Frame.Area.Height - 9) div 2, 50, 9);
    C := ClearWidget; C.Render(PopupArea, Frame.Buffer);
    PopupBlock := TBlock.Default.WithBorders(BordersAll)
      .WithBorderSet(BorderSetRounded)
      .WithTitle(' commands ')
      .WithBorderStyle(TStyle.Default.WithFg(Theme.AccentTool).WithModifier([mbBold]))
      .WithStyle(TStyle.Default.WithBg(RgbColor(25, 25, 35)));
    PopupPara := TParagraph.FromString(
      '  /help    ' + #$E2#$80#$94 + ' show help' + #10 +
      '  /clear   ' + #$E2#$80#$94 + ' clear history' + #10 +
      '  /quit    ' + #$E2#$80#$94 + ' exit' + #10 + #10 +
      '  Ctrl+P   ' + #$E2#$80#$94 + ' toggle palette' + #10 +
      '  Esc      ' + #$E2#$80#$94 + ' close')
      .WithBlock(PopupBlock)
      .WithStyle(TStyle.Default.WithFg(Theme.FgPrimary).WithBg(RgbColor(25, 25, 35)));
    PopupPara.Render(PopupArea, Frame.Buffer);
  end;

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if State = asPalette then begin
    if (K.Code = kcEsc) or ((K.Code = kcChar) and (K.Ch = Ord('p')) and (kmCtrl in K.Modifiers)) then State := asIdle;
    Exit;
  end;
  if (K.Code = kcChar) and (K.Ch = Ord('c')) and (kmCtrl in K.Modifiers) then begin Term.RequestQuit; Exit; end;
  if (K.Code = kcChar) and (K.Ch = Ord('p')) and (kmCtrl in K.Modifiers) then begin State := asPalette; Exit; end;
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcEnter: if State = asIdle then SendMessage;
    kcBackspace: if State = asIdle then BackspaceInput;
    kcChar: if (State = asIdle) and (K.Ch >= 32) then InsertInput(K.Ch);
    kcLeft: if InputCurCol > 0 then Dec(InputCurCol);
    kcRight: if InputCurCol < GraphemeWidth(InputBuf) then Inc(InputCurCol);
    kcPageUp: begin Inc(ScrollOffset, 5); end;
    kcPageDown: begin Dec(ScrollOffset, 5); if ScrollOffset < 0 then ScrollOffset := 0; end;
    kcUp: begin Inc(ScrollOffset); end;
    kcDown: begin Dec(ScrollOffset); if ScrollOffset < 0 then ScrollOffset := 0; end;
  else end;
end;

var
  Ev: TEvent;
begin
  Theme := ThemeDefaultDark;
  MsgCount := 0; InputBuf := ''; InputCurCol := 0;
  State := asIdle; ResponseIdx := 0; TokenCount := 0;
  ScrollOffset := 0; ThinkTick := 0; SpinnerTick := 0;
  ModelName := 'claude-opus-4-7';
  CwdPath := '~/projects/fafafa.tui';

  AddMsg(mrSystem, 'Welcome to cli888. Type a message and press Enter.');
  AddMsg(mrSystem, 'Try: /help, /clear, Ctrl+P for command palette.');

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
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
