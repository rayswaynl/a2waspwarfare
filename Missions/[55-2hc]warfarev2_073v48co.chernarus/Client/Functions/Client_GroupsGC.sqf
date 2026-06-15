// Client\Functions\Client_GroupsGC.sqf
// Marty/claude-gaming (2026-06-14): client-LOCAL empty-group reaper. A2 OA has a hard ~144
// groups/side cap; empty groups are not auto-reclaimed. A chunk of leaked empties are
// CLIENT-OWNED (created with client locality, orphaned empty when a player disconnects).
// deleteGroup only reaps a group that is EMPTY *and* LOCAL to the executing machine, so the
// server/HC GC (server_groupsGC.sqf) silently no-ops on these. Each player client reaps its
// OWN local empty groups here. Complements (does not duplicate) the server sweep and the
// event-driven delegated-town cleanup (Client_CleanupDelegatedTownAI.sqf).
//
// claude-gaming (2026-06-15): this ALSO runs on HEADLESS CLIENTS. An HC owns ~12-16 delegated
// commander-team / town groups that are LOCAL to it. Their lifecycle self-reap
// (Common_RunCommanderTeam.sqf:789 deleteGroup _team) fires when GetLiveUnits==0, but that
// deleteGroup NO-OPs if dead-but-not-yet-engine-collected corpses still sit in `units _team`
// (deleteGroup needs the group truly EMPTY). The corpse husk is then HC-local and empty, and
// nothing on the HC ever retries it: the server GC (server_groupsGC.sqf) deleteGroup no-ops on
// non-server-local groups, and this reaper used to be hasInterface-gated OFF on an HC
// (hasInterface==false on a headless client). Result = HC empty-group LEAK toward the 144/side
// cap. So the gate is broadened: run on a player client (hasInterface) OR on a headless client
// (isMultiplayer && !isServer && !hasInterface). The body is HC-safe as-is: `player` is the HC's
// own civilian unit, `group player` is its civilian infra group (always skipped below), the
// debounce + persistent + WFBE_CL_TownAI_Groups-tracked guards protect live/delegated teams, and
// _cliId already mirrors HC_StatLoop's HC-<netId>. The DEDICATED SERVER (isServer, no interface)
// is still excluded - it has its own server_groupsGC.sqf.
WFBE_GC_IsHC = isMultiplayer && {!isServer} && {!hasInterface};
if (!hasInterface && {!WFBE_GC_IsHC}) exitWith {}; // run on player clients + HCs; skip the dedicated server (server has server_groupsGC.sqf)
waitUntil {commonInitComplete};

Private ["_cliId","_dbN","_scanned","_emptyLocal","_reaped","_confirmedGone","_skipPers","_skipTracked","_cands","_grp","_ldr","_p","_since","_reg","_tracked"];

// On an HC, mirror HC_StatLoop.sqf's "HC-<netId>" so its reaped lines line up with HCSTAT.
// On a player client, keep the original "CL-<netId>" tag. Either way it is a stable per-process id.
_cliId = format ["%1-%2", (if (WFBE_GC_IsHC) then {"HC"} else {"CL"}), netId player];
_dbN   = missionNamespace getVariable ["WFBE_C_CLIENT_GROUPGC_DEBOUNCE", 10]; // stable-empty seconds (>= 2x the 5s town deadline)

["INFORMATION", Format ["Client_GroupsGC.sqf: %1 empty-group reaper started (%2)", (if (WFBE_GC_IsHC) then {"headless-client"} else {"client"}), _cliId]] Call WFBE_CO_FNC_LogContent;

while {!WFBE_GameOver} do {
    sleep 60;

    _scanned = 0; _emptyLocal = 0; _reaped = 0; _confirmedGone = 0; _skipPers = 0; _skipTracked = 0;
    _cands = [];
    _reg = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []]; // delegated-town groups: handled elsewhere

    // --- Pass 1: scan + debounce-stamp; collect stably-empty local candidates ---
    {
        _grp = _x;
        _scanned = _scanned + 1;
        if (!isNull _grp && {_grp != group player} && {(count units _grp) == 0}) then {
            _ldr = leader _grp;                               // empty group may have a null leader
            if (local _ldr || isNull _ldr) then {             // A2 OA: test the leader, never the group (local <group> throws)
                _emptyLocal = _emptyLocal + 1;
                _p = _grp getVariable "wfbe_persistent";      // group getVariable: single-arg = universally safe
                if (isNil "_p") then {_p = false};
                if (_p) then {
                    _skipPers = _skipPers + 1;
                } else {
                    _tracked = false;
                    { if (count _x >= 3 && {(_x select 2) == _grp}) exitWith {_tracked = true} } forEach _reg;
                    if (_tracked) then {
                        _skipTracked = _skipTracked + 1;
                    } else {
                        _since = _grp getVariable "wfbe_emptySince";
                        if (isNil "_since") then {_since = -1};
                        if (_since < 0) then {
                            _grp setVariable ["wfbe_emptySince", time];   // first seen empty: stamp + wait out debounce
                        } else {
                            if (time - _since >= _dbN) then {_cands = _cands + [_grp]};
                        };
                    };
                };
            };
        } else {
            // re-filled (or player group): clear any stale stamp so a future empty re-debounces from scratch
            if (!isNull _grp && {(count units _grp) > 0}) then {_grp setVariable ["wfbe_emptySince", nil]};
        };
    } forEach allGroups;

    // --- Pass 2: delete candidates (never mutate allGroups mid-iteration) ---
    {
        // re-confirm immediately before deleting (ownership/fill could have changed during pass 1)
        if (!isNull _x && {_x != group player} && {(count units _x) == 0} && {local (leader _x) || isNull (leader _x)}) then {
            deleteGroup _x;
            _reaped = _reaped + 1;
            if (isNull _x) then {_confirmedGone = _confirmedGone + 1};   // confirmedGone proof: husk actually gone
        };
    } forEach _cands;

    if (_reaped > 0) then {
        // Machine-parsed wire line (distinct tag from the server's EMPTYGRP|v1|). t = round minutes (house style).
        diag_log ("CLIENT_EMPTY_GROUP_CLEANUP|v1|" + _cliId
            + "|scanned=" + str _scanned
            + "|emptyLocal=" + str _emptyLocal
            + "|reaped=" + str _reaped
            + "|confirmedGone=" + str _confirmedGone
            + "|skippedPersistent=" + str _skipPers
            + "|skippedTracked=" + str _skipTracked
            + "|t=" + str (round (time / 60)));
        // Human-readable companion line (LogContent is the client-flavored channel).
        ["INFORMATION", Format ["CLIENT_EMPTY_GROUP_CLEANUP cli:%1 reaped:%2 confirmedGone:%3 emptyLocal:%4 scanned:%5", _cliId, _reaped, _confirmedGone, _emptyLocal, _scanned]] Call WFBE_CO_FNC_LogContent;
    };
};
