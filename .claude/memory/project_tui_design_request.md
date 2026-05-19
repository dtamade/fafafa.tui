---
name: tui-design-migration-request
description: tui-design 项目对 fafafa.tui 的承接需求清单——鼠标全协议、overlay 渲染、pointer capture、hover/leave、scrollbar 原语等
metadata: 
  node_type: memory
  type: project
  originSessionId: cab57cca-ba23-4226-a721-4b7d7886f7fc
---

tui-design 项目负责人对 fafafa.tui 提出的承接需求（2026-05-19）。

**Why:** tui-design 是一个编辑器级 TUI 应用（画布工具、图层面板、弹窗交互），需要 fafafa.tui 从"cli888 渲染子集"升级为"编辑器级交互运行时"。如果不承接，tui-design 会另起一层。

**How to apply:** 这份需求是 fafafa.tui 的下一阶段路线图输入。不需要一次性全做，但需要明确哪些承接、哪些拒绝、哪些分阶段。

## 核心需求分类

### P0 — 必须做（否则无法承接）

1. **鼠标全协议**：SGR mouse motion tracking（不只是 click+wheel）
   - MouseMoved / MouseDown / MouseUp / MouseDrag / MouseWheel
   - 开启：`CSI ?1003h`（any-event tracking）+ `CSI ?1006h`（SGR encoding）
   - 恢复：退出时 `CSI ?1003l` + `CSI ?1006l`
   - 坐标：统一 0-based cell 坐标 + 按钮 + 修饰键 + event kind

2. **Pointer capture**：drag 开始后目标锁定，直到 MouseUp 或 Esc 释放
   - 上层注册 capture target
   - 所有后续 move/up 事件路由到 captured target
   - Esc 中断 = 释放 capture + 通知上层 cancel

3. **Hover/Leave 语义**：
   - 上层能判断"刚进入/刚移出/仍在内部"
   - 移出时触发清理回调
   - 重新进入时触发恢复回调

4. **Overlay/preview 渲染层**：
   - 至少两层 buffer：base（静态文档）+ overlay（动态预览）
   - overlay-only redraw：鼠标移动时只重绘 overlay，不触发 base diff
   - 清除 overlay 不影响 base

5. **Esc 统一中断语义**：
   - Esc 不被 TTerminal 吞掉
   - 上层能注册"当前交互 session"，Esc 触发 session.Cancel
   - cancel 清理 capture + hover + drag 状态

### P1 — 应该做（提升可用性）

6. **Scrollbar 通用原语**：track/thumb 计算、click 分页、drag 更新、释放清理
7. **Hit-test / region helper**：统一的区域命中判断，不让上层裸算像素
8. **Interaction session helper**：pointer down → up/esc 的会话抽象
9. **列表拖拽重排 primitives**：row hit-test、drag source/target、drop commit

### P2 — 可以后做（锦上添花）

10. **跨终端能力矩阵**：wezterm/kitty/xterm/tmux/Windows Terminal 支持度
11. **降级策略**：不支持 motion tracking 时显式降级到 click/wheel
12. **文本宽度统一 contract**：鼠标命中、文本裁切、对齐、滚动共用同一套宽度计算

### 对 ccore 的要求（转发）

- stable / experimental / internal 三级公开面
- 稳定可锁定的 integration tag/branch
- 不无限上卷成应用框架
- 图片 IO / HTTP / 剪贴板等能力的边界先定清楚

## fafafa.tui 当前差距

| 需求 | 当前状态 | 差距 |
|---|---|---|
| 鼠标 motion tracking | 只有 click + wheel | 需要加 Moved/Drag/Up + CSI 1003h |
| Pointer capture | 无 | 需要新建 capture 机制 |
| Hover/Leave | 无 | 需要新建 hover tracking |
| Overlay buffer | 无（单 buffer diff） | 需要双层 buffer 架构 |
| Esc 中断 | 当前直接退出程序 | 需要 session 抽象 |
| Scrollbar | 无 | 需要新建 widget |
| Hit-test | 无 | 需要新建 helper |
| 跨终端矩阵 | 未文档化 | 需要写 |

## 决策点

用户需要决定：
1. fafafa.tui 是否承接 tui-design？（定位升级）
2. 如果承接，分几个阶段？
3. 是否需要先出 migration profile 文档再动代码？

相关：[[project-fafafa-tui]]、[[ftui-performance-discipline]]
