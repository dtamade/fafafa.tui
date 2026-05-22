program jv;

{$mode objfpc}{$H+}

uses
  SysUtils,
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
  ftui_tree,
  ftui_input,
  ftui_paragraph;

const
  MAX_DEPTH = 64;

type
  TJsonKind = (jkNull, jkBool, jkNumber, jkString, jkArray, jkObject);

  TJsonNode = record
    Key: AnsiString;
    Value: AnsiString;
    Kind: TJsonKind;
    Children: array of TJsonNode;
  end;

  TJvApp = class(TApp)
  private
    FRoot: TJsonNode;
    FTreeNodes: array of TTreeNode;
    FTreeState: TTreeState;
    FSearchMode: Boolean;
    FSearchState: TInputState;
    FSearchHit: Integer;
    FFileName: AnsiString;
    FError: AnsiString;
    procedure BuildTree;
    procedure BuildTreeNode(const JN: TJsonNode; var TN: TTreeNode);
    function ParseJson(const S: AnsiString; var P: Integer): TJsonNode;
    function ParseString(const S: AnsiString; var P: Integer): AnsiString;
    function ParseNumber(const S: AnsiString; var P: Integer): AnsiString;
    procedure SkipWS(const S: AnsiString; var P: Integer);
    function GetCurrentPath: AnsiString;
    procedure SearchNext;
  protected
    procedure OnInit; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

{ JSON Parser }

procedure TJvApp.SkipWS(const S: AnsiString; var P: Integer);
begin
  while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do Inc(P);
end;

function TJvApp.ParseString(const S: AnsiString; var P: Integer): AnsiString;
var R: AnsiString;
begin
  R := '';
  Inc(P); // skip opening "
  while (P <= Length(S)) and (S[P] <> '"') do
  begin
    if S[P] = '\' then
    begin
      Inc(P);
      if P <= Length(S) then
      begin
        case S[P] of
          'n': R := R + #10;
          't': R := R + #9;
          'r': R := R + #13;
          '\': R := R + '\';
          '/': R := R + '/';
          '"': R := R + '"';
        else
          R := R + '\' + S[P];
        end;
      end;
    end
    else
      R := R + S[P];
    Inc(P);
  end;
  if (P <= Length(S)) and (S[P] = '"') then Inc(P);
  Result := R;
end;

function TJvApp.ParseNumber(const S: AnsiString; var P: Integer): AnsiString;
var Start: Integer;
begin
  Start := P;
  if (P <= Length(S)) and (S[P] = '-') then Inc(P);
  while (P <= Length(S)) and (S[P] in ['0'..'9']) do Inc(P);
  if (P <= Length(S)) and (S[P] = '.') then
  begin
    Inc(P);
    while (P <= Length(S)) and (S[P] in ['0'..'9']) do Inc(P);
  end;
  if (P <= Length(S)) and (S[P] in ['e', 'E']) then
  begin
    Inc(P);
    if (P <= Length(S)) and (S[P] in ['+', '-']) then Inc(P);
    while (P <= Length(S)) and (S[P] in ['0'..'9']) do Inc(P);
  end;
  Result := Copy(S, Start, P - Start);
end;

// PLACEHOLDER_PARSE_JSON

function TJvApp.ParseJson(const S: AnsiString; var P: Integer): TJsonNode;
var
  Key: AnsiString;
  ChildCount: Integer;
begin
  Result.Key := '';
  Result.Value := '';
  Result.Kind := jkNull;
  SetLength(Result.Children, 0);
  SkipWS(S, P);
  if P > Length(S) then Exit;

  case S[P] of
    '"':
    begin
      Result.Kind := jkString;
      Result.Value := ParseString(S, P);
    end;
    '-', '0'..'9':
    begin
      Result.Kind := jkNumber;
      Result.Value := ParseNumber(S, P);
    end;
    't':
    begin
      Result.Kind := jkBool;
      Result.Value := 'true';
      Inc(P, 4);
    end;
    'f':
    begin
      Result.Kind := jkBool;
      Result.Value := 'false';
      Inc(P, 5);
    end;
    'n':
    begin
      Result.Kind := jkNull;
      Result.Value := 'null';
      Inc(P, 4);
    end;
    '[':
    begin
      Result.Kind := jkArray;
      Inc(P);
      SkipWS(S, P);
      ChildCount := 0;
      while (P <= Length(S)) and (S[P] <> ']') do
      begin
        SetLength(Result.Children, ChildCount + 1);
        Result.Children[ChildCount] := ParseJson(S, P);
        Result.Children[ChildCount].Key := IntToStr(ChildCount);
        Inc(ChildCount);
        SkipWS(S, P);
        if (P <= Length(S)) and (S[P] = ',') then Inc(P);
        SkipWS(S, P);
      end;
      if (P <= Length(S)) then Inc(P); // skip ]
    end;
    '{':
    begin
      Result.Kind := jkObject;
      Inc(P);
      SkipWS(S, P);
      ChildCount := 0;
      while (P <= Length(S)) and (S[P] <> '}') do
      begin
        SkipWS(S, P);
        if (P <= Length(S)) and (S[P] = '"') then
          Key := ParseString(S, P)
        else
          Key := '?';
        SkipWS(S, P);
        if (P <= Length(S)) and (S[P] = ':') then Inc(P);
        SetLength(Result.Children, ChildCount + 1);
        Result.Children[ChildCount] := ParseJson(S, P);
        Result.Children[ChildCount].Key := Key;
        Inc(ChildCount);
        SkipWS(S, P);
        if (P <= Length(S)) and (S[P] = ',') then Inc(P);
        SkipWS(S, P);
      end;
      if (P <= Length(S)) then Inc(P); // skip }
    end;
  end;
end;

// PLACEHOLDER_BUILD_TREE

procedure TJvApp.BuildTreeNode(const JN: TJsonNode; var TN: TTreeNode);
var
  Lbl: AnsiString;
  I: Integer;
  ChildNodes: array of TTreeNode;
begin
  case JN.Kind of
    jkObject:
    begin
      if JN.Key <> '' then
        Lbl := JN.Key + ': {' + IntToStr(Length(JN.Children)) + '}'
      else
        Lbl := '{' + IntToStr(Length(JN.Children)) + '}';
    end;
    jkArray:
    begin
      if JN.Key <> '' then
        Lbl := JN.Key + ': [' + IntToStr(Length(JN.Children)) + ']'
      else
        Lbl := '[' + IntToStr(Length(JN.Children)) + ']';
    end;
  else
    if JN.Key <> '' then
      Lbl := JN.Key + ': ' + JN.Value
    else
      Lbl := JN.Value;
  end;

  TN := TTreeNode.Make(Lbl);
  if Length(JN.Children) > 0 then
  begin
    SetLength(ChildNodes, Length(JN.Children));
    for I := 0 to High(JN.Children) do
      BuildTreeNode(JN.Children[I], ChildNodes[I]);
    TN := TN.WithChildren(ChildNodes);
  end;
end;

procedure TJvApp.BuildTree;
var I: Integer;
begin
  if (FRoot.Kind = jkObject) or (FRoot.Kind = jkArray) then
  begin
    SetLength(FTreeNodes, Length(FRoot.Children));
    for I := 0 to High(FRoot.Children) do
      BuildTreeNode(FRoot.Children[I], FTreeNodes[I]);
  end
  else
  begin
    SetLength(FTreeNodes, 1);
    BuildTreeNode(FRoot, FTreeNodes[0]);
  end;
  FTreeState := TTreeState.Empty;
end;

{ Visible-tree walk: mirrors TTree's DFS flattening logic }

type
  TWalkResult = record
    Found: Boolean;
    Label_: AnsiString;
    Path: AnsiString;
  end;

procedure WalkJsonNodes(const Nodes: array of TJsonNode;
  const ParentPath: AnsiString; var State: TTreeState;
  var FlatIdx: Integer; Target: Integer; var Res: TWalkResult);
var
  I: Integer;
  CurPath: AnsiString;
  IsOpen: Boolean;
begin
  for I := 0 to High(Nodes) do
  begin
    if Nodes[I].Key <> '' then
    begin
      if (Length(Nodes[I].Key) > 0) and (Nodes[I].Key[1] in ['0'..'9']) then
        CurPath := ParentPath + '[' + Nodes[I].Key + ']'
      else
        CurPath := ParentPath + '.' + Nodes[I].Key;
    end
    else
      CurPath := ParentPath;

    if FlatIdx = Target then
    begin
      Res.Found := True;
      Res.Path := CurPath;
      case Nodes[I].Kind of
        jkObject:
          if Nodes[I].Key <> '' then
            Res.Label_ := Nodes[I].Key + ': {' + IntToStr(Length(Nodes[I].Children)) + '}'
          else
            Res.Label_ := '{' + IntToStr(Length(Nodes[I].Children)) + '}';
        jkArray:
          if Nodes[I].Key <> '' then
            Res.Label_ := Nodes[I].Key + ': [' + IntToStr(Length(Nodes[I].Children)) + ']'
          else
            Res.Label_ := '[' + IntToStr(Length(Nodes[I].Children)) + ']';
      else
        if Nodes[I].Key <> '' then
          Res.Label_ := Nodes[I].Key + ': ' + Nodes[I].Value
        else
          Res.Label_ := Nodes[I].Value;
      end;
    end;

    IsOpen := (Length(Nodes[I].Children) > 0) and State.IsOpen(FlatIdx);
    Inc(FlatIdx);
    if Res.Found then Exit;

    if IsOpen then
    begin
      WalkJsonNodes(Nodes[I].Children, CurPath, State, FlatIdx, Target, Res);
      if Res.Found then Exit;
    end;
  end;
end;

{ Search and navigation }

function TJvApp.GetCurrentPath: AnsiString;
var
  FlatIdx: Integer;
  Res: TWalkResult;
begin
  Res.Found := False;
  FlatIdx := 0;
  if (FRoot.Kind = jkObject) or (FRoot.Kind = jkArray) then
    WalkJsonNodes(FRoot.Children, '$', FTreeState, FlatIdx, FTreeState.Selected, Res)
  else
  begin
    Res.Found := True;
    Res.Path := '$';
  end;
  if Res.Found then
    Result := Res.Path
  else
    Result := '$';
end;

procedure TJvApp.SearchNext;
var
  FlatIdx, I, Target, FlatN: Integer;
  Res: TWalkResult;
  Query: AnsiString;
begin
  Query := LowerCase(FSearchState.Text);
  if Query = '' then Exit;
  FlatN := FTreeState.FlatCount;
  if FlatN = 0 then Exit;
  for I := 1 to FlatN do
  begin
    Target := (FTreeState.Selected + I) mod FlatN;
    Res.Found := False;
    FlatIdx := 0;
    if (FRoot.Kind = jkObject) or (FRoot.Kind = jkArray) then
      WalkJsonNodes(FRoot.Children, '$', FTreeState, FlatIdx, Target, Res);
    if Res.Found and (Pos(Query, LowerCase(Res.Label_)) > 0) then
    begin
      FTreeState.Selected := Target;
      FSearchHit := Target;
      Exit;
    end;
  end;
end;

{ App lifecycle }

procedure TJvApp.OnInit;
var
  S, Line: AnsiString;
  F: TextFile;
  P: Integer;
begin
  FSearchMode := False;
  FSearchState := TInputState.Empty;
  FSearchHit := -1;
  FError := '';

  if ParamCount >= 1 then
  begin
    FFileName := ParamStr(1);
    AssignFile(F, FFileName);
    {$I-} Reset(F); {$I+}
    if IOResult <> 0 then
    begin
      FError := 'Cannot open: ' + FFileName;
      BuildTree;
      Exit;
    end;
    S := '';
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      S := S + Line + #10;
    end;
    CloseFile(F);
  end
  else
  begin
    FFileName := '';
    FError := 'Usage: jv <file.json>';
    S := '';
  end;

  if S = '' then
  begin
    FError := 'Empty input';
    BuildTree;
    Exit;
  end;

  P := 1;
  FRoot := ParseJson(S, P);
  BuildTree;
end;

procedure TJvApp.Render(var Frame: TFrame);
var
  Rows: TRectArray;
  T: TTree;
  StatusText: AnsiString;
begin
  if FError <> '' then
  begin
    TParagraph.FromString('Error: ' + FError + #10#10 + 'q = quit')
      .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' jv '))
      .Render(Frame.Area, Frame.Buffer);
    Exit;
  end;

  Rows := VerticalSplit(Frame.Area, [FillConstraint(1), LengthConstraint(1)]);

  T := TTree.Create(FTreeNodes)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' ' + FFileName + ' '))
    .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]))
    .WithIndent(2);
  T.RenderStateful(Rows[0], Frame.Buffer, FTreeState);

  if FSearchMode then
    StatusText := '/' + FSearchState.Text + '_'
  else
    StatusText := GetCurrentPath + '  [/=search n=next Enter=fold q=quit]';

  TParagraph.FromString(StatusText)
    .WithStyle(TStyle.Default.WithModifier([mbReversed]))
    .Render(Rows[1], Frame.Buffer);
end;

procedure TJvApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;

  if FSearchMode then
  begin
    case Ev.Key.Code of
      kcEsc:
        FSearchMode := False;
      kcEnter:
      begin
        FSearchMode := False;
        SearchNext;
      end;
      kcBackspace:
        FSearchState.DeleteBack;
      kcChar:
        FSearchState.InsertChar(Ev.Key.Ch);
    end;
    Exit;
  end;

  case Ev.Key.Code of
    kcUp:
      if FTreeState.Selected > 0 then Dec(FTreeState.Selected);
    kcDown:
      if FTreeState.Selected < FTreeState.FlatCount - 1 then
        Inc(FTreeState.Selected);
    kcPageUp:
      begin
        Dec(FTreeState.Selected, 10);
        if FTreeState.Selected < 0 then FTreeState.Selected := 0;
      end;
    kcPageDown:
      begin
        Inc(FTreeState.Selected, 10);
        if FTreeState.Selected >= FTreeState.FlatCount then
          FTreeState.Selected := FTreeState.FlatCount - 1;
      end;
    kcHome:
      FTreeState.Selected := 0;
    kcEnd:
      if FTreeState.FlatCount > 0 then
        FTreeState.Selected := FTreeState.FlatCount - 1;
    kcEnter:
      FTreeState.Toggle(FTreeState.Selected);
    kcRight:
      if not FTreeState.IsOpen(FTreeState.Selected) then
        FTreeState.Toggle(FTreeState.Selected);
    kcLeft:
      if FTreeState.IsOpen(FTreeState.Selected) then
        FTreeState.Toggle(FTreeState.Selected);
    kcChar:
      case Ev.Key.Ch of
        Ord('q'): Quit;
        Ord('/'): begin FSearchMode := True; FSearchState := TInputState.Empty; end;
        Ord('n'): SearchNext;
      end;
  end;
end;

var App: TJvApp;
begin
  App := TJvApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
