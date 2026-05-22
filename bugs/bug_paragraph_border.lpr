program bug_paragraph_border;
{$mode objfpc}{$H+}
{
  BUG: TParagraph.Render 会破坏 TPanel 绘制的右边框

  复现步骤：
  1. 用 TPanel 创建一个带边框的布局
  2. 在某个 cell 内用 TParagraph.Render 渲染文字
  3. 右边框在 TParagraph 渲染的那几行会消失

  预期行为：TParagraph 只在 cell 内部渲染，不影响 cell 外的边框字符
  实际行为：右边框的 │ 字符在 TParagraph 渲染的行上消失

  怀疑原因：TParagraph.Render 第 290 行 ABuf.SetStyle(Clip, Style)
  可能 Clip 的宽度计算有 off-by-one，覆盖了右边框位置的样式
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
  ContentArea: TRect;
begin
  G := TPanel.Create(
    [LengthConstraint(16), MinConstraint(0)],
    [MinConstraint(0)]
  ).WithBorderSet(BorderSetPlain)
   .WithBorderStyle(TStyle.Default.WithFg(clWhite))
   .Render(Frame.Area, Frame.Buffer);

  ContentArea := PanelCell(G, 1, 0);

  // 这行会导致右边框在对应行消失
  TParagraph.FromString('Hello World' + LineEnding + 'Second line')
    .WithStyle(TStyle.Default.WithFg(clCyan))
    .WithAlignment(caCenter)
    .Render(ContentArea, Frame.Buffer);
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
