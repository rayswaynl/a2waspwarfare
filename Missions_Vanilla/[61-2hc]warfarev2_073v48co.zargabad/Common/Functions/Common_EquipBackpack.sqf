/*
	Equip a unit with a backpack or remove it.
	 Parameters:
		- Unit
		- Backpack
		- {Backpack content}
*/

Private ["_backpack","_backpack_content","_counts","_items","_unit","_unit_bp"];

_unit = _this select 0;
_backpack = _this select 1;
_backpack_content = if (count _this > 2) then {_this select 2} else {[]};

//--- r72b loadout-equip-null: unit/class/content fail-clean. Nil backpack string or failed
//--- addBackpack left unitBackpack null and clearWeaponCargoGlobal aborted; nested select on
//--- malformed content did the same.
if (isNull _unit || {!(alive _unit)}) exitWith {};
if (isNil "_backpack" || {typeName _backpack != "STRING"}) then {_backpack = ""};
if (isNil "_backpack_content" || {typeName _backpack_content != "ARRAY"}) then {_backpack_content = []};

//--- Always remove the Backpack.
_unit_bp = unitBackpack _unit;
if !(isNull _unit_bp) then {removeBackpack _unit};

//--- Add Backpack if necessary.
if (_backpack != "") then {
	//--- Skip unknown classnames (profile/modpack desync) instead of addBackpack no-op + null cargo.
	if !(isClass (configFile >> "CfgVehicles" >> _backpack)) exitWith {
		diag_log Format ["[WFBE] WARNING: EquipBackpack dropped unknown backpack class [%1].", _backpack];
	};
	_unit addBackpack _backpack;
	_unit_bp = unitBackpack _unit;
	if (isNull _unit_bp) exitWith {
		diag_log Format ["[WFBE] WARNING: EquipBackpack addBackpack failed for [%1] on unit.", _backpack];
	};

	//--- Clear the existing default content.
	clearWeaponCargoGlobal _unit_bp;
	clearMagazineCargoGlobal _unit_bp;

	//--- Don't bother if there is no content.
	if (count _backpack_content < 2) exitWith {};

	//--- Weapons (shape: [[items],[counts]])
	if (typeName (_backpack_content select 0) == "ARRAY" && {count (_backpack_content select 0) >= 2}) then {
		_items = (_backpack_content select 0) select 0;
		_counts = (_backpack_content select 0) select 1;
		if (typeName _items == "ARRAY" && {typeName _counts == "ARRAY"}) then {
			for '_i' from 0 to (((count _items) min (count _counts)) - 1) do {
				_unit_bp addWeaponCargoGlobal [_items select _i, _counts select _i];
			};
		};
	};

	//--- Ammo
	if (typeName (_backpack_content select 1) == "ARRAY" && {count (_backpack_content select 1) >= 2}) then {
		_items = (_backpack_content select 1) select 0;
		_counts = (_backpack_content select 1) select 1;
		if (typeName _items == "ARRAY" && {typeName _counts == "ARRAY"}) then {
			for '_i' from 0 to (((count _items) min (count _counts)) - 1) do {
				_unit_bp addMagazineCargoGlobal [_items select _i, _counts select _i];
			};
		};
	};
};
