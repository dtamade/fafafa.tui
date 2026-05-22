program phase7_demo;

{$mode objfpc}{$H+}

uses
  SysUtils,
  ftui_rect,
  ftui_color,
  ftui_modifier,
  ftui_style,
  ftui_cell,
  ftui_buffer,
  ftui_layout,
  ftui_layout_dsl,
  ftui_borders,
  ftui_block,
  ftui_paragraph,
  ftui_event,
  ftui_terminal,
  ftui_theme,
  ftui_anim,
  ftui_grid,
  ftui_virtual_list,
  ftui_syntax,
  ftui_markdown,
  ftui_command_palette,
  ftui_tooltip,
  ftui_file_tree;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Theme: TTheme;
  Spinner: TSpinner;
  VLState: TVirtualListState;
  FTState: TFileTreeState;
  CPState: TCommandPaletteState;
  CP: TCommandPalette;
  Tick: Integer;

function ItemProvider(Index: Integer): AnsiString;
begin
  Result := Format('Item #%d — data payload here', [Index]);
end;

procedure RenderFrame;
var
  Cols: TRectArray;
  LeftRows: TRectArray;
  FT: TFileTree;
  VL: TVirtualList;
  MD: TMarkdown;
  Tip: TTooltip;
begin
  Frame := Term.BeginFrame;
  Frame.Buffer.SetStyle(Frame.Area, Theme.Bg);

  // 3-column layout
  Cols := H(Frame.Area, [Fixed(22), Flex(1), Flex(1)]);

  // Left: File tree
  FT := TFileTree.Default
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(' Files ')
      .WithBorderStyle(Theme.Border))
    .WithDirStyle(TStyle.Default.WithFg(clCyan).WithModifier([mbBold]))
    .WithSelectedStyle(Theme.Primary);
  FT.RenderStateful(Cols[0], Frame.Buffer, FTState);

  // Middle: split into virtual list + markdown
  LeftRows := V(Cols[1], [Flex(1), Flex(1)]);

  // Virtual list (1M items)
  VL := TVirtualList.Create(@ItemProvider)
    .WithShowIndex(True)
    .WithBlock(TBlock.Default.WithBorders(BordersAll)
      .WithTitle(Format(' VirtualList [%d/%d] ', [VLState.Selected + 1, VLState.TotalItems]))
      .WithBorderStyle(Theme.Border))
    .WithStyle(Theme.Fg)
    .WithSelectedStyle(Theme.Primary);
  VL.RenderStateful(LeftRows[0], Frame.Buffer, VLState);

  // Markdown
  MD := TMarkdown.Create(
    '# fafafa.tui' + #10 +
    '' + #10 +
    '## Phase 7 Features' + #10 +
    '' + #10 +
    '- Virtual List (1M items)' + #10 +
    '- Syntax Highlighting' + #10 +
    '- Markdown Rendering' + #10 +
    '- Command Palette' + #10 +
    '- File Tree Browser' + #10 +
    '- Tooltips' + #10 +
    '' + #10 +
    '---' + #10 +
    '' + #10 +
    '```' + #10 +
    'procedure Hello;' + #10 +
    'begin' + #10 +
    '  WriteLn(''Hi!'');' + #10 +
    'end;' + #10 +
    '```'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Markdown ')
    .WithBorderStyle(Theme.Border));
  MD.Render(LeftRows[1], Frame.Buffer);

  // Right: syntax highlighted code
  TParagraph.FromString(
    Format('%s Phase 7 Demo', [Spinner.Frame(Tick)]) + #10 + #10 +
    'Keys:' + #10 +
    '  j/k - virtual list' + #10 +
    '  n/p - file tree' + #10 +
    '  Space - toggle dir' + #10 +
    '  Ctrl+P - cmd palette' + #10 +
    '  q - quit'
  ).WithBlock(TBlock.Default.WithBorders(BordersAll)
    .WithTitle(' Help ')
    .WithBorderStyle(Theme.Border))
  .WithStyle(Theme.Fg)
  .Render(Cols[2], Frame.Buffer);

  // Tooltip on file tree selection
  if FTState.Selected < Length(FTState.Nodes) then
  begin
    Tip := TTooltip.Create(FTState.Nodes[FTState.Selected].Name)
      .WithPosition(ttpRight)
      .WithStyle(Theme.Fg)
      .WithBorderStyle(Theme.Border);
  end;

  // Command palette overlay
  CP.RenderStateful(Frame.Area, Frame.Buffer, CPState);

  Term.EndFrame(Frame);
end;

procedure HandleKey(const K: TKeyEvent);
begin
  if CPState.Visible then
  begin
    case K.Code of
      kcEsc: CPState.Close;
      kcUp: CPState.SelectPrev;
      kcDown: CPState.SelectNext;
      kcChar: CPState.Input.InsertChar(K.Ch);
      kcBackspace: CPState.Input.DeleteBack;
      kcEnter: CPState.Close;
    else end;
    Exit;
  end;

  case K.Code of
    kcEsc: Term.RequestQuit;
    kcChar:
      case K.Ch of
        Ord('q'), Ord('Q'): Term.RequestQuit;
        Ord('j'): VLState.SelectNext;
        Ord('k'): VLState.SelectPrev;
        Ord('n'): FTState.SelectNext;
        Ord('p'): FTState.SelectPrev;
        Ord(' '): FTState.ToggleExpand;
      end;
    kcPageDown: VLState.PageDown(10);
    kcPageUp: VLState.PageUp(10);
  else end;
end;

begin
  Term := TTerminal.Create;
  try
    Theme := TTheme.Nord;
    Spinner := TSpinner.Create(skBraille);
    VLState := TVirtualListState.Create(1000000);
    Tick := 0;

    // Build file tree
    FTState := TFileTreeState.Empty;
    FTState.AddNode('src', True, 0);
    FTState.AddNode('core', True, 1);
    FTState.AddNode('ftui_rect.pas', False, 2);
    FTState.AddNode('ftui_color.pas', False, 2);
    FTState.AddNode('ftui_style.pas', False, 2);
    FTState.AddNode('widgets', True, 1);
    FTState.AddNode('ftui_table.pas', False, 2);
    FTState.AddNode('ftui_tree.pas', False, 2);
    FTState.AddNode('ftui_input.pas', False, 2);
    FTState.AddNode('tests', True, 0);
    FTState.AddNode('test_runner.lpr', False, 1);
    FTState.AddNode('examples', True, 0);
    FTState.AddNode('phase7_demo.lpr', False, 1);

    // Command palette
    CP := TCommandPalette.Create([
      TCommandItem.Make('Open File', 'Browse and open'),
      TCommandItem.Make('Save', 'Save current file'),
      TCommandItem.Make('Find', 'Search in files'),
      TCommandItem.Make('Replace', 'Find and replace'),
      TCommandItem.Make('Git Status', 'Show git status'),
      TCommandItem.Make('Quit', 'Exit application')
    ]).WithWidth(45);
    CPState := TCommandPaletteState.Empty;

    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      RenderFrame;
      Ev := Term.PollEvent(100);
      case Ev.Kind of
        evKey: HandleKey(Ev.Key);
      else end;
      Inc(Tick);
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
