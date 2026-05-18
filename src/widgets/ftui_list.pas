unit ftui_list;

// List + ListState — vertical scrolling list of single-line items.
//
// Scope (matches cli888):
//   - Vertical only (TopToBottom)
//   - Single-line items (each TListItem.Content is one line of bytes)
//   - Optional Block surround
//   - Highlight: selected row gets HighlightStyle patched on, with
//     an optional HighlightSymbol gutter
//
// Out of scope (cli888 uses 0):
//   - ListDirection BottomToTop
//   - HighlightSpacing variants (we always reserve gutter when symbol set)
//   - Multi-line items + repeat_highlight_symbol
//   - scroll_padding (kept simple)
//
// Offset adjustment (per ratatui get_items_bounds):
//   1. Clamp State.Offset to [0, len-1]
//   2. Walk forward from Offset accumulating row heights until they
//      would overflow Inner.Height — that gives us the visible window
//   3. If Selected lies past LastVisible, move LastVisible forward
//      and trim FirstVisible until height fits again
//   4. If Selected lies before FirstVisible, do the symmetric thing
//   5. Write back FirstVisible into State.Offset
//
// For single-line items height_of(item) == 1, so the algorithm
// degenerates: visible rows = Inner.Height; if Selected is outside
// [Offset, Offset+visible), move Offset.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_text,
  ftui_block;

type
  TListItem = record
    Content: AnsiString;
    Style: TStyle;

    class function FromString(const S: AnsiString): TListItem; static;
    function WithStyle(const St: TStyle): TListItem;
  end;

  TListItems = array of TListItem;

  TListState = record
    Offset: Integer;
    HasSelection: Boolean;
    Selected: Integer;

    class function Empty: TListState; static;
    procedure Select(I: Integer);
    procedure ClearSelection;
  end;

  TList = record
    Items: TListItems;
    Style: TStyle;
    HighlightStyle: TStyle;
    HighlightSymbol: AnsiString;
    HasHighlightSymbol: Boolean;
    HasBlock: Boolean;
    Block: TBlock;

    class function Create(const AItems: array of TListItem): TList; static;
    class function FromStrings(const AItems: array of AnsiString): TList; static;

    function WithBlock(const B: TBlock): TList;
    function WithStyle(const S: TStyle): TList;
    function WithHighlightStyle(const S: TStyle): TList;
    function WithHighlightSymbol(const Sym: AnsiString): TList;

    procedure Render(const Area: TRect; ABuf: TBuffer);
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TListState);
  end;

implementation

{ TListItem }

class function TListItem.FromString(const S: AnsiString): TListItem;
begin
  Result.Content := S;
  Result.Style := TStyle.Default;
end;

function TListItem.WithStyle(const St: TStyle): TListItem;
begin
  Result := Self;
  Result.Style := St;
end;

{ TListState }

class function TListState.Empty: TListState;
begin
  Result.Offset := 0;
  Result.HasSelection := False;
  Result.Selected := 0;
end;

procedure TListState.Select(I: Integer);
begin
  HasSelection := True;
  Selected := I;
end;

procedure TListState.ClearSelection;
begin
  HasSelection := False;
end;

{ TList }

class function TList.Create(const AItems: array of TListItem): TList;
var
  I: Integer;
begin
  SetLength(Result.Items, Length(AItems));
  for I := 0 to High(AItems) do
    Result.Items[I] := AItems[I];
  Result.Style := TStyle.Default;
  Result.HighlightStyle := TStyle.Default;
  Result.HighlightSymbol := '';
  Result.HasHighlightSymbol := False;
  Result.HasBlock := False;
  Result.Block := TBlock.Default;
end;

class function TList.FromStrings(const AItems: array of AnsiString): TList;
var
  I: Integer;
  Built: array of TListItem;
begin
  SetLength(Built, Length(AItems));
  for I := 0 to High(AItems) do
    Built[I] := TListItem.FromString(AItems[I]);
  Result := TList.Create(Built);
end;

function TList.WithBlock(const B: TBlock): TList;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := B;
end;

function TList.WithStyle(const S: TStyle): TList;
begin
  Result := Self;
  Result.Style := S;
end;

function TList.WithHighlightStyle(const S: TStyle): TList;
begin
  Result := Self;
  Result.HighlightStyle := S;
end;

function TList.WithHighlightSymbol(const Sym: AnsiString): TList;
begin
  Result := Self;
  Result.HighlightSymbol := Sym;
  Result.HasHighlightSymbol := Length(Sym) > 0;
end;

procedure TList.Render(const Area: TRect; ABuf: TBuffer);
var
  Dummy: TListState;
begin
  Dummy := TListState.Empty;
  RenderStateful(Area, ABuf, Dummy);
end;

procedure TList.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TListState);
var
  Clip, Inner: TRect;
  N, GutterW, MaxRows, Visible: Integer;
  FirstVis, LastVis: Integer;
  RowY, RowIdx, X, ItemMaxW: Integer;
  Sty: TStyle;
  Sel: Integer;
  Sym, Blank: AnsiString;
begin
  Clip := ABuf.Area.Intersection(Area);
  if Clip.IsEmpty then Exit;

  ABuf.SetStyle(Clip, Style);

  if HasBlock then
  begin
    Block.Render(Clip, ABuf);
    Inner := Block.Inner(Clip);
  end
  else
    Inner := Clip;

  if Inner.IsEmpty then Exit;
  ABuf.SetStyle(Inner, Style);

  N := Length(Items);
  if N = 0 then
  begin
    State.ClearSelection;
    Exit;
  end;

  // Reserve gutter for highlight symbol when configured.  ratatui uses
  // HighlightSpacing::Always | WhenSelected; we go with WhenSelected
  // semantics: gutter shows iff a symbol is configured AND selection
  // is set.  Matches cli888 behaviour.
  GutterW := 0;
  if HasHighlightSymbol and State.HasSelection then
    GutterW := Length(HighlightSymbol);

  ItemMaxW := Inner.Width - GutterW;
  if ItemMaxW < 0 then ItemMaxW := 0;

  // Clamp Selected to a valid index — defensive against external state.
  if State.HasSelection then
  begin
    if State.Selected < 0 then State.Selected := 0;
    if State.Selected >= N then State.Selected := N - 1;
  end;

  // Single-line items => visible window length == Inner.Height.
  MaxRows := Inner.Height;
  Visible := MaxRows;
  if Visible > N then Visible := N;

  FirstVis := State.Offset;
  if FirstVis < 0 then FirstVis := 0;
  if FirstVis > N - 1 then FirstVis := N - 1;
  LastVis := FirstVis + Visible;
  if LastVis > N then
  begin
    LastVis := N;
    FirstVis := N - Visible;
    if FirstVis < 0 then FirstVis := 0;
  end;

  if State.HasSelection then
  begin
    Sel := State.Selected;
    // Pull window down if selection is past the right edge.
    while Sel >= LastVis do
    begin
      Inc(LastVis);
      if LastVis - FirstVis > Visible then
        Inc(FirstVis);
    end;
    // Pull window up if selection is before the left edge.
    while Sel < FirstVis do
    begin
      Dec(FirstVis);
      if LastVis - FirstVis > Visible then
        Dec(LastVis);
    end;
  end;

  State.Offset := FirstVis;

  // Pre-build the blank gutter.  Constant string; we reuse it for
  // every non-selected row that needs gutter padding.
  if GutterW > 0 then
  begin
    SetLength(Blank, GutterW);
    FillChar(Blank[1], GutterW, Ord(' '));
  end
  else
    Blank := '';

  RowIdx := FirstVis;
  RowY := Inner.Y;
  while (RowIdx < LastVis) and (RowY < Inner.Y + Inner.Height) do
  begin
    // Row base style: list.style patched with item.style.
    Sty := Style.Patch(Items[RowIdx].Style);

    // Apply per-item style across the entire visible row (including
    // gutter), so highlighting later overlays uniformly.
    ABuf.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), Sty);

    // Gutter: highlight symbol on selected row, blank on others.
    if GutterW > 0 then
    begin
      if State.HasSelection and (RowIdx = State.Selected) then
        Sym := HighlightSymbol
      else
        Sym := Blank;
      ABuf.SetStringN(Inner.X, RowY, Sym, GutterW, Sty);
    end;

    // Item content area: shifted past gutter, clipped to ItemMaxW.
    X := Inner.X + GutterW;
    if ItemMaxW > 0 then
      ABuf.SetStringN(X, RowY, Items[RowIdx].Content, ItemMaxW, Sty);

    // Highlight overlay on the selected row.  Last so it wins over
    // both gutter and content style.
    if State.HasSelection and (RowIdx = State.Selected) then
      ABuf.SetStyle(TRect.Make(Inner.X, RowY, Inner.Width, 1), HighlightStyle);

    Inc(RowIdx);
    Inc(RowY);
  end;
end;

end.
