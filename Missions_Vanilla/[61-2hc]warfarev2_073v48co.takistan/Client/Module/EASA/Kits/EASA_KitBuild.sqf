/*
	EASA_KitBuild.sqf  (WFBE_CL_FNC_KitBuild)
	Per-client LOCAL realiser for an EASA custom kit. Runs on EVERY machine:
	  - on the owner immediately after EASA_ApplyKit,
	  - on remote clients via the WFBE_KIT_SIGNAL publicVariable handler,
	  - on JIP joiners via the reconcile pass in Init_Client.
	Reads the public, JIP-persistent vehicle state WFBE_KIT_Spec ([] / nil = no kit).
	Builds local attached visuals (createVehicleLocal -> attachTo) plus the per-kind functional layer
	(HandleDamage for ARMOR, fire action for MOUNT). Idempotent: tears down any prior realisation first.

	kitSpec contract (5th element of an EASA loadout row, see EASA_Equip.sqf):
	  []                                                                   -> no kit
	  ["COSMETIC", _visuals]
	  ["MOUNT",  _visuals, _ammoClass, _maxAmmo, _muzzleOff, _muzzleDir, _spread, _initSpeed]
	  ["ARMOR",  _visuals, _reductPct, _maxHits, _ammoTags]
	  _visuals = [ [_fancyClass, _vanillaClass, _offset, _dir], ... ]
	    _fancyClass   = optional addon model class ("" = none -> use vanilla fallback)
	    _vanillaClass = base-game object used when the addon is absent
	    _offset/_dir  = attach offset [x,y,z] / yaw degrees relative to the vehicle
	Arma 2 OA only.
*/
private ["_vehicle","_spec","_kind","_visuals","_objs"];
_vehicle = _this select 0;
if (isNull _vehicle) exitWith {};

//--- Idempotent: clear any prior LOCAL realisation (handles swap + removal).
[_vehicle] call EASA_KitRemove;

_spec = _vehicle getVariable ["WFBE_KIT_Spec", []];
if (count _spec == 0) exitWith {};   //--- isEqualTo is A3-only; count==0 tests empty in OA.

_kind    = _spec select 0;
_visuals = _spec select 1;

//--- 1) Local visuals: addon model when present on this client, else the vanilla fallback object.
_objs = [];
{
	private ["_fancy","_vanilla","_off","_dir","_cls","_o"];
	_fancy   = _x select 0;
	_vanilla = _x select 1;
	_off     = _x select 2;
	_dir     = _x select 3;
	_cls = if (_fancy != "" && {isClass (configFile >> "CfgVehicles" >> _fancy)}) then {_fancy} else {_vanilla};
	if (_cls != "" && {isClass (configFile >> "CfgVehicles" >> _cls)}) then {
		_o = _cls createVehicleLocal (position _vehicle);
		_o setDir _dir;
		_o attachTo [_vehicle, _off];
		_o enableSimulation false;
		_o allowDamage false;
		_objs = _objs + [_o];
	};
} forEach _visuals;
_vehicle setVariable ["WFBE_KIT_LocalObjs", _objs];

//--- 2) Functional layer.
switch (_kind) do {
	//--- ARMOR: register the damage-mitigation handler on every machine; only the machine where the
	//--- vehicle is local has its return value honoured, so adding everywhere is locality-proof.
	case "ARMOR": {
		private ["_eh"];
		_eh = _vehicle addEventHandler ["HandleDamage", {_this call EASA_Kit_Armor}];
		_vehicle setVariable ["WFBE_KIT_DmgEH", _eh];
	};
	//--- MOUNT: local fire action, shown only to the driver/gunner with ammo remaining.
	case "MOUNT": {
		private ["_act"];
		_act = _vehicle addAction [
			"<t color='#ffd24d'>Fire rocket pod</t>",
			{_this call EASA_Kit_Fire},
			[], 6, false, true, "",
			"((_target getVariable ['WFBE_KIT_Ammo',0]) > 0) && {([driver _target, gunner _target] find player) >= 0}"
		];
		_vehicle setVariable ["WFBE_KIT_FireAction", _act];
	};
	default {};
};
