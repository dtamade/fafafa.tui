unit ftui_layout_dsl;

// Convenience DSL over ftui_layout.
//
// Short function names for common constraint + split patterns:
//   Fixed(N)    = LengthConstraint(N)
//   Flex(W)     = FillConstraint(W)
//   Pct(N)      = PercentageConstraint(N)
//   AtLeast(N)  = MinConstraint(N)
//   AtMost(N)   = MaxConstraint(N)
//   V(Area, Cs) = VerticalSplit(Area, Cs)
//   H(Area, Cs) = HorizontalSplit(Area, Cs)

{$mode objfpc}{$H+}{$inline on}

interface

uses
  ftui_rect,
  ftui_layout;

function Fixed(N: Word): TConstraint; inline;
function Flex(Weight: Word = 1): TConstraint; inline;
function Pct(N: Word): TConstraint; inline;
function AtLeast(N: Word): TConstraint; inline;
function AtMost(N: Word): TConstraint; inline;

function V(const Area: TRect; const Cs: array of TConstraint): TRectArray;
function H(const Area: TRect; const Cs: array of TConstraint): TRectArray;

implementation

function Fixed(N: Word): TConstraint;
begin
  Result := LengthConstraint(N);
end;

function Flex(Weight: Word = 1): TConstraint;
begin
  Result := FillConstraint(Weight);
end;

function Pct(N: Word): TConstraint;
begin
  Result := PercentageConstraint(N);
end;

function AtLeast(N: Word): TConstraint;
begin
  Result := MinConstraint(N);
end;

function AtMost(N: Word): TConstraint;
begin
  Result := MaxConstraint(N);
end;

function V(const Area: TRect; const Cs: array of TConstraint): TRectArray;
begin
  Result := VerticalSplit(Area, Cs);
end;

function H(const Area: TRect; const Cs: array of TConstraint): TRectArray;
begin
  Result := HorizontalSplit(Area, Cs);
end;

end.
