Private ["_funds"];

if (isNull _this) exitWith {0};

_funds = (_this getVariable "wfbe_funds");
//--- Type guard mirroring Common_ChangeTeamFunds.sqf: wfbe_funds can be non-numeric on a group that
//--- was never funded or whose wallet was corrupted, and returning it raw poisons every arithmetic
//--- caller (price checks, refunds, UI). Treat anything that is not a SCALAR as 0, same as the writer.
if (isNil '_funds' || {typeName _funds != "SCALAR"}) exitWith {0};
_funds