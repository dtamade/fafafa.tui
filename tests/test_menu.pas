unit test_menu;

{$mode objfpc}{$H+}

interface

procedure RegisterMenuTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_buffer,
  ftui_menu;

procedure Test_BasicRender;
var
  M: TMenu;
  Buf: TBuffer;
  Area: TRect;
  State: TMenuState;
begin
  Area := TRect.Make(0, 0, 20, 5);
  Buf := TBuffer.CreateEmpty(Area);
  M := TMenu.Create([
    TMenuItem.Action('Open'),
    TMenuItem.Action('Save'),
    TMenuItem.Action('Quit')
  ]);
  State := TMenuState.Default;
  M.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Open', Buf.RowAsString(0)) > 0, 'Open visible');
  AssertTrue(Pos('Save', Buf.RowAsString(1)) > 0, 'Save visible');
  AssertTrue(Pos('Quit', Buf.RowAsString(2)) > 0, 'Quit visible');
  Buf.Free;
end;

procedure Test_Separator;
var
  M: TMenu;
  Buf: TBuffer;
  Area: TRect;
  State: TMenuState;
begin
  Area := TRect.Make(0, 0, 20, 4);
  Buf := TBuffer.CreateEmpty(Area);
  M := TMenu.Create([
    TMenuItem.Action('A'),
    TMenuItem.Separator,
    TMenuItem.Action('B')
  ]);
  State := TMenuState.Default;
  M.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('---', Buf.RowAsString(1)) > 0, 'separator rendered');
  Buf.Free;
end;

procedure Test_Shortcut;
var
  M: TMenu;
  Buf: TBuffer;
  Area: TRect;
  State: TMenuState;
begin
  Area := TRect.Make(0, 0, 25, 3);
  Buf := TBuffer.CreateEmpty(Area);
  M := TMenu.Create([
    TMenuItem.Action('Save').WithShortcut('Ctrl+S')
  ]);
  State := TMenuState.Default;
  M.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('Ctrl+S', Buf.RowAsString(0)) > 0, 'shortcut visible');
  Buf.Free;
end;

procedure Test_MoveDown;
var
  M: TMenu;
  State: TMenuState;
begin
  M := TMenu.Create([
    TMenuItem.Action('A'),
    TMenuItem.Separator,
    TMenuItem.Action('B')
  ]);
  State := TMenuState.Default;
  State.Selected := 0;
  M.MoveDown(State);
  AssertEqInt(2, State.Selected, 'skips separator');
end;

procedure Test_MoveUp;
var
  M: TMenu;
  State: TMenuState;
begin
  M := TMenu.Create([
    TMenuItem.Action('A'),
    TMenuItem.Separator,
    TMenuItem.Action('B')
  ]);
  State := TMenuState.Default;
  State.Selected := 2;
  M.MoveUp(State);
  AssertEqInt(0, State.Selected, 'skips separator going up');
end;

procedure Test_DisabledSkipped;
var
  M: TMenu;
  State: TMenuState;
begin
  M := TMenu.Create([
    TMenuItem.Action('A'),
    TMenuItem.Action('B').WithEnabled(False),
    TMenuItem.Action('C')
  ]);
  State := TMenuState.Default;
  State.Selected := 0;
  M.MoveDown(State);
  AssertEqInt(2, State.Selected, 'skips disabled item');
end;

procedure Test_SubmenuMarker;
var
  M: TMenu;
  Buf: TBuffer;
  Area: TRect;
  State: TMenuState;
begin
  Area := TRect.Make(0, 0, 20, 3);
  Buf := TBuffer.CreateEmpty(Area);
  M := TMenu.Create([
    TMenuItem.Action('File').WithChildren([
      TMenuItem.Action('New')
    ])
  ]);
  State := TMenuState.Default;
  M.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('>', Buf.RowAsString(0)) > 0, 'submenu marker visible');
  Buf.Free;
end;

procedure Test_ItemCount;
var M: TMenu;
begin
  M := TMenu.Create([
    TMenuItem.Action('A'),
    TMenuItem.Separator,
    TMenuItem.Action('B')
  ]);
  AssertEqInt(3, M.ItemCount, 'total items = 3');
  AssertEqInt(2, M.SelectableCount, 'selectable = 2');
end;

procedure RegisterMenuTests;
begin
  RegisterTest('menu / basic render',       @Test_BasicRender);
  RegisterTest('menu / separator',          @Test_Separator);
  RegisterTest('menu / shortcut',           @Test_Shortcut);
  RegisterTest('menu / move down',          @Test_MoveDown);
  RegisterTest('menu / move up',            @Test_MoveUp);
  RegisterTest('menu / disabled skipped',   @Test_DisabledSkipped);
  RegisterTest('menu / submenu marker',     @Test_SubmenuMarker);
  RegisterTest('menu / item count',         @Test_ItemCount);
end;

end.
