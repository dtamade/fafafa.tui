unit ftui_color_cap;

{$mode objfpc}{$H+}{$inline on}

interface

uses
  ftui_color;

type
  TColorCapability = (ccMono, cc16, cc256, ccTrueColor);

function DetectColorCapability: TColorCapability;
function ResolveColor(const C: TColor; Cap: TColorCapability): TColor;

implementation

uses
  SysUtils;

const
  CUBE_VALUES: array[0..5] of Byte = (0, 95, 135, 175, 215, 255);

function CubeToRgb(Idx: Byte; out R, G, B: Byte): Boolean; inline;
var Off: Byte;
begin
  if (Idx < 16) or (Idx > 231) then Exit(False);
  Off := Idx - 16;
  R := CUBE_VALUES[Off div 36];
  G := CUBE_VALUES[(Off div 6) mod 6];
  B := CUBE_VALUES[Off mod 6];
  Result := True;
end;

function GrayToRgb(Idx: Byte; out V: Byte): Boolean; inline;
begin
  if (Idx < 232) or (Idx > 255) then Exit(False);
  V := 8 + (Idx - 232) * 10;
  Result := True;
end;

function ColorDist(R1, G1, B1, R2, G2, B2: Integer): Integer; inline;
begin
  Result := (R1-R2)*(R1-R2) + (G1-G2)*(G1-G2) + (B1-B2)*(B1-B2);
end;
function RgbToNearest256(R, G, B: Byte): Byte;
var
  I, D, Best, BestD: Integer;
  CR, CG, CB, GV: Byte;
begin
  Best := 16;
  BestD := MaxInt;
  for I := 16 to 231 do
  begin
    CubeToRgb(I, CR, CG, CB);
    D := ColorDist(R, G, B, CR, CG, CB);
    if D < BestD then begin BestD := D; Best := I; end;
  end;
  for I := 232 to 255 do
  begin
    GrayToRgb(I, GV);
    D := ColorDist(R, G, B, GV, GV, GV);
    if D < BestD then begin BestD := D; Best := I; end;
  end;
  Result := Best;
end;

function Index256To16(Idx: Byte): Byte;
var R, G, B, GV: Byte; Lum: Integer;
begin
  if Idx < 16 then Exit(Idx);
  if CubeToRgb(Idx, R, G, B) then
  begin
    Lum := (Integer(R)*299 + Integer(G)*587 + Integer(B)*114) div 1000;
    if Lum > 170 then Result := 15
    else if Lum > 85 then
    begin
      if (R > G) and (R > B) then Result := 9
      else if (G > R) and (G > B) then Result := 10
      else if (B > R) and (B > G) then Result := 12
      else Result := 7;
    end
    else
    begin
      if (R > G) and (R > B) then Result := 1
      else if (G > R) and (G > B) then Result := 2
      else if (B > R) and (B > G) then Result := 4
      else Result := 0;
    end;
  end
  else if GrayToRgb(Idx, GV) then
  begin
    if GV > 192 then Result := 15
    else if GV > 128 then Result := 7
    else if GV > 64 then Result := 8
    else Result := 0;
  end
  else
    Result := 7;
end;
function DetectColorCapability: TColorCapability;
var CT, Term: AnsiString;
begin
  CT := GetEnvironmentVariable('COLORTERM');
  if (CT = 'truecolor') or (CT = '24bit') then Exit(ccTrueColor);
  Term := GetEnvironmentVariable('TERM');
  if Pos('256color', Term) > 0 then Exit(cc256);
  if (Term = 'linux') or (Term = 'dumb') then Exit(ccMono);
  Result := cc16;
end;

function ResolveColor(const C: TColor; Cap: TColorCapability): TColor;
begin
  case C.Kind of
    ckUnset, ckReset:
      Result := C;
    ckRgb:
      case Cap of
        ccTrueColor: Result := C;
        cc256: Result := IndexedColor(RgbToNearest256(C.R, C.G, C.B));
        cc16:  Result := IndexedColor(Index256To16(RgbToNearest256(C.R, C.G, C.B)));
        ccMono: Result := ResetColor;
      end;
    ckIndexed:
      case Cap of
        ccTrueColor, cc256: Result := C;
        cc16:
          if C.Index >= 16 then
            Result := IndexedColor(Index256To16(C.Index))
          else
            Result := C;
        ccMono: Result := ResetColor;
      end;
  end;
end;

end.
