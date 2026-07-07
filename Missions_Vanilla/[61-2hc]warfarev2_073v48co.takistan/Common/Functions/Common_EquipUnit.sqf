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

Private ["_backpack","_backpack_content","_cap","_capped","_eligible","_magazines","_mi","_muzzles","_unit","_use","_weapons","_okW","_okA","_dropped"];

_unit = _this select 0;
_weapons = _this select 1;
_magazines = _this select 2;
_eligible = _this select 3;
_backpack = if (count _this > 4) then {_this select 4} else {""};
_backpack_content = if (count _this > 5) then {_this select 5} else {[]};

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
{ if (_x != "" && {isClass (configFile >> "CfgWeapons" >> _x)}) then {_okW set [count _okW, _x]} else {_dropped set [count _dropped, _x]} } forEach _weapons;
{ if (_x != "" && {isClass (configFile >> "CfgMagazines" >> _x)}) then {_okA set [count _okA, _x]} else {_dropped set [count _dropped, _x]} } forEach _magazines;
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
{_unit addMagazine _x} forEach _magazines;

//--- A weapon added BEFORE its magazines spawns UNLOADED in OA (players must hand-reload every gun on
//--- respawn; addMagazine afterwards never chambers it). Re-add each weapon now that the magazines are
//--- in inventory so the engine chambers it - all addMagazine calls above already ran with the muzzles
//--- present, so the muzzle-bind RPT stays quiet (preserves the build-31 weapons-first fix).
{_unit removeWeapon _x; _unit addWeapon _x} forEach _weapons;

//--- Get a proper muzzle.
_use = "";
{if (_x != "") exitWith {_use = _x}} forEach _eligible;

if (_use != "") then { 
	_muzzles = getArray (configFile >> "CfgWeapons" >> _use >> "muzzles"); 
	if !("this" in _muzzles) then {_unit selectWeapon (_muzzles select 0)} else {_unit selectWeapon _use}; 
};

//--- Backpack handling.
[_unit, _backpack, _backpack_content] Call WFBE_CO_FNC_EquipBackpack;