unit test_keybind;

{$mode objfpc}{$H+}

interface

procedure RegisterKeybindTests;

implementation

uses
  SysUtils,
  ftui_testkit,
  ftui_event,
  ftui_keybind;

var
  ActionCalled: Boolean;

procedure TestAction;
begin
  ActionCalled := True;
end;

procedure Test_CreateManager;
var KM: TKeybindManager;
begin
  KM := TKeybindManager.Create;
  AssertEqInt(0, KM.BindingCount, 'no bindings');
  AssertTrue(KM.Mode = kmNormal, 'default normal');
  KM.Free;
end;

procedure Test_BindAndHandle;
var
  KM: TKeybindManager;
  K: TKeyEvent;
begin
  KM := TKeybindManager.Create;
  KM.BindChar(kmNormal, 'q', @TestAction, 'Quit');
  ActionCalled := False;
  K.Code := kcChar;
  K.Ch := Ord('q');
  AssertTrue(KM.HandleKey(K), 'handled');
  AssertTrue(ActionCalled, 'action called');
  KM.Free;
end;

procedure Test_ModeFiltering;
var
  KM: TKeybindManager;
  K: TKeyEvent;
begin
  KM := TKeybindManager.Create;
  KM.BindChar(kmInsert, 'a', @TestAction, 'Insert a');
  ActionCalled := False;
  K.Code := kcChar;
  K.Ch := Ord('a');
  // In normal mode, should not trigger
  AssertTrue(not KM.HandleKey(K), 'not handled in normal');
  AssertTrue(not ActionCalled, 'not called');
  // Switch to insert
  KM.SetMode(kmInsert);
  AssertTrue(KM.HandleKey(K), 'handled in insert');
  AssertTrue(ActionCalled, 'called in insert');
  KM.Free;
end;

procedure Test_BindKey;
var
  KM: TKeybindManager;
  K: TKeyEvent;
begin
  KM := TKeybindManager.Create;
  KM.BindKey(kmNormal, kcUp, @TestAction, 'Move up');
  ActionCalled := False;
  K.Code := kcUp;
  K.Ch := 0;
  AssertTrue(KM.HandleKey(K), 'up handled');
  AssertTrue(ActionCalled, 'up action called');
  KM.Free;
end;

procedure Test_UnhandledKey;
var
  KM: TKeybindManager;
  K: TKeyEvent;
begin
  KM := TKeybindManager.Create;
  KM.BindChar(kmNormal, 'q', @TestAction, 'Quit');
  K.Code := kcChar;
  K.Ch := Ord('x');
  AssertTrue(not KM.HandleKey(K), 'x not handled');
  KM.Free;
end;

procedure Test_HelpText;
var
  KM: TKeybindManager;
  Help: AnsiString;
begin
  KM := TKeybindManager.Create;
  KM.BindChar(kmNormal, 'q', @TestAction, 'Quit app');
  KM.BindKey(kmNormal, kcUp, @TestAction, 'Move up');
  Help := KM.HelpText;
  AssertTrue(Pos('Quit app', Help) > 0, 'help has quit');
  AssertTrue(Pos('Move up', Help) > 0, 'help has move up');
  KM.Free;
end;

procedure Test_MultipleBindings;
var
  KM: TKeybindManager;
begin
  KM := TKeybindManager.Create;
  KM.BindChar(kmNormal, 'a', @TestAction, 'A');
  KM.BindChar(kmNormal, 'b', @TestAction, 'B');
  KM.BindChar(kmInsert, 'c', @TestAction, 'C');
  AssertEqInt(3, KM.BindingCount, '3 bindings');
  KM.Free;
end;

procedure RegisterKeybindTests;
begin
  RegisterTest('keybind / create manager',    @Test_CreateManager);
  RegisterTest('keybind / bind and handle',   @Test_BindAndHandle);
  RegisterTest('keybind / mode filtering',    @Test_ModeFiltering);
  RegisterTest('keybind / bind key',          @Test_BindKey);
  RegisterTest('keybind / unhandled key',     @Test_UnhandledKey);
  RegisterTest('keybind / help text',         @Test_HelpText);
  RegisterTest('keybind / multiple bindings', @Test_MultipleBindings);
end;

end.
