unit ftui_style;

// 1:1 mapping of ratatui::style::Style.
//
// Layout — a packed record passed by value everywhere:
//
//   Fg, Bg, Ul: TColor          (4 bytes each; ckUnset = ratatui None)
//   AddMod, SubMod: TModifier   (2 bytes each; disjoint by construction)
//
// Patch semantics are taken verbatim from ratatui 0.29 Style::patch:
//
//   Fg/Bg/Ul   ── other.X.or(self.X)         (other wins iff set)
//   AddMod     ── (self.AddMod - other.SubMod) + other.AddMod
//   SubMod     ── (self.SubMod - other.AddMod) + other.SubMod
//
// A single modifier bit can never live in both AddMod and SubMod after
// patching — the receiver's prior state is overridden by whichever side
// of `other` mentions it.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_color,
  ftui_modifier;

type
  TStyle = packed record
    Fg, Bg, Ul: TColor;
    AddMod, SubMod: TModifier;

    class function Default: TStyle; static; inline;

    function WithFg(const C: TColor): TStyle;
    function WithBg(const C: TColor): TStyle;
    function WithUnderline(const C: TColor): TStyle;

    // Add the given modifier bits and clear them from SubMod.
    function WithModifier(const M: TModifier): TStyle;

    // Add the given modifier bits to SubMod and clear them from AddMod.
    function WithoutModifier(const M: TModifier): TStyle;

    // Combine two styles. `Other` overrides `Self` field-by-field using
    // ratatui's exact rule (see unit header).
    function Patch(const Other: TStyle): TStyle;
  end;

function StyleDefault: TStyle; inline;
function StyleEquals(const A, B: TStyle): Boolean; inline;

implementation

class function TStyle.Default: TStyle;
begin
  Result.Fg := UnsetColor;
  Result.Bg := UnsetColor;
  Result.Ul := UnsetColor;
  Result.AddMod := [];
  Result.SubMod := [];
end;

function StyleDefault: TStyle;
begin
  Result := TStyle.Default;
end;

function TStyle.WithFg(const C: TColor): TStyle;
begin
  Result := Self;
  Result.Fg := C;
end;

function TStyle.WithBg(const C: TColor): TStyle;
begin
  Result := Self;
  Result.Bg := C;
end;

function TStyle.WithUnderline(const C: TColor): TStyle;
begin
  Result := Self;
  Result.Ul := C;
end;

function TStyle.WithModifier(const M: TModifier): TStyle;
begin
  Result := Self;
  Result.AddMod := Result.AddMod + M;
  Result.SubMod := Result.SubMod - M;
end;

function TStyle.WithoutModifier(const M: TModifier): TStyle;
begin
  Result := Self;
  Result.SubMod := Result.SubMod + M;
  Result.AddMod := Result.AddMod - M;
end;

function TStyle.Patch(const Other: TStyle): TStyle;
begin
  Result := Self;
  if ColorIsSet(Other.Fg) then Result.Fg := Other.Fg;
  if ColorIsSet(Other.Bg) then Result.Bg := Other.Bg;
  if ColorIsSet(Other.Ul) then Result.Ul := Other.Ul;
  Result.AddMod := (Result.AddMod - Other.SubMod) + Other.AddMod;
  Result.SubMod := (Result.SubMod - Other.AddMod) + Other.SubMod;
end;

function StyleEquals(const A, B: TStyle): Boolean;
begin
  Result := ColorEquals(A.Fg, B.Fg) and
            ColorEquals(A.Bg, B.Bg) and
            ColorEquals(A.Ul, B.Ul) and
            (A.AddMod = B.AddMod) and
            (A.SubMod = B.SubMod);
end;

end.
