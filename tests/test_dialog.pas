unit test_dialog;

{$mode objfpc}{$H+}

interface

procedure RegisterDialogTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_cell,
  ftui_buffer,
  ftui_dialog;

procedure Test_CenteredArea;
var
  D: TDialog;
  Container, Area: TRect;
begin
  Container := TRect.Make(0, 0, 80, 24);
  D := TDialog.Create('Test', 'body').WithWidth(40).WithHeight(10);
  Area := D.CenteredArea(Container);
  AssertEqInt(20, Area.X, 'centered X = (80-40)/2');
  AssertEqInt(7, Area.Y, 'centered Y = (24-10)/2');
  AssertEqInt(40, Area.Width, 'width preserved');
  AssertEqInt(10, Area.Height, 'height preserved');
end;

procedure Test_CenteredAreaClamped;
var
  D: TDialog;
  Container, Area: TRect;
begin
  Container := TRect.Make(0, 0, 20, 5);
  D := TDialog.Create('T', 'b').WithWidth(40).WithHeight(10);
  Area := D.CenteredArea(Container);
  AssertEqInt(20, Area.Width, 'clamped to container width');
  AssertEqInt(5, Area.Height, 'clamped to container height');
end;

procedure Test_RenderShowsTitle;
var
  D: TDialog;
  Buf: TBuffer;
  Container: TRect;
  I: Integer;
  Found: Boolean;
begin
  Container := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Container);
  D := TDialog.Create('Alert', 'Something happened')
    .WithWidth(30).WithHeight(8)
    .WithDimBackground(False);
  D.Render(Container, Buf);
  Found := False;
  for I := 0 to Container.Height - 1 do
    if Pos('Alert', Buf.RowAsString(I)) > 0 then
    begin
      Found := True;
      Break;
    end;
  AssertTrue(Found, 'title visible in buffer');
  Buf.Free;
end;

procedure Test_RenderShowsBody;
var
  D: TDialog;
  Buf: TBuffer;
  Container: TRect;
  I: Integer;
  Found: Boolean;
begin
  Container := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Container);
  D := TDialog.Create('Info', 'Hello World')
    .WithWidth(30).WithHeight(8)
    .WithDimBackground(False);
  D.Render(Container, Buf);
  Found := False;
  for I := 0 to Container.Height - 1 do
    if Pos('Hello World', Buf.RowAsString(I)) > 0 then
    begin
      Found := True;
      Break;
    end;
  AssertTrue(Found, 'body text visible');
  Buf.Free;
end;

procedure Test_RenderShowsButtons;
var
  D: TDialog;
  Buf: TBuffer;
  Container: TRect;
  I: Integer;
  FoundOK, FoundCancel: Boolean;
begin
  Container := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Container);
  D := TDialog.Create('Confirm', 'Are you sure?')
    .WithWidth(40).WithHeight(10)
    .WithButtons(['OK', 'Cancel'])
    .WithDimBackground(False);
  D.Render(Container, Buf);
  FoundOK := False;
  FoundCancel := False;
  for I := 0 to Container.Height - 1 do
  begin
    if Pos('OK', Buf.RowAsString(I)) > 0 then FoundOK := True;
    if Pos('Cancel', Buf.RowAsString(I)) > 0 then FoundCancel := True;
  end;
  AssertTrue(FoundOK, 'OK button visible');
  AssertTrue(FoundCancel, 'Cancel button visible');
  Buf.Free;
end;

procedure Test_ActiveButtonHighlighted;
var
  D: TDialog;
  Buf: TBuffer;
  Container: TRect;
  Area: TRect;
  CP: PCell;
  I, BtnY, BtnX: Integer;
  Row: AnsiString;
begin
  Container := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Container);
  D := TDialog.Create('Q', 'question')
    .WithWidth(30).WithHeight(8)
    .WithButtons(['Yes', 'No'])
    .WithActiveButtonStyle(TStyle.Default.WithModifier([mbReversed]))
    .WithDimBackground(False);
  D.SelectedButton := 0;
  D.Render(Container, Buf);
  Area := D.CenteredArea(Container);
  BtnY := -1;
  for I := Area.Y to Area.Y + Area.Height - 1 do
  begin
    Row := Buf.RowAsString(I);
    if Pos('Yes', Row) > 0 then
    begin
      BtnY := I;
      BtnX := Pos('Yes', Row) - 1;
      Break;
    end;
  end;
  AssertTrue(BtnY >= 0, 'found button row');
  CP := Buf.CellAt(BtnX, BtnY);
  AssertTrue(CP <> nil, 'cell exists');
  AssertTrue(mbReversed in CP^.Modifier, 'active button has reversed');
  Buf.Free;
end;

procedure Test_DimBackground;
var
  D: TDialog;
  Buf: TBuffer;
  Container: TRect;
  CP: PCell;
begin
  Container := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Container);
  D := TDialog.Create('X', 'y')
    .WithWidth(20).WithHeight(5)
    .WithDimBackground(True);
  D.Render(Container, Buf);
  // Corner cell (0,0) should have Dim modifier from background dimming
  CP := Buf.CellAt(0, 0);
  AssertTrue(CP <> nil, 'corner cell exists');
  AssertTrue(mbDim in CP^.Modifier, 'background is dimmed');
  Buf.Free;
end;

procedure RegisterDialogTests;
begin
  RegisterTest('dialog / centered area',           @Test_CenteredArea);
  RegisterTest('dialog / centered area clamped',   @Test_CenteredAreaClamped);
  RegisterTest('dialog / render shows title',      @Test_RenderShowsTitle);
  RegisterTest('dialog / render shows body',       @Test_RenderShowsBody);
  RegisterTest('dialog / render shows buttons',    @Test_RenderShowsButtons);
  RegisterTest('dialog / active button highlight', @Test_ActiveButtonHighlighted);
  RegisterTest('dialog / dim background',          @Test_DimBackground);
end;

end.
