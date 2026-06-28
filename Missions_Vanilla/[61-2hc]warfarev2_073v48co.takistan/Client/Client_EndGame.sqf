Private ['_HQ','_base','_blist','_camShotOrder','_camera','_nvgstate','_position','_secTarget','_side','_track','_vehi','_holdTime','_winPos','_t0','_ang','_radius'];

_side = _this;

//--- B67 [wiki-wins]: the payload IS the winner. The old block inverted _side
//--- (west<->east, with a "_side is the looser" comment), which named the WRONG
//--- side in the victory banner and skipped resistance entirely. Inversion removed:
//--- _side now stays the winner. The fly-over below still iterates the non-winner
//--- sides via ([west,east,resistance] - [_side]), so it remains correct.

[_side] ExecVM "Client\GUI\GUI_EndOfGameStats.sqf";
//_track = if (WF_A2_Vanilla) then {"Track21_Rise_Of_The_Fallen"} else {"EP1_Track15"}; //---old
_track = "wf_outro"; //---changed-MrNiceGuy
playMusic _track;

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

//--- [endgame winner cam]: per-client SKIP. SPACE (DIK 57) or ESC (DIK 1) ends the cinematic early for
//--- THIS client only and drops to the score/debrief screen. We consume those two keys (return true) so
//--- ESC does not pop the pause menu over the cam; every other key passes through (return false). The
//--- handler index is captured so we can remove exactly our own handler at the end (never the mission's).
WFBE_ENDGAME_SKIP = false;
WFBE_ENDGAME_SKIP_EH = -1;
if (!isDedicated && !isNull (findDisplay 46)) then {
	WFBE_ENDGAME_SKIP_EH = (findDisplay 46) displayAddEventHandler ["KeyDown", {
		private "_k"; _k = _this select 1;
		if (_k in [1,57]) then { WFBE_ENDGAME_SKIP = true; true } else { false };
	}];
	hintSilent parseText "<t size='0.8' color='#cccccc'>Press SPACE to skip the victory cam</t>";
};

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

//--- [endgame winner cam]: winner-focused, time-bounded cinematic. The old code panned over EVERY base
//--- on the map (both sides), which was unfocused AND on a populated server was usually cut short anyway -
//--- server_victory_threeway.sqf used to call failMission only ~5-7s after sending the "endgame" signal,
//--- long before this fly-over could finish. The server now holds the round open for WFBE_C_ENDGAME_HOLD
//--- seconds (same default as here), so this orbit reliably plays to completion / is long enough to
//--- capture for video. Everything below is client-local: no units, no AI, zero server cost.
_holdTime = missionNamespace getVariable ["WFBE_C_ENDGAME_HOLD", 45];
_winPos = getPos ((_side) Call WFBE_CO_FNC_GetSideHQ);

//--- Slow orbit of the WINNING HQ for the hold duration (or until skipped). camSetRelPos is relative to
//--- the cam target, so re-targeting the HQ position each leg keeps it centred while we walk the azimuth.
//--- Gentle vertical bob (sin of the angle) so it reads as a sweep, not a flat turntable.
_t0 = time;
_ang = 200;        //--- start high/behind for a hero reveal
_radius = 150;
while { (time - _t0) < _holdTime && !WFBE_ENDGAME_SKIP } do {
	_ang = _ang + 24;
	_camera camSetTarget _winPos;
	_camera camSetRelPos [_radius * sin(_ang), _radius * cos(_ang), 45 + (25 * sin(_ang))];
	_camera camCommit 4;
	waitUntil { camCommitted _camera || WFBE_ENDGAME_SKIP || (time - _t0) >= _holdTime };
};

//--- Remove exactly our own KeyDown handler (leave any mission handlers intact).
if (!isDedicated && WFBE_ENDGAME_SKIP_EH >= 0 && !isNull (findDisplay 46)) then {
	(findDisplay 46) displayRemoveEventHandler ["KeyDown", WFBE_ENDGAME_SKIP_EH];
	WFBE_ENDGAME_SKIP_EH = -1;
};

sleep (if (WFBE_ENDGAME_SKIP) then {0.2} else {1.5});
failMission "END1";