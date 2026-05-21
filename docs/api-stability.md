# fafafa.tui API Stability

本文档定义每个公共单元的稳定性级别。消费方据此决定哪些 API 可以安全依赖。

## 级别定义

- **stable**：tag 之间不改签名、不改语义。可以安全依赖。
- **experimental**：可能在下一个 tag 改签名或语义。使用前看 changelog。
- **internal**：随时可改。消费方不应直接 import。

## 单元分级

### stable（可安全依赖）

| 单元 | 提供 |
|---|---|
| `ftui_rect` | TRect / TPosition / TSize / TMargin |
| `ftui_color` | TColor (ckUnset/ckReset/ckIndexed/ckRgb) + 16 named |
| `ftui_modifier` | TModifierBit + TModifier (set of 9 bits) |
| `ftui_style` | TStyle + WithFg/WithBg/WithModifier/Patch |
| `ftui_cell` | TCell + CellEmpty + CellSetSymbol/ApplyStyle/Equals |
| `ftui_buffer` | TBuffer + SetString/SetStringN/SetStyle/Diff/DiffInto/Resize/Reset |
| `ftui_grapheme` | GraphemeAdvance / GraphemeWidth / CodepointWidth |
| `ftui_text` | TSpan / TLine / TText / TAlignment |
| `ftui_layout` | TConstraint (Length/Min/Percentage/Fill) + VerticalSplit/HorizontalSplit |
| `ftui_event` | TEvent / TKeyEvent / TMouseEvent / TResizeEvent / TEventKind |
| `ftui_borders` | TBorderSet / BorderSetPlain / BorderSetRounded / BordersAll |
| `ftui_format` | FormatBytes / FormatBytesKB |

### experimental — 核心与布局

| 单元 | 提供 | 变化风险 |
|---|---|---|
| `ftui_app` | TApp + Run/Quit/Render/HandleEvent/OnTick | 生命周期钩子可能增加 |
| `ftui_focus` | TFocusManager | 焦点策略可能扩展 |
| `ftui_overlay` | TOverlayBuffer + MergeInto | merge 策略可能加 alpha |
| `ftui_screen` | TScreen | 多屏管理接口可能变化 |
| `ftui_anim` | 动画插值 | 接口未稳定 |
| `ftui_keybind` | 快捷键绑定 | 接口未稳定 |
| `ftui_color_cap` | 终端色彩能力检测 | 检测策略可能调整 |
| `ftui_grid` | Grid 布局 | 可能与 layout 合并 |
| `ftui_layout_dsl` | 声明式布局 DSL | 语法可能变化 |
| `ftui_terminal` | TTerminal + TFrame (overlay/capture/session) | 接口稳定，内部可能优化 |
| `ftui_frame_budget` | TFrameBudget | 字段可能增减 |
| `ftui_event_loop` | 事件循环 | 可能重构 |
| `ftui_clipboard` | OSC 52 剪贴板 | 协议支持可能扩展 |

### experimental — Widget

| 单元 | 提供 | 变化风险 |
|---|---|---|
| `ftui_block` | TBlock + Render/Inner | WithBorderSet 签名可能调整 |
| `ftui_paragraph` | TParagraph + Wrap/Alignment/Scroll | word wrapper 算法可能改进 |
| `ftui_list` | TList + TListState | 可能加 multi-line item |
| `ftui_table` | TTable + TTableState + WithAlign | 列定义可能扩展 |
| `ftui_tree` | TTree + TTreeState | 接口稳定 |
| `ftui_tabs` | TTabs | 接口稳定 |
| `ftui_gauge` | TGauge + WithThreshold | 接口稳定 |
| `ftui_sparkline` | TSparkline + WithMax/WithStyle | 接口稳定 |
| `ftui_barchart` | TBarChart | 接口稳定 |
| `ftui_linechart` | TLineChart | 数据点格式可能变化 |
| `ftui_calendar` | TCalendar | 接口稳定 |
| `ftui_input` | TInput + TInputState | 接口稳定 |
| `ftui_input_editor` | TInputEditor | 光标模型可能重构 |
| `ftui_textarea` | TTextArea | 可能与 input_editor 合并 |
| `ftui_select` | TSelect + TSelectState | 接口稳定 |
| `ftui_form` | TForm | 字段类型可能扩展 |
| `ftui_scrollbar` | TScrollbar + HitAt/OffsetFromDragY | 可能加水平方向 |
| `ftui_scrollview` | TScrollView + RenderStateful | 虚拟滚动策略可能优化 |
| `ftui_virtual_list` | TVirtualList | 接口未稳定 |
| `ftui_modal` | TModal | 接口稳定 |
| `ftui_dialog` | TDialog | 按钮配置可能扩展 |
| `ftui_popover` | TPopover | 定位策略可能调整 |
| `ftui_menu` | TMenu + TMenuState | 子菜单支持可能变化 |
| `ftui_toast` | TToast | 动画可能调整 |
| `ftui_tooltip` | TTooltip | 触发方式可能扩展 |
| `ftui_notification_center` | TNotificationCenter | 队列策略可能变化 |
| `ftui_statusbar` | TStatusBar | 接口稳定 |
| `ftui_breadcrumb` | TBreadcrumb | 接口稳定 |
| `ftui_command_palette` | TCommandPalette + TCommandPaletteState.Empty | 搜索算法可能改进 |
| `ftui_split_pane` | TSplitPane | 拖拽交互可能调整 |
| `ftui_canvas` | TCanvas | 绘制原语可能扩展 |
| `ftui_diffview` | TDiffView | 接口未稳定 |
| `ftui_file_tree` | TFileTree | 接口未稳定 |
| `ftui_kanban` | TKanban | 接口未稳定 |
| `ftui_image` | TImage | 渲染策略可能变化 |
| `ftui_markdown` | TMarkdown | 解析器可能改进 |
| `ftui_syntax` | TSyntax | 语言支持可能扩展 |
| `ftui_timeline` | TTimeline | 接口未稳定 |
| `ftui_progress_group` | TProgressGroup | 接口稳定 |
| `ftui_interaction` | TPointerCapture / TInteractionSession / HitTest | 接口可能扩展 |
| `ftui_clear` | TClear | 稳定但太简单，可能合并 |
| `ftui_theme` (widget) | TTheme + ThemeDefaultDark | 字段可能增减 |

### internal（不应直接依赖）

| 单元 | 说明 |
|---|---|
| `ftui_bytes` | TByteBuilder — backend 内部使用 |
| `ftui_ansi` | ANSI 序列 emitter — backend 内部 |
| `ftui_ansi_backend` | TAnsiBackend — Terminal 内部使用 |
| `ftui_test_backend` | TTestBackend — 仅测试用 |
| `ftui_termios` | termios 绑定 — Terminal 内部 |
| `ftui_input_parser` | ParseOne — Terminal 内部使用 |
| `ftui_theme` (core) | 核心主题定义 — widget/ftui_theme 的基础 |

## 版本承诺

- `v0.5.0-alpha` 起：stable 单元的**类型定义和函数签名**不变
- experimental 单元：每个 tag 的 changelog 列出变化
- internal 单元：不保证任何稳定性

## 集成建议

消费方应该：
1. 只 `uses` stable 和 experimental 单元
2. 不直接 `uses` internal 单元（通过 TTerminal 间接使用）
3. 锁定 git tag（不跟 main 分支）
4. 升级前看 changelog
