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

private ["_curVeh","_curTrack","_startT","_dur","_n"];
_curVeh = objNull;
_curTrack = "";
_startT = 0;
_dur = 0;
_n = count WASP_RADIO_PLAYLIST;

while {true} do {
	private ["_veh","_on","_idx","_track","_changed","_finished","_towerUp"];
	_veh = vehicle player;
	_towerUp = (side player) call WFBE_CO_FNC_HasSideRadioTower;
	_on = (_veh != player)
		&& {alive _veh}
		&& {_veh getVariable ["WASP_Radio_On", false]}
		&& {(missionNamespace getVariable ["WASP_RADIO_MODE", 1]) == 1}
		&& {_towerUp}
		&& {_n > 0};

	if (_on) then {
		_idx = (_veh getVariable ["WASP_Radio_Index", 0]) % _n;
		_track = WASP_RADIO_PLAYLIST select _idx;
		_changed = (_veh != _curVeh) || {_track != _curTrack};
		_finished = !_changed && {(time - _startT) >= _dur};

		if (_finished) then {
			_idx = (_idx + 1) % _n;
			_veh setVariable ["WASP_Radio_Index", _idx, true];
			_track = WASP_RADIO_PLAYLIST select _idx;
			_changed = true;
		};

		if (_changed) then {
			// Graceful degradation: if the modpack addon isn't loaded the class is absent -> no-op (no RPT spam).
			if (isClass (configFile >> "CfgMusic" >> _track)) then {
				playMusic _track;
			};
			_curVeh = _veh;
			_curTrack = _track;
			_startT = time;
			_dur = WASP_RADIO_DUR select _idx;
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
