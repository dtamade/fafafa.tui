program spinner_demo;

{$mode objfpc}{$H+}

uses
  ftui_app,
  ftui_anim,
  ftui_event,
  ftui_terminal,
  ftui_rect,
  ftui_buffer,
  ftui_style,
  ftui_color,
  ftui_block,
  ftui_borders;

type
  TSpinnerApp = class(TApp)
  private
    FSpinners: array[0..4] of TSpinner;
    FNames: array[0..4] of AnsiString;
  protected
    procedure OnInit; override;
    procedure Render(var Frame: TFrame); override;
    procedure OnTick; override;
  end;

procedure TSpinnerApp.OnInit;
begin
  FSpinners[0] := TSpinner.Create(skDots);
  FSpinners[1] := TSpinner.Create(skLine);
  FSpinners[2] := TSpinner.Create(skBraille);
  FSpinners[3] := TSpinner.Create(skArrow);
  FSpinners[4] := TSpinner.Custom(['.  ', '.. ', '...', ' ..', '  .', '   '], 200);
  FNames[0] := 'Dots   ';
  FNames[1] := 'Line   ';
  FNames[2] := 'Braille';
  FNames[3] := 'Arrow  ';
  FNames[4] := 'Custom ';
end;

procedure TSpinnerApp.Render(var Frame: TFrame);
var
  Area: TRect;
  Blk: TBlock;
  Inner: TRect;
  I: Integer;
  Ms: QWord;
  S: AnsiString;
  St: TStyle;
begin
  RequestAnimationFrame;
  Area := Frame.Buffer.Area;
  Blk := TBlock.Default
    .WithTitle(' Spinner Demo (Ctrl+Q to quit) ')
    .WithBorders(BordersAll);
  Blk.Render(Area, Frame.Buffer);
  Inner := Blk.Inner(Area);

  Ms := ElapsedMs;
  St := TStyle.Default.WithFg(RgbColor(100, 200, 255));

  for I := 0 to 4 do
  begin
    if Inner.Y + I >= Inner.Y + Inner.Height then Break;
    S := FNames[I] + '  ' + FSpinners[I].FrameAt(Ms) + '  Loading...';
    Frame.Buffer.SetStringN(Inner.X + 1, Inner.Y + I, S, Inner.Width - 2, St);
  end;
end;

procedure TSpinnerApp.OnTick;
begin
  // nothing — rendering is time-based via FrameAt
end;

var
  App: TSpinnerApp;
begin
  App := TSpinnerApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
