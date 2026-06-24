Private["_class","_label","_rlType","_side","_structure","_structures","_structuresNames","_idx"];

_structure = _this select 0;
_side = _this select 1;

_class = typeOf _structure;

_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES', _side];
_structuresNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',_side];

//--- B62 (Ray 2026-06-21): guard the latent crash. If _class is not in _structuresNames, `find` returns -1
//--- and `_structures select -1` throws "Zero divisor" on A2-OA 1.64 (negative array index), which aborts the
//--- whole structure-marker spawn and leaves the own-side marker un-built. Resolve the index defensively first.
//--- (_idx declared in the Private[] header above; A2-OA 1.64 has no A3 `private _x = ...` inline form.)
_idx = _structuresNames find _class;
_rlType = if (_idx >= 0) then {_structures select _idx} else {""};

_label = switch (_rlType) do {
	case "Barracks": {"B"};
	case "Light": {"L"};
	case "CommandCenter": {"C"};
	case "Heavy": {"H"};
	case "Aircraft": {"A"};
	case "ServicePoint": {"S"};
	case "Bank": {"R"};			//--- Federal Reserve (economy bank) - 'R' next to its map marker (claude-gaming 2026-06-13)
	case "AARadar": {"AAR"};
	case "ArtilleryRadar": {"AR"};
	case "Reserve": {"RES"};
	default {""};
};

_label