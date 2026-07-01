/*
	WFBE_CO_FNC_AICOMNextOrderSeq - guarded next wfbe_aicom_order sequence.

	AICOM order writers only need a monotonic next sequence. The public group
	variable may be nil, empty or malformed after HC/JIP churn, so keep the
	shape checks in one OA-safe helper before any writer selects slot 0.
*/
private ["_team","_order","_seq"];
_team = _this select 0;
_seq = -1;

if (!isNull _team) then {
	_order = _team getVariable "wfbe_aicom_order";
	if (!isNil "_order" && {typeName _order == "ARRAY"} && {count _order > 0}) then {
		_seq = _order select 0;
		if (typeName _seq != "SCALAR") then {_seq = -1};
	};
};

_seq + 1
