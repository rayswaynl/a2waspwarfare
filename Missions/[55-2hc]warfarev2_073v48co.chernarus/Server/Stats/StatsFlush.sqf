// Server-only flush loop (Arma 2 dialect). Every WFBE_C_STATS_FLUSH_INTERVAL seconds: credit
// playtime + current side to each connected player, then emit ONE batched WASPSTAT line to the
// RPT and zero the buffers. The DiscordBot tails the RPT, accumulates lifetime totals, writes
// stats.json. Wire format: WASPSTAT|v1|<seq>|<uid>:<d0..d14>,<side>|<uid2>:...
//
// SEQ: WFBE_WASPSTAT_SEQ is a shared server global so that KILL/CAPTURE/ROUNDEND emitters
// (Task 10) share one ordered sequence across all WASPSTAT v1 record types.

if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
if (!WFBE_C_STATS_ENABLED) exitWith {};

// Initialise the shared sequence counter once (other emitters may start it first).
if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };

while {true} do {
	sleep WFBE_C_STATS_FLUSH_INTERVAL;

	// 1) Credit playtime + record current side for every connected human player.
	{
		if (isPlayer _x) then {
			private ["_uid","_sideNum"];
			_uid = getPlayerUID _x;
			if (_uid != "") then {
				[_uid, WFBE_STAT_PLAYTIME, WFBE_C_STATS_FLUSH_INTERVAL] call WFBE_SE_FNC_RecordStat;
				_sideNum = switch (side _x) do { case west: {1}; case east: {2}; case resistance: {3}; default {0} };
				[_uid, _sideNum] call WFBE_SE_FNC_RecordStatSide;
			};
		};
	} forEach (call BIS_fnc_listPlayers);

	// 2) Build and emit one line for all dirty UIDs, then reset.
	if (count WFBE_STATS_DIRTY_UIDS > 0) then {
		private "_line";
		WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
		_line = "WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ;
		{
			private ["_uid","_buf","_sideNum","_csv"];
			_uid = _x;
			_buf = missionNamespace getVariable ["WFBE_STAT_BUF_" + _uid, []];
			if (count _buf >= WFBE_STAT_FIELD_COUNT) then {
				_sideNum = missionNamespace getVariable ["WFBE_STAT_SIDE_" + _uid, 0];
				_csv = "";
				{ _csv = _csv + (str _x) + ","; } forEach _buf;   // 15 deltas
				_csv = _csv + (str _sideNum);                      // + trailing side
				_line = _line + "|" + _uid + ":" + _csv;
				missionNamespace setVariable ["WFBE_STAT_BUF_" + _uid, nil];   // clear buffer (delta sent)
			};
		} forEach WFBE_STATS_DIRTY_UIDS;
		WFBE_STATS_DIRTY_UIDS = [];

		diag_log _line;
	};
};
