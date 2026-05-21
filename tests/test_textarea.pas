unit test_textarea;

{$mode objfpc}{$H+}

interface

procedure RegisterTextAreaTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_cell,
  ftui_buffer,
  ftui_textarea;

procedure Test_CreateFromText;
var TA: TTextArea;
begin
  TA := TTextArea.Create('line1' + #10 + 'line2' + #10 + 'line3');
  AssertEqInt(3, TA.LineCount, '3 lines');
  AssertEqStr('line1', TA.Lines[0], 'first line');
  AssertEqStr('line2', TA.Lines[1], 'second line');
  AssertEqStr('line3', TA.Lines[2], 'third line');
end;

procedure Test_FromLines;
var TA: TTextArea;
begin
  TA := TTextArea.FromLines(['alpha', 'beta', 'gamma']);
  AssertEqInt(3, TA.LineCount, '3 lines');
  AssertEqStr('beta', TA.Lines[1], 'second line');
end;

procedure Test_RenderShowsContent;
var
  TA: TTextArea;
  Buf: TBuffer;
  Area: TRect;
  State: TTextAreaState;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  TA := TTextArea.Create('hello' + #10 + 'world');
  State := TTextAreaState.Empty;
  TA.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('hello', Buf.RowAsString(0)) > 0, 'hello visible');
  AssertTrue(Pos('world', Buf.RowAsString(1)) > 0, 'world visible');
  Buf.Free;
end;

procedure Test_LineNumbers;
var
  TA: TTextArea;
  Buf: TBuffer;
  Area: TRect;
  State: TTextAreaState;
begin
  Area := TRect.Make(0, 0, 30, 3);
  Buf := TBuffer.CreateEmpty(Area);
  TA := TTextArea.Create('a' + #10 + 'b' + #10 + 'c').WithShowLineNumbers(True);
  State := TTextAreaState.Empty;
  TA.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('1', Buf.RowAsString(0)) > 0, 'line number 1');
  AssertTrue(Pos('2', Buf.RowAsString(1)) > 0, 'line number 2');
  Buf.Free;
end;

procedure Test_NoLineNumbers;
var
  TA: TTextArea;
  Buf: TBuffer;
  Area: TRect;
  State: TTextAreaState;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 20, 2);
  Buf := TBuffer.CreateEmpty(Area);
  TA := TTextArea.Create('test').WithShowLineNumbers(False);
  State := TTextAreaState.Empty;
  TA.RenderStateful(Area, Buf, State);
  Row := Buf.RowAsString(0);
  AssertTrue(Pos('test', Row) = 1, 'content starts at col 0 without line numbers');
  Buf.Free;
end;

procedure Test_ScrollOnCursor;
var
  TA: TTextArea;
  Buf: TBuffer;
  Area: TRect;
  State: TTextAreaState;
begin
  Area := TRect.Make(0, 0, 20, 3);
  Buf := TBuffer.CreateEmpty(Area);
  TA := TTextArea.FromLines(['a', 'b', 'c', 'd', 'e', 'f']);
  State := TTextAreaState.Empty;
  State.CursorRow := 5;
  TA.RenderStateful(Area, Buf, State);
  AssertTrue(State.ScrollY >= 3, 'scrolled to show cursor at row 5');
  Buf.Free;
end;

procedure Test_CursorHighlight;
var
  TA: TTextArea;
  Buf: TBuffer;
  Area: TRect;
  State: TTextAreaState;
  CP: PCell;
begin
  Area := TRect.Make(0, 0, 20, 3);
  Buf := TBuffer.CreateEmpty(Area);
  TA := TTextArea.Create('hello').WithShowLineNumbers(False)
    .WithCursorStyle(TStyle.Default.WithModifier([mbReversed]));
  State := TTextAreaState.Empty;
  State.CursorRow := 0;
  State.CursorCol := 2;
  TA.RenderStateful(Area, Buf, State);
  CP := Buf.CellAt(2, 0);
  AssertTrue(CP <> nil, 'cell exists');
  AssertTrue(mbReversed in CP^.Modifier, 'cursor cell has reversed');
  Buf.Free;
end;

procedure RegisterTextAreaTests;
begin
  RegisterTest('textarea / create from text',   @Test_CreateFromText);
  RegisterTest('textarea / from lines',         @Test_FromLines);
  RegisterTest('textarea / render shows content', @Test_RenderShowsContent);
  RegisterTest('textarea / line numbers',       @Test_LineNumbers);
  RegisterTest('textarea / no line numbers',    @Test_NoLineNumbers);
  RegisterTest('textarea / scroll on cursor',   @Test_ScrollOnCursor);
  RegisterTest('textarea / cursor highlight',   @Test_CursorHighlight);
end;

end.
