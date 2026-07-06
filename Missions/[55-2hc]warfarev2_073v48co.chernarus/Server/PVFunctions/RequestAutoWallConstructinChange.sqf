Private ['_isAutoWallConstructingEnabled','_player','_side'];

if !(typeName _this in ["ARRAY"]) exitWith {
	["WARNING", Format ["RequestAutoWallConstructinChange.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (count _this < 2) exitWith {
	["WARNING", Format ["RequestAutoWallConstructinChange.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_isAutoWallConstructingEnabled = _this select 0;
_player = _this select 1;

if !(typeName _isAutoWallConstructingEnabled in ["BOOL"]) exitWith {
	["WARNING", Format ["RequestAutoWallConstructinChange.sqf: rejected non-bool state [%1].", _isAutoWallConstructingEnabled]] Call WFBE_CO_FNC_LogContent;
};
if (!(typeName _player in ["OBJECT"]) || {isNull _player}) exitWith {
	["WARNING", Format ["RequestAutoWallConstructinChange.sqf: rejected invalid player object [%1].", _player]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer _player) exitWith {
	["WARNING", Format ["RequestAutoWallConstructinChange.sqf: rejected non-player requester [%1].", _player]] Call WFBE_CO_FNC_LogContent;
};

//--- wiki-wins: scope the toggle to the requester's side (was a single global affecting every side + the AI),
//--- and notify the whole side so all that side's commanders' HUDs stay in sync (was sent only to the toggler).
_side = side _player;
missionNamespace setVariable [Format["WFBE_AUTOWALL_%1", _side], _isAutoWallConstructingEnabled];
isAutoWallConstructingEnabled = _isAutoWallConstructingEnabled; //--- keep the legacy global in step for any stray reader
[_side, "HandleSpecial", ["auto-wall-constructing-changed", _isAutoWallConstructingEnabled]] Call WFBE_CO_FNC_SendToClients;
