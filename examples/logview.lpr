program logview;

{$mode objfpc}{$H+}
{$IFNDEF UNIX}
begin
  WriteLn('logview requires Unix (uses fpRead/fpOpen for non-blocking file tail)');
end.
{$ELSE}

uses
  SysUtils, {$IFDEF UNIX}BaseUnix,{$ENDIF}
  ftui_app,
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
  ftui_input,
  ftui_paragraph;

const
  MAX_LINES = 10000;
  TICK_MS = 200;

type
  TLogLevel = (llDebug, llInfo, llWarn, llError, llUnknown);

  TLogLine = record
    Text: AnsiString;
    Level: TLogLevel;
  end;

  TLogviewApp = class(TApp)
  private
    FLines: array of TLogLine;
    FLineCount: Integer;
    FFiltered: array of Integer;
    FFilterCount: Integer;
    FOffset: Integer;
    FFollow: Boolean;
    FFilterMode: Boolean;
    FFilterState: TInputState;
    FFilterText: AnsiString;
    FFileName: AnsiString;
    FFileHandle: cInt;
    FFilePos: Int64;
    FError: AnsiString;
    procedure LoadFile;
    procedure TailFile;
    procedure AddLine(const S: AnsiString);
    procedure RebuildFilter;
    function DetectLevel(const S: AnsiString): TLogLevel;
    function LevelStyle(L: TLogLevel): TStyle;
  protected
    procedure OnInit; override;
    procedure OnTick; override;
    procedure OnDestroy; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

// PLACEHOLDER_IMPL

function TLogviewApp.DetectLevel(const S: AnsiString): TLogLevel;
var I: Integer; U: AnsiString;
begin
  Result := llUnknown;
  U := '';
  for I := 1 to Length(S) do
    if I <= 80 then
      U := U + UpCase(S[I]);
  if Pos('ERROR', U) > 0 then Result := llError
  else if Pos('WARN', U) > 0 then Result := llWarn
  else if Pos('INFO', U) > 0 then Result := llInfo
  else if Pos('DEBUG', U) > 0 then Result := llDebug;
end;

function TLogviewApp.LevelStyle(L: TLogLevel): TStyle;
begin
  case L of
    llError: Result := TStyle.Default.WithFg(IndexedColor(1));
    llWarn:  Result := TStyle.Default.WithFg(IndexedColor(3));
    llInfo:  Result := TStyle.Default.WithFg(IndexedColor(2));
    llDebug: Result := TStyle.Default.WithFg(IndexedColor(8));
  else
    Result := TStyle.Default;
  end;
end;

procedure TLogviewApp.AddLine(const S: AnsiString);
begin
  if FLineCount >= MAX_LINES then
  begin
    Move(FLines[1], FLines[0], (MAX_LINES - 1) * SizeOf(TLogLine));
    Dec(FLineCount);
  end;
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 1024);
  FLines[FLineCount].Text := S;
  FLines[FLineCount].Level := DetectLevel(S);
  Inc(FLineCount);
end;

procedure TLogviewApp.RebuildFilter;
var I: Integer; Query: AnsiString;
begin
  FFilterCount := 0;
  if FFilterText = '' then
  begin
    SetLength(FFiltered, FLineCount);
    for I := 0 to FLineCount - 1 do
    begin
      FFiltered[I] := I;
      Inc(FFilterCount);
    end;
    Exit;
  end;
  Query := LowerCase(FFilterText);
  SetLength(FFiltered, FLineCount);
  for I := 0 to FLineCount - 1 do
    if Pos(Query, LowerCase(FLines[I].Text)) > 0 then
    begin
      FFiltered[FFilterCount] := I;
      Inc(FFilterCount);
    end;
end;

procedure TLogviewApp.LoadFile;
var
  F: TextFile;
  Line: AnsiString;
begin
  AssignFile(F, FFileName);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then
  begin
    FError := 'Cannot open: ' + FFileName;
    Exit;
  end;
  while not EOF(F) do
  begin
    ReadLn(F, Line);
    AddLine(Line);
  end;
  CloseFile(F);
end;

procedure TLogviewApp.TailFile;
var
  Buf: array[0..4095] of Char;
  BytesRead: Int64;
  Line: AnsiString;
  I: Integer;
  NewLines: Boolean;
begin
  if FFileHandle < 0 then Exit;
  NewLines := False;
  repeat
    BytesRead := fpRead(FFileHandle, Buf, SizeOf(Buf));
    if BytesRead <= 0 then Break;
    Line := '';
    for I := 0 to BytesRead - 1 do
    begin
      if Buf[I] = #10 then
      begin
        AddLine(Line);
        Line := '';
        NewLines := True;
      end
      else if Buf[I] <> #13 then
        Line := Line + Buf[I];
    end;
    if Line <> '' then
    begin
      AddLine(Line);
      NewLines := True;
    end;
    Inc(FFilePos, BytesRead);
  until BytesRead < SizeOf(Buf);
  if NewLines then
    RebuildFilter;
end;

// PLACEHOLDER_LIFECYCLE

procedure TLogviewApp.OnInit;
begin
  TickInterval := TICK_MS;
  FLineCount := 0;
  FFilterCount := 0;
  FOffset := 0;
  FFollow := True;
  FFilterMode := False;
  FFilterState := TInputState.Empty;
  FFilterText := '';
  FError := '';
  SetLength(FLines, 1024);
  SetLength(FFiltered, 1024);

  if ParamCount < 1 then
  begin
    FError := 'Usage: logview <file>';
    Exit;
  end;
  FFileName := ParamStr(1);
  LoadFile;
  RebuildFilter;

  FFileHandle := fpOpen(FFileName, O_RdOnly or O_NonBlock);
  if FFileHandle >= 0 then
  begin
    FFilePos := fpLSeek(FFileHandle, 0, SEEK_END);
  end;
end;

procedure TLogviewApp.OnTick;
begin
  TailFile;
end;

procedure TLogviewApp.OnDestroy;
begin
  if FFileHandle >= 0 then
    fpClose(FFileHandle);
end;

procedure TLogviewApp.Render(var Frame: TFrame);
var
  Rows: TRectArray;
  ViewH, I, LineIdx, Y: Integer;
  Sty: TStyle;
  StatusText: AnsiString;
  CountStr: string[8];
begin
  if FError <> '' then
  begin
    TParagraph.FromString('Error: ' + FError + #10#10 + 'q = quit')
      .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' logview '))
      .Render(Frame.Area, Frame.Buffer);
    Exit;
  end;

  Rows := VerticalSplit(Frame.Area, [FillConstraint(1), LengthConstraint(1)]);
  ViewH := Rows[0].Height;

  if FFollow and (FFilterCount > ViewH) then
    FOffset := FFilterCount - ViewH;
  if FOffset < 0 then FOffset := 0;
  if FOffset > FFilterCount - ViewH then
    FOffset := FFilterCount - ViewH;
  if FOffset < 0 then FOffset := 0;

  Y := Rows[0].Y;
  for I := 0 to ViewH - 1 do
  begin
    LineIdx := FOffset + I;
    if LineIdx >= FFilterCount then Break;
    Sty := LevelStyle(FLines[FFiltered[LineIdx]].Level);
    Frame.Buffer.SetStringN(Rows[0].X, Y + I,
      FLines[FFiltered[LineIdx]].Text, Rows[0].Width, Sty);
  end;

  if FFilterMode then
    StatusText := '/' + FFilterState.Text + '_'
  else
  begin
    Str(FFilterCount, CountStr);
    StatusText := ' ' + FFileName + '  lines:' + CountStr;
    if FFilterText <> '' then
      StatusText := StatusText + '  filter:"' + FFilterText + '"';
    if FFollow then
      StatusText := StatusText + '  [FOLLOW]';
    StatusText := StatusText + '  [/=filter F=follow q=quit]';
  end;
  TParagraph.FromString(StatusText)
    .WithStyle(TStyle.Default.WithModifier([mbReversed]))
    .Render(Rows[1], Frame.Buffer);
end;

procedure TLogviewApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;

  if FFilterMode then
  begin
    case Ev.Key.Code of
      kcEsc:
      begin
        FFilterMode := False;
        FFilterText := '';
        RebuildFilter;
      end;
      kcEnter:
      begin
        FFilterMode := False;
        FFilterText := FFilterState.Text;
        RebuildFilter;
        FOffset := 0;
      end;
      kcBackspace:
        FFilterState.DeleteBack;
      kcChar:
        FFilterState.InsertChar(Ev.Key.Ch);
    end;
    Exit;
  end;

  case Ev.Key.Code of
    kcUp:
    begin
      FFollow := False;
      if FOffset > 0 then Dec(FOffset);
    end;
    kcDown:
    begin
      FFollow := False;
      Inc(FOffset);
    end;
    kcPageUp:
    begin
      FFollow := False;
      Dec(FOffset, 20);
      if FOffset < 0 then FOffset := 0;
    end;
    kcPageDown:
    begin
      FFollow := False;
      Inc(FOffset, 20);
    end;
    kcHome:
    begin
      FFollow := False;
      FOffset := 0;
    end;
    kcEnd:
      FFollow := True;
    kcChar:
      case Ev.Key.Ch of
        Ord('q'): Quit;
        Ord('/'): begin FFilterMode := True; FFilterState := TInputState.Empty; end;
        Ord('f'), Ord('F'): FFollow := not FFollow;
      end;
  end;
end;

var App: TLogviewApp;
begin
  App := TLogviewApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
{$ENDIF}
