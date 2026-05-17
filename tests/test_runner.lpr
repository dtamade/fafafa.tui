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
  test_buffer;

var
  Failed: Integer;
begin
  RegisterRectTests;
  RegisterColorTests;
  RegisterModifierTests;
  RegisterStyleTests;
  RegisterCellTests;
  RegisterBufferTests;
  Failed := RunAllTests;
  if Failed = 0 then
    Halt(0)
  else
    Halt(1);
end.
