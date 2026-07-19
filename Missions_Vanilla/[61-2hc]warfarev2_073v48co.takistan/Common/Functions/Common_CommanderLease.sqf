/*
    C1 stable commander UID/side lease.

    The legacy wfbe_commander group remains the derived view consumed by the
    rest of the mission. The lease keeps the human identity and group binding
    stable across leader death, promotion, respawn and a short disconnect.

    Round-3 review (codex reject 2026-07-19, P1 x3): a bare timestamp request and a
    "check-then-Call" executor step are NOT safe against SQF's scheduled-environment
    preemption - the engine can hand control to another script between ANY two
    statements that are not inside a single explicit no-yield block, not only across
    an explicit sleep/waitUntil. Two concrete repros were proven: a STALE stand-down
    request surviving a reclaim + fresh disconnect and clearing the WRONG (later)
    lease, and a reclaim landing between the executor's holder-check and its
    StandDown call. The disconnect lease-mismatch branch also bypassed the executor
    entirely, and RequestNewCommander/RequestClaimCommander/Server_VoteForCommander
    published wfbe_commander directly instead of routing through it.

    FIX: every lease-coupled state transition (grant, reclaim, stand-down) is now a
    VERSIONED COMMAND consumed exclusively by the per-side executor - the ONLY code
    in the mission that ever writes wfbe_commander / wfbe_commander_lease /
    wfbe_commander_lease_gen. Every grant AND every successful reclaim bumps a
    monotonic per-side GENERATION counter embedded in the lease tuple. A stand-down
    command captures the generation it targets at enqueue time; the executor
    discards it unless the CURRENT generation still matches - stale-by-construction,
    with no reliance on statement-adjacency being uninterruptible. Writers/receivers
    (RequestNewCommander, RequestClaimCommander, Server_VoteForCommander,
    Server_HandleSpecial's reclaim, Server_OnPlayerDisconnected's grace-arm AND
    mismatch branches, RequestJoin's side-change) only ENQUEUE; none of them ever
    touch wfbe_commander/lease state directly when the flag is on.

    Command slots are per-KIND single-value overwrite slots (not a FIFO array): an
    enqueue is one pure `setVariable` WRITE with no prior read, so two enqueuers of
    the SAME kind racing on the SAME frame cannot corrupt each other into a torn
    read-modify-write (there is no read step to race). A late-arriving enqueue of
    the SAME kind simply supersedes an unconsumed earlier one - for GRANT/RECLAIM
    that is always safe (the latest request is the one that should win; there is no
    canonical ordering to violate for genuinely simultaneous requests). Local/server-
    only state (nothing here is ever read client-side): no broadcast on any of it.
*/

WFBE_CO_FNC_CommanderLeaseEligible = {
    Private ["_side","_team","_leader","_ok"];
    _side = _this select 0;
    _team = _this select 1;
    _ok = false;
    if (_side != civilian && {!isNull _team} && {side _team == _side} && {!([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
        _leader = leader _team;
        if (!isNull _leader && {isPlayer _leader} && {(getPlayerUID _leader) != ""}) then {_ok = true};
    };
    _ok
};

WFBE_CO_FNC_CommanderLeaseHolderPresent = {
    Private ["_side","_logic","_lease","_uid","_groupKey","_present"];
    _side = _this select 0;
    _present = false;
    if (_side == civilian) exitWith {_present};

    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {_present};
    _lease = _logic getVariable ["wfbe_commander_lease", []];
    if (typeName _lease != "ARRAY") then {_lease = []};
    if (count _lease < 6) exitWith {_present};
    _uid = _lease select 0;
    _groupKey = _lease select 2;

    {
        if (!isNull _x && {alive _x} && {isPlayer _x} && {(getPlayerUID _x) == _uid} && {(groupId (group _x)) == _groupKey}) then {_present = true};
    } forEach allUnits;
    _present
};

//--- ENQUEUE-ONLY entry points (safe to Call from any server-side file). None of these mutate
//--- wfbe_commander / wfbe_commander_lease / wfbe_commander_lease_gen - they only stamp a
//--- per-kind command slot for the executor to consume.

WFBE_CO_FNC_CommanderLeaseRequestGrant = {
    //--- params: [side, team-or-objNull, source]. objNull team = explicit AI hand-back.
    Private ["_side","_team","_source","_logic"];
    _side = _this select 0;
    _team = _this select 1;
    _source = _this select 2;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _logic setVariable ["wfbe_commander_lease_cmd_grant", [_team, _source, time]];
};

WFBE_CO_FNC_CommanderLeaseRequestReclaim = {
    //--- params: [side, uid, team]. Re-validated fully (uid+group+eligibility) at exec time.
    Private ["_side","_uid","_team","_logic"];
    _side = _this select 0;
    _uid = _this select 1;
    _team = _this select 2;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _logic setVariable ["wfbe_commander_lease_cmd_reclaim", [_uid, _team, time]];
};

WFBE_CO_FNC_CommanderLeaseRequestStandDown = {
    //--- params: [side, targetGen]. targetGen is the generation captured by the CALLER at the
    //--- moment it decided a stand-down was warranted (grace expiry, side-change, disconnect
    //--- mismatch) - the executor discards this request outright if the side's generation has
    //--- since moved on (a newer grant/reclaim happened), regardless of exactly when.
    Private ["_side","_gen","_logic"];
    _side = _this select 0;
    _gen = _this select 1;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _logic setVariable ["wfbe_commander_lease_cmd_standdown", [_gen, time]];
};

//--- EXECUTOR-INTERNAL ONLY below this line. These are the only functions that ever write
//--- wfbe_commander / wfbe_commander_lease / wfbe_commander_lease_gen; a source contract test
//--- pins that their only Call sites are inside the executor loop.

WFBE_CO_FNC_CommanderLeaseExecGrant = {
    Private ["_side","_logic","_cmd","_team","_source","_gen","_leader","_uid"];
    _side = _this select 0;
    _logic = _this select 1;
    _cmd = _this select 2;
    _team = _cmd select 0;
    _source = _cmd select 1;

    if (isNull _team) exitWith {
        //--- Explicit AI hand-back (vote resolved to AI, or an assign cleared the seat).
        _gen = (_logic getVariable ["wfbe_commander_lease_gen", 0]) + 1;
        _logic setVariable ["wfbe_commander_lease_gen", _gen];
        _logic setVariable ["wfbe_commander_lease", nil];
        _logic setVariable ["wfbe_commander_lease_expires", nil];
        _logic setVariable ["wfbe_commander", objNull, true];
        [_side, objNull] Spawn WFBE_SE_FNC_AssignForCommander;
    };

    if (!([_side, _team] Call WFBE_CO_FNC_CommanderLeaseEligible)) exitWith {
        ["WARNING", Format ["CommanderLease ExecGrant: [%1] DENIED ineligible %2 request for team %3 - seat unchanged.", _side, _source, _team]] Call WFBE_CO_FNC_LogContent;
    };

    _leader = leader _team;
    _uid = getPlayerUID _leader;
    _gen = (_logic getVariable ["wfbe_commander_lease_gen", 0]) + 1;
    _logic setVariable ["wfbe_commander_lease_gen", _gen];
    _logic setVariable ["wfbe_commander_lease", [_uid, _side, groupId _team, time, _source, _gen]];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
    _logic setVariable ["wfbe_commander", _team, true];
    [_side, _team] Spawn WFBE_SE_FNC_AssignForCommander;
};

WFBE_CO_FNC_CommanderLeaseExecReclaim = {
    Private ["_side","_logic","_cmd","_uid","_team","_lease","_gen"];
    _side = _this select 0;
    _logic = _this select 1;
    _cmd = _this select 2;
    _uid = _cmd select 0;
    _team = _cmd select 1;

    if (isNull _team) exitWith {};
    _lease = _logic getVariable ["wfbe_commander_lease", []];
    if (typeName _lease != "ARRAY" || {count _lease < 6}) exitWith {};
    if ((_lease select 0) != _uid || {(_lease select 2) != (groupId _team)}) exitWith {};
    if (!([_side, _team] Call WFBE_CO_FNC_CommanderLeaseEligible)) exitWith {};

    //--- Reclaim bumps generation too, even though it is "the same lease continuing": this is
    //--- what makes a stand-down request queued BEFORE the reclaim provably stale afterwards -
    //--- the generation-mismatch gate in ExecStandDown below needs no separate holder-timing
    //--- assumption to be correct.
    _gen = (_logic getVariable ["wfbe_commander_lease_gen", 0]) + 1;
    _logic setVariable ["wfbe_commander_lease_gen", _gen];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
    _logic setVariable ["wfbe_commander_lease", [_uid, _side, groupId _team, time, "reclaim", _gen]];
    _logic setVariable ["wfbe_commander", _team, true];
    [_side, "HandleSpecial", ["new-commander-assigned", _team]] Call WFBE_CO_FNC_SendToClients;
};

WFBE_CO_FNC_CommanderLeaseExecStandDown = {
    Private ["_side","_logic","_cmd","_targetGen","_curGen","_commander","_lease"];
    _side = _this select 0;
    _logic = _this select 1;
    _cmd = _this select 2;
    _targetGen = _cmd select 0;

    _curGen = _logic getVariable ["wfbe_commander_lease_gen", 0];
    //--- THE generation gate: a stand-down request only ever fires against the EXACT lease
    //--- generation it was raised for. Any grant or reclaim since - by definition, from ANY
    //--- source, at ANY interleaving point - has already bumped the generation, so this
    //--- comparison alone is sufficient; no timing assumption about "no yield between check and
    //--- effect" is required, because there is nothing left to race: the generation the
    //--- request captured either still matches reality or it categorically does not.
    if (_targetGen != _curGen) exitWith {};

    _commander = _logic getVariable ["wfbe_commander", objNull];
    _lease = _logic getVariable ["wfbe_commander_lease", []];
    if (isNull _commander && {typeName _lease != "ARRAY" || {count _lease == 0}}) exitWith {};

    //--- Defense-in-depth on top of the generation gate (belt-and-braces, matches the style
    //--- already used by CommanderLeaseEligible above).
    if ([_side] Call WFBE_CO_FNC_CommanderLeaseHolderPresent) exitWith {};

    _logic setVariable ["wfbe_commander_lease", nil];
    _logic setVariable ["wfbe_commander_lease_expires", nil];
    _logic setVariable ["wfbe_commander", objNull, true];
    [_side, "LocalizeMessage", ['CommanderDisconnected']] Call WFBE_CO_FNC_SendToClients;
    {[_x,false] Call SetTeamAutonomous;[_x, ""] Call SetTeamRespawn} forEach (_logic getVariable "wfbe_teams");
};

//--- The single per-side executor. Spawned ONCE per side from Init_Server when the lease flag
//--- is on (flag off = never spawned = byte-identical). Polls its three per-kind command slots
//--- every second and is the ONLY caller of the three Exec* functions above - single-owner by
//--- construction, not by convention: no other file ever Calls them.
WFBE_CO_FNC_CommanderLeaseStandDownExecutor = {
    Private ["_side","_logic","_cmd"];
    _side = _this select 0;
    if (_side == civilian) exitWith {};
    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    while {true} do {
        sleep 1;

        _cmd = _logic getVariable "wfbe_commander_lease_cmd_grant";
        if (!isNil "_cmd") then {
            _logic setVariable ["wfbe_commander_lease_cmd_grant", nil];
            [_side, _logic, _cmd] Call WFBE_CO_FNC_CommanderLeaseExecGrant;
        };

        _cmd = _logic getVariable "wfbe_commander_lease_cmd_reclaim";
        if (!isNil "_cmd") then {
            _logic setVariable ["wfbe_commander_lease_cmd_reclaim", nil];
            [_side, _logic, _cmd] Call WFBE_CO_FNC_CommanderLeaseExecReclaim;
        };

        _cmd = _logic getVariable "wfbe_commander_lease_cmd_standdown";
        if (!isNil "_cmd") then {
            _logic setVariable ["wfbe_commander_lease_cmd_standdown", nil];
            [_side, _logic, _cmd] Call WFBE_CO_FNC_CommanderLeaseExecStandDown;
        };
    };
};

WFBE_CO_FNC_CommanderLeaseGraceCheck = {
    //--- params: [side, expires, gen] - gen is the lease generation active when grace was armed;
    //--- carried through to the stand-down request so a reclaim/re-grant since then (which
    //--- always bumps generation) makes this request provably stale at executor time.
    Private ["_side","_expires","_gen","_wait","_logic","_currentExpires"];
    _side = _this select 0;
    _expires = _this select 1;
    _gen = _this select 2;
    _wait = _expires - time;
    if (_wait > 0) then {sleep _wait};

    _logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
    if (isNull _logic) exitWith {};
    _currentExpires = _logic getVariable "wfbe_commander_lease_expires";
    if (isNil "_currentExpires") exitWith {};
    if (_currentExpires != _expires) exitWith {};
    if ([_side] Call WFBE_CO_FNC_CommanderLeaseHolderPresent) exitWith {};
    [_side, _gen] Call WFBE_CO_FNC_CommanderLeaseRequestStandDown; //--- request only; the executor performs the effects
};
