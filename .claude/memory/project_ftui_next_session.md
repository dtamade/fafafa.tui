---
name: ftui-next-session-plan
description: 下次会话待办：TTerminal 重构集成 overlay/capture/session + 文档统一 + 迁移验收测试
metadata:
  type: project
---

下次会话进入 ~/projects/fafafa.tui 时的待办：

核心任务：把 overlay/capture/session 从 demo 手工拼升级为 TTerminal 原生支持。

## 1. TTerminal 重构

- TFrame 加 Overlay: TOverlayBuffer 字段
- TTerminal 加 FMerged/FOverlay/FCapture/FSession/FPrevMousePos
- TTerminal 加 HasMouseTracking/HasTruecolor/HasKittyKeyboard 属性
- BeginFrame: FCurr.Reset + FOverlay.Clear，Frame.Overlay := FOverlay
- EndFrame: copy FCurr→FMerged, FOverlay.MergeInto(FCurr, FMerged), diff FPrev vs FMerged
- DetectCapabilities: 检测 $COLORTERM/$TERM_PROGRAM

## 2. 迁移验收测试 (test_migration_acceptance.pas)

- Moved hover（SGR 序列 → DetectHoverChange）
- Drag 只写 overlay（base 不变）
- 离开区域清 preview
- Esc cancel 回滚 session

## 3. 文档统一

- README: 定位升级为"通用 TUI 运行时"
- CLAUDE.md: 范围扩展到 tui-design
- port-roadmap.md: 纳入 Phase A-D + v0.7.0-beta
- api-stability.md: terminal 升级为 experimental
- migration-profile.md: 标记 [delivered] vs [planned]

## 当前 git 状态

3ff41be wip: terminal uses overlay+interaction (prep for integration)
v0.7.0-beta tag 已打。211 测试全过。
