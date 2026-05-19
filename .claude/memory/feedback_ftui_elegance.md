---
name: ftui-elegance-discipline
description: fafafa.tui 项目的优雅纪律——API 简洁、命名一致、注释克制、范围克制
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cab57cca-ba23-4226-a721-4b7d7886f7fc
---

fafafa.tui 在追求高性能的同时必须保持优雅。"够快"和"好看"两个标准同时成立才算合格。

**Why:** 用户两次强调："记住 高性能" + "记住 高性能和优雅"。优雅不是装饰，是消费方上手成本的关键——cli888-pascal 是首个、也可能不是唯一的消费方。一个又快又难用的库等于失败。同时优雅本身也保护性能：不优雅的 API 往往逼消费方自己拼字符串、嵌套调用，反而把热路径污染。

**How to apply:** 在 fafafa.tui 仓内执行：

1. **API 简洁**：每个公共类型做一件事，不留"可选第 N 种用法"。Builder 风格 `WithFg/WithBg/WithTitle` 链式返回 record by value，跟 ratatui 的 `.fg().bg().title()` 视觉等价
2. **命名一致**：`T` 前缀 / `I` 前缀 / `E` 前缀严格执行；枚举值用双字母 scope（`mb` modifier、`ck` color kind、`bs` border side、`ca` align、`dir` direction、`ev` event）。一个 scope 一旦确定，全仓不变
3. **不留半成品**：feature gate、`if Assigned` 防御、"先放着以后 review"、`// TODO` 全禁。一个单元要么完整提交要么不提交。`TODO` 例外只允许在 docs/*.md 的明确范围内（CJK 宽度等单点缺口）
4. **注释克制**：每个 unit 头一段 doc 说明定位（参考 ccore_errors.pas 风格），代码里只在"为什么这么写"时加注释，绝不写"这是 X 的实现"。命名好就不需要注释
5. **范围克制**：CLAUDE.md 的范围冻结清单不可越界。任何"顺手再加个 widget" / "这个 Constraint 也实现了吧"一律走"两个问题"门禁
6. **测试也要优雅**：测试名 `单元 / 行为描述`，断言信息含上下文；不写测试时不堆 `for I := 0 to 100 do AssertEq(I, F(I))` 这种凑数
7. **错误信息可读**：`EFtuiError.Message` 必须让消费方不读源码就能定位。Namespace + Code + 描述三段式
8. **示例先行**：每加一个 widget 必须在 examples/ 至少一个能跑的 .lpr，让"长什么样"先于"怎么实现"

不优雅的信号清单（看到立刻停下来重做）：

- 同一概念在不同 unit 名字不同
- record/class 边界混乱（明明数据型却开成 class）
- 接口里有 `Reserved1/Reserved2` 等占位字段
- 公共方法返回 `Boolean` 而消费方根本看不到失败原因
- 嵌套层数 > 3 的链式调用
- 一个 record 字段超过 8 个

性能跟优雅的优先级：**两者同时不达标返工，单边不达标也返工**。这事不打折。

相关：[[project-fafafa-tui]]、[[ftui-performance-discipline]]
