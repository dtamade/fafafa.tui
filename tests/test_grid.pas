unit test_grid;

{$mode objfpc}{$H+}

interface

procedure RegisterGridTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_layout,
  ftui_layout_dsl,
  ftui_grid;

procedure Test_UniformGrid;
var
  G: TGridResult;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 20);
  G := Grid(Area, 2, 3);
  AssertEqInt(2, G.Rows, '2 rows');
  AssertEqInt(3, G.Cols, '3 cols');
  AssertEqInt(10, G.Cell(0, 0).Width, 'cell width 10');
  AssertEqInt(10, G.Cell(0, 0).Height, 'cell height 10');
  AssertEqInt(10, G.Cell(0, 1).X, 'col 1 starts at 10');
  AssertEqInt(10, G.Cell(1, 0).Y, 'row 1 starts at 10');
end;

procedure Test_ConstraintGrid;
var
  G: TGridResult;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 40, 10);
  G := Grid(Area,
    [LengthConstraint(3), Flex(1)],
    [LengthConstraint(10), Flex(1), LengthConstraint(5)]
  );
  AssertEqInt(2, G.Rows, '2 rows');
  AssertEqInt(3, G.Cols, '3 cols');
  AssertEqInt(3, G.Cell(0, 0).Height, 'first row height 3');
  AssertEqInt(7, G.Cell(1, 0).Height, 'second row flex');
  AssertEqInt(10, G.Cell(0, 0).Width, 'first col width 10');
  AssertEqInt(5, G.Cell(0, 2).Width, 'third col width 5');
  AssertEqInt(25, G.Cell(0, 1).Width, 'middle col flex');
end;

procedure Test_CellAccessor;
var
  G: TGridResult;
  Area: TRect;
  R: TRect;
begin
  Area := TRect.Make(5, 5, 20, 10);
  G := Grid(Area, 2, 2);
  R := G.Cell(0, 0);
  AssertEqInt(5, R.X, 'origin X');
  AssertEqInt(5, R.Y, 'origin Y');
  R := G.Cell(1, 1);
  AssertEqInt(15, R.X, 'cell(1,1) X');
  AssertEqInt(10, R.Y, 'cell(1,1) Y');
end;

procedure Test_OutOfBounds;
var
  G: TGridResult;
  Area: TRect;
  R: TRect;
begin
  Area := TRect.Make(0, 0, 20, 10);
  G := Grid(Area, 2, 2);
  R := G.Cell(5, 5);
  AssertTrue(R.IsEmpty, 'out of bounds returns empty');
end;

procedure Test_EmptyArea;
var
  G: TGridResult;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 0, 0);
  G := Grid(Area, 3, 3);
  AssertEqInt(0, Length(G.Cells), 'no cells for empty area');
end;

procedure Test_SingleCell;
var
  G: TGridResult;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 50, 25);
  G := Grid(Area, 1, 1);
  AssertEqInt(50, G.Cell(0, 0).Width, 'full width');
  AssertEqInt(25, G.Cell(0, 0).Height, 'full height');
end;

procedure Test_Adjacency;
var
  G: TGridResult;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 20);
  G := Grid(Area, 2, 3);
  // Cells should be adjacent (no gaps)
  AssertEqInt(G.Cell(0, 0).X + G.Cell(0, 0).Width, G.Cell(0, 1).X, 'col 0 right = col 1 left');
  AssertEqInt(G.Cell(0, 0).Y + G.Cell(0, 0).Height, G.Cell(1, 0).Y, 'row 0 bottom = row 1 top');
end;

procedure RegisterGridTests;
begin
  RegisterTest('grid / uniform grid',       @Test_UniformGrid);
  RegisterTest('grid / constraint grid',    @Test_ConstraintGrid);
  RegisterTest('grid / cell accessor',      @Test_CellAccessor);
  RegisterTest('grid / out of bounds',      @Test_OutOfBounds);
  RegisterTest('grid / empty area',         @Test_EmptyArea);
  RegisterTest('grid / single cell',        @Test_SingleCell);
  RegisterTest('grid / adjacency',          @Test_Adjacency);
end;

end.
