unit test_anim;

{$mode objfpc}{$H+}

interface

procedure RegisterAnimTests;

implementation

uses
  ftui_testkit,
  ftui_anim;

procedure Test_EaseLinearEndpoints;
begin
  AssertTrue(Abs(EaseLinear(0.0)) < 0.001, 'EaseLinear(0) = 0');
  AssertTrue(Abs(EaseLinear(1.0) - 1.0) < 0.001, 'EaseLinear(1) = 1');
  AssertTrue(Abs(EaseLinear(0.5) - 0.5) < 0.001, 'EaseLinear(0.5) = 0.5');
end;

procedure Test_EaseInQuadEndpoints;
begin
  AssertTrue(Abs(EaseInQuad(0.0)) < 0.001, 'EaseInQuad(0) = 0');
  AssertTrue(Abs(EaseInQuad(1.0) - 1.0) < 0.001, 'EaseInQuad(1) = 1');
  AssertTrue(EaseInQuad(0.5) < 0.5, 'EaseInQuad(0.5) < 0.5 (accelerating)');
end;

procedure Test_EaseOutQuadDeceleration;
begin
  AssertTrue(Abs(EaseOutQuad(0.0)) < 0.001, 'EaseOutQuad(0) = 0');
  AssertTrue(Abs(EaseOutQuad(1.0) - 1.0) < 0.001, 'EaseOutQuad(1) = 1');
  AssertTrue(EaseOutQuad(0.5) > 0.5, 'EaseOutQuad(0.5) > 0.5 (decelerating)');
end;

procedure Test_EaseInOutQuadSymmetry;
begin
  AssertTrue(Abs(EaseInOutQuad(0.5) - 0.5) < 0.001, 'EaseInOutQuad(0.5) = 0.5');
  AssertTrue(Abs(EaseInOutQuad(0.0)) < 0.001, 'EaseInOutQuad(0) = 0');
  AssertTrue(Abs(EaseInOutQuad(1.0) - 1.0) < 0.001, 'EaseInOutQuad(1) = 1');
end;

procedure Test_EaseBounceEndpoint;
begin
  AssertTrue(Abs(EaseBounce(0.0)) < 0.001, 'EaseBounce(0) = 0');
  AssertTrue(Abs(EaseBounce(1.0) - 1.0) < 0.001, 'EaseBounce(1) = 1');
end;

procedure Test_LerpInteger;
begin
  AssertEqInt(50, Lerp(0, 100, 0.5), 'Lerp(0,100,0.5) = 50');
  AssertEqInt(0, Lerp(0, 100, 0.0), 'Lerp(0,100,0) = 0');
  AssertEqInt(100, Lerp(0, 100, 1.0), 'Lerp(0,100,1) = 100');
end;

procedure Test_LerpFloat;
begin
  AssertTrue(Abs(LerpF(0.0, 1.0, 0.25) - 0.25) < 0.001, 'LerpF(0,1,0.25) = 0.25');
  AssertTrue(Abs(LerpF(10.0, 20.0, 0.5) - 15.0) < 0.001, 'LerpF(10,20,0.5) = 15');
end;

procedure Test_SpinnerFrameCycles;
var
  S: TSpinner;
begin
  S := TSpinner.Create(skDots);
  AssertEqStr(S.Frames[0], S.Frame(0), 'Frame(0) = first');
  AssertEqStr(S.Frames[1], S.Frame(1), 'Frame(1) = second');
  AssertEqStr(S.Frames[0], S.Frame(10), 'Frame(10) wraps to first');
  AssertEqStr(S.Frames[3], S.Frame(13), 'Frame(13) wraps to fourth');
end;

procedure Test_SpinnerLineHas4Frames;
var
  S: TSpinner;
begin
  S := TSpinner.Create(skLine);
  AssertEqInt(4, Length(S.Frames), 'skLine has 4 frames');
  AssertEqStr('|', S.Frame(0), 'skLine frame 0');
  AssertEqStr('\', S.Frame(3), 'skLine frame 3');
end;

procedure Test_TransitionStartsAtStartVal;
var
  Tr: TTransition;
begin
  Tr := TTransition.Create(10.0, 90.0, 1000);
  AssertTrue(Abs(Tr.Value - 10.0) < 0.001, 'Transition starts at StartVal');
  AssertFalse(Tr.Done, 'Not done at start');
end;

procedure Test_TransitionEndsAtEndVal;
var
  Tr: TTransition;
begin
  Tr := TTransition.Create(10.0, 90.0, 1000);
  Tr.Advance(1000);
  AssertTrue(Abs(Tr.Value - 90.0) < 0.001, 'Transition ends at EndVal');
  AssertTrue(Tr.Done, 'Done after full duration');
end;

procedure Test_TransitionAdvanceWorks;
var
  Tr: TTransition;
begin
  Tr := TTransition.Create(0.0, 100.0, 1000);
  Tr.Advance(500);
  AssertTrue(Abs(Tr.Value - 50.0) < 0.001, 'Halfway value with linear easing');
  AssertFalse(Tr.Done, 'Not done at halfway');
  Tr.Advance(500);
  AssertTrue(Abs(Tr.Value - 100.0) < 0.001, 'Full value after complete');
  AssertTrue(Tr.Done, 'Done after full advance');
end;

procedure Test_TransitionWithEasingAppliesCurve;
var
  Tr: TTransition;
  V: Double;
begin
  Tr := TTransition.Create(0.0, 100.0, 1000).WithEasing(@EaseInQuad);
  Tr.Advance(500);
  V := Tr.Value;
  AssertTrue(V < 50.0, 'EaseInQuad at halfway < 50 (accelerating)');
  AssertTrue(V > 0.0, 'EaseInQuad at halfway > 0');
end;

procedure Test_TransitionReset;
var
  Tr: TTransition;
begin
  Tr := TTransition.Create(0.0, 100.0, 1000);
  Tr.Advance(800);
  Tr.Reset;
  AssertTrue(Abs(Tr.Value - 0.0) < 0.001, 'After reset, value is StartVal');
  AssertFalse(Tr.Done, 'After reset, not done');
end;

procedure RegisterAnimTests;
begin
  RegisterTest('anim / EaseLinear endpoints',          @Test_EaseLinearEndpoints);
  RegisterTest('anim / EaseInQuad endpoints',          @Test_EaseInQuadEndpoints);
  RegisterTest('anim / EaseOutQuad deceleration',      @Test_EaseOutQuadDeceleration);
  RegisterTest('anim / EaseInOutQuad symmetry',        @Test_EaseInOutQuadSymmetry);
  RegisterTest('anim / EaseBounce endpoint',           @Test_EaseBounceEndpoint);
  RegisterTest('anim / Lerp integer',                  @Test_LerpInteger);
  RegisterTest('anim / LerpF float',                   @Test_LerpFloat);
  RegisterTest('anim / Spinner frame cycles',          @Test_SpinnerFrameCycles);
  RegisterTest('anim / Spinner skLine has 4 frames',   @Test_SpinnerLineHas4Frames);
  RegisterTest('anim / Transition starts at StartVal', @Test_TransitionStartsAtStartVal);
  RegisterTest('anim / Transition ends at EndVal',     @Test_TransitionEndsAtEndVal);
  RegisterTest('anim / Transition advance works',      @Test_TransitionAdvanceWorks);
  RegisterTest('anim / Transition with easing curve',  @Test_TransitionWithEasingAppliesCurve);
  RegisterTest('anim / Transition reset',              @Test_TransitionReset);
end;

end.
