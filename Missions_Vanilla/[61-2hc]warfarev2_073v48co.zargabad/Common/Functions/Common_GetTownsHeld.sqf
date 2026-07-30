Private["_count","_held","_sideID","_sid"];

_held = 0;
_sideID = _this Call GetSideID;

//--- 2-arg sideID (income/victory held-count): nil/unset towns never count for any side.
{ _sid = _x getVariable ["sideID", WFBE_C_UNKNOWN_ID]; if (!(isNil "_sid") && {_sid == _sideID}) then {_held = _held + 1} } forEach towns;

_held
