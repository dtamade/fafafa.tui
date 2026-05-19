# fafafa.tui 性能基准结果

测试环境：Linux x86-64, FPC 3.3.1, -O3 优化

## 基准结果

| Benchmark | 场景 | 结果 | 目标 | 状态 |
|-----------|------|------|------|------|
| bench_diff | 200×60 全屏, 1000 帧 | 957 μs/frame | < 1ms | PASS |
| bench_layout | 100K 次 VerticalSplit | 0.41 μs/call | < 5μs | PASS |
| bench_input | 100K ESC 序列解析 | 50 ns/event | < 1μs | PASS |
| bench_render | 80×24, 1000 帧, 20 items | 140 μs/frame | < 1ms | PASS |
| bench_mouse_move | 1000 连续 moved 事件 | 14 μs/event | < 500μs | PASS |

## bench_diff 分阶段分析

200×60 全屏刷新（75% cell 变化）：

| 阶段 | 耗时 | 说明 |
|------|------|------|
| Fill (widget render) | ~180 μs | 模拟 widget 写入 12000 cell |
| Diff | ~420 μs | 比较 prev/curr buffer, 输出 patches |
| Draw (ANSI gen) | ~290 μs | patches → ANSI 字节流 |
| **总计** | **~890 μs** | |

## 关键优化

1. CellEquals: 5×QWord 比较替代逐字段比较
2. Diff: 指针算术 + 内联比较, 消除 mod/div
3. DrawPatches: QWord 比较 style, 内联 SGR 输出
4. Buffer.Reset: doubling-copy 批量填充
5. AppendByte: 内联 capacity 检查避免函数调用
6. AnsiSgrReset: 预编码常量数组一次写入

## 与 ratatui 对比（参考值）

ratatui 在类似硬件上的 bench_diff (200×60):
- Rust release build: ~200-400 μs/frame (含 crossterm backend)
- fafafa.tui: ~890 μs/frame (含 ANSI backend)

差距约 2-3x, 主要来自:
- FPC 缺少 SIMD auto-vectorization (Rust LLVM 会自动向量化 memcmp)
- Pascal 动态数组有引用计数开销
- 无 LTO (link-time optimization)

对于 TUI 应用 (60fps = 16.6ms/frame), 957μs 提供 >1000fps 余量, 完全够用。
