unit ftui_tooltip;

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
  ftui_block,
  ftui_borders;

type
  TTooltipPosition = (ttpAbove, ttpBelow, ttpLeft, ttpRight);

  TTooltip = record
    Text: AnsiString;
    Position: TTooltipPosition;
    Style: TStyle;
    BorderStyle: TStyle;
    MaxWidth: Integer;

    class function Create(const AText: AnsiString): TTooltip; static;
    function WithPosition(P: TTooltipPosition): TTooltip;
    function WithStyle(const S: TStyle): TTooltip;
    function WithBorderStyle(const S: TStyle): TTooltip;
    function WithMaxWidth(W: Integer): TTooltip;
    procedure Render(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
  end;

implementation

uses
  SysUtils;

class function TTooltip.Create(const AText: AnsiString): TTooltip;
begin
  Result.Text := AText;
  Result.Position := ttpAbove;
  Result.Style := TStyle.Default;
  Result.BorderStyle := TStyle.Default.WithFg(clWhite);
  Result.MaxWidth := 40;
end;

function TTooltip.WithPosition(P: TTooltipPosition): TTooltip;
begin Result := Self; Result.Position := P; end;

function TTooltip.WithStyle(const S: TStyle): TTooltip;
begin Result := Self; Result.Style := S; end;

function TTooltip.WithBorderStyle(const S: TStyle): TTooltip;
begin Result := Self; Result.BorderStyle := S; end;

function TTooltip.WithMaxWidth(W: Integer): TTooltip;
begin Result := Self; Result.MaxWidth := W; end;

procedure TTooltip.Render(const Anchor: TRect; const Bounds: TRect; ABuf: TBuffer);
var
  TipW, TipH, TipX, TipY: Integer;
  TipArea: TRect;
begin
  if Length(Text) = 0 then Exit;

  TipW := Length(Text) + 2; // +2 for border
  if TipW > MaxWidth then TipW := MaxWidth;
  TipH := 3; // border + text + border

  // Position relative to anchor
  case Position of
    ttpAbove:
    begin
      TipX := Anchor.X;
      TipY := Anchor.Y - TipH;
    end;
    ttpBelow:
    begin
      TipX := Anchor.X;
      TipY := Anchor.Y + Anchor.Height;
    end;
    ttpLeft:
    begin
      TipX := Anchor.X - TipW;
      TipY := Anchor.Y;
    end;
    ttpRight:
    begin
      TipX := Anchor.X + Anchor.Width;
      TipY := Anchor.Y;
    end;
  end;

  // Clamp to bounds (upper first, then lower wins if too small)
  if TipX + TipW > Bounds.X + Bounds.Width then
    TipX := Bounds.X + Bounds.Width - TipW;
  if TipY + TipH > Bounds.Y + Bounds.Height then
    TipY := Bounds.Y + Bounds.Height - TipH;
  if TipX < Bounds.X then TipX := Bounds.X;
  if TipY < Bounds.Y then TipY := Bounds.Y;

  // Clamp width if tooltip wider than bounds
  if TipW > Bounds.Width then TipW := Bounds.Width;
  if TipH > Bounds.Height then TipH := Bounds.Height;

  TipArea := TRect.Make(TipX, TipY, TipW, TipH);
  if TipArea.IsEmpty then Exit;

  // Render bordered tooltip
  ABuf.SetStyle(TipArea, Style);
  TBlock.Default.WithBorders(BordersAll)
    .WithBorderStyle(BorderStyle)
    .Render(TipArea, ABuf);

  // Text inside
  ABuf.SetStringN(TipX + 1, TipY + 1, Text, TipW - 2, Style);
end;

end.
