// Server-only. Buffers a per-player stat delta into missionNamespace. O(1), no IPC, no disk.
// No-op when stats are disabled or the UID is empty (e.g. a headless client). Arma 2 dialect.
// Defines:
//   [uid, statIndex, amount=1] call WFBE_SE_FNC_RecordStat
//   [uid, sideNumber]          call WFBE_SE_FNC_RecordStatSide   // 1 west, 2 east, 0 none

WFBE_SE_FNC_RecordStat = {
	private ["_uid","_statIndex","_amount","_key","_buf"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	_uid = _this select 0;
	_statIndex = _this select 1;
	_amount = if (count _this > 2) then { _this select 2 } else { 1 };
	if (isNil "_uid") exitWith {};
	if (_uid == "") exitWith {};
	if (_amount == 0) exitWith {};

	_key = "WFBE_STAT_BUF_" + _uid;
	_buf = missionNamespace getVariable [_key, []];
	if (count _buf < WFBE_STAT_FIELD_COUNT) then {
		_buf = [];
		for "_i" from 1 to WFBE_STAT_FIELD_COUNT do { _buf set [count _buf, 0]; };
	};
	_buf set [_statIndex, (_buf select _statIndex) + _amount];
	missionNamespace setVariable [_key, _buf];
	if (!(_uid in WFBE_STATS_DIRTY_UIDS)) then { WFBE_STATS_DIRTY_UIDS set [count WFBE_STATS_DIRTY_UIDS, _uid]; };
};

WFBE_SE_FNC_RecordStatSide = {
	private ["_uid","_sideNum"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	_uid = _this select 0;
	_sideNum = _this select 1;
	if (isNil "_uid") exitWith {};
	if (_uid == "") exitWith {};
	missionNamespace setVariable ["WFBE_STAT_SIDE_" + _uid, _sideNum];
	if (!(_uid in WFBE_STATS_DIRTY_UIDS)) then { WFBE_STATS_DIRTY_UIDS set [count WFBE_STATS_DIRTY_UIDS, _uid]; };
};
