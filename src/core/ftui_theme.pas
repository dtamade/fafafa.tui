unit ftui_theme;

// Lightweight theme system providing named style slots for consistent
// UI appearance.  Each TTheme is a plain record of TStyle values —
// no heap, no inheritance, no registry.  Consumers pick a preset
// (Dark/Light/Nord/Dracula) or build their own by value.

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

uses
  ftui_color, ftui_modifier, ftui_style;

type
  TTheme = record
    // Base styles
    Bg: TStyle;
    Fg: TStyle;
    // Widget styles
    Border: TStyle;
    BorderFocused: TStyle;
    Title: TStyle;
    Highlight: TStyle;
    // Semantic styles
    Primary: TStyle;
    Secondary: TStyle;
    Success: TStyle;
    Warning: TStyle;
    Error_: TStyle;
    Muted: TStyle;
    // Component-specific
    Header: TStyle;
    StatusBar: TStyle;
    Button: TStyle;
    ButtonActive: TStyle;

    class function Dark: TTheme; static;
    class function Light: TTheme; static;
    class function Nord: TTheme; static;
    class function Dracula: TTheme; static;
  end;

implementation

class function TTheme.Dark: TTheme;
begin
  Result.Bg            := TStyle.Default.WithBg(clBlack);
  Result.Fg            := TStyle.Default.WithFg(clWhite);
  Result.Border        := TStyle.Default.WithFg(clCyan);
  Result.BorderFocused := TStyle.Default.WithFg(clLightCyan).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(clWhite).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(clBlack).WithBg(clBlue);
  Result.Primary       := TStyle.Default.WithFg(clBlue);
  Result.Secondary     := TStyle.Default.WithFg(clGray);
  Result.Success       := TStyle.Default.WithFg(clGreen);
  Result.Warning       := TStyle.Default.WithFg(clYellow);
  Result.Error_        := TStyle.Default.WithFg(clRed);
  Result.Muted         := TStyle.Default.WithFg(clDarkGray);
  Result.Header        := TStyle.Default.WithFg(clWhite).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(clWhite).WithBg(clDarkGray);
  Result.Button        := TStyle.Default.WithFg(clWhite).WithBg(clBlue);
  Result.ButtonActive  := TStyle.Default.WithFg(clBlack).WithBg(clLightBlue);
end;

class function TTheme.Light: TTheme;
begin
  Result.Bg            := TStyle.Default.WithBg(clWhite);
  Result.Fg            := TStyle.Default.WithFg(clBlack);
  Result.Border        := TStyle.Default.WithFg(clDarkGray);
  Result.BorderFocused := TStyle.Default.WithFg(clBlack).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(clBlack).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(clWhite).WithBg(clBlue);
  Result.Primary       := TStyle.Default.WithFg(clBlue);
  Result.Secondary     := TStyle.Default.WithFg(clDarkGray);
  Result.Success       := TStyle.Default.WithFg(clGreen);
  Result.Warning       := TStyle.Default.WithFg(clYellow);
  Result.Error_        := TStyle.Default.WithFg(clRed);
  Result.Muted         := TStyle.Default.WithFg(clGray);
  Result.Header        := TStyle.Default.WithFg(clBlack).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(clBlack).WithBg(clGray);
  Result.Button        := TStyle.Default.WithFg(clWhite).WithBg(clBlue);
  Result.ButtonActive  := TStyle.Default.WithFg(clWhite).WithBg(clLightBlue);
end;

class function TTheme.Nord: TTheme;
begin
  // Nord palette
  Result.Bg            := TStyle.Default.WithBg(RgbColor(46, 52, 64));
  Result.Fg            := TStyle.Default.WithFg(RgbColor(236, 239, 244));
  Result.Border        := TStyle.Default.WithFg(RgbColor(76, 86, 106));
  Result.BorderFocused := TStyle.Default.WithFg(RgbColor(136, 192, 208)).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(RgbColor(236, 239, 244)).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(RgbColor(46, 52, 64)).WithBg(RgbColor(136, 192, 208));
  Result.Primary       := TStyle.Default.WithFg(RgbColor(136, 192, 208));
  Result.Secondary     := TStyle.Default.WithFg(RgbColor(129, 161, 193));
  Result.Success       := TStyle.Default.WithFg(RgbColor(163, 190, 140));
  Result.Warning       := TStyle.Default.WithFg(RgbColor(235, 203, 139));
  Result.Error_        := TStyle.Default.WithFg(RgbColor(191, 97, 106));
  Result.Muted         := TStyle.Default.WithFg(RgbColor(76, 86, 106));
  Result.Header        := TStyle.Default.WithFg(RgbColor(236, 239, 244)).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(RgbColor(236, 239, 244)).WithBg(RgbColor(59, 66, 82));
  Result.Button        := TStyle.Default.WithFg(RgbColor(46, 52, 64)).WithBg(RgbColor(136, 192, 208));
  Result.ButtonActive  := TStyle.Default.WithFg(RgbColor(46, 52, 64)).WithBg(RgbColor(129, 161, 193));
end;

class function TTheme.Dracula: TTheme;
begin
  // Dracula palette
  Result.Bg            := TStyle.Default.WithBg(RgbColor(40, 42, 54));
  Result.Fg            := TStyle.Default.WithFg(RgbColor(248, 248, 242));
  Result.Border        := TStyle.Default.WithFg(RgbColor(98, 114, 164));
  Result.BorderFocused := TStyle.Default.WithFg(RgbColor(189, 147, 249)).WithModifier([mbBold]);
  Result.Title         := TStyle.Default.WithFg(RgbColor(248, 248, 242)).WithModifier([mbBold]);
  Result.Highlight     := TStyle.Default.WithFg(RgbColor(40, 42, 54)).WithBg(RgbColor(189, 147, 249));
  Result.Primary       := TStyle.Default.WithFg(RgbColor(189, 147, 249));
  Result.Secondary     := TStyle.Default.WithFg(RgbColor(139, 233, 253));
  Result.Success       := TStyle.Default.WithFg(RgbColor(80, 250, 123));
  Result.Warning       := TStyle.Default.WithFg(RgbColor(241, 250, 140));
  Result.Error_        := TStyle.Default.WithFg(RgbColor(255, 85, 85));
  Result.Muted         := TStyle.Default.WithFg(RgbColor(98, 114, 164));
  Result.Header        := TStyle.Default.WithFg(RgbColor(248, 248, 242)).WithModifier([mbBold]);
  Result.StatusBar     := TStyle.Default.WithFg(RgbColor(248, 248, 242)).WithBg(RgbColor(68, 71, 90));
  Result.Button        := TStyle.Default.WithFg(RgbColor(40, 42, 54)).WithBg(RgbColor(189, 147, 249));
  Result.ButtonActive  := TStyle.Default.WithFg(RgbColor(40, 42, 54)).WithBg(RgbColor(139, 233, 253));
end;

end.
