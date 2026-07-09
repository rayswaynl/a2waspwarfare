/*
	WFBE_CO_FNC_GroupGetBool — safe boolean getVariable for GROUP receivers.

	A2 OA 1.64 trap (the "G1" class): the 2-arg `group getVariable [name, default]`
	form returns nil (NOT the default) when the var is UNSET on a GROUP. Reading a
	bool that way and using it (`nil || {..}`, `if (nil)`, `nil != x`, ...) throws
	"Type Nothing". Side logics / objects / namespaces do NOT have this quirk — only
	groups — so route GROUP bool reads through this helper. It restores the intended
	default-on-missing semantics using the safe 1-arg form + isNil.

	Params: [ group, varName (string), default ]
	Returns: the stored value, or `default` when the var is unset/nil.
*/
private ["_grp","_name","_default","_v"];
_grp     = _this select 0;
_name    = _this select 1;
_default = _this select 2;
_v = _grp getVariable _name;
if (isNil "_v") then {_default} else {_v}
