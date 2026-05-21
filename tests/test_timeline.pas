unit test_timeline;
{$mode objfpc}{$H+}
interface
procedure RegisterTimelineTests;
implementation
uses ftui_testkit, ftui_rect, ftui_style, ftui_color, ftui_buffer, ftui_timeline;

procedure Test_CreateEvent;
var E: TTimelineEvent;
begin
  E := TTimelineEvent.Make('10:30', 'Deploy v2.1');
  AssertEqStr('10:30', E.Time, 'time');
  AssertEqStr('Deploy v2.1', E.Title, 'title');
end;

procedure Test_RenderShowsEvents;
var TL: TTimeline; Buf: TBuffer; Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 10);
  Buf := TBuffer.CreateEmpty(Area);
  TL := TTimeline.Create([
    TTimelineEvent.Make('09:00', 'Start'),
    TTimelineEvent.Make('10:00', 'Build'),
    TTimelineEvent.Make('11:00', 'Deploy')
  ]);
  TL.Render(Area, Buf);
  AssertTrue(Pos('Start', Buf.RowAsString(0)) > 0, 'first event');
  Buf.Free;
end;

procedure Test_WithDescription;
var TL: TTimeline; Buf: TBuffer; Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 10);
  Buf := TBuffer.CreateEmpty(Area);
  TL := TTimeline.Create([
    TTimelineEvent.Make('12:00', 'Fix').WithDescription('Hotfix for #123')
  ]);
  TL.Render(Area, Buf);
  AssertTrue(Pos('Hotfix', Buf.RowAsString(1)) > 0, 'description on next line');
  Buf.Free;
end;

procedure RegisterTimelineTests;
begin
  RegisterTest('timeline / create event',   @Test_CreateEvent);
  RegisterTest('timeline / render events',  @Test_RenderShowsEvents);
  RegisterTest('timeline / with description', @Test_WithDescription);
end;
end.
