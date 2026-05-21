unit test_calendar;

{$mode objfpc}{$H+}

interface

procedure RegisterCalendarTests;

implementation

uses
  SysUtils, DateUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_buffer,
  ftui_calendar;

procedure Test_Today;
var S: TCalendarState;
    Y, M, D: Word;
begin
  DecodeDate(Now, Y, M, D);
  S := TCalendarState.Today;
  AssertEqInt(Integer(Y), Integer(S.Year), 'year');
  AssertEqInt(Integer(M), Integer(S.Month), 'month');
  AssertEqInt(Integer(D), Integer(S.SelectedDay), 'day');
end;

procedure Test_Make;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2025, 3, 15);
  AssertEqInt(2025, Integer(S.Year), 'year');
  AssertEqInt(3, Integer(S.Month), 'month');
  AssertEqInt(15, Integer(S.SelectedDay), 'day');
end;

procedure Test_DaysInMonth;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2024, 2, 1);
  AssertEqInt(29, Integer(S.DaysInMonth), 'feb 2024 leap');
  S := TCalendarState.Make(2025, 2, 1);
  AssertEqInt(28, Integer(S.DaysInMonth), 'feb 2025 non-leap');
  S := TCalendarState.Make(2025, 1, 1);
  AssertEqInt(31, Integer(S.DaysInMonth), 'jan');
end;

procedure Test_NextMonth;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2025, 12, 15);
  S.NextMonth;
  AssertEqInt(2026, Integer(S.Year), 'year wrapped');
  AssertEqInt(1, Integer(S.Month), 'jan');
  AssertEqInt(15, Integer(S.SelectedDay), 'day preserved');
end;

procedure Test_PrevMonth;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2025, 1, 31);
  S.PrevMonth;
  AssertEqInt(2024, Integer(S.Year), 'year wrapped back');
  AssertEqInt(12, Integer(S.Month), 'dec');
  AssertEqInt(31, Integer(S.SelectedDay), 'day clamped to dec 31');
end;

procedure Test_PrevMonthClamp;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2025, 3, 31);
  S.PrevMonth;
  AssertEqInt(28, Integer(S.SelectedDay), 'clamped to feb 28');
end;

procedure Test_NextDay;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2025, 1, 31);
  S.NextDay;
  AssertEqInt(2, Integer(S.Month), 'rolled to feb');
  AssertEqInt(1, Integer(S.SelectedDay), 'day 1');
end;

procedure Test_PrevDay;
var S: TCalendarState;
begin
  S := TCalendarState.Make(2025, 2, 1);
  S.PrevDay;
  AssertEqInt(1, Integer(S.Month), 'rolled to jan');
  AssertEqInt(31, Integer(S.SelectedDay), 'jan 31');
end;

procedure Test_RenderShowsMonth;
var
  Cal: TCalendar;
  Buf: TBuffer;
  Area: TRect;
  State: TCalendarState;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 22, 9);
  Buf := TBuffer.CreateEmpty(Area);
  Cal := TCalendar.Default;
  State := TCalendarState.Make(2025, 6, 15);
  Cal.RenderStateful(Area, Buf, State);
  Row := Buf.RowAsString(0);
  AssertTrue(Pos('June', Row) > 0, 'month name visible');
  AssertTrue(Pos('2025', Row) > 0, 'year visible');
  Buf.Free;
end;

procedure Test_RenderShowsDowHeader;
var
  Cal: TCalendar;
  Buf: TBuffer;
  Area: TRect;
  State: TCalendarState;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 22, 9);
  Buf := TBuffer.CreateEmpty(Area);
  Cal := TCalendar.Default;
  State := TCalendarState.Make(2025, 6, 1);
  Cal.RenderStateful(Area, Buf, State);
  Row := Buf.RowAsString(1);
  AssertTrue(Pos('Mo', Row) > 0, 'Mo header');
  AssertTrue(Pos('Su', Row) > 0, 'Su header');
  Buf.Free;
end;

procedure Test_RenderShowsDays;
var
  Cal: TCalendar;
  Buf: TBuffer;
  Area: TRect;
  State: TCalendarState;
  Found: Boolean;
  I: Integer;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 22, 9);
  Buf := TBuffer.CreateEmpty(Area);
  Cal := TCalendar.Default;
  State := TCalendarState.Make(2025, 6, 1);
  Cal.RenderStateful(Area, Buf, State);
  Found := False;
  for I := 2 to 8 do
  begin
    Row := Buf.RowAsString(I);
    if Pos('15', Row) > 0 then Found := True;
  end;
  AssertTrue(Found, 'day 15 visible');
  Buf.Free;
end;

procedure RegisterCalendarTests;
begin
  RegisterTest('calendar / today',              @Test_Today);
  RegisterTest('calendar / make',               @Test_Make);
  RegisterTest('calendar / days in month',      @Test_DaysInMonth);
  RegisterTest('calendar / next month',         @Test_NextMonth);
  RegisterTest('calendar / prev month',         @Test_PrevMonth);
  RegisterTest('calendar / prev month clamp',   @Test_PrevMonthClamp);
  RegisterTest('calendar / next day',           @Test_NextDay);
  RegisterTest('calendar / prev day',           @Test_PrevDay);
  RegisterTest('calendar / render shows month', @Test_RenderShowsMonth);
  RegisterTest('calendar / render dow header',  @Test_RenderShowsDowHeader);
  RegisterTest('calendar / render shows days',  @Test_RenderShowsDays);
end;

end.
