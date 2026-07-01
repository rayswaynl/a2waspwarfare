/*
	WFBE_CO_FNC_GroupGetValue - safe getVariable default for GROUP receivers.

	A2 OA 1.64 returns nil instead of the supplied default for unset GROUP
	variables when using `group getVariable [name, default]`. Use the safe
	1-arg read plus an isNil guard so arrays, strings, objects, positions, and
	scalars keep their intended default semantics.
*/
private ["_grp","_name","_default","_v"];
_grp     = _this select 0;
_name    = _this select 1;
_default = _this select 2;
_v = _grp getVariable _name;
if (isNil "_v") then {_default} else {_v}
