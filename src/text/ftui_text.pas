unit ftui_text;

// Span / Line / Text — ratatui's text-tree primitives, mapped to
// FreePascal records.
//
// ratatui hierarchy:
//   Span<'a>  : { content: Cow<str>, style: Style }              one styled run
//   Line<'a>  : { spans: Vec<Span>, style, alignment: Option }   one row
//   Text<'a>  : { lines: Vec<Line>, style, alignment: Option }   multi-line
//
// Pascal mapping:
//   TSpan    : packed record (content + style)
//   TLine    : record (Spans + Style + Alignment)
//   TText    : record (Lines + Style + Alignment)
//
// Width computation:
//   M1 ASCII-only — Length(content) bytes.
//   M2 will switch to grapheme-aware width via utf8proc.  The public
//   surface (TSpan.Width / TLine.Width / TText.Width) won't change.
//
// Style is "rendered" by walking the tree and patching the per-node
// Style onto the Span.Style at render time — TBlock / TParagraph /
// TList do that themselves.  The text records carry the style; they
// don't apply it.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}
{$packenum 1}
{$packset 2}

interface

uses
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_grapheme;

type
  TAlignment = (caLeft, caCenter, caRight);

  TSpan = record
    Content: AnsiString;
    Style: TStyle;

    class function Raw(const S: AnsiString): TSpan; static;
    class function Styled(const S: AnsiString; const St: TStyle): TSpan; static;

    function Width: Integer;       // M1: byte count.  M2: grapheme width.
    function WithStyle(const St: TStyle): TSpan;
  end;
  TSpans = array of TSpan;

  TLine = record
    Spans: TSpans;
    Style: TStyle;
    HasAlignment: Boolean;
    Alignment: TAlignment;

    class function Empty: TLine; static;
    class function FromString(const S: AnsiString): TLine; static;
    class function Raw(const S: AnsiString): TLine; static;
    class function Styled(const S: AnsiString; const St: TStyle): TLine; static;
    class function FromSpans(const ASpans: array of TSpan): TLine; static;

    function Width: Integer;
    function WithStyle(const St: TStyle): TLine;
    function WithAlignment(A: TAlignment): TLine;
  end;
  TLines = array of TLine;

  TText = record
    Lines: TLines;
    Style: TStyle;
    HasAlignment: Boolean;
    Alignment: TAlignment;

    class function Empty: TText; static;
    class function FromString(const S: AnsiString): TText; static;
    class function FromLines(const ALines: array of TLine): TText; static;
    class function Raw(const S: AnsiString): TText; static;
    class function Styled(const S: AnsiString; const St: TStyle): TText; static;

    function Width: Integer;        // max line width
    function Height: Integer;       // line count
    function WithStyle(const St: TStyle): TText;
    function WithAlignment(A: TAlignment): TText;
  end;

implementation

{ TSpan }

class function TSpan.Raw(const S: AnsiString): TSpan;
begin
  Result.Content := S;
  Result.Style := TStyle.Default;
end;

class function TSpan.Styled(const S: AnsiString; const St: TStyle): TSpan;
begin
  Result.Content := S;
  Result.Style := St;
end;

function TSpan.Width: Integer;
begin
  Result := GraphemeWidth(Content);
end;

function TSpan.WithStyle(const St: TStyle): TSpan;
begin
  Result := Self;
  Result.Style := St;
end;

{ TLine }

class function TLine.Empty: TLine;
begin
  Result.Spans := nil;
  Result.Style := TStyle.Default;
  Result.HasAlignment := False;
  Result.Alignment := caLeft;
end;

class function TLine.FromString(const S: AnsiString): TLine;
begin
  Result := Empty;
  SetLength(Result.Spans, 1);
  Result.Spans[0] := TSpan.Raw(S);
end;

class function TLine.Raw(const S: AnsiString): TLine;
begin
  Result := FromString(S);
end;

class function TLine.Styled(const S: AnsiString; const St: TStyle): TLine;
begin
  Result := Empty;
  SetLength(Result.Spans, 1);
  Result.Spans[0] := TSpan.Styled(S, St);
end;

class function TLine.FromSpans(const ASpans: array of TSpan): TLine;
var
  I: Integer;
begin
  Result := Empty;
  SetLength(Result.Spans, System.Length(ASpans));
  for I := 0 to System.High(ASpans) do
    Result.Spans[I] := ASpans[I];
end;

function TLine.Width: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to System.High(Spans) do
    Inc(Result, Spans[I].Width);
end;

function TLine.WithStyle(const St: TStyle): TLine;
begin
  Result := Self;
  Result.Style := St;
end;

function TLine.WithAlignment(A: TAlignment): TLine;
begin
  Result := Self;
  Result.HasAlignment := True;
  Result.Alignment := A;
end;

{ TText }

class function TText.Empty: TText;
begin
  Result.Lines := nil;
  Result.Style := TStyle.Default;
  Result.HasAlignment := False;
  Result.Alignment := caLeft;
end;

// Splits S on LF, treating CRLF the same as LF.  ASCII-only — control
// bytes other than CR/LF are passed through verbatim (the buffer layer
// strips controls when writing into cells, so this stays simple here).
class function TText.FromString(const S: AnsiString): TText;
var
  I, Start, LineCount: Integer;
  Ch: Byte;
begin
  Result := Empty;

  // Two-pass parse: count, then materialise — keeps SetLength single-shot.
  LineCount := 1;
  for I := 1 to System.Length(S) do
    if S[I] = #10 then Inc(LineCount);
  SetLength(Result.Lines, LineCount);

  LineCount := 0;
  Start := 1;
  I := 1;
  while I <= System.Length(S) do
  begin
    Ch := Byte(S[I]);
    if Ch = 10 then
    begin
      // Trim trailing CR.
      if (I - 1 >= Start) and (S[I - 1] = #13) then
        Result.Lines[LineCount] := TLine.FromString(Copy(S, Start, I - 1 - Start))
      else
        Result.Lines[LineCount] := TLine.FromString(Copy(S, Start, I - Start));
      Inc(LineCount);
      Start := I + 1;
    end;
    Inc(I);
  end;
  // Last line (may be empty if S ends with LF).
  Result.Lines[LineCount] := TLine.FromString(Copy(S, Start, System.Length(S) - Start + 1));
end;

class function TText.FromLines(const ALines: array of TLine): TText;
var
  I: Integer;
begin
  Result := Empty;
  SetLength(Result.Lines, System.Length(ALines));
  for I := 0 to System.High(ALines) do
    Result.Lines[I] := ALines[I];
end;

class function TText.Raw(const S: AnsiString): TText;
begin
  Result := FromString(S);
end;

class function TText.Styled(const S: AnsiString; const St: TStyle): TText;
begin
  Result := FromString(S);
  Result.Style := St;
end;

function TText.Width: Integer;
var
  I, W: Integer;
begin
  Result := 0;
  for I := 0 to System.High(Lines) do
  begin
    W := Lines[I].Width;
    if W > Result then Result := W;
  end;
end;

function TText.Height: Integer;
begin
  Result := System.Length(Lines);
end;

function TText.WithStyle(const St: TStyle): TText;
begin
  Result := Self;
  Result.Style := St;
end;

function TText.WithAlignment(A: TAlignment): TText;
begin
  Result := Self;
  Result.HasAlignment := True;
  Result.Alignment := A;
end;

end.
