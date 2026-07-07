disableSerialization;
MenuAction = -1;

_vehi = [group player,false] Call GetTeamVehicles;
_alives = (units group player) Call GetLiveUnits;
{if (vehicle _x == _x) then {_vehi = _vehi + [_x]}} forEach _alives;
_lastUse = 0;
_typeRepair = missionNamespace getVariable Format['WFBE_%1REPAIRTRUCKS',sideJoinedText];
_sheal = missionNamespace getVariable 'WFBE_C_UNITS_SUPPORT_HEAL_TIME';
_srearm = missionNamespace getVariable 'WFBE_C_UNITS_SUPPORT_REARM_TIME';
_srefuel = missionNamespace getVariable 'WFBE_C_UNITS_SUPPORT_REFUEL_TIME';
_srepair = missionNamespace getVariable 'WFBE_C_UNITS_SUPPORT_REPAIR_TIME';

_healPrice = 0;
_repairPrice = 0;
_refuelPrice = 0;
_rearmPrice = 0;
_lastVeh = objNull;
_lastDmg = 0;
_lastFue = 0;

if (isNil "WFBE_PR8_ServiceMenuProofLogged") then {
	WFBE_PR8_ServiceMenuProofLogged = true;
	["INFORMATION", "GUI_Menu_Service.sqf: PR8 service menu active (full-service row, refuel-all, damage/fuel status, repair-point EASA gate)."] Call WFBE_CO_FNC_LogContent;
};

// Marty: Shared service helpers used by the selected-unit buttons and the new all-unit buttons.
//--- fix(hunt): shared precondition mirroring SupportRearm.sqf's hard abort ("You can't rearm air in town"):
//--- an Air vehicle whose support list contains a town Depot can never rearm, so no charge site may take the
//--- money first (the pre-pay pattern has no refund path). [_veh, _supports] -> BOOL blocked.
_martyRearmBlockedAirDepot = {
	Private ["_veh","_supports","_blocked"];
	_veh = _this select 0;
	_supports = _this select 1;
	_blocked = false;
	if ((typeOf _veh) isKindOf "Air") then {
		{if ((typeOf _x) == WFBE_Logic_Depot) then {_blocked = true}} forEach _supports;
	};
	_blocked
};

_martyServiceGetPrice = {
	Private ["_action","_fuel","_get","_price","_type","_veh"];
	_veh = _this select 0;
	_action = _this select 1;
	_price = 0;

	if (_action == "HEAL") exitWith {
		if (_veh isKindOf "Man") exitWith {round((getDammage _veh) * (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_HEAL_PRICE"))};
		{
			if (alive _x) then {
				_price = _price + round((getDammage _x) * (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_HEAL_PRICE"));
			};
		} forEach (crew _veh);
		_price
	};

	if (_veh isKindOf "Man") exitWith {0};

	_type = typeOf _veh;
	_get = missionNamespace getVariable _type;

	if (_action == "REFUEL") exitWith {
		if (fuel _veh >= 1) exitWith {0};
		if (isNil "_get") exitWith {200};
		_fuel = ((fuel _veh) - 1) * -1;
		round(_fuel * ((_get select QUERYUNITPRICE) / (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_REFUEL_PRICE")))
	};

	if (_action == "REPAIR") exitWith {
		if (getDammage _veh <= 0) exitWith {0};
		if (isNil "_get") exitWith {500};
		round((getDammage _veh) * ((_get select QUERYUNITPRICE) / (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_REPAIR_PRICE")))
	};

	if (_action == "REARM") exitWith {
		if (isNil "_get") exitWith {500};
		Private ["_basePrice","_frac","_isArty"];
		_basePrice = round((_get select QUERYUNITPRICE) / (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_REARM_PRICE"));
		//--- Proportional pricing: charge only for ammo actually missing (arty always pays full).
		if ((missionNamespace getVariable ["WFBE_C_SUPPORT_REARM_PROPORTIONAL",0]) > 0) then {
			_isArty = ([typeOf _veh, str sideJoined] Call IsArtillery) != -1;
			if !(_isArty) then {
				_frac = _veh Call WFBE_CO_FNC_GetAmmoFraction;
				_basePrice = round(_basePrice * ((1 - _frac) max 0.1));
			};
		};
		_basePrice
	};

	0
};

// Marty: Short visible reason for disabled service controls.
_martyServiceBlockReason = {
	Private ["_veh"];
	_veh = _this select 0;

	if !(alive _veh) exitWith {"destroyed"};
	if (_veh isKindOf "Man") exitWith {""};
	if (((getPos _veh) select 2) > 2) exitWith {"airborne"};
	if (speed _veh > 20) exitWith {"moving"};

	""
};

// Marty: Vehicles cannot use vehicle services while moving too fast or airborne; infantry healing remains allowed.
_martyServiceCanUse = {
	Private ["_veh"];
	_veh = _this select 0;

	([_veh] Call _martyServiceBlockReason) == ""
};

_martyServiceBuildFull = {
	Private ["_actions","_fullTypes","_price","_priceOne","_veh"];
	_veh = _this select 0;
	_actions = [];
	_price = 0;
	_fullTypes = if (_veh isKindOf "Man") then {["HEAL"]} else {["REPAIR","REFUEL","REARM","HEAL"]};

	{
		if (!(_x == "REPAIR" && {_veh getVariable ["wfbe_repair_inProgress", false]})) then {
			_priceOne = [_veh,_x] Call _martyServiceGetPrice;
			if (_priceOne > 0) then {
				_actions = _actions + [_x];
				_price = _price + _priceOne;
			};
		};
	} forEach _fullTypes;

	[_actions,_price]
};

// Marty: Build an all-or-nothing batch from the current service list.
_martyServiceBuildBatch = {
	Private ["_action","_batch","_canAdd","_effective","_i","_nearSupport","_price","_priceOne","_seen","_supports","_veh"];
	_action = _this select 0;
	_effective = _this select 1;
	_nearSupport = _this select 2;
	_batch = [];
	_seen = [];
	_price = 0;

	for "_i" from 0 to ((count _effective) - 1) do {
		_veh = vehicle (_effective select _i);
		_canAdd = true;

		if (_veh in _seen) then {_canAdd = false};
		if !(alive _veh) then {_canAdd = false};
		if !([_veh] Call _martyServiceCanUse) then {_canAdd = false};
		if (_canAdd && {_action == "REARM"} && {[_veh, _nearSupport select _i] Call _martyRearmBlockedAirDepot}) then {_canAdd = false}; //--- fix(hunt): an air unit parked near a town depot would be charged its batch share and then hard-aborted by SupportRearm - keep it out of the batch (and out of the price).
		if (_canAdd && {_action == "REPAIR"} && {_veh getVariable ["wfbe_repair_inProgress", false]}) then {_canAdd = false}; //--- guard: skip vehicles already being repaired to prevent double-charge

		if (_canAdd) then {
			_seen = _seen + [_veh];
			_priceOne = [_veh,_action] Call _martyServiceGetPrice;

			if (_priceOne > 0) then {
				_supports = _nearSupport select _i;
				_batch = _batch + [[_veh,_supports]];
				_price = _price + _priceOne;
			};
		};
	};

	[_batch,_price]
};

// Marty: Charge once, then queue the existing service scripts with a tiny delay to keep the client responsive.
_martyServiceStartBatch = {
	Private ["_action","_batch","_funds","_label","_price","_spType","_typeRepair"];
	_action = _this select 0;
	_batch = _this select 1;
	_price = _this select 2;
	_typeRepair = _this select 3;
	_spType = _this select 4;
	_label = _this select 5;

	if ((count _batch) == 0) exitWith {hint Format ["No units eligible for %1 all.", _label]};

	_funds = Call GetPlayerFunds;
	if (_funds < _price) exitWith {hint Format ["Not enough funds for %1 all: $%2 needed.", _label, _price - _funds]};

	-_price Call ChangePlayerFunds;
	hint Format ["%1 all queued: %2 units for $%3.", _label, (count _batch), _price];

	[_batch,_action,_typeRepair,_spType] Spawn {
		Private ["_action","_batch","_i","_item","_spType","_supports","_typeRepair","_veh"];
		_batch = _this select 0;
		_action = _this select 1;
		_typeRepair = _this select 2;
		_spType = _this select 3;

		for "_i" from 0 to ((count _batch) - 1) do {
			_item = _batch select _i;
			_veh = _item select 0;
			_supports = _item select 1;

			if (_action == "REARM") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportRearm};
			if (_action == "REPAIR") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportRepair};
			if (_action == "REFUEL") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportRefuel};
			if (_action == "HEAL") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportHeal};

			sleep 0.35;
		};
	};
};

_martyServiceStartFull = {
	Private ["_actions","_funds","_i","_label","_price","_spType","_supports","_typeRepair","_veh"];
	_veh = _this select 0;
	_supports = _this select 1;
	_actions = _this select 2;
	_price = _this select 3;
	_typeRepair = _this select 4;
	_spType = _this select 5;
	_label = [typeOf _veh, 'displayName'] Call GetConfigInfo;
	
	//--- fix(hunt): drop a doomed REARM leg (air near a town depot) BEFORE charging - SupportRearm hard-aborts
	//--- that case after the bundled price was already taken (no refund path).
	if (("REARM" in _actions) && {[_veh,_supports] Call _martyRearmBlockedAirDepot}) then {
		_actions = _actions - ["REARM"];
		_price = _price - ([_veh,"REARM"] Call _martyServiceGetPrice);
		if (_price < 0) then {_price = 0};
	};

	if ((count _actions) == 0) exitWith {hint Format ["%1 does not need service.", _label]};

	_funds = Call GetPlayerFunds;
	if (_funds < _price) exitWith {hint Format ["Not enough funds for full service: $%1 needed.", _price - _funds]};

	-_price Call ChangePlayerFunds;
	hint Format ["Full service queued for %1: $%2.", _label, _price];

	[_veh,_supports,_actions,_typeRepair,_spType] Spawn {
		Private ["_actions","_i","_spType","_supports","_typeRepair","_veh","_action"];
		_veh = _this select 0;
		_supports = _this select 1;
		_actions = _this select 2;
		_typeRepair = _this select 3;
		_spType = _this select 4;

		for "_i" from 0 to ((count _actions) - 1) do {
			_action = _actions select _i;
			if (_action == "REARM") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportRearm};
			if (_action == "REPAIR") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportRepair};
			if (_action == "REFUEL") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportRefuel};
			if (_action == "HEAL") then {[_veh,_supports,_typeRepair,_spType] Spawn SupportHeal};
			sleep 0.35;
		};
	};
};

_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;

//--- Service Point.
_csp = objNull;
_sp = [sideJoined, missionNamespace getVariable Format ["WFBE_%1SERVICEPOINTTYPE",sideJoinedText],_buildings] Call GetFactories;
if (count _sp > 0) then {
	_csp = [vehicle player,_sp] Call WFBE_CO_FNC_GetClosestEntity;
};

if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_EASA") > 0) then {
	_enable = false;
	_enableRepairPointEASA = false;
	WFBE_CL_V_RepairPointEASAActive = false;
	_currentUpgrades = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
	_easaLevel = _currentUpgrades select WFBE_UP_EASA;
	if (_easaLevel > 0) then {
		if (typeOf(vehicle player) in (missionNamespace getVariable 'WFBE_EASA_Vehicles')) then {
			if (driver (vehicle player) == player) then {
				if (!(isNull _csp)) then {
					if (player distance _csp < (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE")) then {_enable = true};
				};
				if (!_enable && !isNil "WFBE_CL_FNC_CanUseRepairPointEASA") then {
					if ([player, vehicle player] Call WFBE_CL_FNC_CanUseRepairPointEASA) then {
						_enable = true;
						_enableRepairPointEASA = true;
					};
				};
			};
		};
	};
	//--- GUER Insurgents are base-less (no service points, no EASA upgrade economy above): grant EASA at FRIENDLY
	//--- town centers instead. GUER-only (the resistance gate locks WEST/EAST out). No cooldown -> treated like a
	//--- base service point, so WFBE_CL_V_RepairPointEASAActive stays false and the menu uses the normal buy path.
	if (!_enable && (missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {sideJoined == resistance}) then {
		if (typeOf(vehicle player) in (missionNamespace getVariable 'WFBE_EASA_Vehicles') && {driver (vehicle player) == player}) then {
			if (!isNil "WFBE_CL_FNC_CanUseTownCenterEASA" && {[player, vehicle player] Call WFBE_CL_FNC_CanUseTownCenterEASA}) then {_enable = true};
		};
	};
	WFBE_CL_V_RepairPointEASAActive = _enableRepairPointEASA;
	ctrlEnable [20010,_enable];
} else {
	WFBE_CL_V_RepairPointEASAActive = false;
	ctrlEnable [20010,false];
};

_effective = [];
_nearSupport = [];
_spType = missionNamespace getVariable Format ["%1SP",sideJoinedText];
_i = 0;
{
	_closestSP = objNull;
	_add = false;
	
	_nearSupport set [_i, []];
	
	//--- Service Point.
	if (count _sp > 0) then {
		_closestSP = [_x,_sp] Call WFBE_CO_FNC_GetClosestEntity;
		if !(isNull _closestSP) then {
			if (_x distance _closestSP < (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE")) then {
				_add = true;
				_nearSupport set [_i,(_nearSupport select _i) + [_closestSP]];
			};
		};
	};

	//--- Depots.
	_nObject = [_x, (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE")] Call WFBE_CL_FNC_GetClosestDepot;
	
	if !(isNull _nObject) then {
		_add = true;
		_nearSupport set [_i,(_nearSupport select _i) + [_nObject]];
	};
	
	//--- Repairs Trucks.
	_checks = (getPos _x) nearEntities[_typeRepair, missionNamespace getVariable "WFBE_C_UNITS_REPAIR_TRUCK_RANGE"];
	if (count _checks > 0) then {
		_add = true;
		_nearSupport set [_i,(_nearSupport select _i) + _checks];
	};
		
	//--- Repair-truck-built service points (EASA-capable defenses; not in the side structures list).  FIX: rearm/repair/refuel now see a service point built from a repair truck.
	_rtSPs = nearestObjects [getPos _x, ["Base_WarfareBVehicleServicePoint"], (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE")];
	{
		if (alive _x && {_x getVariable ["WFBE_RepairTruckServicePoint", false]}) then {
			_add = true;
			_nearSupport set [_i,(_nearSupport select _i) + [_x]];
		};
	} forEach _rtSPs;

	//--- Add the vehicle ?
	if (_add) then {
		_effective = _effective + [_x];
		_desc = [typeOf _x, 'displayName'] Call GetConfigInfo;
		_finalNumber = (_x) Call GetAIDigit;
		_isInVehicle = "";
		if (_x != vehicle _x) then {
			_descVehi = [typeOf (vehicle _x), 'displayName'] Call GetConfigInfo;
			_isInVehicle = " [" + _descVehi + "] ";
		};
		private ["_svc","_state"];
			//--- QoL: open-time damage (and fuel, for vehicles) snapshot on each service-list row.
			_svc = vehicle _x;
			_state = " (dmg " + str (round ((getDammage _svc) * 100)) + "%";
			if !(_svc isKindOf "Man") then {_state = _state + " fuel " + str (round ((fuel _svc) * 100)) + "% ammo " + str (round ((_svc Call WFBE_CO_FNC_GetAmmoFraction) * 100)) + "%"};
			_state = _state + ")";
			_txt = "["+_finalNumber+"] "+ _desc + _isInVehicle + _state;
		lbAdd[20002,_txt];
		
		_i = _i + 1;
	};
} forEach _vehi;

_checks = (getPos player) nearEntities[_typeRepair, missionNamespace getVariable "WFBE_C_UNITS_REPAIR_TRUCK_RANGE"];
if (count _checks > 0) then {
	_repair = _checks select 0;
	_vehi = ((getPos _repair) nearEntities[["Car","Motorcycle","Tank","Air","Ship","StaticWeapon"],100]) - [_repair];
	{
		if (!(_x in _effective) && {side _x in [sideJoined, civilian]}) then {
			_effective = _effective + [_x];
			_nearSupport set [_i,[_repair]];
			_descVehi = [typeOf (vehicle _x), 'displayName'] Call GetConfigInfo;
			lbAdd[20002,_descVehi];

			_i = _i + 1;
		};
	} forEach _vehi;
};

if (count _effective > 0) then {lbSetCurSel[20002,0]};

while {true} do {
	sleep 0.1;
	
	if (side group player != sideJoined) exitWith {closeDialog 0};
	if (!dialog) exitWith {};
	_curSel = lbCurSel(20002);
	_funds = Call GetPlayerFunds;
	_veh = objNull;
	_desc = "";
	_blockReason = "";
	_canBeUsed = false;
	_martyFullData = [[],0];
	_martyFullActions = [];
	_martyFullPrice = 0;
	_martyFullEnabled = false;
	if ((_curSel < 0) || (_curSel >= count _effective)) then {_curSel = -1};

	// Marty: Refresh batch prices from the current list so all-unit buttons stay all-or-nothing.
	_martyRearmBatchData = ["REARM",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyRepairBatchData = ["REPAIR",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyRefuelBatchData = ["REFUEL",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyHealBatchData = ["HEAL",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyRearmBatch = _martyRearmBatchData select 0;
	_martyRepairBatch = _martyRepairBatchData select 0;
	_martyRefuelBatch = _martyRefuelBatchData select 0;
	_martyHealBatch = _martyHealBatchData select 0;
	_martyRearmPrice = _martyRearmBatchData select 1;
	_martyRepairPrice = _martyRepairBatchData select 1;
	_martyRefuelPrice = _martyRefuelBatchData select 1;
	_martyHealPrice = _martyHealBatchData select 1;

	ctrlSetText [20016,"$"+str(_martyRearmPrice)];
	ctrlSetText [20018,"$"+str(_martyRepairPrice)];
	ctrlSetText [20020,"$"+str(_martyHealPrice)];
	//--- QoL item4 (client-qol-batch2): refuel-all batch price label (idc 20025, mirrors 20016/18/20).
	ctrlSetText [20025,"$"+str(_martyRefuelPrice)];

	_martyEnableRearm = false;
	_martyEnableRepair = false;
	_martyEnableRefuel = false;
	_martyEnableHeal = false;
	if ((count _martyRearmBatch) > 0) then {_martyEnableRearm = _funds >= _martyRearmPrice};
	if ((count _martyRepairBatch) > 0) then {_martyEnableRepair = _funds >= _martyRepairPrice};
	if ((count _martyRefuelBatch) > 0) then {_martyEnableRefuel = _funds >= _martyRefuelPrice};
	if ((count _martyHealBatch) > 0) then {_martyEnableHeal = _funds >= _martyHealPrice};

	ctrlEnable [20015,_martyEnableRearm];
	ctrlEnable [20017,_martyEnableRepair];
	ctrlEnable [20022,_martyEnableRefuel];
	ctrlEnable [20019,_martyEnableHeal];

	// Marty: Single-unit buttons use the same service price and eligibility helpers as the batch buttons.
	if (_curSel != -1) then {
		_veh = (vehicle (_effective select _curSel));
		_desc = [typeOf _veh, 'displayName'] Call GetConfigInfo;
		_blockReason = [_veh] Call _martyServiceBlockReason;
		_canBeUsed = [_veh] Call _martyServiceCanUse;
		
		if (_veh isKindOf "Man") then {
			{ctrlEnable [_x,false]} forEach [20003,20004,20005];
			ctrlSetText [20008,"Heal Unit"];
			//--- Healing.
			_healPrice = [_veh,"HEAL"] Call _martyServiceGetPrice;
			_enabled = if (_healPrice > 0 && _funds >= _healPrice) then {true} else {false};
			ctrlEnable [20008,_enabled];
			ctrlSetText [20011,"$0"];
			ctrlSetText [20012,"$0"];
			ctrlSetText [20013,"$0"];
			ctrlSetText [20014,"$"+str(_healPrice)];
			_martyFullData = [_veh] Call _martyServiceBuildFull;
			if ((typeName _martyFullData == "ARRAY") && {(count _martyFullData) > 1}) then {
				_martyFullActions = _martyFullData select 0;
				_martyFullPrice = _martyFullData select 1;
			};
		} else {
			//--- Prevent on the air re-supply.
			ctrlSetText [20008,"Heal Crew"];
			//--- Healing.
			_healPrice = [_veh,"HEAL"] Call _martyServiceGetPrice;
			ctrlSetText [20014,"$"+str(_healPrice)];
			//--- Repair.
			_repairPrice = [_veh,"REPAIR"] Call _martyServiceGetPrice;
			ctrlSetText [20012,"$"+str(_repairPrice)];
			//--- Rearm.
			_rearmPrice = [_veh,"REARM"] Call _martyServiceGetPrice;
			ctrlSetText [20011,"$"+str(_rearmPrice)];
			//--- Refuel.
			_refuelPrice = [_veh,"REFUEL"] Call _martyServiceGetPrice;
			ctrlSetText [20013,"$"+str(_refuelPrice)];

			_enabled = if (_canBeUsed && _rearmPrice > 0 && _funds >= _rearmPrice) then {true} else {false};
			ctrlEnable [20003,_enabled];
			_enabled = if (_canBeUsed && _repairPrice > 0 && _funds >= _repairPrice && !(_veh getVariable ["wfbe_repair_inProgress", false])) then {true} else {false};
			ctrlEnable [20004,_enabled];
			_enabled = if (_canBeUsed && _refuelPrice > 0 && _funds >= _refuelPrice) then {true} else {false};
			ctrlEnable [20005,_enabled];
			_enabled = if (_canBeUsed && _healPrice > 0 && _funds >= _healPrice) then {true} else {false};
			ctrlEnable [20008,_enabled];
			_martyFullData = [_veh] Call _martyServiceBuildFull;
			if ((typeName _martyFullData == "ARRAY") && {(count _martyFullData) > 1}) then {
				_martyFullActions = _martyFullData select 0;
				_martyFullPrice = _martyFullData select 1;
			};
		};

		ctrlSetText [20024,"$"+str(_martyFullPrice)];
		_martyFullEnabled = _canBeUsed && ((count _martyFullActions) > 0) && (_funds >= _martyFullPrice);
		ctrlEnable [20023,_martyFullEnabled];

		_serviceState = if (_blockReason != "") then {"Blocked: " + _blockReason} else {"Ready"};
		if (_blockReason == "") then {
			if (_martyFullPrice > _funds && (count _martyFullActions) > 0) then {_serviceState = "Need $" + str(_martyFullPrice - _funds) + " for full service"};
			if ((count _martyFullActions) == 0) then {_serviceState = "No selected service needed"};
		};
		_damageText = str(round((getDammage _veh) * 100)) + "%";
		_fuelText = if (_veh isKindOf "Man") then {"Inf"} else {str(round((fuel _veh) * 100)) + "%"};
		_ammoText = if (_veh isKindOf "Man") then {"-"} else {str(round((_veh Call WFBE_CO_FNC_GetAmmoFraction) * 100)) + "%"};
		_dialog = findDisplay 20000;
		if (!isNull _dialog) then {
			(_dialog displayCtrl 20021) ctrlSetStructuredText (parseText Format["<t color='#f0e68c' shadow='1'>%1 | Dmg %2 | Fuel %3 | Ammo %9</t><br /><t color='#f0e68c' shadow='1'>%4 | All Rm $%5 Rp $%6 Rf $%7 Hl $%8</t>",_desc,_damageText,_fuelText,_serviceState,_martyRearmPrice,_martyRepairPrice,_martyRefuelPrice,_martyHealPrice,_ammoText]);
		};
		
		_lastVeh = _veh;
		
		//--- Rearm.
		if (MenuAction == 1) then {
			MenuAction = -1;
			if ((_curSel != -1) && {[_veh,_nearSupport select _curSel] Call _martyRearmBlockedAirDepot}) then {
				hint "You can't rearm air in town"; //--- fix(hunt): precondition BEFORE the charge - SupportRearm hard-aborts this case AFTER the money is taken (no refund path).
			} else {
				if (_funds >= _rearmPrice) then { //--- QoL: affordability guard (parity with repair/heal)
				-_rearmPrice Call ChangePlayerFunds;

				//--- Spawn a Rearm thread.
				[_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRearm;
				};
			};
		};	
		
		//--- Repair.
		if (MenuAction == 2) then {
			MenuAction = -1;

			if (!(_veh getVariable ["wfbe_repair_inProgress", false]) && _repairPrice > 0 && _funds >= _repairPrice) then { //--- guard: skip if repair already in progress (parity with rearm/refuel)
                -_repairPrice Call ChangePlayerFunds;

                //--- Spawn a Repair thread.
                [_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRepair;
			};
		};
		
		//--- Refuel.
		if (MenuAction == 3) then {
			MenuAction = -1;
			if (_funds >= _refuelPrice) then { //--- QoL: affordability guard (parity with repair/heal)
			-_refuelPrice Call ChangePlayerFunds;

			//--- Spawn a Refuel thread.
			[_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRefuel;
			};
		};
		
		//--- Heal.
		if (MenuAction == 5) then {
			MenuAction = -1;

			if (_healPrice > 0 && _funds >= _healPrice) then { //--- wiki-wins: affordability guard (parity with rearm/refuel)
			    -_healPrice Call ChangePlayerFunds;

			    //--- Spawn a Healing thread.
			    [_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportHeal;
			};
		};
	} else {
		{ctrlEnable[_x,false]} forEach [20003,20004,20005,20008,20015,20017,20019,20022,20023];
		_dialog = findDisplay 20000;
		if (!isNull _dialog) then {
			(_dialog displayCtrl 20021) ctrlSetStructuredText (parseText "<t color='#f0e68c' shadow='1'>No service target selected</t>");
		};
		ctrlSetText [20024,"$0"];
	};

	// Marty: All-unit service actions are based on the same refreshed batch data used to enable the buttons.
	if (MenuAction == 11) then {
		MenuAction = -1;
		["REARM",_martyRearmBatch,_martyRearmPrice,_typeRepair,_spType,"Rearm"] Call _martyServiceStartBatch;
	};

	if (MenuAction == 12) then {
		MenuAction = -1;
		["REPAIR",_martyRepairBatch,_martyRepairPrice,_typeRepair,_spType,"Repair"] Call _martyServiceStartBatch;
	};

	if (MenuAction == 13) then {
		MenuAction = -1;
		["REFUEL",_martyRefuelBatch,_martyRefuelPrice,_typeRepair,_spType,"Refuel"] Call _martyServiceStartBatch;
	};

	if (MenuAction == 15) then {
		MenuAction = -1;
		["HEAL",_martyHealBatch,_martyHealPrice,_typeRepair,_spType,"Heal"] Call _martyServiceStartBatch;
	};

	if (MenuAction == 16) then {
		MenuAction = -1;
		if ((_curSel != -1) && {!isNull _veh}) then {
			[_veh,_nearSupport select _curSel,_martyFullActions,_martyFullPrice,_typeRepair,_spType] Call _martyServiceStartFull;
		};
	};
	
	//--- EASA. TBD: Add dialog;
	if (MenuAction == 7) then {
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_EASA";
	};
	
	//--- Back Button.
	if (MenuAction == 8) exitWith { //---added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};
};
