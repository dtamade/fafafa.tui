unit ftui_format;

{$mode objfpc}{$H+}{$inline on}

interface

function FormatBytes(Bytes: Int64): AnsiString;
function FormatBytesKB(KB: Int64): AnsiString;

implementation

function FormatBytes(Bytes: Int64): AnsiString;
var
  Val: Double;
  IntPart, FracPart: Integer;
  Buf: string[8];
begin
  if Bytes < 1024 then
  begin
    Str(Bytes, Buf);
    Result := Buf + ' B';
  end
  else if Bytes < 1024 * 1024 then
  begin
    Val := Bytes / 1024;
    IntPart := Trunc(Val);
    FracPart := Trunc((Val - IntPart) * 10);
    Str(IntPart, Buf);
    if FracPart > 0 then
      Result := Buf + '.' + Chr(Ord('0') + FracPart) + ' KB'
    else
      Result := Buf + ' KB';
  end
  else if Bytes < Int64(1024) * 1024 * 1024 then
  begin
    Val := Bytes / (1024 * 1024);
    IntPart := Trunc(Val);
    FracPart := Trunc((Val - IntPart) * 10);
    Str(IntPart, Buf);
    if FracPart > 0 then
      Result := Buf + '.' + Chr(Ord('0') + FracPart) + ' MB'
    else
      Result := Buf + ' MB';
  end
  else
  begin
    Val := Bytes / (Int64(1024) * 1024 * 1024);
    IntPart := Trunc(Val);
    FracPart := Trunc((Val - IntPart) * 10);
    Str(IntPart, Buf);
    if FracPart > 0 then
      Result := Buf + '.' + Chr(Ord('0') + FracPart) + ' GB'
    else
      Result := Buf + ' GB';
  end;
end;

function FormatBytesKB(KB: Int64): AnsiString;
begin
  Result := FormatBytes(KB * 1024);
end;

end.
