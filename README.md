# fafafa.tui

FreePascal 的 **immediate-mode TUI 框架**。受 Rust ratatui 启发，为 Pascal 生态重新设计。

零外部依赖 / 双缓冲 diff 渲染 / 43 个 widget / 636 测试 / 亚毫秒帧时间

当前消费方：cli888-pascal（聊天 TUI）、tui-design（画布编辑器）。

## Quick Start

20 行代码 → 可运行的 TUI 应用：

```pascal
program myapp;
{$mode objfpc}{$H+}
uses
  ftui_app, ftui_event, ftui_rect, ftui_style,
  ftui_buffer, ftui_block, ftui_borders, ftui_paragraph;
type
  TMyApp = class(TApp)
  protected
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure TMyApp.Render(var Frame: TFrame);
begin
  TParagraph.FromString('Hello, TUI!' + #10 + 'q = quit')
    .WithBlock(TBlock.Default.WithBorders(BordersAll))
    .Render(Frame.Area, Frame.Buffer);
end;

procedure TMyApp.HandleEvent(const Ev: TEvent);
begin
  if (Ev.Kind = evKey) and (Ev.Key.Ch = Ord('q')) then Quit;
end;

var App: TMyApp;
begin
  App := TMyApp.Create;
  try App.Run; finally App.Free; end;
end.
```

```bash
fpc -Fusrc/core -Fusrc/text -Fusrc/terminal -Fusrc/input \
    -Fusrc/backend -Fusrc/layout -Fusrc/widgets myapp.lpr
```

或使用脚手架：`make quickstart NAME=myapp`

## 真实工具 Examples

| 工具 | 行数 | 展示能力 |
|------|------|----------|
| `sysmon` | 554 | Gauge 阈值着色 / Sparkline / Table 排序对齐 / Tabs / 实时刷新 |
| `jv` | 528 | Tree 折叠展开 / 搜索 / JSON path / 键盘导航 |
| `logview` | 354 | tail -f / 级别着色 / 实时过滤 / follow 模式 |

## Features

### 渲染引擎

- 双缓冲 diff：prev/curr buffer 逐 cell 比较，只输出变化部分
- 24 字节 packed cell：inline glyph 存储，零堆分配
- CJK / 全角字符：正确处理 width-2 grapheme，trailing cell 自动标记
- Overlay 层：base buffer + overlay buffer 双层合成
- 帧预算：TFrameBudget 控制渲染频率，避免过度刷新

### 布局

- Constraint 求解器：Length / Min / Percentage / Fill 四种约束
- VerticalSplit / HorizontalSplit 快捷函数
- Grid 布局：行列比例分配
- Layout DSL：声明式嵌套布局

### 输入

- 完整键盘：ASCII / 功能键 / CSI u (kitty keyboard protocol)
- 鼠标全协议：Down / Up / Moved / Drag / Wheel（SGR 1003h + 1006h）
- Pointer capture + Interaction session + Esc 中断
- 焦点管理：Tab/Shift+Tab 循环，FocusManager

### 终端

- ANSI backend：TrueColor / 256 色 / 16 色自适应
- TestBackend：注入事件序列，捕获渲染输出，用于测试
- 能力检测：HasMouseTracking / HasTruecolor / HasKittyKeyboard
- 剪贴板：OSC 52 读写

### Widget 目录（43 个）

**数据展示**
| Widget | 说明 |
|--------|------|
| Paragraph | 多行文本 + 自动换行 + 对齐 |
| Table | 列对齐 / 排序 / 滚动 / 选中高亮 |
| Tree | 折叠展开 / 缩进 / 选中 / flat index |
| List | 单列列表 + 选中状态 |
| BarChart | 垂直柱状图 + 标签 |
| LineChart | 折线图 + 多系列 |
| Sparkline | Braille 点阵迷你图 |
| Gauge | 进度条 + 阈值着色 |
| ProgressGroup | 多进度条组 |
| Calendar | 月历 + 日期标记 |
| Timeline | 时间线 |
| DiffView | 并排 diff 展示 |
| Markdown | Markdown 渲染 |
| Syntax | 语法高亮 |
| Image | 半字符块图像 |

**导航与容器**
| Widget | 说明 |
|--------|------|
| Block | 边框 + 标题容器 |
| Tabs | 标签页切换 |
| ScrollView | 虚拟滚动视口 |
| SplitPane | 可拖拽分割面板 |
| Modal | 模态对话框 |
| Dialog | 确认/取消对话框 |
| Popover | 弹出层 |
| Menu | 下拉菜单 |
| Breadcrumb | 面包屑导航 |
| VirtualList | 大数据虚拟列表 |

**输入与交互**
| Widget | 说明 |
|--------|------|
| Input | 单行文本输入 |
| InputEditor | 多行编辑器 + 光标 |
| TextArea | 多行文本域 |
| Select | 下拉选择 |
| Form | 表单布局 |
| CommandPalette | 命令面板 + 模糊搜索 |
| Scrollbar | 滚动条 + 拖拽 + 点击定位 |

**反馈与提示**
| Widget | 说明 |
|--------|------|
| Toast | 临时通知 |
| Tooltip | 悬浮提示 |
| NotificationCenter | 通知队列管理 |
| StatusBar | 底部状态栏 |

**文件与系统**
| Widget | 说明 |
|--------|------|
| FileTree | 文件树浏览 |
| Canvas | 自由绘制画布 |
| Kanban | 看板 |

**基础**
| Widget | 说明 |
|--------|------|
| Clear | 清空区域 |
| Interaction | 指针捕获 / Hit-test / Hover |
| Theme | 主题配色 |

## 性能

测试环境：Linux x86-64, FPC 3.3.1, -O3

| Benchmark | 场景 | 结果 | 目标 |
|-----------|------|------|------|
| bench_diff | 200×60 全屏 diff | 957 μs/frame | < 1ms |
| bench_render | 80×24 完整渲染 | 140 μs/frame | < 1ms |
| bench_layout | 100K 次 split | 0.41 μs/call | < 5μs |
| bench_input | 100K ESC 序列 | 50 ns/event | < 1μs |
| bench_cjk | CJK vs ASCII | 0.95x | ~1.0x |

CJK 渲染无额外开销。详见 `docs/perf-results.md`。

## 目录结构

```
src/
  core/       rect, color, modifier, style, cell, buffer, grapheme,
              focus, overlay, screen, app, anim, keybind, color_cap, theme
  text/       text (Span/Line/Text), format (FormatBytes)
  layout/     layout (Constraint solver), grid, layout_dsl
  input/      event, input_parser
  terminal/   terminal, frame_budget, event_loop, termios, clipboard
  backend/    ansi_backend, ansi, bytes, test_backend
  widgets/    43 个 widget 单元
tests/        73 个测试文件, 651 个测试用例
examples/     26 个可运行 demo
benchmarks/   7 个性能基准
docs/         API 稳定性 / 性能结果 / 移植规范 / 终端能力
```

## 构建

依赖：FreePascal >= 3.2.0（推荐 3.3.1 trunk）

```bash
make test         # 编译并运行 636 个测试
make examples     # 编译所有 26 个 demo
make bench        # 运行性能基准（3 次取最优）
make ci           # 完整门禁：test + examples + benchmarks + acceptance
make clean        # 清理构建产物
```

## 设计原则

1. **Immediate mode**：widget 不持有渲染状态，每帧重新描述 UI
2. **双缓冲 diff**：Terminal 持有 prev/curr buffer，只输出变化 cell
3. **热路径零分配**：packed record + 连续数组 + 指针算术
4. **Pascal 原生**：不是 ratatui 的逐行翻译，是为 Pascal 生态重新设计的 API

## API 模式

```pascal
// Stateless widget
TParagraph.FromString('hello')
  .WithBlock(TBlock.Default.WithBorders(BordersAll))
  .WithAlignment(caCenter)
  .Render(Area, Buffer);

// Stateful widget
TTree.Create(Nodes)
  .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]))
  .RenderStateful(Area, Buffer, TreeState);

// State 构造
State := TListState.Empty;        // 标准
State := TTreeState.Empty;        // 标准
State := TCommandPaletteState.Empty;  // 标准
```

详见 `docs/api-stability.md` 了解各单元稳定性级别。

## License

MIT
