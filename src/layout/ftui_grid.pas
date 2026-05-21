unit ftui_grid;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_rect,
  ftui_layout;

type
  TGridResult = record
    Cells: array of array of TRect;
    Rows: Integer;
    Cols: Integer;
    function Cell(Row, Col: Integer): TRect; inline;
  end;

function Grid(const Area: TRect;
  const RowConstraints: array of TConstraint;
  const ColConstraints: array of TConstraint): TGridResult;

function Grid(const Area: TRect;
  RowCount, ColCount: Integer): TGridResult;

implementation

function TGridResult.Cell(Row, Col: Integer): TRect;
begin
  if (Row >= 0) and (Row < Rows) and (Col >= 0) and (Col < Cols) then
    Result := Cells[Row][Col]
  else
    Result := TRect.Make(0, 0, 0, 0);
end;

function Grid(const Area: TRect;
  const RowConstraints: array of TConstraint;
  const ColConstraints: array of TConstraint): TGridResult;
var
  RowRects: TRectArray;
  ColRects: TRectArray;
  R, C, NR, NC: Integer;
begin
  NR := Length(RowConstraints);
  NC := Length(ColConstraints);
  Result.Rows := NR;
  Result.Cols := NC;

  if (NR = 0) or (NC = 0) or Area.IsEmpty then
  begin
    SetLength(Result.Cells, 0);
    Exit;
  end;

  // Split area into rows
  RowRects := VerticalSplit(Area, RowConstraints);

  SetLength(Result.Cells, NR, NC);

  for R := 0 to NR - 1 do
  begin
    // Split each row into columns
    ColRects := HorizontalSplit(RowRects[R], ColConstraints);
    for C := 0 to NC - 1 do
      Result.Cells[R][C] := ColRects[C];
  end;
end;

function Grid(const Area: TRect; RowCount, ColCount: Integer): TGridResult;
var
  RowCs, ColCs: array of TConstraint;
  I: Integer;
begin
  SetLength(RowCs, RowCount);
  SetLength(ColCs, ColCount);
  for I := 0 to RowCount - 1 do
    RowCs[I] := FillConstraint(1);
  for I := 0 to ColCount - 1 do
    ColCs[I] := FillConstraint(1);
  Result := Grid(Area, RowCs, ColCs);
end;

end.
