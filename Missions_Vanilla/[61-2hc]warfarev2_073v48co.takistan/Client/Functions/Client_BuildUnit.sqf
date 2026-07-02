Private ["_building","_cpt","_commander","_crew","_currentUnit","_description","_direction","_distance","_driver","_extracrew","_factory","_factoryPosition","_factoryType","_group","_gunner","_index","_init","_isArtillery","_isMan","_locked","_longest","_position","_queu","_queu2","_ret","_show","_soldier","_spawnedUnits","_waitTime","_txt","_type","_upgrades","_unique","_unit","_vehi","_vehicle","_vehicles","_faction","_queuLabels","_unitLabel33","_ah6xM134Kit","_tkEasaKit","_tkeRow"];
_building = _this select 0;
_unit = _this select 1;
_vehi = _this select 2;
_factory = _this select 3;
_cpt = _this select 4;
_currentCost = if (count _this > 5) then {_this select 5} else {0}; //--- FC2: purchase price, for refund if the factory is destroyed mid-build.

_isMan = if (_unit isKindOf "Man") then {true} else {false};

unitQueu = unitQueu + _cpt;

_distance = 0;
_direction = 0;
_longest = 0;
_position = 0;
_waitTime = 0;
_factoryType = "";
_description = "";

_currentUnit = missionNamespace getVariable _unit;
_waitTime = _currentUnit select QUERYUNITTIME;
_description = _currentUnit select QUERYUNITLABEL;
	
_spawnpaddir=2;


_type = typeOf _building;
_index = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",sideJoinedText]) find _type;
if (_index != -1) then {
	_distance = (missionNamespace getVariable Format ["WFBE_%1STRUCTUREDISTANCES",sideJoinedText]) select _index;
	_direction = (missionNamespace getVariable Format ["WFBE_%1STRUCTUREDIRECTIONS",sideJoinedText]) select _index;
	_factoryType = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES",sideJoinedText]) select _index;

	
if (_factoryType in ["Light"]) then {
	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];

	_pads = _building nearObjects ["HeliH", 250];

	// Filter out unwanted objects from _pads based on their names (because they inherit from HeliH)
    _filteredPads = [];
    {
        if (typeOf _x != "HeliHCivil" && typeOf _x != "HeliHRescue") then {
            _filteredPads set [count _filteredPads, _x];
        };
    } forEach _pads;
    _pads = _filteredPads;

	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

}else{//---------------------------------------------------------check for heavy


if (_factoryType in ["Heavy"]) then {
	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];
	_pads = _building nearObjects ["HeliHRescue", 250];
	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

}else{//--------------------------------------------------------check for air


if (_factoryType in ["Aircraft"]) then {
	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];
	_pads = _building nearObjects ["HeliHCivil", 250];
	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

}else{//-------------------------------------------its barracks,found only 3 marker in a2 for now

	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];
	_pads = _building nearObjects ["Sr_border", 250];
	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

//_position = [getPos _building,_distance,getDir _building + _direction] Call GetPositionFrom;

};};};

_longest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME",_factoryType];
	
	
} else {
	if (_type == WFBE_Logic_Depot) then {
		_distance = missionNamespace getVariable "WFBE_C_DEPOT_BUY_DISTANCE";
		_direction = missionNamespace getVariable "WFBE_C_DEPOT_BUY_DIR";
		_factoryType = "Depot";
	};
	if (_type == WFBE_Logic_Airfield) then {
		_distance = missionNamespace getVariable "WFBE_C_HANGAR_BUY_DISTANCE";
		_direction = missionNamespace getVariable "WFBE_C_HANGAR_BUY_DIR";
		_factoryType = "Airport";
	};
	_position = [getPos _building,_distance,getDir _building + _direction] Call GetPositionFrom;
	_longest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME",_factoryType];
};

if ((missionNamespace getVariable ["WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING", 0]) > 0) then {
	if (isNil "WFBE_CL_FACTORY_QUEUE_SEQUENCE") then {WFBE_CL_FACTORY_QUEUE_SEQUENCE = 0};
	WFBE_CL_FACTORY_QUEUE_SEQUENCE = WFBE_CL_FACTORY_QUEUE_SEQUENCE + 1;
	varQueu = Format["%1_%2_%3_%4", getPlayerUID player, diag_tickTime, WFBE_CL_FACTORY_QUEUE_SEQUENCE, floor random 1000000];
} else {
	varQueu = Format["%1_%2", getPlayerUID player, diag_tickTime];
};
_unique = varQueu;
_queu = _building getVariable "queu";
if (isNil "_queu") then {_queu = []};
_queu = _queu + [_unique];
_building setVariable ["queu",_queu,true];
//--- QoL cancel: store price-paid and cpt in parallel arrays so Action_CancelQueue.sqf can refund correctly.
private ["_queuCosts","_queuCpts"];
_queuCosts = _building getVariable ["queu_costs", []];
_queuCosts = _queuCosts + [_currentCost];
_building setVariable ["queu_costs", _queuCosts, true];
_queuCpts = _building getVariable ["queu_cpts", []];
_queuCpts = _queuCpts + [_cpt];
_building setVariable ["queu_cpts", _queuCpts, true];
//--- Task 33: store the human-readable unit label so the buy-menu queue readout can display it.
_unitLabel33 = _currentUnit select QUERYUNITLABEL;
_queuLabels = _building getVariable ["queu_labels", []];
_queuLabels = _queuLabels + [_unitLabel33];
_building setVariable ["queu_labels", _queuLabels, true];
//--- QoL cancel: add a cancel action on this building for the buyer (removed after their slot resolves).
private ["_cancelActionID"];
_cancelActionID = _building addAction [
	"<t color='#ff9900'>Cancel last queued unit</t>",
	"Client\Action\Action_CancelQueue.sqf",
	[_factory],
	50,
	false,
	true,
	"",
	"cursorObject == _target && player distance _target < 25"
];
_building setVariable [Format ["wfbe_cancel_action_%1", getPlayerUID player], _cancelActionID];

_ret = 0;
_queu2 = [0];

if (count _queu > 0) then {_queu2 = _building getVariable "queu"};

_show = false;
while {_unique != _queu select 0 && alive _building && !isNull _building} do {
	sleep 4;
	_show = true;
	_ret = _ret + 4;
	_queu = _building getVariable "queu";

	if (_queu select 0 == _queu2 select 0) then {
		if (_ret > _longest) then {
			if (count _queu > 0) then {
				_queu = _building getVariable "queu";
				_queu = _queu - [_queu select 0];
				_building setVariable ["queu",_queu,true];
			};
		};
	};
	if (count _queu != count _queu2) then {
		_ret = 0;
		_queu2 = _building getVariable "queu";
	};
};

if (_show) then {hint(parseText(Format [localize "STR_WF_INFO_BuyEffective",_description]))};

sleep _waitTime;

_queu = _building getVariable "queu";
private ["_qIdx"];
_qIdx = _queu find _unique;
_queu = _queu - [_unique];
_building setVariable ["queu",_queu,true];
//--- QoL cancel: keep parallel arrays in sync when the unit actually spawns.
if (_qIdx >= 0) then {
	private ["_qCosts","_qCpts","_qLabels","_newArr","_i"];
	_qCosts = _building getVariable ["queu_costs", []];
	_qCpts  = _building getVariable ["queu_cpts",  []];
	_qLabels = _building getVariable ["queu_labels", []];
	if (_qIdx < count _qCosts) then {
		_newArr = []; _i = 0;
		{if (_i != _qIdx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _qCosts;
		_building setVariable ["queu_costs", _newArr, true];
	};
	if (_qIdx < count _qCpts) then {
		_newArr = []; _i = 0;
		{if (_i != _qIdx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _qCpts;
		_building setVariable ["queu_cpts", _newArr, true];
	};
	//--- Task 33: keep queu_labels in sync.
	if (_qIdx < count _qLabels) then {
		_newArr = []; _i = 0;
		{if (_i != _qIdx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _qLabels;
		_building setVariable ["queu_labels", _newArr, true];
	};
};
//--- QoL cancel: remove the per-player cancel action once their slot is resolved.
private ["_myActionKey","_myActionID"];
_myActionKey = Format ["wfbe_cancel_action_%1", getPlayerUID player];
_myActionID = _building getVariable [_myActionKey, -1];
if (_myActionID >= 0) then {
	_building removeAction _myActionID;
	_building setVariable [_myActionKey, -1];
};

//--- E1: was this slot CANCELLED during its build? Action_CancelQueue removed _unique from the queue,
//--- already decremented unitQueu + WFBE_C_QUEUE_<factory>, and refunded the price. Bail WITHOUT spawning
//--- (else the player keeps BOTH the refund AND the unit) and WITHOUT re-touching the counters (the cancel
//--- already balanced them). _qIdx (queue index just after sleep) == -1 means no longer queued => cancelled.
if (_qIdx < 0) exitWith {};
_group = group player;
_spawnedUnits = [];
if (!alive _building || isNull _building) exitWith {
	unitQueu = unitQueu - _cpt;
	missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_factory],(missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_factory])-1];
	//--- FC2: factory was destroyed mid-build (nothing spawned) -> refund the purchase price. This is the real destroyed-factory path.
	if (_currentCost > 0) then {(_currentCost) Call ChangePlayerFunds};
};

if (_isMan) then {
	_soldier = [_unit,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;

	//--- OA or CO, Since BIS will soon fix it... not!, we fix unit backpack attachment on creation.
	if (WF_A2_Arrowhead || WF_A2_CombinedOps) then {
		//--- Make sure that our unit is supposed to have a backpack.
		if (getText(configFile >> 'CfgVehicles' >> _unit >> 'backpack') != "") then {
			//--- Retrieve the unit gear config.
			_gear_config = (_unit) Call WFBE_CO_FNC_GetUnitConfigGear;
			_gear_backpack = _gear_config select 2;
			_gear_backpack_content = _gear_config select 3;

			//--- Backpack handling.
			if (_gear_backpack != "") then {[_soldier, _gear_backpack, _gear_backpack_content] Call WFBE_CO_FNC_EquipBackpack};
		};
	};

	_spawnedUnits = [_soldier];

	[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;
} else {
	_driver = _vehi select 0;
	_gunner = _vehi select 1;
	_commander = _vehi select 2;
	_extracrew = _vehi select 3;
	_locked = _vehi select 4;

	_factoryPosition = getPos _building;
	
	
	if (_spawnpaddir==2) then {//there is no spawnpad
	_direction = -((((_position select 1) - (_factoryPosition select 1)) atan2 ((_position select 0) - (_factoryPosition select 0))) - 90);//--- model to world that later on.
	};
	//--- cmdcon42 Option C Row 2: the synthetic buy token "AH6X_M134" is NOT a CfgVehicles class, so
	//--- createVehicle on it would return objNull. Capture the variant flag (the tuple time/label were
	//--- already read from the synthetic key at :21-23 above, giving the 5500 price + "AH-6X (M134)" name),
	//--- then remap _unit to the real hull AH6X_EP1 BEFORE createVehicle. After this line every downstream
	//--- _unit use (createVehicle, isKindOf "Air" pilot-crew + CM/AA blocks) sees the real hull.
	_ah6xM134Kit = (_unit == "AH6X_M134");
	if (_ah6xM134Kit) then {_unit = "AH6X_EP1"};

	//--- cmdcon42-i: TK-EASA variant tokens (e.g. "TKV_AH64D_HELLFIRE") are SYNTHETIC buy keys, NOT CfgVehicles
	//--- classes, so createVehicle on the token would return objNull. Resolve the catalog row (self-gates on
	//--- worldName + WFBE_C_TK_EASA_ROSTER -> [] on Chernarus), capture the kit, then remap _unit to the real base
	//--- hull BEFORE createVehicle so every downstream _unit use (createVehicle, isKindOf "Air" crew/CM blocks)
	//--- sees the real hull. Mirrors the AH6X_M134 precedent (Core_US.sqf synthetic token, PR #151).
	//--- Cheap prefix guard: TK-EASA synthetic tokens are the only classes prefixed "TKV_", so a normal purchase
	//--- (real hull, any map) skips the catalog lookup entirely (no compile, no forEach) - the catalog is only
	//--- consulted for an actual variant buy, which only exists on Takistan with the flag on.
	_tkEasaKit = [];
	if ((_unit find "TKV_") == 0) then {
		{
			if ((_x select 0) == _unit) exitWith { _tkeRow = _x; _unit = _x select 1; _tkEasaKit = _x select 7; };
		} forEach (Call Compile preprocessFile "Common\Functions\Common_TKEasaRoster.sqf");
	};
	_vehicle = [_unit, _position, sideID, _direction, _locked] Call WFBE_CO_FNC_CreateVehicle;

	//--- cmdcon42c HOTFIX (Ray 2026-07-02): UNIVERSAL BUYFAIL-REFUND GUARD. WFBE_CO_FNC_CreateVehicle
	//--- returns objNull whenever the engine cannot spawn the hull - a bad/unresolved buy class (e.g. a
	//--- synthetic AH6X_M134 / TKV_* token whose remap above did not resolve to a real hull), a blocked
	//--- spawn position, or any createVehicle failure. The player was ALREADY charged at buy time
	//--- (GUI_Menu_BuyUnits.sqf: -(_currentCost) Call ChangePlayerFunds), so a silent null spawn = the
	//--- player pays and gets nothing. Detect it here and (a) release the per-factory queue slot + unitQueu
	//--- (else the factory soft-locks at its cap, exactly like the empty-vehicle exit does), and (b) refund
	//--- the exact price paid. Same idiom as the destroyed-factory refund path (:282-287 above).
	if (isNull _vehicle) exitWith {
		unitQueu = unitQueu - _cpt;
		missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_factory],(missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_factory])-1];
		if (_currentCost > 0) then {(_currentCost) Call ChangePlayerFunds};
		["WARNING", Format ["Client_BuildUnit.sqf: buy of [%1] produced objNull (spawn failed) - refunded $%2 and released queue slot for factory [%3].", _unit, _currentCost, _factory]] Call WFBE_CO_FNC_LogContent;
	};

	clientTeam reveal _vehicle;

	//--- cmdcon42 Option C Row 2: arm the AH-6X hull with the AH-6J's minigun. The AH6X_EP1 hull ships
	//--- UNARMED (weapons[]={}/magazines[]={}, config-proven from CfgVehicles AH6X_EP1). We add the exact
	//--- weapon+magazine the armed AH6J_EP1 carries: weapon "TwinM134" (class TwinM134 : M134) and magazine
	//--- "4000Rnd_762x51_M134" (both config-proven present in CfgWeapons/CfgMagazines). On the AH-6 these are
	//--- HULL-level (AH6J_EP1 weapons[]/magazines[] sit on the vehicle body, class Turrets {} is empty), so
	//--- plain addWeapon/addMagazine (NOT the [-1] turret path used for the Ka-137). Runs on the buyer's client
	//--- on the freshly-created local hull (same machine/timing as the existing GUER Ka-137 flares kit below);
	//--- Common_CreateVehicle globalizes the hull via setVehicleInit right after creation, so the weapon state
	//--- replicates. Idempotent remove-then-add so a re-buy or JIP re-run cannot stack duplicate mags.
	if (_ah6xM134Kit && {!isNull _vehicle}) then {
		_vehicle removeMagazine "4000Rnd_762x51_M134";
		_vehicle removeWeapon "TwinM134";
		_vehicle addWeapon "TwinM134";
		_vehicle addMagazine "4000Rnd_762x51_M134";
		["INFORMATION", Format ["Client_BuildUnit.sqf: AH-6X (M134) armed with TwinM134 + 4000Rnd_762x51_M134 [%1].", typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};

	//--- cmdcon42-i: arm the freshly-created base hull with the variant's EASA-proven weapon+magazine kit.
	//--- All four TK-EASA base hulls (AH64D_EP1 / A10_US_EP1 / Mi24_D_TK_EP1 / Su25_TK_EP1) mount at HULL level
	//--- (none is in EASA_Equip's turret-special list), so plain addWeapon/addMagazine is correct - same path,
	//--- machine and timing as the AH6X_M134 kit. Idempotent remove-then-add so a re-buy / JIP re-run cannot
	//--- stack duplicate mags. Runs on the buyer's client on the local hull; WFBE_CO_FNC_CreateVehicle globalises
	//--- the hull (setVehicleInit) right after creation, so the weapon state replicates. Kit classnames are reused
	//--- verbatim from Client\Module\EASA\EASA_Init.sqf for the same base hull (all config-proven on that airframe).
	if ((count _tkEasaKit) == 2 && {!isNull _vehicle}) then {
		{ _vehicle removeMagazine _x } forEach (_tkEasaKit select 1);
		{ _vehicle removeWeapon _x }   forEach (_tkEasaKit select 0);
		{ _vehicle addWeapon _x }      forEach (_tkEasaKit select 0);
		{ _vehicle addMagazine _x }    forEach (_tkEasaKit select 1);
		["INFORMATION", Format ["Client_BuildUnit.sqf: TK-EASA variant '%1' armed on %2 (weapons %3).", (_tkeRow select 0), typeOf _vehicle, (_tkEasaKit select 0)]] Call WFBE_CO_FNC_LogContent;
	};

	_vehicles = (WF_Logic getVariable "emptyVehicles") + [_vehicle];
	WF_Logic setVariable ["emptyVehicles",_vehicles,true];

	if (isHostedServer) then {_vehicle setVariable ["WFBE_Taxi_Prohib", true]};

	//--- cmdcon42-j (Ray 2026-07-02): PRODUCIBLE SCUD (Takistan). A bought MAZ_543_SCUD_TK_EP1 becomes a side launch
	//--- platform: (a) ask the SERVER to register it (cap-enforced there — a surplus purchase is deleted + refunded), and
	//--- (b) give the vehicle a "SCUD Fire Mission (map-click)" action for its crew/owner-side players that opens a map-click
	//--- and sends the SAME icbm-tel-fire payload the Tactical menu uses, WITH this specific hull as the platform hint (the
	//--- server re-validates everything). Fires a SATURATION conventional strike (the flagship conventional munition). Mirrors
	//--- the carrier scud-action-add + GUER-VBIED buyer-local-add / GetIn-re-add persistence idioms. TK + flag gated.
	if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) > 0 && {worldName == "Takistan"} && {(typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])}) then {
		//--- (a) SERVER-SIDE registration request (side-keyed platform array + cap enforcement live on the server). Pass the
		//--- ACTUAL price paid (_currentCost, incl. modifiers + crew) so an over-cap refusal refunds the exact amount deducted.
		["RequestSpecial", ["tk-scud-register", _vehicle, sideJoined, group player, _currentCost]] Call WFBE_CO_FNC_SendToServer;

		//--- Global flag so any machine that gets this hull local can recognise it + (re)arm the action.
		_vehicle setVariable ["wfbe_is_tk_scud", true, true];

		//--- Local helper: add the fire-mission action once per local hull instance (dedupe via wfbe_tk_scud_action). The
		//--- condition restricts the action to the owning side; the server still validates side/cooldown/range/funds on fire.
		WFBE_CL_FNC_AddTkScudAction = {
			private ["_v","_aid"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (!(_v getVariable ["wfbe_is_tk_scud", false])) exitWith {};
			if ((_v getVariable ["wfbe_tk_scud_action", -1]) >= 0) exitWith {};   //--- already armed on this machine.
			_aid = _v addAction [
				"<t color='#ff9900'>SCUD Fire Mission (map-click)</t>",
				{
					private ["_v","_caller","_cost"];
					_v = _this select 0;
					_caller = _this select 1;
					_cost = missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000];
					if (((group _caller) Call WFBE_CO_FNC_GetTeamFunds) < _cost) exitWith { hintSilent parseText Format ["<t color='#F8D664'>Not enough funds for a SCUD saturation strike ($%1).</t>", _cost]; };
					hintSilent parseText "<t color='#F89060'>SCUD: click the target on the map.</t>";
					openMap true;
					//--- capture the firing hull so onMapSingleClick can hint it as the platform.
					wfbe_tk_scud_fire_veh = _v;
					onMapSingleClick {
						onMapSingleClick {};
						openMap false;
						private ["_veh"];
						_veh = wfbe_tk_scud_fire_veh;
						if (isNull _veh || {!alive _veh}) exitWith { hintSilent parseText "<t color='#ff5a5a'>That SCUD is gone.</t>"; };
						//--- SAME payload the Tactical menu sends, + this hull as the platform hint. No client fund deduction
						//--- (the server WFBE_SE_FNC_IcbmTelFire re-validates platform/cooldown/range/funds and charges).
						["RequestSpecial", ["icbm-tel-fire", playerSide, [_pos select 0, _pos select 1, 0], "SATURATION", group player, 0, _veh]] Call WFBE_CO_FNC_SendToServer;
						hintSilent parseText "<t color='#F89060'>SCUD saturation order sent (server validates SCUD + range + funds).</t>";
						false
					};
				},
				//--- Show only to a crew member whose side matches the hull's registered owner side (server-set wfbe_tk_scud_side;
				//--- falls back to playerSide before registration replicates). Server re-validates side on fire regardless.
				[], 6, false, true, "", "alive _target && {_this in crew _target} && {(_target getVariable ['wfbe_tk_scud_side', playerSide]) == side _this}"
			];
			_v setVariable ["wfbe_tk_scud_action", _aid];
		};

		//--- Immediate buyer-local add (instant availability) + GetIn re-add for persistence (mirrors the VBIED idiom).
		_vehicle call WFBE_CL_FNC_AddTkScudAction;
		_vehicle addEventHandler ["GetIn", {
			private ["_v","_u"];
			_v = _this select 0;
			_u = _this select 2;
			if (_u == player) then { _v call WFBE_CL_FNC_AddTkScudAction };
		}];
	};

	//--- Clear the vehicle.
	(_vehicle) call WFBE_CO_FNC_ClearVehicleCargo;

	/* Section: Local Init (Client Only) */

	//--- Lock / Unlock.
	_vehicle addAction [localize "STR_WF_Unlock","Client\Action\Action_ToggleLock.sqf", [], 95, false, true, '', 'alive _target && locked _target'];
	_vehicle addAction [localize "STR_WF_Lock","Client\Action\Action_ToggleLock.sqf", [], 94, false, true, '', 'alive _target && !(locked _target)'];

	//--- GUER PLAYER VBIED: the buyable hilux1_civil_2_covered gets a driver-detonate action (Feature B player-side).
	//--- The action is driver-only + resistance-only (condition) and asks the server to blast (mirrors AI wildcard W21)
	//--- + pays the driver's GUER team cash-for-kills.
	//--- C2 (persistence): addAction is LOCAL, so a single buyer-time add was lost the moment the buyer relogged
	//--- (EHs/actions are not JIP-persistent) or any other client became the driver. We now (a) tag the vehicle with
	//--- a global flag so any client can recognise it as a VBIED, and (b) attach a GetIn driver-path that re-adds the
	//--- action to the *local* driver instance whenever a unit takes the wheel — so the buyer keeps it across
	//--- get-out/get-in and re-driving, and a local player who inherits this truck as driver gets it on their own
	//--- machine. Idempotent via wfbe_vbied_action (one action per local vehicle instance). Gate-OFF / non-VBIED =
	//--- no flag, no EH, no action (byte-for-byte today's behaviour).
	//--- NOTE (out of my file scope): for a teammate already standing on ANOTHER client when the truck spawns, the
	//--- fully-correct delivery is an all-clients re-applier (the per-client updateclient.sqf MHQ-action pattern, or a
	//--- registered PVFunction like SetMHQLock). That re-applier lives outside the GUER bundle's owned files.
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {((typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])) || ((typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"]))}) then {  //--- B75: hilux/datsun truck VBIED OR the kill-gated M113 APC VBIED.
		//--- Global flag so any machine that gets this vehicle local can recognise + (re)arm the action.
		_vehicle setVariable ["wfbe_is_guer_vbied", true, true];

		//--- B75 (guer-tech): tag the VBIED variant so the GetIn path arms the right movement assist. The soft truck
		//--- (a Car) keeps Valhalla high-climbing; the tracked M113 APC gets the dedicated ~2x-speed boost loop instead.
		if ((typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"])) then {
			_vehicle setVariable ["wfbe_vbied_m113", true, true];
		} else {
			//--- B67 (guer-reward): the truck VBIED is a Car, so enable Valhalla High Climbing on it (broadcast) so the
			//--- suicide truck can scale steep terrain to reach targets. Mirrors LowGear_Toggle.sqf's enable path.
			_vehicle setVariable ["WFBE_HighClimbingEnabled", true, true];
		};

		//--- Local helper: add the detonate action once per local vehicle instance (dedupe via wfbe_vbied_action).
		WFBE_CL_FNC_AddGuerVbiedAction = {
			private ["_v"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (!(_v getVariable ["wfbe_is_guer_vbied", false])) exitWith {};
			if ((_v getVariable ["wfbe_vbied_action", -1]) >= 0) exitWith {};   //--- already armed on this machine.
			private ["_aid"];
			_aid = _v addAction ["<t color='#ff3333'>Detonate VBIED</t>","Client\Action\Action_GuerVbiedDetonate.sqf", [], 6, false, true, "", "driver _target == _this && {side _this == resistance}"];
			_v setVariable ["wfbe_vbied_action", _aid];
		};

		//--- B75 (guer-tech): M113 VBIED ~2x-speed driver-local boost. A2-OA has NO setMaxSpeed, so mirror the Valhalla
		//--- high-climbing setVelocity idiom: each tick, while the LOCAL player drives, nudge the forward velocity up
		//--- until ~2x the M113's stock top speed (self-limiting). Idempotent via wfbe_m113_boost_running.
		WFBE_CL_FNC_GuerVbiedM113Boost = {
			private ["_v"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (_v getVariable ["wfbe_m113_boost_running", false]) exitWith {};   //--- already boosting on this machine.
			_v setVariable ["wfbe_m113_boost_running", true];
			[_v] spawn {
				private ["_v","_coef","_baseMax","_target","_vel","_dir","_fwd"];
				_v = _this select 0;
				_coef = missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_SPEEDCOEF", 2.0];
				_baseMax = getNumber (configFile >> "CfgVehicles" >> (typeOf _v) >> "maxSpeed");   //--- km/h
				if (_baseMax <= 0) then {_baseMax = 60};
				_target = _baseMax * _coef;
				while {alive _v && {driver _v == player} && {canMove _v}} do {
					if (isEngineOn _v && {(speed _v) > 3} && {(speed _v) < _target}) then {
						_vel = velocity _v;
						_dir = direction _v;
						_fwd = (_vel select 0) * sin _dir + (_vel select 1) * cos _dir;   //--- forward velocity component (only boost when actually moving forward).
						if (_fwd > 0) then {
							//--- add 7% of the forward speed ALONG the heading only, so a turning/skidding tracked APC
							//--- doesn't get its lateral drift amplified (self-limited by the speed < _target guard above).
							private ["_add"];
							_add = _fwd * 0.07;
							_v setVelocity [(_vel select 0) + (_add * sin _dir), (_vel select 1) + (_add * cos _dir), (_vel select 2)];
						};
					};
					sleep 0.1;
				};
				_v setVariable ["wfbe_m113_boost_running", false];
			};
		};

		//--- Immediate buyer-local add (instant availability) + GetIn driver-path re-add for persistence.
		_vehicle call WFBE_CL_FNC_AddGuerVbiedAction;
		_vehicle addEventHandler ["GetIn", {
			private ["_v","_pos","_u"];
			_v = _this select 0;
			_pos = _this select 1;
			_u = _this select 2;
			if (_pos == "driver" && {_u == player} && {side _u == resistance}) then {
				_v call WFBE_CL_FNC_AddGuerVbiedAction;
				//--- B67 (guer-reward): start the Valhalla High Climbing loop for the local driver, exactly the way
				//--- LowGear_Toggle.sqf does (set Local_HighClimbingModeOn, spawn VALHALLA_FNC_LowGear if not running).
				if (_v getVariable ["WFBE_HighClimbingEnabled", false]) then {
					Local_HighClimbingModeOn = true;
					if (!Local_HighClimbingRunning) then {
						_v spawn VALHALLA_FNC_LowGear;
					};
				};
				//--- B75 (guer-tech): start the M113 ~2x-speed boost for the local driver (mirrors the high-climb start above).
				if (_v getVariable ["wfbe_vbied_m113", false]) then {
					_v call WFBE_CL_FNC_GuerVbiedM113Boost;
				};
			};
		}];
	};

	//--- GUER PLAYER MORTAR STRIKE: the buyable V3S_Gue truck gets a driver-only "Call mortar strike" action — a
	//--- cooldown-gated, range-limited call-in barrage (Action_GuerMortarStrike.sqf -> RequestSpecial "guer-mortar-strike"
	//--- -> Server_HandleSpecial spawns scripted 82mm HE ordnance). This mirrors the GUER VBIED block above EXACTLY:
	//--- addAction is LOCAL and not JIP-persistent, so we (a) tag the truck with a broadcast flag any machine can
	//--- recognise, and (b) attach a GetIn driver-path that re-adds the action to the *local* driver instance whenever a
	//--- resistance player takes the wheel — so the buyer keeps it across get-out/get-in and a local player who inherits
	//--- the truck as driver gets it on their own machine. Idempotent via wfbe_mortar_action (one action per local
	//--- vehicle instance). Gate-OFF / non-V3S = no flag, no EH, no action (byte-for-byte today's behaviour).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {(typeOf _vehicle) == "V3S_Gue"}) then {
		//--- Global flag so any machine that gets this vehicle local can recognise + (re)arm the action.
		_vehicle setVariable ["wfbe_is_guer_mortar", true, true];

		//--- Local helper: add the mortar action once per local vehicle instance (dedupe via wfbe_mortar_action).
		WFBE_CL_FNC_AddGuerMortarAction = {
			private ["_v","_aid"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (!(_v getVariable ["wfbe_is_guer_mortar", false])) exitWith {};
			if ((_v getVariable ["wfbe_mortar_action", -1]) >= 0) exitWith {};   //--- already armed on this machine.
			_aid = _v addAction ["<t color='#ffcc33'>Call mortar strike</t>","Client\Action\Action_GuerMortarStrike.sqf", [], 6, false, true, "", "driver _target == _this && {side _this == resistance}"];
			_v setVariable ["wfbe_mortar_action", _aid];
		};

		//--- Immediate buyer-local add (instant availability) + GetIn driver-path re-add for persistence.
		_vehicle call WFBE_CL_FNC_AddGuerMortarAction;
		_vehicle addEventHandler ["GetIn", {
			private ["_v","_pos","_u"];
			_v = _this select 0;
			_pos = _this select 1;
			_u = _this select 2;
			if (_pos == "driver" && {_u == player} && {side _u == resistance}) then {
				_v call WFBE_CL_FNC_AddGuerMortarAction;
			};
		}];
	};

	//--- B75 (guer-tech FOB): tag a freshly-bought GUER FOB delivery truck (broadcast) so any machine can recognise it
	//--- as a real FOB truck (vs an AI faction's Ural_INS that shares the classname). The flag gates the "Build FOB"
	//--- action (Init_Unit.sqf) and the spawn-on-truck list (Client_GetRespawnAvailable.sqf).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {(typeOf _vehicle) in (missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []])}) then {
		_vehicle setVariable ["wfbe_is_guer_fob", true, true];
	};

	//--- B76 (guer-depot climb): GUER buys EVERY vehicle from the Depot (GUI_Menu_BuyUnits forces _type='Depot'),
	//--- and their technicals need to scale the steep Takistan/Chernarus terrain to be useful. Only the VBIED truck
	//--- (line ~357) had Valhalla High Climbing forced on; every other Depot car spawned with it OFF (default
	//--- WFBE_HighClimbingDefaultEnabled = false), so the buyer had to toggle it by hand each time. Enable it by
	//--- default on GUER Depot cars (broadcast), mirroring the VBIED path. Skip vehicles already handled as a VBIED
	//--- (their own GetIn path already arms the climb loop). The buyer keeps the Init_Unit "High-climbing gear off"
	//--- toggle to turn it back off. GetIn driver-path starts the loop for whoever takes the wheel, exactly the way
	//--- LowGear_Toggle.sqf does. Idempotent: setVariable + a dedupe-guarded GetIn EH (wfbe_depot_climb_eh).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_factory == "Depot"} && {_vehicle isKindOf "Car"} && {!(_vehicle getVariable ["wfbe_is_guer_vbied", false])}) then {
		_vehicle setVariable ["WFBE_HighClimbingEnabled", true, true];

		if ((_vehicle getVariable ["wfbe_depot_climb_eh", -1]) < 0) then {
			private ["_eh"];
			_eh = _vehicle addEventHandler ["GetIn", {
				private ["_v","_pos","_u"];
				_v = _this select 0;
				_pos = _this select 1;
				_u = _this select 2;
				if (_pos == "driver" && {_u == player} && {_v getVariable ["WFBE_HighClimbingEnabled", false]}) then {
					Local_HighClimbingModeOn = true;
					if (!Local_HighClimbingRunning) then {
						_v spawn VALHALLA_FNC_LowGear;
					};
				};
			}];
			_vehicle setVariable ["wfbe_depot_climb_eh", _eh];
		};
	};

	//--- Salvage Truck.
	if (_unit in (missionNamespace getVariable Format['WFBE_%1SALVAGETRUCK',sideJoinedText])) then {[_vehicle] execVM 'Client\FSM\updatesalvage.sqf'};

	//--- Units Balancing.
	if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {(_vehicle) Call BalanceInit};

	if (_unit isKindOf "Air") then {
		//--- Countermeasures.
			if (getNumber(configFile >> "CfgVehicles" >> typeOf _vehicle >> "incommingmissliedetectionsystem") > 8) then {_vehicle addeventhandler ['IncomingMissile',{_this spawn HandleAlarm;}]};
		if !(WF_A2_Vanilla) then {
			switch (missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") do { //--- Remove CM if needed.
				case 0: {(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures}; //--- Disabled.
				case 1: { //--- Enabled with upgrades.
					if (((sideJoined Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_FLARESCM) == 0) then {
						(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures;
					};
				};
			};
		};

		//--- No AA missiles.
		switch (missionNamespace getVariable "WFBE_C_GAMEPLAY_AIR_AA_MISSILES") do {
			case 0: {(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles};
			case 1: {
				if (((sideJoined Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIRAAM) == 0) then {
					(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles;
				};
			};
		};
	};

	//--- B75 (guer-tech): KILL-SCALED Ka-137 FLARES. The Ka137_MG_PMC ships with no countermeasures, and the GUER
	//--- air CM-strip above (RemoveCountermeasures, fired because GUER has no flares upgrade) would also strip anything
	//--- we add - so we arm flares HERE, AFTER that strip. Give the player's Ka-137 a CMFlareLauncher + a flare mag
	//--- sized by the kill tier (60 -> 120 -> 240). The Ka-137 fires from its MainTurret, so turret-path [-1] is
	//--- MANDATORY (hull addMagazine/addWeapon silently no-op on it - same special-case the EASA path keys on).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {sideJoined == resistance} && {(typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_KA137_TYPE", "Ka137_MG_PMC"])}) then {
		private ["_ka137Tier","_ka137Mags","_ka137Mag","_ka137Launcher"];
		_ka137Tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
		_ka137Mags = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_MAGS", ["60Rnd_CMFlareMagazine","120Rnd_CMFlareMagazine","240Rnd_CMFlareMagazine"]];
		if (_ka137Tier < 0) then {_ka137Tier = 0};
		if (_ka137Tier > ((count _ka137Mags) - 1)) then {_ka137Tier = (count _ka137Mags) - 1};
		_ka137Mag = _ka137Mags select _ka137Tier;
		_ka137Launcher = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_LAUNCHER", "CMFlareLauncher"];
		//--- Clear any flare mag/launcher already on the turret (idempotent), then arm launcher + the sized mag. Uses
		//--- the same remove/add turret-path [-1] commands EASA_RemoveLoadout.sqf / Server_GuerAirDef.sqf use (A2-OA safe).
		{_vehicle removeMagazineTurret [_x, [-1]]} forEach ["60Rnd_CMFlareMagazine","120Rnd_CMFlareMagazine","240Rnd_CMFlareMagazine"];
		_vehicle removeWeaponTurret [_ka137Launcher, [-1]];
		_vehicle addWeaponTurret [_ka137Launcher, [-1]];
		_vehicle addMagazineTurret [_ka137Mag, [-1]];
		["INFORMATION", Format ["Client_BuildUnit.sqf: GUER Ka-137 armed with flares [%1] at tier [%2].", _ka137Mag, _ka137Tier]] Call WFBE_CO_FNC_LogContent;
	};

	//--- Are we dealing with an artillery unit.

	_isArtillery = [_unit,sideJoinedText] Call IsArtillery;
	if (_isArtillery != -1) then {[_vehicle,_isArtillery,sideJoinedText] Call EquipArtillery;};

	/* Section: Creation */

	[sideJoinedText,'VehiclesCreated',1] Call UpdateStatistics;
	_built = 0;
	_group addVehicle _vehicle;

_vehicle allowCrewInImmobile true;
_vehicle addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];

if ((typeOf _vehicle ) in ['MLRS','GRAD','GRAD_CDF','MLRS_DES_EP1','M1129_MC_EP1','GRAD_TK_EP1','GRAD_CDF','GRAD_RU','GRAD_INS']) then {
	_vehicle setVariable ["restricted",false];_vehicle addEventHandler ["GetIn",{_this Spawn HandleArty}]
};

// Could seperate the array here for modded vehicles
if(typeOf _vehicle in ['F35B','AV8B','AV8B2','A10','A10_US_EP1','Su25_TK_EP1','Su34','Su39','An2_TK_EP1','L159_ACR','L39_TK_EP1','Su25_Ins','ibrPRACS_MiG21mol']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles}];
};

//--- Jets survive the first SPAAG (Tunguska/Linebacker) hit — fuel drained + slight damage to attempt a landing; a second hit explodes. Set WFBE_C_JET_AA_SURVIVE 0 to disable.
if (_vehicle isKindOf "Plane" && (missionNamespace getVariable ["WFBE_C_JET_AA_SURVIVE", 1]) > 0) then {
	_vehicle addEventHandler ["HandleDamage", {_this Call HandleJetAADamage}];
};

if(typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles;}];
};

if(typeOf _vehicle in ['T90','BMP3']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleATReload;}];
};

if(typeOf _vehicle in ['Pandur2_ACR']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleCommanderReload;}];
};

if ({(typeOf _vehicle) isKindOf _x} count ["LAV25_Base","M2A2_Base","BMP2_Base","BTR90_Base" ] != 0) then {_vehicle addeventhandler ["fired",{_this spawn HandleReload;}];};

//--- V2: removed duplicate "fired"->HandleReload event handler (was identical to the IFV line above; double-registering spawned HandleReload twice per shot).

if({(_vehicle isKindOf _x)} count ["Tank","Wheeled_APC"] !=0) then {_vehicle addeventhandler ['Engine',{_this execVM "Client\Module\Engines\Engine.sqf"}];
     _vehicle addAction ["<t color='"+"#00E4FF"+"'>STEALTH ON</t>","Client\Module\Engines\Stopengine.sqf", [], 7,false, true,"","alive _target &&(isEngineOn _target)"];};

// IRS MODULE
if ((typeOf _vehicle) isKindOf "Tank" || (typeOf _vehicle) isKindOf "Car") then {

	_vehicle addeventhandler ['incomingMissile',{_this spawn HandleATMissiles}];


	if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_IRSMOKE") > 0) then { //--- IR Smoke
		if (((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 0) then { //--- Make sure that the unit is defined in IRS_Init and that the upgrade is available.
			_get = missionNamespace getVariable Format ["%1_IRS", (typeOf _vehicle)];
			if !(isNil '_get') then {

				_getSelectOne = _get select 1;

				// Check if the vehicle has the 2nd upgrade for the IR Smoke. Double the amount of smoke if true.
				if (((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 1) then { _getSelectOne = _getSelectOne * 2;};

				_vehicle setVariable ["wfbe_irs_flares", _getSelectOne, true];
				_vehicle addEventHandler ["incomingMissile", {_this spawn WFBE_CO_MOD_IRS_OnIncomingMissile}];

				//--- Trello #38: per-vehicle toggle for automatic IR smoke. addAction is LOCAL (re-adds on rebuy) - acceptable for a personal toggle.
				_vehicle addAction [localize "STR_WF_Action_IRS_Disable","Client\Action\Action_ToggleIRSmoke.sqf", [true], 6, false, true, "", "alive _target && !(_target getVariable ['wfbe_irs_disabled', false])"];
				_vehicle addAction [localize "STR_WF_Action_IRS_Enable","Client\Action\Action_ToggleIRSmoke.sqf", [false], 6, false, true, "", "alive _target && (_target getVariable ['wfbe_irs_disabled', false])"];
			};
		};
	};
};



	//--- Empty Vehicle.
	if (!_driver && !_gunner && !_commander) exitWith {
		//--- Release fix (#3): empty-vehicle exit must still release the per-factory queue slot,
		//--- otherwise WFBE_C_QUEUE_<type> leaks one each empty purchase and the factory soft-locks at its cap.
		//--- NO refund here: this is the normal crewless/Depot purchase path and the vehicle WAS already
		//--- spawned above. (The genuine destroyed-factory refund lives in the !alive _building exit earlier.)
		unitQueu = unitQueu - _cpt;
		missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_factory],(missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_factory])-1];
	};

	//--- Crew Management.
	_crew = missionNamespace getVariable Format ["WFBE_%1SOLDIER",sideJoinedText];
	
	// Marty : All crew members in tanks and wheeled APCs (LAV-25, BTR-90, Pandur / HF vehicles) are replaced by engineers of their side.
	// Russian side do not have engineer class so we use takistan class engineer for russian.
	//if (_unit isKindOf "Tank") then {_crew = missionNamespace getVariable Format ["WFBE_%1CREW",sideJoinedText]};
	if (_unit isKindOf "Tank" || _unit isKindOf "Wheeled_APC") then {
		if (sideJoinedText == "WEST")then 
		{
			// WEST side (american)
			_crew = "US_Soldier_Engineer_EP1" ;
			//player sideChat Format ["US_Soldier_Engineer_EP1 for %1",sideJoinedText];
		}
		else 
		{
			// EAST side (russian)
			_crew = "TK_Soldier_Engineer_EP1" ;
			//player sideChat Format ["TK_Soldier_Engineer_EP1 for %1",sideJoinedText];
		};
	};

	if (_unit isKindOf "Air") then {
		_crew = missionNamespace getVariable Format ["WFBE_%1PILOT",sideJoinedText];
	};

	_rearmor = {
   				_ammo = _this select 4;
   				_result = 0;

   				switch (_ammo) do {
                    case "B_20mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_23mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HEI" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_30mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_30mm_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "Sh_40_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};   
     				default {_result = _this select 2;};
    			};
   				_result
  			};

	//--- Driver.
	if (_driver) then {
		_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
		//// add eventhandler

		[_soldier] allowGetIn true;
		_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
		_soldier moveInDriver _vehicle;
		_spawnedUnits = _spawnedUnits + [_soldier];
	};

	//--- Gunner.
	if (_gunner) then {
		_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
		//// add eventhandler
		_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];

		[_soldier] allowGetIn true;
		_soldier moveInGunner _vehicle;
		_spawnedUnits = _spawnedUnits + [_soldier];
	};

	//--- Commander.
	if (_commander) then {
		_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
		//// add eventhandler
		_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];

		[_soldier] allowGetIn true;
		_soldier moveInCommander _vehicle;
		_spawnedUnits = _spawnedUnits + [_soldier];
	};

	//--- Extra vehicle turrets.
	if (_extracrew) then {
		Private ["_turrets"];
		_turrets = _currentUnit select QUERYUNITTURRETS;

		{
			if (isNull (_vehicle turretUnit _x)) then {
				_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
				_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
				[_soldier] allowGetIn true;
				_soldier moveInTurret [_vehicle, _x];
				_spawnedUnits = _spawnedUnits + [_soldier];
			};
		} forEach _turrets;
	};



	[sideJoinedText,'UnitsCreated',_cpt] Call UpdateStatistics;
};

if (_factory in ["Barracks","Light","Heavy","Aircraft","Depot","Airport"]) then {
	[_group, _spawnedUnits] call WFBE_CL_FNC_SendSpawnedUnitsToLeaderWaypoint;
};

unitQueu = unitQueu - _cpt;

missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_factory],(missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_factory])-1];
hint parseText(Format [localize "STR_WF_INFO_Build_Complete",_description]);
