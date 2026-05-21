unit test_table;

{$mode objfpc}{$H+}

interface

procedure RegisterTableTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_layout,
  ftui_table;

procedure Test_BasicRender;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('Name', LengthConstraint(10)),
    TTableColumn.Make('Age', LengthConstraint(10))
  ]).WithRows([
    TTableRow.Make(['Alice', '30']),
    TTableRow.Make(['Bob', '25'])
  ]);
  T.Render(Area, Buf);
  // Header row should contain column titles
  AssertTrue(Pos('Name', Buf.RowAsString(0)) > 0, 'header has Name');
  AssertTrue(Pos('Age', Buf.RowAsString(0)) > 0, 'header has Age');
  // Data rows
  AssertTrue(Pos('Alice', Buf.RowAsString(1)) > 0, 'row 1 has Alice');
  AssertTrue(Pos('30', Buf.RowAsString(1)) > 0, 'row 1 has 30');
  AssertTrue(Pos('Bob', Buf.RowAsString(2)) > 0, 'row 2 has Bob');
  Buf.Free;
end;

procedure Test_SelectionHighlight;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
  State: TTableState;
  CP: PCell;
begin
  Area := TRect.Make(0, 0, 20, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('X', LengthConstraint(20))
  ]).WithRows([
    TTableRow.Make(['first']),
    TTableRow.Make(['second'])
  ]).WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]));
  State := TTableState.Empty;
  State.Select(1);
  T.RenderStateful(Area, Buf, State);
  // Row 1 (data index 1) is at Y=2 (header at Y=0, data starts Y=1)
  CP := Buf.CellAt(0, 2);
  AssertTrue(CP <> nil, 'cell exists');
  AssertTrue(mbReversed in CP^.Modifier, 'selected row has reversed');
  Buf.Free;
end;

procedure Test_ScrollOffset;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
  State: TTableState;
begin
  // Area only fits header + 2 data rows
  Area := TRect.Make(0, 0, 20, 3);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('V', LengthConstraint(20))
  ]).WithRows([
    TTableRow.Make(['r0']),
    TTableRow.Make(['r1']),
    TTableRow.Make(['r2']),
    TTableRow.Make(['r3'])
  ]);
  State := TTableState.Empty;
  State.Select(3);
  T.RenderStateful(Area, Buf, State);
  // With selection at 3 and only 2 visible rows, offset should scroll
  AssertTrue(State.Offset >= 2, 'offset scrolled to show selection');
  Buf.Free;
end;

procedure Test_NoHeader;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 3);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('Col', LengthConstraint(20))
  ]).WithRows([
    TTableRow.Make(['data1']),
    TTableRow.Make(['data2']),
    TTableRow.Make(['data3'])
  ]).WithHeader(False);
  T.Render(Area, Buf);
  // Without header, first row should be data
  AssertTrue(Pos('data1', Buf.RowAsString(0)) > 0, 'no header: row 0 is data');
  AssertTrue(Pos('data2', Buf.RowAsString(1)) > 0, 'no header: row 1 is data');
  AssertTrue(Pos('data3', Buf.RowAsString(2)) > 0, 'no header: row 2 is data');
  Buf.Free;
end;

procedure Test_ColumnAlignment;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
  Row: AnsiString;
begin
  Area := TRect.Make(0, 0, 20, 2);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('R', LengthConstraint(10)).WithAlign(caRight),
    TTableColumn.Make('L', LengthConstraint(10))
  ]).WithRows([
    TTableRow.Make(['hi', 'lo'])
  ]);
  T.Render(Area, Buf);
  Row := Buf.RowAsString(1);
  // Right-aligned 'hi' in 10 cols should have leading spaces
  AssertTrue(Pos('hi', Row) > 1, 'right-aligned has leading space');
  Buf.Free;
end;

procedure Test_EmptyTable;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 20, 5);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('A', LengthConstraint(10))
  ]);
  T.Render(Area, Buf);
  // Should not crash, header still renders
  AssertTrue(Pos('A', Buf.RowAsString(0)) > 0, 'empty table still shows header');
  Buf.Free;
end;

procedure Test_ConstraintWidths;
var
  T: TTable;
  Buf: TBuffer;
  Area: TRect;
begin
  Area := TRect.Make(0, 0, 30, 3);
  Buf := TBuffer.CreateEmpty(Area);
  T := TTable.Create([
    TTableColumn.Make('Fixed', LengthConstraint(10)),
    TTableColumn.Make('Flex', MinConstraint(0))
  ]).WithRows([
    TTableRow.Make(['A', 'B'])
  ]);
  T.Render(Area, Buf);
  // Flex column should fill remaining 20 cols
  AssertTrue(Pos('B', Buf.RowAsString(1)) > 0, 'flex column renders');
  Buf.Free;
end;

procedure RegisterTableTests;
begin
  RegisterTest('table / basic render',         @Test_BasicRender);
  RegisterTest('table / selection highlight',  @Test_SelectionHighlight);
  RegisterTest('table / scroll offset',        @Test_ScrollOffset);
  RegisterTest('table / no header',            @Test_NoHeader);
  RegisterTest('table / column alignment',     @Test_ColumnAlignment);
  RegisterTest('table / empty table',          @Test_EmptyTable);
  RegisterTest('table / constraint widths',    @Test_ConstraintWidths);
end;

end.
