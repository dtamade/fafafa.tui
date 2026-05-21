unit test_popover;

{$mode objfpc}{$H+}

interface

uses
  ftui_testkit;

procedure RegisterTests;

implementation

uses
  ftui_popover,
  ftui_rect,
  ftui_cell,
  ftui_buffer;

procedure Test_HiddenNoRender;
var
  Pop: TPopover;
  State: TPopoverState;
  Buf: TBuffer;
  Area, Anchor: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  Anchor := TRect.Make(5, 5, 10, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Pop := TPopover.Create(['One', 'Two', 'Three']);
  State := TPopoverState.Hidden;
  Pop.RenderStateful(Anchor, Area, Buf, State);
  AssertTrue(Buf.CellAt(5, 6)^.Glyph.Bytes[0] = 32, 'hidden popover writes nothing');
  Buf.Free;
end;

procedure Test_ShowRendersItems;
var
  Pop: TPopover;
  State: TPopoverState;
  Buf: TBuffer;
  Area, Anchor: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  Anchor := TRect.Make(5, 3, 10, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Pop := TPopover.Create(['Alpha', 'Beta', 'Gamma']).WithWidth(12);
  State := TPopoverState.Hidden;
  State.Show;
  Pop.RenderStateful(Anchor, Area, Buf, State);
  AssertTrue(Buf.CellAt(6, 5)^.Glyph.Bytes[0] <> 32, 'popover rendered content');
  Buf.Free;
end;

procedure Test_SelectionClamp;
var
  Pop: TPopover;
  State: TPopoverState;
  Buf: TBuffer;
  Area, Anchor: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  Anchor := TRect.Make(0, 0, 5, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Pop := TPopover.Create(['A', 'B']);
  State := TPopoverState.Hidden;
  State.Show;
  State.Selected := 99;
  Pop.RenderStateful(Anchor, Area, Buf, State);
  AssertEqInt(1, State.Selected, 'selection clamped');
  Buf.Free;
end;

procedure Test_AnchorAbove;
var
  Pop: TPopover;
  State: TPopoverState;
  Buf: TBuffer;
  Area, Anchor: TRect;
begin
  Area := TRect.Make(0, 0, 40, 20);
  Anchor := TRect.Make(5, 10, 10, 1);
  Buf := TBuffer.CreateEmpty(Area);
  Pop := TPopover.Create(['X', 'Y']).WithAnchor(paAbove).WithWidth(10);
  State := TPopoverState.Hidden;
  State.Show;
  Pop.RenderStateful(Anchor, Area, Buf, State);
  AssertTrue(Buf.CellAt(6, 7)^.Glyph.Bytes[0] <> 32, 'above anchor rendered');
  Buf.Free;
end;

procedure RegisterTests;
begin
  RegisterTest('popover / hidden no render', @Test_HiddenNoRender);
  RegisterTest('popover / show renders items', @Test_ShowRendersItems);
  RegisterTest('popover / selection clamp', @Test_SelectionClamp);
  RegisterTest('popover / anchor above', @Test_AnchorAbove);
end;

end.
