// Server-only. Buffers a per-player stat delta into missionNamespace. O(1), no IPC, no disk.
// No-op when stats are disabled or the UID is empty (e.g. a headless client). Arma 2 dialect.
// Defines:
//   [uid, statIndex, amount=1] call WFBE_SE_FNC_RecordStat
//   [uid, sideNumber]          call WFBE_SE_FNC_RecordStatSide   // 1 west, 2 east, 0 none

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
	if (_uid == "") exitWith {false};
	!(isNil {missionNamespace getVariable [Format ["WFBE_HEADLESS_%1", _uid], nil]})
};

WFBE_SE_FNC_RecordStat = {
	private ["_uid","_statIndex","_amount","_key","_buf"];
	if (isNil "WFBE_C_STATS_ENABLED") exitWith {};
	if (!WFBE_C_STATS_ENABLED) exitWith {};
	_uid = _this select 0;
	_statIndex = _this select 1;
	_amount = if (count _this > 2) then { _this select 2 } else { 1 };
	if (isNil "_uid") exitWith {};
	if (_uid == "") exitWith {};
	if (_uid call WFBE_SE_FNC_IsHeadlessUid) exitWith {};
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
	if (_uid call WFBE_SE_FNC_IsHeadlessUid) exitWith {};
	missionNamespace setVariable ["WFBE_STAT_SIDE_" + _uid, _sideNum];
	if (!(_uid in WFBE_STATS_DIRTY_UIDS)) then { WFBE_STATS_DIRTY_UIDS set [count WFBE_STATS_DIRTY_UIDS, _uid]; };
};
