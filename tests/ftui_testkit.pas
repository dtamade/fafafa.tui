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
//     comparison. When a buffer differs from the expected lines, the
//     output shows expected/actual side-by-side with row markers.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  EFtuiTestFailed = class(Exception);

  TTestProc = procedure;

  TTestEntry = record
    Name: AnsiString;
    Proc: TTestProc;
  end;

procedure RegisterTest(const AName: AnsiString; AProc: TTestProc);
function RunAllTests: Integer;   // returns 0 if all passed, otherwise count of failures

procedure Assert_(Cond: Boolean; const Msg: AnsiString);
procedure AssertEqInt(Expected, Actual: Int64; const Ctx: AnsiString);
procedure AssertEqStr(const Expected, Actual: AnsiString; const Ctx: AnsiString);
procedure AssertEqBool(Expected, Actual: Boolean; const Ctx: AnsiString);
procedure AssertTrue(Cond: Boolean; const Ctx: AnsiString);
procedure AssertFalse(Cond: Boolean; const Ctx: AnsiString);

// Buffer snapshot assertion is implemented in test units that import
// ftui_buffer (avoids a circular include here). This unit exposes only
// the formatting helper used to render the diff.
function FormatBufferDiff(const ExpectedLines, ActualLines: array of AnsiString): AnsiString;

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
  I, Failed: Integer;
  Started: AnsiString;
begin
  Failed := 0;
  WriteLn(Format('running %d tests', [Length(GTests)]));
  for I := 0 to High(GTests) do
  begin
    Started := GTests[I].Name;
    try
      GTests[I].Proc();
      WriteLn('  ok      ', Started);
    except
      on E: EFtuiTestFailed do
      begin
        WriteLn('  FAILED  ', Started);
        WriteLn('    ', E.Message);
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
    WriteLn(Format('all %d tests passed', [Length(GTests)]))
  else
    WriteLn(Format('%d / %d tests failed', [Failed, Length(GTests)]));
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

function FormatBufferDiff(const ExpectedLines, ActualLines: array of AnsiString): AnsiString;
var
  I, MaxRows: Integer;
  Result_: AnsiString;
  Marker: AnsiString;
  Exp, Act: AnsiString;
begin
  Result_ := 'buffer mismatch:' + LineEnding;
  Result_ := Result_ + '  row | expected                          | actual' + LineEnding;
  MaxRows := Length(ExpectedLines);
  if Length(ActualLines) > MaxRows then
    MaxRows := Length(ActualLines);
  for I := 0 to MaxRows - 1 do
  begin
    if I < Length(ExpectedLines) then Exp := ExpectedLines[I] else Exp := '<missing>';
    if I < Length(ActualLines)   then Act := ActualLines[I]   else Act := '<missing>';
    if Exp = Act then Marker := '   ' else Marker := ' * ';
    Result_ := Result_ + Format(' %s%2d | %-32s | %s', [Marker, I, Exp, Act]) + LineEnding;
  end;
  Result := Result_;
end;

end.
