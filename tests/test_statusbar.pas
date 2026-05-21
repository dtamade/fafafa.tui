unit test_statusbar;

{$mode objfpc}{$H+}

interface

procedure RegisterStatusBarTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_color,
  ftui_modifier,
  ftui_buffer,
  ftui_statusbar;

procedure Test_LeftSegments;
var
  SB: TStatusBar;
  Buf: TBuffer;
  Area: TRect;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 40, 1);
  Buf := TBuffer.CreateEmpty(Area);
  SB := TStatusBar.Default.WithLeft([
    TStatusSegment.Make(' NORMAL '),
    TStatusSegment.Make(' main.pas ')
  ]);
  SB.Render(Area, Buf);
  Row := Buf.RowAsString(0);
  AssertTrue(Pos('NORMAL', Row) > 0, 'left: NORMAL visible');
  AssertTrue(Pos('main.pas', Row) > 0, 'left: main.pas visible');
  AssertTrue(Pos('NORMAL', Row) < Pos('main.pas', Row), 'left: order preserved');
  Buf.Free;
end;

procedure Test_RightSegments;
var
  SB: TStatusBar;
  Buf: TBuffer;
  Area: TRect;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 40, 1);
  Buf := TBuffer.CreateEmpty(Area);
  SB := TStatusBar.Default.WithRight([
    TStatusSegment.Make(' Ln 42 '),
    TStatusSegment.Make(' UTF-8 ')
  ]);
  SB.Render(Area, Buf);
  Row := Buf.RowAsString(0);
  AssertTrue(Pos('Ln 42', Row) > 0, 'right: Ln 42 visible');
  AssertTrue(Pos('UTF-8', Row) > 0, 'right: UTF-8 visible');
  AssertTrue(Pos('UTF-8', Row) > 30, 'right: near right edge');
  Buf.Free;
end;

procedure Test_CenterSegments;
var
  SB: TStatusBar;
  Buf: TBuffer;
  Area: TRect;
  Row: AnsiString;
  P: Integer;
begin
  Area := TRect.Make(0, 0, 40, 1);
  Buf := TBuffer.CreateEmpty(Area);
  SB := TStatusBar.Default.WithCenter([
    TStatusSegment.Make('TITLE')
  ]);
  SB.Render(Area, Buf);
  Row := Buf.RowAsString(0);
  P := Pos('TITLE', Row);
  AssertTrue(P > 15, 'center: roughly centered');
  AssertTrue(P < 25, 'center: not too far right');
  Buf.Free;
end;

procedure Test_AllThreeRegions;
var
  SB: TStatusBar;
  Buf: TBuffer;
  Area: TRect;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 60, 1);
  Buf := TBuffer.CreateEmpty(Area);
  SB := TStatusBar.Default
    .WithLeft([TStatusSegment.Make(' L ')])
    .WithCenter([TStatusSegment.Make(' C ')])
    .WithRight([TStatusSegment.Make(' R ')]);
  SB.Render(Area, Buf);
  Row := Buf.RowAsString(0);
  AssertTrue(Pos('L', Row) < Pos('C', Row), 'L before C');
  AssertTrue(Pos('C', Row) < Pos('R', Row), 'C before R');
  Buf.Free;
end;

procedure Test_EmptyStatusBar;
var
  SB: TStatusBar;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 1);
  Buf := TBuffer.CreateEmpty(Area);
  SB := TStatusBar.Default;
  SB.Render(Area, Buf);
  // Should not crash
  AssertTrue(True, 'empty statusbar renders');
  Buf.Free;
end;

procedure RegisterStatusBarTests;
begin
  RegisterTest('statusbar / left segments',     @Test_LeftSegments);
  RegisterTest('statusbar / right segments',    @Test_RightSegments);
  RegisterTest('statusbar / center segments',   @Test_CenterSegments);
  RegisterTest('statusbar / all three regions', @Test_AllThreeRegions);
  RegisterTest('statusbar / empty',             @Test_EmptyStatusBar);
end;

end.
