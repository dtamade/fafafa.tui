program quickstart;

{$mode objfpc}{$H+}

uses
  ftui_app,
  ftui_event,
  ftui_terminal,
  ftui_rect,
  ftui_style,
  ftui_modifier,
  ftui_buffer,
  ftui_block,
  ftui_borders,
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
  TParagraph.FromString('Counter: ' + S + #10#10 + 'Space = increment, q = quit')
    .WithBlock(TBlock.Default.WithBorders(BordersAll).WithTitle(' quickstart '))
    .WithStyle(TStyle.Default)
    .Render(Frame.Area, Frame.Buffer);
end;

procedure TMyApp.HandleEvent(const Ev: TEvent);
begin
  if Ev.Kind <> evKey then Exit;
  case Ev.Key.Code of
    kcChar:
      case Ev.Key.Ch of
        Ord(' '): Inc(FCounter);
        Ord('q'): Quit;
      end;
  end;
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
