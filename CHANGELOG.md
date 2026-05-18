# Changelog

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
