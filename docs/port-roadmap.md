# fafafa.tui 移植路线图

5 个 milestone，每个 milestone 有明确的判定标准。完成判定标准后才能进入下一个 milestone，**不允许跳跃推进**。

## M0 — 基础设施和判断锚（目标：1 周）

证明整套构建链路、命名、测试基础设施可用。结尾跑一个能在终端画带颜色边框的 demo。

### 实现单元

- `tests/ftui_testkit.pas` ← **第一个实现的单元**
  - `Assert(cond, msg)`、`AssertEq*`（int/string/bool）
  - `RunTest(name, proc)`、`RunSuite(name, [proc...])`
  - `AssertBufferEquals(buf, lines: array of AnsiString)`：buffer 快照断言（差异时打印 diff 行号 + 期望/实际）
- `src/core/ftui_rect.pas`（含 `TPosition`、`TSize`、`TMargin`、`TRect`）
- `src/core/ftui_color.pas`（`TColor` + 16 named constants + 构造函数）
- `src/core/ftui_modifier.pas`（`TModifierBit` + `TModifier`）
- `src/core/ftui_style.pas`（`TStyle` + `WithFg/WithBg/WithModifier/Patch`）
- `src/core/ftui_cell.pas`（`TCell` + `CellSetGlyph`/`CellEquals`）
- `src/core/ftui_buffer.pas`（`TBuffer` + `SetString`/`SetStyle`/`Diff`/`Resize`/`Reset`）
- `src/backend/ftui_ansi_backend.pas`（最小写 stdout，能输出彩色单元格）
- `examples/hello_box.lpr`（800ms 后自动退出，画一个 10×3 红色边框框 + 文字）

### 判定标准

- [x] `make test` 跑通至少 30 个断言 — **77 断言全过**（rect 9 + color 8 + modifier 7 + style 10 + cell 7 + buffer 15 + bytes 8 + ansi 9 + backend 4）
- [x] `AssertBufferEquals` 在断言失败时输出 ratatui 风格的 expected/actual diff — testkit 实现 `FormatDiff` 含 `*` 标记
- [x] `make examples` 编译 hello_box.lpr 成功 — 99 行 compile 0.2 秒
- [x] 跑 `./build/bin/hello_box`，终端能看到红色边框 + 文字 + 800ms 后自动退出 — script 录 PTY 字节流验证 `[?1049h ... +----------+ ... fafafa.tui ... [?1049l` 全程正确
- [x] `make clean && make` 全套从零构建 < 5 秒 — **0.4 秒**（提前 10 倍）

## M1 — Text 与 Layout（目标：2 周）

让"用 widget 拼界面"成为可能。这一步完成之后，**即使 widget 还没全实现，消费方也可以用 buffer.SetString + layout split 自己拼任何东西**。

### 实现单元

- `src/text/ftui_text.pas`（`TSpan`/`TLine`/`TText` + width 计算）
  - 第一阶段 `Width` 用 `Length(Content)` 字节数粗算（ASCII-only 准）
  - CJK/emoji 双宽留 TODO，M2 引入 utf8proc 时再补
- `src/layout/ftui_layout.pas`（`TConstraint`/`TLayout` + split solver）
- `src/backend/ftui_test_backend.pas`（DrawPatches 应用到内部 buffer，AsLines 走 Buffer.AsLines）
- `examples/layout_demo.lpr`（用 layout 切 3 行 × 3 列，每格画不同色 SetString）

注：原 roadmap 写"M1 实现 terminal 骨架"——已剥离到 M3。M1 的 widget
测试和 demo 都不需要 TFrame，TestBackend / 直接 Buffer.SetString 就够；
提前实现 TFrame 会引入 M3 必然返工的 API。范围克制。

### 判定标准

- [x] `VerticalSplit/HorizontalSplit` 测试覆盖 25+ 个 case — **30+ 个 case**（含 pure lengths / percentage / length+pct 混用 / Min 平分 / Min 高 floor / 偏移 area / 空 area / 空 constraints）
- [x] `TBuffer.Diff` 跟 ratatui 等价 — M0-3 已完成 15 个 buffer 测试（含 skip / style-only / empty / overlap 路径）
- [x] `TestBackend` 能正确反映多色 patches — 4 个 test_backend 测试 + 配 layout_demo 输出
- [x] `examples/layout_demo.lpr` 视觉一致 — PTY script 字节流验证：黄底标题、3 色 body 列、灰底 footer，SGR 切换次数最小化

## M2 — 4 个核心 Widget（目标：2 周）

cli888 主聊天界面骨架可拼。

### 实现单元

- `src/widgets/ftui_block.pas`（`TBlock` + Borders + Title + Inner）
- `src/widgets/ftui_paragraph.pas`（`TParagraph` + Wrap{trim:true} + Alignment + Scroll）
- `src/widgets/ftui_list.pas`（`TList` + `TListState` + 高亮 + 滚动）
- `src/widgets/ftui_clear.pas`（`TClear`）
- `examples/chat_mock.lpr`（拼出 cli888 主界面骨架：标题栏 + 消息列表 + 输入框，**纯静态**）

引入 utf8proc：

- `src/text/ftui_grapheme.pas`：`function GraphemeWidth(const S: AnsiString; ByteOffset: Integer): Integer`
- 编译选项：默认依赖系统 utf8proc（`apt install libutf8proc-dev`）；后续可选 vendoring

### 判定标准

- [ ] 每个 widget 至少 20 个 buffer 快照断言测试
- [ ] `Block.Inner` 在 4 种 Borders 组合下都正确
- [ ] `Paragraph` 在 Wrap{trim:true} + Alignment 下行为跟 ratatui 等价（对比 5+ ratatui 例子的 buffer 输出）
- [ ] `List` 在 selection + scroll_padding 下行为跟 ratatui 等价
- [ ] `examples/chat_mock.lpr` 视觉效果跟 cli888 主聊天界面相似
- [ ] CJK 字符串在 widget 里宽度计算正确（"你好"占 4 列）

## M3 — Terminal 主循环 + 输入（目标：2 周）

完整的 TUI 主循环：raw mode、双缓冲渲染、输入事件、滚轮、resize。

### 实现单元

- `src/input/ftui_event.pas`（`TEvent`/`TKeyEvent`/`TMouseEvent`/`TResizeEvent`）
- `src/input/ftui_input_parser.pas`（字节流 → `TEvent`）
- `src/terminal/ftui_terminal.pas` 完整版（含 `EnterRawMode`、`LeaveRawMode`、`PollEvent`、`ResizeFromTerminal`）
  - termios 直接绑（`unit termio` 或 `BaseUnix` 自己包）
  - SIGWINCH 信号处理（resize 事件）
  - 同步阻塞 stdin loop（M3 不引入 libuv，第一阶段够用）
- `examples/full_demo.lpr`（完整 TUI：方向键导航 List、Enter 选中、q 退出、滚轮翻页、终端 resize 自适应）

### 判定标准

- [ ] 32+ 个键码（含 Ctrl/Alt/Shift 修饰）解析单元测试通过
- [ ] 滚轮 SGR mouse 解析正确
- [ ] resize 事件能正确触发 buffer 重建
- [ ] `examples/full_demo.lpr` 在 gnome-terminal、alacritty、wezterm 三种终端下行为一致
- [ ] 退出 raw mode 时 termios 完整恢复（手动测试：跑完 demo 后 stty 没有副作用）

## M4 — 测试覆盖与基准（目标：1 周）

把测试覆盖率打满，跑性能微基准给出真实数字。

### 实现内容

- 用 cli888 真实 buffer 快照 dump 出来（脚本提取 50+ 个 cli888 单元测试中的 ratatui buffer），改写为 fafafa.tui 等价测试
- `benchmarks/bench_diff.lpr`（200×60 全屏随机刷新 1000 帧，输出 frame time / fps / 字节流量）
- `benchmarks/bench_layout.lpr`（10000 次 split 调用 / 不同 constraint 组合）
- `benchmarks/bench_input.lpr`（解析 100K 行 ESC 序列）
- `docs/perf-results.md`：把基准结果写下来（含 Rust ratatui 对比，如果有数据）

### 判定标准

- [ ] 总测试数 ≥ 200
- [ ] 50 个从 cli888 真实 dump 出来的 buffer 快照测试通过
- [ ] `bench_diff` 在 200×60 全屏刷新场景下 frame time < 1ms
- [ ] `bench_layout` 单次 split < 5μs
- [ ] 整套 `make test && make examples && make benchmarks` < 30 秒

## M5 — cli888 真接入（开放，跟 cli888-pascal 节奏）

不在本 roadmap 范围。等 cli888-pascal 项目启动后单独排。

## 跨 milestone 不变规则

1. **每个 milestone 结束后 git tag**：`m0` / `m1` / ...，方便回滚
2. **每周一更新 `progress.md`**：上周完成、本周计划、卡点
3. **任何范围扩展回到 CLAUDE.md 的"范围扩展规则"**走两个问题
4. **fpc 编译选项固定**：`-MObjFPC -Sh -O3 -gl -CR`（带 range check + line info）
5. **测试先于实现**：每个新 type 至少 5 个断言才能 commit

## 当前状态

- [x] 项目骨架建立
- [x] README / CLAUDE.md / 移植规范文档
- [x] **M0 完成（2026-05-18）** ✅
  - 6 个核心单元 + 3 个 backend 单元 + testkit + hello_box demo
  - 77 个测试断言全部通过，0 warning / 0 note
  - clean build 0.4 秒（要求 < 5 秒，提前 10 倍）
  - 二进制：test_runner 1.7M，hello_box ~500K
  - 字节流验证：alt screen + cursor hide + clear + 边框 + 文字 + leave alt
- [x] **M1 完成（2026-05-18）** ✅
  - ftui_text（Span/Line/Text，CRLF 处理 + alignment）
  - ftui_layout（Length/Min/Percentage 三 pass solver + trailing-absorb）
  - ftui_test_backend（DrawPatches 应用到内部 buffer + cursor/alt 状态跟踪）
  - examples/layout_demo.lpr（3 行 × 3 列彩色布局演示）
  - 总测试 103/103，0 warning / 0 note
  - terminal 骨架推迟到 M3（避免提前抽象）
- [ ] M2 进行中
