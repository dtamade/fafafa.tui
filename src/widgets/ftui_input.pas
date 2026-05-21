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
  ftui_block;

type
  TInputState = record
    Text: AnsiString;
    Cursor: Integer;
    ScrollX: Integer;

    class function Empty: TInputState; static;
    class function WithText(const S: AnsiString): TInputState; static;
    procedure InsertChar(Ch: Char);
    procedure DeleteBack;
    procedure DeleteForward;
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveHome;
    procedure MoveEnd;
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

uses
  SysUtils;

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

procedure TInputState.InsertChar(Ch: Char);
begin
  Insert(Ch, Text, Cursor + 1);
  Inc(Cursor);
end;

procedure TInputState.DeleteBack;
begin
  if Cursor > 0 then
  begin
    Delete(Text, Cursor, 1);
    Dec(Cursor);
  end;
end;

procedure TInputState.DeleteForward;
begin
  if Cursor < Length(Text) then
    Delete(Text, Cursor + 1, 1);
end;

procedure TInputState.MoveLeft;
begin
  if Cursor > 0 then Dec(Cursor);
end;

procedure TInputState.MoveRight;
begin
  if Cursor < Length(Text) then Inc(Cursor);
end;

procedure TInputState.MoveHome;
begin
  Cursor := 0;
end;

procedure TInputState.MoveEnd;
begin
  Cursor := Length(Text);
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
  VisibleW, CursorX, I: Integer;
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
    DisplayText := StringOfChar(MaskChar, Length(State.Text))
  else
    DisplayText := State.Text;

  // Ensure cursor is visible by adjusting scroll
  if State.Cursor < State.ScrollX then
    State.ScrollX := State.Cursor;
  if State.Cursor >= State.ScrollX + VisibleW then
    State.ScrollX := State.Cursor - VisibleW + 1;
  if State.ScrollX < 0 then State.ScrollX := 0;

  // Render text or placeholder
  if (Length(DisplayText) = 0) and (Length(Placeholder) > 0) then
    ABuf.SetStringN(Inner.X, Inner.Y, Placeholder, VisibleW, PlaceholderStyle)
  else
  begin
    ABuf.SetStringN(Inner.X, Inner.Y,
      Copy(DisplayText, State.ScrollX + 1, VisibleW), VisibleW, Style);
  end;

  // Cursor highlight
  CursorX := State.Cursor - State.ScrollX;
  if (CursorX >= 0) and (CursorX < VisibleW) then
    ABuf.SetStyle(TRect.Make(Inner.X + CursorX, Inner.Y, 1, 1), CursorStyle);
end;

end.
