/*
    TEAMBAR reason-coded probe (card wasp-player-group-rank-order-diagnosis-20260718).

    Owner live report: "my human player appeared as #2 in my own group". The A2 command bar
    sorts by rank then join order; selectLeader sets only the star. The existing
    WFBE_C_PLAYER_TEAMBAR_FIRST mitigation (COLONEL + slot1-rejoin) still recurs post-fix, and
    the independent review requires instrumentation that captures EVERY guard input the rejoin
    logic evaluates, at every lifecycle transition, so the FIRST failing transition is named
    from the RPT instead of inferred.

    One structured TEAMBAR|v2|PROBE line per call into the CLIENT RPT (probe runs client-side,
    where the command bar lives; ship the RPT via the existing client-RPT push). Logs, per
    guard: alive, team-binding equality, leadership, array slot 0, per-unit rank/isPlayer/
    locality for the first 8 group members, and the mitigation flag - every input of
    Init_Client's init-slot1-rejoin and Client_OnKilled's respawn-slot1-rejoin, so a skipped
    rejoin is attributable to its exact guard.

    Telemetry-only. WFBE_C_TEAMBAR_PROBE default 1 = on; 0 = kill-switch.
    A2-OA-safe: Private-then-assign, no inline private, no A3 commands.
*/

WFBE_CL_FNC_TeambarProbe = {
    Private ["_evt","_phase","_grp","_sameTeam","_ldr","_ldrIsP","_arr0","_arr0IsP","_o","_i","_u","_n"];
    _evt = _this select 0;
    _phase = _this select 1;
    if ((missionNamespace getVariable ["WFBE_C_TEAMBAR_PROBE", 1]) <= 0) exitWith {};

    _grp = group player;
    _sameTeam = (_grp == (missionNamespace getVariable ["WFBE_Client_Team", grpNull]));
    _ldr = leader _grp;
    _ldrIsP = (_ldr == player);
    _arr0 = objNull;
    if (count (units _grp) > 0) then {_arr0 = (units _grp) select 0};
    _arr0IsP = (_arr0 == player);

    _o = "";
    _n = (count (units _grp)) min 8;
    for '_i' from 0 to (_n - 1) do {
        _u = (units _grp) select _i;
        _o = _o + Format ["%1:r%2/p%3/l%4/a%5 ", _i, rankId _u, isPlayer _u, local _u, alive _u];
    };

    diag_log Format ["TEAMBAR|v2|PROBE|evt=%1|phase=%2|t=%3|flag=%4|alivePlayer=%5|sameTeam=%6|isLeader=%7|arr0IsPlayer=%8|playerRankId=%9|groupId=%10|units=%11|order=[ %12]",
        _evt, _phase, round time,
        (missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]),
        alive player, _sameTeam, _ldrIsP, _arr0IsP, rankId player,
        groupId _grp, count (units _grp), _o];
};
