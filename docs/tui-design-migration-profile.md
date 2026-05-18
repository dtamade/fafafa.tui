# fafafa.tui — tui-design Migration Profile

本文档定义 fafafa.tui 为承接 tui-design 迁移所提供的能力合同。
tui-design 负责人可据此判断是否锁定 fafafa.tui 作为主承接层。

## 1. 事件模型合同

### 鼠标事件

```pascal
TMouseEventKind = (
  mkDown,        // 按钮按下（含按钮 ID）
  mkUp,          // 按钮释放
  mkMoved,       // 移动（无按钮按下）
  mkDrag,        // 拖拽（有按钮按下时移动）
  mkWheel        // 滚轮（ScrollUp / ScrollDown）
);

TMouseButton = (mbLeft, mbMiddle, mbRight);

TMouseEvent = record
  Kind: TMouseEventKind;
  Button: TMouseButton;
  X, Y: Word;              // 0-based cell 坐标
  Modifiers: TKeyModifiers;
end;
```

**协议**：SGR 1006 编码 + any-event tracking (CSI ?1003h)。
**开启**：`TTerminal.EnterTui` 自动发送 `CSI ?1003h` + `CSI ?1006h`。
**恢复**：`TTerminal.LeaveTui` 自动发送 `CSI ?1003l` + `CSI ?1006l`。
**坐标语义**：所有事件统一 0-based cell 坐标，消费方不需要自己减 1。

### 键盘事件

保持现有 `TKeyEvent` 不变。CSI u (kitty protocol) 已支持 Shift+Enter 等修饰键区分。

### Esc 合同

- `TTerminal` 不吞 Esc——始终作为 `kcEsc` 事件传递给消费方
- 消费方通过 `TInteractionSession` 注册当前交互上下文
- Esc 到达时，如果有活跃 session，先触发 `session.Cancel`
- 如果没有活跃 session，Esc 传递到应用层（退出/关闭弹窗等）

## 2. 渲染层次合同

### 双层 Buffer 架构

```
┌─────────────────────────────┐
│  Overlay Buffer (dynamic)   │  ← 工具预览、光标反馈、hover 高亮
├─────────────────────────────┤
│  Base Buffer (static)       │  ← 文档内容、UI chrome、弹窗
└─────────────────────────────┘
         ↓ Merge
┌─────────────────────────────┐
│  Merged Buffer              │  ← Diff against prev frame → ANSI output
└─────────────────────────────┘
```

**合同**：
- `Frame.BaseBuffer`：静态内容，只在文档/UI 变化时重绘
- `Frame.OverlayBuffer`：动态内容，每次鼠标移动可重绘
- `Frame.InvalidateOverlay`：只重绘 overlay，不触发 base diff [planned — 当前实现是全帧 merge，性能已验证 10μs/event]
- `Frame.InvalidateBase`：重绘 base + overlay
- Merge 算法：overlay cell 非空时覆盖 base cell（简单覆盖，不做 alpha）

**性能保证**：
- overlay-only redraw：只 diff overlay 变化的 cell（鼠标移动热路径）
- base 不变时 merged result 只在 overlay 区域产出 patch
- 连续 move/drag 时不会整屏暴力刷新

### 脏标记

消费方可设置脏标记控制重绘粒度：

```pascal
TInvalidation = set of (
  invBase,       // 文档/UI 变化
  invOverlay,    // 预览/光标/hover 变化
  invCursor      // 只光标位置变化
);
```

## 3. Pointer Capture 合同

```pascal
TTerminal.SetCapture(Target: Pointer);   // 开始捕获
TTerminal.ReleaseCapture;                // 释放捕获
TTerminal.HasCapture: Boolean;           // 查询状态
```

**行为**：
- `SetCapture` 后，所有 mkMoved/mkDrag/mkUp 事件路由到 captured target
- `ReleaseCapture` 或 mkUp 自动释放
- Esc 触发 `session.Cancel` → 自动 `ReleaseCapture`
- 捕获期间鼠标离开终端窗口：不产生 Leave 事件（终端限制），但 Up 事件仍然到达

## 4. Hover/Leave 合同

```pascal
TTerminal.HoverTarget: Pointer;          // 当前 hover 的目标
TTerminal.PrevMousePos: TPosition;       // 上一帧鼠标位置
```

**消费方判断逻辑**：
- Enter = `PrevMousePos` 不在区域内 + 当前 `MousePos` 在区域内
- Leave = `PrevMousePos` 在区域内 + 当前 `MousePos` 不在区域内
- Stay = 两帧都在区域内

**fafafa.tui 提供的 helper**：

```pascal
function HitTest(const Area: TRect; const Ev: TMouseEvent): Boolean;
function HoverChanged(const Area: TRect; Prev, Curr: TPosition): THoverChange;
// THoverChange = (hcNone, hcEntered, hcLeft, hcStay)
```

## 5. Scrollbar 合同

```pascal
TScrollbar = record
  // 输入
  TotalItems: Integer;
  VisibleItems: Integer;
  ScrollOffset: Integer;
  // 输出
  function TrackRect(const Area: TRect): TRect;
  function ThumbRect(const Area: TRect): TRect;
  function HitThumb(const Area: TRect; Y: Integer): Boolean;
  function HitTrack(const Area: TRect; Y: Integer): TScrollbarHit;
  // TScrollbarHit = (shAbove, shThumb, shBelow)
  // 渲染
  procedure Render(const Area: TRect; ABuf: TBuffer; const Sty: TScrollbarStyle);
end;
```

**拖拽合同**：
- MouseDown on thumb → SetCapture
- Drag → 更新 ScrollOffset 按比例
- MouseUp → ReleaseCapture + commit
- Esc → ReleaseCapture + 回滚到 drag 前的 offset

## 6. 文本宽度合同

所有组件共用 `ftui_grapheme.GraphemeWidth` 和 `GraphemeAdvance`：
- 鼠标命中计算
- 文本裁切
- 对齐
- 滚动偏移
- 光标定位

**保证**：同一个字符串在渲染和命中计算中返回相同的列宽。

## 7. 降级策略

| 终端 | Motion tracking | SGR mouse | 降级行为 |
|---|---|---|---|
| wezterm | ✅ | ✅ | 全功能 |
| kitty | ✅ | ✅ | 全功能 |
| alacritty | ✅ | ✅ | 全功能 |
| ghostty | ✅ | ✅ | 全功能 |
| gnome-terminal | ✅ | ✅ | 全功能 |
| xterm | ✅ | ✅ | 全功能 |
| tmux | ⚠️ 需配置 | ✅ | 需 `set -g mouse on` |
| Windows Terminal | ✅ | ✅ | 全功能 |
| 不支持 1003h 的终端 | ❌ | ❌ | 降级到 click+wheel only |

**降级检测**：`TTerminal.HasMouseTracking: Boolean`（optimistic flag：开启 1003h 后设为 True；不做主动探测，因为大多数现代终端都支持）。
**显式降级**：消费方可查询 `HasMouseTracking` 决定是否启用 hover/drag 功能。

## 8. Interaction Session 合同

```pascal
TInteractionSession = class
  procedure Begin_(Target: Pointer);
  procedure Commit;
  procedure Cancel;
  function IsActive: Boolean;
  property Target: Pointer;
end;
```

**生命周期**：
- `Begin_`：注册当前交互（drag/stroke/rename/filter）
- `Commit`：正常结束（MouseUp / Enter）
- `Cancel`：中断（Esc / 焦点丢失）
- Cancel 自动清理：ReleaseCapture + 通知 target + 清除 hover state

## 9. 稳定锚点承诺

- Phase A 完成后打 tag `v0.5.0-alpha`（鼠标全协议 + capture + session）
- Phase B 完成后打 tag `v0.6.0-alpha`（overlay + hover）
- Phase C 完成后打 tag `v0.7.0-beta`（scrollbar + hit-test + primitives）
- Phase D 打 tag `v0.8.0-rc`（文档 + 矩阵 + 稳定 API）
- 正式承接 tag：`v1.0.0-tui-design-ready`

**API 稳定性**：
- `stable`：tag 之间不改签名
- `experimental`：可能在下一个 tag 改
- `internal`：随时可改，消费方不应依赖

## 10. 首波验收对照

| tui-design 验收项 | fafafa.tui 交付 Phase |
|---|---|
| 鼠标 Moved 实时更新画布 cursor | Phase A |
| 移出画布清 preview，进入恢复 | Phase B |
| Line/Rect 拖拽只显示预览 | Phase B |
| Esc 中断 stroke 回滚 | Phase A |
| 图层列表 row drag reorder | Phase C |
| scrollbar thumb drag | Phase C |
| 弹窗按钮/grid hover 正确清理 | Phase B |
| 跨终端 fallback | Phase D |

## 11. 实现说明（给迁移方的技术透明度）

### overlay 热路径的实际实现

当前 EndFrame 的实现是：
1. Copy base (FCurr) → merged (FMerged)
2. FOverlay.MergeInto(FCurr, FMerged) — 只覆盖 marked cells
3. FPrev.Diff(FMerged, Patches) — diff 只产出变化的 cell

**为什么这已经是 overlay-only redraw**：
- 如果 base 没变（只有 overlay 变了），step 3 的 diff 只产出 overlay 区域的 patches
- 终端只收到 overlay 变化的 ANSI 序列，不是整屏
- bench_mouse_move 证明：1000 次连续 moved 事件，每次 10μs（含 copy + merge + diff）

**为什么不做 InvalidateOverlay 快捷路径**：
- 当前实现已经满足性能目标（10μs < 500μs 预算的 50 倍）
- 加快捷路径会增加状态管理复杂度（需要跟踪"base 是否变了"）
- 如果未来画布规模增大（如 400×100），可以加——但那时再做，不提前优化

**迁移方可以依赖的行为保证**：
- 连续 move/drag 不会整屏暴力刷新（diff 保证）
- overlay.Clear 后下一帧 merged = base（旧 preview 消失）
- 性能预算：mouse move 热路径 < 100μs/event

### HasMouseTracking 的语义

`HasMouseTracking` 是 **optimistic flag**：
- EnterTui 发送 CSI ?1003h 后设为 True
- 不做主动探测（因为几乎所有现代终端都支持）
- 如果终端不支持，消费方不会收到 mkMoved/mkDrag 事件（静默降级）
- 消费方可以检查"是否收到过 mkMoved"来判断实际支持度

### 可锁定基线

**tui-design 应锁定 `v0.8.0-rc`**。

这个 tag 包含：
- 鼠标全协议 + overlay + capture + session + scrollbar + hit-test
- TTerminal 原生集成（不需要手工拼）
- 211 个自动化测试
- canvas_overlay_demo 验收 4 项
- bench_mouse_move 性能证明
- 文档统一（README/CLAUDE.md/api-stability/migration-profile 一致）

升级到未来 tag 时看 CHANGELOG.md 的 Breaking changes 段。
