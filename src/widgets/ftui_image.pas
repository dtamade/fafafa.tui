unit ftui_image;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_rect,
  ftui_style,
  ftui_buffer;

type
  TImageProtocol = (ipKitty, ipSixel, ipHalfBlock);

  TImagePixel = packed record
    R, G, B, A: Byte;
  end;

  TImageData = record
    Pixels: array of TImagePixel;
    Width: Integer;
    Height: Integer;

    class function Create(AWidth, AHeight: Integer): TImageData; static;
    procedure SetPixel(X, Y: Integer; R, G, B: Byte; A: Byte = 255);
    function GetPixel(X, Y: Integer): TImagePixel; inline;
  end;

  TImage = record
    Data: TImageData;
    Protocol: TImageProtocol;
    Style: TStyle;

    class function Create(const AData: TImageData): TImage; static;
    function WithProtocol(P: TImageProtocol): TImage;
    function WithStyle(const S: TStyle): TImage;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

function DetectImageProtocol: TImageProtocol;
function EncodeKittyImage(const Data: TImageData; const Area: TRect): AnsiString;
function EncodeSixelImage(const Data: TImageData; const Area: TRect): AnsiString;

implementation

uses
  SysUtils, ftui_color, ftui_cell;

{ TImageData }

class function TImageData.Create(AWidth, AHeight: Integer): TImageData;
begin
  Result.Width := AWidth;
  Result.Height := AHeight;
  SetLength(Result.Pixels, AWidth * AHeight);
  if AWidth * AHeight > 0 then
    FillChar(Result.Pixels[0], AWidth * AHeight * SizeOf(TImagePixel), 0);
end;

procedure TImageData.SetPixel(X, Y: Integer; R, G, B: Byte; A: Byte);
begin
  if (X >= 0) and (X < Width) and (Y >= 0) and (Y < Height) then
  begin
    Pixels[Y * Width + X].R := R;
    Pixels[Y * Width + X].G := G;
    Pixels[Y * Width + X].B := B;
    Pixels[Y * Width + X].A := A;
  end;
end;

function TImageData.GetPixel(X, Y: Integer): TImagePixel;
begin
  if (X >= 0) and (X < Width) and (Y >= 0) and (Y < Height) then
    Result := Pixels[Y * Width + X]
  else
  begin
    Result.R := 0; Result.G := 0; Result.B := 0; Result.A := 0;
  end;
end;

{ TImage }

class function TImage.Create(const AData: TImageData): TImage;
begin
  Result.Data := AData;
  Result.Protocol := ipHalfBlock;
  Result.Style := TStyle.Default;
end;

function TImage.WithProtocol(P: TImageProtocol): TImage;
begin Result := Self; Result.Protocol := P; end;

function TImage.WithStyle(const S: TStyle): TImage;
begin Result := Self; Result.Style := S; end;

procedure TImage.Render(const Area: TRect; ABuf: TBuffer);
var
  X, Y, SrcX, SrcY, TopY, BotY: Integer;
  TopP, BotP: TImagePixel;
  CellSty: TStyle;
begin
  if Area.IsEmpty then Exit;
  if (Data.Width = 0) or (Data.Height = 0) then Exit;

  case Protocol of
    ipHalfBlock:
    begin
      for Y := 0 to Area.Height - 1 do
      begin
        TopY := (Y * 2) * Data.Height div (Area.Height * 2);
        BotY := (Y * 2 + 1) * Data.Height div (Area.Height * 2);
        for X := 0 to Area.Width - 1 do
        begin
          SrcX := X * Data.Width div Area.Width;
          TopP := Data.GetPixel(SrcX, TopY);
          BotP := Data.GetPixel(SrcX, BotY);

          CellSty := TStyle.Default
            .WithFg(RgbColor(TopP.R, TopP.G, TopP.B))
            .WithBg(RgbColor(BotP.R, BotP.G, BotP.B));

          ABuf.SetStringN(Area.X + X, Area.Y + Y, #$E2#$96#$80, 1, CellSty);
        end;
      end;
    end;
    ipKitty, ipSixel:
      ; // These protocols write escape sequences directly to terminal
        // and cannot be rendered through the cell buffer.
        // Use EncodeKittyImage/EncodeSixelImage for direct output.
  end;
end;

function DetectImageProtocol: TImageProtocol;
var Term: AnsiString;
begin
  Term := GetEnvironmentVariable('TERM');
  if (Pos('kitty', Term) > 0) or (GetEnvironmentVariable('KITTY_WINDOW_ID') <> '') then
    Result := ipKitty
  else if (Pos('sixel', GetEnvironmentVariable('TERM_FEATURES')) > 0) then
    Result := ipSixel
  else
    Result := ipHalfBlock;
end;

const
  Base64Chars: AnsiString = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function Base64Encode(const Data: array of Byte; Len: Integer): AnsiString;
var
  I, OutLen, Pad: Integer;
  B0, B1, B2: Byte;
begin
  OutLen := ((Len + 2) div 3) * 4;
  SetLength(Result, OutLen);
  I := 0;
  Pad := 0;
  while I < Len do
  begin
    B0 := Data[I];
    if I + 1 < Len then B1 := Data[I + 1] else begin B1 := 0; Inc(Pad); end;
    if I + 2 < Len then B2 := Data[I + 2] else begin B2 := 0; Inc(Pad); end;

    Result[(I div 3) * 4 + 1] := Base64Chars[(B0 shr 2) + 1];
    Result[(I div 3) * 4 + 2] := Base64Chars[((B0 and 3) shl 4 or (B1 shr 4)) + 1];
    Result[(I div 3) * 4 + 3] := Base64Chars[((B1 and $0F) shl 2 or (B2 shr 6)) + 1];
    Result[(I div 3) * 4 + 4] := Base64Chars[(B2 and $3F) + 1];

    Inc(I, 3);
  end;
  if Pad >= 1 then Result[OutLen] := '=';
  if Pad >= 2 then Result[OutLen - 1] := '=';
end;

function EncodeKittyImage(const Data: TImageData; const Area: TRect): AnsiString;
var
  RawBytes: array of Byte;
  I, Len: Integer;
  Encoded: AnsiString;
begin
  Len := Data.Width * Data.Height * 4;
  SetLength(RawBytes, Len);
  for I := 0 to Data.Width * Data.Height - 1 do
  begin
    RawBytes[I * 4] := Data.Pixels[I].R;
    RawBytes[I * 4 + 1] := Data.Pixels[I].G;
    RawBytes[I * 4 + 2] := Data.Pixels[I].B;
    RawBytes[I * 4 + 3] := Data.Pixels[I].A;
  end;

  Encoded := Base64Encode(RawBytes, Len);

  // Kitty graphics protocol: ESC_G with RGBA payload
  Result := Format(#27'_Gf=32,s=%d,v=%d,a=T,t=d;%s'#27'\', [
    Data.Width, Data.Height, Encoded
  ]);
end;

function EncodeSixelImage(const Data: TImageData; const Area: TRect): AnsiString;
var
  Y, X, Band, Bit: Integer;
  P: TImagePixel;
  SixelByte: Byte;
  ColorIdx: Integer;
begin
  // Simplified sixel: monochrome threshold
  Result := #27'P0;0;0q';
  Result := Result + Format('"1;1;%d;%d', [Data.Width, Data.Height]);

  // Color 1 = white
  Result := Result + '#1;2;100;100;100';
  Result := Result + '#1';

  for Band := 0 to (Data.Height - 1) div 6 do
  begin
    for X := 0 to Data.Width - 1 do
    begin
      SixelByte := 0;
      for Bit := 0 to 5 do
      begin
        Y := Band * 6 + Bit;
        if Y < Data.Height then
        begin
          P := Data.GetPixel(X, Y);
          // Luminance threshold
          if (Integer(P.R) + Integer(P.G) + Integer(P.B)) div 3 > 128 then
            SixelByte := SixelByte or (1 shl Bit);
        end;
      end;
      Result := Result + Chr(SixelByte + 63);
    end;
    if Band < (Data.Height - 1) div 6 then
      Result := Result + '-';
  end;

  Result := Result + #27'\';
end;

end.
