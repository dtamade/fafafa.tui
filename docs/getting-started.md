# Getting Started

5 分钟从零到一个可交互的 TUI 应用。

## 前置条件

- FreePascal >= 3.2.2（`fpc --version`）
- Linux 或 macOS（ANSI 终端）
- Git

## 1. 克隆

```bash
git clone https://github.com/user/fafafa.tui.git
cd fafafa.tui
```

## 2. 安装（生成编译配置）

```bash
bash install.sh
```

这会生成 `fafafa_tui.cfg`，包含所有 `-Fu` 路径。之后编译任何使用 fafafa.tui 的程序只需：

```bash
fpc @/path/to/fafafa.tui/fafafa_tui.cfg yourapp.lpr
```

## 3. 验证安装

```bash
make test
```

应看到 664 tests, 0 failures。

## 4. 创建你的第一个应用

```bash
make quickstart NAME=hello
cd hello
make run
```

这会生成一个带计数器的交互式 TUI 应用。按空格递增，按 q 退出。

## 5. 理解生成的代码

```pascal
program hello;
{$mode objfpc}{$H+}
uses
  ftui_app, ftui_event, ftui_terminal, ftui_rect,
  ftui_style, ftui_buffer, ftui_block, ftui_borders,
  ftui_paragraph;

type
  TMyApp = class(TApp)
  private
    FCounter: Integer;
  protected
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure TMyApp.Render(var Frame: TFrame);
var S: string[16];
begin
  Str(FCounter, S);
  TParagraph.FromString('Counter: ' + S)
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' hello '))
    .Render(Frame.Area, Frame.Buffer);
end;

procedure TMyApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  if (Ev.Key.Code = kcChar) and (Ev.Key.Ch = Ord(' ')) then
    Inc(FCounter);
end;

var App: TMyApp;
begin
  App := TMyApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
```

核心模式：

1. 继承 `TApp`
2. Override `Render` — 每帧绘制 UI
3. Override `HandleEvent` — 处理输入
4. `TApp.Run` 管理终端生命周期（进入 raw mode → 主循环 → 恢复终端）

默认 Ctrl+C / Ctrl+Q 退出。

## 6. 下一步

- 浏览 `examples/` 目录查看更多 widget 用法
- 查看 `docs/api-stability.md` 了解哪些 API 可以安全依赖
- 运行 `make bench` 查看性能基准

## 集成到已有项目

### 方式 A：Makefile include

```makefile
FTUI_ROOT := /path/to/fafafa.tui
include $(FTUI_ROOT)/fafafa_tui.mk

FPC_FLAGS := -MObjFPC -Sh $(FTUI_FPC_FLAGS) -FEbuild
myapp: myapp.lpr
	$(FPC) $(FPC_FLAGS) $<
```

### 方式 B：fpc @cfg

```bash
fpc @/path/to/fafafa.tui/fafafa_tui.cfg -FEbuild myapp.lpr
```

### 方式 C：Lazarus IDE

打开 `fafafa_tui.lpk`，安装为 IDE 包。之后在项目依赖中添加 `fafafa_tui`。
