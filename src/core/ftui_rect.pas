unit ftui_rect;

// Geometry primitives shared by every other ftui_* unit.
//
// All four types are 1:1 with ratatui::layout (Rect / Position / Size /
// Margin). Stored as `packed record` so they pass by value cheaply
// (4 Words = 8 bytes for TRect) and never allocate.
//
// Word-sized fields (u16) match ratatui exactly — terminal sizes never
// exceed u16 in practice and matching the upstream type avoids signed
// overflow when intersecting two rects near the screen edge.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

type
  TPosition = packed record
    X, Y: Word;
  end;

  TSize = packed record
    Width, Height: Word;
  end;

  TMargin = packed record
    Horizontal, Vertical: Word;
  end;

  TRect = packed record
    X, Y, Width, Height: Word;

    class function Make(AX, AY, AW, AH: Word): TRect; static; inline;

    function Area: LongWord; inline;
    function Left: Word; inline;
    function Right: Word; inline;          // exclusive: X + Width
    function Top: Word; inline;
    function Bottom: Word; inline;         // exclusive: Y + Height

    function IsEmpty: Boolean; inline;
    function Contains(const P: TPosition): Boolean; inline;
    function Intersects(const Other: TRect): Boolean;
    function Intersection(const Other: TRect): TRect;
    function Union(const Other: TRect): TRect;
    function Inner(const M: TMargin): TRect;
  end;

function PositionMake(X, Y: Word): TPosition; inline;
function SizeMake(W, H: Word): TSize; inline;
function MarginMake(H, V: Word): TMargin; inline;

function RectEquals(const A, B: TRect): Boolean; inline;
function PositionEquals(const A, B: TPosition): Boolean; inline;

implementation

function PositionMake(X, Y: Word): TPosition;
begin
  Result.X := X;
  Result.Y := Y;
end;

function SizeMake(W, H: Word): TSize;
begin
  Result.Width := W;
  Result.Height := H;
end;

function MarginMake(H, V: Word): TMargin;
begin
  Result.Horizontal := H;
  Result.Vertical := V;
end;

function PositionEquals(const A, B: TPosition): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

function RectEquals(const A, B: TRect): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y) and
            (A.Width = B.Width) and (A.Height = B.Height);
end;

class function TRect.Make(AX, AY, AW, AH: Word): TRect;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Width := AW;
  Result.Height := AH;
end;

function TRect.Area: LongWord;
begin
  Result := LongWord(Width) * LongWord(Height);
end;

function TRect.Left: Word;
begin
  Result := X;
end;

function TRect.Right: Word;
begin
  Result := X + Width;
end;

function TRect.Top: Word;
begin
  Result := Y;
end;

function TRect.Bottom: Word;
begin
  Result := Y + Height;
end;

function TRect.IsEmpty: Boolean;
begin
  Result := (Width = 0) or (Height = 0);
end;

function TRect.Contains(const P: TPosition): Boolean;
begin
  Result := (P.X >= X) and (P.X < Right) and
            (P.Y >= Y) and (P.Y < Bottom);
end;

function TRect.Intersects(const Other: TRect): Boolean;
begin
  Result := (X < Other.Right) and (Right > Other.X) and
            (Y < Other.Bottom) and (Bottom > Other.Y);
end;

function TRect.Intersection(const Other: TRect): TRect;
var
  L, R, T, B: Integer;
begin
  if not Intersects(Other) then
  begin
    Result := TRect.Make(0, 0, 0, 0);
    Exit;
  end;
  L := X; if Other.X > L then L := Other.X;
  T := Y; if Other.Y > T then T := Other.Y;
  R := Right; if Other.Right < R then R := Other.Right;
  B := Bottom; if Other.Bottom < B then B := Other.Bottom;
  Result := TRect.Make(L, T, R - L, B - T);
end;

function TRect.Union(const Other: TRect): TRect;
var
  L, R, T, B: Integer;
begin
  if Self.IsEmpty then
  begin
    Result := Other;
    Exit;
  end;
  if Other.IsEmpty then
  begin
    Result := Self;
    Exit;
  end;
  L := X; if Other.X < L then L := Other.X;
  T := Y; if Other.Y < T then T := Other.Y;
  R := Right; if Other.Right > R then R := Other.Right;
  B := Bottom; if Other.Bottom > B then B := Other.Bottom;
  Result := TRect.Make(L, T, R - L, B - T);
end;

function TRect.Inner(const M: TMargin): TRect;
var
  DH, DV: LongInt;
  NewW, NewH: LongInt;
begin
  DH := LongInt(M.Horizontal) * 2;
  DV := LongInt(M.Vertical) * 2;
  if DH >= LongInt(Width) then
    NewW := 0
  else
    NewW := LongInt(Width) - DH;
  if DV >= LongInt(Height) then
    NewH := 0
  else
    NewH := LongInt(Height) - DV;
  if NewW = 0 then
  begin
    Result := TRect.Make(X, Y, 0, 0);
    Exit;
  end;
  Result := TRect.Make(X + M.Horizontal, Y + M.Vertical, NewW, NewH);
end;

end.
