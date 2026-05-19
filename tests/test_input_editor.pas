unit test_input_editor;

{$mode objfpc}{$H+}

interface

procedure RegisterInputEditorTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_event,
  ftui_input_editor;

procedure Test_EmptyOnCreate;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    AssertTrue(E.IsEmpty, 'empty');
    AssertEqInt(1, E.LineCount, 'empty string = 1 line');
    AssertEqStr('', E.Content, 'content empty');
  finally E.Free; end;
end;

procedure Test_InsertAscii;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('h'));
    E.InsertChar(Ord('i'));
    AssertEqStr('hi', E.Content, 'hi');
    AssertEqInt(1, E.LineCount, 'still 1 line');
  finally E.Free; end;
end;

procedure Test_InsertCjk;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar($4F60);   // 你
    E.InsertChar($597D);   // 好
    AssertEqStr(#$E4#$BD#$A0#$E5#$A5#$BD, E.Content, '你好');
  finally E.Free; end;
end;

procedure Test_InsertNewlineAndLineCount;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertNewline;
    E.InsertChar(Ord('b'));
    AssertEqStr('a' + #10 + 'b', E.Content, 'a\\nb');
    AssertEqInt(2, E.LineCount, '2 lines');
  finally E.Free; end;
end;

procedure Test_MaxLinesLimit;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.CreateWithMaxLines(2);
  try
    E.InsertChar(Ord('a'));
    E.InsertNewline;
    E.InsertChar(Ord('b'));
    E.InsertNewline;   // should be refused (already 2 lines)
    E.InsertChar(Ord('c'));
    AssertEqInt(2, E.LineCount, 'still 2 lines');
    AssertEqStr('a' + #10 + 'bc', E.Content, 'LF refused, c appended to line 2');
  finally E.Free; end;
end;

procedure Test_BackspaceAscii;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertChar(Ord('b'));
    E.InsertChar(Ord('c'));
    E.DeleteBackward;
    AssertEqStr('ab', E.Content, 'deleted c');
    E.DeleteBackward;
    AssertEqStr('a', E.Content, 'deleted b');
  finally E.Free; end;
end;

procedure Test_BackspaceCjk;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar($4F60);   // 你 (3 bytes)
    E.InsertChar(Ord('x'));
    E.DeleteBackward;
    AssertEqStr(#$E4#$BD#$A0, E.Content, 'deleted x, 你 remains');
    E.DeleteBackward;
    AssertEqStr('', E.Content, 'deleted 你');
  finally E.Free; end;
end;

procedure Test_BackspaceAcrossLine;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertNewline;
    E.InsertChar(Ord('b'));
    E.MoveHome;          // cursor at start of line 2
    E.DeleteBackward;    // should delete the LF, merging lines
    AssertEqStr('ab', E.Content, 'lines merged');
    AssertEqInt(1, E.LineCount, '1 line after merge');
  finally E.Free; end;
end;

procedure Test_DeleteForward;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertChar(Ord('b'));
    E.MoveLeft;
    E.MoveLeft;
    E.DeleteForward;
    AssertEqStr('b', E.Content, 'deleted a forward');
  finally E.Free; end;
end;

procedure Test_MoveLeftRight;
var E: TInputEditor; Buf2: TBuffer;
    P: TPosition;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertChar(Ord('b'));
    E.InsertChar(Ord('c'));
    // Cursor at end (byte 3).
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 1));
    AssertEqInt(3, P.X, 'cursor at col 3');
    E.MoveLeft;
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 1));
    AssertEqInt(2, P.X, 'after left: col 2');
    E.MoveRight;
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 1));
    AssertEqInt(3, P.X, 'after right: col 3');
  finally E.Free; end;
end;

procedure Test_MoveUpDown;
var E: TInputEditor; Buf2: TBuffer;
    P: TPosition;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertChar(Ord('b'));
    E.InsertChar(Ord('c'));
    E.InsertNewline;
    E.InsertChar(Ord('x'));
    // Cursor at line 1, col 1.
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 5));
    AssertEqInt(1, P.X, 'line 1 col 1');
    AssertEqInt(1, P.Y, 'row 1');
    E.MoveUp;
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 5));
    AssertEqInt(0, P.Y, 'row 0 after up');
    AssertEqInt(1, P.X, 'col 1 preserved (target col)');
    E.MoveDown;
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 5));
    AssertEqInt(1, P.Y, 'row 1 after down');
  finally E.Free; end;
end;

procedure Test_HomeEnd;
var E: TInputEditor; Buf2: TBuffer;
    P: TPosition;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('a'));
    E.InsertChar(Ord('b'));
    E.InsertChar(Ord('c'));
    E.MoveHome;
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 1));
    AssertEqInt(0, P.X, 'home -> col 0');
    E.MoveEnd;
    P := E.CursorScreenPos(TRect.Make(0, 0, 10, 1));
    AssertEqInt(3, P.X, 'end -> col 3');
  finally E.Free; end;
end;

procedure Test_Clear;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.InsertChar(Ord('x'));
    E.InsertNewline;
    E.InsertChar(Ord('y'));
    E.Clear;
    AssertTrue(E.IsEmpty, 'empty after clear');
    AssertEqInt(1, E.LineCount, '1 line after clear');
  finally E.Free; end;
end;

procedure Test_ScrollFollowsCursor;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.CreateWithMaxLines(10);
  try
    E.InsertChar(Ord('1')); E.InsertNewline;
    E.InsertChar(Ord('2')); E.InsertNewline;
    E.InsertChar(Ord('3')); E.InsertNewline;
    E.InsertChar(Ord('4')); E.InsertNewline;
    E.InsertChar(Ord('5'));
    // 5 lines, visible height = 2.  Cursor on line 4.
    // After Render with height 2, ScrollRow should be 3 (shows lines 3-4).
    Buf2 := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
    try E.Render(TRect.Make(0, 0, 10, 2), Buf2, TStyle.Default, TStyle.Default, '');
    finally Buf2.Free; end;
    AssertEqInt(3, E.ScrollRow, 'scroll follows cursor to row 3');
  finally E.Free; end;
end;

procedure Test_HandleKeyShiftEnter;
var E: TInputEditor; Buf2: TBuffer;
begin
  E := TInputEditor.Create;
  try
    E.HandleKey(KeyCharEvent(Ord('a'), []).Key);
    E.HandleKey(KeyCodeEvent(kcEnter, [kmShift]).Key);
    E.HandleKey(KeyCharEvent(Ord('b'), []).Key);
    AssertEqStr('a' + #10 + 'b', E.Content, 'shift+enter inserts newline');
    AssertEqInt(2, E.LineCount, '2 lines');
  finally E.Free; end;
end;

procedure Test_RenderShowsContent;
var
  E: TInputEditor;
  Buf: TBuffer;
begin
  E := TInputEditor.Create;
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    E.InsertChar(Ord('h'));
    E.InsertChar(Ord('i'));
    E.Render(TRect.Make(0, 0, 10, 2), Buf, TStyle.Default, TStyle.Default, 'placeholder');
    AssertBufferEquals(Buf, ['hi        ', '          ']);
  finally Buf.Free; E.Free; end;
end;

procedure Test_RenderShowsPlaceholder;
var
  E: TInputEditor;
  Buf: TBuffer;
begin
  E := TInputEditor.Create;
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 1));
  try
    E.Render(TRect.Make(0, 0, 12, 1), Buf, TStyle.Default, TStyle.Default, 'type here...');
    AssertBufferEquals(Buf, ['type here...']);
  finally Buf.Free; E.Free; end;
end;

procedure RegisterInputEditorTests;
begin
  RegisterTest('input_editor / empty on create',         @Test_EmptyOnCreate);
  RegisterTest('input_editor / insert ASCII',            @Test_InsertAscii);
  RegisterTest('input_editor / insert CJK',             @Test_InsertCjk);
  RegisterTest('input_editor / newline + line count',    @Test_InsertNewlineAndLineCount);
  RegisterTest('input_editor / MaxLines limit',          @Test_MaxLinesLimit);
  RegisterTest('input_editor / backspace ASCII',         @Test_BackspaceAscii);
  RegisterTest('input_editor / backspace CJK',           @Test_BackspaceCjk);
  RegisterTest('input_editor / backspace across line',   @Test_BackspaceAcrossLine);
  RegisterTest('input_editor / delete forward',          @Test_DeleteForward);
  RegisterTest('input_editor / move left/right',         @Test_MoveLeftRight);
  RegisterTest('input_editor / move up/down',            @Test_MoveUpDown);
  RegisterTest('input_editor / home/end',                @Test_HomeEnd);
  RegisterTest('input_editor / clear',                   @Test_Clear);
  RegisterTest('input_editor / scroll follows cursor',   @Test_ScrollFollowsCursor);
  RegisterTest('input_editor / HandleKey shift+enter',   @Test_HandleKeyShiftEnter);
  RegisterTest('input_editor / render shows content',    @Test_RenderShowsContent);
  RegisterTest('input_editor / render shows placeholder',@Test_RenderShowsPlaceholder);
end;

end.
