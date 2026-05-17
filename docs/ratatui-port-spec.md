# ratatui → fafafa.tui 移植规范

这是 Rust ratatui 0.29 → FreePascal fafafa.tui 的逐项 API 映射表。先文档后代码：每个新 ratatui 概念在被实现之前，必须先在这里登记。

参考版本：ratatui 0.29.x（锁死，不追上游）。

## 1. 基础数据类型

### Rect / Position / Size / Margin

```rust
// ratatui::layout::Rect
pub struct Rect { pub x: u16, pub y: u16, pub width: u16, pub height: u16 }
impl Rect {
    pub fn new(x: u16, y: u16, w: u16, h: u16) -> Self;
    pub fn area(self) -> u32;
    pub fn left/right/top/bottom() -> u16;
    pub fn intersection(self, other: Rect) -> Rect;
    pub fn union(self, other: Rect) -> Rect;
    pub fn contains(self, p: Position) -> bool;
    pub fn intersects(self, other: Rect) -> bool;
    pub fn inner(self, margin: Margin) -> Rect;  // shrink by margin
}
```

```pascal
// ftui_rect.pas
type
  TPosition = packed record X, Y: Word; end;
  TSize     = packed record Width, Height: Word; end;
  TMargin   = packed record Horizontal, Vertical: Word; end;

  TRect = packed record
    X, Y, Width, Height: Word;
    class function Make(AX, AY, AW, AH: Word): TRect; static; inline;
    function Area: LongWord; inline;
    function Left: Word; inline;
    function Right: Word; inline;
    function Top: Word; inline;
    function Bottom: Word; inline;
    function Intersection(const Other: TRect): TRect;
    function Union(const Other: TRect): TRect;
    function Contains(const P: TPosition): Boolean;
    function Intersects(const Other: TRect): Boolean;
    function Inner(const M: TMargin): TRect;
    function IsEmpty: Boolean; inline;
  end;
```

### Color

```rust
pub enum Color {
    Reset, Black, Red, Green, Yellow, Blue, Magenta, Cyan, Gray,
    DarkGray, LightRed, LightGreen, LightYellow, LightBlue,
    LightMagenta, LightCyan, White,
    Rgb(u8, u8, u8),
    Indexed(u8),
}
```

```pascal
// ftui_color.pas
type
  TColorKind = (ckReset, ckIndexed, ckRgb);

  TColor = packed record
    Kind: TColorKind;
    case Byte of
      0: (Index: Byte);            // for ckIndexed; named colors map to 0..15
      1: (R, G, B: Byte);          // for ckRgb
  end;

// Constructors (无构造，直接函数返回 record)
function ResetColor: TColor; inline;
function IndexedColor(I: Byte): TColor; inline;
function RgbColor(R, G, B: Byte): TColor; inline;

// Named color constants (映射到 IndexedColor 0..15)
const
  clBlack:        TColor = (Kind: ckIndexed; Index: 0);
  clRed:          TColor = (Kind: ckIndexed; Index: 1);
  clGreen:        TColor = (Kind: ckIndexed; Index: 2);
  clYellow:       TColor = (Kind: ckIndexed; Index: 3);
  clBlue:         TColor = (Kind: ckIndexed; Index: 4);
  clMagenta:      TColor = (Kind: ckIndexed; Index: 5);
  clCyan:         TColor = (Kind: ckIndexed; Index: 6);
  clGray:         TColor = (Kind: ckIndexed; Index: 7);
  clDarkGray:     TColor = (Kind: ckIndexed; Index: 8);
  clLightRed:     TColor = (Kind: ckIndexed; Index: 9);
  clLightGreen:   TColor = (Kind: ckIndexed; Index: 10);
  clLightYellow:  TColor = (Kind: ckIndexed; Index: 11);
  clLightBlue:    TColor = (Kind: ckIndexed; Index: 12);
  clLightMagenta: TColor = (Kind: ckIndexed; Index: 13);
  clLightCyan:    TColor = (Kind: ckIndexed; Index: 14);
  clWhite:        TColor = (Kind: ckIndexed; Index: 15);
  clReset:        TColor = (Kind: ckReset; Index: 0);

function ColorEquals(const A, B: TColor): Boolean; inline;
```

### Modifier

```rust
bitflags! {
    pub struct Modifier: u16 {
        const BOLD = 1<<0;
        const DIM = 1<<1;
        const ITALIC = 1<<2;
        const UNDERLINED = 1<<3;
        const SLOW_BLINK = 1<<4;
        const RAPID_BLINK = 1<<5;
        const REVERSED = 1<<6;
        const HIDDEN = 1<<7;
        const CROSSED_OUT = 1<<8;
    }
}
```

```pascal
// ftui_modifier.pas
type
  TModifierBit = (
    mbBold, mbDim, mbItalic, mbUnderlined,
    mbSlowBlink, mbRapidBlink, mbReversed,
    mbHidden, mbCrossedOut
  );
  TModifier = set of TModifierBit;
```

Pascal `set` 在 9 个元素时编译为 16-bit，跟 Rust bitflags `u16` 对等。

### Style

```rust
pub struct Style {
    pub fg: Option<Color>,
    pub bg: Option<Color>,
    pub underline_color: Option<Color>,
    pub add_modifier: Modifier,
    pub sub_modifier: Modifier,
}
impl Style {
    pub fn fg(self, c: Color) -> Self;
    pub fn bg(self, c: Color) -> Self;
    pub fn add_modifier(self, m: Modifier) -> Self;
    pub fn remove_modifier(self, m: Modifier) -> Self;
    pub fn patch(self, other: Style) -> Self;
}
```

```pascal
// ftui_style.pas
type
  TStyle = packed record
    FgKind: (skNone, skSet);
    Fg: TColor;
    BgKind: (skNone, skSet);
    Bg: TColor;
    UlKind: (skNone, skSet);
    Ul: TColor;
    AddMod: TModifier;
    SubMod: TModifier;

    class function Default: TStyle; static; inline;
    function WithFg(const C: TColor): TStyle;
    function WithBg(const C: TColor): TStyle;
    function WithUnderline(const C: TColor): TStyle;
    function WithModifier(const M: TModifier): TStyle;        // = AddMod
    function WithoutModifier(const M: TModifier): TStyle;     // = SubMod
    function Patch(const Other: TStyle): TStyle;
  end;

function StyleDefault: TStyle; inline;
function StyleEquals(const A, B: TStyle): Boolean;
```

注：Rust `Option<Color>` 翻译成 `FgKind/BgKind/UlKind` 三个独立 enum + 同名 TColor 字段，避免引入 `TOptionalColor` 类型。

## 2. Cell + Buffer

### Cell

```rust
pub struct Cell {
    pub symbol: CompactString,   // ≤24 bytes inline
    pub fg: Color,
    pub bg: Color,
    pub underline_color: Color,
    pub modifier: Modifier,
    pub skip: bool,
}
```

```pascal
// ftui_cell.pas
const
  FTUI_CELL_GLYPH_BYTES = 24;

type
  TCellGlyph = packed record
    Len: Byte;
    Bytes: array[0..FTUI_CELL_GLYPH_BYTES - 1] of Byte;
  end;

  TCell = packed record
    Glyph: TCellGlyph;
    Fg, Bg, Ul: TColor;
    Modifier: TModifier;
    Width: Byte;     // 1 or 2
    Skip: Boolean;
  end;
  PCell = ^TCell;

// Helpers
procedure CellReset(var C: TCell); inline;
procedure CellSetGlyph(var C: TCell; const S: AnsiString);
procedure CellApplyStyle(var C: TCell; const S: TStyle); inline;
function CellEquals(const A, B: TCell): Boolean;
```

### Buffer

```rust
pub struct Buffer {
    pub area: Rect,
    pub content: Vec<Cell>,
}
impl Buffer {
    pub fn empty(area: Rect) -> Self;
    pub fn filled(area: Rect, cell: &Cell) -> Self;
    pub fn cell(&self, p: Position) -> Option<&Cell>;
    pub fn cell_mut(&mut self, p: Position) -> Option<&mut Cell>;
    pub fn set_string(&mut self, x, y, s, style);
    pub fn set_stringn(&mut self, x, y, s, max_w, style);
    pub fn set_style(&mut self, area: Rect, style: Style);
    pub fn diff(&self, other: &Buffer) -> Vec<(u16, u16, &Cell)>;
    pub fn resize(&mut self, area: Rect);
    pub fn reset(&mut self);
}
```

```pascal
// ftui_buffer.pas
type
  TDiffEntry = packed record
    X, Y: Word;
    Cell: TCell;
  end;
  TDiffEntries = array of TDiffEntry;

  TBuffer = class
  private
    FArea: TRect;
    FContent: array of TCell;
    function IndexOf(X, Y: Integer): Integer; inline;
  public
    constructor CreateEmpty(const Area: TRect);
    constructor CreateFilled(const Area: TRect; const C: TCell);

    property Area: TRect read FArea;
    function CellAt(X, Y: Integer): PCell;       // nil if out of range
    procedure SetString(X, Y: Integer; const S: AnsiString; const Style: TStyle);
    procedure SetStringN(X, Y: Integer; const S: AnsiString; MaxW: Integer; const Style: TStyle);
    procedure SetStyle(const A: TRect; const S: TStyle);
    procedure Reset;
    procedure Resize(const A: TRect);
    procedure Diff(const Prev: TBuffer; out Patches: TDiffEntries);
  end;
```

## 3. Text

### Span / Line / Text

```rust
pub struct Span<'a> { pub content: Cow<'a, str>, pub style: Style }
impl Span {
    pub fn raw(s) -> Self;
    pub fn styled(s, style) -> Self;
}

pub struct Line<'a> {
    pub spans: Vec<Span<'a>>,
    pub style: Style,
    pub alignment: Option<Alignment>,
}
impl Line {
    pub fn from(s) -> Self;
    pub fn raw(s) -> Self;
    pub fn styled(s, style) -> Self;
    pub fn width(&self) -> usize;
    pub fn alignment(self, a: Alignment) -> Self;
}

pub struct Text<'a> {
    pub lines: Vec<Line<'a>>,
    pub style: Style,
    pub alignment: Option<Alignment>,
}
```

```pascal
// ftui_text.pas
type
  TAlignment = (caLeft, caCenter, caRight);

  TSpan = packed record
    Content: AnsiString;
    Style: TStyle;
    class function Raw(const S: AnsiString): TSpan; static;
    class function Styled(const S: AnsiString; const St: TStyle): TSpan; static;
    function Width: Integer;          // grapheme cluster width sum
  end;

  TLine = record
    Spans: array of TSpan;
    Style: TStyle;
    HasAlignment: Boolean;
    Alignment: TAlignment;
    class function FromSpans(const ASpans: array of TSpan): TLine; static;
    class function FromString(const S: AnsiString): TLine; static;
    class function Raw(const S: AnsiString): TLine; static;
    class function Styled(const S: AnsiString; const St: TStyle): TLine; static;
    function Width: Integer;
    function WithAlignment(A: TAlignment): TLine;
  end;

  TText = record
    Lines: array of TLine;
    Style: TStyle;
    HasAlignment: Boolean;
    Alignment: TAlignment;
    class function FromString(const S: AnsiString): TText; static;
    class function FromLines(const ALines: array of TLine): TText; static;
    function Width: Integer;
    function Height: Integer;
  end;
```

注：Span 因为只装 `AnsiString` 引用计数字段，可以用 `packed record`；Line/Text 含 `array of TSpan` 动态数组，普通 `record` 更稳。

## 4. Layout

### Constraint

```rust
pub enum Constraint {
    Min(u16), Max(u16), Length(u16),
    Percentage(u16), Ratio(u32, u32), Fill(u16),
}
```

只实现 cli888 用到的三种：

```pascal
// ftui_layout.pas
type
  TConstraintKind = (ckLength, ckMin, ckPercentage);

  TConstraint = packed record
    Kind: TConstraintKind;
    Value: Word;
  end;

function LengthConstraint(N: Word): TConstraint; inline;
function MinConstraint(N: Word): TConstraint; inline;
function PercentageConstraint(N: Word): TConstraint; inline;

type
  TDirection = (dirHorizontal, dirVertical);

  TLayout = record
    Direction: TDirection;
    Constraints: array of TConstraint;

    class function Default: TLayout; static;
    function WithDirection(D: TDirection): TLayout;
    function WithConstraints(const Cs: array of TConstraint): TLayout;
    function Split(const Area: TRect): array of TRect;
  end;

function HorizontalSplit(const Area: TRect; const Cs: array of TConstraint): array of TRect;
function VerticalSplit(const Area: TRect; const Cs: array of TConstraint): array of TRect;
```

Split solver 算法（不用 cassowary）：

1. 总可用 size = Area.Width 或 Height（按 direction）
2. 第一遍：所有 Length / Percentage 直接占位
3. 第二遍：剩余空间均分给所有 Min（每个至少 Min.Value）
4. 第三遍：再有剩余继续分给 Min（多者均分）
5. clamp 到边界

cli888 实测覆盖率 100%。

## 5. Widgets

### IWidget interface

```rust
pub trait Widget {
    fn render(self, area: Rect, buf: &mut Buffer);
}
pub trait StatefulWidget {
    type State;
    fn render(self, area: Rect, buf: &mut Buffer, state: &mut Self::State);
}
```

```pascal
// ftui_widgets.pas
type
  IWidget = interface
    ['{...}']
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;
```

`StatefulWidget` 不抽接口——具体类自己开 Render 重载，多带 `var State: TXxxState` 参数。

### Block

```rust
pub struct Block { borders, title, title_alignment, border_style, padding, style }
```

cli888 用法：`Block::default().borders(Borders::ALL).title("...")` + `.border_style(...)` + `.style(...)`。

```pascal
type
  TBorderSide = (bsTop, bsRight, bsBottom, bsLeft);
  TBorders = set of TBorderSide;

const
  BordersNone: TBorders = [];
  BordersAll: TBorders = [bsTop, bsRight, bsBottom, bsLeft];

type
  TBlock = record
    Borders: TBorders;
    Title: AnsiString;
    TitleStyle: TStyle;
    BorderStyle: TStyle;
    Style: TStyle;
    HasTitle: Boolean;

    class function Default: TBlock; static;
    function WithBorders(B: TBorders): TBlock;
    function WithTitle(const T: AnsiString): TBlock;
    function WithTitleStyle(const S: TStyle): TBlock;
    function WithBorderStyle(const S: TStyle): TBlock;
    function WithStyle(const S: TStyle): TBlock;

    procedure Render(const Area: TRect; ABuf: TBuffer);
    function Inner(const Area: TRect): TRect;     // 减去 borders 的内部 area
  end;
```

不实现 `BorderType`（圆角/双线）、`Padding`、多 title、`title_alignment`（cli888 不用）。

### Paragraph

```rust
pub struct Paragraph<'a> { text, style, block, wrap, alignment, scroll }
```

```pascal
type
  TWrap = record
    Trim: Boolean;
  end;

const
  WrapTrim: TWrap = (Trim: True);

type
  TParagraph = record
    Text: TText;
    Style: TStyle;
    HasBlock: Boolean;
    Block: TBlock;
    HasWrap: Boolean;
    Wrap: TWrap;
    HasAlignment: Boolean;
    Alignment: TAlignment;
    Scroll: TPosition;          // (x_offset, y_offset)

    class function FromText(const T: TText): TParagraph; static;
    class function FromString(const S: AnsiString): TParagraph; static;
    function WithStyle(const S: TStyle): TParagraph;
    function WithBlock(const B: TBlock): TParagraph;
    function WithWrap(const W: TWrap): TParagraph;
    function WithAlignment(A: TAlignment): TParagraph;
    function WithScroll(X, Y: Word): TParagraph;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;
```

### List + ListState

```rust
pub struct ListItem<'a> { content: Text<'a>, style: Style }
pub struct List<'a> { items, block, style, highlight_style, highlight_symbol, repeat_highlight_symbol, scroll_padding }
pub struct ListState { offset, selected }
```

```pascal
type
  TListItem = record
    Content: TText;
    Style: TStyle;
    class function FromString(const S: AnsiString): TListItem; static;
    class function FromText(const T: TText): TListItem; static;
    function WithStyle(const S: TStyle): TListItem;
  end;

  TListState = record
    Offset: Integer;
    HasSelection: Boolean;
    Selected: Integer;
    procedure Select(I: Integer);
    procedure ClearSelection;
  end;

  TList = record
    Items: array of TListItem;
    Style: TStyle;
    HighlightStyle: TStyle;
    HighlightSymbol: AnsiString;
    HasBlock: Boolean;
    Block: TBlock;
    ScrollPadding: Word;

    class function Create(const AItems: array of TListItem): TList; static;
    function WithBlock(const B: TBlock): TList;
    function WithStyle(const S: TStyle): TList;
    function WithHighlightStyle(const S: TStyle): TList;
    function WithHighlightSymbol(const Sym: AnsiString): TList;
    procedure Render(const Area: TRect; ABuf: TBuffer);
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TListState);
  end;
```

### Clear

```pascal
type
  TClear = record
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

function ClearWidget: TClear; inline;
```

## 6. Backend / Terminal / Frame

### IBackend

```pascal
// ftui_backend.pas
type
  IBackend = interface
    ['{...}']
    function GetSize: TSize;
    procedure Draw(const Patches: TDiffEntries);
    procedure ShowCursor;
    procedure HideCursor;
    procedure SetCursorPosition(X, Y: Word);
    procedure SetCursorStyle(Kind: TCursorStyleKind);
    procedure ClearAll;
    procedure Flush;
  end;

  TCursorStyleKind = (
    csDefault, csBlinkingBlock, csSteadyBlock,
    csBlinkingUnderscore, csSteadyUnderscore,
    csBlinkingBar, csSteadyBar
  );
```

### ANSI backend / Test backend

`ftui_ansi_backend.pas`：写 stdout fd（默认 1），全用 byte buffer + `fpwrite`，**无字符串拼接**。

`ftui_test_backend.pas`：内部维护一个虚拟 buffer，提供 `DumpAsLines: array of AnsiString` / `DumpAsString` 给测试断言用。

### Terminal / Frame

```rust
pub struct Terminal<B: Backend> { backend, current_buffer, previous_buffer, hidden_cursor, viewport }
pub struct Frame<'a> { cursor_position, viewport_area, buffer, count }
impl Terminal {
    pub fn draw(&mut self, f: impl FnOnce(&mut Frame));
    pub fn resize(&mut self, area: Rect);
    pub fn clear(&mut self);
}
```

```pascal
// ftui_terminal.pas
type
  TFrame = class
  public
    Area: TRect;
    Buffer: TBuffer;
    HasCursor: Boolean;
    CursorPos: TPosition;
    CursorStyle: TCursorStyleKind;
    procedure RenderWidget(const W; const Area: TRect);   // generic helper
    procedure SetCursorPosition(X, Y: Word);
    procedure HideCursor;
  end;

  TTerminal = class
  private
    FBackend: IBackend;
    FPrev, FCurr: TBuffer;
    FFrame: TFrame;
  public
    constructor Create(ABackend: IBackend);
    destructor Destroy; override;

    function BeginFrame: TFrame;
    procedure EndFrame(F: TFrame);          // diff + flush
    procedure Resize(const A: TRect);
    procedure ClearAll;

    property Backend: IBackend read FBackend;
  end;
```

`RenderWidget` 用 generic 方法：

```pascal
generic procedure TFrame.RenderWidget<TWidget>(W: TWidget; const Area: TRect);
begin
  W.Render(Area, Self.Buffer);
end;
```

或者每个 widget 类型写一个 overload（更稳，FPC 泛型方法在 trunk 上偶有坑）。

## 7. Input

### Event

```rust
pub enum Event {
    Key(KeyEvent), Mouse(MouseEvent), Resize(u16, u16),
    Paste(String), FocusGained, FocusLost,
}
```

只实现 cli888 用到的三个：

```pascal
// ftui_event.pas
type
  TEventKind = (evKey, evMouse, evResize);

  TKeyCodeKind = (
    kcChar, kcEnter, kcEsc, kcTab, kcBackTab, kcBackspace, kcDelete,
    kcLeft, kcRight, kcUp, kcDown,
    kcHome, kcEnd, kcPageUp, kcPageDown,
    kcInsert, kcF, kcNull
  );

  TKeyModifier = (kmCtrl, kmAlt, kmShift);
  TKeyModifiers = set of TKeyModifier;

  TKeyEvent = packed record
    Code: TKeyCodeKind;
    Ch: Cardinal;          // for kcChar (UCS-4)
    F: Byte;               // for kcF, F1..F12
    Modifiers: TKeyModifiers;
  end;

  TMouseEventKind = (mkScrollUp, mkScrollDown, mkLeftDown);
  TMouseEvent = packed record
    Kind: TMouseEventKind;
    X, Y: Word;
    Modifiers: TKeyModifiers;
  end;

  TResizeEvent = packed record W, H: Word; end;

  TEvent = record
    Kind: TEventKind;
    case Byte of
      0: (Key: TKeyEvent);
      1: (Mouse: TMouseEvent);
      2: (Resize: TResizeEvent);
  end;
```

不实现 paste / focus / kitty protocol。

### Input parser

`ftui_input_parser.pas`：把 stdin 读出的字节流（含 ESC 序列）解析成 `TEvent`。最小集：

- ASCII 可打印字符 → `kcChar`
- ESC + 单字符 → Alt+Char
- CSI 序列（ESC [ ...）→ 方向键 / Home / End / PageUp/Down / Delete / 滚轮（SGR mouse）
- SS3 序列（ESC O ...）→ F1-F4
- 单 ESC（no follow-up within timeout）→ `kcEsc`

不解析：bracketed paste、focus events、kitty CSI u 协议。

## 8. cli888 实际使用频度（移植优先级参考）

数据来源：cli888 主仓 grep 统计（2026-05-18）。

| API | 次数 | 优先级 |
|---|---|---|
| `Color::Rgb` | 659 | M0 |
| `Span::styled` | 411 | M1 |
| `.fg()` | 477 | M0 |
| `Block::default + Borders::ALL` | 117 + 108 | M2 |
| `Modifier::BOLD` | 113 | M0 |
| `Constraint::Length` | 96 | M1 |
| `frame.render_widget` | 152 | M3 |
| `Color::DarkGray`/`Cyan`/`Yellow`/`Red` | 175 | M0（IndexedColor 即可） |
| `Constraint::Min` | 45 | M1 |
| `Constraint::Percentage` | 44 | M1 |
| `KeyCode::Char` | 484 | M3 |
| `KeyCode::Esc/Enter/方向键` | 333 | M3 |
| `MouseEventKind::ScrollUp/Down` | 12 | M3 |
| `Wrap{trim:true}` | 5 | M2 |
| `Borders::BOTTOM/TOP/RIGHT` | 7 | M2 |
| Tabs / Table / Gauge / Chart 等 | 0 | 不实现 |
| Bracketed paste / Focus events | 0 | 不实现 |
| Mouse drag / move | 0 | 不实现 |
