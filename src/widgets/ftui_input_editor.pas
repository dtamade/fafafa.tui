unit ftui_input_editor;

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
    FCurByte: Integer;
    FTargetCol: Integer;
    FMaxLines: Integer;
    FScrollRow: Integer;
    FAnchor: Integer;         // -1 = no selection

    function LineCount_: Integer;
    procedure CursorToRowCol(out Row, Col: Integer);
    function RowColToByte(Row, Col: Integer): Integer;
    function LineStartByte(Row: Integer): Integer;
    function LineEndByte(Row: Integer): Integer;
    function LineWidth(Row: Integer): Integer;
    procedure EnsureCursorVisible(VisibleHeight: Integer);
    function PrevGraphemeByte: Integer;
    function NextGraphemeByte: Integer;

    function HasSelection: Boolean; inline;
    procedure ClearSelection; inline;
    procedure SelectionRange(out SelStart, SelEnd: Integer);
    function SelectedText: AnsiString;
    procedure DeleteSelection;

    procedure PushUndo;
    function IsWordByte(B: Byte): Boolean; inline;
    function PrevWordBoundary: Integer;
    function NextWordBoundary: Integer;
    procedure MoveLeftInternal(Selecting: Boolean);
    procedure MoveRightInternal(Selecting: Boolean);
    procedure MoveUpInternal(Selecting: Boolean);
    procedure MoveDownInternal(Selecting: Boolean);
    procedure MoveHomeInternal(Selecting: Boolean);
    procedure MoveEndInternal(Selecting: Boolean);
    procedure MoveWordLeftInternal(Selecting: Boolean);
    procedure MoveWordRightInternal(Selecting: Boolean);
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
    procedure MoveWordLeft;
    procedure MoveWordRight;

    procedure SelectAll;
    procedure CopySelection;
    procedure CutSelection;
    procedure Paste;
    procedure DeleteLine;
    procedure Undo;
    procedure Redo;

    procedure Render(const Area: TRect; ABuf: TBuffer;
      const TextSty, PlaceholderSty: TStyle;
      const Placeholder: AnsiString); overload;
    procedure Render(const Area: TRect; ABuf: TBuffer;
      const TextSty, PlaceholderSty, SelectionSty: TStyle;
      const Placeholder: AnsiString); overload;
    function CursorScreenPos(const Area: TRect): TPosition;

    procedure Clear;
    function Content: AnsiString;
    function IsEmpty: Boolean; inline;
    function LineCount: Integer; inline;

    property MaxLines: Integer read FMaxLines write FMaxLines;
    property ScrollRow: Integer read FScrollRow;
  end;

implementation

const
  UNDO_MAX = 100;

type
  TEditorSnapshot = record
    Text: AnsiString;
    CurByte: Integer;
    Anchor: Integer;
  end;

var
  GClipboard: AnsiString = '';
  GUndoStack: array[0..UNDO_MAX-1] of TEditorSnapshot;
  GUndoCount: Integer = 0;
  GRedoStack: array[0..UNDO_MAX-1] of TEditorSnapshot;
  GRedoCount: Integer = 0;

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
  FAnchor := -1;
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
  FAnchor := -1;
end;

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
      if R = Row then Exit(I);
    end;
  end;
  Result := Length(FText);
end;

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

function TInputEditor.LineWidth(Row: Integer): Integer;
var StartB, EndB: Integer;
begin
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  if EndB < StartB then Exit(0);
  Result := GraphemeWidth(Copy(FText, StartB + 1, EndB - StartB));
end;

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

{ Selection }

function TInputEditor.HasSelection: Boolean;
begin
  Result := (FAnchor >= 0) and (FAnchor <> FCurByte);
end;

procedure TInputEditor.ClearSelection;
begin
  FAnchor := -1;
end;

procedure TInputEditor.SelectionRange(out SelStart, SelEnd: Integer);
begin
  if FAnchor < FCurByte then begin SelStart := FAnchor; SelEnd := FCurByte; end
  else begin SelStart := FCurByte; SelEnd := FAnchor; end;
end;

function TInputEditor.SelectedText: AnsiString;
var S, E: Integer;
begin
  if not HasSelection then Exit('');
  SelectionRange(S, E);
  Result := Copy(FText, S + 1, E - S);
end;

procedure TInputEditor.DeleteSelection;
var S, E: Integer;
begin
  if not HasSelection then Exit;
  SelectionRange(S, E);
  Delete(FText, S + 1, E - S);
  FCurByte := S;
  FAnchor := -1;
end;
{ Undo/Redo }

procedure TInputEditor.PushUndo;
var Snap: TEditorSnapshot;
begin
  Snap.Text := FText;
  Snap.CurByte := FCurByte;
  Snap.Anchor := FAnchor;
  if GUndoCount < UNDO_MAX then
  begin
    GUndoStack[GUndoCount] := Snap;
    Inc(GUndoCount);
  end
  else
  begin
    Move(GUndoStack[1], GUndoStack[0], (UNDO_MAX - 1) * SizeOf(TEditorSnapshot));
    GUndoStack[UNDO_MAX - 1] := Snap;
  end;
  GRedoCount := 0;
end;

procedure TInputEditor.Undo;
var Snap, Curr: TEditorSnapshot;
begin
  if GUndoCount = 0 then Exit;
  Curr.Text := FText;
  Curr.CurByte := FCurByte;
  Curr.Anchor := FAnchor;
  if GRedoCount < UNDO_MAX then
  begin
    GRedoStack[GRedoCount] := Curr;
    Inc(GRedoCount);
  end;
  Dec(GUndoCount);
  Snap := GUndoStack[GUndoCount];
  FText := Snap.Text;
  FCurByte := Snap.CurByte;
  FAnchor := Snap.Anchor;
  FTargetCol := -1;
end;

procedure TInputEditor.Redo;
var Snap, Curr: TEditorSnapshot;
begin
  if GRedoCount = 0 then Exit;
  Curr.Text := FText;
  Curr.CurByte := FCurByte;
  Curr.Anchor := FAnchor;
  if GUndoCount < UNDO_MAX then
  begin
    GUndoStack[GUndoCount] := Curr;
    Inc(GUndoCount);
  end;
  Dec(GRedoCount);
  Snap := GRedoStack[GRedoCount];
  FText := Snap.Text;
  FCurByte := Snap.CurByte;
  FAnchor := Snap.Anchor;
  FTargetCol := -1;
end;

{ Word boundaries }

function TInputEditor.IsWordByte(B: Byte): Boolean;
begin
  Result := (B >= Ord('A')) and (B <= Ord('Z')) or
            (B >= Ord('a')) and (B <= Ord('z')) or
            (B >= Ord('0')) and (B <= Ord('9')) or
            (B = Ord('_')) or (B >= 128);
end;

function TInputEditor.PrevWordBoundary: Integer;
var P: Integer;
begin
  P := FCurByte;
  if P <= 0 then Exit(0);
  Dec(P);
  while (P > 0) and not IsWordByte(Byte(FText[P + 1])) do Dec(P);
  while (P > 0) and IsWordByte(Byte(FText[P])) do Dec(P);
  Result := P;
end;

function TInputEditor.NextWordBoundary: Integer;
var P, Len: Integer;
begin
  Len := Length(FText);
  P := FCurByte;
  if P >= Len then Exit(Len);
  while (P < Len) and IsWordByte(Byte(FText[P + 1])) do Inc(P);
  while (P < Len) and not IsWordByte(Byte(FText[P + 1])) do Inc(P);
  Result := P;
end;
{ Movement internals }

procedure TInputEditor.MoveLeftInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else if HasSelection then begin SelectionRange(FCurByte, FAnchor); FCurByte := FCurByte; ClearSelection; FTargetCol := -1; Exit; end
  else ClearSelection;
  if FCurByte > 0 then
    FCurByte := PrevGraphemeByte;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveRightInternal(Selecting: Boolean);
var Dummy: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else if HasSelection then begin SelectionRange(Dummy, FCurByte); ClearSelection; FTargetCol := -1; Exit; end
  else ClearSelection;
  if FCurByte < Length(FText) then
    FCurByte := NextGraphemeByte;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveUpInternal(Selecting: Boolean);
var Row, Col, Target: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  if Row <= 0 then Exit;
  if FTargetCol < 0 then FTargetCol := Col;
  Target := FTargetCol;
  FCurByte := RowColToByte(Row - 1, Target);
end;

procedure TInputEditor.MoveDownInternal(Selecting: Boolean);
var Row, Col, Target: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  if Row >= LineCount_ - 1 then Exit;
  if FTargetCol < 0 then FTargetCol := Col;
  Target := FTargetCol;
  FCurByte := RowColToByte(Row + 1, Target);
end;

procedure TInputEditor.MoveHomeInternal(Selecting: Boolean);
var Row, Col: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  FCurByte := LineStartByte(Row);
  FTargetCol := -1;
end;

procedure TInputEditor.MoveEndInternal(Selecting: Boolean);
var Row, Col: Integer;
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  CursorToRowCol(Row, Col);
  FCurByte := LineEndByte(Row);
  FTargetCol := -1;
end;

procedure TInputEditor.MoveWordLeftInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  FCurByte := PrevWordBoundary;
  FTargetCol := -1;
end;

procedure TInputEditor.MoveWordRightInternal(Selecting: Boolean);
begin
  if Selecting then begin if FAnchor < 0 then FAnchor := FCurByte; end
  else ClearSelection;
  FCurByte := NextWordBoundary;
  FTargetCol := -1;
end;
{ Public movement (non-selecting) }

procedure TInputEditor.MoveLeft;      begin MoveLeftInternal(False); end;
procedure TInputEditor.MoveRight;     begin MoveRightInternal(False); end;
procedure TInputEditor.MoveUp;        begin MoveUpInternal(False); end;
procedure TInputEditor.MoveDown;      begin MoveDownInternal(False); end;
procedure TInputEditor.MoveHome;      begin MoveHomeInternal(False); end;
procedure TInputEditor.MoveEnd;       begin MoveEndInternal(False); end;
procedure TInputEditor.MoveWordLeft;  begin MoveWordLeftInternal(False); end;
procedure TInputEditor.MoveWordRight; begin MoveWordRightInternal(False); end;

{ Editing operations }

procedure TInputEditor.InsertChar(Cp: LongWord);
var S: AnsiString;
begin
  if Cp = 10 then begin InsertNewline; Exit; end;
  if Cp < 32 then Exit;
  PushUndo;
  if HasSelection then DeleteSelection;
  S := Ucs4ToUtf8(Cp);
  Insert(S, FText, FCurByte + 1);
  Inc(FCurByte, Length(S));
  FTargetCol := -1;
end;

procedure TInputEditor.InsertNewline;
begin
  if LineCount_ >= FMaxLines then Exit;
  PushUndo;
  if HasSelection then DeleteSelection;
  Insert(#10, FText, FCurByte + 1);
  Inc(FCurByte);
  FTargetCol := -1;
end;

procedure TInputEditor.DeleteBackward;
var Prev: Integer;
begin
  if HasSelection then begin PushUndo; DeleteSelection; FTargetCol := -1; Exit; end;
  if FCurByte <= 0 then Exit;
  PushUndo;
  Prev := PrevGraphemeByte;
  Delete(FText, Prev + 1, FCurByte - Prev);
  FCurByte := Prev;
  FTargetCol := -1;
end;

procedure TInputEditor.DeleteForward;
var Next: Integer;
begin
  if HasSelection then begin PushUndo; DeleteSelection; FTargetCol := -1; Exit; end;
  if FCurByte >= Length(FText) then Exit;
  PushUndo;
  Next := NextGraphemeByte;
  Delete(FText, FCurByte + 1, Next - FCurByte);
  FTargetCol := -1;
end;

{ Clipboard }

procedure TInputEditor.SelectAll;
begin
  FAnchor := 0;
  FCurByte := Length(FText);
  FTargetCol := -1;
end;

procedure TInputEditor.CopySelection;
begin
  if HasSelection then
    GClipboard := SelectedText;
end;

procedure TInputEditor.CutSelection;
begin
  if not HasSelection then Exit;
  GClipboard := SelectedText;
  PushUndo;
  DeleteSelection;
  FTargetCol := -1;
end;

procedure TInputEditor.Paste;
var I, NewLines, CurLines: Integer;
    Clipped: AnsiString;
begin
  if GClipboard = '' then Exit;
  PushUndo;
  if HasSelection then DeleteSelection;
  Clipped := GClipboard;
  CurLines := LineCount_;
  NewLines := 0;
  for I := 1 to Length(Clipped) do
    if Clipped[I] = #10 then Inc(NewLines);
  if CurLines + NewLines > FMaxLines then
  begin
    NewLines := FMaxLines - CurLines;
    if NewLines < 0 then NewLines := 0;
    I := 0;
    while (I < Length(Clipped)) and (NewLines >= 0) do
    begin
      Inc(I);
      if Clipped[I] = #10 then
      begin
        Dec(NewLines);
        if NewLines < 0 then begin Clipped := Copy(Clipped, 1, I - 1); Break; end;
      end;
    end;
  end;
  Insert(Clipped, FText, FCurByte + 1);
  Inc(FCurByte, Length(Clipped));
  FTargetCol := -1;
end;

procedure TInputEditor.DeleteLine;
var Row, Col, StartB, EndB: Integer;
begin
  PushUndo;
  CursorToRowCol(Row, Col);
  StartB := LineStartByte(Row);
  EndB := LineEndByte(Row);
  if (EndB < Length(FText)) and (FText[EndB + 1] = #10) then
    Inc(EndB);
  if EndB < StartB then EndB := StartB;
  Delete(FText, StartB + 1, EndB - StartB);
  FCurByte := StartB;
  if FCurByte > Length(FText) then FCurByte := Length(FText);
  FAnchor := -1;
  FTargetCol := -1;
end;
{ HandleKey }

procedure TInputEditor.HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcChar:
      if kmCtrl in K.Modifiers then
      begin
        case K.Ch of
          Ord('a'), Ord('A'): SelectAll;
          Ord('c'), Ord('C'): CopySelection;
          Ord('x'), Ord('X'): CutSelection;
          Ord('v'), Ord('V'): Paste;
          Ord('z'), Ord('Z'):
            if kmShift in K.Modifiers then Redo else Undo;
          Ord('y'), Ord('Y'): Redo;
          Ord('d'), Ord('D'): DeleteLine;
        else
          InsertChar(K.Ch);
        end;
      end
      else
        InsertChar(K.Ch);
    kcEnter:
      if (kmShift in K.Modifiers) or (kmAlt in K.Modifiers) then
        InsertNewline;
    kcBackspace:
      DeleteBackward;
    kcDelete:
      DeleteForward;
    kcLeft:
      if kmCtrl in K.Modifiers then
        MoveWordLeftInternal(kmShift in K.Modifiers)
      else
        MoveLeftInternal(kmShift in K.Modifiers);
    kcRight:
      if kmCtrl in K.Modifiers then
        MoveWordRightInternal(kmShift in K.Modifiers)
      else
        MoveRightInternal(kmShift in K.Modifiers);
    kcUp:
      MoveUpInternal(kmShift in K.Modifiers);
    kcDown:
      MoveDownInternal(kmShift in K.Modifiers);
    kcHome:
      MoveHomeInternal(kmShift in K.Modifiers);
    kcEnd:
      MoveEndInternal(kmShift in K.Modifiers);
  else
  end;
end;
{ Render }

procedure TInputEditor.Render(const Area: TRect; ABuf: TBuffer;
  const TextSty, PlaceholderSty: TStyle;
  const Placeholder: AnsiString);
begin
  Render(Area, ABuf, TextSty, PlaceholderSty, TStyle.Default, Placeholder);
end;

procedure TInputEditor.Render(const Area: TRect; ABuf: TBuffer;
  const TextSty, PlaceholderSty, SelectionSty: TStyle;
  const Placeholder: AnsiString);
var
  VisH, Row, I, StartB, EndB, DrawRow: Integer;
  LineStr: AnsiString;
  SelStart, SelEnd: Integer;
  SelActive: Boolean;
  LineByteStart, Col, P: Integer;
  Adv: TGraphemeAdvance;
  SelColStart, SelColEnd, C: Integer;
  SelRect: TRect;
begin
  VisH := Area.Height;
  if VisH <= 0 then Exit;
  EnsureCursorVisible(VisH);

  if IsEmpty then
  begin
    ABuf.SetStringN(Area.X, Area.Y, Placeholder, Area.Width, PlaceholderSty);
    Exit;
  end;

  SelActive := HasSelection;
  if SelActive then SelectionRange(SelStart, SelEnd)
  else begin SelStart := 0; SelEnd := 0; end;

  Row := 0;
  I := 0;
  while (Row < FScrollRow) and (I < Length(FText)) do
  begin
    if FText[I + 1] = #10 then Inc(Row);
    Inc(I);
  end;

  DrawRow := 0;
  StartB := I;
  while (DrawRow < VisH) and (StartB <= Length(FText)) do
  begin
    EndB := StartB;
    while (EndB < Length(FText)) and (FText[EndB + 1] <> #10) do
      Inc(EndB);
    LineStr := Copy(FText, StartB + 1, EndB - StartB);
    ABuf.SetStringN(Area.X, Area.Y + DrawRow, LineStr, Area.Width, TextSty);

    if SelActive and (SelStart < EndB) and (SelEnd > StartB) then
    begin
      LineByteStart := StartB;
      SelColStart := 0;
      SelColEnd := 0;
      P := LineByteStart;
      Col := 0;
      while P < EndB do
      begin
        if P = SelStart then SelColStart := Col
        else if P < SelStart then SelColStart := Col + 1;
        if FText[P + 1] = #10 then Break;
        Adv := GraphemeAdvance(FText[1], Length(FText), P);
        Inc(Col, Adv.Width);
        Inc(P, Adv.ByteLen);
        if P <= SelEnd then SelColEnd := Col;
      end;
      if SelStart <= LineByteStart then SelColStart := 0;
      if SelEnd >= EndB then SelColEnd := Col;
      if SelColEnd > SelColStart then
      begin
        C := SelColEnd - SelColStart;
        if C > Area.Width - SelColStart then C := Area.Width - SelColStart;
        SelRect := TRect.Make(Area.X + SelColStart, Area.Y + DrawRow, C, 1);
        ABuf.SetStyle(SelRect, SelectionSty);
      end;
    end;

    Inc(DrawRow);
    if (EndB < Length(FText)) and (FText[EndB + 1] = #10) then
      StartB := EndB + 1
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
