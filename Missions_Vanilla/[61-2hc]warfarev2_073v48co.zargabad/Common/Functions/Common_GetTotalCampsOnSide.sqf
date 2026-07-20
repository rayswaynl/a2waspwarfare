/*
	Get all of the camp which belong to the x side from a town.
	 Parameters:
		- Town.
		- Side.
*/

Private ["_camps","_side","_sideID","_total","_town"];

_town = _this select 0;
_side = _this select 1;

_sideID = _side Call WFBE_CO_FNC_GetSideID;

_camps = _town getVariable "camps";
//--- cmdcon44-d (claude-gaming 2026-07-03): nil-safe (see Common_GetTotalCamps note). `count nil` throws; treat an
//--- unset "camps" as no-camps (1), matching the empty-list branch, so the capture-rate division never blows up.
if (isNil "_camps") exitWith {1};
if (count _camps == 0) exitWith {1};

//--- fable/camp-null-count (2026-07-19): when EVERY camp logic in the list has been deleted, the
//--- town must behave exactly like a no-camp town (both functions return 1 -> Total == OnSide ->
//--- capturable), not deadlock at Total=1/OnSide=0. Same !isNull semantics as the side tally below
//--- and as GetTotalCamps' live count.
Private ["_live"];
_live = 0;
{if (!isNull _x) then {_live = _live + 1}} forEach _camps;
if (_live == 0) exitWith {1};

_total = 0;

{if (!isNull _x && {(_x getVariable ["sideID",-1]) == _sideID}) then {_total = _total + 1}} forEach _camps;

_total