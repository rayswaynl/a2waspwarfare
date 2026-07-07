/*
	Handle a vehicle emptiness.
	 Parameters:
		- Vehicle.
		- {Delay override}.
*/

Private ["_delay", "_timer", "_vehicle"];

_vehicle = _this select 0;

// Nil-guard: _vehicle can be nil if the caller passes no argument or passes nil explicitly.
// isNull covers the case where a valid object reference has since been deleted (objNull).
// Skip-iteration pattern: exit the entire script scope — there is nothing useful to do
// without a vehicle reference, and silently defaulting to objNull would let typeOf/alive
// run against a null object and produce wrong results rather than a clean no-op.
if (isNil "_vehicle") exitWith {};
if (isNull _vehicle) exitWith {};

_delay = if (count _this > 1) then {_this select 1} else {if (typeOf _vehicle in ['HMMWV_Ambulance','HMMWV_Ambulance_DES_EP1','UH60M_MEV_EP1','M1133_MEV_EP1','GAZ_Vodnik_MedEvac','Mi17_medevac_RU','M113Ambul_TK_EP1']) then {(missionNamespace getVariable "WFBE_C_UNITS_EMPTY_TIMEOUT")*2} else {missionNamespace getVariable "WFBE_C_UNITS_EMPTY_TIMEOUT"};};

_timer = 0;

// Added double timer for the repair trucks too
if (typeOf _vehicle in ['MtvrRepair','WarfareRepairTruck_Gue','V3S_Repair_TK_GUE_EP1','UralRepair_CDF','UralRepair_INS','KamazRepair','UralRepair_TK_EP1','MtvrRepair_DES_EP1']) then {
    _delay = (missionNamespace getVariable "WFBE_C_UNITS_EMPTY_TIMEOUT")*2;
};

// Added 24 hours timer for the supply trucks
if (typeOf _vehicle in ['V3S_Supply_TK_GUE_EP1','WarfareSupplyTruck_RU', 'WarfareSupplyTruck_USMC', 'WarfareSupplyTruck_INS', 'WarfareSupplyTruck_Gue', 'WarfareSupplyTruck_CDF', 'UralSupply_TK_EP1', 'MtvrSupply_DES_EP1']) then {
    _delay = 86400;
};

while {alive _vehicle} do {
	sleep 20;
	
	_timer = if (({alive _x} count crew _vehicle) > 0 || {(_vehicle getVariable ["wfbe_airlifted", false]) && {!isNull (attachedTo _vehicle)}}) then {0} else {_timer + 20}; //--- fable/airlift-gc-exempt: an airlifted hull is crewless by design - do not run down the empty-vehicle fuse while slung
	if (_timer > _delay) exitWith {deleteVehicle _vehicle};
};

emptyQueu = emptyQueu - [_vehicle];