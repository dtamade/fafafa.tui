unit ftui_tabs;

// Horizontal tab bar widget.
//
// Renders tab titles separated by a configurable separator string.
// The selected tab (via TTabsState.Selected) uses ActiveStyle; all
// others use InactiveStyle.  Truncates output if total width exceeds
// the available Area.Width.

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
  ftui_grapheme;

type
  TTabsState = record
    Selected: Integer;
  end;

  TTabs = record
    Titles: array of AnsiString;
    ActiveStyle: TStyle;
    InactiveStyle: TStyle;
    Separator: AnsiString;

    class function Create(const ATitles: array of AnsiString): TTabs; static;
    function WithActiveStyle(const S: TStyle): TTabs;
    function WithInactiveStyle(const S: TStyle): TTabs;
    function WithSeparator(const S: AnsiString): TTabs;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTabsState);
  end;

implementation

{ TTabs }

class function TTabs.Create(const ATitles: array of AnsiString): TTabs;
var
  I: Integer;
begin
  SetLength(Result.Titles, Length(ATitles));
  for I := 0 to High(ATitles) do
    Result.Titles[I] := ATitles[I];
  Result.ActiveStyle := TStyle.Default;
  Result.InactiveStyle := TStyle.Default;
  Result.Separator := ' | ';
end;

function TTabs.WithActiveStyle(const S: TStyle): TTabs;
begin
  Result := Self;
  Result.ActiveStyle := S;
end;

function TTabs.WithInactiveStyle(const S: TStyle): TTabs;
begin
  Result := Self;
  Result.InactiveStyle := S;
end;

function TTabs.WithSeparator(const S: AnsiString): TTabs;
begin
  Result := Self;
  Result.Separator := S;
end;

procedure TTabs.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TTabsState);
var
  N, I, Cursor, MaxX, TitleW, SepW, Written: Integer;
  Y: Integer;
  Sty: TStyle;
begin
  if Area.IsEmpty then Exit;
  N := Length(Titles);
  if N = 0 then Exit;

  Y := Area.Y;
  MaxX := Area.X + Area.Width;
  Cursor := Area.X;
  SepW := GraphemeWidth(Separator);

  for I := 0 to N - 1 do
  begin
    if Cursor >= MaxX then Break;

    // Insert separator before all tabs except the first
    if I > 0 then
    begin
      if Cursor + SepW > MaxX then
      begin
        // Partial separator: write what fits
        Written := ABuf.SetStringN(Cursor, Y, Separator, MaxX - Cursor, InactiveStyle);
        Inc(Cursor, Written);
        Break;
      end;
      Written := ABuf.SetStringN(Cursor, Y, Separator, SepW, InactiveStyle);
      Inc(Cursor, Written);
      if Cursor >= MaxX then Break;
    end;

    // Determine style for this tab
    if I = State.Selected then
      Sty := ActiveStyle
    else
      Sty := InactiveStyle;

    // Write the title, clipped to remaining width
    TitleW := MaxX - Cursor;
    Written := ABuf.SetStringN(Cursor, Y, Titles[I], TitleW, Sty);
    Inc(Cursor, Written);
  end;
end;

end.
