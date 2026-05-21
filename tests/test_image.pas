unit test_image;

{$mode objfpc}{$H+}

interface

procedure RegisterImageTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_rect,
  ftui_style,
  ftui_color,
  ftui_buffer,
  ftui_image;

procedure Test_CreateImageData;
var D: TImageData;
begin
  D := TImageData.Create(10, 5);
  AssertEqInt(10, D.Width, 'width');
  AssertEqInt(5, D.Height, 'height');
  AssertEqInt(50, Length(D.Pixels), 'pixel count');
end;

procedure Test_SetGetPixel;
var D: TImageData; P: TImagePixel;
begin
  D := TImageData.Create(4, 4);
  D.SetPixel(2, 3, 255, 128, 64, 200);
  P := D.GetPixel(2, 3);
  AssertEqInt(255, Integer(P.R), 'R');
  AssertEqInt(128, Integer(P.G), 'G');
  AssertEqInt(64, Integer(P.B), 'B');
  AssertEqInt(200, Integer(P.A), 'A');
end;

procedure Test_GetPixelOutOfBounds;
var D: TImageData; P: TImagePixel;
begin
  D := TImageData.Create(2, 2);
  P := D.GetPixel(5, 5);
  AssertEqInt(0, Integer(P.R), 'OOB R=0');
  AssertEqInt(0, Integer(P.A), 'OOB A=0');
end;

procedure Test_HalfBlockRender;
var
  Img: TImage;
  D: TImageData;
  Buf: TBuffer;
  Area: TRect;
  Row: AnsiString;
begin
  D := TImageData.Create(4, 4);
  D.SetPixel(0, 0, 255, 0, 0);
  D.SetPixel(1, 0, 0, 255, 0);
  Area := TRect.Make(0, 0, 4, 2);
  Buf := TBuffer.CreateEmpty(Area);
  Img := TImage.Create(D).WithProtocol(ipHalfBlock);
  Img.Render(Area, Buf);
  Row := Buf.RowAsString(0);
  AssertTrue(Length(Row) > 0, 'half-block rendered');
  Buf.Free;
end;

procedure Test_DetectProtocol;
var P: TImageProtocol;
begin
  P := DetectImageProtocol;
  AssertTrue(P in [ipKitty, ipSixel, ipHalfBlock], 'valid protocol');
end;

procedure Test_EncodeKitty;
var
  D: TImageData;
  S: AnsiString;
begin
  D := TImageData.Create(2, 2);
  D.SetPixel(0, 0, 255, 0, 0, 255);
  D.SetPixel(1, 0, 0, 255, 0, 255);
  S := EncodeKittyImage(D, TRect.Make(0, 0, 2, 1));
  AssertTrue(Pos('_G', S) > 0, 'kitty escape present');
  AssertTrue(Pos('f=32', S) > 0, 'RGBA format');
  AssertTrue(Pos('s=2', S) > 0, 'width=2');
  AssertTrue(Pos('v=2', S) > 0, 'height=2');
end;

procedure Test_EncodeSixel;
var
  D: TImageData;
  S: AnsiString;
begin
  D := TImageData.Create(3, 6);
  D.SetPixel(0, 0, 255, 255, 255);
  D.SetPixel(1, 1, 255, 255, 255);
  S := EncodeSixelImage(D, TRect.Make(0, 0, 3, 1));
  AssertTrue(Pos(#27'P', S) = 1, 'sixel DCS start');
  AssertTrue(Pos(#27'\', S) > 0, 'sixel ST end');
end;

procedure Test_EmptyImageNoCrash;
var
  Img: TImage;
  D: TImageData;
  Buf: TBuffer;
  Area: TRect;
begin
  D := TImageData.Create(0, 0);
  Area := TRect.Make(0, 0, 10, 5);
  Buf := TBuffer.CreateEmpty(Area);
  Img := TImage.Create(D);
  Img.Render(Area, Buf);
  AssertTrue(True, 'no crash on empty image');
  Buf.Free;
end;

procedure RegisterImageTests;
begin
  RegisterTest('image / create data',         @Test_CreateImageData);
  RegisterTest('image / set get pixel',       @Test_SetGetPixel);
  RegisterTest('image / get pixel OOB',       @Test_GetPixelOutOfBounds);
  RegisterTest('image / half-block render',   @Test_HalfBlockRender);
  RegisterTest('image / detect protocol',     @Test_DetectProtocol);
  RegisterTest('image / encode kitty',        @Test_EncodeKitty);
  RegisterTest('image / encode sixel',        @Test_EncodeSixel);
  RegisterTest('image / empty no crash',      @Test_EmptyImageNoCrash);
end;

end.
