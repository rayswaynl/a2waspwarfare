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
private ["_list_Players","_unitCameraAITeams","_srcTeams","_aiTeams","_aiN"];
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

_unitCameraAITeams = (missionNamespace getVariable ["WFBE_C_UNIT_CAMERA_AI_TEAMS", 0]) > 0;
if (_unitCameraAITeams) then {
	_srcTeams = clientTeams;
	if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
		private "_lt"; _lt = WFBE_Client_Logic getVariable "wfbe_teams";
		if (!isNil "_lt" && {(typeName _lt) == "ARRAY"}) then {_srcTeams = _lt};
	};
	_aiTeams = [];
	{
		private "_grp"; _grp = _x;
		if (!isNull _grp && {!isPlayer (leader _grp)}) then {
			private "_alive"; _alive = {alive _x} count units _grp;
			if (_alive > 0) then {_aiTeams = _aiTeams + [_grp]};
		};
	} forEach _srcTeams;
	if (count _aiTeams > 0) then {
		_list_Players = _list_Players + [grpNull];
		lbAdd[21002,"--- AI Teams ---"];
		_aiN = 1;
		{
			private "_grp"; _grp = _x;
			private "_alive"; _alive = {alive _x} count units _grp;
			if (_alive > 0) then {
				_list_Players = _list_Players + [_grp];
				lbAdd[21002,Format["[AI %1] %2 (%3)",_aiN,name (leader _grp),_alive]];
				_aiN = _aiN + 1;
			};
		} forEach _aiTeams;
	};
};

_player_group = group player;
//--- cmdcon41-w3d TAG-CLICK POPUP FIX: the roster listbox (21002) lists player-led clientTeams by default, and optionally
//--- live AI-led teams as camera-only targets. The old start index was `clientTeams find _player_group` - an index into the FULL clientTeams array,
//--- not the filtered player-led list, and -1 when the caller's group is not a player-led clientTeams entry (the war-room
//--- VIEW-TEAM path, or an HC-seated / solo commander). `lbSetCurSel [21002,-1]` then left NO row selected, so the first
//--- Leader-Selection action (MenuAction 101) did `_list_Players select (lbCurSel 21002)` = `select -1` = a "Zero divisor /
//--- index" popup (the reported tag-click error, RPT-silent because it is an engine dialog fault). Resolve the index INTO
//--- _list_Players and clamp to a valid row (0 if the player's own group is not player-led, so a row is always selected).
//--- Flag-gated so it can be disabled if ever needed (default ON).
_id = _list_Players find _player_group;
if ((missionNamespace getVariable ["WFBE_C_CMD_MENU_V2", 1]) > 0) then {
	if (_id < 0) then {_id = 0};                                  //--- caller not listed -> default to the first camera target so a row is always selected
	if (count _list_Players == 0) then {_id = -1};               //--- but if NO camera targets exist, leave nothing selected (the 101 handler is guarded below)
	if (_id >= 0 && {isNull (_list_Players select _id)} && {(count _list_Players) > (_id + 1)}) then {_id = _id + 1}; //--- skip the read-only AI Teams header if it is the first row
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
		//--- cmdcon41-w3d TAG-CLICK POPUP FIX: guard `_list_Players select (lbCurSel 21002)` against an empty camera-target
		//--- list, a -1 current selection, and the read-only AI Teams header (grpNull). Only index when a valid row is
		//--- selected into a non-empty list with a real group; otherwise no-op the swap so the camera stays on its current unit.
		private "_lsSel"; _lsSel = lbCurSel 21002;
		if (count _list_Players > 0 && {_lsSel >= 0} && {_lsSel < (count _list_Players)}) then {
			private "_selGroup"; _selGroup = _list_Players select _lsSel;
			if (!isNull _selGroup) then {
				_selected = leader _selGroup;

				_currentUnit = (_selected) Call GetUnitVehicle;
				_units = (Units (group _selected) - [_selected]) Call GetLiveUnits;
				lbClear 21004;
				{
					_unitNumber = (_x) Call GetAIDigit;
					lbAdd[21004,Format["[%1] (%2) %3", _unitNumber, GetText (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "displayName"),name _x]];
				} forEach _units;
				_cameraSwap = true;
			};
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
