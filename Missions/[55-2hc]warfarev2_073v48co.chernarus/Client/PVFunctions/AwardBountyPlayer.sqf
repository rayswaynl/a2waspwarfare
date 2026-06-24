Private["_assist","_bounty","_get","_name","_type", "_killed","_coef","_streak","_mult"];

if (!isNil "isHeadLessClient") then {if (isHeadLessClient) exitWith {}};
if (isNull player) exitWith {};

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

sleep (random 3);

Format[Localize "STR_WF_CHAT_Award_Bounty", _bounty, _name] Call GroupChatMessage;
(_bounty) Call ChangePlayerFunds;
