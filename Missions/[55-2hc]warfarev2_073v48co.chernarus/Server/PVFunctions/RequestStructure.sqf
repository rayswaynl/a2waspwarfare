Private ['_dir','_index','_pos','_script','_side','_structure','_structureType','_structures','_structuresNames','_rlType'];

_side = _this select 0;
_structureType = _this select 1;
_pos = _this select 2;
_dir = _this select 3;

_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES',str _side];
_structuresNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',str _side];
_rlType = _structures select (_structuresNames find _structureType);

["DEBUG (RequestStructure.sqf)", Format ["Building: %1", _rlType]] Call WFBE_CO_FNC_LogContent;

if (_rlType in ["Barracks", "Light", "CommandCenter", "Heavy", "Aircraft", "ServicePoint", "AARadar", "CBRadar", "Bank", "ArtilleryRadar", "Reserve"]) then {
    [_side, "HandleSpecial", ['building-started', _rlType, _pos]] Call WFBE_CO_FNC_SendToClients;
};

//--- CBR requires an alive AAR on the same side.
if (_rlType == "CBRadar") then {
	private ["_aarClass","_aarAlive","_structs"];
	_aarClass = missionNamespace getVariable [Format ["%1AAR", str _side], ""];
	_aarAlive = false;
	if (_aarClass != "") then {
		_structs = (_side) Call WFBE_CO_FNC_GetSideStructures;
		{if (alive _x && typeOf _x == _aarClass) exitWith {_aarAlive = true}} forEach _structs;
	};
	if (!_aarAlive) exitWith {
		[_side, "LocalizeMessage", ["CBRadarNeedsAAR"]] Call WFBE_CO_FNC_SendToClients;
		["WARNING", Format ["RequestStructure.sqf: [%1] CBRadar build rejected — no alive AAR.", str _side]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Bank: one per side + must be placed outside own base protection area.
if (_rlType == "Bank" && (missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	private ["_bankKey","_existingBank","_logik","_startPos","_baseAreas","_protRange","_tooClose","_checkCenters"];
	_bankKey = if (_side == west) then {"WFBE_BANK_WEST"} else {"WFBE_BANK_EAST"};
	_existingBank = missionNamespace getVariable [_bankKey, objNull];
	if (!(isNull _existingBank) && alive _existingBank) exitWith {
		[_side, "LocalizeMessage", ["BankAlreadyBuilt"]] Call WFBE_CO_FNC_SendToClients;
		["WARNING", Format ["RequestStructure.sqf: [%1] Bank build rejected — bank already alive.", str _side]] Call WFBE_CO_FNC_LogContent;
	};
	_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
	_startPos = _logik getVariable ["wfbe_startpos", [0,0,0]];
	_baseAreas = _logik getVariable ["wfbe_basearea", []];
	_protRange = missionNamespace getVariable ["WFBE_C_BASE_PROTECTION_RANGE", 800];
	_checkCenters = [_startPos];
	{_checkCenters = _checkCenters + [getPos _x]} forEach _baseAreas;
	_tooClose = false;
	{if (_pos distance _x < _protRange) exitWith {_tooClose = true}} forEach _checkCenters;
	if (_tooClose) exitWith {
		[_side, "LocalizeMessage", ["BankTooCloseToBase"]] Call WFBE_CO_FNC_SendToClients;
		["WARNING", Format ["RequestStructure.sqf: [%1] Bank build rejected — placement too close to base (< %2 m).", str _side, _protRange]] Call WFBE_CO_FNC_LogContent;
	};
};

_index = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",str _side]) find _structureType;
if (_index != -1) then {
	_script = (missionNamespace getVariable Format ["WFBE_%1STRUCTURESCRIPTS",str _side]) select _index;
	[_structureType,_side,_pos,_dir,_index] ExecVM (Format["Server\Construction\Construction_%1.sqf",_script]);
};