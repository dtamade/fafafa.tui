unit ftui_input;

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
  ftui_grapheme,
  ftui_block;

type
  TInputState = record
    Text: AnsiString;
    Cursor: Integer;
    ScrollX: Integer;

    class function Empty: TInputState; static;
    class function WithText(const S: AnsiString): TInputState; static;
    procedure InsertChar(Cp: LongWord);
    procedure InsertStr(const S: AnsiString);
    procedure DeleteBack;
    procedure DeleteForward;
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveHome;
    procedure MoveEnd;
    function CursorCol: Integer;
    function TextWidth: Integer;
  end;

  TInput = record
    Placeholder: AnsiString;
    MaskChar: Char;
    Style: TStyle;
    PlaceholderStyle: TStyle;
    CursorStyle: TStyle;
    HasBlock: Boolean;
    Block: TBlock;

    class function Default: TInput; static;
    function WithPlaceholder(const S: AnsiString): TInput;
    function WithMask(Ch: Char): TInput;
    function WithStyle(const S: TStyle): TInput;
    function WithPlaceholderStyle(const S: TStyle): TInput;
    function WithCursorStyle(const S: TStyle): TInput;
    function WithBlock(const B: TBlock): TInput;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TInputState);
  end;

implementation

function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then
  begin
    SetLength(Result, 1);
    Result[1] := Chr(Cp);
  end
  else if Cp < $800 then
  begin
    SetLength(Result, 2);
    Result[1] := Chr($C0 or (Cp shr 6));
    Result[2] := Chr($80 or (Cp and $3F));
  end
  else if Cp < $10000 then
  begin
    SetLength(Result, 3);
    Result[1] := Chr($E0 or (Cp shr 12));
    Result[2] := Chr($80 or ((Cp shr 6) and $3F));
    Result[3] := Chr($80 or (Cp and $3F));
  end
  else
  begin
    SetLength(Result, 4);
    Result[1] := Chr($F0 or (Cp shr 18));
    Result[2] := Chr($80 or ((Cp shr 12) and $3F));
    Result[3] := Chr($80 or ((Cp shr 6) and $3F));
    Result[4] := Chr($80 or (Cp and $3F));
  end;
end;

function PrevGraphemeByte(const S: AnsiString; Pos: Integer): Integer;
var P: Integer;
begin
  P := Pos - 1;
  while (P > 0) and ((Byte(S[P + 1]) and $C0) = $80) do
    Dec(P);
  if P < 0 then P := 0;
  Result := P;
end;

function GraphemeCount(const S: AnsiString): Integer;
var P: Integer; Adv: TGraphemeAdvance;
begin
  Result := 0;
  P := 0;
  while P < Length(S) do
  begin
    Adv := GraphemeAdvance(S[1], Length(S), P);
    Inc(P, Adv.ByteLen);
    Inc(Result);
  end;
end;

function ColWidthUpTo(const S: AnsiString; BytePos: Integer): Integer;
var P: Integer; Adv: TGraphemeAdvance;
begin
  Result := 0;
  P := 0;
  while P < BytePos do
  begin
    if P >= Length(S) then Break;
    Adv := GraphemeAdvance(S[1], Length(S), P);
    Inc(Result, Adv.Width);
    Inc(P, Adv.ByteLen);
  end;
end;

{ TInputState }

class function TInputState.Empty: TInputState;
begin
  Result.Text := '';
  Result.Cursor := 0;
  Result.ScrollX := 0;
end;

class function TInputState.WithText(const S: AnsiString): TInputState;
begin
  Result.Text := S;
  Result.Cursor := Length(S);
  Result.ScrollX := 0;
end;

procedure TInputState.InsertChar(Cp: LongWord);
var S: AnsiString;
begin
  if Cp < 32 then Exit;
  S := Ucs4ToUtf8(Cp);
  Insert(S, Text, Cursor + 1);
  Inc(Cursor, Length(S));
end;

procedure TInputState.InsertStr(const S: AnsiString);
var I, Len: Integer; Clean: AnsiString;
begin
  Len := 0;
  SetLength(Clean, Length(S));
  for I := 1 to Length(S) do
    if (S[I] <> #10) and (S[I] <> #13) then
    begin
      Inc(Len);
      Clean[Len] := S[I];
    end;
  SetLength(Clean, Len);
  if Len = 0 then Exit;
  Insert(Clean, Text, Cursor + 1);
  Inc(Cursor, Len);
end;

procedure TInputState.DeleteBack;
var Prev: Integer;
begin
  if Cursor <= 0 then Exit;
  Prev := PrevGraphemeByte(Text, Cursor);
  Delete(Text, Prev + 1, Cursor - Prev);
  Cursor := Prev;
end;

procedure TInputState.DeleteForward;
var Adv: TGraphemeAdvance;
begin
  if Cursor >= Length(Text) then Exit;
  Adv := GraphemeAdvance(Text[1], Length(Text), Cursor);
  Delete(Text, Cursor + 1, Adv.ByteLen);
end;

procedure TInputState.MoveLeft;
begin
  if Cursor <= 0 then Exit;
  Cursor := PrevGraphemeByte(Text, Cursor);
end;

procedure TInputState.MoveRight;
var Adv: TGraphemeAdvance;
begin
  if Cursor >= Length(Text) then Exit;
  Adv := GraphemeAdvance(Text[1], Length(Text), Cursor);
  Inc(Cursor, Adv.ByteLen);
end;

procedure TInputState.MoveHome;
begin
  Cursor := 0;
end;

procedure TInputState.MoveEnd;
begin
  Cursor := Length(Text);
end;

function TInputState.CursorCol: Integer;
begin
  Result := ColWidthUpTo(Text, Cursor);
end;

function TInputState.TextWidth: Integer;
begin
  Result := GraphemeWidth(Text);
end;

{ TInput }

class function TInput.Default: TInput;
begin
  Result.Placeholder := '';
  Result.MaskChar := #0;
  Result.Style := TStyle.Default;
  Result.PlaceholderStyle := TStyle.Default.WithFg(clDarkGray);
  Result.CursorStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.HasBlock := False;
  Result.Block := TBlock.Default;
end;

function TInput.WithPlaceholder(const S: AnsiString): TInput;
begin
  Result := Self;
  Result.Placeholder := S;
end;

function TInput.WithMask(Ch: Char): TInput;
begin
  Result := Self;
  Result.MaskChar := Ch;
end;

function TInput.WithStyle(const S: TStyle): TInput;
begin
  Result := Self;
  Result.Style := S;
end;

function TInput.WithPlaceholderStyle(const S: TStyle): TInput;
begin
  Result := Self;
  Result.PlaceholderStyle := S;
end;

function TInput.WithCursorStyle(const S: TStyle): TInput;
begin
  Result := Self;
  Result.CursorStyle := S;
end;

function TInput.WithBlock(const B: TBlock): TInput;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := B;
end;

procedure TInput.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TInputState);
var
  Inner: TRect;
  DisplayText: AnsiString;
  VisibleW, CursorCol, ScrollCol: Integer;
  P, Col: Integer;
  Adv: TGraphemeAdvance;
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

  VisibleW := Inner.Width;

  // Build display text (masked or raw)
  if MaskChar <> #0 then
    DisplayText := StringOfChar(MaskChar, GraphemeCount(State.Text))
  else
    DisplayText := State.Text;

  // Calculate cursor column position (display width from ScrollX to Cursor)
  CursorCol := ColWidthUpTo(DisplayText, State.Cursor);
  ScrollCol := ColWidthUpTo(DisplayText, State.ScrollX);

  // Adjust ScrollX so cursor is visible (using column widths)
  if CursorCol < ScrollCol then
    State.ScrollX := State.Cursor
  else if CursorCol - ScrollCol >= VisibleW then
  begin
    // Move ScrollX forward until cursor fits
    P := State.Cursor;
    Col := 0;
    while (P > 0) and (Col < VisibleW - 1) do
    begin
      P := PrevGraphemeByte(DisplayText, P);
      Adv := GraphemeAdvance(DisplayText[1], Length(DisplayText), P);
      Inc(Col, Adv.Width);
    end;
    State.ScrollX := P;
  end;
  if State.ScrollX < 0 then State.ScrollX := 0;

  // Render text or placeholder
  if (Length(DisplayText) = 0) and (Length(Placeholder) > 0) then
    ABuf.SetStringN(Inner.X, Inner.Y, Placeholder, VisibleW, PlaceholderStyle)
  else if Length(DisplayText) > 0 then
    ABuf.SetStringN(Inner.X, Inner.Y,
      Copy(DisplayText, State.ScrollX + 1, Length(DisplayText) - State.ScrollX),
      VisibleW, Style);

  // Cursor highlight (at correct column position)
  CursorCol := ColWidthUpTo(DisplayText, State.Cursor);
  ScrollCol := ColWidthUpTo(DisplayText, State.ScrollX);
  Col := CursorCol - ScrollCol;
  if (Col >= 0) and (Col < VisibleW) then
    ABuf.SetStyle(TRect.Make(Inner.X + Col, Inner.Y, 1, 1), CursorStyle);
end;

end.
