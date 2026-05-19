# fafafa.tui

Pascal 项目的 **通用 TUI 运行时**。从 CLI 聊天到图形编辑器的全谱终端交互。当前消费方：cli888-pascal（聊天 TUI）、tui-design（画布编辑器）。

## 定位

`fafafa.tui` 是通用 TUI 运行时，支持从 CLI 聊天到图形编辑器的全谱交互。

**已支持的能力面：**

- 鼠标全协议：Down / Up / Moved / Drag / Wheel（SGR 1003h + 1006h）
- 双层渲染：base buffer + overlay buffer + 自动 merge
- Pointer capture + Interaction session + Esc 中断语义
- Hover/Leave 检测 + Hit-test helper
- Scrollbar 原语（track/thumb/drag/page）
- 多行输入编辑器（grapheme-aware 光标 + MaxLines + 滚动）
- CJK / emoji 双宽字符（纯 Pascal East Asian Width 表）
- 4 个核心 widget（Block / Paragraph / List / Clear）+ 圆角边框
- Layout solver（Length / Min / Percentage）
- 性能：80×24 帧 191μs，mouse move 10μs/event

**API 稳定性**：见 [`docs/api-stability.md`](./docs/api-stability.md)。
**tui-design 迁移合同**：见 [`docs/tui-design-migration-profile.md`](./docs/tui-design-migration-profile.md)。
**跨终端矩阵**：见 [`docs/terminal-capabilities.md`](./docs/terminal-capabilities.md)。

## 第一阶段公共面

10 个公共单元：

| 单元 | 提供 |
|---|---|
| `ftui_rect` | `TRect` / `TPosition` / `TSize` / `TMargin` |
| `ftui_color` | `TColor`（Reset/Indexed/Rgb） |
| `ftui_modifier` | `TModifier`（set of 9 bits） |
| `ftui_style` | `TStyle`（fg/bg/modifier） |
| `ftui_cell` | `TCell`（packed record，栈内联 glyph） |
| `ftui_buffer` | `TBuffer`（连续 cell 数组 + diff） |
| `ftui_text` | `TSpan` / `TLine` / `TText` |
| `ftui_layout` | `TConstraint` / `TLayout`（Length/Min/Percentage） |
| `ftui_widgets` | `TBlock` / `TParagraph` / `TList` + `TListState` / `TClear` |
| `ftui_terminal` | `TTerminal` / `TFrame` + ANSI 后端 + 输入解析 |

## 设计原则

### immediate mode

跟 ratatui 一致：每帧从零重画一个 buffer，跟上一帧 diff，只输出差异 ANSI 序列到终端。无保留状态、无树、无引用追踪。Pascal 写起来**比 Rust 还顺手**——没有生命周期问题。

### 数组化 cell 布局

热路径全是 `array of TCell` + `packed record`，不出现字符串拼接。一帧 200×60 = 12000 个 cell 的 diff 与输出全程**整数和字节操作**，FPC 编译出来跟 Rust 是同一量级机器码。

### 零外部依赖

第一阶段除 RTL 外不依赖任何外部库。`utf8proc` 在 M2 阶段引入用于 CJK/emoji 宽字符判定，仍然不引入 ccore——保持 fafafa.tui 作为独立 Pascal 库的边界。

## 给消费方的接入说明

```pascal
program myapp;
{$mode objfpc}{$H+}
uses
  ftui_rect, ftui_style, ftui_buffer,
  ftui_borders, ftui_block, ftui_event, ftui_terminal;
var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
begin
  Term := TTerminal.Create;
  try
    if not Term.EnterTui then begin WriteLn('not a tty'); Halt(1); end;
    while not Term.ShouldQuit do
    begin
      Frame := Term.BeginFrame;
      TBlock.Default
        .WithBorders(BordersAll)
        .WithTitle('hello')
        .Render(Frame.Area, Frame.Buffer);
      Term.EndFrame(Frame);
      Ev := Term.PollEvent(-1);
      if (Ev.Kind = evKey) and (Ev.Key.Code = kcEsc) then
        Term.RequestQuit;
    end;
  finally
    Term.LeaveTui;
    Term.Free;
  end;
end.
```

## tui-design 迁移基线

当前推荐锁定版本：**`v0.8.0-rc`**

验收流程：
```bash
make test                          # 217 unit tests
make examples                      # 11 demos (含 canvas_overlay_demo)
bash scripts/acceptance_test.sh    # 9 PTY-level tests (需要 tmux)
```

## 仓内构建

```bash
make           # 编译所有单元
make test      # 跑测试套件
make examples  # 编译 examples/*.lpr
make clean     # 清理 build/
```

## 目录

```
src/
  core/         ftui_rect, ftui_color, ftui_modifier, ftui_style,
                ftui_cell, ftui_buffer
  text/         ftui_span, ftui_line, ftui_text, ftui_grapheme
  layout/       ftui_layout, ftui_constraint
  widgets/      ftui_block, ftui_paragraph, ftui_list, ftui_clear
  backend/      ftui_backend (interface), ftui_ansi_backend, ftui_test_backend
  terminal/     ftui_terminal, ftui_frame
  input/        ftui_event, ftui_key, ftui_input_parser
tests/
  ftui_testkit.pas        # 断言 + buffer 快照基础设施
  test_*.pas              # 各单元测试
examples/
  hello_box.lpr           # M0 出口
  chat_mock.lpr           # M2 出口
  full_demo.lpr           # M4 出口
docs/
  ratatui-port-spec.md    # Rust API → Pascal API 映射表
  port-roadmap.md         # M0-M4 任务清单与判定标准
  design-notes.md
benchmarks/
  bench_diff.lpr          # 性能微基准
build/
  bin/                    # 二进制输出
```

## 工作纪律

见 [`CLAUDE.md`](./CLAUDE.md)。

## License

MIT
