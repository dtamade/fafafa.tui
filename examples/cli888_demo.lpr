program cli888_demo;

// Full cli888-style TUI demo.  Replicates the real cli888 chat
// experience:
//
//   ┌─────────────── title bar ───────────────┐
//   │                                         │
//   │  message history (scrollable)           │
//   │    user> hello                          │
//   │    ai>   streaming response...          │
//   │    user> /help                          │
//   │    ai>   (tool call: Read file.txt)     │
//   │                                         │
//   ├─────────────────────────────────────────┤
//   │  input box (multi-line, Enter sends)    │
//   │  > _                                    │
//   ├─────────────────────────────────────────┤
//   │  status: model | tokens | cost          │
//   └─────────────────────────────────────────┘
//
// Interactions:
//   - Type message + Enter to "send" (adds to history)
//   - AI responds with simulated streaming (char by char)
//   - Ctrl+P opens command palette (popup)
//   - ↑/↓ in input box scrolls message history
//   - PageUp/PageDown scrolls history
//   - Ctrl+C / Esc quits
//   - Resize auto-adapts
//
// This is the "proof of concept" that fafafa.tui can host cli888.

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
  ftui_grapheme,
  ftui_event,
  ftui_terminal;

const
  MAX_MESSAGES = 200;
  AI_RESPONSES: array[0..4] of AnsiString = (
    'I can help with that! Let me think about it for a moment...',
    'Here''s what I found: the function is defined in src/main.pas at line 42.',
    'Sure, I''ll read that file for you.' + #10 + #10 + '```' + #10 + 'program hello;' + #10 + 'begin' + #10 + '  WriteLn(''hello world'');' + #10 + 'end.' + #10 + '```',
    #$E8#$BF#$99#$E6#$98#$AF#$E4#$B8#$AD#$E6#$96#$87#$E5#$9B#$9E#$E5#$A4#$8D#$EF#$BC#$8C + ' mixed with English and ' + #$F0#$9F#$98#$80 + ' emoji!',
    'Done! I''ve made the changes. Here''s a summary:' + #10 + '  - Modified 3 files' + #10 + '  - Added 42 lines' + #10 + '  - Removed 7 lines'
  );

type
  TMessageRole = (mrUser, mrAI, mrSystem);

  TMessage = record
    Role: TMessageRole;
    Content: AnsiString;
    IsStreaming: Boolean;
  end;

  TAppState = (asIdle, asStreaming, asCommandPalette);

var
  Term: TTerminal;
  Messages: array[0..MAX_MESSAGES - 1] of TMessage;
  MsgCount: Integer;
  InputBuf: AnsiString;
  InputCurCol: Integer;
  State: TAppState;
  StreamIdx: Integer;
  StreamRevealed: Integer;
  StreamTarget: AnsiString;
  HistoryScroll: Integer;
  ResponseIdx: Integer;
  TokenCount: Integer;

procedure AddMessage(Role: TMessageRole; const Content: AnsiString);
begin
  if MsgCount >= MAX_MESSAGES then Exit;
  Messages[MsgCount].Role := Role;
  Messages[MsgCount].Content := Content;
  Messages[MsgCount].IsStreaming := False;
  Inc(MsgCount);
  HistoryScroll := MsgCount;
end;

procedure StartStreaming;
begin
  StreamTarget := AI_RESPONSES[ResponseIdx mod Length(AI_RESPONSES)];
  Inc(ResponseIdx);
  StreamRevealed := 0;
  StreamIdx := MsgCount;
  if MsgCount < MAX_MESSAGES then
  begin
    Messages[MsgCount].Role := mrAI;
    Messages[MsgCount].Content := '';
    Messages[MsgCount].IsStreaming := True;
    Inc(MsgCount);
  end;
  State := asStreaming;
  Inc(TokenCount, Length(StreamTarget) div 4);
end;

procedure AdvanceStream;
begin
  if StreamRevealed < Length(StreamTarget) then
  begin
    Inc(StreamRevealed);
    Messages[StreamIdx].Content := Copy(StreamTarget, 1, StreamRevealed);
  end
  else
  begin
    Messages[StreamIdx].IsStreaming := False;
    State := asIdle;
  end;
end;

procedure SendMessage;
var
  Msg: AnsiString;
begin
  Msg := InputBuf;
  if Length(Msg) = 0 then Exit;
  AddMessage(mrUser, Msg);
  InputBuf := '';
  InputCurCol := 0;
  Inc(TokenCount, Length(Msg) div 4);

  if Msg = '/help' then
    AddMessage(mrSystem, 'Commands: /help, /clear, /quit')
  else if Msg = '/clear' then
    MsgCount := 0
  else if Msg = '/quit' then
    Term.RequestQuit
  else
    StartStreaming;
end;

function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then
  begin SetLength(Result, 1); Result[1] := AnsiChar(Cp); end
  else if Cp < $800 then
  begin
    SetLength(Result, 2);
    Result[1] := AnsiChar($C0 or (Cp shr 6));
    Result[2] := AnsiChar($80 or (Cp and $3F));
  end
  else if Cp < $10000 then
  begin
    SetLength(Result, 3);
    Result[1] := AnsiChar($E0 or (Cp shr 12));
    Result[2] := AnsiChar($80 or ((Cp shr 6) and $3F));
    Result[3] := AnsiChar($80 or (Cp and $3F));
  end
  else
  begin
    SetLength(Result, 4);
    Result[1] := AnsiChar($F0 or (Cp shr 18));
    Result[2] := AnsiChar($80 or ((Cp shr 12) and $3F));
    Result[3] := AnsiChar($80 or ((Cp shr 6) and $3F));
    Result[4] := AnsiChar($80 or (Cp and $3F));
  end;
end;

function ColToByteOffset(const S: AnsiString; Col: Integer): Integer;
var
  Pos, Cols: Integer;
  Adv: TGraphemeAdvance;
begin
  Pos := 0; Cols := 0;
  while (Pos < Length(S)) and (Cols < Col) do
  begin
    Adv := GraphemeAdvance(S[1], Length(S), Pos);
    Inc(Pos, Adv.ByteLen);
    Inc(Cols, Adv.Width);
  end;
  Result := Pos;
end;

procedure InsertInputChar(Cp: LongWord);
var
  S: AnsiString;
  BytePos: Integer;
begin
  S := Ucs4ToUtf8(Cp);
  BytePos := ColToByteOffset(InputBuf, InputCurCol);
  Insert(S, InputBuf, BytePos + 1);
  Inc(InputCurCol, GraphemeWidth(S));
end;

procedure DeleteInputBackward;
var
  Cols, PrevPos, PrevWidth, BytePos: Integer;
  Adv: TGraphemeAdvance;
begin
  if InputCurCol <= 0 then Exit;
  Cols := 0; PrevPos := 0; PrevWidth := 1;
  BytePos := 0;
  while Cols < InputCurCol do
  begin
    PrevPos := BytePos;
    Adv := GraphemeAdvance(InputBuf[1], Length(InputBuf), BytePos);
    PrevWidth := Adv.Width;
    Inc(BytePos, Adv.ByteLen);
    Inc(Cols, Adv.Width);
  end;
  Delete(InputBuf, PrevPos + 1, BytePos - PrevPos);
  Dec(InputCurCol, PrevWidth);
  if InputCurCol < 0 then InputCurCol := 0;
end;

function CenteredRect(Outer: TRect; W, H: Word): TRect;
var
  X, Y: Integer;
begin
  X := Outer.X + (Integer(Outer.Width) - W) div 2;
  Y := Outer.Y + (Integer(Outer.Height) - H) div 2;
  if X < Outer.X then X := Outer.X;
  if Y < Outer.Y then Y := Outer.Y;
  Result := TRect.Make(X, Y, W, H);
end;

procedure RenderFrame;
var
  Frame: TFrame;
  Rows: TRectArray;
  TitleArea, HistArea, InputArea, StatusArea: TRect;
  Title, Status: TParagraph;
  HistBlock, InputBlock: TBlock;
  HistInner, InputInner: TRect;
  I, Y, VisRows, StartMsg: Integer;
  Prefix, Line: AnsiString;
  LineSty, UserSty, AiSty, SysSty, StreamSty: TStyle;
  PopupArea: TRect;
  PopupBlock: TBlock;
  PopupContent: TParagraph;
  C: TClear;
  CostStr: AnsiString;
begin
  Frame := Term.BeginFrame;

  Rows := VerticalSplit(Frame.Area, [
    LengthConstraint(1),
    MinConstraint(0),
    LengthConstraint(3),
    LengthConstraint(1)
  ]);
  TitleArea  := Rows[0];
  HistArea   := Rows[1];
  InputArea  := Rows[2];
  StatusArea := Rows[3];

  // Title bar.
  Title := TParagraph.FromString(' cli888 — AI-powered terminal assistant ')
            .WithStyle(TStyle.Default.WithBg(RgbColor(30, 30, 50)).WithFg(clWhite).WithModifier([mbBold]))
            .WithAlignment(caCenter);
  Title.Render(TitleArea, Frame.Buffer);

  // Message history.
  UserSty := TStyle.Default.WithFg(clCyan);
  AiSty := TStyle.Default.WithFg(clGreen);
  SysSty := TStyle.Default.WithFg(clYellow);
  StreamSty := TStyle.Default.WithFg(clGreen).WithModifier([mbDim]);

  HistBlock := TBlock.Default
                .WithBorders(BordersAll)
                .WithBorderStyle(TStyle.Default.WithFg(RgbColor(60, 60, 80)));
  HistBlock.Render(HistArea, Frame.Buffer);
  HistInner := HistBlock.Inner(HistArea);

  VisRows := HistInner.Height;
  StartMsg := MsgCount - VisRows;
  if StartMsg < 0 then StartMsg := 0;
  // Allow scrolling up.
  if HistoryScroll < MsgCount then
    StartMsg := HistoryScroll - VisRows;
  if StartMsg < 0 then StartMsg := 0;

  Y := 0;
  for I := StartMsg to MsgCount - 1 do
  begin
    if Y >= VisRows then Break;
    case Messages[I].Role of
      mrUser:   begin Prefix := 'you> '; LineSty := UserSty; end;
      mrAI:     begin Prefix := ' ai> '; LineSty := AiSty; end;
      mrSystem: begin Prefix := ' sys> '; LineSty := SysSty; end;
    end;
    if Messages[I].IsStreaming then LineSty := StreamSty;

    Line := Prefix + Messages[I].Content;
    // Truncate to one visual line for simplicity in this demo.
    Frame.Buffer.SetStringN(HistInner.X, HistInner.Y + Y, Line, HistInner.Width, LineSty);
    Inc(Y);
  end;

  // Input box.
  InputBlock := TBlock.Default
                  .WithBorders(BordersAll)
                  .WithTitle(' input ')
                  .WithBorderStyle(TStyle.Default.WithFg(clCyan));
  InputBlock.Render(InputArea, Frame.Buffer);
  InputInner := InputBlock.Inner(InputArea);

  Frame.Buffer.SetString(InputInner.X, InputInner.Y, '> ' + InputBuf,
    TStyle.Default.WithFg(clWhite));

  Frame.HasCursor := True;
  Frame.CursorPos.X := InputInner.X + 2 + InputCurCol;
  Frame.CursorPos.Y := InputInner.Y;

  // Status bar.
  CostStr := Format(' model: claude-opus-4-7 | tokens: %d | cost: $%.4f ',
    [TokenCount, TokenCount * 0.00003]);
  Status := TParagraph.FromString(CostStr)
              .WithStyle(TStyle.Default.WithBg(RgbColor(30, 30, 50)).WithFg(clGray));
  Status.Render(StatusArea, Frame.Buffer);

  // Command palette popup.
  if State = asCommandPalette then
  begin
    PopupArea := CenteredRect(Frame.Area, 50, 10);
    C := ClearWidget;
    C.Render(PopupArea, Frame.Buffer);
    PopupBlock := TBlock.Default
                    .WithBorders(BordersAll)
                    .WithTitle(' command palette ')
                    .WithBorderStyle(TStyle.Default.WithFg(clYellow).WithModifier([mbBold]))
                    .WithStyle(TStyle.Default.WithBg(RgbColor(20, 20, 40)));
    PopupContent := TParagraph.FromString(
      '  /help     — show help' + #10 +
      '  /clear    — clear history' + #10 +
      '  /quit     — exit' + #10 + #10 +
      '  Ctrl+P    — toggle this palette' + #10 +
      '  Esc       — close')
      .WithBlock(PopupBlock)
      .WithStyle(TStyle.Default.WithFg(clWhite).WithBg(RgbColor(20, 20, 40)));
    PopupContent.Render(PopupArea, Frame.Buffer);
  end;

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  // Command palette intercepts.
  if State = asCommandPalette then
  begin
    case K.Code of
      kcEsc: State := asIdle;
      kcChar:
        if (K.Ch = Ord('p')) and (kmCtrl in K.Modifiers) then
          State := asIdle;
    else
    end;
    Exit;
  end;

  // Ctrl+C quits.
  if (K.Code = kcChar) and (K.Ch = Ord('c')) and (kmCtrl in K.Modifiers) then
  begin
    Term.RequestQuit;
    Exit;
  end;

  // Ctrl+P opens command palette.
  if (K.Code = kcChar) and (K.Ch = Ord('p')) and (kmCtrl in K.Modifiers) then
  begin
    State := asCommandPalette;
    Exit;
  end;

  case K.Code of
    kcEsc: Term.RequestQuit;
    kcEnter: SendMessage;
    kcBackspace: DeleteInputBackward;
    kcChar:
      if K.Ch >= 32 then
        InsertInputChar(K.Ch);
    kcLeft:
      if InputCurCol > 0 then Dec(InputCurCol);
    kcRight:
      if InputCurCol < GraphemeWidth(InputBuf) then Inc(InputCurCol);
    kcPageUp:
      begin
        Dec(HistoryScroll, 5);
        if HistoryScroll < 0 then HistoryScroll := 0;
      end;
    kcPageDown:
      begin
        Inc(HistoryScroll, 5);
        if HistoryScroll > MsgCount then HistoryScroll := MsgCount;
      end;
    kcUp:
      begin
        Dec(HistoryScroll);
        if HistoryScroll < 0 then HistoryScroll := 0;
      end;
    kcDown:
      begin
        Inc(HistoryScroll);
        if HistoryScroll > MsgCount then HistoryScroll := MsgCount;
      end;
  else
  end;
end;

var
  Ev: TEvent;

begin
  MsgCount := 0;
  InputBuf := '';
  InputCurCol := 0;
  State := asIdle;
  ResponseIdx := 0;
  TokenCount := 0;
  HistoryScroll := 0;

  AddMessage(mrSystem, 'Welcome to cli888. Type a message and press Enter.');
  AddMessage(mrSystem, 'Try: /help, /clear, Ctrl+P for command palette.');
  HistoryScroll := MsgCount;

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;

    while not Term.ShouldQuit do
    begin
      RenderFrame;

      if State = asStreaming then
      begin
        Ev := Term.PollEvent(15);
        AdvanceStream;
      end
      else
        Ev := Term.PollEvent(-1);

      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
        evMouse:
          case Ev.Mouse.Kind of
            mkScrollUp:   begin Dec(HistoryScroll); if HistoryScroll < 0 then HistoryScroll := 0; end;
            mkScrollDown: begin Inc(HistoryScroll); if HistoryScroll > MsgCount then HistoryScroll := MsgCount; end;
          else
          end;
      else
      end;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
