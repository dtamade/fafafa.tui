program split_panels_demo;

// Split-panel file browser: left panel = file list, right panel =
// content preview.  Tab switches focus, ←/→ adjusts split ratio,
// ↑/↓ navigates the list, q quits.
//
// Proves: dynamic layout recalculation, multi-panel focus management,
// per-panel independent scroll, border style changes on focus.

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_text,
  ftui_layout,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_list,
  ftui_event,
  ftui_terminal;

const
  FILE_COUNT = 8;

type
  TFocus = (focLeft, focRight);

var
  Term: TTerminal;
  Focus: TFocus;
  SplitPct: Integer;     // left panel percentage (20..80)
  ListSt: TListState;
  Frame: TFrame;
  Ev: TEvent;

  FileNames: array[0..FILE_COUNT - 1] of AnsiString;
  FileContents: array[0..FILE_COUNT - 1] of AnsiString;

procedure InitFiles;
begin
  FileNames[0] := 'README.md';
  FileNames[1] := 'Makefile';
  FileNames[2] := 'src/main.pas';
  FileNames[3] := 'src/utils.pas';
  FileNames[4] := 'tests/test_all.pas';
  FileNames[5] := 'docs/design.md';
  FileNames[6] := '.gitignore';
  FileNames[7] := 'CHANGELOG.md';

  FileContents[0] := '# My Project' + #10 + '' + #10 + 'A demo project.' + #10 + 'Built with fafafa.tui.';
  FileContents[1] := 'FPC ?= fpc' + #10 + '' + #10 + 'all: build' + #10 + '' + #10 + 'build:' + #10 + '  $(FPC) main.pas';
  FileContents[2] := 'program main;' + #10 + 'begin' + #10 + '  WriteLn(''hello'');' + #10 + 'end.';
  FileContents[3] := 'unit utils;' + #10 + 'interface' + #10 + 'function Add(A, B: Integer): Integer;' + #10 + 'implementation' + #10 + 'function Add(A, B: Integer): Integer;' + #10 + 'begin Result := A + B; end;' + #10 + 'end.';
  FileContents[4] := 'program test_all;' + #10 + 'uses utils;' + #10 + 'begin' + #10 + '  assert(Add(1,2) = 3);' + #10 + '  WriteLn(''ok'');' + #10 + 'end.';
  FileContents[5] := '# Design Notes' + #10 + '' + #10 + '## Architecture' + #10 + '' + #10 + 'Simple layered design.' + #10 + 'Core -> UI -> App.';
  FileContents[6] := 'build/' + #10 + '*.o' + #10 + '*.ppu';
  FileContents[7] := '# Changelog' + #10 + '' + #10 + '## v0.1.0' + #10 + '- Initial release';
end;

procedure RenderFrame;
var
  Cols: TRectArray;
  LeftArea, RightArea: TRect;
  LeftBlock, RightBlock: TBlock;
  LeftBorderSty, RightBorderSty: TStyle;
  FileList: TList;
  ContentPara: TParagraph;
  SelIdx: Integer;
begin
  Frame := Term.BeginFrame;

  Cols := HorizontalSplit(Frame.Area, [
    PercentageConstraint(SplitPct),
    MinConstraint(0)
  ]);
  LeftArea := Cols[0];
  RightArea := Cols[1];

  if Focus = focLeft then
  begin
    LeftBorderSty := TStyle.Default.WithFg(clCyan).WithModifier([mbBold]);
    RightBorderSty := TStyle.Default.WithFg(clDarkGray);
  end
  else
  begin
    LeftBorderSty := TStyle.Default.WithFg(clDarkGray);
    RightBorderSty := TStyle.Default.WithFg(clCyan).WithModifier([mbBold]);
  end;

  // Left panel: file list.
  LeftBlock := TBlock.Default
                .WithBorders(BordersAll)
                .WithTitle(' files ')
                .WithBorderStyle(LeftBorderSty);
  FileList := TList.FromStrings(FileNames)
                .WithBlock(LeftBlock)
                .WithHighlightSymbol('> ')
                .WithHighlightStyle(TStyle.Default.WithBg(RgbColor(30, 50, 70)).WithFg(clWhite).WithModifier([mbBold]));
  FileList.RenderStateful(LeftArea, Frame.Buffer, ListSt);

  // Right panel: content preview.
  if ListSt.HasSelection then
    SelIdx := ListSt.Selected
  else
    SelIdx := 0;

  RightBlock := TBlock.Default
                  .WithBorders(BordersAll)
                  .WithTitle(' ' + FileNames[SelIdx] + ' ')
                  .WithBorderStyle(RightBorderSty);
  ContentPara := TParagraph.FromString(FileContents[SelIdx])
                  .WithBlock(RightBlock)
                  .WithWrap(WrapTrim)
                  .WithStyle(TStyle.Default.WithFg(clGreen));
  ContentPara.Render(RightArea, Frame.Buffer);

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('j'): if Focus = focLeft then Inc(ListSt.Selected);
        Ord('k'): if Focus = focLeft then Dec(ListSt.Selected);
      end;
    kcTab:
      if Focus = focLeft then Focus := focRight else Focus := focLeft;
    kcUp:
      if Focus = focLeft then Dec(ListSt.Selected);
    kcDown:
      if Focus = focLeft then Inc(ListSt.Selected);
    kcLeft:
      if SplitPct > 20 then Dec(SplitPct, 5);
    kcRight:
      if SplitPct < 80 then Inc(SplitPct, 5);
  else
  end;
  if ListSt.Selected < 0 then ListSt.Selected := 0;
  if ListSt.Selected >= FILE_COUNT then ListSt.Selected := FILE_COUNT - 1;
end;

begin
  InitFiles;
  SplitPct := 30;
  Focus := focLeft;
  ListSt := TListState.Empty;
  ListSt.Select(0);

  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(-1);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else
      end;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
