/*
	fable/awacs-radar: AWACS PILOT WATCH. Launched once per client from Init_Client.sqf,
	only when WFBE_C_AWACS > 0. Polls the local player's vehicle; when the player is the
	DRIVER of a WFBE_C_AWACS_TYPES airframe, spawns awacs_spotter.sqf for it (one live
	spotter at a time - handle re-checked via scriptDone; the spotter exits by itself
	when the player leaves the seat or the airframe dies, and re-entry re-arms here).
	Classnames are matched LOWERCASE: SQF 'in' on strings is case-sensitive and typeOf
	returns config casing, which may differ from the roster strings.
*/
Private ['_handle','_types','_veh'];

_types = [];
{_types = _types + [toLower _x]} forEach (missionNamespace getVariable ["WFBE_C_AWACS_TYPES", []]);
if (count _types == 0) exitWith {diag_log "AWACS: pilot watch NOT armed (empty WFBE_C_AWACS_TYPES)"};

diag_log Format ["AWACS: pilot watch armed for %1", _types];
_handle = [] Spawn {};

while {true} do {
	sleep 5;
	if (alive player) then {
		_veh = vehicle player;
		if (_veh != player) then {
			if ((toLower typeOf _veh) in _types && {driver _veh == player} && {scriptDone _handle}) then {
				_handle = [_veh] ExecVM 'Client\Module\AWACS\awacs_spotter.sqf';
			};
		};
	};
};
