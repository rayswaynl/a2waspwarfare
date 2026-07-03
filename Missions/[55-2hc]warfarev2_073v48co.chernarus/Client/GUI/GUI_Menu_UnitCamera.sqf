/*
 Original author: 	Benny?
 Contributors : 	Marty
*/

disableSerialization;
_display = _this select 0;
MenuAction = -1;
mouseButtonUp = -1;
WF_MenuAction = -1; 

_cameraModes = ["Internal","External","Gunner","Group"];

// Marty : Modifying the script in order to display only human player and not bots (= empty slots) in the unit camera list :
private ["_list_Players","_list_AITeams","_count_PlayerTeams"];
_list_Players = [];

_n = 1;
{
	if (isPlayer (leader _x)) then 
	{
		_list_Players = _list_Players + [_x] ;
		lbAdd[21002,Format["[%1] %2",_n,name (leader _x)]];
		_n = _n + 1;
	};
} forEach clientTeams;

//--- Lane 178 AI Teams section: populate _list_AITeams from the live side-logic wfbe_teams
//--- (the same broadcast source the Command Console uses for its roster). Filter: NOT player-led,
//--- at least one alive unit. Camera-switch only, no order paths. No flag - pure client QoL.
//--- HIGH/MODERATE fix (review): capture player-only count before AI rows are appended,
//--- so the zero-team sentinel and initial-row clamp use the correct player-only count.
_count_PlayerTeams = count _list_Players;
_list_AITeams = [];
//--- Prefer the live broadcast wfbe_teams over the frozen boot-snapshot clientTeams (same fix as Command Console).
//--- LOW fix (review): fallback clientTeams scan moved to else branch - only runs when wfbe_teams is unavailable.
if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
	private "_lt178"; _lt178 = WFBE_Client_Logic getVariable "wfbe_teams";
	if (!isNil "_lt178" && {(typeName _lt178) == "ARRAY"}) then {
		_list_AITeams = [];
		{
			private "_aiGrp178b"; _aiGrp178b = _x;
			if (!isNull _aiGrp178b && {!isPlayer (leader _aiGrp178b)} && {({alive _x} count units _aiGrp178b) > 0}) then
			{
				_list_AITeams = _list_AITeams + [_aiGrp178b];
			};
		} forEach _lt178;
	};
} else {
	//--- Fallback: scan clientTeams (boot-time snapshot) when wfbe_teams broadcast not yet received.
	{
		private "_aiGrp178"; _aiGrp178 = _x;
		if (!isNull _aiGrp178 && {!isPlayer (leader _aiGrp178)} && {({alive _x} count units _aiGrp178) > 0}) then
		{
			_list_AITeams = _list_AITeams + [_aiGrp178];
		};
	} forEach clientTeams;
};
//--- Append section header + one row per AI team to listbox 21002 (read-only section below player list).
//--- The header row maps to grpNull in _list_Players so the 101 handler skips it.
if (count _list_AITeams > 0) then {
	lbAdd[21002,"--- AI Teams ---"];
	_list_Players = _list_Players + [grpNull];
	{
		private "_aiG178"; _aiG178 = _x;
		private ["_typeTag178","_alive178","_total178"];
		_typeTag178 = "INF";
		{
			if (!isNull _x && {alive _x}) then {
				private "_veh178"; _veh178 = vehicle _x;
				if (_veh178 != _x) then {
					if (_veh178 isKindOf "Air") exitWith {_typeTag178 = "AIR"};
					if (_veh178 isKindOf "Tank") then {if (_typeTag178 != "AIR") then {_typeTag178 = "HVY"}};
					if ((_veh178 isKindOf "Wheeled_APC") || {_veh178 isKindOf "Car"}) then {if (_typeTag178 == "INF") then {_typeTag178 = "LGHT"}};
				};
			};
		} forEach units _aiG178;
		_alive178 = {alive _x} count units _aiG178;
		_total178 = count units _aiG178;
		lbAdd[21002, Format["[AI] %1 (%2) %3/%4", name (leader _aiG178), _typeTag178, _alive178, _total178]];
		_list_Players = _list_Players + [_aiG178];
	} forEach _list_AITeams;
};

_player_group = group player;
//--- cmdcon41-w3d TAG-CLICK POPUP FIX: the roster listbox (21002) lists ONLY player-led clientTeams (the _list_Players
//--- loop above), but the old start index was `clientTeams find _player_group` - an index into the FULL clientTeams array,
//--- not the filtered player-led list, and -1 when the caller's group is not a player-led clientTeams entry (the war-room
//--- VIEW-TEAM path, or an HC-seated / solo commander). `lbSetCurSel [21002,-1]` then left NO row selected, so the first
//--- Leader-Selection action (MenuAction 101) did `_list_Players select (lbCurSel 21002)` = `select -1` = a "Zero divisor /
//--- index" popup (the reported tag-click error, RPT-silent because it is an engine dialog fault). Resolve the index INTO
//--- _list_Players and clamp to a valid row (0 if the player's own group is not player-led, so a row is always selected).
//--- Flag-gated so it can be disabled if ever needed (default ON).
_id = _list_Players find _player_group;
if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0) then {
	if (_id < 0) then {_id = 0};                                  //--- caller not a player-led team -> default to the first listed player team so a row is always selected
	//--- HIGH fix (review): _list_Players now includes AI rows (grpNull + AI groups); use
	//--- _count_PlayerTeams (captured before AI rows) as the correct player-only empty check.
	if (_count_PlayerTeams == 0) then {
		//--- MODERATE fix (review): no player teams. If AI rows present, clamp _id to index 1
		//--- (first real AI group row, past the grpNull '--- AI Teams ---' header row at index 0).
		if (count _list_Players > 1) then {_id = 1} else {_id = -1};
	};
};
lbSetCurSel[21002,_id];
_currentUnit = (player) Call GetUnitVehicle;
//--- Command Console v2 (claude-gaming 2026-07-01): VIEW TEAM entry. The command console seeds WFBE_CmdCon_CamUnit with a
//--- selected AI team's leader before opening this camera; if it holds a live unit, start the camera on that unit (its
//--- vehicle) instead of the player. One-shot: cleared immediately so a normal camera open (Tactical) is unaffected.
if (!isNil "WFBE_CmdCon_CamUnit") then {
	private "_seedUnit"; _seedUnit = WFBE_CmdCon_CamUnit;
	WFBE_CmdCon_CamUnit = nil;
	if (!isNull _seedUnit && {alive _seedUnit}) then {_currentUnit = (_seedUnit) Call GetUnitVehicle};
};
_currentMode = "Internal";
_currentUnit switchCamera _currentMode;
_units = (Units (group player) - [player]) Call GetLiveUnits;

{
	_unitNumber = (_x) Call GetAIDigit;
	lbAdd[21004,Format["[%1] (%2) %3", _unitNumber, GetText (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "displayName"),name _x]];
} forEach _units;
// Marty end.

_type = if (!(difficultyEnabled "3rdPersonView")) then {["Internal"]} else {["Internal","External","Ironsight","Group"]};
{lbAdd[21006,_x]} forEach _type;
lbSetCurSel[21006,0];

_map = _display displayCtrl 21007;
_map ctrlMapAnimAdd [0,.25,getPos _currentUnit];
ctrlMapAnimCommit _map;

while {true} do {
	sleep 0.1;
	
	_cameraSwap = false;
	if (side group player != sideJoined || !dialog) exitWith {};

	//--- Map click.
	if (mouseButtonUp == 0) then {
		mouseButtonUp = -1;
		_near = _map PosScreenToWorld[mouseX,mouseY];
		_list = _near nearEntities [["Man","Car","Motorcycle","Ship","Tank","Air"],200];
		if (count _list > 0) then {
			_objects = [];
			{if (!(_x isKindOf "Man") && side _x != sideJoined) then {if (count (crew _x) == 0) then {_objects = _objects - [_x]}};if (side _x == sideJoined) then {_objects = _objects + [_x]}} forEach _list;
			if (count _objects > 0) then {
				_currentUnit = ([_near,_objects] Call WFBE_CO_FNC_GetClosestEntity) Call GetUnitVehicle;
				_cameraSwap = true;
			};
		};
	};	
	
	// Marty : Display the units ai owned to a selected player in the menu with their corresponding number, their type (vehicle, infantry...), their name given into the game :
	//--- Leader Selection.
	if (MenuAction == 101) then {
		MenuAction = -1;
		//--- cmdcon41-w3d TAG-CLICK POPUP FIX: guard `_list_Players select (lbCurSel 21002)` against an empty player-team
		//--- list AND a -1 current selection (both threw the "Zero divisor / index" popup). Only index when a valid row is
		//--- selected into a non-empty list; otherwise no-op the swap so the camera stays on its current unit.
		private "_lsSel"; _lsSel = lbCurSel 21002;
		if (count _list_Players > 0 && {_lsSel >= 0} && {_lsSel < (count _list_Players)}) then {
			private "_selGrp178"; _selGrp178 = _list_Players select _lsSel;
			//--- Lane 178: skip grpNull (AI Teams section header) and any null/dead leader.
			if (!isNull _selGrp178 && {alive (leader _selGrp178)}) then {
				_selected = leader _selGrp178;

				_currentUnit = (_selected) Call GetUnitVehicle;
				_units = (Units (group _selected) - [_selected]) Call GetLiveUnits;
				lbClear 21004;
				{
					_unitNumber = (_x) Call GetAIDigit;
					lbAdd[21004,Format["[%1] (%2) %3", _unitNumber, GetText (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "displayName"),name _x]];
				} forEach _units;
				_cameraSwap = true;
			}; //--- Lane 178: end null/grpNull guard
		};
	};
	// Marty end.
	
	//--- Leader commands AIs.
	if (MenuAction == 102) then {
		MenuAction = -1;
		//--- cmdcon41-w3d TAG-CLICK POPUP FIX: same empty-list / -1 guard for the unit sub-list (21004).
		private "_unSel"; _unSel = lbCurSel 21004;
		if (count _units > 0 && {_unSel >= 0} && {_unSel < (count _units)}) then {
			_currentUnit = (_units select _unSel) Call GetUnitVehicle;
			_cameraSwap = true;
		};
	};
	
	//--- Camera Modes
	if (MenuAction == 103) then {
		MenuAction = -1;
		_currentMode = (_cameraModes select (lbCurSel 21006));
		_cameraSwap = true;
	};
	//--- Unflip button clicked
    if (WF_MenuAction == 140 && !(isNil "_currentUnit")) then {
        WF_MenuAction = -1;
        if(!(isNil "_currentUnit")) then {
            if(!(isPlayer (_currentUnit))) then {
                _vehicle = vehicle _currentUnit;            
            
                _vehicle setPos [getPos _vehicle select 0, getPos _vehicle select 1, 0.5];
                _vehicle setVelocity [0,0,-0.5];                
            };            
        };    
        _cameraSwap = true;
    };
	
	if !(alive _currentUnit) then {
		_currentUnit = (player) Call GetUnitVehicle;
		_cameraSwap = true;
	};
	
	//--- Update the Camera.
	if (_cameraSwap) then {
		ctrlMapAnimClear _map;
		_map ctrlMapAnimAdd [1,.25,getPos _currentUnit];
		ctrlMapAnimCommit _map;
		_currentUnit switchCamera _currentMode;
	};
};

closeDialog 0;
((player) Call GetUnitVehicle) switchCamera _currentMode;