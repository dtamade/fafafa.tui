# Changelog

## v1.0.0-rc2 (2026-05-22)

CJK 全面修复 + TPanel 布局引擎。

### Breaking Changes

- `TInputState.InsertChar(Ch: Char)` → `TInputState.InsertChar(Cp: LongWord)`
  支持 CJK/emoji 输入。迁移：`State.InsertChar(Ord('x'))` 或直接传 `Key.Ch`（已是 LongWord）。

### 新增

- **TPanel 布局引擎**（`ftui_panel.pas`）：
  - 2D 网格布局，8×8 上限，零堆分配
  - 5 种边框风格（Plain/Rounded/Double/Heavy/Dashed）
  - WithSepSet / WithHSepStartCol / WithHSepStartColAt / WithVSepStartRow / WithVSepEndRow
  - WithHSepVisible / WithVSepVisible / WithHSepTitle
  - WithFocus / WithFocusStyle / WithPadding / WithCellPadding
  - WithMinWidth / WithMinHeight / WithColWeight / WithRowWeight / WithDebug
  - PanelCell / PanelCellPadded / PanelCellSpan / PanelHitTestSep
  - 预设工厂：Sidebar / HSplit / Grid
  - Junction 自动计算（4-bit lookup）
- `TInputState.InsertStr` — 粘贴多字节字符串
- `TInputState.CursorCol` / `TextWidth` — 显示宽度辅助
- `GraphemeWidthRange` — 零分配范围列宽计算
- `bench_fullscreen` — 200×60 端到端性能基线（632μs/frame）
- `BorderSetDouble` / `BorderSetHeavy` / `BorderSetDashed` 边框字符集
- 包分发：install.sh / fafafa_tui.mk / fafafa_tui.lpk / docs/getting-started.md

### 修复

- **CJK 渲染全面修复**：
  - TParagraph：渲染循环改为 GraphemeAdvance，修复 CJK 乱码 + 右边框消失
  - TParagraph：WrapOneLine 改为列宽累加，修复 CJK 不折行
  - TParagraph：Width=1 + 宽字符时 force-advance 防止无限循环
  - TParagraph：宽字符行尾溢出检查
  - TInputState：编辑模型重写为 grapheme-aware
  - TInput Mask 模式：cursor 映射改为 grapheme 索引
  - 7 个 widget 布局修复：Length(S) → GraphemeWidth(S)
    （table, statusbar, breadcrumb, menu, timeline, tooltip, dialog）
- **内存安全**：
  - CellEquals 加 SizeOf(TCell)=40 编译期断言
  - EndFrame 去掉冗余 FMerged.Reset + 加空 buffer 保护
  - TApp.Run 嵌套 try/finally 保证 OnDestroy 异常不跳过 LeaveTui
  - TKanban/TFileTree State 索引渲染前 clamp
  - TVirtualList State.Selected 超出 TotalItems 时自动 clamp
- **信号处理**：GResizePending/GTermPending 改为 LongInt + InterlockedExchange
- **输入解析**：ParseDecimal 加整数溢出保护（clamp 100000）
- **编译兼容**：CompareMem → CompareByte（clean build 兼容）
- **GraphemeAdvance**：Offset>=Len 时返回 ByteLen=0 + Assert
- **热路径**：TVirtualList gutter 改为栈上 itoa，Markdown SetLength 倍增，
  TParagraph LineW 改为 GraphemeWidthRange（零分配）

### 性能

| Benchmark | 结果 | 目标 |
|-----------|------|------|
| bench_fullscreen (200×60) | 632 μs/frame | < 2000 μs |
| bench_diff (200×60) | 957 μs/frame | < 1000 μs |
| bench_render (80×24) | 140 μs/frame | < 1000 μs |

### 测试

- 704 测试，0 failures，0 warnings
- 新增 34 个 panel 测试 + 5 个 CJK 测试 + 7 个 input CJK 测试

---

## v1.0.0-rc1 (2026-05-21)

首个 release candidate。API 冻结——stable 单元的类型定义和函数签名在 v1.x 内不变。

### Highlights

- 43 个 widget，覆盖数据展示、导航容器、输入交互、反馈提示四大类
- 双缓冲 diff 渲染引擎，200×60 全屏 < 1ms
- 完整键盘 + 鼠标全协议（SGR 1003h + CSI u）
- TApp 应用脚手架：20 行代码 → 可运行 TUI 应用
- 664 个测试，7 个性能基准
- 零外部依赖

### 稳定性

- 55 个单元标记为 **stable**（见 `docs/api-stability.md`）
- 6 个单元保留 **experimental**（keybind, event_loop, image, syntax, input_editor, textarea）
- 7 个单元标记为 **internal**

### 安全

- 修复 4 个内存安全 bug（空 buffer 指针越界）
- 添加 SIGTERM handler，外部 kill 信号触发正常终端恢复
- 所有热路径零字符串拼接，经审计确认

### API 变更（相对于 v0.9.0）

- `TScrollView.RenderFrame` → `TScrollView.RenderStateful`（命名一致性）
- `TCommandPaletteState.Create` → `TCommandPaletteState.Empty`（命名一致性）

### 性能

| Benchmark | 结果 | 目标 |
|-----------|------|------|
| bench_diff (200×60) | 957 μs/frame | < 1ms |
| bench_render (80×24) | 140 μs/frame | < 1ms |
| bench_layout (100K) | 0.41 μs/call | < 5μs |
| bench_input (100K) | 50 ns/event | < 1μs |
| bench_cjk | 0.95x vs ASCII | ~1.0x |

### 已知限制

- Grapheme clustering 不处理 ZWJ emoji 序列（单 codepoint 逐个渲染）
- 仅 Linux/macOS ANSI 终端，无 Windows 原生支持
- 同步阻塞事件循环（无异步 I/O）

### 版本承诺

v1.0 起，stable 单元遵循语义化版本：
- patch (v1.0.x)：bug 修复，不改 API
- minor (v1.x.0)：新增功能，不 break 现有 API
- experimental 单元可能在 minor 版本变化，CHANGELOG 会列出

---

## v0.9.0 (2026-05-19) — M4 性能基准 + cli888 场景测试

### 性能优化
- bench_diff: 1495μs → 957μs/frame (-36%), 达到 < 1ms 目标
- CellEquals: 5×QWord 整块比较替代逐字段比较
- Buffer.Diff: 指针算术 + 内联比较, 消除 mod/div 运算
- DrawPatches: QWord style 比较, 内联 SGR, GlyphLen=1 fast-path
- Buffer.Reset: doubling-copy 批量填充
- AppendByte: 内联 capacity 检查
- AnsiSgrReset: 预编码常量数组
- TBuffer.ContentPtr: 无边界检查的直接 cell 访问

### 新增
- 50 个 cli888 场景 buffer 快照测试 (test_cli888_scenarios.pas)
- docs/perf-results.md: 完整基准数据 + 分阶段分析

### 测试
- 总测试数: 267 (从 217 增加 50)
- 全部 PASS, 0 warning / 0 note

---

## v0.8.0-rc (2026-05-19) — tui-design 可锁定基线

**这是 tui-design 迁移的推荐锁定版本。**

### 新增
- TTerminal 原生 overlay 支持：TFrame.Buffer (base) + TFrame.Overlay (preview)
- TTerminal.Capture / Session / PrevMousePos 公共属性
- TTerminal.HasMouseTracking / HasTruecolor / HasKittyKeyboard 能力检测
- 鼠标全协议：mkDown / mkUp / mkMoved / mkDrag / mkScrollUp / mkScrollDown
- SGR 1003h (any-event tracking) + 1006h (SGR encoding) 自动开启/恢复
- TOverlayBuffer：稀疏层 + MergeInto + Clear + Dirty flag
- TPointerCapture：Acquire / Release
- TInteractionSession：Begin_ / Commit / Cancel
- HitTest / HitTestEvent / DetectHoverChange helpers
- TScrollbar：ThumbSize / ThumbStart / HitAt / OffsetFromDragY / Render
- canvas_overlay_demo：证明 Moved/Drag/Leave/Esc 四项验收
- bench_mouse_move：10μs/event（100K events/sec）

### 文档
- docs/tui-design-migration-profile.md：正式迁移合同
- docs/api-stability.md：27 单元三级分类
- docs/terminal-capabilities.md：跨终端能力矩阵

### Breaking changes
- TMouseEvent 加 Button 字段（从 mkLeftDown 改为 mkDown + mbLeft）
- MouseEvent() 构造函数签名变化（加 Btn 参数）
- TFrame 加 Overlay 字段

---

## v0.7.0-beta (2026-05-19)

### 新增
- 注释清理（清掉旧叙事）
- Parser 测试补齐（mkUp/mkMoved/mkDrag/mkMiddle/mkRight）
- bench_mouse_move 基准
- canvas_overlay_demo

---

## v0.6.0-alpha (2026-05-19)

### 新增
- docs/api-stability.md
- docs/terminal-capabilities.md
- Scrollbar Render nil 检查修复

---

## v0.5.0-alpha (2026-05-19)

### 新增
- ftui_interaction（Capture / Session / HitTest / HoverChange）
- ftui_overlay（双层 buffer）
- ftui_scrollbar（track/thumb/drag/page）
- 鼠标全协议（Phase A）

---

## m3 (2026-05-18)

### 新增
- TTerminal 主循环 + 输入事件解析
- ftui_event / ftui_input_parser / ftui_termios
- full_demo 交互式示例

---

## m2.1 (2026-05-18)

### 新增
- CJK / emoji 双宽字符（纯 Pascal East Asian Width 表）
- TBuffer.SetStringN UTF-8 路径
- TSpan.Width 走 GraphemeWidth

---

## m2 (2026-05-18)

### 新增
- TBlock / TParagraph / TList / TClear
- chat_mock 示例

---

## m1 (2026-05-18)

### 新增
- TText (Span/Line/Text)
- TLayout (Length/Min/Percentage solver)
- TTestBackend
- layout_demo 示例

---

## m0 (2026-05-18)

### 新增
- 项目立项
- TRect / TColor / TModifier / TStyle / TCell / TBuffer
- TByteBuilder / ANSI backend
- hello_box 示例
- 测试基础设施 (ftui_testkit)
