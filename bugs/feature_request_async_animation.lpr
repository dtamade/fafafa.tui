program feature_request_async_animation;
{$mode objfpc}{$H+}
{
  Feature Request: TApp 框架级异步任务 + 动画支持

  背景：
  music888 在实现 loading 动画时发现，高帧率渲染、spinner 动画、异步任务管理
  这些是每个 TUI 应用都需要的通用能力，不应该每个应用自己实现。

  当前 music888 的做法（workaround）：
  - 手动管理 PollEvent(33) 实现 30fps
  - 手动 FLoadingTick 计数器驱动 spinner 动画
  - 手动创建 TThread + Done 标志 + 主循环 poll
  - 每个需要异步加载的地方都重复这套模式

  ═══════════════════════════════════════════════════════════════════════

  需求 1: 内置 Spinner/Loading 组件

  期望 API:
    TSpinner.Create(SpinnerBraille)  // 或 SpinnerDots, SpinnerLine 等预设
      .WithStyle(TStyle.Default.WithFg(clCyan))
      .Render(Area, Buf);            // 自动根据当前时间选择帧

  框架自动管理动画帧——应用只需要每帧调用 Render，组件内部根据
  时间戳（GetTickCount64）自动选择当前帧，不需要应用维护计数器。

  ═══════════════════════════════════════════════════════════════════════

  需求 2: TApp 异步任务调度

  期望 API:
    // 提交异步任务
    App.RunAsync(
      @DoNetworkRequest,     // 在后台线程执行
      @OnRequestComplete     // 完成后在主线程回调
    );

  或者更简单的模式（类似 JavaScript Promise）:
    FTask := TAsyncTask.Create(@DoNetworkRequest);
    FTask.Start;

    // 在 OnTick 中:
    if FTask.Done then
    begin
      ApplyResult(FTask.Result);
      FTask.Free;
      FTask := nil;
    end;

  框架提供 TAsyncTask 基类，自动处理：
  - 线程创建和生命周期管理
  - Done 标志的内存安全
  - 取消支持（Terminate + 超时）
  - 错误传播

  ═══════════════════════════════════════════════════════════════════════

  需求 3: 自适应帧率

  当前 TApp.TickInterval 是固定的。期望：
  - 无动画时低帧率（省 CPU）：100-200ms
  - 有活跃动画时自动提高帧率：16-33ms
  - 动画结束后自动降回低帧率

  期望 API:
    App.RequestAnimationFrame;  // 标记当前有动画需要高帧率
    // 或者
    App.SetAnimating(True/False);

  框架内部根据是否有活跃动画自动调整 PollEvent 超时。

  ═══════════════════════════════════════════════════════════════════════

  需求 4: 内置 Loading 状态管理

  很多 TUI 应用有这个模式：
  - 用户触发操作 → 显示 loading → 异步执行 → 完成后更新 UI

  期望框架提供一个 TLoadingOverlay 或 TLoadingState：
    FLoading := TLoadingState.Create('加载歌单...');
    FLoading.Start(@DoLoad, @OnDone);
    // 自动在指定区域显示 spinner + 文字
    // 完成后自动清除

  ═══════════════════════════════════════════════════════════════════════

  优先级建议：
  1. 需求 1（Spinner 组件）— 最简单，独立，立即可用
  2. 需求 3（自适应帧率）— 对所有动画都有益
  3. 需求 2（异步任务）— 最有价值但设计复杂度高
  4. 需求 4（Loading 状态）— 建立在 1+2+3 之上的高层封装

  参考：
  - Rust ratatui: Frame::render_widget(Spinner)
  - Go bubbletea: tea.Cmd (异步命令模式)
  - Python textual: Worker (后台任务 + UI 更新)
}
end.
