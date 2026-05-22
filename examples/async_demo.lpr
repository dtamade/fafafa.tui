program async_demo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  ftui_app,
  ftui_task,
  ftui_loading,
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
  PFetchResult = ^TFetchResult;
  TFetchResult = record
    Items: array[0..4] of ShortString;
    Count: Integer;
  end;

function SimulateNetworkFetch(const Ctx: TTaskContext): TTaskResult;
var
  P: PFetchResult;
  I: Integer;
begin
  for I := 0 to 19 do
  begin
    if IsCancelled(Ctx) then
    begin
      Result.Status := tsCancelled;
      Result.Data := nil;
      Result.DataSize := 0;
      Result.Error := '';
      Exit;
    end;
    Sleep(100);
  end;
  New(P);
  P^.Count := 5;
  P^.Items[0] := 'Song A - Artist 1';
  P^.Items[1] := 'Song B - Artist 2';
  P^.Items[2] := 'Song C - Artist 3';
  P^.Items[3] := 'Song D - Artist 4';
  P^.Items[4] := 'Song E - Artist 5';
  Result.Data := P;
  Result.DataSize := SizeOf(TFetchResult);
  Result.Error := '';
  Result.Status := tsCompleted;
end;

type
  TAsyncApp = class(TApp)
  private
    FSpinner: TSpinner;
    FLoading: TLoadingGroup;
    FPlaylist: PFetchResult;
    FSlots: array[0..31] of TCompletionSlot;
  protected
    procedure OnInit; override;
    procedure OnTick; override;
    procedure Render(var Frame: TFrame); override;
    procedure HandleEvent(const Ev: TEvent); override;
    procedure OnDestroy; override;
  end;

procedure TAsyncApp.OnInit;
var
  Spec: TTaskSpec;
  Id: TTaskId;
begin
  FSpinner := TSpinner.Create(skBraille);
  FLoading := TLoadingGroup.Empty;
  FPlaylist := nil;
  Spec := MakeSpec(@SimulateNetworkFetch, nil, 0, 'fetch');
  Id := Tasks.Spawn(Spec);
  FLoading.Start(0, Id, ElapsedMs);
end;

procedure TAsyncApp.OnTick;
var
  N: Integer;
begin
  N := Tasks.DrainCompleted(FSlots, 32);
  if N > 0 then
    FLoading.Update(FSlots, N);
  if (FLoading.GetPhase(0) = lpSuccess) and (FPlaylist = nil) then
    FPlaylist := PFetchResult(FLoading.Items[0].Data);
end;

procedure TAsyncApp.Render(var Frame: TFrame);
var
  Area, Inner: TRect;
  Blk: TBlock;
  I: Integer;
  St: TStyle;
begin
  if FLoading.AnyLoading then
    RequestAnimationFrame;

  Area := Frame.Buffer.Area;
  Blk := TBlock.Default
    .WithTitle(' Async Demo (Ctrl+Q quit, r=reload) ')
    .WithBorders(BordersAll);
  Blk.Render(Area, Frame.Buffer);
  Inner := Blk.Inner(Area);

  case FLoading.GetPhase(0) of
    lpLoading: begin
      St := TStyle.Default.WithFg(RgbColor(100, 200, 255));
      Frame.Buffer.SetStringN(Inner.X + 1, Inner.Y,
        FSpinner.FrameAt(ElapsedMs) + '  Loading playlist...',
        Inner.Width - 2, St);
    end;
    lpSuccess: begin
      if FPlaylist <> nil then
      begin
        St := TStyle.Default.WithFg(RgbColor(100, 255, 100));
        Frame.Buffer.SetStringN(Inner.X + 1, Inner.Y,
          'Playlist loaded:', Inner.Width - 2, St);
        St := TStyle.Default;
        for I := 0 to FPlaylist^.Count - 1 do
        begin
          if Inner.Y + 1 + I >= Inner.Y + Inner.Height then Break;
          Frame.Buffer.SetStringN(Inner.X + 2, Inner.Y + 1 + I,
            '  ' + FPlaylist^.Items[I], Inner.Width - 3, St);
        end;
      end;
    end;
    lpError: begin
      St := TStyle.Default.WithFg(RgbColor(255, 80, 80));
      Frame.Buffer.SetStringN(Inner.X + 1, Inner.Y,
        'Error: ' + FLoading.Items[0].Error, Inner.Width - 2, St);
    end;
  end;
end;

procedure TAsyncApp.HandleEvent(const Ev: TEvent);
var
  Spec: TTaskSpec;
  Id: TTaskId;
begin
  if (Ev.Kind = evKey) and (Ev.Key.Code = kcChar) and
     (Ev.Key.Ch = Ord('r')) then
  begin
    if FPlaylist <> nil then
    begin
      Dispose(FPlaylist);
      FPlaylist := nil;
    end;
    FLoading := TLoadingGroup.Empty;
    Spec := MakeSpec(@SimulateNetworkFetch, nil, 0, 'fetch');
    Id := Tasks.Spawn(Spec);
    FLoading.Start(0, Id, ElapsedMs);
  end;
end;

procedure TAsyncApp.OnDestroy;
begin
  if FPlaylist <> nil then
  begin
    Dispose(FPlaylist);
    FPlaylist := nil;
  end;
end;

var
  App: TAsyncApp;
begin
  App := TAsyncApp.Create;
  try
    App.Run;
  finally
    App.Free;
  end;
end.
