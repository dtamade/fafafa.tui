program test_mini;
{$mode objfpc}{$H+}
uses
  SysUtils,
  ftui_testkit,
  test_theme,
  test_anim;
var
  Failed: Integer;
begin
  RegisterThemeTests;
  RegisterAnimTests;
  Failed := RunAllTests;
  if Failed = 0 then Halt(0) else Halt(1);
end.
