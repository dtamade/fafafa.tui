program cli888_demo;

// Full cli888-faithful TUI demo.  Matches the real cli888 layout:
//
//   ┌─────────────────────────────────────────┐
//   │  消息区域（Paragraph + Wrap 直接画）     │  自适应高度
//   │   👤 user message                       │  cyan
//   │   🤖 ai response with 3-col indent      │  green/gray
//   │   🔧 tool_name (args...)                │  yellow
//   │   ℹ  system info                        │  magenta
//   ├─────────────────────────────────────────┤
//   │  输入框（Block + 边框 + 焦点色）         │  3 行
//   │  👤 > input text_                       │
//   ├─────────────────────────────────────────┤
//   │  cwd                        model_name  │  状态行 1
//   │  hints                      State: Idle │  状态行 2
//   └─────────────────────────────────────────┘
//
// No title bar — messages start at the top (like real cli888).
// Welcome banner shown when history is empty.

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
  ftui_event,
  ftui_terminal;

const
  MAX_MESSAGES = 300;
  ICON_USER    = #$F0#$9F#$91#$A4;   // 👤
  ICON_AI      = #$F0#$9F#$A4#$96;   // 🤖
  ICON_TOOL    = #$F0#$9F#$94#$A7;   // 🔧
  ICON_INFO    = #$E2#$84#$B9;       // ℹ
  ICON_CHECK   = #$E2#$9C#$93;       // ✓
  ICON_THINK   = #$F0#$9F#$92#$AD;   // 💭

  AI_RESPONSES: array[0..4] of AnsiString = (
    'I can help with that! Let me look into it...',
    'Here''s what I found: the function is defined in `src/main.pas` at line 42. It takes two parameters and returns an integer.',
    'Sure, I''ll read that file for you.' + #10 + #10 + '```pascal' + #10 + 'program hello;' + #10 + 'begin' + #10 + '  WriteLn(''hello world'');' + #10 + 'end.' + #10 + '```' + #10 + #10 + 'The file is 4 lines long.',
    #$E8#$BF#$99#$E6#$98#$AF#$E4#$B8#$AD#$E6#$96#$87#$E5#$9B#$9E#$E5#$A4#$8D + ', mixed with English and ' + #$F0#$9F#$98#$80 + ' emoji!',
    'Done! Here''s a summary:' + #10 + '  - Modified 3 files' + #10 + '  - Added 42 lines' + #10 + '  - Removed 7 lines' + #10 + '  - All tests passing ' + ICON_CHECK
  );

type
  TMsgRole = (mrUser, mrAI, mrTool, mrSystem);

  TMsg = record
    Role: TMsgRole;
    Content: AnsiString;
    ToolName: AnsiString;
  end;

  TAppState = (asIdle, asThinking, asStreaming, asPalette);

var
  Term: TTerminal;
  Msgs: array[0..MAX_MESSAGES - 1] of TMsg;
  MsgCount: Integer;
  InputBuf: AnsiString;
  InputCurCol: Integer;
  State: TAppState;
  StreamIdx, StreamRevealed: Integer;
  StreamTarget: AnsiString;
  ThinkTimer: Integer;
  ScrollOffset: Integer;
  ResponseIdx: Integer;
  TokenCount: Integer;
  ElapsedSec: Integer;
  ModelName: AnsiString;
  CwdPath: AnsiString;

procedure AddMsg(Role: TMsgRole; const Content: AnsiString; const Tool: AnsiString = '');
begin
  if MsgCount >= MAX_MESSAGES then Exit;
  Msgs[MsgCount].Role := Role;
  Msgs[MsgCount].Content := Content;
  Msgs[MsgCount].ToolName := Tool;
  Inc(MsgCount);
  ScrollOffset := 0;
end;

procedure StartResponse;
begin
  State := asThinking;
  ThinkTimer := 0;
  ElapsedSec := 0;
end;

procedure AdvanceThinking;
begin
  Inc(ThinkTimer);
  if ThinkTimer >= 40 then
  begin
    // Simulate tool call before response.
    if (ResponseIdx mod 3) = 0 then
      AddMsg(mrTool, 'Read src/main.pas', 'Read');

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
  if StreamRevealed < Length(StreamTarget) then
  begin
    Inc(StreamRevealed);
    Msgs[StreamIdx].Content := Copy(StreamTarget, 1, StreamRevealed);
  end
  else
  begin
    State := asIdle;
    Inc(ElapsedSec);
  end;
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
begin
  S := Ucs4ToUtf8(Cp); B := ColToByteOfs(InputBuf, InputCurCol);
  Insert(S, InputBuf, B + 1); Inc(InputCurCol, GraphemeWidth(S));
end;

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
  InputBuf := ''; InputCurCol := 0;
  if Msgs[MsgCount - 1].Content = '/help' then
    AddMsg(mrSystem, 'Commands: /help /clear /quit | Ctrl+P palette | Ctrl+C quit')
  else if Msgs[MsgCount - 1].Content = '/clear' then
    MsgCount := 0
  else if Msgs[MsgCount - 1].Content = '/quit' then
    Term.RequestQuit
  else
    StartResponse;
end;

// Spinner animation frames.
function SpinnerChar: AnsiString;
const Frames: array[0..7] of AnsiString = (#$E2#$A0#$8B, #$E2#$A0#$99, #$E2#$A0#$B9, #$E2#$A0#$B8, #$E2#$A0#$BC, #$E2#$A0#$B4, #$E2#$A0#$A6, #$E2#$A0#$A7);
begin
  Result := Frames[(ThinkTimer div 3) mod 8];
end;

procedure RenderMessages(const Area: TRect; Buf: TBuffer);
var
  I, Y, MaxY, StartI: Integer;
  Prefix, Line: AnsiString;
  Sty: TStyle;
begin
  MaxY := Area.Height;
  if MaxY <= 0 then Exit;

  // Show welcome banner if no messages.
  if MsgCount = 0 then
  begin
    Buf.SetString(Area.X + 2, Area.Y + 1, 'Welcome to cli888', TStyle.Default.WithFg(clCyan).WithModifier([mbBold]));
    Buf.SetString(Area.X + 2, Area.Y + 3, 'Type a message and press Enter to chat.', TStyle.Default.WithFg(clDarkGray));
    Buf.SetString(Area.X + 2, Area.Y + 4, 'Try /help for commands, Ctrl+P for palette.', TStyle.Default.WithFg(clDarkGray));
    Exit;
  end;

  // Simple scroll: show last N messages that fit.
  StartI := MsgCount - MaxY + ScrollOffset;
  if StartI < 0 then StartI := 0;

  Y := 0;
  for I := StartI to MsgCount - 1 do
  begin
    if Y >= MaxY then Break;
    case Msgs[I].Role of
      mrUser:
        begin
          Prefix := ' ' + ICON_USER + ' ';
          Sty := TStyle.Default.WithFg(clCyan);
        end;
      mrAI:
        begin
          Prefix := ' ' + ICON_AI + ' ';
          Sty := TStyle.Default.WithFg(clGreen);
        end;
      mrTool:
        begin
          Prefix := '  ' + ICON_TOOL + ' ';
          Sty := TStyle.Default.WithFg(clYellow);
        end;
      mrSystem:
        begin
          Prefix := ' ' + ICON_INFO + '  ';
          Sty := TStyle.Default.WithFg(clMagenta);
        end;
    end;

    Line := Prefix + Msgs[I].Content;
    Buf.SetStringN(Area.X, Area.Y + Y, Line, Area.Width, Sty);
    Inc(Y);
  end;
end;

procedure RenderFrame;
var
  Frame: TFrame;
  Rows: TRectArray;
  MsgArea, InputArea, StatusArea: TRect;
  InputBlock: TBlock;
  InputInner: TRect;
  InputBorderSty: TStyle;
  StatusLine1, StatusLine2: AnsiString;
  StateLabel, HintStr: AnsiString;
  PopupArea: TRect;
  C: TClear;
  PopupBlock: TBlock;
  PopupPara: TParagraph;
begin
  Frame := Term.BeginFrame;

  // Layout: messages (flex) | input (3) | status (2)
  Rows := VerticalSplit(Frame.Area, [
    MinConstraint(0),
    LengthConstraint(3),
    LengthConstraint(2)
  ]);
  MsgArea    := Rows[0];
  InputArea  := Rows[1];
  StatusArea := Rows[2];

  // Messages area — direct buffer painting (like real cli888).
  RenderMessages(MsgArea, Frame.Buffer);

  // Input box — bordered, focused style.
  if State = asIdle then
    InputBorderSty := TStyle.Default.WithFg(clCyan)
  else
    InputBorderSty := TStyle.Default.WithFg(clDarkGray);

  InputBlock := TBlock.Default
                  .WithBorders(BordersAll)
                  .WithTitle(' ' + ICON_USER + ' ')
                  .WithBorderStyle(InputBorderSty)
                  .WithTitleStyle(TStyle.Default.WithFg(clCyan).WithModifier([mbBold]));
  InputBlock.Render(InputArea, Frame.Buffer);
  InputInner := InputBlock.Inner(InputArea);

  Frame.Buffer.SetString(InputInner.X, InputInner.Y, '> ' + InputBuf,
    TStyle.Default.WithFg(clWhite));

  Frame.HasCursor := (State = asIdle);
  Frame.CursorPos.X := InputInner.X + 2 + InputCurCol;
  Frame.CursorPos.Y := InputInner.Y;

  // Status bar — 2 rows.
  // Row 1: CWD (left) + model (right)
  StatusLine1 := ' ' + CwdPath;
  while Length(StatusLine1) + Length(ModelName) + 2 < Frame.Area.Width do
    StatusLine1 := StatusLine1 + ' ';
  StatusLine1 := StatusLine1 + ModelName + ' ';
  Frame.Buffer.SetStringN(StatusArea.X, StatusArea.Y, StatusLine1, StatusArea.Width,
    TStyle.Default.WithBg(RgbColor(30, 30, 50)).WithFg(clDarkGray));
  // Model name highlighted.
  Frame.Buffer.SetStringN(
    StatusArea.X + Integer(StatusArea.Width) - Length(ModelName) - 1,
    StatusArea.Y, ModelName,
    Length(ModelName),
    TStyle.Default.WithBg(RgbColor(30, 30, 50)).WithFg(clWhite).WithModifier([mbBold]));

  // Row 2: hints (left) + state (right)
  case State of
    asIdle:      StateLabel := 'State: Idle';
    asThinking:  StateLabel := SpinnerChar + ' Thinking...';
    asStreaming:  StateLabel := SpinnerChar + ' Streaming';
    asPalette:   StateLabel := 'State: Palette';
  end;
  HintStr := ' Enter send | Ctrl+P palette | Ctrl+C quit';
  StatusLine2 := HintStr;
  while Length(StatusLine2) + Length(StateLabel) + 2 < Frame.Area.Width do
    StatusLine2 := StatusLine2 + ' ';
  StatusLine2 := StatusLine2 + StateLabel + ' ';
  Frame.Buffer.SetStringN(StatusArea.X, StatusArea.Y + 1, StatusLine2, StatusArea.Width,
    TStyle.Default.WithBg(RgbColor(30, 30, 50)).WithFg(clDarkGray));

  // Command palette popup.
  if State = asPalette then
  begin
    PopupArea := TRect.Make(
      Frame.Area.X + (Frame.Area.Width - 50) div 2,
      Frame.Area.Y + (Frame.Area.Height - 8) div 2, 50, 8);
    C := ClearWidget; C.Render(PopupArea, Frame.Buffer);
    PopupBlock := TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' commands ')
      .WithBorderStyle(TStyle.Default.WithFg(clYellow).WithModifier([mbBold]))
      .WithStyle(TStyle.Default.WithBg(RgbColor(20, 20, 40)));
    PopupPara := TParagraph.FromString(
      '  /help    ' + #$E2#$80#$94 + ' show help' + #10 +
      '  /clear   ' + #$E2#$80#$94 + ' clear history' + #10 +
      '  /quit    ' + #$E2#$80#$94 + ' exit' + #10 + #10 +
      '  Esc      ' + #$E2#$80#$94 + ' close this palette')
      .WithBlock(PopupBlock)
      .WithStyle(TStyle.Default.WithFg(clWhite).WithBg(RgbColor(20, 20, 40)));
    PopupPara.Render(PopupArea, Frame.Buffer);
  end;

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if State = asPalette then
  begin
    if (K.Code = kcEsc) or ((K.Code = kcChar) and (K.Ch = Ord('p')) and (kmCtrl in K.Modifiers)) then
      State := asIdle;
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
    kcPageUp: begin Inc(ScrollOffset, 5); if ScrollOffset > MsgCount then ScrollOffset := MsgCount; end;
    kcPageDown: begin Dec(ScrollOffset, 5); if ScrollOffset < 0 then ScrollOffset := 0; end;
    kcUp: begin Inc(ScrollOffset); if ScrollOffset > MsgCount then ScrollOffset := MsgCount; end;
    kcDown: begin Dec(ScrollOffset); if ScrollOffset < 0 then ScrollOffset := 0; end;
  else
  end;
end;

var
  Ev: TEvent;

begin
  MsgCount := 0; InputBuf := ''; InputCurCol := 0;
  State := asIdle; ResponseIdx := 0; TokenCount := 0;
  ScrollOffset := 0; ThinkTimer := 0; ElapsedSec := 0;
  ModelName := 'claude-opus-4-7';
  CwdPath := '~/projects/fafafa.tui';

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;

    while not Term.ShouldQuit do
    begin
      RenderFrame;
      case State of
        asThinking:  begin Ev := Term.PollEvent(30); AdvanceThinking; end;
        asStreaming: begin Ev := Term.PollEvent(12); AdvanceStream; end;
      else
        Ev := Term.PollEvent(-1);
      end;
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
        evMouse:
          case Ev.Mouse.Kind of
            mkScrollUp:   begin Inc(ScrollOffset); if ScrollOffset > MsgCount then ScrollOffset := MsgCount; end;
            mkScrollDown: begin Dec(ScrollOffset); if ScrollOffset < 0 then ScrollOffset := 0; end;
          else end;
      else end;
    end;
  finally
    Term.LeaveTui; Term.Free;
  end;
end.
