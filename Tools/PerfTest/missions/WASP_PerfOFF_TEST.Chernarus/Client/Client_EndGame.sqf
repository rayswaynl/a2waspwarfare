Private ['_HQ','_base','_blist','_camShotOrder','_camera','_musicTrack','_nvgstate','_position','_secTarget','_side','_track','_vehi'];

_side = _this;

//--- B67 [wiki-wins]: the payload IS the winner. The old block inverted _side
//--- (west<->east, with a "_side is the looser" comment), which named the WRONG
//--- side in the victory banner and skipped resistance entirely. Inversion removed:
//--- _side now stays the winner. The fly-over below still iterates the non-winner
//--- sides via ([west,east,resistance] - [_side]), so it remains correct.

[_side] ExecVM "Client\GUI\GUI_EndOfGameStats.sqf";
//_track = if (WF_A2_Vanilla) then {"Track21_Rise_Of_The_Fallen"} else {"EP1_Track15"}; //---old
_musicTrack = "wf_outro"; //---changed-MrNiceGuy; lane 51 keeps this legacy fallback while optional soundtrack is disabled.
if ((missionNamespace getVariable ["WFBE_C_MUSIC_ENABLE", 0]) > 0) then {
	_musicTrack = missionNamespace getVariable ["WFBE_C_MUSIC_VICTORY_TRACK", "wf_outro"];
};
if ((count (toArray _musicTrack)) > 0) then {playMusic _musicTrack;};

_track_hq = [];
_track = [];
{
	if (missionNamespace getVariable Format["WFBE_%1_PRESENT", _x]) then {
		_logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
		_hq = _logik getVariable "wfbe_hq";
		_track_hq = _track_hq + [_hq];
		_track = _track + ([_hq, (_x) Call WFBE_CO_FNC_GetSideStructures] Call SortByDistance);
	};
} forEach ([west,east,resistance] - [_side]);

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
_blist = [_hq] + _track_hq + ([_hq, (_side) Call WFBE_CO_FNC_GetSideStructures] Call SortByDistance) + _track;

// _base = WestMHQ;
// _secTarget = EastMHQ;
// if (_side == West) then {_base = EastMHQ;_secTarget = WestMHQ};
// _position = getPos _base;

// _blist = [_secTarget,_blist] Call SortByDistance;
// _blist = [_secTarget] + _blist;

//--- Safety Pos.
_hq = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
_vehi = vehicle player;
if (_vehi != player) then {player action ["EJECT", _vehi];_vehi = player};
_vehi setVelocity [0,0,-0.1];
_vehi setPos ([getPos _hq,20,30] Call GetRandomPosition);

if (!isNil "DeathCamera") then {
	DeathCamera cameraEffect["TERMINATE","BACK"];
	camDestroy DeathCamera;
	"colorCorrections" ppEffectEnable false;
	"dynamicBlur" ppEffectEnable false;
};

_camera = "camera" camCreate (getPos (_blist select 0));
_camera camSetDir 0;
_camera camSetFov 0.200;
_camera cameraEffect["Internal","back"];
_camera camSetTarget getPos (_blist select 0);
_camera camSetRelPos [160.80,130.29,140.07];
_camera camCommit 0;
_nvgstate = if (daytime > 18.5 || daytime < 5.5) then {true} else {false};
camUseNVG _nvgstate;

//--- B69 [S7 victory outro spectacle]: a SHORT, purely cosmetic celebration at the
//--- WINNING HQ. Runs entirely client-local in its own thread, spawned only AFTER
//--- gameOver/failMission is already in motion (this whole script runs post-gameOver),
//--- so it can never touch AI, the server loop, or server FPS. Total AI count is
//--- unaffected (no units created). Reuses the #lightpoint + Universal-billboard
//--- particle idiom from Client\Module\Nuke\nuke.sqf:47-50, heavily downscaled.
//--- Default-on; gated behind a missionNamespace flag so it can be disabled without
//--- a code change (constant added by the dedicated constants agent; getVariable
//--- [name,default] keeps this safe before that constant exists).
if (missionNamespace getVariable ["WFBE_C_VICTORY_OUTRO_FX", true]) then {
	[_side, getPos (_blist select 0)] Spawn {
		Private ['_fxSide','_fxPos','_col','_flare','_light','_i'];
		_fxSide = _this select 0;
		_fxPos  = _this select 1;
		//--- Faction colour (R,G,B), plain == comparisons (no A3 commands).
		_col = [255, 200, 80];                               //--- default: warm gold
		if (_fxSide == west)       then {_col = [60, 140, 255]};   //--- BLUFOR  blue
		if (_fxSide == east)       then {_col = [255, 60, 60]};    //--- OPFOR   red
		if (_fxSide == resistance) then {_col = [80, 230, 90]};    //--- GUER    green

		//--- Faction-coloured flare fountain straight up from the HQ (cosmetic only).
		_flare = "#particlesource" createVehicleLocal [(_fxPos select 0), (_fxPos select 1), ((_fxPos select 2) + 2)];
		_flare setParticleParams [["\Ca\Data\ParticleEffects\Universal\Universal", 16, 7, 48], "", "Billboard", 1, 6, [0, 0, 0],
			[0, 0, 22], 0, 1.6, 1, 0, [1.2, 0.4],
			[[(_col select 0)/255, (_col select 1)/255, (_col select 2)/255, 0.9],
			 [(_col select 0)/255, (_col select 1)/255, (_col select 2)/255, 0.6],
			 [(_col select 0)/255, (_col select 1)/255, (_col select 2)/255, 0]],
			[0.4], 0.1, 1, "", "", _flare];
		_flare setParticleRandom [1, [4, 4, 4], [3, 3, 9], 0, 0.4, [0, 0, 0, 0.1], 0, 0];
		_flare setDropInterval 0.01;

		//--- Downscaled #lightpoint above the HQ in faction colour (nuke uses brightness
		//--- 100000 / ambient 1500; here ~brightness 12 / ambient ~6 so it tints, not blinds).
		_light = "#lightpoint" createVehicleLocal [(_fxPos select 0), (_fxPos select 1), ((_fxPos select 2) + 30)];
		_light setLightColor   [(_col select 0)/30, (_col select 1)/30, (_col select 2)/30];
		_light setLightAmbient [(_col select 0)/45, (_col select 1)/45, (_col select 2)/45];
		_light setLightBrightness 12;

		//--- Brief celebratory pulse, then full self-clean. Short by design.
		for "_i" from 0 to 9 do {
			_light setLightBrightness (6 + (random 14));
			sleep 0.4;
		};

		_flare setDropInterval 0;
		deleteVehicle _light;
		sleep 3;
		deleteVehicle _flare;
	};
};

waitUntil {camCommitted _camera};

_camera camSetRelPos [-190.71,190.55,180.94];
_camera camCommit 10;

waitUntil {camCommitted _camera};

_camShotOrder = [[0,100,35],[50,0,20],[0,-50,20],[-50,0,20]];

{
	_camera camSetPos getPos _x;
	_camera camSetTarget getPos _x;
	
	{
		_camera camSetRelPos _x;
		_camera camCommit 5;
		waitUntil {camCommitted _camera};
	} forEach _camShotOrder;
	
	_camera camSetRelPos [0,100,35];
	_camera camCommit 5;
	waitUntil {camCommitted _camera};
} forEach _blist;

sleep 3;
failMission "END1";
