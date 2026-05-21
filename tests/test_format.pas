unit test_format;

{$mode objfpc}{$H+}

interface

procedure RegisterFormatTests;

implementation

uses
  ftui_testkit,
  ftui_format;

procedure Test_FormatBytesSmall;
begin
  AssertEqStr('0 B', FormatBytes(0), '0 bytes');
  AssertEqStr('512 B', FormatBytes(512), '512 bytes');
  AssertEqStr('1023 B', FormatBytes(1023), 'below 1 KB');
end;

procedure Test_FormatBytesKilobytes;
begin
  AssertEqStr('1 KB', FormatBytes(1024), 'exactly 1 KB');
  AssertEqStr('1.5 KB', FormatBytes(1536), '1.5 KB');
  AssertEqStr('10 KB', FormatBytes(10240), '10 KB');
  AssertEqStr('999 KB', FormatBytes(999 * 1024), '999 KB');
end;

procedure Test_FormatBytesMegabytes;
begin
  AssertEqStr('1 MB', FormatBytes(1024 * 1024), 'exactly 1 MB');
  AssertEqStr('1.5 MB', FormatBytes(1536 * 1024), '1.5 MB');
  AssertEqStr('512 MB', FormatBytes(512 * 1024 * 1024), '512 MB');
end;

procedure Test_FormatBytesGigabytes;
begin
  AssertEqStr('1 GB', FormatBytes(Int64(1024) * 1024 * 1024), '1 GB');
  AssertEqStr('2.5 GB', FormatBytes(Int64(2560) * 1024 * 1024), '2.5 GB');
end;

procedure Test_FormatBytesKBHelper;
begin
  AssertEqStr('1 MB', FormatBytesKB(1024), '1024 KB = 1 MB');
  AssertEqStr('512 KB', FormatBytesKB(512), '512 KB');
  AssertEqStr('1 GB', FormatBytesKB(1024 * 1024), '1M KB = 1 GB');
end;

procedure RegisterFormatTests;
begin
  RegisterTest('format / bytes small',      @Test_FormatBytesSmall);
  RegisterTest('format / bytes kilobytes',  @Test_FormatBytesKilobytes);
  RegisterTest('format / bytes megabytes',  @Test_FormatBytesMegabytes);
  RegisterTest('format / bytes gigabytes',  @Test_FormatBytesGigabytes);
  RegisterTest('format / bytes KB helper',  @Test_FormatBytesKBHelper);
end;

end.
