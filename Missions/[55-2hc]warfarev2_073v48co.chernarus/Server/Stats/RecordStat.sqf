// Server-only. Buffers a per-player stat delta into missionNamespace. O(1), no IPC, no disk.
// No-op when stats are disabled or the UID is empty (e.g. a headless client). Arma 2 dialect.
// Defines:
//   [uid, statIndex, amount=1] call WFBE_SE_FNC_RecordStat
//   [uid, sideNumber]          call WFBE_SE_FNC_RecordStatSide   // 1 west, 2 east, 0 none
//   [] call WFBE_SE_FNC_CreditPlaytimeConnected   // playtime+side+name for live humans
//   [] call WFBE_SE_FNC_FlushStatsDirty           // emit dirty WASPSTAT|v1 batch (or no-op)

//--- HC-UID EXCLUSION (card wasp-zg-civ-hc-slots-20260719). A headless client IS an isPlayer unit,
//--- and Server\Functions\Server_HandleSpecial.sqf (connected-hc) states outright that "A2 HCs can
//--- report an empty/shared UID" - so the historical `_uid != ""` test below is NOT a reliable HC
//--- filter. When an HC does report a non-empty UID its rows enter WASPSTAT exactly like a human's
//--- (owner live report 2026-07-19: HC UID rows inside WASPSTAT lines). The connected-hc handler
//--- already stamps a durable per-uid marker (WFBE_HEADLESS_<uid>) that
//--- Server\Functions\Server_OnPlayerConnected.sqf calls "the SOLE HC-identification gate"; reuse
//--- that stamp here. O(1), no new state, no change to the HC registration path itself.
WFBE_SE_FNC_IsHeadlessUid = {
	private "_uid";
	_uid = _this;
	if (isNil "_uid") exitWith {false};
	if (typeName _uid != "STRING") exitWith {false};
	if (_uid == "") exitWith {false};
	!(isNil {missionNamespace getVariable [Format ["WFBE_HEADLESS_%1", _uid], nil]})
};

//--- r78: strip wire-format delimiters from player display names before WASPSTAT/PLAYERSTAT payload
//--- attach. PLAYERSTAT already stripped "|" (ASCII 124); StatsFlush historically appended the raw
//--- name after "~" so a name containing "|" or "~" forked the multi-UID line / name trailer for
//--- the DiscordBot RPT parser. Same A2-OA-safe toArray/toString strip as server_playerstat_loop.
WFBE_SE_FNC_SanitizeStatName = {
	private ["_name","_chars","_clean"];
	_name = _this;
	if (isNil "_name") exitWith {""};
	if (typeName _name != "STRING") exitWith {""};
	_chars = toArray _name;
	_clean = [];
	//--- 124='|'  126='~'  10=LF  13=CR — keep the rest (incl. non-ASCII) intact.
	{ if (!(_x in [124, 126, 10, 13])) then { _clean set [count _clean, _x] }; } forEach _chars;
	toString _clean
};

WFBE_SE_FNC_RecordStat = {
	private ["_uid","_statIndex","_amount","_key","_buf","_fieldCount"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	if (isNil "WFBE_STAT_FIELD_COUNT") exitWith {};
	if (isNil "WFBE_STATS_DIRTY_UIDS") then { WFBE_STATS_DIRTY_UIDS = []; };
	if (typeName _this != "ARRAY") exitWith {};
	if ((count _this) < 2) exitWith {};
	_uid = _this select 0;
	_statIndex = _this select 1;
	_amount = if (count _this > 2) then { _this select 2 } else { 1 };
	if (isNil "_uid") exitWith {};
	if (typeName _uid != "STRING") exitWith {};
	if (_uid == "") exitWith {};
	if (_uid call WFBE_SE_FNC_IsHeadlessUid) exitWith {};
	//--- r78: OOB / non-scalar index used to throw on `select` and kill the caller (kill/capture/
	//--- build paths). Fail-clean instead of poisoning RequestOnUnitKilled / town capture.
	if (isNil "_statIndex") exitWith {};
	if (typeName _statIndex != "SCALAR") exitWith {};
	_fieldCount = WFBE_STAT_FIELD_COUNT;
	if (typeName _fieldCount != "SCALAR") exitWith {};
	if (_statIndex < 0 || {_statIndex >= _fieldCount}) exitWith {};
	if (isNil "_amount") exitWith {};
	if (typeName _amount != "SCALAR") exitWith {};
	if (_amount == 0) exitWith {};

	_key = "WFBE_STAT_BUF_" + _uid;
	_buf = missionNamespace getVariable [_key, []];
	if (count _buf < _fieldCount) then {
		_buf = [];
		for "_i" from 1 to _fieldCount do { _buf set [count _buf, 0]; };
	};
	_buf set [_statIndex, (_buf select _statIndex) + _amount];
	missionNamespace setVariable [_key, _buf];
	if (!(_uid in WFBE_STATS_DIRTY_UIDS)) then { WFBE_STATS_DIRTY_UIDS set [count WFBE_STATS_DIRTY_UIDS, _uid]; };
};

WFBE_SE_FNC_RecordStatSide = {
	private ["_uid","_sideNum"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	if (isNil "WFBE_STATS_DIRTY_UIDS") then { WFBE_STATS_DIRTY_UIDS = []; };
	if (typeName _this != "ARRAY") exitWith {};
	if ((count _this) < 2) exitWith {};
	_uid = _this select 0;
	_sideNum = _this select 1;
	if (isNil "_uid") exitWith {};
	if (typeName _uid != "STRING") exitWith {};
	if (_uid == "") exitWith {};
	if (_uid call WFBE_SE_FNC_IsHeadlessUid) exitWith {};
	if (isNil "_sideNum") exitWith {};
	if (typeName _sideNum != "SCALAR") exitWith {};
	missionNamespace setVariable ["WFBE_STAT_SIDE_" + _uid, _sideNum];
	if (!(_uid in WFBE_STATS_DIRTY_UIDS)) then { WFBE_STATS_DIRTY_UIDS set [count WFBE_STATS_DIRTY_UIDS, _uid]; };
};

//--- Credit one full flush-interval of playtime + current side + name cache for every connected human.
//--- Shared by the periodic StatsFlush loop and the terminal ROUNDEND flush.
WFBE_SE_FNC_CreditPlaytimeConnected = {
	private ["_interval","_uid","_sideNum","_nm"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	_interval = if (isNil "WFBE_C_STATS_FLUSH_INTERVAL") then {60} else {WFBE_C_STATS_FLUSH_INTERVAL};
	if (typeName _interval != "SCALAR") then {_interval = 60};
	if (_interval <= 0) then {_interval = 60};
	{
		// cmdcon41 (P0-5): HC-FILTER AT SOURCE. A headless client is an isPlayer unit but is NOT a human
		// participant - crediting it here leaks a phantom "HC" entry into WASPSTAT -> leaderboard/report.
		// Skip any unit whose name is a known HC name (A2-OA-safe exact `in` check - no A3 string find/substring).
		if ((isPlayer _x) && {!((name _x) in WFBE_C_HC_NAMES)}) then {
			_uid = getPlayerUID _x;
			//--- Stamp check in addition to the name list above. The name list is now the single shared
			//--- WFBE_C_HC_NAMES (Init_CommonConstants.sqf) rather than one of several drifting literals,
			//--- but this stays as defence in depth: WFBE_HEADLESS_<uid> is set by connected-hc
			//--- registration and does not depend on the HC's profile name at all.
			if ((_uid != "") && {!(_uid call WFBE_SE_FNC_IsHeadlessUid)}) then {
				[_uid, WFBE_STAT_PLAYTIME, _interval] call WFBE_SE_FNC_RecordStat;
				_sideNum = switch (side _x) do { case west: {1}; case east: {2}; case resistance: {3}; default {0} };
				[_uid, _sideNum] call WFBE_SE_FNC_RecordStatSide;
				//--- PR#84 + r78: cache sanitized display name for the next flush segment.
				_nm = (name _x) call WFBE_SE_FNC_SanitizeStatName;
				missionNamespace setVariable ["WFBE_STAT_NAME_" + _uid, _nm];
			};
		};
	} forEach (call BIS_fnc_listPlayers);
};

//--- Emit ONE batched WASPSTAT|v1 line for all dirty UIDs, then clear dirty set.
//--- r78: only diag_log (and burn a sequence number) when at least one UID segment was appended —
//--- HC purge / empty-buffer dirty rows used to emit a bare "WASPSTAT|v1|<seq>" header that the
//--- ingest pipeline treated as a corrupt/empty batch.
//--- Optional _this: [uid, name] to stamp a disconnecting player's name before emit (name object gone).
WFBE_SE_FNC_FlushStatsDirty = {
	private ["_line","_uid","_buf","_sideNum","_csv","_name","_segments","_stampUid","_stampName","_fieldCount"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	if (isNil "WFBE_STATS_DIRTY_UIDS") then { WFBE_STATS_DIRTY_UIDS = []; };
	if (isNil "WFBE_STAT_FIELD_COUNT") exitWith {};
	_fieldCount = WFBE_STAT_FIELD_COUNT;
	if (typeName _fieldCount != "SCALAR") exitWith {};

	//--- Optional disconnect stamp: [uid, name] so the last segment still carries a display name.
	if (!isNil "_this" && {typeName _this == "ARRAY"} && {(count _this) >= 2}) then {
		_stampUid = _this select 0;
		_stampName = _this select 1;
		if (!(isNil "_stampUid") && {typeName _stampUid == "STRING"} && {_stampUid != ""}) then {
			if (!(isNil "_stampName") && {typeName _stampName == "STRING"}) then {
				missionNamespace setVariable ["WFBE_STAT_NAME_" + _stampUid, _stampName call WFBE_SE_FNC_SanitizeStatName];
			};
		};
	};

	if (count WFBE_STATS_DIRTY_UIDS == 0) exitWith {};

	if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
	_segments = 0;
	_line = "";
	{
		_uid = _x;
		_buf = missionNamespace getVariable ["WFBE_STAT_BUF_" + _uid, []];
		//--- HC RETROACTIVE PURGE: RecordStat now refuses stamped HC uids, but rows can still be
		//--- buffered during the transient window between an HC connecting and connected-hc
		//--- registration stamping it (card: transient EAST player-team enrollment window).
		//--- Emptying _buf here drops the uid: the emit block below needs WFBE_STAT_FIELD_COUNT
		//--- entries and skips it. No exitWith - that would abort the whole forEach, not one pass.
		if (_uid call WFBE_SE_FNC_IsHeadlessUid) then {
			_buf = [];
			missionNamespace setVariable ["WFBE_STAT_BUF_" + _uid, nil];
			missionNamespace setVariable ["WFBE_STAT_SIDE_" + _uid, nil];
			missionNamespace setVariable ["WFBE_STAT_NAME_" + _uid, nil];
			diag_log ("HCSTAT|v1|PURGE|" + _uid + "|buffered rows dropped: uid is a registered headless client");
		};
		if (count _buf >= _fieldCount) then {
			_sideNum = missionNamespace getVariable ["WFBE_STAT_SIDE_" + _uid, 0];
			_csv = "";
			{ _csv = _csv + (str _x) + ","; } forEach _buf;   // 15 deltas
			_csv = _csv + (str _sideNum);                      // + trailing side
			//--- PR#84 + r78: append ~<sanitized-name> after the numeric csv+side.
			_name = missionNamespace getVariable ["WFBE_STAT_NAME_" + _uid, ""];
			if (typeName _name != "STRING") then {_name = ""};
			_name = _name call WFBE_SE_FNC_SanitizeStatName;
			if (_segments == 0) then {
				WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
				_line = "WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ;
			};
			_line = _line + "|" + _uid + ":" + _csv + "~" + _name;
			_segments = _segments + 1;
			missionNamespace setVariable ["WFBE_STAT_BUF_" + _uid, nil];   // clear buffer (delta sent)
			missionNamespace setVariable ["WFBE_STAT_NAME_" + _uid, nil]; //--- PR#84: clear cached name.
		};
	} forEach WFBE_STATS_DIRTY_UIDS;
	WFBE_STATS_DIRTY_UIDS = [];

	if (_segments > 0) then {
		diag_log _line;
	};
};

//--- Terminal / one-shot: credit live playtime then flush every dirty buffer. Used at ROUNDEND
//--- so the last interval is not lost when ENDGAME_HOLD < FLUSH_INTERVAL and failMission races the loop.
WFBE_SE_FNC_FlushStatsTerminal = {
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	[] call WFBE_SE_FNC_CreditPlaytimeConnected;
	[] call WFBE_SE_FNC_FlushStatsDirty;
};
