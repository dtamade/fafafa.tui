unit ftui_layout;

// Constraint-based 1-D split.
//
// ratatui ships with cassowary; we don't.  fafafa.tui supports only
// the three Constraint kinds cli888 actually uses (Length / Min /
// Percentage), and resolves them with a deterministic three-pass
// algorithm.  The algorithm matches ratatui semantics on every test
// case in our suite, but it does NOT generalise to mixed Min+Max or
// Ratio — those constraint kinds are out of scope.
//
// Algorithm (for total = Area.Width or Area.Height):
//
//   1. Pass 1 — Length: every Length(L) takes exactly L (clamped to
//      [0, remaining]).  Subtract from `remaining`.
//   2. Pass 2 — Percentage: every Percentage(P) takes
//      round(total * P / 100), clamped to [0, remaining].  We use the
//      *original* total, not the post-Length remaining, so percentages
//      stay stable when sibling Lengths are added/removed (matches
//      ratatui CASS-with-equal-strength behaviour).
//   3. Pass 3 — Min: distribute remaining space equally among Min
//      slots, with each slot guaranteed >= its Min(N).  If
//      `remaining < sum_of_mins`, mins still get their floor and the
//      total may exceed the area — caller is responsible for keeping
//      sums sane.
//   4. The residual (remaining after Pass 3) is added to the LAST
//      flexible slot — Min, then Percentage, then Length, in that
//      reverse-priority order.  This matches the ratatui Legacy flex
//      mode "trailing slot absorbs leftover" behaviour.
//
// Output positions are assigned left-to-right (or top-to-bottom) so
// adjacent rects share an edge with no gap.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}

interface

uses
  ftui_rect;

type
  TConstraintKind = (ckLength, ckMin, ckMax, ckPercentage, ckFill);

  TConstraint = packed record
    Kind: TConstraintKind;
    Value: Word;
    Value2: Word;   // ckFill: weight; unused for others
  end;

  TDirection = (dirHorizontal, dirVertical);

  TConstraints = array of TConstraint;
  TRectArray   = array of TRect;
  TIntArray    = array of Integer;

  TLayout = record
    Direction: TDirection;
    Constraints: TConstraints;

    class function Default: TLayout; static;
    class function Horizontal(const Cs: array of TConstraint): TLayout; static;
    class function Vertical(const Cs: array of TConstraint): TLayout; static;

    function WithDirection(D: TDirection): TLayout;
    function WithConstraints(const Cs: array of TConstraint): TLayout;
    function Split(const Area: TRect): TRectArray;
  end;

function LengthConstraint(N: Word): TConstraint; inline;
function MinConstraint(N: Word): TConstraint; inline;
function MaxConstraint(N: Word): TConstraint; inline;
function PercentageConstraint(N: Word): TConstraint; inline;
function FillConstraint(Weight: Word): TConstraint; inline;

// Stand-alone helpers for callers who don't want to build a TLayout
// just to slice a rect.
function HorizontalSplit(const Area: TRect; const Cs: array of TConstraint): TRectArray;
function VerticalSplit  (const Area: TRect; const Cs: array of TConstraint): TRectArray;

implementation

function LengthConstraint(N: Word): TConstraint;
begin
  Result.Kind := ckLength;
  Result.Value := N;
  Result.Value2 := 0;
end;

function MinConstraint(N: Word): TConstraint;
begin
  Result.Kind := ckMin;
  Result.Value := N;
  Result.Value2 := 0;
end;

function MaxConstraint(N: Word): TConstraint;
begin
  Result.Kind := ckMax;
  Result.Value := N;
  Result.Value2 := 0;
end;

function PercentageConstraint(N: Word): TConstraint;
begin
  Result.Kind := ckPercentage;
  Result.Value := N;
  Result.Value2 := 0;
end;

function FillConstraint(Weight: Word): TConstraint;
begin
  Result.Kind := ckFill;
  Result.Value := 0;
  Result.Value2 := Weight;
  if Weight = 0 then Result.Value2 := 1;
end;

{ TLayout }

class function TLayout.Default: TLayout;
begin
  Result.Direction := dirVertical;
  Result.Constraints := nil;
end;

class function TLayout.Horizontal(const Cs: array of TConstraint): TLayout;
begin
  Result := Default;
  Result.Direction := dirHorizontal;
  Result := Result.WithConstraints(Cs);
end;

class function TLayout.Vertical(const Cs: array of TConstraint): TLayout;
begin
  Result := Default;
  Result.Direction := dirVertical;
  Result := Result.WithConstraints(Cs);
end;

function TLayout.WithDirection(D: TDirection): TLayout;
begin
  Result := Self;
  Result.Direction := D;
end;

function TLayout.WithConstraints(const Cs: array of TConstraint): TLayout;
var
  I: Integer;
begin
  Result := Self;
  SetLength(Result.Constraints, System.Length(Cs));
  for I := 0 to System.High(Cs) do
    Result.Constraints[I] := Cs[I];
end;

// Compute slot sizes along the chosen axis.  Returns an array the same
// length as Cs.  Total is the available extent (Area.Width or
// Area.Height); the algorithm is described in the unit header.
function ComputeSlotSizes(Total: Integer;
  const Cs: array of TConstraint): TIntArray;
var
  N, I, Want, Take, MinCount, Remaining: Integer;
  LastFlexIdx: Integer;
  FillTotal, FillWeight: Integer;
begin
  N := System.Length(Cs);
  SetLength(Result, N);
  if N = 0 then Exit;

  Remaining := Total;
  if Remaining < 0 then Remaining := 0;

  // Pass 1 — Length.
  for I := 0 to N - 1 do
    if Cs[I].Kind = ckLength then
    begin
      Want := Cs[I].Value;
      if Want > Remaining then Want := Remaining;
      Result[I] := Want;
      Dec(Remaining, Want);
    end;

  // Pass 2 — Percentage of the original Total.
  for I := 0 to N - 1 do
    if Cs[I].Kind = ckPercentage then
    begin
      Want := (Total * Cs[I].Value) div 100;
      if Want > Remaining then Want := Remaining;
      Result[I] := Want;
      Dec(Remaining, Want);
    end;

  // Pass 3 — Max: takes up to Value, but no more than fair share.
  for I := 0 to N - 1 do
    if Cs[I].Kind = ckMax then
    begin
      Want := Remaining;
      if Want > Integer(Cs[I].Value) then Want := Cs[I].Value;
      if Want < 0 then Want := 0;
      Result[I] := Want;
      Dec(Remaining, Want);
    end;

  // Pass 4 — Min: distribute remaining over Min slots.
  MinCount := 0;
  for I := 0 to N - 1 do
    if Cs[I].Kind = ckMin then Inc(MinCount);

  if MinCount > 0 then
  begin
    if Remaining < 0 then Remaining := 0;
    for I := 0 to N - 1 do
      if Cs[I].Kind = ckMin then
      begin
        if MinCount > 1 then
          Take := Remaining div MinCount
        else
          Take := Remaining;
        if Take < Cs[I].Value then Take := Cs[I].Value;
        if Take > Remaining then Take := Remaining;
        if Take < 0 then Take := 0;
        Result[I] := Take;
        Dec(Remaining, Take);
        Dec(MinCount);
      end;
  end;

  // Pass 5 — Fill: distribute remaining by weight.
  FillTotal := 0;
  for I := 0 to N - 1 do
    if Cs[I].Kind = ckFill then
      Inc(FillTotal, Cs[I].Value2);

  if (FillTotal > 0) and (Remaining > 0) then
  begin
    for I := 0 to N - 1 do
      if Cs[I].Kind = ckFill then
      begin
        FillWeight := Cs[I].Value2;
        Take := (Remaining * FillWeight) div FillTotal;
        Result[I] := Take;
      end;
    // Assign residual to last Fill slot
    Want := 0;
    for I := 0 to N - 1 do
      if Cs[I].Kind = ckFill then Inc(Want, Result[I]);
    if Want < Remaining then
      for I := N - 1 downto 0 do
        if Cs[I].Kind = ckFill then
        begin
          Inc(Result[I], Remaining - Want);
          Break;
        end;
    Remaining := 0;
  end;

  // Pass 6 — absorb residual into the last non-Max slot.
  if Remaining <> 0 then
  begin
    LastFlexIdx := -1;
    for I := N - 1 downto 0 do
      if Cs[I].Kind <> ckMax then
      begin
        LastFlexIdx := I;
        Break;
      end;
    if LastFlexIdx >= 0 then
    begin
      if Result[LastFlexIdx] + Remaining < 0 then
        Result[LastFlexIdx] := 0
      else
        Inc(Result[LastFlexIdx], Remaining);
    end;
  end;
end;

function TLayout.Split(const Area: TRect): TRectArray;
var
  Sizes: TIntArray;
  Total, I, Cursor: Integer;
begin
  if Direction = dirHorizontal then
    Total := Area.Width
  else
    Total := Area.Height;

  Sizes := ComputeSlotSizes(Total, Constraints);
  SetLength(Result, System.Length(Sizes));

  Cursor := 0;
  for I := 0 to System.High(Sizes) do
  begin
    if Direction = dirHorizontal then
    begin
      Result[I] := TRect.Make(Area.X + Cursor, Area.Y, Sizes[I], Area.Height);
    end
    else
    begin
      Result[I] := TRect.Make(Area.X, Area.Y + Cursor, Area.Width, Sizes[I]);
    end;
    Inc(Cursor, Sizes[I]);
  end;
end;

function HorizontalSplit(const Area: TRect; const Cs: array of TConstraint): TRectArray;
begin
  Result := TLayout.Horizontal(Cs).Split(Area);
end;

function VerticalSplit(const Area: TRect; const Cs: array of TConstraint): TRectArray;
begin
  Result := TLayout.Vertical(Cs).Split(Area);
end;

end.
