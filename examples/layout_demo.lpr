program layout_demo;

// Visual smoke for ftui_layout: split a 60x10 area into a 3-row grid:
//
//   header (Length 1)  — yellow bar with the title
//   body   (Min    0)  — 3-column layout, painted RGB
//   footer (Length 1)  — gray hint line
//
// Then split body horizontally into [Percentage(30), Min(0), Length(20)]:
//   left       — red panel
//   middle     — green panel (gets the Min slot)
//   right      — blue panel (anchored 20 wide on the right)
//
// 800ms hold then leave alt screen.  No widgets yet — we just paint
// each region's interior with SetString.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_buffer,
  ftui_layout,
  ftui_ansi_backend;

const
  STDOUT = 1;
  AREA_W = 60;
  AREA_H = 10;

procedure FillRegion(Buf: TBuffer; const R: TRect; Sym: AnsiChar; const Sty: TStyle);
var
  Y: Integer;
  Line: AnsiString;
begin
  if R.IsEmpty then Exit;
  SetLength(Line, R.Width);
  FillChar(Line[1], R.Width, Ord(Sym));
  for Y := R.Y to R.Y + R.Height - 1 do
    Buf.SetString(R.X, Y, Line, Sty);
end;

procedure CenteredString(Buf: TBuffer; const R: TRect; const S: AnsiString;
  const Sty: TStyle);
var
  X, Y: Integer;
begin
  if R.IsEmpty then Exit;
  Y := R.Y + R.Height div 2;
  if Length(S) >= R.Width then
    X := R.X
  else
    X := R.X + (R.Width - Length(S)) div 2;
  Buf.SetString(X, Y, S, Sty);
end;

var
  Backend: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  Rows, Cols: TRectArray;
  Header, Body, Footer, Left, Middle, Right: TRect;

begin
  Backend := TAnsiBackend.Create(STDOUT);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, AREA_W, AREA_H));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, AREA_W, AREA_H));
  try
    Backend.EnterAlternate;
    Backend.HideCursor;
    Backend.ClearScreen;
    Backend.Flush;

    // Vertical split: 1-row header, flexible body, 1-row footer.
    Rows := VerticalSplit(Curr.Area,
      [LengthConstraint(1), MinConstraint(0), LengthConstraint(1)]);
    Header := Rows[0];
    Body   := Rows[1];
    Footer := Rows[2];

    // Horizontal split inside body: 30%, fill, exactly 20 anchored right.
    Cols := HorizontalSplit(Body,
      [PercentageConstraint(30), MinConstraint(0), LengthConstraint(20)]);
    Left   := Cols[0];
    Middle := Cols[1];
    Right  := Cols[2];

    FillRegion(Curr, Header, ' ', TStyle.Default.WithBg(clYellow).WithFg(clBlack));
    CenteredString(Curr, Header, ' fafafa.tui M1 layout demo ',
      TStyle.Default.WithBg(clYellow).WithFg(clBlack).WithModifier([mbBold]));

    FillRegion(Curr, Left,   '.', TStyle.Default.WithBg(RgbColor(60, 20, 20)).WithFg(clRed));
    CenteredString(Curr, Left, 'Percentage(30)',
      TStyle.Default.WithBg(RgbColor(60, 20, 20)).WithFg(clRed).WithModifier([mbBold]));

    FillRegion(Curr, Middle, '.', TStyle.Default.WithBg(RgbColor(20, 60, 20)).WithFg(clGreen));
    CenteredString(Curr, Middle, 'Min(0)',
      TStyle.Default.WithBg(RgbColor(20, 60, 20)).WithFg(clGreen).WithModifier([mbBold]));

    FillRegion(Curr, Right,  '.', TStyle.Default.WithBg(RgbColor(20, 20, 60)).WithFg(clCyan));
    CenteredString(Curr, Right, 'Length(20)',
      TStyle.Default.WithBg(RgbColor(20, 20, 60)).WithFg(clCyan).WithModifier([mbBold]));

    FillRegion(Curr, Footer, ' ', TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));
    Curr.SetString(Footer.X + 1, Footer.Y, 'Three constraints, one solver, zero allocations on the hot path.',
      TStyle.Default.WithBg(clDarkGray).WithFg(clWhite));

    Prev.Diff(Curr, Patches);
    Backend.DrawPatches(Patches);
    Backend.Flush;

    Sleep(800);

    Backend.LeaveAlternate;
    Backend.ShowCursor;
    Backend.Flush;
  finally
    Curr.Free;
    Prev.Free;
    Backend.Free;
  end;
end.
