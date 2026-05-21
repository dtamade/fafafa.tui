# fafafa.tui API Stability

本文档定义每个公共单元的稳定性级别。消费方据此决定哪些 API 可以安全依赖。

## 级别定义

- **stable**：v1.x 内不改签名、不改语义。可以安全依赖。
- **experimental**：可能在 v1.x 内改签名或语义。使用前看 CHANGELOG。
- **internal**：随时可改。消费方不应直接 import。

## 单元分级

### stable（可安全依赖）

#### 核心

| 单元 | 提供 |
|---|---|
| `ftui_rect` | TRect / TPosition / TSize / TMargin |
| `ftui_color` | TColor (ckUnset/ckReset/ckIndexed/ckRgb) + 16 named |
| `ftui_modifier` | TModifierBit + TModifier (set of 9 bits) |
| `ftui_style` | TStyle + WithFg/WithBg/WithModifier/Patch |
| `ftui_cell` | TCell + CellEmpty + CellSetSymbol/ApplyStyle/Equals |
| `ftui_buffer` | TBuffer + SetString/SetStringN/SetStyle/Diff/DiffInto/Resize/Reset |
| `ftui_grapheme` | GraphemeAdvance / GraphemeWidth / CodepointWidth |
| `ftui_app` | TApp + Run/Quit/Render/HandleEvent/OnTick/OnInit/OnDestroy |
| `ftui_focus` | TFocusManager + Register/Navigate/HandleKey/IsFocused |
| `ftui_overlay` | TOverlayBuffer + SetCell/SetString/Clear/MergeInto |
| `ftui_screen` | TScreen / TScreenStack + Push/Pop/Replace |
| `ftui_anim` | TSpinner + TTransition + TEasingFunc |
| `ftui_color_cap` | DetectColorCapability / ResolveColor |

#### 文本与布局

| 单元 | 提供 |
|---|---|
| `ftui_text` | TSpan / TLine / TText / TAlignment |
| `ftui_format` | FormatBytes / FormatBytesKB |
| `ftui_layout` | TConstraint (Length/Min/Percentage/Fill) + VerticalSplit/HorizontalSplit |
| `ftui_grid` | Grid() + TGridResult |

#### 输入与终端

| 单元 | 提供 |
|---|---|
| `ftui_event` | TEvent / TKeyEvent / TMouseEvent / TResizeEvent / TEventKind |
| `ftui_terminal` | TTerminal + TFrame + EnterTui/LeaveTui/BeginFrame/EndFrame/PollEvent |
| `ftui_frame_budget` | TFrameBudget + BeginFrame/EndFrame/ElapsedMs |
| `ftui_clipboard` | TClipboard + Detect/Copy/Paste |
| `ftui_borders` | TBorderSet / BorderSetPlain / BorderSetRounded / BordersAll |

#### Widget

| 单元 | 提供 |
|---|---|
| `ftui_block` | TBlock + Render/Inner/WithBorders/WithTitle |
| `ftui_paragraph` | TParagraph + FromString/WithBlock/WithAlignment/Render |
| `ftui_list` | TList + TListState + RenderStateful |
| `ftui_table` | TTable + TTableState + WithRows/WithAlign/RenderStateful |
| `ftui_tree` | TTree + TTreeState + WithChildren/RenderStateful |
| `ftui_tabs` | TTabs + RenderStateful |
| `ftui_gauge` | TGauge + WithThreshold/Render |
| `ftui_sparkline` | TSparkline + WithMax/WithStyle/Render |
| `ftui_barchart` | TBarChart + WithShowValues/Render |
| `ftui_linechart` | TLineChart + Render |
| `ftui_calendar` | TCalendar + TCalendarState + RenderStateful |
| `ftui_input` | TInput + TInputState + RenderStateful |
| `ftui_select` | TSelect + TSelectState + RenderStateful |
| `ftui_form` | TForm + Render |
| `ftui_scrollbar` | TScrollbar + HitAt/OffsetFromDragY/Render |
| `ftui_scrollview` | TScrollView + RenderStateful |
| `ftui_virtual_list` | TVirtualList + TVirtualListState + RenderStateful |
| `ftui_modal` | TModal + WithSize/WithSizePercent |
| `ftui_dialog` | TDialog + Render |
| `ftui_popover` | TPopover + RenderStateful |
| `ftui_menu` | TMenu + TMenuState + RenderStateful |
| `ftui_toast` | TToast + Render |
| `ftui_tooltip` | TTooltip + Render |
| `ftui_notification_center` | TNotificationCenter + Push/Render |
| `ftui_statusbar` | TStatusBar + WithLeft/WithCenter/WithRight/Render |
| `ftui_breadcrumb` | TBreadcrumb + WithActive/Render |
| `ftui_command_palette` | TCommandPalette + TCommandPaletteState.Empty + RenderStateful |
| `ftui_split_pane` | TSplitPane + RenderStateful |
| `ftui_canvas` | TCanvas + Render |
| `ftui_diffview` | TDiffView + TDiffViewState + FromUnifiedDiff/RenderStateful |
| `ftui_file_tree` | TFileTree + TFileTreeState + RenderStateful |
| `ftui_kanban` | TKanban + TKanbanState + RenderStateful |
| `ftui_markdown` | TMarkdown + WithTheme/Render |
| `ftui_timeline` | TTimeline + WithNodeChar/Render |
| `ftui_progress_group` | TProgressGroup + Render |
| `ftui_clear` | TClear + Render |
| `ftui_interaction` | TPointerCapture / TInteractionSession / HitTest |
| `ftui_theme` | TTheme + ThemeDefaultDark |

### experimental（v1.1 决定）

| 单元 | 提供 | 原因 |
|---|---|---|
| `ftui_keybind` | TKeybindManager | Action 类型可能从裸指针改为 method of object |
| `ftui_event_loop` | TEventLoop | 与 TApp 功能重叠，可能重构或合并 |
| `ftui_image` | TImage + Kitty/Sixel 编码 | 协议编码函数签名可能随终端支持变化 |
| `ftui_syntax` | TSyntax + TokenizePascal | 仅支持 Pascal，多语言扩展时接口会变 |
| `ftui_input_editor` | TInputEditor | 光标模型可能重构 |
| `ftui_textarea` | TTextArea | 可能与 input_editor 合并 |

### internal（不应直接依赖）

| 单元 | 说明 |
|---|---|
| `ftui_bytes` | TByteBuilder — backend 内部使用 |
| `ftui_ansi` | ANSI 序列 emitter — backend 内部 |
| `ftui_ansi_backend` | TAnsiBackend — Terminal 内部使用 |
| `ftui_test_backend` | TTestBackend — 仅测试用 |
| `ftui_termios` | termios 绑定 — Terminal 内部 |
| `ftui_input_parser` | ParseOne — Terminal 内部使用 |
| `ftui_layout_dsl` | 布局便利函数 — ftui_layout 的语法糖 |

## 版本承诺

- v1.0 起：stable 单元的**类型定义和函数签名**在 v1.x 内不变
- experimental 单元：每个 minor version 的 CHANGELOG 列出变化
- internal 单元：不保证任何稳定性

## 集成建议

消费方应该：
1. 只 `uses` stable 和 experimental 单元
2. 不直接 `uses` internal 单元（通过 TTerminal 间接使用）
3. 锁定 git tag（不跟 main 分支）
4. 升级前看 CHANGELOG
