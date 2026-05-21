unit test_file_tree;

{$mode objfpc}{$H+}

interface

procedure RegisterFileTreeTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_buffer,
  ftui_file_tree;

procedure Test_EmptyState;
var S: TFileTreeState;
begin
  S := TFileTreeState.Empty;
  AssertEqInt(0, Length(S.Nodes), 'no nodes');
  AssertEqInt(0, S.Selected, 'selected 0');
end;

procedure Test_AddNodes;
var S: TFileTreeState;
begin
  S := TFileTreeState.Empty;
  S.AddNode('src', True, 0);
  S.AddNode('main.pas', False, 1);
  S.AddNode('utils.pas', False, 1);
  AssertEqInt(3, Length(S.Nodes), '3 nodes');
  AssertTrue(S.Nodes[0].IsDir, 'first is dir');
  AssertTrue(not S.Nodes[1].IsDir, 'second is file');
end;

procedure Test_ToggleExpand;
var S: TFileTreeState;
begin
  S := TFileTreeState.Empty;
  S.AddNode('dir', True, 0);
  AssertTrue(S.Nodes[0].Expanded, 'expanded by default');
  S.Selected := 0;
  S.ToggleExpand;
  AssertTrue(not S.Nodes[0].Expanded, 'collapsed');
  S.ToggleExpand;
  AssertTrue(S.Nodes[0].Expanded, 'expanded again');
end;

procedure Test_SelectNavigation;
var S: TFileTreeState;
begin
  S := TFileTreeState.Empty;
  S.AddNode('a', False, 0);
  S.AddNode('b', False, 0);
  S.AddNode('c', False, 0);
  S.SelectNext;
  AssertEqInt(1, S.Selected, 'next');
  S.SelectNext;
  AssertEqInt(2, S.Selected, 'next again');
  S.SelectPrev;
  AssertEqInt(1, S.Selected, 'prev');
end;

procedure Test_RenderShowsFiles;
var
  FT: TFileTree;
  S: TFileTreeState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  S := TFileTreeState.Empty;
  S.AddNode('src', True, 0);
  S.AddNode('main.pas', False, 1);
  FT := TFileTree.Default;
  FT.RenderStateful(Area, Buf, S);
  AssertTrue(Pos('src', Buf.RowAsString(0)) > 0, 'dir visible');
  AssertTrue(Pos('main.pas', Buf.RowAsString(1)) > 0, 'file visible');
  Buf.Free;
end;

procedure Test_CollapsedHidesChildren;
var
  FT: TFileTree;
  S: TFileTreeState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 5);
  Buf := TBuffer.CreateEmpty(Area);
  S := TFileTreeState.Empty;
  S.AddNode('src', True, 0);
  S.AddNode('hidden.pas', False, 1);
  S.AddNode('visible.txt', False, 0);
  S.Nodes[0].Expanded := False;
  FT := TFileTree.Default;
  FT.RenderStateful(Area, Buf, S);
  AssertTrue(Pos('hidden', Buf.RowAsString(1)) = 0, 'child hidden when collapsed');
  AssertTrue(Pos('visible', Buf.RowAsString(1)) > 0, 'sibling visible');
  Buf.Free;
end;

procedure Test_DirMarkers;
var
  FT: TFileTree;
  S: TFileTreeState;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 3);
  Buf := TBuffer.CreateEmpty(Area);
  S := TFileTreeState.Empty;
  S.AddNode('open_dir', True, 0);
  S.AddNode('closed_dir', True, 0);
  S.Nodes[1].Expanded := False;
  FT := TFileTree.Default;
  FT.RenderStateful(Area, Buf, S);
  AssertTrue(Pos('[-]', Buf.RowAsString(0)) > 0, 'expanded marker');
  AssertTrue(Pos('[+]', Buf.RowAsString(1)) > 0, 'collapsed marker');
  Buf.Free;
end;

procedure RegisterFileTreeTests;
begin
  RegisterTest('file_tree / empty state',       @Test_EmptyState);
  RegisterTest('file_tree / add nodes',         @Test_AddNodes);
  RegisterTest('file_tree / toggle expand',     @Test_ToggleExpand);
  RegisterTest('file_tree / select navigation', @Test_SelectNavigation);
  RegisterTest('file_tree / render files',      @Test_RenderShowsFiles);
  RegisterTest('file_tree / collapsed hides',   @Test_CollapsedHidesChildren);
  RegisterTest('file_tree / dir markers',       @Test_DirMarkers);
end;

end.
