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

	//--- TERRITORIAL VICTORY (Ray, cmdcon41-w3b): a side that holds >= FRAC of all towns for MINS
	//--- unbroken WINS. This is a NEW win MODE (explicitly requested by Ray for build84), flag-gated
	//--- so it can be dialled off without a code change. It does NOT touch the supremacy/HQ-loss
	//--- detection below - it only, when its clock completes, feeds the SAME award block (via the
	//--- per-side WFBE_TERRITORIAL_WIN_<sid> marker read inside that block) so ROUNDEND / WASPSTAT /
	//--- winner plumbing / map rotation all fire IDENTICALLY. Clock state lives in missionNamespace,
	//--- keyed by side-ID; announcements route through the existing DashboardAnnounce PVF (systemChat
	//--- to every client on every side - same reach the OILFIELD opener uses). Milestones are
	//--- rate-limited to once each via a "last minute-bucket announced" marker per side.
	//--- Flags (integrator registers in Init_CommonConstants; read inline here with safe defaults):
	//---   WFBE_C_VICTORY_TERRITORIAL      (default 1)   master enable
	//---   WFBE_C_VICTORY_TERRITORIAL_FRAC (default 0.8) fraction of towns that must be held
	//---   WFBE_C_VICTORY_TERRITORIAL_MINS (default 30)  minutes the fraction must be held unbroken
	if ( !WFBE_GameOver && ((missionNamespace getVariable ["WFBE_C_VICTORY_TERRITORIAL", 1]) > 0) && (_total > 0) ) then {
		private ["_terrFrac","_terrMins","_terrHoldS","_sid","_clockKey","_mileKey","_winKey","_held","_needed","_startS","_elapsedS","_remainS","_remMin","_sideName"];
		_terrFrac  = missionNamespace getVariable ["WFBE_C_VICTORY_TERRITORIAL_FRAC", 0.8];
		_terrMins  = missionNamespace getVariable ["WFBE_C_VICTORY_TERRITORIAL_MINS", 30];
		_terrHoldS = _terrMins * 60;
		{
			_sid      = (_x) Call WFBE_CO_FNC_GetSideID;
			_clockKey = Format ["WFBE_TERRITORIAL_CLOCK_%1", _sid];  //--- start-time (seconds) while a clock runs; -1 = no clock (numeric sentinel, 2-arg get)
			_mileKey  = Format ["WFBE_TERRITORIAL_MILE_%1", _sid];   //--- last milestone minute-bucket announced (rate-limit)
			_winKey   = Format ["WFBE_TERRITORIAL_WIN_%1", _sid];    //--- 1 = clock completed -> award loop should crown this side
			_held     = (_x) Call GetTownsHeld;
			//--- We gate on the RATIO (_held/_total >= _frac) rather than a pre-rounded town count, so
			//--- there is no off-by-one rounding ambiguity at the threshold. _needed is display-only.
			_needed   = _terrFrac * _total;
			_sideName = str _x;
			//--- Read the running-clock start with the blessed 2-arg default form (-1 = not running).
			_startS   = missionNamespace getVariable [_clockKey, -1];
			if ((_held / _total) >= _terrFrac) then {
				//--- Side is AT/ABOVE the threshold this tick.
				if (_startS < 0) then {
					//--- No clock yet -> start one and announce the threat to BOTH sides.
					missionNamespace setVariable [_clockKey, time];
					missionNamespace setVariable [_mileKey, -1];        //--- no milestone announced yet
					missionNamespace setVariable [_winKey, 0];
					[nil, "DashboardAnnounce", [Format ["%1 dominates the region (%2 of %3 towns) - VICTORY in %4:00 unless their grip is broken!", _sideName, _held, _total, _terrMins]]] Call WFBE_CO_FNC_SendToClients;
					diag_log ("AICOMSTAT|v1|EVENT|" + (str _x) + "|" + str (round (time / 60)) + "|VICTORY_TERRITORIAL|clock-start held" + str _held + "/" + str _total + " mins" + str _terrMins);
					["INFORMATION", Format ["server_victory_threeway.sqf: TERRITORIAL clock STARTED for %1 (holds %2/%3 towns, need %4) - win in %5 min unbroken.", _sideName, _held, _total, _needed, _terrMins]] Call WFBE_CO_FNC_LogContent;
				} else {
					//--- Clock already running (_startS is its start time) -> advance milestones + check completion.
					_elapsedS = time - _startS;
					_remainS  = (_terrHoldS - _elapsedS) max 0;
					_remMin   = ceil (_remainS / 60);   //--- minutes remaining, rounded UP for the human-facing countdown
					if (_elapsedS >= _terrHoldS) then {
						//--- COMPLETED: mark ready. The existing award block (below) reads _winKey and
						//--- crowns _x through the SAME win path (double-fire guard preserved there).
						missionNamespace setVariable [_winKey, 1];
					} else {
						//--- Milestone re-announce at 20/10/5/1 minutes remaining, once each (rate-limited by
						//--- the last-bucket marker). Buckets are the exact minute thresholds.
						private ["_lastBucket","_bucket"];
						_lastBucket = missionNamespace getVariable [_mileKey, -1];
						_bucket = 0;
						if (_remMin <= 20 && _remMin > 10) then {_bucket = 20};
						if (_remMin <= 10 && _remMin > 5)  then {_bucket = 10};
						if (_remMin <= 5  && _remMin > 1)  then {_bucket = 5};
						if (_remMin <= 1)                  then {_bucket = 1};
						if (_bucket > 0 && _bucket != _lastBucket) then {
							missionNamespace setVariable [_mileKey, _bucket];
							[nil, "DashboardAnnounce", [Format ["%1 still holds the region (%2/%3 towns) - VICTORY in %4 minute(s) unless broken!", _sideName, _held, _total, _bucket]]] Call WFBE_CO_FNC_SendToClients;
							diag_log ("AICOMSTAT|v1|EVENT|" + (str _x) + "|" + str (round (time / 60)) + "|VICTORY_TERRITORIAL|milestone-" + str _bucket + "min held" + str _held + "/" + str _total);
						};
					};
				};
			} else {
				//--- Side dropped BELOW the threshold -> break the siege: cancel any running clock and
				//--- announce it to BOTH sides. Only announce when a clock was actually running (_startS >= 0).
				if (_startS >= 0) then {
					missionNamespace setVariable [_clockKey, -1];
					missionNamespace setVariable [_mileKey, -1];
					missionNamespace setVariable [_winKey, 0];
					[nil, "DashboardAnnounce", [Format ["The siege is broken! %1 no longer dominates the region (down to %2/%3 towns) - the victory clock is reset.", _sideName, _held, _total]]] Call WFBE_CO_FNC_SendToClients;
					diag_log ("AICOMSTAT|v1|EVENT|" + (str _x) + "|" + str (round (time / 60)) + "|VICTORY_TERRITORIAL|clock-broken held" + str _held + "/" + str _total);
					["INFORMATION", Format ["server_victory_threeway.sqf: TERRITORIAL clock BROKEN for %1 (now holds %2/%3 towns) - reset.", _sideName, _held, _total]] Call WFBE_CO_FNC_LogContent;
				};
			};
		} forEach WFBE_PRESENTSIDES - [WFBE_DEFENDER];
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

			//--- TERRITORIAL VICTORY (cmdcon41-w3b): read the completion marker the clock block above set
			//--- for THIS side. When 1, this side held >= FRAC of towns for the full duration -> it is the
			//--- WINNER, and we route through the SAME award path so ROUNDEND / WASPSTAT / rotation match.
			//--- Default-0 via the blessed 2-arg get (no A3 ops) so this is inert until a clock completes.
			private ["_terrWin"];
			_terrWin = (missionNamespace getVariable [Format ["WFBE_TERRITORIAL_WIN_%1", ((_x) Call WFBE_CO_FNC_GetSideID)], 0]) > 0;

			//--- B67 [wiki-wins]: explicit parenthesisation. The old expression
			//---   !(alive _hq) && _factories==0 || _towns==_total && !WFBE_GameOver
			//--- relies on left-to-right SQF precedence and reads ambiguously, and the
			//--- forEach could fire the award block twice in one tick (once per side).
			//--- Now: fire only while NOT already over, for a clear supremacy/HQ-loss win;
			//--- WFBE_GameOver also short-circuits any later side in the same forEach pass.
			//--- cmdcon41-w3b: the territorial clock (_terrWin) is OR-ed in as a third win trigger.
			if ( !WFBE_GameOver && ( (!(alive _hq) && _factories == 0) || (_towns == _total) || _terrWin ) ) then {
				//--- FIX D (winner backwards): the award block fires for the evaluated side _x.
				//--- If the towns-supremacy sub-condition is true, _x is the WINNER. Otherwise the
				//--- HQ-loss branch fired - _x is the side whose own HQ was razed = the LOSER, so the
				//--- real winner is the OTHER side. GUER (defender) is excluded from this loop, so the
				//--- winner is strictly the opposite of the two-sided WEST/EAST pair.
				//--- cmdcon41-w3b: territorial completion means _x (the dominating holder) is the WINNER,
				//--- same as the supremacy branch, so it shares the _winSide = _x assignment.
				if (_terrWin) then {
					_winSide = _x;
					diag_log ("AICOMSTAT|v1|EVENT|" + (str _x) + "|" + str (round (time / 60)) + "|VICTORY_TERRITORIAL|win-awarded held" + str _towns + "/" + str _total);
					["INFORMATION", Format ["server_victory_threeway.sqf: TERRITORIAL VICTORY awarded to %1 (held %2/%3 towns for the full duration).", str _x, _towns, _total]] Call WFBE_CO_FNC_LogContent;
					[nil, "DashboardAnnounce", [Format ["%1 has WON by TERRITORIAL DOMINANCE - held the region long enough to secure victory!", str _x]]] Call WFBE_CO_FNC_SendToClients;
				} else {
					if (_towns == _total) then {
						_winSide = _x;
					} else {
						if (_x == west) then { _winSide = east } else { _winSide = west };
					};
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

					// AICOM_FINAL: one final per-side summary at game-over, before the round-end marker.
					private ["_aicomRoundSec","_aicomElMin","_aicomSide","_aicomSideText","_aicomLogic","_aicomSnap","_aicomSnapOk","_aicomFunds","_aicomSupply","_aicomTowns","_aicomTeams","_aicomTeamDigest","_aicomCas","_aicomVeh","_aicomMade","_aicomKilled"];
					_aicomRoundSec = round(time);
					_aicomElMin = round(_aicomRoundSec / 60);
					{
						_aicomSide = _x;
						_aicomSideText = str _aicomSide;
						_aicomLogic = (_aicomSide) Call WFBE_CO_FNC_GetSideLogic;
						_aicomSnap = [];
						_aicomSnapOk = false;
						_aicomFunds = 0;
						_aicomSupply = 0;
						_aicomTowns = 0;
						_aicomTeams = 0;
						_aicomTeamDigest = [];
						if (!isNil "_aicomLogic" && {!isNull _aicomLogic}) then {
							_aicomSnap = _aicomLogic getVariable ["wfbe_aicom2_snap", []];
							_aicomSnapOk = (count _aicomSnap) >= 26;
						};
						if (_aicomSnapOk) then {
							_aicomFunds = _aicomSnap select WFBE_SNAP_FUNDS;
							_aicomSupply = _aicomSnap select WFBE_SNAP_SUPPLY;
							_aicomTowns = _aicomSnap select WFBE_SNAP_MYTOWNS;
							_aicomTeamDigest = _aicomSnap select WFBE_SNAP_TEAMS;
							_aicomTeams = count _aicomTeamDigest;
						} else {
							_aicomFunds = (_aicomSide) Call GetAICommanderFunds;
							_aicomSupply = (_aicomSide) Call WFBE_CO_FNC_GetSideSupply;
							_aicomTowns = (_aicomSide) Call GetTownsHeld;
							if (!isNil "_aicomLogic" && {!isNull _aicomLogic}) then {_aicomTeams = count (_aicomLogic getVariable ["wfbe_teams", []])};
						};
						_aicomCas = WF_Logic getVariable [Format ["%1Casualties", _aicomSideText], 0];
						_aicomVeh = WF_Logic getVariable [Format ["%1VehiclesLost", _aicomSideText], 0];
						_aicomMade = WF_Logic getVariable [Format ["%1UnitsCreated", _aicomSideText], 0];
						_aicomKilled = WF_Logic getVariable [Format ["%1KilledEnemy", _aicomSideText], 0];
						diag_log ("AICOMSTAT|v2|FINAL|" + _aicomSideText + "|" + str _aicomElMin + "|winner=" + str _winSide + "|durationSec=" + str _aicomRoundSec + "|cas=" + str _aicomCas + "|vehLost=" + str _aicomVeh + "|made=" + str _aicomMade + "|killed=" + str _aicomKilled + "|funds=" + str _aicomFunds + "|supply=" + str _aicomSupply + "|towns=" + str _aicomTowns + "|foundedTeams=" + str _aicomTeams + "|world=" + worldName);
					} forEach WFBE_PRESENTSIDES - [WFBE_DEFENDER];

					diag_log ("WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|ROUNDEND|" + str _winSide + "|" + str _aicomRoundSec + "|" + worldName);
				};

				//--- MATCH|v1|END|: single match-facts summary for Stats V2. _winSide reused from
				//--- the victory block; durationSec and town counts are recomputed independently
				//--- (so END is correct regardless of WFBE_C_STATLOG). Gated on WFBE_C_MATCH_TELEMETRY (default 1).
				if ((missionNamespace getVariable ["WFBE_C_MATCH_TELEMETRY", 1]) > 0) then {
					private ["_meWTowns","_meETowns","_meGTowns","_meWCas","_meECas","_meWVeh","_meEVeh","_mePlayers","_meDurationSec"];
					_meDurationSec = round(time);
					_meWTowns  = west  Call GetTownsHeld;
					_meETowns  = east  Call GetTownsHeld;
					_meGTowns  = resistance Call GetTownsHeld;
					_meWCas    = WF_Logic getVariable ["WESTCasualties",  0];
					_meECas    = WF_Logic getVariable ["EASTCasualties",  0];
					_meWVeh    = WF_Logic getVariable ["WESTVehiclesLost", 0];
					_meEVeh    = WF_Logic getVariable ["EASTVehiclesLost", 0];
					_mePlayers = { isPlayer _x } count playableUnits;
					diag_log ("MATCH|v1|END|winner=" + str _winSide
						+ "|durationSec=" + str _meDurationSec
						+ "|world=" + worldName
						+ "|townsW=" + str _meWTowns
						+ "|townsE=" + str _meETowns
						+ "|townsG=" + str _meGTowns
						+ "|casW=" + str _meWCas
						+ "|casE=" + str _meECas
						+ "|vehLostW=" + str _meWVeh
						+ "|vehLostE=" + str _meEVeh
						+ "|players=" + str _mePlayers
						+ "|totalTowns=" + str _total);
					["INFORMATION", Format ["server_victory_threeway.sqf: MATCH|v1|END| emitted - winner=%1 duration=%2s.", str _winSide, _meDurationSec]] Call WFBE_CO_FNC_LogContent;
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
