unit ftui_modifier;

// 1:1 mapping of ratatui::style::Modifier (a u16 bitflags) onto a Pascal
// `set of` enum.  All nine bits ratatui ships with are present in the
// same logical positions; FPC compiles `set of TModifierBit` (9 elements)
// into a single 16-bit word, so AddMod/SubMod fields combine via plain
// integer AND/OR/XOR — exactly what bitflags does on the Rust side.
//
// Hot paths use `+ - *` (union / difference / intersection) on TModifier
// directly.  No heap, no class, no allocation.

{$mode objfpc}{$H+}{$inline on}
{$packset 2}         // pack `set of` to 2 bytes (9 elements -> u16)

interface

type
  TModifierBit = (
    mbBold,        // SGR 1
    mbDim,         // SGR 2
    mbItalic,      // SGR 3
    mbUnderlined,  // SGR 4
    mbSlowBlink,   // SGR 5
    mbRapidBlink,  // SGR 6
    mbReversed,    // SGR 7
    mbHidden,      // SGR 8
    mbCrossedOut   // SGR 9
  );

  TModifier = set of TModifierBit;

const
  ModifierNone: TModifier = [];

function ModifierEquals(const A, B: TModifier): Boolean; inline;
function ModifierIsEmpty(const M: TModifier): Boolean; inline;

implementation

function ModifierEquals(const A, B: TModifier): Boolean;
begin
  Result := A = B;
end;

function ModifierIsEmpty(const M: TModifier): Boolean;
begin
  Result := M = [];
end;

end.
