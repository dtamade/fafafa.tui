program test_runner;

// Master test runner. Each tests/test_<unit>.pas registers its tests
// here; we then dispatch to ftui_testkit.RunAllTests.
//
// Add new test units to both the `uses` and the registration block.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_testkit,
  test_rect;

var
  Failed: Integer;
begin
  RegisterRectTests;
  Failed := RunAllTests;
  if Failed = 0 then
    Halt(0)
  else
    Halt(1);
end.
