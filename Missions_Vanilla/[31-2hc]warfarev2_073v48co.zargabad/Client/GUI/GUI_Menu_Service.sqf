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

// Marty: Shared service helpers used by the selected-unit buttons and the new all-unit buttons.
_martyServiceGetPrice = {
	Private ["_action","_get","_price","_type","_veh"];
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

	if (_action == "REPAIR") exitWith {
		if (getDammage _veh <= 0) exitWith {0};
		if (isNil "_get") exitWith {500};
		round((getDammage _veh) * ((_get select QUERYUNITPRICE) / (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_REPAIR_PRICE")))
	};

	if (_action == "REARM") exitWith {
		if (isNil "_get") exitWith {500};
		round((_get select QUERYUNITPRICE) / (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_REARM_PRICE"))
	};

	0
};

// Marty: Vehicles cannot use vehicle services while moving too fast or airborne; infantry healing remains allowed.
_martyServiceCanUse = {
	Private ["_veh"];
	_veh = _this select 0;

	if (_veh isKindOf "Man") exitWith {true};
	if (((getPos _veh) select 2) > 2) exitWith {false};
	if (speed _veh > 20) exitWith {false};

	true
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
	_currentUpgrades = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
	_easaLevel = _currentUpgrades select WFBE_UP_EASA;
	if (!(isNull _csp) && _easaLevel > 0) then {
		if (player distance _csp < (missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_RANGE")) then {
			if (typeOf(vehicle player) in (missionNamespace getVariable 'WFBE_EASA_Vehicles')) then {
				if (driver (vehicle player) == player) then {_enable = true};
			};
		};
	};
	ctrlEnable [20010,_enable];
} else {
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
		_txt = "["+_finalNumber+"] "+ _desc + _isInVehicle;
		lbAdd[20002,_txt];
		
		_i = _i + 1;
	};
} forEach _vehi;

_checks = (getPos player) nearEntities[_typeRepair, missionNamespace getVariable "WFBE_C_UNITS_REPAIR_TRUCK_RANGE"];
if (count _checks > 0) then {
	_repair = _checks select 0;
	_vehi = ((getPos _repair) nearEntities[["Car","Motorcycle","Tank","Air","Ship","StaticWeapon"],100]) - [_repair];
	{
		if !(_x in _effective) then {
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

	// Marty: Refresh batch prices from the current list so all-unit buttons stay all-or-nothing.
	_martyRearmBatchData = ["REARM",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyRepairBatchData = ["REPAIR",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyHealBatchData = ["HEAL",_effective,_nearSupport] Call _martyServiceBuildBatch;
	_martyRearmBatch = _martyRearmBatchData select 0;
	_martyRepairBatch = _martyRepairBatchData select 0;
	_martyHealBatch = _martyHealBatchData select 0;
	_martyRearmPrice = _martyRearmBatchData select 1;
	_martyRepairPrice = _martyRepairBatchData select 1;
	_martyHealPrice = _martyHealBatchData select 1;

	ctrlSetText [20016,"$"+str(_martyRearmPrice)];
	ctrlSetText [20018,"$"+str(_martyRepairPrice)];
	ctrlSetText [20020,"$"+str(_martyHealPrice)];

	_martyEnableRearm = false;
	_martyEnableRepair = false;
	_martyEnableHeal = false;
	if ((count _martyRearmBatch) > 0) then {_martyEnableRearm = _funds >= _martyRearmPrice};
	if ((count _martyRepairBatch) > 0) then {_martyEnableRepair = _funds >= _martyRepairPrice};
	if ((count _martyHealBatch) > 0) then {_martyEnableHeal = _funds >= _martyHealPrice};

	ctrlEnable [20015,_martyEnableRearm];
	ctrlEnable [20017,_martyEnableRepair];
	ctrlEnable [20019,_martyEnableHeal];

	// Marty: Single-unit buttons use the same service price and eligibility helpers as the batch buttons.
	if (_curSel != -1) then {
		_veh = (vehicle (_effective select _curSel));
		
		if (_veh isKindOf "Man") then {
			{ctrlEnable [_x,false]} forEach [20003,20004,20005];
			//--- Healing.
			_healPrice = [_veh,"HEAL"] Call _martyServiceGetPrice;
			_enabled = if (_healPrice > 0 && _funds >= _healPrice) then {true} else {false};
			ctrlEnable [20008,_enabled];
			ctrlSetText [20011,"$0"];
			ctrlSetText [20012,"$0"];
			ctrlSetText [20013,"$0"];
			ctrlSetText [20014,"$"+str(_healPrice)];
		} else {
			//--- Prevent on the air re-supply.
			_canBeUsed = [_veh] Call _martyServiceCanUse;
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
			if (_veh != _lastVeh || fuel _veh != _lastFue) then {
				_type = typeOf _veh;
				_lastFue = fuel _veh;
				_get = missionNamespace getVariable _type;
				if !(isNil '_get') then {
					_fuel = ((fuel _veh) -1) * -1;
					_refuelPrice = round(_fuel*((_get select QUERYUNITPRICE)/(missionNamespace getVariable "WFBE_C_UNITS_SUPPORT_REFUEL_PRICE")));
				} else {
					_refuelPrice = 200;
				};
			};
			ctrlSetText [20013,"$"+str(_refuelPrice)];

			_enabled = if (_canBeUsed && _rearmPrice > 0 && _funds >= _rearmPrice) then {true} else {false};
			ctrlEnable [20003,_enabled];
			_enabled = if (_canBeUsed && _repairPrice > 0 && _funds >= _repairPrice) then {true} else {false};
			ctrlEnable [20004,_enabled];
			_enabled = if (_canBeUsed && _refuelPrice > 0 && _funds >= _refuelPrice) then {true} else {false};
			ctrlEnable [20005,_enabled];
			_enabled = if (_canBeUsed && _healPrice > 0 && _funds >= _healPrice) then {true} else {false};
			ctrlEnable [20008,_enabled];
		};
		
		_lastVeh = _veh;
		
		//--- Rearm.
		if (MenuAction == 1) then {
			MenuAction = -1;
			-_rearmPrice Call ChangePlayerFunds;
			
			//--- Spawn a Rearm thread.
			[_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRearm;
		};	
		
		//--- Repair.
		if (MenuAction == 2) then {
			MenuAction = -1;

			if (_repairPrice > 0) then {
                -_repairPrice Call ChangePlayerFunds;

                //--- Spawn a Repair thread.
                [_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRepair;
			};
		};
		
		//--- Refuel.
		if (MenuAction == 3) then {
			MenuAction = -1;
			-_refuelPrice Call ChangePlayerFunds;

			//--- Spawn a Refuel thread.
			[_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportRefuel;
		};
		
		//--- Heal.
		if (MenuAction == 5) then {
			MenuAction = -1;

			if (_healPrice > 0) then {
			    -_healPrice Call ChangePlayerFunds;

			    //--- Spawn a Healing thread.
			    [_veh,_nearSupport select _curSel,_typeRepair,_spType] Spawn SupportHeal;
			};
		};
	} else {
		{ctrlEnable[_x,false]} forEach [20003,20004,20005,20008];
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

	if (MenuAction == 15) then {
		MenuAction = -1;
		["HEAL",_martyHealBatch,_martyHealPrice,_typeRepair,_spType,"Heal"] Call _martyServiceStartBatch;
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
