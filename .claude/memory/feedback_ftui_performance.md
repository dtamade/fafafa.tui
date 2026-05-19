---
name: ftui-performance-discipline
description: fafafa.tui 项目的高性能硬纪律——热路径只用数组和 packed record，禁止字符串拼接
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cab57cca-ba23-4226-a721-4b7d7886f7fc
---

fafafa.tui（Pascal ratatui 子集）是高性能项目。所有热路径代码必须遵守以下纪律：

**Why:** 用户明确要求"记住 高性能"，并且整个移植决策的前提就是"FPC 性能能跟得上 Rust ratatui"。一旦热路径出现 `s := s + ch` 这种 AnsiString 拼接，单帧 12000 cell 输出能从 300μs 退化到 50ms（60fps → 20fps），整个性能承诺崩塌。

**How to apply:** 在 fafafa.tui 仓内写代码、改代码、review 代码时无条件执行：

1. 热路径数据 = `array of T` + `packed record`，绝不用 `TList<T>` 或 class（堆分配 + GC 头开销毁 cache 局部性）
2. ANSI 输出走 `array of Byte` append-only buffer，最后一次 `fpwrite` 给 stdout；**禁止 `IntToStr` / `Format` / `s := s + ...`** 出现在每帧渲染路径
3. 整数转 ASCII 用 itoa-style 直写字节（`AppendInt(N: Integer)`），不走 RTL 字符串函数
4. `TCell` 是 `packed record`，glyph 栈内联 24 字节（对应 ratatui CompactString），不堆分配
5. `TBuffer.FContent: array of TCell` 连续数组，按 `y * width + x` 索引，不用嵌套数组
6. `TModifier = set of TModifierBit`（Pascal 一等公民，编译为 u16 位运算），不用 class 或 record + 字段
7. `TStyle` packed record by value 传，不传指针不传引用
8. widget Render 签名固定为 `procedure Render(const Area: TRect; ABuf: TBuffer)`，`Area` 是 const param 传栈

字符串只允许在三处出现：API 入口（用户传 title/text，进来后立刻切 grapheme 写入 cell）、`TSpan.Content`（冷路径遍历）、异常 `Message`（错误路径）。

代码 review 看到任何热路径字符串拼接 / IntToStr / Format / TList / class 化 cell，**立刻打回**，不商量。

性能验证：M4 阶段 `benchmarks/bench_diff.lpr` 必须证明 200×60 全屏刷新 frame time < 1ms。这个数字是承诺，不是参考。

相关：[[project-fafafa-tui]]、[[ftui-elegance-discipline]]
