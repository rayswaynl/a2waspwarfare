/*
	Equip a unit with a defined loadout.
	 Parameters:
		- Unit
		- Weapons
		- Magazines
		- Selectable weapons (Priority).
		- {Backpack}
		- {Backpack content}
*/

Private ["_backpack","_backpack_content","_bound","_cap","_capped","_compatMuzzles","_eligible","_entry","_mag","_magazines","_mi","_muzzles","_unit","_use","_weapon","_weapons","_okW","_okA","_dropped"];

_unit = _this select 0;
_weapons = _this select 1;
_magazines = _this select 2;
_eligible = if (count _this > 3) then {_this select 3} else {[]};
_backpack = if (count _this > 4) then {_this select 4} else {""};
_backpack_content = if (count _this > 5) then {_this select 5} else {[]};

//--- r72b loadout-equip-null: fail-clean when unit is null/dead or any loadout slot is nil/non-array
//--- (short AI/custom gear rows, profile desync, or caller select past end). Bare forEach/count on nil
//--- aborts the equip script mid-strip and leaves the unit naked.
if (isNull _unit || {!(alive _unit)}) exitWith {
	["WARNING", "Common_EquipUnit.sqf: skipped equip - unit null/dead."] Call WFBE_CO_FNC_LogContent;
};
if (isNil "_weapons" || {typeName _weapons != "ARRAY"}) then {_weapons = []};
if (isNil "_magazines" || {typeName _magazines != "ARRAY"}) then {_magazines = []};
if (isNil "_eligible" || {typeName _eligible != "ARRAY"}) then {_eligible = []};
if (isNil "_backpack" || {typeName _backpack != "STRING"}) then {_backpack = ""};
if (isNil "_backpack_content" || {typeName _backpack_content != "ARRAY"}) then {_backpack_content = []};

//--- Cap magazine count to inventory capacity.
_cap = missionNamespace getVariable ["WFBE_C_GEAR_MAG_SLOTS", 12];
if (count _magazines > _cap) then {
	_capped = [];
	for "_mi" from 0 to _cap - 1 do {_capped set [count _capped, _magazines select _mi]};
	_magazines = _capped;
};

//--- Equip with default stuff.
removeAllWeapons _unit;
removeAllItems _unit;

//--- Class-existence guard (live-burn 2026-07-07): a gear preset persisted in profileNamespace under
//--- another modpack (e.g. ACE_AK74M_PSO) throws the engine 'No entry CfgWeapons...' dialog on apply.
//--- Drop unknown classes here (the one choke every loadout passes through) with a single WARNING.
_okW = []; _okA = []; _dropped = [];
{ if (typeName _x == "STRING" && {_x != ""} && {isClass (configFile >> "CfgWeapons" >> _x)}) then {_okW set [count _okW, _x]} else {_dropped set [count _dropped, _x]} } forEach _weapons;
{ if (typeName _x == "STRING" && {_x != ""} && {isClass (configFile >> "CfgMagazines" >> _x)}) then {_okA set [count _okA, _x]} else {_dropped set [count _dropped, _x]} } forEach _magazines;
if (count _dropped > 0) then { diag_log Format ["[WFBE] WARNING: loadout dropped %1 unknown classname(s): %2", count _dropped, _dropped] };
_weapons = _okW; _magazines = _okA;
//--- Mission registry scrub (item #416): strip engine-valid classnames that are not in any
//--- side's buy table. Runs only for player units (AI loadouts come from CfgVehicles, not the
//--- buy registry). Flag WFBE_C_LOADOUT_REGISTRY_SCRUB (default 1 = ON).
if (isPlayer _unit && {(missionNamespace getVariable ["WFBE_C_LOADOUT_REGISTRY_SCRUB", 1]) > 0}) then {
	private ["_regW","_regA","_regDrop"];
	_regW = []; _regA = []; _regDrop = [];
	{ if !(isNil {missionNamespace getVariable _x}) then {_regW set [count _regW, _x]} else {_regDrop set [count _regDrop, _x]} } forEach _weapons;
	{ if !(isNil {missionNamespace getVariable Format["Mag_%1", _x]}) then {_regA set [count _regA, _x]} else {_regDrop set [count _regDrop, _x]} } forEach _magazines;
	if (count _regDrop > 0) then {
		diag_log Format ["[WFBE] WARNING (#416): stripped %1 non-purchasable item(s) from player %2: %3", count _regDrop, name _unit, _regDrop];
		hint Format ["Loadout adjusted: %1 item(s) not available on this server were removed.", count _regDrop];
	};
	_weapons = _regW; _magazines = _regA;
};

//--- Weapons FIRST so each magazine binds to a matching muzzle (e.g. AT13 -> MetisLauncher); otherwise OA throws "Cannot use magazine X in muzzle Y".
//--- removeAllWeapons also strips the virtual Throw/Put weapons; restore them so grenade/smoke/mine magazines
//--- (HandGrenade_West, SmokeShell*, Mine, PipeBomb) have a muzzle to bind to, otherwise OA spams
//--- "Cannot use magazine SmokeShell in muzzle HandGrenadeMuzzle" / "Mine in muzzle TimeBombMuzzle" etc.
_unit addWeapon "Throw";
_unit addWeapon "Put";
{_unit addWeapon _x} forEach _weapons;
//--- addMagazine binds against the unit's current muzzle.  Selecting a compatible
//--- weapon/muzzle for each magazine prevents a later launcher round (e.g. PG7VL)
//--- from being evaluated against a machine-gun muzzle (e.g. m8_SAW).
_compatMuzzles = [];
{
	_weapon = _x;
	_muzzles = getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
	if (count _muzzles == 0 || {"this" in _muzzles}) then {
		_compatMuzzles set [count _compatMuzzles, [_weapon, getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines")]];
	} else {
		{
			_compatMuzzles set [count _compatMuzzles, [_x, getArray (configFile >> "CfgWeapons" >> _weapon >> _x >> "magazines")]];
		} forEach _muzzles;
	};
} forEach (["Throw","Put"] + _weapons);
{
	_mag = _x;
	_bound = false;
	{
		_entry = _x;
		if (!_bound && {_mag in (_entry select 1)}) then {
			_unit selectWeapon (_entry select 0);
			_unit addMagazine _mag;
			_bound = true;
		};
	} forEach _compatMuzzles;
	if (!_bound) then {_unit addMagazine _mag};
} forEach _magazines;

//--- A weapon added BEFORE its magazines spawns UNLOADED in OA (players must hand-reload every gun on
//--- respawn; addMagazine afterwards never chambers it). Re-add each weapon now that the magazines are
//--- in inventory so the engine chambers it - all addMagazine calls above already ran with the muzzles
//--- present, so the muzzle-bind RPT stays quiet (preserves the build-31 weapons-first fix).
{_unit removeWeapon _x; _unit addWeapon _x} forEach _weapons;

//--- INFORMATION (fable/m136-rocket-20260802): a disposable launcher's magazine classname equals its own
//--- weapon classname (M136, RPG18, RPG7V, Strela, ...). If that magazine never makes it into _magazines
//--- (missing loadout entry, registry-scrub drop, etc.) the launcher spawns empty - confirm the pairing
//--- here so soak RPT scans catch a future regression at the equip site instead of a field report.
{
	if (isClass (configFile >> "CfgMagazines" >> _x)) then {
		if (_x in _magazines) then {
			["INFORMATION", Format ["Common_EquipUnit.sqf: disposable launcher [%1] equipped WITH its own magazine on %2.", _x, _unit]] Call WFBE_CO_FNC_LogContent;
		} else {
			["WARNING", Format ["Common_EquipUnit.sqf: disposable launcher [%1] equipped on %2 with NO matching magazine in loadout - launcher will fire empty.", _x, _unit]] Call WFBE_CO_FNC_LogContent;
		};
	};
} forEach _weapons;

//--- Get a proper muzzle.
_use = "";
{if (typeName _x == "STRING" && {_x != ""}) exitWith {_use = _x}} forEach _eligible;

if (_use != "") then {
	_muzzles = getArray (configFile >> "CfgWeapons" >> _use >> "muzzles");
	//--- Missing/empty muzzles entry: getArray returns [] — unguarded select 0 kills the equip script.
	if (count _muzzles == 0 || {("this" in _muzzles)}) then {_unit selectWeapon _use} else {_unit selectWeapon (_muzzles select 0)};
};

//--- Backpack handling.
[_unit, _backpack, _backpack_content] Call WFBE_CO_FNC_EquipBackpack;
