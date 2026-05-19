unit ftui_testkit;

// fafafa.tui test harness.
//
// Tiny, dependency-free assertion + buffer-snapshot helpers shared by
// every test_*.pas unit.
//
// Design points:
//   - No fpcunit, no test discovery: each test_*.pas exports a single
//     `procedure RegisterTests` and the master tests/test_runner.lpr
//     calls them all.
//   - Failing assertions throw EFtuiTestFailed with enough context to
//     locate the call site without a debugger.
//   - AssertBufferEquals is the centerpiece: ratatui-style snapshot
//     comparison.  When a buffer differs from expected, the message
//     contains a row-by-row diff with `*` markers on mismatched rows.

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  ftui_buffer;

type
  EFtuiTestFailed = class(Exception);

  TTestProc = procedure;

  TTestEntry = record
    Name: AnsiString;
    Proc: TTestProc;
  end;

procedure RegisterTest(const AName: AnsiString; AProc: TTestProc);
function RunAllTests: Integer;

procedure Assert_(Cond: Boolean; const Msg: AnsiString);
procedure AssertEqInt(Expected, Actual: Int64; const Ctx: AnsiString);
procedure AssertEqStr(const Expected, Actual: AnsiString; const Ctx: AnsiString);
procedure AssertEqBool(Expected, Actual: Boolean; const Ctx: AnsiString);
procedure AssertTrue(Cond: Boolean; const Ctx: AnsiString);
procedure AssertFalse(Cond: Boolean; const Ctx: AnsiString);

// Compare a live TBuffer against a list of expected row strings.  Each
// line shorter than buffer width is right-padded with spaces; longer
// lines are clipped — same convenience as ratatui Buffer::with_lines.
//
// On mismatch raises EFtuiTestFailed with a row-by-row diff.
procedure AssertBufferEquals(ABuf: TBuffer; const Expected: array of AnsiString);

implementation

var
  GTests: array of TTestEntry;

procedure RegisterTest(const AName: AnsiString; AProc: TTestProc);
var
  N: Integer;
begin
  N := Length(GTests);
  SetLength(GTests, N + 1);
  GTests[N].Name := AName;
  GTests[N].Proc := AProc;
end;

function RunAllTests: Integer;
var
  I, Failed, Ran, Skipped: Integer;
  Started, Filter: AnsiString;
begin
  Failed := 0;
  Ran := 0;
  Skipped := 0;
  Filter := '';
  if ParamCount >= 1 then
    Filter := ParamStr(1);

  if Filter = '' then
    WriteLn(Format('running %d tests', [Length(GTests)]))
  else
    WriteLn(Format('running tests matching "%s"', [Filter]));

  for I := 0 to High(GTests) do
  begin
    Started := GTests[I].Name;
    if (Filter <> '') and (Pos(Filter, Started) = 0) then
    begin
      Inc(Skipped);
      Continue;
    end;
    Inc(Ran);
    try
      GTests[I].Proc();
      WriteLn('  ok      ', Started);
    except
      on E: EFtuiTestFailed do
      begin
        WriteLn('  FAILED  ', Started);
        WriteLn(E.Message);
        Inc(Failed);
      end;
      on E: Exception do
      begin
        WriteLn('  CRASH   ', Started);
        WriteLn('    ', E.ClassName, ': ', E.Message);
        Inc(Failed);
      end;
    end;
  end;
  WriteLn;
  if Failed = 0 then
    WriteLn(Format('all %d tests passed', [Ran]))
  else
    WriteLn(Format('%d / %d tests failed', [Failed, Ran]));
  if Skipped > 0 then
    WriteLn(Format('(%d skipped by filter)', [Skipped]));
  Result := Failed;
end;

procedure Assert_(Cond: Boolean; const Msg: AnsiString);
begin
  if not Cond then
    raise EFtuiTestFailed.Create(Msg);
end;

procedure AssertEqInt(Expected, Actual: Int64; const Ctx: AnsiString);
begin
  if Expected <> Actual then
    raise EFtuiTestFailed.CreateFmt('%s: expected %d, got %d',
      [Ctx, Expected, Actual]);
end;

procedure AssertEqStr(const Expected, Actual: AnsiString; const Ctx: AnsiString);
begin
  if Expected <> Actual then
    raise EFtuiTestFailed.CreateFmt('%s: expected %s, got %s',
      [Ctx, QuotedStr(Expected), QuotedStr(Actual)]);
end;

procedure AssertEqBool(Expected, Actual: Boolean; const Ctx: AnsiString);
begin
  if Expected <> Actual then
    raise EFtuiTestFailed.CreateFmt('%s: expected %s, got %s',
      [Ctx, BoolToStr(Expected, True), BoolToStr(Actual, True)]);
end;

procedure AssertTrue(Cond: Boolean; const Ctx: AnsiString);
begin
  if not Cond then
    raise EFtuiTestFailed.CreateFmt('%s: expected True', [Ctx]);
end;

procedure AssertFalse(Cond: Boolean; const Ctx: AnsiString);
begin
  if Cond then
    raise EFtuiTestFailed.CreateFmt('%s: expected False', [Ctx]);
end;

// Internal: build a single AnsiString carrying the expected/actual diff.
// Cold path so we don't have to micro-optimize allocation.
function FormatDiff(const Expected, Actual: array of AnsiString;
  W: Integer): AnsiString;
var
  I: Integer;
  Marker: AnsiString;
  ExpRow, ActRow: AnsiString;
begin
  Result := 'buffer mismatch (width=' + IntToStr(W) + '):' + LineEnding;
  Result := Result + Format('  row | %-*s | %s', [W, 'expected', 'actual']) + LineEnding;
  for I := 0 to Length(Expected) - 1 do
  begin
    if I < Length(Expected) then ExpRow := Expected[I] else ExpRow := '<missing>';
    if I < Length(Actual)   then ActRow := Actual[I]   else ActRow := '<missing>';
    if ExpRow = ActRow then Marker := '   ' else Marker := ' * ';
    Result := Result + Format(' %s%2d | %-*s | %s',
      [Marker, I, W, ExpRow, ActRow]) + LineEnding;
  end;
end;

procedure AssertBufferEquals(ABuf: TBuffer; const Expected: array of AnsiString);
var
  Actual: TBufferLines;
  ExpectedCopy: array of AnsiString;
  W, I, ExpLen, Mismatches: Integer;
begin
  W := ABuf.Width;
  if Length(Expected) <> ABuf.Height then
    raise EFtuiTestFailed.CreateFmt(
      'AssertBufferEquals: expected %d rows, buffer has %d',
      [Length(Expected), ABuf.Height]);

  SetLength(ExpectedCopy, Length(Expected));
  for I := 0 to High(Expected) do
  begin
    ExpLen := Length(Expected[I]);
    if ExpLen >= W then
      // Use as-is.  Equal-byte path covers pure ASCII (1 byte = 1
      // column), and the longer-byte path covers rows with multi-byte
      // graphemes (3 bytes per box-drawing char etc).  Either way the
      // expected string IS the byte stream we'll compare against.
      ExpectedCopy[I] := Expected[I]
    else
    begin
      // Convenience: pad short ASCII expected rows with spaces.
      // Lets test authors write '+' for a 1-cell border without
      // padding to full width.
      SetLength(ExpectedCopy[I], W);
      if ExpLen > 0 then
        Move(Expected[I][1], ExpectedCopy[I][1], ExpLen);
      FillChar(ExpectedCopy[I][ExpLen + 1], W - ExpLen, Ord(' '));
    end;
  end;

  Actual := ABuf.AsLines;
  Mismatches := 0;
  for I := 0 to High(Actual) do
    if ExpectedCopy[I] <> Actual[I] then
      Inc(Mismatches);

  if Mismatches > 0 then
    raise EFtuiTestFailed.Create(FormatDiff(ExpectedCopy, Actual, W));
end;

end.
