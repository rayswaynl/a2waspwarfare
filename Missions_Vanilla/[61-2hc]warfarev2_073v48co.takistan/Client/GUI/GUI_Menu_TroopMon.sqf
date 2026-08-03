disableSerialization;
/*
	TroopMon - filterable own-side troop/group monitor (fable/cmd-troopmon-freelook).

	Cached-array pattern: Client_TroopMonBuildList.sqf rebuilds its row array on a
	WFBE_C_COMMANDER_TROOPMON_REFRESH-second timer (default 2s); repeated dialog opens and every
	filter change inside that window reuse the SAME cached array - no per-open full clientTeams/units
	rescan. Read-only: sends nothing to the server.

	Scope note: distinct from the Spectator v8 lane (never touches Client_Spectator*.sqf) and from the
	war-room roster (GUI_Menu_Command.sqf idc 14661, AI-led teams only) - TroopMon lists EVERY own-side
	group, AI-led and player-led, so the commander can see the whole force at a glance.
*/

if (count _this < 1) exitWith {hint "TroopMon: bad call.";};

private ["_display","_ct2","_types","_rows","_lastHash","_applyFilter","_repaint"];
_display = _this select 0;

//--- defence-in-depth: the ONLY path here is the flag-gated war-room button, but re-check anyway -
//--- a stray/modified client press must never leave the dialog silently open on a non-commander.
_ct2 = commanderTeam;
if (isNil "_ct2" || {isNull _ct2} || {_ct2 != group player}) exitWith {
	hintSilent parseText "<t color='#F8D664'>Only the side commander can use the troop monitor.</t>";
	closeDialog 0;
};

_types = ["ALL","INF","LGHT","HVY","AIR"];
lbClear 33010;
{lbAdd [33010, _x]} forEach _types;
lbSetCurSel [33010, 0];

MenuAction = -1;
_lastHash = "";

_applyFilter = {
	private ["_typeSel","_rowsIn","_out","_typeWant","_row"];
	_typeSel = lbCurSel 33010;
	if (_typeSel < 0) then {_typeSel = 0};
	_typeWant = _types select _typeSel;
	_rowsIn = [false] call WFBE_CL_FNC_TroopMonBuildList;
	_out = [];
	{
		_row = _x;
		if (_typeWant == "ALL" || {(_row select 1) == _typeWant}) then {_out set [count _out, _row]};
	} forEach _rowsIn;
	_out
};

_rows = [] call _applyFilter;

_repaint = {
	private ["_rowsLocal","_hashLocal","_r","_txt","_col","_idx"];
	_rowsLocal = _this select 0;
	_hashLocal = "";
	{_hashLocal = _hashLocal + (str _x) + "#";} forEach _rowsLocal;
	if (_hashLocal != _lastHash) then {
		_lastHash = _hashLocal;
		lbClear 33011;
		{
			_r = _x;
			_txt = Format ["[%1] %2 | %3 | %4/%5 | %6",
				(if (_r select 6) then {"PLR"} else {"AI"}),
				_r select 1, _r select 2, _r select 3, _r select 4, toUpper (_r select 5)];
			_idx = lbAdd [33011, _txt];
			_col = if ((_r select 3) > 0) then {[0.35,0.9,0.45,1]} else {[0.7,0.2,0.2,1]};
			lbSetColor [33011, _idx, _col];
		} forEach _rowsLocal;
		ctrlSetText [33012, Format ["%1 groups shown", count _rowsLocal]];
	};
};
[_rows] call _repaint;

while {alive player && {dialog}} do {
	if (side group player != sideJoined) exitWith {closeDialog 0;};

	//--- BACK -> return to the war room.
	if (MenuAction == 10) exitWith {MenuAction = -1; closeDialog 0; createDialog "RscMenu_Command";};

	//--- REFRESH -> force the cache to rebuild now, ignoring its freshness window.
	if (MenuAction == 11) then {
		MenuAction = -1;
		[true] call WFBE_CL_FNC_TroopMonBuildList;
	};

	//--- VIEW -> open the existing unit camera (RscMenu_UnitCamera) on the selected group's leader -
	//--- the SAME WFBE_CmdCon_CamUnit seed hook the war-room roster's own VIEW TEAM action already uses
	//--- (GUI_Menu_Command.sqf MenuAction 726). No new camera code for this path.
	if (MenuAction == 12) then {
		MenuAction = -1;
		private "_sel"; _sel = lbCurSel 33011;
		if (_sel >= 0 && {_sel < count _rows}) then {
			private "_lg"; _lg = (_rows select _sel) select 0;
			if (!isNull _lg && {alive (leader _lg)}) then {
				WFBE_CmdCon_CamUnit = leader _lg;
				closeDialog 0;
				createDialog "RscMenu_UnitCamera";
			} else {
				hintSilent parseText "<t color='#F8D664'>That group has no live leader to view.</t>";
			};
		} else {
			hintSilent parseText "<t color='#F8D664'>Select a group in the list first.</t>";
		};
	};

	//--- Filter combo re-read every pass - cheap in-memory filter over the cached rows, no rescan.
	_rows = [] call _applyFilter;
	[_rows] call _repaint;
	sleep 0.5;
};
