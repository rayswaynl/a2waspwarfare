/*
    SG14: Server-authoritative AFK kick handler.
    Author: fable/lane129
    Description:
        The client's monitorAFK.sqf (and the legacy updateclient.sqf FSM path) detect AFK
        locally and REPORT here via publicVariableServer. The server validates the player
        object and issues the actual kick so the action cannot be suppressed or forged by
        a client mod.
    Parameters (received via WFBE_SE_FNC_HandlePVF dispatch):
        _this select 0 : Object - the reporting player's player object
    Returns: nothing
*/

private ["_player", "_name", "_rejected", "_now", "_cooldownVar", "_cooldownUntil", "_vehicle", "_activeDriver"];

_player = _this select 0;

//--- Validate: must be a real, living, in-mission playable unit.
if (isNull _player) exitWith {
    ["WARNING", "RequestAFKKick.sqf: rejected - null player object."] Call WFBE_CO_FNC_LogContent;
};

if (!isPlayer _player) exitWith {
    ["WARNING", format ["RequestAFKKick.sqf: rejected - object [%1] is not a player.", _player]] Call WFBE_CO_FNC_LogContent;
};

if (!alive _player) exitWith {
    ["WARNING", format ["RequestAFKKick.sqf: rejected - player [%1] is already dead/disconnected.", name _player]] Call WFBE_CO_FNC_LogContent;
};

//--- v5 (owner 2026-08-01): never AFK-kick a caster - the camera consumes their input so the body
//--- always looks idle. Server-authoritative twin of the client-side exemption in updateclient.sqf
//--- (the seat flag is set by the slot's sqm init on the server, so it IS visible here).
if (_player getVariable ["wfbe_caster_slot", false]) exitWith {
    ["INFORMATION", format ["RequestAFKKick.sqf: rejected - [%1] is a caster seat, exempt from AFK kick.", name _player]] Call WFBE_CO_FNC_LogContent;
};

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- Traced legit callers: Client/Module/AFKkick/monitorAFK.sqf and the legacy
//--- Client/FSM/updateclient.sqf inactivity block. BOTH only ever report the CALLING
//--- client's own `player` object (`WFBE_PVF_RequestAFKKick = ["SRVFNCRequestAFKKick", [player]]`)
//--- exactly ONCE - each runs a `while {!gameOver && !_kickRequested}` loop that sets the
//--- exit flag and never retries. But publicVariableServer carries no trusted sender on A2, so
//--- with only the pre-existing isNull/isPlayer/alive checks ANY client can name ANY OTHER
//--- player here and get them BE-kicked instantly - pure griefing, live, worse than the usual
//--- spoofable-self-report class because there was no per-target narrowing at all.
//--- Grepped the whole tree: there is no server-tracked last-activity/idle var published
//--- anywhere the server could validate against (both AFK timers are 100% client-local), and
//--- standing up one would mean a new always-on per-player position-sampling loop - real
//--- perf cost, out of scope for a hardening-only fix. Full closure is the nonce-echo-binding
//--- design lane already carded 2026-07-25 (see a2-sqf-review-false-positives.md rule 7);
//--- until it lands, narrow strictly with what the server CAN observe right now:
//---   1) per-target cooldown, keyed on UID (survives the kick/reconnect cycle) - a forger
//---      can no longer kick-loop/harass the same victim repeatedly.
//---   2) reject targets the server can see are clearly ACTIVE this instant (driving/piloting
//---      a vehicle, or moving faster than a walk) - a genuinely AFK player is stationary and
//---      not at the controls, so this rejects the most obvious forgeries (kicking someone
//---      mid-firefight or mid-drive) without touching the true-AFK case.
//--- (2) can still misfire on an AFK PASSENGER in a vehicle someone else is actively driving
//--- (their speed tracks the vehicle even though they gave no input themselves) - not provably
//--- safe for 100% of legitimate calls, so both narrowings stay OFF by default per repo policy.
_rejected = false;
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
    _now = diag_tickTime;
    _cooldownVar = format ["WFBE_SE_VAR_AFKKickCooldown_%1", getPlayerUID _player];
    _cooldownUntil = missionNamespace getVariable [_cooldownVar, -1];

    if (_cooldownUntil > _now) then {
        _rejected = true;
        ["WARNING", format ["RequestAFKKick.sqf: rejected - player [%1] is within the per-target AFK-kick cooldown (%2s remaining).", name _player, round (_cooldownUntil - _now)]] Call WFBE_CO_FNC_LogContent;
    };

    if (!_rejected) then {
        _vehicle = vehicle _player;
        _activeDriver = (_vehicle != _player) && {(driver _vehicle) == _player};
        if (_activeDriver || {(speed _player) > 1}) then {
            _rejected = true;
            ["WARNING", format ["RequestAFKKick.sqf: rejected - player [%1] fails server-observed AFK plausibility (speed=%2, activeDriver=%3).", name _player, (speed _player), _activeDriver]] Call WFBE_CO_FNC_LogContent;
        };
    };

    if (!_rejected) then {
        missionNamespace setVariable [_cooldownVar, _now + 120];
    };
};
if (_rejected) exitWith {};

_name = name _player;

["INFORMATION", format ["RequestAFKKick.sqf: kicking player [%1] for AFK (server-authoritative).", _name]] Call WFBE_CO_FNC_LogContent;

//--- Issue the BattlEye kick (same mechanism used by updateclient.sqf / publicvariable.txt filter action 5).
kickAFK = format ["%1 Kicked for AFKing", _name];
publicVariable "kickAFK";
