---
name: project-fafafa-tui
description: fafafa.tui 项目状态——为 cli888-pascal 量身做的 ratatui 子集，路径 ~/projects/fafafa.tui
metadata: 
  node_type: memory
  type: project
  originSessionId: cab57cca-ba23-4226-a721-4b7d7886f7fc
---

`fafafa.tui` 是 FreePascal 项目，为 cli888-pascal 移植做的 ratatui 子集 TUI 渲染层。

**Why:** 用户要把 cli888（185K 行 Rust）移植到 FreePascal，理由是 Rust 编译卡机太重。Pascal 没有 ratatui 等价物，fpGUI/Free Vision/ncurses 都不合适，所以单独立项。范围按 cli888 真实使用面冻结：4 widget（Block/Paragraph/List/Clear）+ 3 Constraint（Length/Min/Percentage），不做完整 ratatui（那是 25K 行工程，9 个月起跳）。

**How to apply:** 进入 ~/projects/fafafa.tui 工作时：

- 路径：`~/projects/fafafa.tui`，独立 git 仓，**不在 ccore 内部**
- 单元前缀：`ftui_`，类前缀 `T`/`I`/`E`
- 工具链：FPC 3.3.1 trunk（`/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc`），`-MObjFPC -Sh -O3 -gl -CR`，需要 `{$modeswitch advancedrecords}`
- 构建：`make test` / `make examples` / `make benchmarks` / `make clean`
- 范围冻结清单见 CLAUDE.md，任何扩展走"两个问题"门禁（cli888 真实使用 ≥ 5 处 + 用现有 API 拼超过 3 倍代码量）
- 移植映射查表见 docs/ratatui-port-spec.md
- Roadmap 与判定标准见 docs/port-roadmap.md，M0-M4 共 5 个 milestone

**关键纪律：**
- 高性能：[[ftui-performance-discipline]]
- 优雅：[[ftui-elegance-discipline]]

**当前进度（2026-05-18）：**
- **M0 完成 ✅** — git tag `m0` (commit `49b3baf`)
- **M1 完成 ✅** — git tag `m1` (commit `c472721`)
- **M2 完成 ✅** — git tag `m2` (commit `1c0d18b`)
- **M3 完成 ✅** — git tag `m3` (commit `0388aa6`)
- 已实现 21 个公共单元（rect / color / modifier / style / cell / buffer / bytes / ansi / ansi_backend / text / layout / test_backend / borders / clear / block / paragraph / list / event / input_parser / termios / terminal）+ testkit + 4 个 demo（hello_box / layout_demo / chat_mock / full_demo）
- 159 测试断言全过，0 warning、0 note，clean build < 1 秒
- 真机交互 cli888-pascal 可用：raw mode + 双缓冲 + 输入解析 + SIGWINCH + alt screen
- 待办：**M2.1**（utf8proc CJK 接入）/ **M4**（基准 + 真实 cli888 buffer dump 测试）

**M3 关键决定记录：**
- input parser 设计为纯函数 ParseOne(buf, len, atEOF) -> (event, consumed, status)，prNeedMore/prInvalid/prSuccess 三态；测试 100% 不依赖 IO
- termios.pas 是唯一绑 BaseUnix 的单元，未来移植到非 Linux 只改这里
- SIGWINCH 用 module-global flag + sigaction，因为 C signal handler 不能 capture context；fafafa.tui 假设进程作用域单 TTerminal 实例
- VMIN=0/VTIME=0 + poll(2) 阻塞模型：所有阻塞集中在 PollEvent，read 永不阻塞
- bare ESC 处理：AtEOF 时落地为 kcEsc，否则 prNeedMore（区分 ESC 单按和 ESC 序列起始）
- ESC ESC 处理：消费 1 字节产 kcEsc，让下一次 ParseOne 重新解析剩余 ESC
- LeaveTui 用 Free + := nil 替代 FreeAndNil，避免在热路径单元 uses SysUtils
- 不引入 IBackend 接口（M3 仍只有 TAnsiBackend / TTestBackend，方法签名一致即可）

**M2 关键决定记录：**
- CJK 推迟到 M2.1：utf8proc vendoring 是非平凡 ccore-style C 库工作，单独成 milestone 更稳；widget 架构已就位，CJK 接入只改 TSpan.Width 和 buffer 写入路径
- 不实现 BorderType / Padding / multi-title / Wrap{trim:false} / LineTruncator —— 范围克制
- TList 高亮 gutter 仅在 HasSelection 时保留，不实现 HighlightSpacing::Always
- AssertBufferEquals：当 expected 字节数 >= buffer.Width 时不做字节 clip，直接逐字节比较（多字节 grapheme 行测试需要这个）

**M1 关键决定记录：**
- terminal 骨架推迟到 M3（M2 widget 测试用 TestBackend + Buffer.SetString 即够；提前实现 TFrame 必返工，违反 CLAUDE.md 范围克制）
- Layout 三 pass 算法 + trailing-wins，覆盖 cli888 实测的 Length/Min/Percentage 100% case
- 范围冻结严格执行：不实现 Max/Ratio/Fill/cassowary

**判定锚：** M4 必须证明 200×60 全屏刷新 frame time < 1ms。
