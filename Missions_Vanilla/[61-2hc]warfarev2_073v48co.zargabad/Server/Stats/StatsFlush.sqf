// Server-only flush loop (Arma 2 dialect). Every WFBE_C_STATS_FLUSH_INTERVAL seconds: credit
// playtime + current side to each connected player, then emit ONE batched WASPSTAT line to the
// RPT and zero the buffers. The DiscordBot tails the RPT, accumulates lifetime totals, writes
// stats.json. Wire format: WASPSTAT|v1|<seq>|<uid>:<d0..d14>,<side>~name|<uid2>:...
//
// SEQ: WFBE_WASPSTAT_SEQ is a shared server global so that KILL/CAPTURE/ROUNDEND emitters
// (Task 10) share one ordered sequence across all WASPSTAT v1 record types.
//
// r78: body lives in RecordStat.sqf (WFBE_SE_FNC_CreditPlaytimeConnected / FlushStatsDirty) so
// ROUNDEND + disconnect can force the same emit path without racing the interval sleep.

if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
if (!WFBE_C_STATS_ENABLED) exitWith {};

// Initialise the shared sequence counter once (other emitters may start it first).
if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };

while {true} do {
	sleep WFBE_C_STATS_FLUSH_INTERVAL;

	// 1) Credit playtime + record current side for every connected human player.
	[] call WFBE_SE_FNC_CreditPlaytimeConnected;

	// 2) Build and emit one line for all dirty UIDs, then reset (no-op when empty / all purged).
	[] call WFBE_SE_FNC_FlushStatsDirty;
};
