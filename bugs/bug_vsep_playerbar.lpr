program bug_vsep_playerbar;
{$mode objfpc}{$H+}
{
  Feature Request: TPanel 支持 VSep 在特定行终止（或 per-HSep 的 StartCol）

  需求场景：音乐播放器、文件管理器等常见 TUI 布局：
  ┌─ sidebar ─┬─ content ─┐
  │            │            │
  │            │            │
  ├────────────┴────────────┤  ← VSep 在此终止，全宽分隔线
  │  player bar (全宽)      │
  └─────────────────────────┘

  当前 TPanel 的行为：
  - WithHSepStartCol(1) 让 HSep 只在右侧画（sidebar 跨行）
  - 但 VSep 贯穿所有行，无法在某行停止
  - 导致 player bar 被竖线切断

  当前 workaround：嵌套两个 panel + 手动补 junction 字符（┬/┴）
  可以工作，但不够优雅，且 junction 需要手动计算坐标。

  建议 API（任选其一）：
  A. WithVSepEndRow(SepIndex: Integer; Row: Integer): TPanel
     — VSep 只画到指定行（不含），之后的行不画
  B. Per-separator 的 HSepStartCol：
     WithHSepStartCol(SepIndex: Integer; Col: Integer): TPanel
     — 让 HSep[0] 从 col 1 开始，HSep[1] 从 col 0 开始
  C. 自动检测：当某行的所有 cell 被 span 合并时，自动不画 VSep

  方案 B 最灵活，且和现有 WithHSepVisible(SepIndex, Bool) 风格一致。

  参考：go-musicfox、ncmpcpp、cmus、spotify-tui 都是这种布局。
}
uses
  ftui_app, ftui_event, ftui_terminal, ftui_rect,
  ftui_color, ftui_style, ftui_buffer, ftui_text,
  ftui_borders, ftui_layout, ftui_panel, ftui_paragraph;

type
  TBugApp = class(TApp)
  protected
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure TBugApp.Render(var Frame: TFrame);
var
  G: TPanelGrid;
begin
  // 期望：2列×2行，VSep 只在 row 0，row 1 是全宽的 player bar
  // 实际：VSep 贯穿 row 0 和 row 1，player bar 被竖线切断
  G := TPanel.Create(
    [LengthConstraint(16), MinConstraint(0)],
    [MinConstraint(0), LengthConstraint(1)]
  ).WithBorderSet(BorderSetPlain)
   .WithBorderStyle(TStyle.Default.WithFg(clWhite))
   .Render(Frame.Area, Frame.Buffer);

  TParagraph.FromString(' Sidebar')
    .WithStyle(TStyle.Default.WithFg(clCyan))
    .Render(PanelCell(G, 0, 0), Frame.Buffer);

  TParagraph.FromString(' Content area')
    .WithStyle(TStyle.Default.WithFg(clGreen))
    .Render(PanelCell(G, 1, 0), Frame.Buffer);

  // Player bar 应该全宽，但 VSep 的 │ 穿过了这一行
  TParagraph.FromString(' Player bar - should be full width without | in the middle')
    .WithStyle(TStyle.Default.WithFg(clYellow))
    .Render(PanelCell(G, 0, 1), Frame.Buffer);
end;

procedure TBugApp.HandleEvent(const Ev: TEvent);
begin
  if (Ev.Kind = evKey) and (Ev.Key.Code = kcChar) and (Ev.Key.Ch = Ord('q')) then
    Quit;
end;

var App: TBugApp;
begin
  App := TBugApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
