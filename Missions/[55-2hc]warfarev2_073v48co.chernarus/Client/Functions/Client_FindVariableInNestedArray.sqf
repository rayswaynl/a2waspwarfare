private ["_array", "_value", "_index", "_i"];

_array = _this select 0;
_value = _this select 1;

_index = -1;
if (count _array > 0) then {
	for "_i" from 0 to ((count _array) - 1) do {
		if (_value in (_array select _i)) exitWith {_index = _i};
	};
};

_index;
