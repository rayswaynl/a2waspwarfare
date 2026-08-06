/*
	Equip a vehicle
	 Parameters:
		- Vehicle
		- Vehicle Content
*/

Private ["_counts","_items","_vehicle","_vehicle_content"];

_vehicle = _this select 0;
_vehicle_content = _this select 1;

//--- r72b loadout-equip-null: nil/malformed vehicle cargo content used to error on nested
//--- select 0/1/2 (gear menu / empty profile). Coerce and shape-guard each cargo slot.
if (isNull _vehicle || {!(alive _vehicle)}) exitWith {};
if (isNil "_vehicle_content" || {typeName _vehicle_content != "ARRAY"}) exitWith {};

//--- Make sure that the vehicle is alive.
if (alive _vehicle) then {
	//--- Clear the existing default content.
	clearWeaponCargoGlobal _vehicle;
	clearMagazineCargoGlobal _vehicle;
	clearBackpackCargoGlobal _vehicle;

	//--- Don't bother if there is no content.
	if (count _vehicle_content == 0) exitWith {};

	//--- Weapons
	if (count _vehicle_content > 0 && {typeName (_vehicle_content select 0) == "ARRAY"} && {count (_vehicle_content select 0) >= 2}) then {
		_items = (_vehicle_content select 0) select 0;
		_counts = (_vehicle_content select 0) select 1;
		if (typeName _items == "ARRAY" && {typeName _counts == "ARRAY"}) then {
			for '_i' from 0 to (((count _items) min (count _counts)) - 1) do {
				_vehicle addWeaponCargoGlobal [_items select _i, _counts select _i];
			};
		};
	};

	//--- Ammo
	if (count _vehicle_content > 1 && {typeName (_vehicle_content select 1) == "ARRAY"} && {count (_vehicle_content select 1) >= 2}) then {
		_items = (_vehicle_content select 1) select 0;
		_counts = (_vehicle_content select 1) select 1;
		if (typeName _items == "ARRAY" && {typeName _counts == "ARRAY"}) then {
			for '_i' from 0 to (((count _items) min (count _counts)) - 1) do {
				_vehicle addMagazineCargoGlobal [_items select _i, _counts select _i];
			};
		};
	};

	//--- Backpack
	if (count _vehicle_content > 2 && {typeName (_vehicle_content select 2) == "ARRAY"} && {count (_vehicle_content select 2) >= 2}) then {
		_items = (_vehicle_content select 2) select 0;
		_counts = (_vehicle_content select 2) select 1;
		if (typeName _items == "ARRAY" && {typeName _counts == "ARRAY"}) then {
			for '_i' from 0 to (((count _items) min (count _counts)) - 1) do {
				_vehicle addBackpackCargoGlobal [_items select _i, _counts select _i];
			};
		};
	};
};
