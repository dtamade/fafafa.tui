unit ftui_scrollbar;

// Scrollbar primitive — track/thumb calculation, hit-test, drag state,
// and rendering.  Vertical only (horizontal can be added later with
// the same logic rotated 90°).
//
// Usage:
//   1. Set TotalItems, VisibleItems, ScrollOffset
//   2. Call Render(Area, Buf, Style) to draw
//   3. On mouse events, call HitTest/HandleDrag to update ScrollOffset
//
// The scrollbar is a "dumb" record — it doesn't own state beyond what
// the consumer passes in.  Drag state is managed externally via
// TPointerCapture + TInteractionSession.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}

interface

uses
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_cell,
  ftui_buffer;

type
  TScrollbarHit = (shNone, shAbove, shThumb, shBelow);

  TScrollbarStyle = record
    TrackChar: AnsiChar;
    ThumbChar: AnsiChar;
    TrackStyle: TStyle;
    ThumbStyle: TStyle;
  end;

  TScrollbar = record
    TotalItems: Integer;
    VisibleItems: Integer;
    ScrollOffset: Integer;

    // Calculate thumb position and size within a vertical track.
    function ThumbStart(TrackHeight: Integer): Integer;
    function ThumbSize(TrackHeight: Integer): Integer;

    // Hit-test: which part of the scrollbar was clicked?
    function HitAt(TrackArea: TRect; Y: Integer): TScrollbarHit;

    // Given a drag Y position within the track, compute the new ScrollOffset.
    function OffsetFromDragY(TrackArea: TRect; DragY: Integer): Integer;

    // Page up/down: move by VisibleItems.
    function PageUp: Integer;
    function PageDown: Integer;

    // Clamp ScrollOffset to valid range.
    function Clamped: Integer;

    // Render into a 1-column-wide vertical area.
    procedure Render(const TrackArea: TRect; ABuf: TBuffer; const Sty: TScrollbarStyle);
  end;

function DefaultScrollbarStyle: TScrollbarStyle;

implementation

function DefaultScrollbarStyle: TScrollbarStyle;
begin
  Result.TrackChar := ' ';
  Result.ThumbChar := ' ';
  Result.TrackStyle := TStyle.Default.WithBg(IndexedColor(236));
  Result.ThumbStyle := TStyle.Default.WithBg(IndexedColor(245));
end;

function TScrollbar.ThumbStart(TrackHeight: Integer): Integer;
begin
  if TotalItems <= VisibleItems then Exit(0);
  Result := (ScrollOffset * (TrackHeight - ThumbSize(TrackHeight))) div (TotalItems - VisibleItems);
  if Result < 0 then Result := 0;
end;

function TScrollbar.ThumbSize(TrackHeight: Integer): Integer;
begin
  if TotalItems <= 0 then Exit(TrackHeight);
  Result := (VisibleItems * TrackHeight) div TotalItems;
  if Result < 1 then Result := 1;
  if Result > TrackHeight then Result := TrackHeight;
end;

function TScrollbar.HitAt(TrackArea: TRect; Y: Integer): TScrollbarHit;
var
  RelY, TS, TSz: Integer;
begin
  Result := shNone;
  if (Y < TrackArea.Y) or (Y >= TrackArea.Y + TrackArea.Height) then Exit;
  RelY := Y - TrackArea.Y;
  TS := ThumbStart(TrackArea.Height);
  TSz := ThumbSize(TrackArea.Height);
  if RelY < TS then Result := shAbove
  else if RelY < TS + TSz then Result := shThumb
  else Result := shBelow;
end;

function TScrollbar.OffsetFromDragY(TrackArea: TRect; DragY: Integer): Integer;
var
  RelY, TrackH, TSz, MaxOffset, AvailTrack: Integer;
begin
  TrackH := TrackArea.Height;
  TSz := ThumbSize(TrackH);
  AvailTrack := TrackH - TSz;
  if AvailTrack <= 0 then Exit(0);
  MaxOffset := TotalItems - VisibleItems;
  if MaxOffset <= 0 then Exit(0);
  RelY := DragY - TrackArea.Y;
  if RelY < 0 then RelY := 0;
  if RelY > AvailTrack then RelY := AvailTrack;
  Result := (RelY * MaxOffset) div AvailTrack;
end;

function TScrollbar.PageUp: Integer;
begin
  Result := ScrollOffset - VisibleItems;
  if Result < 0 then Result := 0;
end;

function TScrollbar.PageDown: Integer;
var Max: Integer;
begin
  Max := TotalItems - VisibleItems;
  if Max < 0 then Max := 0;
  Result := ScrollOffset + VisibleItems;
  if Result > Max then Result := Max;
end;

function TScrollbar.Clamped: Integer;
var Max: Integer;
begin
  Max := TotalItems - VisibleItems;
  if Max < 0 then Max := 0;
  Result := ScrollOffset;
  if Result < 0 then Result := 0;
  if Result > Max then Result := Max;
end;

procedure TScrollbar.Render(const TrackArea: TRect; ABuf: TBuffer; const Sty: TScrollbarStyle);
var
  Y, TS, TSz: Integer;
  C: TCell;
begin
  if TrackArea.Width < 1 then Exit;
  TS := ThumbStart(TrackArea.Height);
  TSz := ThumbSize(TrackArea.Height);
  for Y := 0 to TrackArea.Height - 1 do
  begin
    C := CellEmpty;
    if (Y >= TS) and (Y < TS + TSz) then
    begin
      CellSetSymbolAscii(C, Sty.ThumbChar);
      CellApplyStyle(C, Sty.ThumbStyle);
    end
    else
    begin
      CellSetSymbolAscii(C, Sty.TrackChar);
      CellApplyStyle(C, Sty.TrackStyle);
    end;
    ABuf.CellAt(TrackArea.X, TrackArea.Y + Y)^ := C;
  end;
end;

end.
