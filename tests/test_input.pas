unit test_input;

{$mode objfpc}{$H+}

interface

procedure RegisterInputTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_cell,
  ftui_buffer,
  ftui_input;

procedure Test_EmptyState;
var S: TInputState;
begin
  S := TInputState.Empty;
  AssertEqStr('', S.Text, 'empty text');
  AssertEqInt(0, S.Cursor, 'cursor at 0');
end;

procedure Test_WithText;
var S: TInputState;
begin
  S := TInputState.WithText('hello');
  AssertEqStr('hello', S.Text, 'text set');
  AssertEqInt(5, S.Cursor, 'cursor at end');
end;

procedure Test_InsertChar;
var S: TInputState;
begin
  S := TInputState.Empty;
  S.InsertChar('a');
  S.InsertChar('b');
  S.InsertChar('c');
  AssertEqStr('abc', S.Text, 'inserted abc');
  AssertEqInt(3, S.Cursor, 'cursor at 3');
end;

procedure Test_InsertMiddle;
var S: TInputState;
begin
  S := TInputState.WithText('ac');
  S.Cursor := 1;
  S.InsertChar('b');
  AssertEqStr('abc', S.Text, 'insert in middle');
  AssertEqInt(2, S.Cursor, 'cursor after insert');
end;

procedure Test_DeleteBack;
var S: TInputState;
begin
  S := TInputState.WithText('abc');
  S.DeleteBack;
  AssertEqStr('ab', S.Text, 'deleted last');
  AssertEqInt(2, S.Cursor, 'cursor at 2');
  S.Cursor := 0;
  S.DeleteBack;
  AssertEqStr('ab', S.Text, 'no delete at start');
end;

procedure Test_DeleteForward;
var S: TInputState;
begin
  S := TInputState.WithText('abc');
  S.Cursor := 1;
  S.DeleteForward;
  AssertEqStr('ac', S.Text, 'deleted forward');
  AssertEqInt(1, S.Cursor, 'cursor unchanged');
end;

procedure Test_MoveLeftRight;
var S: TInputState;
begin
  S := TInputState.WithText('hi');
  S.MoveLeft;
  AssertEqInt(1, S.Cursor, 'moved left');
  S.MoveLeft;
  AssertEqInt(0, S.Cursor, 'at start');
  S.MoveLeft;
  AssertEqInt(0, S.Cursor, 'clamped at 0');
  S.MoveRight;
  AssertEqInt(1, S.Cursor, 'moved right');
  S.MoveEnd;
  AssertEqInt(2, S.Cursor, 'at end');
  S.MoveRight;
  AssertEqInt(2, S.Cursor, 'clamped at end');
end;

procedure Test_HomeEnd;
var S: TInputState;
begin
  S := TInputState.WithText('hello world');
  S.MoveHome;
  AssertEqInt(0, S.Cursor, 'home');
  S.MoveEnd;
  AssertEqInt(11, S.Cursor, 'end');
end;

procedure Test_RenderShowsText;
var
  Inp: TInput;
  Buf: TBuffer;
  Area: TRect;
  State: TInputState;
begin
  Area := TRect.Make(0, 0, 20, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Inp := TInput.Default;
  State := TInputState.WithText('hello');
  State.Cursor := 0;
  Inp.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('hello', Buf.RowAsString(0)) > 0, 'text visible');
  Buf.Free;
end;

procedure Test_RenderPlaceholder;
var
  Inp: TInput;
  Buf: TBuffer;
  Area: TRect;
  State: TInputState;
begin
  Area := TRect.Make(0, 0, 30, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Inp := TInput.Default.WithPlaceholder('Type here...');
  State := TInputState.Empty;
  Inp.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Type here', Buf.RowAsString(0)) > 0, 'placeholder visible');
  Buf.Free;
end;

procedure Test_RenderMask;
var
  Inp: TInput;
  Buf: TBuffer;
  Area: TRect;
  State: TInputState;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 20, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Inp := TInput.Default.WithMask('*');
  State := TInputState.WithText('secret');
  State.Cursor := 0;
  Inp.RenderStateful(Area, Buf, State);
  Row := Buf.RowAsString(0);
  AssertTrue(Pos('******', Row) > 0, 'masked text');
  AssertTrue(Pos('secret', Row) = 0, 'original hidden');
  Buf.Free;
end;

procedure Test_CursorHighlight;
var
  Inp: TInput;
  Buf: TBuffer;
  Area: TRect;
  State: TInputState;
  CP: PCell;
begin
  Area := TRect.Make(0, 0, 20, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Inp := TInput.Default.WithCursorStyle(TStyle.Default.WithModifier([mbReversed]));
  State := TInputState.WithText('abc');
  State.Cursor := 1;
  Inp.RenderStateful(Area, Buf, State);
  CP := Buf.CellAt(1, 0);
  AssertTrue(CP <> nil, 'cell exists');
  AssertTrue(mbReversed in CP^.Modifier, 'cursor reversed');
  Buf.Free;
end;

procedure Test_ScrollOnLongText;
var
  Inp: TInput;
  Buf: TBuffer;
  Area: TRect;
  State: TInputState;
begin
  Area := TRect.Make(0, 0, 10, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Inp := TInput.Default;
  State := TInputState.WithText('abcdefghijklmnop');
  Inp.RenderStateful(Area, Buf, State);
  AssertTrue(State.ScrollX > 0, 'scrolled for long text');
  Buf.Free;
end;

procedure RegisterInputTests;
begin
  RegisterTest('input / empty state',        @Test_EmptyState);
  RegisterTest('input / with text',          @Test_WithText);
  RegisterTest('input / insert char',        @Test_InsertChar);
  RegisterTest('input / insert middle',      @Test_InsertMiddle);
  RegisterTest('input / delete back',        @Test_DeleteBack);
  RegisterTest('input / delete forward',     @Test_DeleteForward);
  RegisterTest('input / move left right',    @Test_MoveLeftRight);
  RegisterTest('input / home end',           @Test_HomeEnd);
  RegisterTest('input / render shows text',  @Test_RenderShowsText);
  RegisterTest('input / render placeholder', @Test_RenderPlaceholder);
  RegisterTest('input / render mask',        @Test_RenderMask);
  RegisterTest('input / cursor highlight',   @Test_CursorHighlight);
  RegisterTest('input / scroll long text',   @Test_ScrollOnLongText);
end;

end.
