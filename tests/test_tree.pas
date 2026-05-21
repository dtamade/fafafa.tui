unit test_tree;

{$mode objfpc}{$H+}

interface

procedure RegisterTreeTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_buffer,
  ftui_tree;

procedure Test_FlatRender;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([
    TTreeNode.Make('root')
  ]);
  State := TTreeState.Empty;
  T.RenderStateful(Area, Buf, State);
  AssertTrue(Pos('root', Buf.RowAsString(0)) > 0, 'root visible');
  AssertEqInt(1, State.FlatCount, 'flat count = 1');
  Buf.Free;
end;

procedure Test_ChildrenCollapsed;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([
    TTreeNode.Make('parent').WithChildren([
      TTreeNode.Make('child1'),
      TTreeNode.Make('child2')
    ])
  ]);
  State := TTreeState.Empty;
  T.RenderStateful(Area, Buf, State);
  AssertEqInt(1, State.FlatCount, 'collapsed: only parent visible');
  AssertTrue(Pos('[+]', Buf.RowAsString(0)) > 0, 'shows [+] marker');
  Buf.Free;
end;

procedure Test_ChildrenExpanded;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([
    TTreeNode.Make('parent').WithChildren([
      TTreeNode.Make('child1'),
      TTreeNode.Make('child2')
    ])
  ]);
  State := TTreeState.Empty;
  State.EnsureSize(1);
  State.Opened[0] := True;
  T.RenderStateful(Area, Buf, State);
  AssertEqInt(3, State.FlatCount, 'expanded: parent + 2 children');
  AssertTrue(Pos('[-]', Buf.RowAsString(0)) > 0, 'shows [-] marker');
  AssertTrue(Pos('child1', Buf.RowAsString(1)) > 0, 'child1 visible');
  AssertTrue(Pos('child2', Buf.RowAsString(2)) > 0, 'child2 visible');
  Buf.Free;
end;

procedure Test_Toggle;
var
  State: TTreeState;
begin
  State := TTreeState.Empty;
  AssertTrue(not State.IsOpen(0), 'initially closed');
  State.Toggle(0);
  AssertTrue(State.IsOpen(0), 'after toggle: open');
  State.Toggle(0);
  AssertTrue(not State.IsOpen(0), 'after second toggle: closed');
end;

procedure Test_Indentation;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
  Row1: AnsiString;
begin
  Area := TRect.Make(0, 0, 40, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([
    TTreeNode.Make('root').WithChildren([
      TTreeNode.Make('leaf')
    ])
  ]).WithIndent(3);
  State := TTreeState.Empty;
  State.EnsureSize(1);
  State.Opened[0] := True;
  T.RenderStateful(Area, Buf, State);
  Row1 := Buf.RowAsString(1);
  // Child should be indented by 3 spaces (IndentSize=3, depth=1)
  AssertTrue(Copy(Row1, 1, 3) = '   ', 'child indented by 3');
  Buf.Free;
end;

procedure Test_ScrollOnSelection;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
begin
  Area := TRect.Make(0, 0, 20, 2);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([
    TTreeNode.Make('a'),
    TTreeNode.Make('b'),
    TTreeNode.Make('c'),
    TTreeNode.Make('d')
  ]);
  State := TTreeState.Empty;
  State.Selected := 3;
  T.RenderStateful(Area, Buf, State);
  AssertTrue(State.Offset >= 2, 'scrolled to show selection');
  Buf.Free;
end;

procedure Test_NestedExpand;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
begin
  Area := TRect.Make(0, 0, 40, 10);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([
    TTreeNode.Make('A').WithChildren([
      TTreeNode.Make('A1').WithChildren([
        TTreeNode.Make('A1a')
      ]),
      TTreeNode.Make('A2')
    ])
  ]);
  State := TTreeState.Empty;
  // Open A (idx 0) and A1 (idx 1)
  State.EnsureSize(2);
  State.Opened[0] := True;
  State.Opened[1] := True;
  T.RenderStateful(Area, Buf, State);
  AssertEqInt(4, State.FlatCount, 'A + A1 + A1a + A2');
  AssertTrue(Pos('A1a', Buf.RowAsString(2)) > 0, 'nested child visible');
  Buf.Free;
end;

procedure Test_EmptyTree;
var
  T: TTree;
  Buf: TBuffer;
  Area: TRect;
  State: TTreeState;
begin
  Area := TRect.Make(0, 0, 20, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTree.Create([]);
  State := TTreeState.Empty;
  T.RenderStateful(Area, Buf, State);
  AssertEqInt(0, State.FlatCount, 'empty tree = 0 rows');
  Buf.Free;
end;

procedure RegisterTreeTests;
begin
  RegisterTest('tree / flat render',          @Test_FlatRender);
  RegisterTest('tree / children collapsed',   @Test_ChildrenCollapsed);
  RegisterTest('tree / children expanded',    @Test_ChildrenExpanded);
  RegisterTest('tree / toggle state',         @Test_Toggle);
  RegisterTest('tree / indentation',          @Test_Indentation);
  RegisterTest('tree / scroll on selection',  @Test_ScrollOnSelection);
  RegisterTest('tree / nested expand',        @Test_NestedExpand);
  RegisterTest('tree / empty tree',           @Test_EmptyTree);
end;

end.
