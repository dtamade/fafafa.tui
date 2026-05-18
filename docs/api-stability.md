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
| `ftui_buffer` | TBuffer + SetString/SetStyle/Diff/Resize/Reset |
| `ftui_grapheme` | GraphemeAdvance / GraphemeWidth / CodepointWidth |
| `ftui_text` | TSpan / TLine / TText / TAlignment |
| `ftui_layout` | TConstraint (Length/Min/Percentage) + TLayout.Split |
| `ftui_event` | TEvent / TKeyEvent / TMouseEvent / TResizeEvent |
| `ftui_borders` | TBorderSet / BorderSetPlain / BorderSetRounded |

### experimental（可能变化）

| 单元 | 提供 | 变化风险 |
|---|---|---|
| `ftui_block` | TBlock + Render/Inner | WithBorderSet 签名可能调整 |
| `ftui_paragraph` | TParagraph + Wrap/Alignment/Scroll | word wrapper 算法可能改进 |
| `ftui_list` | TList + TListState | 可能加 multi-line item 支持 |
| `ftui_clear` | TClear | 稳定但太简单，可能合并到 buffer |
| `ftui_input_editor` | TInputEditor | 光标模型可能重构 |
| `ftui_interaction` | TPointerCapture / TInteractionSession / HitTest / HoverChange | 接口可能扩展 |
| `ftui_overlay` | TOverlayBuffer + MergeInto | merge 策略可能加 alpha |
| `ftui_scrollbar` | TScrollbar + Render/HitAt/OffsetFromDragY | 可能加水平方向 |
| `ftui_theme` | TTheme + ThemeDefaultDark | 字段可能增减 |

### internal（不应直接依赖）

| 单元 | 说明 |
|---|---|
| `ftui_bytes` | TByteBuilder — backend 内部使用 |
| `ftui_ansi` | ANSI 序列 emitter — backend 内部 |
| `ftui_ansi_backend` | TAnsiBackend — Terminal 内部使用 |
| `ftui_test_backend` | TTestBackend — 仅测试用 |
| `ftui_termios` | termios 绑定 — Terminal 内部 |
| `ftui_terminal` | TTerminal — 可能重构为支持 overlay |
| `ftui_input_parser` | ParseOne — Terminal 内部使用 |

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
