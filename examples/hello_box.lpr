program hello_box;

// fafafa.tui M0 visual smoke: paints a 12x4 red-bordered box with the
// text "fafafa.tui" inside, leaves it on screen for 800ms, then clears
// and exits.
//
// Manual frame loop — the proper TFrame / TTerminal abstraction lands
// in M3.  This is just enough to prove every M0 component composes:
//
//   buffer.SetString -> buffer.Diff -> backend.DrawPatches ->
//     backend.Flush -> sleep -> reset+flush
//
// The output uses the alternate screen buffer so the user's scrollback
// is preserved across the demo.

{$mode objfpc}{$H+}

uses
  SysUtils,
  BaseUnix,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_ansi_backend;

const
  STDOUT = 1;
  AREA_W = 60;
  AREA_H = 8;
  BOX_X  = 4;
  BOX_Y  = 1;
  BOX_W  = 12;
  BOX_H  = 4;

var
  Backend: TAnsiBackend;
  Prev, Curr: TBuffer;
  Patches: TDiffEntries;
  Border, Text: TStyle;
  X, Y: Integer;
  C: PCell;

begin
  Backend := TAnsiBackend.Create(STDOUT);
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, AREA_W, AREA_H));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, AREA_W, AREA_H));
  try
    Backend.EnterAlternate;
    Backend.HideCursor;
    Backend.ClearScreen;
    Backend.Flush;

    Border := TStyle.Default.WithFg(clRed).WithModifier([mbBold]);
    Text   := TStyle.Default.WithFg(clCyan);

    // Top + bottom edges.
    for X := BOX_X to BOX_X + BOX_W - 1 do
    begin
      C := Curr.CellAt(X, BOX_Y);              CellSetSymbolAscii(C^, '-'); CellApplyStyle(C^, Border);
      C := Curr.CellAt(X, BOX_Y + BOX_H - 1);  CellSetSymbolAscii(C^, '-'); CellApplyStyle(C^, Border);
    end;
    // Left + right edges.
    for Y := BOX_Y to BOX_Y + BOX_H - 1 do
    begin
      C := Curr.CellAt(BOX_X, Y);              CellSetSymbolAscii(C^, '|'); CellApplyStyle(C^, Border);
      C := Curr.CellAt(BOX_X + BOX_W - 1, Y);  CellSetSymbolAscii(C^, '|'); CellApplyStyle(C^, Border);
    end;
    // Corners.
    C := Curr.CellAt(BOX_X,             BOX_Y);             CellSetSymbolAscii(C^, '+'); CellApplyStyle(C^, Border);
    C := Curr.CellAt(BOX_X + BOX_W - 1, BOX_Y);             CellSetSymbolAscii(C^, '+'); CellApplyStyle(C^, Border);
    C := Curr.CellAt(BOX_X,             BOX_Y + BOX_H - 1); CellSetSymbolAscii(C^, '+'); CellApplyStyle(C^, Border);
    C := Curr.CellAt(BOX_X + BOX_W - 1, BOX_Y + BOX_H - 1); CellSetSymbolAscii(C^, '+'); CellApplyStyle(C^, Border);

    // Centred title — inner width is BOX_W - 2 (= 10), so use 10-char strings.
    Curr.SetString(BOX_X + 1, BOX_Y + 1, 'fafafa.tui', Text);
    Curr.SetString(BOX_X + 1, BOX_Y + 2, '  M0 OK   ', Text);

    Prev.Diff(Curr, Patches);
    Backend.DrawPatches(Patches);
    Backend.Flush;

    // Hold the frame.  fpSelect with a NULL fdset acts as a portable
    // millisecond sleep that doesn't pull the unit weight of `unit
    // sysutils`'s Sleep — we already use sysutils for QuotedStr etc,
    // so just call Sleep here.  800ms is the M0 demo window.
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
