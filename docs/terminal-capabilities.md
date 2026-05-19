# 跨终端能力矩阵

fafafa.tui 依赖的终端能力及各终端支持情况。

## 能力列表

| 能力 | ANSI 序列 | 用途 |
|---|---|---|
| Alternate screen | CSI ?1049h/l | 保护用户 scrollback |
| SGR mouse encoding | CSI ?1006h/l | 坐标 > 223 + 精确按钮 |
| Any-event tracking | CSI ?1003h/l | MouseMoved 不需要按钮 |
| Button-event tracking | CSI ?1002h/l | MouseDrag（按住移动） |
| Normal tracking | CSI ?1000h/l | 基础 click + release |
| Kitty keyboard | CSI > 1u / CSI < u | Shift+Enter 区分（parser 能解析，不主动启用） |
| Truecolor (24-bit) | SGR 38;2;r;g;b | RGB 颜色 |
| 256-color | SGR 38;5;n | 索引颜色 |
| Bold/Italic/Underline | SGR 1/3/4 | 文本修饰 |
| Cursor style | CSI q | Bar/Block/Underline |
| Unicode box drawing | U+2500 range | 边框字符 |
| Wide characters | CJK/Emoji | 双宽 cell |

## 终端支持矩阵

| 终端 | Alt screen | SGR mouse | Any-event (1003) | Kitty kbd | Truecolor | Wide char |
|---|---|---|---|---|---|---|
| **wezterm** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **kitty** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **ghostty** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **alacritty** | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **gnome-terminal** | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **xterm** | ✅ | ✅ | ✅ | ❌ | ⚠️ 需配置 | ✅ |
| **Windows Terminal** | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **tmux** | ✅ | ✅ | ⚠️ `set -g mouse on` | ❌ | ✅ | ✅ |
| **screen** | ✅ | ⚠️ 部分 | ❌ | ❌ | ❌ | ⚠️ |
| **Linux console** | ✅ | ❌ | ❌ | ❌ | ❌ | ⚠️ |

## 降级策略

### 全功能（wezterm / kitty / ghostty）
- 所有能力可用
- Shift+Enter 通过 CSI u 区分
- 鼠标 move/drag/hover 全部工作

### 标准功能（alacritty / gnome-terminal / Windows Terminal）
- 鼠标 move/drag/hover 全部工作
- Shift+Enter 无法区分（降级为 Alt+Enter）
- Truecolor 可用

### 受限功能（tmux）
- 需要用户配置 `set -g mouse on`
- 鼠标事件可能被 tmux 截获
- 建议：检测 $TMUX 环境变量，提示用户配置

### 最低功能（screen / Linux console）
- 只有键盘输入
- 无鼠标事件
- 无 truecolor（降级到 256-color 或 16-color）
- fafafa.tui 仍然可用（键盘导航 + indexed color）

## fafafa.tui 的降级行为

```pascal
// TTerminal 提供能力查询：
TTerminal.HasMouseTracking: Boolean;    // optimistic: 已请求开启 1003h（不做主动探测）
TTerminal.HasTruecolor: Boolean;        // 检测 $COLORTERM
TTerminal.HasKittyKeyboard: Boolean;    // $TERM_PROGRAM 乐观推断（kitty/wezterm/ghostty）
```

消费方根据这些 flag 决定：
- `HasMouseTracking = False` → 不显示 hover 反馈，不启用 drag
- `HasTruecolor = False` → 用 indexed color 替代 RGB
- `HasKittyKeyboard = False` → Shift+Enter 降级为 Alt+Enter

## 检测方法

1. **$COLORTERM**：`truecolor` 或 `24bit` → HasTruecolor
2. **$TERM_PROGRAM**：`WezTerm` / `kitty` / `ghostty` → HasKittyKeyboard
3. **$TMUX**：非空 → 提示 mouse 配置
4. **CSI ?1003h**：发送后直接设为 True（optimistic flag，不做被动检测）
