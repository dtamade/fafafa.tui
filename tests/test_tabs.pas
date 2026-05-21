unit test_tabs;

{$mode objfpc}{$H+}

interface

procedure RegisterTabsTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_tabs;

procedure Test_RendersTitlesWithSeparator;
var
  Buf: TBuffer;
  T: TTabs;
  S: TTabsState;
begin
  // 'A | B | C' = 9 chars, buffer width 20
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    T := TTabs.Create(['A', 'B', 'C']);
    S.Selected := 0;
    T.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, ['A | B | C           ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_SelectedTabUsesActiveStyle;
var
  Buf: TBuffer;
  T: TTabs;
  S: TTabsState;
  CP: PCell;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    T := TTabs.Create(['AA', 'BB'])
          .WithActiveStyle(TStyle.Default.WithFg(clGreen))
          .WithInactiveStyle(TStyle.Default.WithFg(clGray));
    S.Selected := 1;
    T.RenderStateful(Buf.Area, Buf, S);
    // 'AA' at col 0..1 should be inactive (gray)
    CP := Buf.CellAt(0, 0);
    AssertTrue(ColorEquals(clGray, CP^.Fg), 'inactive tab fg = gray');
    // 'BB' at col 5..6 should be active (green)
    CP := Buf.CellAt(5, 0);
    AssertTrue(ColorEquals(clGreen, CP^.Fg), 'active tab fg = green');
  finally
    Buf.Free;
  end;
end;

procedure Test_HandlesEmptyTitlesArray;
var
  Buf: TBuffer;
  T: TTabs;
  S: TTabsState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    T := TTabs.Create([]);
    S.Selected := 0;
    T.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, ['          ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_TruncatesWhenTooWide;
var
  Buf: TBuffer;
  T: TTabs;
  S: TTabsState;
begin
  // 'Hello | World' = 13 chars, buffer only 8 wide
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  try
    T := TTabs.Create(['Hello', 'World']);
    S.Selected := 0;
    T.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, ['Hello | ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_CustomSeparator;
var
  Buf: TBuffer;
  T: TTabs;
  S: TTabsState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    T := TTabs.Create(['X', 'Y']).WithSeparator('-');
    S.Selected := 0;
    T.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, ['X-Y       ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_SingleTab;
var
  Buf: TBuffer;
  T: TTabs;
  S: TTabsState;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    T := TTabs.Create(['Only']);
    S.Selected := 0;
    T.RenderStateful(Buf.Area, Buf, S);
    AssertBufferEquals(Buf, ['Only      ']);
  finally
    Buf.Free;
  end;
end;

procedure RegisterTabsTests;
begin
  RegisterTest('tabs / renders titles with separator',    @Test_RendersTitlesWithSeparator);
  RegisterTest('tabs / selected tab uses active style',   @Test_SelectedTabUsesActiveStyle);
  RegisterTest('tabs / handles empty titles array',       @Test_HandlesEmptyTitlesArray);
  RegisterTest('tabs / truncates when too wide',          @Test_TruncatesWhenTooWide);
  RegisterTest('tabs / custom separator',                 @Test_CustomSeparator);
  RegisterTest('tabs / single tab no separator',          @Test_SingleTab);
end;

end.
