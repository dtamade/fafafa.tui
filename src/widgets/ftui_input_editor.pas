unit ftui_input_editor;

// Multi-line input editor component.
//
// Owns a text buffer (AnsiString) and a byte-offset cursor.  Handles
// all editing operations internally: insert, delete, cursor movement,
// line splitting.  Renders itself into a given buffer area with
// scrolling when content exceeds visible height.
//
// Design:
//   - Single source of truth: FCurByte (byte offset into FText)
//   - Line/column derived on demand via ScanLines
//   - Grapheme-aware: all movement and deletion operates on whole
//     grapheme clusters, not raw bytes
//   - MaxLines: refuses to insert LF when limit reached
//   - Scroll: FScrollRow tracks which line is at the top of the
//     visible area; adjusted automatically to keep cursor visible

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
  ftui_event;

type
  TInputEditor = class
  private
    FText: AnsiString;
    FCurByte: Integer;       // 0-based byte offset
    FTargetCol: Integer;     // remembered column for ↑↓ movement (-1 = not set)
    FMaxLines: Integer;
    FScrollRow: Integer;

    function LineCount_: Integer;
    procedure CursorToRowCol(out Row, Col: Integer);
    function RowColToByte(Row, Col: Integer): Integer;
    function LineStartByte(Row: Integer): Integer;
    function LineEndByte(Row: Integer): Integer;
    function LineWidth(Row: Integer): Integer;
    procedure EnsureCursorVisible(VisibleHeight: Integer);
    function PrevGraphemeByte: Integer;
    function NextGraphemeByte: Integer;
  public
    constructor Create;
    constructor CreateWithMaxLines(AMax: Integer);

    procedure HandleKey(const K: TKeyEvent);
    procedure InsertChar(Cp: LongWord);
    procedure InsertNewline;
    procedure DeleteBackward;
    procedure DeleteForward;
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveUp;
    procedure MoveDown;
    procedure MoveHome;
    procedure MoveEnd;

    procedure Render(const Area: TRect; ABuf: TBuffer;
      const TextSty, PlaceholderSty: TStyle;
      const Placeholder: AnsiString);
    function CursorScreenPos(const Area: TRect): TPosition;

    procedure Clear;
    function Content: AnsiString;
    function IsEmpty: Boolean; inline;
    function LineCount: Integer; inline;

    property MaxLines: Integer read FMaxLines write FMaxLines;
    property ScrollRow: Integer read FScrollRow;
  end;

implementation

// Encode UCS-4 to UTF-8.
function Ucs4ToUtf8(Cp: LongWord): AnsiString;
begin
  if Cp < $80 then begin SetLength(Result, 1); Result[1] := AnsiChar(Cp); end
  else if Cp < $800 then begin SetLength(Result, 2); Result[1] := AnsiChar($C0 or (Cp shr 6)); Result[2] := AnsiChar($80 or (Cp and $3F)); end
  else if Cp < $10000 then begin SetLength(Result, 3); Result[1] := AnsiChar($E0 or (Cp shr 12)); Result[2] := AnsiChar($80 or ((Cp shr 6) and $3F)); Result[3] := AnsiChar($80 or (Cp and $3F)); end
  else begin SetLength(Result, 4); Result[1] := AnsiChar($F0 or (Cp shr 18)); Result[2] := AnsiChar($80 or ((Cp shr 12) and $3F)); Result[3] := AnsiChar($80 or ((Cp shr 6) and $3F)); Result[4] := AnsiChar($80 or (Cp and $3F)); end;
end;

{ TInputEditor }

constructor TInputEditor.Create;
begin
  inherited;
  FText := '';
  FCurByte := 0;
  FTargetCol := -1;
  FMaxLines := 4;
  FScrollRow := 0;
end;

constructor TInputEditor.CreateWithMaxLines(AMax: Integer);
begin
  Create;
  FMaxLines := AMax;
end;

function TInputEditor.LineCount_: Integer;
var I: Integer;
begin
  Result := 1;
  for I := 1 to Length(FText) do
    if FText[I] = #10 then Inc(Result);
end;

function TInputEditor.LineCount: Integer;
begin
  Result := LineCount_;
end;

function TInputEditor.IsEmpty: Boolean;
begin
  Result := Length(FText) = 0;
end;

function TInputEditor.Content: AnsiString;
begin
  Result := FText;
end;

procedure TInputEditor.Clear;
begin
  FText := '';
  FCurByte := 0;
  FTargetCol := -1;
  FScrollRow := 0;
end;

// Find the byte offset where line `Row` starts (0-based row).
function TInputEditor.LineStartByte(Row: Integer): Integer;
var I, R: Integer;
begin
  if Row <= 0 then Exit(0);
  R := 0;
  for I := 1 to Length(FText) do
  begin
    if FText[I] = #10 then
    begin
      Inc(R);
      if R = Row then Exit(I);  // byte after the LF
    end;
  end;
  Result := Length(FText);
end;

// Find the byte offset just past the last char of line `Row` (before LF or EOF).
function TInputEditor.LineEndByte(Row: Integer): Integer;
var I, R: Integer;
begin
  R := 0;
  for I := 1 to Length(FText) do
  begin
    if FText[I] = #10 then
    begin
      if R = Row then Exit(I - 1);
      Inc(R);
    end;
  end;
  Result := Length(FText);
end;

// Display width of line `Row`.
function TInputEditor.LineWidth(Row: Integer): Integer;
var StartB, EndB: Integer;
begin
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  if EndB < StartB then Exit(0);
  Result := GraphemeWidth(Copy(FText, StartB + 1, EndB - StartB));
end;

// Convert FCurByte to (Row, Col) where Col is display columns.
procedure TInputEditor.CursorToRowCol(out Row, Col: Integer);
var P: Integer; Adv: TGraphemeAdvance;
begin
  Row := 0;
  Col := 0;
  P := 0;
  while P < FCurByte do
  begin
    if (P < Length(FText)) and (FText[P + 1] = #10) then
    begin
      Inc(Row);
      Col := 0;
      Inc(P);
    end
    else if P < Length(FText) then
    begin
      Adv := GraphemeAdvance(FText[1], Length(FText), P);
      Inc(Col, Adv.Width);
      Inc(P, Adv.ByteLen);
    end
    else
      Break;
  end;
end;

// Convert (Row, Col) to byte offset.  If Col exceeds line width,
// clamps to end of line.
function TInputEditor.RowColToByte(Row, Col: Integer): Integer;
var StartB, EndB, P, C: Integer; Adv: TGraphemeAdvance;
begin
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  P := StartB;
  C := 0;
  while (P < EndB) and (C < Col) do
  begin
    Adv := GraphemeAdvance(FText[1], Length(FText), P);
    if C + Adv.Width > Col then Break;
    Inc(C, Adv.Width);
    Inc(P, Adv.ByteLen);
  end;
  Result := P;
end;

procedure TInputEditor.EnsureCursorVisible(VisibleHeight: Integer);
var Row, Col: Integer;
begin
  if VisibleHeight <= 0 then Exit;
  CursorToRowCol(Row, Col);
  if Row < FScrollRow then
    FScrollRow := Row;
  if Row >= FScrollRow + VisibleHeight then
    FScrollRow := Row - VisibleHeight + 1;
end;

function TInputEditor.PrevGraphemeByte: Integer;
var P: Integer; Adv: TGraphemeAdvance;
begin
  // Walk forward from start to find the grapheme ending at FCurByte.
  Result := FCurByte;
  if FCurByte <= 0 then Exit(0);
  P := 0;
  Result := 0;
  while P < FCurByte do
  begin
    Result := P;
    if FText[P + 1] = #10 then
      Inc(P)
    else
    begin
      Adv := GraphemeAdvance(FText[1], Length(FText), P);
      Inc(P, Adv.ByteLen);
    end;
  end;
end;

function TInputEditor.NextGraphemeByte: Integer;
var Adv: TGraphemeAdvance;
begin
  if FCurByte >= Length(FText) then Exit(FCurByte);
  if FText[FCurByte + 1] = #10 then
    Result := FCurByte + 1
  else
  begin
    Adv := GraphemeAdvance(FText[1], Length(FText), FCurByte);
    Result := FCurByte + Adv.ByteLen;
  end;
end;

procedure TInputEditor.InsertChar(Cp: LongWord);
var S: AnsiString;
begin
  if Cp = 10 then begin InsertNewline; Exit; end;
  if Cp < 32 then Exit;
  S := Ucs4ToUtf8(Cp);
  Insert(S, FText, FCurByte + 1);
  Inc(FCurByte, Length(S));
  FTargetCol := -1;
end;

procedure TInputEditor.InsertNewline;
begin
  if LineCount_ >= FMaxLines then Exit;
  Insert(#10, FText, FCurByte + 1);
  Inc(FCurByte);
  FTargetCol := -1;
end;

procedure TInputEditor.DeleteBackward;
var Prev: Integer;
begin
  if FCurByte <= 0 then Exit;
  Prev := PrevGraphemeByte;
  Delete(FText, Prev + 1, FCurByte - Prev);
  FCurByte := Prev;
  FTargetCol := -1;
end;

procedure TInputEditor.DeleteForward;
var Next: Integer;
begin
  if FCurByte >= Length(FText) then Exit;
  Next := NextGraphemeByte;
  Delete(FText, FCurByte + 1, Next - FCurByte);
  FTargetCol := -1;
end;

procedure TInputEditor.MoveLeft;
begin
  if FCurByte > 0 then
    FCurByte := PrevGraphemeByte;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveRight;
begin
  if FCurByte < Length(FText) then
    FCurByte := NextGraphemeByte;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveUp;
var Row, Col, Target: Integer;
begin
  CursorToRowCol(Row, Col);
  if Row <= 0 then Exit;
  if FTargetCol < 0 then FTargetCol := Col;
  Target := FTargetCol;
  FCurByte := RowColToByte(Row - 1, Target);
end;

procedure TInputEditor.MoveDown;
var Row, Col, Target: Integer;
begin
  CursorToRowCol(Row, Col);
  if Row >= LineCount_ - 1 then Exit;
  if FTargetCol < 0 then FTargetCol := Col;
  Target := FTargetCol;
  FCurByte := RowColToByte(Row + 1, Target);
end;

procedure TInputEditor.MoveHome;
var Row, Col: Integer;
begin
  CursorToRowCol(Row, Col);
  FCurByte := LineStartByte(Row);
  FTargetCol := -1;
end;

procedure TInputEditor.MoveEnd;
var Row, Col: Integer;
begin
  CursorToRowCol(Row, Col);
  FCurByte := LineEndByte(Row);
  FTargetCol := -1;
end;

procedure TInputEditor.HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcChar:
      InsertChar(K.Ch);
    kcEnter:
      if (kmShift in K.Modifiers) or (kmAlt in K.Modifiers) then
        InsertNewline
      else
        ;  // caller handles plain Enter (send message)
    kcBackspace:
      DeleteBackward;
    kcDelete:
      DeleteForward;
    kcLeft:
      MoveLeft;
    kcRight:
      MoveRight;
    kcUp:
      MoveUp;
    kcDown:
      MoveDown;
    kcHome:
      MoveHome;
    kcEnd:
      MoveEnd;
  else
  end;
end;

procedure TInputEditor.Render(const Area: TRect; ABuf: TBuffer;
  const TextSty, PlaceholderSty: TStyle;
  const Placeholder: AnsiString);
var
  VisH, Row, I, StartB, EndB, DrawRow: Integer;
  LineStr: AnsiString;
begin
  VisH := Area.Height;
  if VisH <= 0 then Exit;
  EnsureCursorVisible(VisH);

  if IsEmpty then
  begin
    ABuf.SetStringN(Area.X, Area.Y, Placeholder, Area.Width, PlaceholderSty);
    Exit;
  end;

  Row := 0;
  I := 0;
  // Skip to FScrollRow.
  while (Row < FScrollRow) and (I < Length(FText)) do
  begin
    if FText[I + 1] = #10 then Inc(Row);
    Inc(I);
  end;

  DrawRow := 0;
  StartB := I;
  while (DrawRow < VisH) and (StartB <= Length(FText)) do
  begin
    // Find end of this line.
    EndB := StartB;
    while (EndB < Length(FText)) and (FText[EndB + 1] <> #10) do
      Inc(EndB);
    LineStr := Copy(FText, StartB + 1, EndB - StartB);
    ABuf.SetStringN(Area.X, Area.Y + DrawRow, LineStr, Area.Width, TextSty);
    Inc(DrawRow);
    // Advance past LF to start of next line.
    // EndB points to the last byte before LF (or end of text).
    // FText[EndB+1] is the LF byte.  Next line starts at EndB+2 (0-based: EndB+1).
    if (EndB < Length(FText)) and (FText[EndB + 1] = #10) then
      StartB := EndB + 1       // now StartB is the 0-based index of the byte AFTER LF
    else
      Break;
  end;
end;

function TInputEditor.CursorScreenPos(const Area: TRect): TPosition;
var Row, Col: Integer;
begin
  CursorToRowCol(Row, Col);
  Result.X := Area.X + Col;
  Result.Y := Area.Y + (Row - FScrollRow);
end;

end.
