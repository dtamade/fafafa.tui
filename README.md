# fafafa.tui

Pascal 项目的 **TUI 渲染层**。把 Rust 生态里 ratatui 的核心思想——**immediate mode + 双缓冲 diff + 数组化 cell 布局**——以 FreePascal 原生方式重写出来，让 Pascal 项目能够构建现代终端用户界面，而不需要 fpGUI、不需要 ncurses、不需要 Free Vision。

## 定位

`fafafa.tui` 不是 ratatui 的完整移植，是 **cli888-pascal 真实需要的 ratatui 子集**。范围按 cli888 的实际使用面冻结，不做无用功。

不在范围内：

- ratatui 完整 widget 全家桶（Tabs/Table/Gauge/Sparkline/Chart/BarChart/Canvas/Calendar/Scrollbar 等都不实现）
- cassowary 通用 Constraint solver（只支持 Length/Min/Percentage 三种）
- bracketed paste / focus events / kitty keyboard protocol
- 鼠标 drag/move 事件（只支持滚轮 + 单次 click）
- Stylize trait 链式 API 全集（保留 `.fg() .bg() .style()` 三个）

详见 [`CLAUDE.md`](./CLAUDE.md)。

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
  SysUtils,
  ftui_rect,
  ftui_color, ftui_modifier, ftui_style,
  ftui_buffer, ftui_text,
  ftui_layout,
  ftui_widgets,
  ftui_terminal;

var
  Term: TTerminal;
  Frame: TFrame;
begin
  Term := TTerminal.CreateAnsi;
  try
    Term.EnterRawMode;
    while not Term.ShouldQuit do
    begin
      Frame := Term.BeginFrame;
      try
        TBlock.Default
          .Borders([bsAll])
          .Title('hello')
          .Render(Frame.Area, Frame.Buffer);
      finally
        Term.EndFrame(Frame);
      end;

      Term.PollEvents;
    end;
  finally
    Term.LeaveRawMode;
    Term.Free;
  end;
end.
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
