unit test_command_palette;

{$mode objfpc}{$H+}

interface

procedure RegisterCommandPaletteTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_command_palette;

procedure Test_FuzzyMatchExact;
begin
  AssertTrue(FuzzyMatch('hello', 'hello world'), 'exact prefix');
  AssertTrue(FuzzyMatch('hw', 'hello world'), 'initials');
  AssertTrue(FuzzyMatch('', 'anything'), 'empty matches all');
  AssertTrue(not FuzzyMatch('xyz', 'hello'), 'no match');
end;

procedure Test_FuzzyMatchCaseInsensitive;
begin
  AssertTrue(FuzzyMatch('HW', 'hello world'), 'case insensitive');
  AssertTrue(FuzzyMatch('hw', 'Hello World'), 'case insensitive 2');
end;

procedure Test_FuzzyScore;
begin
  AssertTrue(FuzzyScore('he', 'hello') > FuzzyScore('he', 'the'), 'prefix scores higher');
  AssertTrue(FuzzyScore('', 'anything') > 0, 'empty has score');
  AssertEqInt(0, FuzzyScore('xyz', 'hello'), 'no match = 0');
end;

procedure Test_CreateState;
var S: TCommandPaletteState;
begin
  S := TCommandPaletteState.Create;
  AssertTrue(not S.Visible, 'not visible');
  AssertEqInt(0, S.Selected, 'selected 0');
end;

procedure Test_OpenClose;
var S: TCommandPaletteState;
begin
  S := TCommandPaletteState.Create;
  S.Open;
  AssertTrue(S.Visible, 'visible after open');
  S.Close;
  AssertTrue(not S.Visible, 'not visible after close');
end;

procedure Test_Filter;
var
  CP: TCommandPalette;
  S: TCommandPaletteState;
begin
  CP := TCommandPalette.Create([
    TCommandItem.Make('Open File', 'Open a file'),
    TCommandItem.Make('Save File', 'Save current'),
    TCommandItem.Make('Quit', 'Exit app')
  ]);
  S := TCommandPaletteState.Create;
  S.Open;
  S.Input.Text := 'fi';
  CP.UpdateFilter(S);
  AssertEqInt(2, Length(S.FilteredIndices), '2 items match "fi"');
end;

procedure Test_FilterEmpty;
var
  CP: TCommandPalette;
  S: TCommandPaletteState;
begin
  CP := TCommandPalette.Create([
    TCommandItem.Make('A', ''),
    TCommandItem.Make('B', ''),
    TCommandItem.Make('C', '')
  ]);
  S := TCommandPaletteState.Create;
  S.Open;
  CP.UpdateFilter(S);
  AssertEqInt(3, Length(S.FilteredIndices), 'all match empty query');
end;

procedure Test_SelectNextPrev;
var
  CP: TCommandPalette;
  S: TCommandPaletteState;
begin
  CP := TCommandPalette.Create([
    TCommandItem.Make('A', ''),
    TCommandItem.Make('B', ''),
    TCommandItem.Make('C', '')
  ]);
  S := TCommandPaletteState.Create;
  S.Open;
  CP.UpdateFilter(S);
  S.SelectNext;
  AssertEqInt(1, S.Selected, 'next');
  S.SelectNext;
  AssertEqInt(2, S.Selected, 'next again');
  S.SelectNext;
  AssertEqInt(2, S.Selected, 'clamped');
  S.SelectPrev;
  AssertEqInt(1, S.Selected, 'prev');
end;

procedure Test_SelectedItem;
var
  CP: TCommandPalette;
  S: TCommandPaletteState;
begin
  CP := TCommandPalette.Create([
    TCommandItem.Make('Alpha', ''),
    TCommandItem.Make('Beta', ''),
    TCommandItem.Make('Gamma', '')
  ]);
  S := TCommandPaletteState.Create;
  S.Open;
  S.Input.Text := 'b';
  CP.UpdateFilter(S);
  AssertEqInt(1, CP.SelectedItem(S), 'Beta is index 1');
end;

procedure Test_RenderWhenVisible;
var
  CP: TCommandPalette;
  S: TCommandPaletteState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Area);
  CP := TCommandPalette.Create([
    TCommandItem.Make('Open', 'Open file'),
    TCommandItem.Make('Save', 'Save file')
  ]).WithWidth(40);
  S := TCommandPaletteState.Create;
  S.Open;
  CP.RenderStateful(Area, Buf, S);
  AssertTrue(Pos('Open', Buf.RowAsString(4)) > 0, 'item visible');
  Buf.Free;
end;

procedure Test_RenderHiddenNoop;
var
  CP: TCommandPalette;
  S: TCommandPaletteState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 60, 20);
  Buf := TBuffer.CreateEmpty(Area);
  CP := TCommandPalette.Create([TCommandItem.Make('X', '')]);
  S := TCommandPaletteState.Create;
  CP.RenderStateful(Area, Buf, S);
  AssertTrue(Pos('X', Buf.RowAsString(4)) = 0, 'nothing rendered when hidden');
  Buf.Free;
end;

procedure RegisterCommandPaletteTests;
begin
  RegisterTest('cmd_palette / fuzzy match exact',    @Test_FuzzyMatchExact);
  RegisterTest('cmd_palette / fuzzy case insensitive', @Test_FuzzyMatchCaseInsensitive);
  RegisterTest('cmd_palette / fuzzy score',          @Test_FuzzyScore);
  RegisterTest('cmd_palette / create state',         @Test_CreateState);
  RegisterTest('cmd_palette / open close',           @Test_OpenClose);
  RegisterTest('cmd_palette / filter',               @Test_Filter);
  RegisterTest('cmd_palette / filter empty',         @Test_FilterEmpty);
  RegisterTest('cmd_palette / select next prev',     @Test_SelectNextPrev);
  RegisterTest('cmd_palette / selected item',        @Test_SelectedItem);
  RegisterTest('cmd_palette / render visible',       @Test_RenderWhenVisible);
  RegisterTest('cmd_palette / render hidden noop',   @Test_RenderHiddenNoop);
end;

end.
