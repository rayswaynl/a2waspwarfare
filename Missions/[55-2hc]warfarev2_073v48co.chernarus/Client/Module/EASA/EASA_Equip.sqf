Private ["_get", "_index", "_loadout", "_loadout_old", "_type", "_vehicle", "_rows", "_easaAll", "_easaDefault"];

_vehicle = _this select 0;
_index = _this select 1;

if (typeName _vehicle != 'OBJECT') exitWith {["ERROR", Format ["EASA_Equip.sqf: Invalid Parameter (_vehicle), expected object instead of [%1]", _vehicle]] Call WFBE_CO_FNC_LogContent};
if (isNull _vehicle) exitWith {["WARNING", "EASA_Equip.sqf: vehicle is null - skip."] Call WFBE_CO_FNC_LogContent};

//--- r72b loadout-equip-null: bound index + row shape. Stale WFBE_EASA_Setup / OOB random index /
//--- short row used to nil-select then forEach and abort mid-strip (disarmed airframe).
if (isNil "_index" || {typeName _index != "SCALAR"}) exitWith {
	["WARNING", Format ["EASA_Equip.sqf: invalid index [%1] for [%2].", _index, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
};

_type = (missionNamespace getVariable 'WFBE_EASA_Vehicles') find (typeOf _vehicle);

//--- EASA Loadout was found.
if (_type != -1) then {
	_easaAll = missionNamespace getVariable ["WFBE_EASA_Loadouts", []];
	if (typeName _easaAll != "ARRAY" || {_type < 0} || {_type >= count _easaAll}) exitWith {
		["WARNING", Format ["EASA_Equip.sqf: no loadout table for typeIdx %1 (%2).", _type, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	_rows = _easaAll select _type;
	if (isNil "_rows" || {typeName _rows != "ARRAY"} || {count _rows == 0}) exitWith {
		["WARNING", Format ["EASA_Equip.sqf: empty loadout rows for [%1].", typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	if (_index < 0 || {_index >= count _rows}) exitWith {
		["WARNING", Format ["EASA_Equip.sqf: index %1 OOB (rows=%2) for [%3].", _index, count _rows, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};

	//--- Do we have something on the vehicle yet?
	_get = _vehicle getVariable 'WFBE_EASA_Setup';

	if (isNil '_get') then { //--- Vehicle has no EASA setup yet.
		_easaDefault = missionNamespace getVariable ["WFBE_EASA_Default", []];
		if (typeName _easaDefault == "ARRAY" && {_type < count _easaDefault}) then {
			[_vehicle, _easaDefault select _type] Call EASA_RemoveLoadout; //--- Remove the default loadout.
		};
		_get = -1;
	} else { //--- Vehicle already had an EASA loadout.
		if (typeName _get == "SCALAR" && {_get >= 0} && {_get < count _rows}) then {
			_loadout_old = (_rows select _get) select 2;
			if (!(isNil "_loadout_old") && {typeName _loadout_old == "ARRAY"} && {count _loadout_old >= 2}) then {
				[_vehicle, _loadout_old] Call EASA_RemoveLoadout;
			};
		} else {
			_get = -1;
		};
	};

	//--- Now we load the new EASA setup.
	_loadout = (_rows select _index) select 2;
	if (isNil "_loadout" || {typeName _loadout != "ARRAY"} || {count _loadout < 2}) exitWith {
		["WARNING", Format ["EASA_Equip.sqf: malformed loadout row %1 for [%2].", _index, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};
	if (typeName (_loadout select 0) != "ARRAY" || {typeName (_loadout select 1) != "ARRAY"}) exitWith {
		["WARNING", Format ["EASA_Equip.sqf: loadout row %1 weapons/mags not arrays for [%2].", _index, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};

	// Turret-armed airframes (Wildcat + Ka-137): the occupant fires from MainTurret, so weapons MUST go on the turret
	// (path [-1] = primary/MainTurret). Hull-level addWeapon leaves the turret empty -> pilot/operator has no usable weapon.
	if (((typeOf _vehicle) == "AW159_Lynx_BAF") || {(typeOf _vehicle) == "Ka137_MG_PMC"}) then {
		{_vehicle addMagazineTurret [_x, [-1]]} forEach (_loadout select 1);
		{_vehicle addWeaponTurret [_x, [-1]]} forEach (_loadout select 0);
	} else {
		{_vehicle addMagazine _x} forEach (_loadout select 1);
		{_vehicle addWeapon _x} forEach (_loadout select 0);
	};

	//--- We update the EASA setup on the vehicle for everyone if needed.
	if (_get != _index) then {_vehicle setVariable ["WFBE_EASA_Setup", _index, true]};

};
