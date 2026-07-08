/*
	WASP Vehicle Radio - the single client-side playback loop (ONE script VM per client).

	Design note (performance): this is deliberately ONE consolidated loop, NOT a per-vehicle
	script, so it does not recreate the per-unit-VM FPS cost the mission fights elsewhere.

	Gate: the loop only plays while the LOCAL player's side has >=1 alive Radio Tower
	(WFBE_C_STRUCTURES_RADIOTOWER, see Common_HasSideRadioTower.sqf). The gate is re-checked
	every tick (1s), so a destroyed/sold tower silences music on the manager's next iteration -
	no per-frame nearObjects scan is needed since it reuses the existing side-structures list.

	Mode 1 (2D personal, DEFAULT): plays the current vehicle's station to the LOCAL player via
	  playMusic while they crew a radio-on vehicle; advances the playlist by WASP_RADIO_DUR;
	  stops on exit / off / destroy / tower loss.
	Mode 2 (3D diegetic, reserved): the hook + public state are already in place; a future
	  revision swaps the playMusic block for a say3D pass over nearby radio-on vehicles. No
	  re-render needed - the addon defines the same tracks in CfgSounds as well as CfgMusic.
*/

if (!isNil "WASP_Radio_ManagerRunning" && {WASP_Radio_ManagerRunning}) exitWith {};
WASP_Radio_ManagerRunning = true;

call compile preprocessFileLineNumbers "WASP\Radio\Radio_Config.sqf";

private ["_curVeh","_curTrack","_startT","_dur"];
_curVeh = objNull;
_curTrack = "";
_startT = 0;
_dur = 0;

while {true} do {
	private ["_veh","_on","_idx","_track","_changed","_finished","_towerUp","_stIdx","_station","_slots","_n"];
	_veh = vehicle player;
	_towerUp = (side player) call WFBE_CO_FNC_HasSideRadioTower;
	_stIdx = _veh getVariable ["WASP_Radio_Station", 0];
	_station = [];
	if (_stIdx >= 0 && {_stIdx < (count WASP_RADIO_STATIONS)}) then {
		_station = WASP_RADIO_STATIONS select _stIdx;
	};
	_slots = if ((count _station) > 0) then {_station select 1} else {[]};
	_n = count _slots;
	_on = (_veh != player)
		&& {alive _veh}
		&& {_veh getVariable ["WASP_Radio_On", false]}
		&& {(missionNamespace getVariable ["WASP_RADIO_MODE", 1]) == 1}
		&& {_towerUp}
		&& {_n > 0};

	if (_on) then {
		_idx = (_veh getVariable ["WASP_Radio_Index", 0]) % _n;
		_track = _slots select _idx;
		_changed = (_veh != _curVeh) || {_track != _curTrack};
		_finished = !_changed && {(time - _startT) >= _dur};

		if (_finished) then {
			_idx = (_idx + 1) % _n;
			_veh setVariable ["WASP_Radio_Index", _idx, true];
			_track = _slots select _idx;
			_changed = true;
		};

		if (_changed) then {
			private ["_durIdx","_vol"];
			// Graceful degradation: if the modpack addon isn't loaded the class is absent -> no-op (no RPT spam).
			if (isClass (configFile >> "CfgMusic" >> _track)) then {
				playMusic _track;
				_vol = missionNamespace getVariable ["WASP_Radio_Volume", 1];
				fadeMusic _vol;
			};
			_curVeh = _veh;
			_curTrack = _track;
			_startT = time;
			_durIdx = WASP_RADIO_PLAYLIST find _track;
			_dur = if (_durIdx >= 0) then {WASP_RADIO_DUR select _durIdx} else {120};
		};
	} else {
		if (_curTrack != "") then {
			playMusic "";
			_curVeh = objNull;
			_curTrack = "";
			_startT = 0;
			_dur = 0;
		};
	};

	sleep 1;
};
