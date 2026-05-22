# fafafa.tui 工作纪律

`fafafa.tui` 是 Pascal 项目的 **TUI 渲染层**。把 ratatui 的核心思想——immediate mode、双缓冲 diff、数组化 cell 布局——以 FreePascal 原生方式重写出来。

## 第一阶段范围冻结

不是"简化版 ratatui"，是**为 cli888-pascal 量身定做的最小子集**。范围由 cli888 实际扫描数据钉死：

### 实现的（10 个公共单元）

```
ftui_rect      TRect / TPosition / TSize / TMargin
ftui_color     TColor (Reset / Indexed / Rgb)
ftui_modifier  TModifier (set of mbBold/mbDim/mbItalic/mbUnderlined/
                          mbSlowBlink/mbRapidBlink/mbReversed/
                          mbHidden/mbCrossedOut)
ftui_style     TStyle (fg/bg/add_mod/sub_mod)
ftui_cell      TCell (packed record, 24-byte inline glyph)
ftui_buffer    TBuffer (连续 cell array + diff + set_string)
ftui_text      TSpan / TLine / TText
ftui_layout    TConstraint (Length/Min/Percentage) + Direction (V/H) + split solver
ftui_widgets   TBlock / TParagraph / TList + TListState / TClear
ftui_terminal  TTerminal / TFrame + ANSI backend + TestBackend + 输入解析
```

### 砍掉的（不做、不留口子、不在 README 公共面里宣传）

- Tabs / Table / Row / Cell(widget) / Gauge / LineGauge / Sparkline
- BarChart / Chart / Canvas / Calendar / Scrollbar
- BorderType（圆角/双线等：cli888 0 处使用）
- Padding 类型（cli888 直接用 Rect 减）
- Constraint::Max / Ratio / Fill / Length+Min 复杂混用
- Margin 类型（直接用 Rect 减）
- Bracketed paste / Focus events（不在当前路线图）
- Stylize trait 全集（保留 fg/bg/style 三个，bold 等展开成 add_modifier）
- Title alignment（cli888 几乎只用 left）

**已扩展到编辑器交互 profile（v0.8.0-rc 起）：**
- 鼠标全协议：Down / Up / Moved / Drag / Wheel（SGR 1003h + 1006h）
- 双层渲染：TFrame.Buffer (base) + TFrame.Overlay (preview)
- Pointer capture + Interaction session + Esc 中断
- Scrollbar 原语 + Hit-test + Hover/Leave 检测
- 能力检测：HasMouseTracking / HasTruecolor / HasKittyKeyboard
- CSI u (kitty keyboard protocol) 支持 Shift+Enter 等修饰键区分

### 范围扩展规则

任何要求加新 widget / 新 Constraint / 新输入事件的 PR，**必须先回答两个问题**：

1. cli888-pascal 的真实场景里有几处用到？
2. 用现有 API 拼出来需要多少行？比直接实现这个 widget 多多少？

只有 (1) ≥ 5 处且 (2) ≥ 3 倍代码量时，才允许新增。否则维持冻结。

已有 2 个独立消费方（cli888-pascal + tui-design），以下限制已解除：

- 多 widget 形态
- "未来 consumer"为动机的预留设计
- SDK / package / 分发机制

## 5 条硬纪律

### 1. 热路径只用数组和 packed record

整个渲染链路**禁止字符串拼接**。所有热路径数据：

- `TCell` 是 `packed record`（栈内联 24 字节 glyph + 12 字节 style + width + skip = 40 字节）
- `TBuffer.FContent` 是 `array of TCell`（连续数组，按 `y * width + x` 索引）
- ANSI 输出走 `TByteBuilder`（`array of Byte` append-only），最后一次 `fpwrite` 给 stdout
- 整数转 ASCII 用 itoa-style 直接写字节，**绝不用 IntToStr**
- `TModifier` 是 `set of TModifierBit`（编译为 u16 位运算）

字符串只在三个地方出现：

- API 入口（`Block.Title('hello')`）：进来后立刻切 grapheme 写入 cell
- `TSpan.Content`（用户视角的内容）：Render 时遍历切片
- 异常 `Message`：错误路径，不在乎性能

不允许任何热路径出现 `s := s + ...`。代码评审看到这个直接打回。

### 2. 单元命名 `ftui_<scope>`

所有单元前缀 `ftui_`，不留例外。`ratatui::buffer::Buffer` → `ftui_buffer.TBuffer`。

类型前缀：

- 类用 `T`（`TBuffer` / `TBlock` / `TParagraph`）
- 接口用 `I`（`IWidget` / `IBackend`）
- 异常用 `E`（`EFtuiError` / `EFtuiBufferError`）
- 枚举单值用 `<scope缩写><Name>`（`bsAll` / `mbBold` / `caCenter`）

### 3. immediate mode + 双缓冲 diff

Render 永远是 `procedure Render(const Area: TRect; var Buf: TBuffer)` 形式。

- widget 不持有渲染状态
- widget 不引用 buffer
- buffer 不引用 widget
- terminal 持有 prev/curr 两个 buffer，每帧 `Frame := BeginFrame; ...; EndFrame(Frame);`，diff 输出

ratatui 的 `StatefulWidget<State=T>` 翻译为：widget 类的 Render 方法多带一个 `var State: TXxxState` 参数，不抽 trait。

### 4. 错误体系

基类 `EFtuiError`，子类按场景分（`EFtuiBufferError` / `EFtuiLayoutError` / `EFtuiBackendError`）。

错误信息要带上下文，让消费方不读源码就能定位。但**热路径绝不靠异常控制流**——`Buffer.CellAt(x, y)` 越界返回 nil，调用方检查后使用。

### 5. 测试基础设施先于代码

`tests/ftui_testkit.pas` 必须**在第一个真实单元之前**写完，提供：

- `Assert*` 系列（int/string/bool/float）
- `AssertBufferEquals(buf, [...])`：跟 ratatui `assert_buffer_eq!` 对等的快照断言，buffer 不一致时打印 diff
- `RunTest(name, proc)`：测试 runner

后续每个单元的测试都用这套基础设施。**先有测试再有代码**——M0/M1 阶段的所有单元都遵循 TDD：先在 testkit 里写 assert，再实现。

## 移植映射规则（详细映射表见 `docs/ratatui-port-spec.md`）

### Rust → Pascal 翻译惯例

| Rust | Pascal | 说明 |
|---|---|---|
| `struct Foo { ... }` | `TFoo = packed record ... end` 或 `class` | 数据型用 record，行为型用 class |
| `enum Foo { A, B(u8) }` | `TFooKind` + variant `case record` | tagged union 用 case record |
| `bitflags! { Modifier: u16 { BOLD, ... } }` | `TModifierBit` enum + `TModifier = set of TModifierBit` | Pascal set 是一等公民 |
| `impl Foo { fn new() -> Self }` | `class function TFoo.Default: TFoo` 或构造器 | record 用 class function，class 用 constructor |
| `trait Widget { fn render(...) }` | `IWidget = interface ... end` | 公共接口用 interface |
| `fn render(self, area, buf)` | `procedure Render(const Area: TRect; var Buf: TBuffer)` | self by value 转 const param |
| `fn render(&mut self, ...)` | `procedure Foo(...)` (method on class) | 不需要特殊处理 |
| `Builder.foo(self, x).bar(self, y)` | `function Foo(X: ...): TThis` (返回自身) | fluent 风格保留，class 用方法链 |
| `Cow<'a, str>` | `string`（拷贝） | 第一阶段不优化 |
| `Vec<T>` | `array of T` | 不用 `TList<T>`（堆分配开销） |
| `Option<T>` | `record Has: Boolean; Value: T end` 或 nullable class | 简单 case 用 record，复杂用 class+nil |
| `Result<T, E>` | 抛异常 | wrap 层只抛异常 |
| `&[T]` slice | `pointer + length` 或 `array of T` const param | 热路径用指针，冷路径直接 array |
| `iter().map().collect()` | `for...begin...end` 展开 | 没有捷径 |
| `derive(Default/PartialEq/Hash/Clone)` | 手写 | 没办法 |
| macro `assert_buffer_eq!` | `AssertBufferEquals(buf, [...])` | 见 testkit |

### 命名映射

| Rust | Pascal |
|---|---|
| `Buffer` | `TBuffer` |
| `Cell` | `TCell` |
| `Rect` | `TRect` |
| `Style` | `TStyle` |
| `Color` | `TColor` |
| `Color::Rgb(r,g,b)` | `RgbColor(r,g,b)` 或 `TColor.Rgb(r,g,b)` |
| `Color::Indexed(i)` | `IndexedColor(i)` |
| `Color::Reset` | `ResetColor` 或 `TColor.Reset` |
| `Modifier::BOLD` | `mbBold` |
| `Constraint::Length(3)` | `LengthConstraint(3)` |
| `Constraint::Min(0)` | `MinConstraint(0)` |
| `Constraint::Percentage(50)` | `PercentageConstraint(50)` |
| `Direction::Vertical` | `dirVertical` |
| `Direction::Horizontal` | `dirHorizontal` |
| `Borders::ALL` | `[bsTop, bsBottom, bsLeft, bsRight]` 或 `BordersAll` |
| `Alignment::Center` | `caCenter` |
| `Block::default()` | `TBlock.Default` |
| `Paragraph::new(text)` | `TParagraph.Create(text)` |
| `List::new(items)` | `TList.Create(items)` |
| `frame.render_widget(w, area)` | `Frame.Render(W, Area)` |
| `frame.buffer_mut()` | `Frame.Buffer` (var/property) |

## 不该出现的工作

直到 fafafa.tui 至少有 2 个独立 consumer 项目之前，**禁止**做：

- 多终端后端（除 ANSI/Test 外）
- Windows 控制台原生 API 后端（Linux/macOS ANSI 优先）
- 异步事件循环抽象（M0-M4 同步阻塞 stdin loop 先用着）
- 性能优化突破"够用"基线（先正确再快）
- 主题系统 / 配色预设（消费方自己拼 TColor）

## 给新增 widget / 新 Constraint 的标准流程

只有当新需求是 cli888-pascal 真实需要、并且不在禁列表里：

1. 在 `docs/ratatui-port-spec.md` 加映射条目（先文档后代码）
2. 在 `tests/test_<unit>.pas` 加 buffer 快照断言（先测试后实现）
3. 在 `src/widgets/ftui_<widget>.pas` 实现
4. 在 `examples/` 至少加一个能 demo 的 .lpr
5. **不写 contract test、不锁 public API、不预留扩展点**
