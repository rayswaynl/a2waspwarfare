/*
	TEAMBAR-FIRST SERVER-SIDE SHARED REJOIN (fable/player-teambar-slot, server heal 2026-07-22).

	Root cause: AI Teams pre-groups a fresh player with a mission-start AI squadmate. The CLIENT
	slot1-rejoin (Init_Client.sqf ~1249 / Client_OnKilled.sqf ~154) only re-joins CLIENT-LOCAL AI
	(join needs locality). A mission-start AI squadmate created at server init is SERVER-local, so
	the client reorder collapses into its "rejoin-no-local-others" no-op both at a FRESH CONNECT and
	again on every RESPAWN, leaving the AI at array index 0 - the player renders as #2 in their own
	command bar. This function runs the SAME createGroup/joinSilent dance server-side, where every
	unit of _tbTeam is guaranteed local.

	Shared by two call sites so the reorder mechanics never drift apart:
		- Server_OnPlayerConnected.sqf (fresh connect / JIP): resolves the human unit itself
		  (clientBody-first, UID-scan fallback) before calling in.
		- Server_HandleSpecial.sqf "update-teamleader" case (Init_Client.sqf connect-ping AND
		  Client_OnKilled.sqf respawn-ping): already holds the human's own networked body directly
		  as _leader, so it is passed straight through - no rescan needed there.

	Parameters (array):
		0: _tbTeam  - GROUP, the human's group.
		1: _tbHuman - OBJECT, the human unit (caller-resolved).
		2: _tbUid   - STRING, the human's UID (log context only).
		3: _tbName  - STRING, the human's name (log context only).
		4: _tbEvt   - STRING, free-form call-site tag for the RPT line (e.g. "connect", "teamleader-update").

	Returns nothing. EVERY path (success, every skip reason, temp-group create failure) diag_logs,
	so a recurrence is diagnosable from RPT without re-instrumenting.

	A2-OA-1.64-safe: array-form Private, no inline private, no pushBack/findIf/params, no
	array-form select/sort/reveal, exitWith only directly after if(...).
*/
Private ["_tbTeam","_tbHuman","_tbUid","_tbName","_tbEvt","_tbOthers","_tbTmp","_tbSkip"];
_tbTeam = _this select 0;
_tbHuman = _this select 1;
_tbUid = _this select 2;
_tbName = _this select 3;
_tbEvt = _this select 4;

_tbSkip = "";
if (isNull _tbTeam) then {_tbSkip = "team-null"};
if (_tbSkip == "" && {isNull _tbHuman}) then {_tbSkip = "human-null"};
//--- NOT-MEMBER guard (round-3 adversarial review 2026-07-22): the update-teamleader call site passes the
//--- client-cached WFBE_Client_Team + player straight from the network ping (Init_Client.sqf ~688 /
//--- Client_OnKilled.sqf ~134 / SkinSelector_Apply.sqf), which can go stale versus the human's real group.
//--- A2 OA 1.64 selectLeader has no implicit-join safety net (added only in A3 v2.21), so selecting a
//--- non-member leader would leave (leader _tbTeam) pointing at a dangling unit and can crash if that unit
//--- is later deleted. The client guards this with its own group-identity check; mirror it here so we only
//--- ever selectLeader a confirmed member. (The connect call site already restricts _tbHuman to units _tbTeam.)
if (_tbSkip == "" && {!(_tbHuman in (units _tbTeam))}) then {_tbSkip = "not-member"};

if (_tbSkip != "") exitWith {
	diag_log Format ["[WFBE][TEAMBAR-SRV] %1 slot1-rejoin: skipped (%2) for [%3] [%4].", _tbEvt, _tbSkip, _tbName, _tbUid];
};

//--- ASSERT LEADER FIRST (round-3 review 2026-07-22, fix/teambar-slot1-ship): match the CLIENT pattern
//--- (Init_Client.sqf ~1234 / Client_OnKilled.sqf ~138-141) which selectLeader-s the human BEFORE its
//--- rejoin. At a FRESH CONNECT the mission-start AI squadmate is still the engine leader of the
//--- pre-grouped team (the client selectLeader assert at Init_Client.sqf ~1234 runs AFTER the ~688
//--- update-teamleader ping that reaches this function), so the previous "not-leader" skip no-op-ed the
//--- heal EXACTLY when it was needed. Membership is confirmed above, so this selectLeader is safe; then
//--- let the index-0 check decide whether a slot renumber is still required.
if ((leader _tbTeam) != _tbHuman) then {_tbTeam selectLeader _tbHuman};
if (((units _tbTeam) select 0) == _tbHuman) exitWith {
	diag_log Format ["[WFBE][TEAMBAR-SRV] %1 slot1-rejoin: skipped (already-index-0) for [%2] [%3].", _tbEvt, _tbName, _tbUid];
};

_tbOthers = [];
{if (alive _x && {!isPlayer _x} && {_x != _tbHuman}) then {_tbOthers set [count _tbOthers, _x]}} forEach (units _tbTeam);
if (count _tbOthers == 0) exitWith {
	diag_log Format ["[WFBE][TEAMBAR-SRV] %1 slot1-rejoin: index-0 occupant is not the human but no AI squadmate qualified (another player at slot 0?) for [%2] [%3] - left untouched.", _tbEvt, _tbName, _tbUid];
};

_tbTmp = createGroup (side _tbTeam);
if (isNull _tbTmp) exitWith {
	diag_log Format ["[WFBE][TEAMBAR-SRV] %1 slot1-rejoin: createGroup null for [%2] [%3] - skipped.", _tbEvt, _tbName, _tbUid];
};
diag_log Format ["[WFBE][TEAMBAR-SRV] %1 slot1-rejoin: temp group %2 created for %3 AI squadmate(s), [%4] [%5].", _tbEvt, _tbTmp, count _tbOthers, _tbName, _tbUid];
_tbOthers joinSilent _tbTmp;
_tbOthers joinSilent _tbTeam;
if (count units _tbTmp == 0) then {deleteGroup _tbTmp};
_tbTeam selectLeader _tbHuman;
diag_log Format ["[WFBE][TEAMBAR-SRV] %1 slot1-rejoin: %2 AI squadmate(s) re-joined behind [%3] [%4].", _tbEvt, count _tbOthers, _tbName, _tbUid];
