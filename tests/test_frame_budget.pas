unit test_frame_budget;

{$mode objfpc}{$H+}

interface

procedure RegisterFrameBudgetTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_frame_budget;

procedure Test_CreateDefaults;
var FB: TFrameBudget;
begin
  FB := TFrameBudget.Create(16.0);
  AssertTrue(Abs(FB.BudgetMs - 16.0) < 0.01, 'budget = 16ms');
  AssertTrue(Abs(FB.DegradeAfterMs - 12.8) < 0.01, 'degrade = 80% of budget');
  AssertEqInt(0, FB.Stats.FrameCount, 'no frames yet');
end;

procedure Test_StatsEmpty;
var S: TFrameStats;
begin
  S := TFrameStats.Empty;
  AssertEqInt(0, S.FrameCount, 'frame count = 0');
  AssertTrue(Abs(S.AvgMs) < 0.01, 'avg = 0');
  AssertTrue(Abs(S.OverBudgetPct) < 0.01, 'over budget pct = 0');
end;

procedure Test_BeginEndFrame;
var FB: TFrameBudget;
begin
  FB := TFrameBudget.Create(1000.0);
  FB.BeginFrame;
  FB.EndFrame;
  AssertEqInt(1, FB.Stats.FrameCount, 'one frame recorded');
  AssertTrue(FB.Stats.LastMs >= 0, 'last ms >= 0');
  AssertTrue(FB.Stats.MinMs <= FB.Stats.MaxMs, 'min <= max');
end;

procedure Test_OverBudgetDetection;
var FB: TFrameBudget;
begin
  // Budget of 0ms means any frame (even 0ms measured) won't trigger
  // since GetTickCount64 has ms resolution. Use a negative-like approach:
  // Set budget to -1 equivalent — but budget is Double, so use 0.
  // Actually: with ms resolution, back-to-back is 0ms which is NOT > 0.
  // So we test the logic by manually checking stats after a known state.
  FB := TFrameBudget.Create(16.0);
  FB.BeginFrame;
  FB.EndFrame;
  // Frame took 0ms (instant), so it should NOT be over budget
  AssertEqInt(0, FB.Stats.OverBudgetCount, 'instant frame not over budget');
  // Now simulate: set budget to 0 and any frame > 0 would trigger
  // But we can't guarantee timing. Instead test the Stats math directly.
  FB.Stats.OverBudgetCount := 5;
  FB.Stats.FrameCount := 10;
  AssertTrue(Abs(FB.Stats.OverBudgetPct - 50.0) < 0.01, 'over budget pct = 50%');
end;

procedure Test_DegradeThreshold;
var FB: TFrameBudget;
begin
  // Test the degrade logic: if LastMs > DegradeAfterMs, ShouldDegrade = True
  // With ms resolution, instant frames measure 0ms. Test the flag logic directly.
  FB := TFrameBudget.Create(16.0).WithDegradeThreshold(0.0);
  AssertTrue(not FB.ShouldDegrade, 'not degraded initially');
  // After a frame that takes 0ms with threshold 0: 0 > 0 is false
  // So set threshold to -1 to guarantee trigger
  FB.DegradeAfterMs := -1.0;
  FB.BeginFrame;
  FB.EndFrame;
  // 0ms > -1.0 is true
  AssertTrue(FB.ShouldDegrade, 'should degrade when frame > threshold');
end;

procedure Test_Reset;
var FB: TFrameBudget;
begin
  FB := TFrameBudget.Create(1000.0);
  FB.BeginFrame;
  FB.EndFrame;
  AssertEqInt(1, FB.Stats.FrameCount, 'one frame before reset');
  FB.Reset;
  AssertEqInt(0, FB.Stats.FrameCount, 'zero frames after reset');
  AssertTrue(not FB.ShouldDegrade, 'degrade cleared');
end;

procedure Test_MultipleFrames;
var FB: TFrameBudget; I: Integer;
begin
  FB := TFrameBudget.Create(1000.0);
  for I := 1 to 5 do
  begin
    FB.BeginFrame;
    FB.EndFrame;
  end;
  AssertEqInt(5, FB.Stats.FrameCount, '5 frames');
  AssertTrue(FB.Stats.TotalMs >= 0, 'total >= 0');
end;

procedure Test_AvgMs;
var S: TFrameStats;
begin
  S := TFrameStats.Empty;
  S.FrameCount := 4;
  S.TotalMs := 40.0;
  AssertTrue(Abs(S.AvgMs - 10.0) < 0.01, 'avg = 10ms');
end;

procedure RegisterFrameBudgetTests;
begin
  RegisterTest('frame_budget / create defaults',       @Test_CreateDefaults);
  RegisterTest('frame_budget / stats empty',           @Test_StatsEmpty);
  RegisterTest('frame_budget / begin end frame',       @Test_BeginEndFrame);
  RegisterTest('frame_budget / over budget detection', @Test_OverBudgetDetection);
  RegisterTest('frame_budget / degrade threshold',     @Test_DegradeThreshold);
  RegisterTest('frame_budget / reset',                 @Test_Reset);
  RegisterTest('frame_budget / multiple frames',       @Test_MultipleFrames);
  RegisterTest('frame_budget / avg ms',                @Test_AvgMs);
end;

end.
