program test_runner;

// Master test runner. Each tests/test_<unit>.pas registers its tests
// here; we then dispatch to ftui_testkit.RunAllTests.
//
// Add new test units to both the `uses` and the registration block.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_testkit,
  test_rect,
  test_color,
  test_modifier,
  test_style,
  test_cell,
  test_buffer,
  test_bytes,
  test_ansi,
  test_ansi_backend,
  test_text,
  test_layout,
  test_test_backend,
  test_clear,
  test_block,
  test_paragraph,
  test_list,
  test_input_parser,
  test_terminal_smoke,
  test_grapheme,
  test_input_editor;

var
  Failed: Integer;
begin
  RegisterRectTests;
  RegisterColorTests;
  RegisterModifierTests;
  RegisterStyleTests;
  RegisterCellTests;
  RegisterBufferTests;
  RegisterBytesTests;
  RegisterAnsiTests;
  RegisterAnsiBackendTests;
  RegisterTextTests;
  RegisterLayoutTests;
  RegisterTestBackendTests;
  RegisterClearTests;
  RegisterBlockTests;
  RegisterParagraphTests;
  RegisterListTests;
  RegisterInputParserTests;
  RegisterTerminalSmokeTests;
  RegisterGraphemeTests;
  RegisterInputEditorTests;
  Failed := RunAllTests;
  if Failed = 0 then
    Halt(0)
  else
    Halt(1);
end.
