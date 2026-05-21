unit test_diffview;
{$mode objfpc}{$H+}
interface
procedure RegisterDiffViewTests;
implementation
uses ftui_testkit, ftui_rect, ftui_style, ftui_buffer, ftui_diffview;

procedure Test_FromUnifiedDiff;
var DV: TDiffView;
begin
  DV := TDiffView.FromUnifiedDiff(
    '--- a/file.pas' + #10 +
    '+++ b/file.pas' + #10 +
    '@@ -1,3 +1,4 @@' + #10 +
    ' context' + #10 +
    '-removed' + #10 +
    '+added' + #10 +
    '+new line'
  );
  AssertTrue(Length(DV.Lines) >= 5, 'parsed lines');
  AssertTrue(DV.Lines[0].Kind = dlHeader, 'first is header');
end;

procedure Test_LineKinds;
var DV: TDiffView; I: Integer; HasAdd, HasRem: Boolean;
begin
  DV := TDiffView.FromUnifiedDiff(
    '@@ -1 +1 @@' + #10 + '-old' + #10 + '+new'
  );
  HasAdd := False; HasRem := False;
  for I := 0 to High(DV.Lines) do
  begin
    if DV.Lines[I].Kind = dlAdded then HasAdd := True;
    if DV.Lines[I].Kind = dlRemoved then HasRem := True;
  end;
  AssertTrue(HasAdd, 'has added');
  AssertTrue(HasRem, 'has removed');
end;

procedure Test_RenderShowsDiff;
var DV: TDiffView; Buf: TBuffer; Area: TRect; State: TDiffViewState;
begin
  Area := TRect.Make(0, 0, 40, 5);
  Buf := TBuffer.CreateEmpty(Area);
  DV := TDiffView.FromUnifiedDiff(
    '@@ -1 +1 @@' + #10 + '-old line' + #10 + '+new line'
  );
  State := TDiffViewState.Empty;
  DV.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('old line', Buf.RowAsString(1)) > 0, 'removed visible');
  AssertTrue(Pos('new line', Buf.RowAsString(2)) > 0, 'added visible');
  Buf.Free;
end;

procedure Test_ScrollState;
var S: TDiffViewState;
begin
  S := TDiffViewState.Empty;
  S.ScrollDown(5);
  AssertEqInt(5, S.ScrollY, 'scrolled down');
  S.ScrollUp(3);
  AssertEqInt(2, S.ScrollY, 'scrolled up');
  S.ScrollUp(10);
  AssertEqInt(0, S.ScrollY, 'clamped');
end;

procedure RegisterDiffViewTests;
begin
  RegisterTest('diffview / from unified diff', @Test_FromUnifiedDiff);
  RegisterTest('diffview / line kinds',        @Test_LineKinds);
  RegisterTest('diffview / render shows diff', @Test_RenderShowsDiff);
  RegisterTest('diffview / scroll state',      @Test_ScrollState);
end;
end.
