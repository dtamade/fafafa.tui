unit test_progress_group;

{$mode objfpc}{$H+}

interface

procedure RegisterProgressGroupTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_color,
  ftui_buffer,
  ftui_progress_group;

procedure Test_CreateItems;
var PG: TProgressGroup;
begin
  PG := TProgressGroup.Create([
    TProgressItem.Make('A', 0.5),
    TProgressItem.Make('B', 0.8)
  ]);
  AssertEqInt(2, Length(PG.Items), '2 items');
end;

procedure Test_RatioClamped;
var P: TProgressItem;
begin
  P := TProgressItem.Make('x', 1.5);
  AssertTrue(P.Ratio <= 1.0, 'clamped to 1.0');
  P := TProgressItem.Make('y', -0.5);
  AssertTrue(P.Ratio >= 0.0, 'clamped to 0.0');
end;

procedure Test_RenderShowsLabels;
var
  PG: TProgressGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 3);
  Buf := TBuffer.CreateEmpty(Area);
  PG := TProgressGroup.Create([
    TProgressItem.Make('Download', 0.7),
    TProgressItem.Make('Upload', 0.3)
  ]);
  PG.Render(Area, Buf);
  AssertTrue(Pos('Download', Buf.RowAsString(0)) > 0, 'label Download');
  AssertTrue(Pos('Upload', Buf.RowAsString(1)) > 0, 'label Upload');
  Buf.Free;
end;

procedure Test_RenderShowsPercent;
var
  PG: TProgressGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 2);
  Buf := TBuffer.CreateEmpty(Area);
  PG := TProgressGroup.Create([
    TProgressItem.Make('Task', 0.5)
  ]).WithShowPercent(True);
  PG.Render(Area, Buf);
  AssertTrue(Pos('50%', Buf.RowAsString(0)) > 0, 'percent shown');
  Buf.Free;
end;

procedure Test_NoPercent;
var
  PG: TProgressGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 2);
  Buf := TBuffer.CreateEmpty(Area);
  PG := TProgressGroup.Create([
    TProgressItem.Make('Task', 0.5)
  ]).WithShowPercent(False);
  PG.Render(Area, Buf);
  AssertTrue(Pos('50%', Buf.RowAsString(0)) = 0, 'no percent');
  Buf.Free;
end;

procedure Test_LabelWidth;
var
  PG: TProgressGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 2);
  Buf := TBuffer.CreateEmpty(Area);
  PG := TProgressGroup.Create([
    TProgressItem.Make('A', 1.0)
  ]).WithLabelWidth(10);
  PG.Render(Area, Buf);
  AssertTrue(Length(Buf.RowAsString(0)) > 0, 'rendered with label width');
  Buf.Free;
end;

procedure Test_EmptyNoCrash;
var
  PG: TProgressGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 5);
  Buf := TBuffer.CreateEmpty(Area);
  PG := TProgressGroup.Create([]);
  PG.Render(Area, Buf);
  AssertTrue(True, 'no crash on empty');
  Buf.Free;
end;

procedure RegisterProgressGroupTests;
begin
  RegisterTest('progress_group / create items',      @Test_CreateItems);
  RegisterTest('progress_group / ratio clamped',     @Test_RatioClamped);
  RegisterTest('progress_group / render labels',     @Test_RenderShowsLabels);
  RegisterTest('progress_group / render percent',    @Test_RenderShowsPercent);
  RegisterTest('progress_group / no percent',        @Test_NoPercent);
  RegisterTest('progress_group / label width',       @Test_LabelWidth);
  RegisterTest('progress_group / empty no crash',    @Test_EmptyNoCrash);
end;

end.
