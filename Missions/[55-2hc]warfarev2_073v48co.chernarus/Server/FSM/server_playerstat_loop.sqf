/* server_playerstat_loop.sqf — periodic per-player leaderboard snapshot emit (claude-gaming 2026-06-14).

   Every WFBE_C_PLAYERSTAT_INTERVAL seconds, emit ONE PLAYERSTAT line per connected human player.
   This is the ONLY telemetry that carries the player display NAME (every other WASPSTAT line is
   UID-only), so it is what lets the public dashboard map UID -> name -> score -> side for the
   Top-Players leaderboard. Score is the engine score of the player object (the authoritative
   per-player score in WFBE; see RequestChangeScore.sqf). Kills/deaths are emitted as 0 here and
   are derived dashboard-side by folding the already-emitted WASPSTAT|...|KILL stream per UID, so
   this loop adds NO new server state and stays engine-cheap.

   Wire format (shares WFBE_WASPSTAT_SEQ with the other v1 emitters so records stay ordered):
     PLAYERSTAT|v1|<seq>|<name>|<uid>|<side>|<score>|<kills>|<deaths>|t=<roundMinutes>
   - name : `name _x`, with any "|" stripped to protect the delimiter.
   - uid  : `getPlayerUID _x`; rows with "" UID are skipped (HCs/AI return "").
   - side : 1=WEST, 2=EAST, 0=other (same numeric encoding as StatsFlush.sqf).
   - score: `score _x` (engine score).
   - first emit is after one full interval (no t=0 boot spam).

   Reuses the always-on WFBE_C_STATLOG gate so it ships without touching the OFF-by-default
   WFBE_C_STATS_ENABLED buffer path. Spawned from Server\Init\Init_Server.sqf only when
   WFBE_C_PLAYERSTAT_ENABLED==1.
*/
scriptName "Server\FSM\server_playerstat_loop.sqf";

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_PLAYERSTAT_ENABLED", 1]) != 1) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) != 1) exitWith {};

private ["_interval"];

_interval = missionNamespace getVariable ["WFBE_C_PLAYERSTAT_INTERVAL", 60];
if (_interval < 30) then {_interval = 30}; //--- floor: never emit faster than every 30s.

// Initialise the shared sequence counter once (other emitters may start it first).
if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };

["INITIALIZATION", Format ["server_playerstat_loop.sqf: Armed. Emitting PLAYERSTAT rows every %1s.", _interval]] Call WFBE_CO_FNC_LogContent;

while {true} do {
	sleep _interval;                                   //--- wait first, so we do not spam at t=0 boot.

	private ["_hcs","_min","_players"];
	_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	_min = round (time / 60);

	//--- Connected humans only: BIS_fnc_listPlayers minus registered HC group leaders. The
	//--- getPlayerUID!="" guard below is a second HC/AI safety net (HCs return "" for UID).
	_players = (call BIS_fnc_listPlayers) - _hcs;

	{
		//--- Capture the player into _p so the inner char-strip forEach (_x = char code) never
		//--- shadows the player object we still need afterwards.
		private ["_p","_uid","_name","_side","_score","_line","_chars","_clean"];
		_p = _x;
		if (isPlayer _p) then {
			_uid = getPlayerUID _p;
			if (_uid != "" && {!((group _p) in _hcs)}) then {
				//--- Strip the "|" delimiter (ASCII 124) from the name so it can't break the row.
				_name  = name _p;
				_chars = toArray _name;
				_clean = [];
				{ if (_x != 124) then { _clean set [count _clean, _x] }; } forEach _chars;
				_name  = toString _clean;
				_side  = switch (side _p) do { case west: {1}; case east: {2}; case resistance: {3}; default {0} };
				_score = score _p;

				WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
				_line = "PLAYERSTAT|v1|" + (str WFBE_WASPSTAT_SEQ) + "|" + _name + "|" + _uid + "|" + (str _side) + "|" + (str _score) + "|0|0|t=" + (str _min) + "|td=" + (str (_p getVariable ["wfbe_guer_td", 0]));
				diag_log _line;
			};
		};
	} forEach _players;
};
