unit ftui_loading;

{$mode objfpc}{$H+}{$inline on}
{$modeswitch advancedrecords}

interface

uses
  ftui_task;

type
  TLoadingPhase = (
    lpIdle,
    lpLoading,
    lpSuccess,
    lpError
  );

  TLoadingState = record
    TaskId: TTaskId;
    Phase: TLoadingPhase;
    StartMs: QWord;
    Error: ShortString;
    Data: Pointer;
    DataSize: UInt32;
  end;

  TLoadingGroup = record
    Items: array[0..15] of TLoadingState;
    Count: Integer;

    class function Empty: TLoadingGroup; static;
    procedure Start(Index: Integer; ATaskId: TTaskId; NowMs: QWord);
    procedure Update(const Slots: array of TCompletionSlot;
                     SlotCount: Integer);
    function AllDone: Boolean;
    function AnyLoading: Boolean;
    function AnyError: Boolean;
    function GetPhase(Index: Integer): TLoadingPhase; inline;
  end;

implementation

class function TLoadingGroup.Empty: TLoadingGroup;
var
  I: Integer;
begin
  Result.Count := 0;
  for I := 0 to High(Result.Items) do
  begin
    Result.Items[I].TaskId := 0;
    Result.Items[I].Phase := lpIdle;
    Result.Items[I].StartMs := 0;
    Result.Items[I].Error := '';
    Result.Items[I].Data := nil;
    Result.Items[I].DataSize := 0;
  end;
end;

procedure TLoadingGroup.Start(Index: Integer; ATaskId: TTaskId; NowMs: QWord);
begin
  if (Index < 0) or (Index > High(Items)) then Exit;
  Items[Index].TaskId := ATaskId;
  Items[Index].Phase := lpLoading;
  Items[Index].StartMs := NowMs;
  Items[Index].Error := '';
  Items[Index].Data := nil;
  Items[Index].DataSize := 0;
  if Index >= Count then
    Count := Index + 1;
end;

procedure TLoadingGroup.Update(const Slots: array of TCompletionSlot;
                               SlotCount: Integer);
var
  I, J: Integer;
begin
  for I := 0 to SlotCount - 1 do
  begin
    for J := 0 to Count - 1 do
    begin
      if (Items[J].Phase = lpLoading) and (Items[J].TaskId = Slots[I].Id) then
      begin
        case Slots[I].Result.Status of
          tsCompleted: begin
            Items[J].Phase := lpSuccess;
            Items[J].Data := Slots[I].Result.Data;
            Items[J].DataSize := Slots[I].Result.DataSize;
          end;
          tsFailed: begin
            Items[J].Phase := lpError;
            Items[J].Error := Slots[I].Result.Error;
          end;
          tsCancelled: begin
            Items[J].Phase := lpIdle;
          end;
        end;
        Break;
      end;
    end;
  end;
end;

function TLoadingGroup.AllDone: Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Phase = lpLoading then
      Exit(False);
  Result := True;
end;

function TLoadingGroup.AnyLoading: Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Phase = lpLoading then
      Exit(True);
  Result := False;
end;

function TLoadingGroup.AnyError: Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Phase = lpError then
      Exit(True);
  Result := False;
end;

function TLoadingGroup.GetPhase(Index: Integer): TLoadingPhase;
begin
  if (Index < 0) or (Index >= Count) then
    Result := lpIdle
  else
    Result := Items[Index].Phase;
end;

end.
