/*
	Fill a listbox with a cargo style loadout
	 Parameters:
		- IDC Listbox
		- Gear
*/

Private ["_clear","_gear","_lb"];

_lb = _this select 0;
_gear = _this select 1;
_clear = _this select 2;

if (_clear) then {lnbClear _lb};

_k = 0;
for '_i' from 0 to count(_gear)-1 do {
	if (count(_gear select _i) > 0) then {
		_items = (_gear select _i) select 0;
		_count = (_gear select _i) select 1;
		
		_prefix = if (_i == 1) then {"Mag_"} else {""};
		
		for '_j' from 0 to count(_items)-1 do {
			_get = missionNamespace getVariable Format ["%1%2",_prefix,_items select _j]; if (isNil "_get" || {typeName _get != "ARRAY"} || {count _get < 2}) then {_get = ["", "?"]}; //--- B755 (Ray 2026-06-25): nil-guard - an unregistered item class returned nil so "_get select 1" threw "Undefined variable" and aborted the gear listbox fill. Fall back to a placeholder row instead of crashing the list.
			lnbAddRow[_lb, [Format ["x%1", _count select _j], _get select 1]];
			lnbSetPicture[_lb,[_k,0],_get select 0];
			lnbSetData[_lb,[_k,0],Format ["%1%2",_prefix,_items select _j]];
			_k = _k + 1;
		};
	};
};