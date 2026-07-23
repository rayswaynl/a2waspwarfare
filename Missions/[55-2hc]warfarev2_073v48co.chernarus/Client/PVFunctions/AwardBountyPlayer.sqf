Private["_assist","_bounty","_get","_name","_type", "_killed","_coef","_streak","_mult"];

if (!isNil "isHeadLessClient") then {if (isHeadLessClient) exitWith {}};
if (isNull player) exitWith {};

//--- Malformed-payload guard: if ARRAY, ensure >= 2 elements ([killedUnit, streak]; _this select 1 read unconditionally below). Bare-object legacy form still accepted.
if ((typeName _this) == "ARRAY" && {count _this < 2}) exitWith {};

//--- Card #66 (killstreak bounty): the server now forwards [killedUnit, victimPreResetStreak].
//--- Accept both the new array form and the legacy bare-object form (backward-compatible).
_streak = if (typeName _this == "ARRAY") then {_this select 1} else {0};
_killed = if (typeName _this == "ARRAY") then {_this select 0} else {_this};
_name = name _killed;

_coef = 7*(score _killed);
_coef = _coef^(-0.1);

_bounty = if (score _killed <= 0) then {
            180;
          } else {
            100+14*(score _killed)*_coef;
          };

_bounty = round _bounty;

//--- Card #66 (killstreak bounty): scale the payout by the VICTIM's streak. A player who built up a
//--- big streak is a juicier target, so killing them pays more. Streak is clamped to the cap so the
//--- multiplier is bounded: mult = 1 + min(streak, CAP) * COEF. Both constants are in Init_CommonConstants.
_mult = 1 + ((_streak min WFBE_C_UNITS_BOUNTY_STREAK_CAP) * WFBE_C_UNITS_BOUNTY_STREAK_COEF);
_bounty = round (_bounty * _mult);

//--- J1 funds authority: the server now computes AND credits this bounty (WFBE_CO_FNC_ComputePvpBounty,
//--- RequestOnUnitKilled.sqf) and forwards the authoritative amount as payload element 2 - display that;
//--- the local math above stays as the legacy-payload fallback.
if ((typeName _this == "ARRAY") && {(count _this) > 2}) then {_bounty = _this select 2};

sleep (random 3);

//--- B748: Kill Feed Settings opt-out gates ONLY the chat line (J1: the payout itself is now server-side).
if (missionNamespace getVariable ["WFBE_KILL_MESSAGES", true]) then {Format[Localize "STR_WF_CHAT_Award_Bounty", _bounty, _name] Call GroupChatMessage};
//--- J1 funds authority: wallet write removed - the server credits the killer's group in RequestOnUnitKilled.sqf.
