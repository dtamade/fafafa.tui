unit test_input;

{$mode objfpc}{$H+}

interface

procedure RegisterInputTests;

implementation

uses
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
  S.InsertChar(Ord('a'));
  S.InsertChar(Ord('b'));
  S.InsertChar(Ord('c'));
  AssertEqStr('abc', S.Text, 'inserted abc');
  AssertEqInt(3, S.Cursor, 'cursor at 3');
end;

procedure Test_InsertMiddle;
var S: TInputState;
begin
  S := TInputState.WithText('ac');
  S.Cursor := 1;
  S.InsertChar(Ord('b'));
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

procedure Test_CJKInsertAndMove;
var S: TInputState;
begin
  S := TInputState.Empty;
  S.InsertChar($4F60);  // 你 (3 bytes, width 2)
  S.InsertChar($597D);  // 好 (3 bytes, width 2)
  AssertEqInt(6, S.Cursor, 'cjk: cursor at end (6 bytes)');
  AssertEqInt(4, S.TextWidth, 'cjk: text width 4 cols');
  AssertEqInt(4, S.CursorCol, 'cjk: cursor col 4');
  S.MoveLeft;
  AssertEqInt(3, S.Cursor, 'cjk: move left to byte 3');
  AssertEqInt(2, S.CursorCol, 'cjk: cursor col 2 after move left');
  S.DeleteBack;
  AssertEqInt(0, S.Cursor, 'cjk: cursor at 0 after delete');
end;

procedure Test_CJKMask;
var S: TInputState; Inp: TInput; Buf: TBuffer;
begin
  S := TInputState.Empty;
  S.InsertChar($4F60);
  S.InsertChar($597D);
  S.InsertChar(Ord('!'));
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  Inp := TInput.Default.WithMask('*');
  Inp.RenderStateful(TRect.Make(0, 0, 20, 1), Buf, S);
  AssertTrue(Pos('***', Buf.RowAsString(0)) > 0, 'mask: 3 graphemes = 3 asterisks');
  Buf.Free;
end;

procedure Test_CJKMixedNav;
var S: TInputState;
begin
  S := TInputState.Empty;
  S.InsertStr('hi' + #$E4#$BD#$A0#$E5#$A5#$BD + 'ok');
  // Text = "hi你好ok" (10 bytes)
  AssertEqInt(10, S.Cursor, 'mixed: cursor at end');
  S.MoveHome;
  S.MoveRight; // h
  S.MoveRight; // i
  AssertEqInt(2, S.Cursor, 'mixed: after 2 rights = byte 2');
  S.MoveRight; // 你 (3 bytes)
  AssertEqInt(5, S.Cursor, 'mixed: skip 你 to byte 5');
  S.MoveRight; // 好 (3 bytes)
  AssertEqInt(8, S.Cursor, 'mixed: skip 好 to byte 8');
  S.MoveLeft;  // back to 好 start
  AssertEqInt(5, S.Cursor, 'mixed: left back to byte 5');
  AssertEqInt(4, S.CursorCol, 'mixed: col at byte 5 = 4 (h+i+你)');
end;

procedure Test_CJKDeleteForward;
var S: TInputState;
begin
  S := TInputState.Empty;
  S.InsertChar(Ord('a'));
  S.InsertChar($4F60);  // 你
  S.InsertChar(Ord('b'));
  // Text = "a你b" (5 bytes), Cursor=5
  S.MoveHome;
  S.MoveRight; // skip 'a', Cursor=1
  S.DeleteForward; // delete 你 (3 bytes)
  AssertEqStr('ab', S.Text, 'del fwd: 你 removed');
  AssertEqInt(1, S.Cursor, 'del fwd: cursor stays at 1');
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
  RegisterTest('input / CJK insert+move',   @Test_CJKInsertAndMove);
  RegisterTest('input / CJK mask',          @Test_CJKMask);
  RegisterTest('input / CJK mixed nav',     @Test_CJKMixedNav);
  RegisterTest('input / CJK delete forward', @Test_CJKDeleteForward);
end;

end.
