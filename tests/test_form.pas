unit test_form;

{$mode objfpc}{$H+}

interface

procedure RegisterFormTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_buffer,
  ftui_form;

procedure Test_CheckboxUnchecked;
var
  CB: TCheckbox;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 1);
  Buf := TBuffer.CreateEmpty(Area);
  CB := TCheckbox.Create('Option A', False);
  CB.Render(Area, Buf);
  AssertTrue(Pos('[ ]', Buf.RowAsString(0)) > 0, 'unchecked marker');
  AssertTrue(Pos('Option A', Buf.RowAsString(0)) > 0, 'label visible');
  Buf.Free;
end;

procedure Test_CheckboxChecked;
var
  CB: TCheckbox;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 1);
  Buf := TBuffer.CreateEmpty(Area);
  CB := TCheckbox.Create('Option B', True);
  CB.Render(Area, Buf);
  AssertTrue(Pos('[x]', Buf.RowAsString(0)) > 0, 'checked marker');
  Buf.Free;
end;

procedure Test_CheckboxToggle;
var CB: TCheckbox;
begin
  CB := TCheckbox.Create('T', False);
  AssertTrue(not CB.Checked, 'starts unchecked');
  CB.Toggle;
  AssertTrue(CB.Checked, 'after toggle: checked');
  CB.Toggle;
  AssertTrue(not CB.Checked, 'after second toggle: unchecked');
end;

procedure Test_RadioGroupRender;
var
  RG: TRadioGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 3);
  Buf := TBuffer.CreateEmpty(Area);
  RG := TRadioGroup.Create(['Red', 'Green', 'Blue']);
  RG.Selected := 1;
  RG.Render(Area, Buf);
  AssertTrue(Pos('( )', Buf.RowAsString(0)) > 0, 'row 0 unselected');
  AssertTrue(Pos('(*)', Buf.RowAsString(1)) > 0, 'row 1 selected');
  AssertTrue(Pos('( )', Buf.RowAsString(2)) > 0, 'row 2 unselected');
  AssertTrue(Pos('Green', Buf.RowAsString(1)) > 0, 'Green label');
  Buf.Free;
end;

procedure Test_RadioGroupSelect;
var RG: TRadioGroup;
begin
  RG := TRadioGroup.Create(['A', 'B', 'C']);
  AssertEqInt(0, RG.Selected, 'default selected = 0');
  RG.Select(2);
  AssertEqInt(2, RG.Selected, 'after select(2)');
  RG.Select(99);
  AssertEqInt(2, RG.Selected, 'out of range ignored');
end;

procedure Test_RadioGroupTruncates;
var
  RG: TRadioGroup;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 2);
  Buf := TBuffer.CreateEmpty(Area);
  RG := TRadioGroup.Create(['A', 'B', 'C', 'D']);
  RG.Render(Area, Buf);
  AssertTrue(Pos('A', Buf.RowAsString(0)) > 0, 'first item visible');
  AssertTrue(Pos('B', Buf.RowAsString(1)) > 0, 'second item visible');
  Buf.Free;
end;

procedure RegisterFormTests;
begin
  RegisterTest('form / checkbox unchecked',    @Test_CheckboxUnchecked);
  RegisterTest('form / checkbox checked',      @Test_CheckboxChecked);
  RegisterTest('form / checkbox toggle',       @Test_CheckboxToggle);
  RegisterTest('form / radio group render',    @Test_RadioGroupRender);
  RegisterTest('form / radio group select',    @Test_RadioGroupSelect);
  RegisterTest('form / radio group truncates', @Test_RadioGroupTruncates);
end;

end.
