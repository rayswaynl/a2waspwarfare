private["_victory","_total","_side","_hq","_structures","_towns","_factories","_uid","_name","_winSide"];

_victory = missionNamespace getVariable "WFBE_C_VICTORY_THREEWAY";
_total = totalTowns;
_innerTimer = 0;
_loopTimer = 80;
_miniSleep = 0.05;

while {!gameOver} do {

	//--- B66 (Ray 2026-06-21) PARAM-TRAP FIX: the old gate `_victory == 0` meant ANY non-zero
	//--- WFBE_C_VICTORY_THREEWAY silently disabled ALL victory detection - the round could never end
	//--- (no supremacy win, no HQ-loss win). Supremacy/HQ-loss detection now runs UNCONDITIONALLY; the
	//--- _victory param no longer gates it. We deliberately add NO new victory MODES here (Ray: no new
	//--- modes) - this only stops the trap so the standard supremacy condition always works.
	//--- ENDGAME SOFT-FORCING (claude-gaming 2026-06-29, SYSTEM 2): after WFBE_C_ENDGAME_FORCE_TIMER minutes of an
	//--- unresolved round, publish an escalating GLOBAL income taper multiplier (WFBE_ENDGAME_FORCE_MULT, 1.0 -> FLOOR)
	//--- that updateresources.sqf applies to AICOM town income, so turtling becomes unsustainable and a side must commit.
	//--- No sim/distance-gating, no freeze/teleport, no antistack touch (Ray hard constraints) - purely an economic squeeze.
	//--- DEFAULT-OFF (WFBE_C_ENDGAME_FORCE_ENABLE=0 -> publish a neutral 1.0 so the consumer is a no-op when dark). The
	//--- round is "unresolved" simply because we are still in this !gameOver loop; mission 'time' is the elapsed clock.
	if ((missionNamespace getVariable ["WFBE_C_ENDGAME_FORCE_ENABLE", 0]) > 0) then {
		private ["_forceStartS","_overMin","_step","_floor","_mult","_prevMult"];
		_forceStartS = (missionNamespace getVariable ["WFBE_C_ENDGAME_FORCE_TIMER", 90]) * 60;
		_overMin = ((time - _forceStartS) / 60) max 0;   //--- minutes elapsed PAST the force timer (0 before it)
		_step  = missionNamespace getVariable ["WFBE_C_ENDGAME_FORCE_TAPER_STEP", 0.04];
		_floor = missionNamespace getVariable ["WFBE_C_ENDGAME_FORCE_TAPER_FLOOR", 0.10];
		_mult = (1 - (_overMin * _step)) max _floor;     //--- 1.0 until the timer, then escalating shrink down to FLOOR
		_prevMult = missionNamespace getVariable ["WFBE_ENDGAME_FORCE_MULT", 1];
		missionNamespace setVariable ["WFBE_ENDGAME_FORCE_MULT", _mult];
		//--- one-line INFORMATION the first tick the squeeze actually starts biting (mult drops below 1), for soak proof.
		if (_overMin > 0 && {_prevMult >= 1} && {_mult < 1}) then {
			["INFORMATION", Format ["server_victory_threeway.sqf: ENDGAME SOFT-FORCE engaged at %1 min (past %2-min timer) - global income taper begins (mult now %3, floor %4).", round (time / 60), missionNamespace getVariable ["WFBE_C_ENDGAME_FORCE_TIMER", 90], _mult, _floor]] Call WFBE_CO_FNC_LogContent;
			diag_log ("AICOMSTAT|v1|EVENT|ALL|" + str (round (time / 60)) + "|ENDGAME_FORCE|mult" + str _mult);
		};
	} else {
		//--- Dark: keep the consumer a strict no-op (neutral multiplier).
		missionNamespace setVariable ["WFBE_ENDGAME_FORCE_MULT", 1];
	};

	if (!gameOver) then {
		{
			_side = _x;
			_hq = (_x) Call WFBE_CO_FNC_GetSideHQ;
			_structures = (_x) Call WFBE_CO_FNC_GetSideStructures;
			_towns = (_x) Call GetTownsHeld;

				//--- B67 [wiki-wins]: once a winner is set this tick, do not award again for
				//--- any remaining side in this same forEach pass (belt-and-braces with the
				//--- !WFBE_GameOver guard inside the award condition below).
				if (WFBE_GameOver) exitWith {};

			//--- HQ not registered yet (early boot) -> skip this side this tick. NOTE: do NOT
			//--- treat nil as "HQ dead": at boot factories are 0 too, and that would end the
			//--- round instantly. The old code threw on the nil instead (16x/boot in RPT).
			if (isNil "_hq") exitWith {};
			if (isNull _hq) exitWith {};

			_factories = 0;
			{
				_factories = _factories + count([_side,missionNamespace getVariable Format ["WFBE_%1%2TYPE",_side,_x], _structures] Call GetFactories);
			} forEach ["BARRACKS","LIGHT","HEAVY","AIRCRAFT"];

			//--- B67 [wiki-wins]: explicit parenthesisation. The old expression
			//---   !(alive _hq) && _factories==0 || _towns==_total && !WFBE_GameOver
			//--- relies on left-to-right SQF precedence and reads ambiguously, and the
			//--- forEach could fire the award block twice in one tick (once per side).
			//--- Now: fire only while NOT already over, for a clear supremacy/HQ-loss win;
			//--- WFBE_GameOver also short-circuits any later side in the same forEach pass.
			if ( !WFBE_GameOver && ( (!(alive _hq) && _factories == 0) || (_towns == _total) ) ) then {
				//--- FIX D (winner backwards): the award block fires for the evaluated side _x.
				//--- If the towns-supremacy sub-condition is true, _x is the WINNER. Otherwise the
				//--- HQ-loss branch fired - _x is the side whose own HQ was razed = the LOSER, so the
				//--- real winner is the OTHER side. GUER (defender) is excluded from this loop, so the
				//--- winner is strictly the opposite of the two-sided WEST/EAST pair.
				if (_towns == _total) then {
					_winSide = _x;
				} else {
					if (_x == west) then { _winSide = east } else { _winSide = west };
				};
				[nil, "HandleSpecial", ["endgame", (_winSide) Call WFBE_CO_FNC_GetSideID]] Call WFBE_CO_FNC_SendToClients;

				// 0 = NONE
				// 1 = CHERNARUS
				// 2 = TAKISTAN
				["SET_MAP", 0] call WFBE_SE_FNC_CallDatabaseSetMap;

				WF_Logic setVariable ["WF_Winner", _winSide];
				gameOver = true;
				WFBE_GameOver = true;

				// WASPSTAT ROUNDEND telemetry (Task 10). Winner = _winSide (the real winning side).
				// durationSec = round(time) which mirrors GlobalGameStats.sqf's _uptime source.
				if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) == 1) then {
					if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
					WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
					diag_log ("WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|ROUNDEND|" + str _winSide + "|" + str round(time) + "|" + worldName);
				};

				[_winSide] call WFBE_CO_FNC_LogGameEnd;
			};
		} forEach WFBE_PRESENTSIDES - [WFBE_DEFENDER];
	};

	sleep _loopTimer;
	_innerTimer = _innerTimer + _loopTimer;

};

// Marty: When AntiStack is disabled, no score sampling loop exists; skip final AntiStack DB persistence and finish the mission normally.
if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
	["INFORMATION", "server_victory_threeway.sqf: AntiStack is disabled; skipped final score DB save and player list flush."] Call WFBE_CO_FNC_LogContent;
	_hold = missionNamespace getVariable ["WFBE_C_ENDGAME_HOLD",45];
	sleep _hold;
	sleep 5;
	diag_log Format["[WFBE (OUTRO)][frameno:%1 | ticktime:%2] server_victory_threeway.sqf: Mission end - [Done]",diag_frameno,diag_tickTime];
	failMission "END1";
};

//--- Save the players' stats to database.
{
	if (isPlayer _x) then {
		_uid = getPlayerUID _x;
		_name = name _x;
		_playerScore = missionNamespace getVariable format ["WFBE_CO_CURRENT_SCORE_PLAYER_%1", _uid];
		
		if (isNil "_playerScore") then {
			_playerScore = 0;
			["ERROR", Format ["Server_Victory_Threeway.sqf: Player [%1] [%2] has no score to be saved upon match end. This can be caused by immediate disconnection from the match after joining, or it can be something fishy. Or the player just joined when the match ended.", _name, _uid]] Call WFBE_CO_FNC_LogContent;
		};
		_oldScore = missionNamespace getVariable format ["WFBE_CO_OLD_SCORE_PLAYER_%1", _uid];
		
		if (isNil "_oldScore") then {
			_oldScore = 0;
		};
		
		missionNamespace setVariable [format["WFBE_CO_OLD_SCORE_PLAYER_%1", _uid], _playerScore];
		_playerScoreDiff = _playerScore - _oldScore;
		_result = ["STORE", [_uid, _playerScoreDiff]] call WFBE_SE_FNC_CallDatabaseStore;
		sleep _miniSleep;
		
	};
} forEach allUnits;

["FLUSH_PLAYERLIST"] call WFBE_SE_FNC_CallDatabaseFlushPlayerList;

_hold = missionNamespace getVariable ["WFBE_C_ENDGAME_HOLD",45];
sleep _hold;
sleep 5;
diag_log Format["[WFBE (OUTRO)][frameno:%1 | ticktime:%2] server_victory_threeway.sqf: Mission end - [Done]",diag_frameno,diag_tickTime];
failMission "END1";
