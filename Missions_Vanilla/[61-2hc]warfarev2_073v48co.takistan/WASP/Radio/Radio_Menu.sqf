/*
	WASP Vehicle Radio - open the radio choice menu (temporary sub-actions).
	Run as an addAction script (local) from Init_Unit.sqf via the single "Radio" action.
	_this = [target (vehicle), caller, actionId, arguments].

	Adds temporary addActions on the vehicle for station choice, volume choice and
	"Radio Off" so the player can pick without a custom dialog (A2-proof, no RscDisplay).
	The sub-actions remove themselves after WASP_RADIO_MENU_TIMEOUT seconds (default 15) so
	they do not linger once the player has picked (or ignored) a choice.

	Gate: requires >=1 alive Radio Tower on the caller's side (WFBE_C_STRUCTURES_RADIOTOWER).
*/

private ["_veh","_caller","_ids","_i","_id","_stationNames"];
_veh = _this select 0;
_caller = _this select 1;
if (isNull _veh) exitWith {};

if !((side _caller) call WFBE_CO_FNC_HasSideRadioTower) exitWith {};

if (isNil "WASP_RADIO_STATIONS") then {
	call compile preprocessFileLineNumbers "WASP\Radio\Radio_Config.sqf";
};

// Idempotency: do not stack a second set of sub-actions if the menu is already open.
if (_veh getVariable ["WASP_Radio_MenuOpen", false]) exitWith {};
_veh setVariable ["WASP_Radio_MenuOpen", true];

_ids = [];
_stationNames = [];
{
	_stationNames set [count _stationNames, (_x select 0)];
} forEach WASP_RADIO_STATIONS;

_i = 0;
{
	private ["_stIdx","_label"];
	_stIdx = _i;
	_label = "<t color='#FFBD4C'>Station: " + _x + "</t>";
	_id = _veh addAction [_label, "WASP\Radio\Radio_SetStation.sqf", _stIdx, 4, false, true, "", "vehicle player == _target && alive _target"];
	_ids set [count _ids, _id];
	_i = _i + 1;
} forEach _stationNames;

_id = _veh addAction ["<t color='#FFBD4C'>Volume: Low</t>", "WASP\Radio\Radio_SetVolume.sqf", 0.25, 4, false, true, "", "vehicle player == _target && alive _target"];
_ids set [count _ids, _id];
_id = _veh addAction ["<t color='#FFBD4C'>Volume: Medium</t>", "WASP\Radio\Radio_SetVolume.sqf", 0.55, 4, false, true, "", "vehicle player == _target && alive _target"];
_ids set [count _ids, _id];
_id = _veh addAction ["<t color='#FFBD4C'>Volume: High</t>", "WASP\Radio\Radio_SetVolume.sqf", 1, 4, false, true, "", "vehicle player == _target && alive _target"];
_ids set [count _ids, _id];

_id = _veh addAction ["<t color='#FFBD4C'>Radio Off</t>", "WASP\Radio\Radio_Off.sqf", [], 4, false, true, "", "vehicle player == _target"];
_ids set [count _ids, _id];

_veh setVariable ["WASP_Radio_MenuIds", _ids];

[_veh, _ids] spawn {
	private ["_v","_idList"];
	_v = _this select 0;
	_idList = _this select 1;
	sleep (missionNamespace getVariable ["WASP_RADIO_MENU_TIMEOUT", 15]);
	if (!isNull _v) then {
		{
			_v removeAction _x;
		} forEach _idList;
		_v setVariable ["WASP_Radio_MenuOpen", false];
	};
};
