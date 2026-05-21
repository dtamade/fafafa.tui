unit ftui_textarea;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_block;

type
  TTextAreaState = record
    ScrollY: Integer;
    CursorRow: Integer;
    CursorCol: Integer;

    class function Empty: TTextAreaState; static;
  end;

  THighlightFunc = function(const Line: AnsiString; Row: Integer): TStyle;

  TTextArea = record
    Lines: array of AnsiString;
    Style: TStyle;
    LineNumStyle: TStyle;
    CursorStyle: TStyle;
    ShowLineNumbers: Boolean;
    HasBlock: Boolean;
    Block: TBlock;
    ReadOnly: Boolean;
    Highlight: THighlightFunc;

    class function Create(const AText: AnsiString): TTextArea; static;
    class function FromLines(const ALines: array of AnsiString): TTextArea; static;
    function WithStyle(const S: TStyle): TTextArea;
    function WithLineNumStyle(const S: TStyle): TTextArea;
    function WithCursorStyle(const S: TStyle): TTextArea;
    function WithShowLineNumbers(V: Boolean): TTextArea;
    function WithBlock(const B: TBlock): TTextArea;
    function WithHighlight(F: THighlightFunc): TTextArea;
    function LineCount: Integer;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTextAreaState);
  end;

implementation

uses
  SysUtils;

{ TTextAreaState }

class function TTextAreaState.Empty: TTextAreaState;
begin
  Result.ScrollY := 0;
  Result.CursorRow := 0;
  Result.CursorCol := 0;
end;

{ TTextArea }

class function TTextArea.Create(const AText: AnsiString): TTextArea;
var
  I, Start, Len: Integer;
  Count: Integer;
begin
  Result.Lines := nil;
  Result.Style := TStyle.Default;
  Result.LineNumStyle := TStyle.Default.WithFg(clDarkGray);
  Result.CursorStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.ShowLineNumbers := True;
  Result.HasBlock := False;
  Result.Block := TBlock.Default;
  Result.ReadOnly := False;
  Result.Highlight := nil;

  // Split text into lines
  Len := Length(AText);
  Count := 0;
  Start := 1;
  for I := 1 to Len do
  begin
    if AText[I] = #10 then
    begin
      Inc(Count);
      SetLength(Result.Lines, Count);
      Result.Lines[Count - 1] := Copy(AText, Start, I - Start);
      Start := I + 1;
    end;
  end;
  Inc(Count);
  SetLength(Result.Lines, Count);
  Result.Lines[Count - 1] := Copy(AText, Start, Len - Start + 1);
end;

class function TTextArea.FromLines(const ALines: array of AnsiString): TTextArea;
var I: Integer;
begin
  Result := TTextArea.Create('');
  SetLength(Result.Lines, Length(ALines));
  for I := 0 to High(ALines) do
    Result.Lines[I] := ALines[I];
end;

function TTextArea.WithStyle(const S: TStyle): TTextArea;
begin
  Result := Self;
  Result.Style := S;
end;

function TTextArea.WithLineNumStyle(const S: TStyle): TTextArea;
begin
  Result := Self;
  Result.LineNumStyle := S;
end;

function TTextArea.WithCursorStyle(const S: TStyle): TTextArea;
begin
  Result := Self;
  Result.CursorStyle := S;
end;

function TTextArea.WithShowLineNumbers(V: Boolean): TTextArea;
begin
  Result := Self;
  Result.ShowLineNumbers := V;
end;

function TTextArea.WithBlock(const B: TBlock): TTextArea;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := B;
end;

function TTextArea.WithHighlight(F: THighlightFunc): TTextArea;
begin
  Result := Self;
  Result.Highlight := F;
end;

function TTextArea.LineCount: Integer;
begin
  Result := Length(Lines);
end;

procedure TTextArea.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTextAreaState);
var
  Inner: TRect;
  GutterW, VisibleRows, I, Row, Y, TextX, TextW: Integer;
  NumStr: AnsiString;
  LineSty: TStyle;
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  // Gutter width for line numbers
  GutterW := 0;
  if ShowLineNumbers then
  begin
    GutterW := Length(IntToStr(LineCount)) + 1;
    if GutterW < 4 then GutterW := 4;
  end;

  TextX := Inner.X + GutterW;
  TextW := Inner.Width - GutterW;
  if TextW < 1 then TextW := 1;

  VisibleRows := Inner.Height;

  // Ensure cursor is visible
  if State.CursorRow < State.ScrollY then
    State.ScrollY := State.CursorRow;
  if State.CursorRow >= State.ScrollY + VisibleRows then
    State.ScrollY := State.CursorRow - VisibleRows + 1;
  if State.ScrollY < 0 then State.ScrollY := 0;

  // Render visible lines
  Y := Inner.Y;
  for I := 0 to VisibleRows - 1 do
  begin
    Row := State.ScrollY + I;
    if Row >= LineCount then Break;

    // Line number
    if ShowLineNumbers then
    begin
      NumStr := IntToStr(Row + 1);
      while Length(NumStr) < GutterW - 1 do
        NumStr := ' ' + NumStr;
      NumStr := NumStr + ' ';
      ABuf.SetStringN(Inner.X, Y, NumStr, GutterW, LineNumStyle);
    end;

    // Line content
    if Assigned(Highlight) then
      LineSty := Highlight(Lines[Row], Row)
    else
      LineSty := Style;

    ABuf.SetStringN(TextX, Y, Lines[Row], TextW, LineSty);

    // Cursor highlight
    if Row = State.CursorRow then
    begin
      if (State.CursorCol >= 0) and (State.CursorCol < TextW) then
        ABuf.SetStyle(TRect.Make(TextX + State.CursorCol, Y, 1, 1), CursorStyle);
    end;

    Inc(Y);
  end;
end;

end.
