/*
	WASP Vehicle Radio - the single client-side playback loop (ONE script VM per client).

	Design note (performance): this is deliberately ONE consolidated loop, NOT a per-vehicle
	script, so it does not recreate the per-unit-VM FPS cost the mission fights elsewhere.

	Gate: the loop only plays while the LOCAL player's side has >=1 alive Radio Tower
	(WFBE_C_STRUCTURES_RADIOTOWER, see Common_HasSideRadioTower.sqf). The gate is re-checked
	every tick (1s), so a destroyed/sold tower silences the stream on the manager's next
	iteration - no per-frame nearObjects scan is needed since it reuses the existing
	side-structures list.

	Playback: each station is a continuous internet stream (see Radio_Config.sqf), started/
	stopped via the client-side "a2waspwarfare_Extension" callExtension RADIO,PLAY/STOP commands
	(BASS-backed; the extension connects on a background thread so this loop never blocks on
	network I/O). Unlike the old playMusic implementation there is no track/duration bookkeeping -
	a continuous stream has no "track end" to advance past, so the loop only reacts to vehicle/
	station/on-off/tower changes.
*/

if (!isNil "WASP_Radio_ManagerRunning" && {WASP_Radio_ManagerRunning}) exitWith {};
WASP_Radio_ManagerRunning = true;

call compile preprocessFileLineNumbers "WASP\Radio\Radio_Config.sqf";

private ["_curVeh","_curUrl"];
_curVeh = objNull;
_curUrl = "";

while {true} do {
	private ["_veh","_on","_stIdx","_station","_url","_changed","_towerUp"];
	_veh = vehicle player;
	_towerUp = (side player) call WFBE_CO_FNC_HasSideRadioTower;
	_stIdx = _veh getVariable ["WASP_Radio_Station", 0];
	_station = [];
	if (_stIdx >= 0 && {_stIdx < (count WASP_RADIO_STATIONS)}) then {
		_station = WASP_RADIO_STATIONS select _stIdx;
	};
	_url = if ((count _station) > 1) then {_station select 1} else {""};
	_on = (_veh != player)
		&& {alive _veh}
		&& {_veh getVariable ["WASP_Radio_On", false]}
		&& {(missionNamespace getVariable ["WASP_RADIO_MODE", 1]) == 1}
		&& {_towerUp}
		&& {_url != ""};

	if (_on) then {
		_changed = (_veh != _curVeh) || {_url != _curUrl};

		if (_changed) then {
			private ["_vol"];
			"a2waspwarfare_Extension" callExtension format ["RADIO,PLAY,%1", _url];
			_vol = missionNamespace getVariable ["WASP_Radio_Volume", 1];
			"a2waspwarfare_Extension" callExtension format ["RADIO,VOLUME,%1", round(_vol * 100)];
			_curVeh = _veh;
			_curUrl = _url;
		};
	} else {
		if (_curUrl != "") then {
			"a2waspwarfare_Extension" callExtension "RADIO,STOP";
			_curVeh = objNull;
			_curUrl = "";
		};
	};

	sleep 1;
};
