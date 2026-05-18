unit test_clear;

{$mode objfpc}{$H+}

interface

procedure RegisterClearTests;

implementation

uses
  ftui_testkit,
  ftui_rect,
  ftui_color,
  ftui_style,
  ftui_buffer,
  ftui_clear;

procedure Test_ClearOnEmptyBufferIsIdentity;
var
  Buf: TBuffer;
  C: TClear;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    C := ClearWidget;
    C.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['    ', '    ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_ClearWipesPreviousContent;
var
  Buf: TBuffer;
  C: TClear;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    Buf.SetString(0, 0, 'noisy', TStyle.Default.WithFg(clRed));
    Buf.SetString(0, 1, 'data!', TStyle.Default.WithBg(clBlue));
    C := ClearWidget;
    C.Render(Buf.Area, Buf);
    AssertBufferEquals(Buf, ['     ', '     ']);
  finally
    Buf.Free;
  end;
end;

procedure Test_ClearOnSubAreaLeavesRestUntouched;
var
  Buf: TBuffer;
  C: TClear;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    Buf.SetString(0, 0, 'aaaaaa', TStyle.Default);
    Buf.SetString(0, 1, 'bbbbbb', TStyle.Default);
    Buf.SetString(0, 2, 'cccccc', TStyle.Default);
    C := ClearWidget;
    C.Render(TRect.Make(2, 1, 3, 1), Buf);
    AssertBufferEquals(Buf, [
      'aaaaaa',
      'bb   b',
      'cccccc'
    ]);
  finally
    Buf.Free;
  end;
end;

procedure RegisterClearTests;
begin
  RegisterTest('clear / on empty buffer is identity',  @Test_ClearOnEmptyBufferIsIdentity);
  RegisterTest('clear / wipes previous content',       @Test_ClearWipesPreviousContent);
  RegisterTest('clear / sub-area leaves rest intact',  @Test_ClearOnSubAreaLeavesRestUntouched);
end;

end.
