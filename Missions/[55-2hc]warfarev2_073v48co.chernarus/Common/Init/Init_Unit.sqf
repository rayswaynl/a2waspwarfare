/*
	Initialize a unit for clients (JIP Compatible).
	Contributors : Marty.
*/

Private ["_get","_isMan","_logik","_perfAARStarted","_perfBlinkingEH","_perfMarkerRefresh","_perfMarkerType","_perfSideMatch","_perfStart","_side","_sideID","_unit","_unit_kind","_upgrades"];

_unit 				= _this select 0;
_sideID 	 		= _this select 1;
_unit_kind = typeOf _unit;

if !(alive _unit) exitWith {}; //--- Abort if the unit is null or dead.

if(isNil 'commonInitComplete')then{
	commonInitComplete = false;
};

waitUntil {commonInitComplete}; //--- Wait for the common part.


_side = (_sideID) Call GetSideFromID;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

waitUntil {!isNil {_logik getVariable "wfbe_upgrades"}};
_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;

// --- 				[Generic Vehicle initialization] (Run on all clients AND server)


if !(local player) exitWith {}; //--- We don't need the server to process it.

//--- HC THREAD-LEAK FIX (runtime-proven on MIKSUUS-TEST, WASPLAB|v1|HCINIT probe 2026-07-11): on a
//--- headless client `player` IS the HC's own playable unit and IS local, so the guard above does NOT
//--- exit - and clientInitComplete is only ever set by Init_Client.sqf, which never runs on an HC
//--- (probe: cic=false + a canary waitUntil parked forever on BOTH HCs). Every server-broadcast
//--- Init_Unit therefore permanently parked one scheduled thread PER UNIT on EVERY HC - each parked
//--- waitUntil re-evaluates its condition every frame on the HC's single saturated core. Exit here
//--- exactly like the dedicated server does above; the HC needs none of the client-side init below
//--- (actions/markers/UI). Nil-guarded: real clients + server are byte-identical.
if (!isNil "isHeadLessClient" && {isHeadLessClient}) exitWith {};

waitUntil {clientInitComplete}; //--- Wait for the client part.

sleep 2; //--- Wait a bit.

// Marty: Performance Audit starts after JIP waits and the intentional sleep, so it measures active client setup only.
_perfStart = diag_tickTime;
_perfAARStarted = 0;
_perfBlinkingEH = 0;
_perfMarkerType = "";
_perfMarkerRefresh = -1;

_isMan = if (_unit isKindOf 'Man') then {true} else {false};
// --- 				[Generic Vehicle initialization] (Run on all clients)

if(side _unit == east && !(_unit hasWeapon "NVGoggles")) then {
	_unit addWeapon "NVGoggles";
};


if(!isNil 'Zeta_Lifter')then{
	if (_unit_kind in Zeta_Lifter) then { //--- Units that can lift vehicles.
		if (_upgrades select WFBE_UP_AIRLIFT > 0) then {_unit addAction [localize "STR_WF_Lift", 'Client\Module\ZetaCargo\Zeta_Hook.sqf']};
	};
};
if (_unit_kind in (missionNamespace getVariable ["WFBE_REPAIRTRUCKS", []])) then { //--- Repair Trucks. (fable/fix-hc-repairtrucks-nil: default [] - nil here errored EVERY unit init on the HC and aborted the rest of this script)
	//--- Build action.
	_unit addAction [localize 'STR_WF_BuildMenu_Repair','Client\Action\Action_BuildRepair.sqf', [], 99, false, true, '', Format['side group player == side _target && alive _target && player distance _target <= %1', missionNamespace getVariable 'WFBE_C_UNITS_REPAIR_TRUCK_RANGE']];

	//--- UAV2 FOB: shown only when the feature is armed and the shared engineer/repair-truck/upgrade gate passes.
	if ((missionNamespace getVariable ["WFBE_C_UAV2_FOB", 0]) > 0) then {
		_unit addAction ["<t color='#76F563'>Build UAV2 Forward FOB</t>", "Client\Action\Action_BuildUAV2FOB.sqf", [], 96, false, true, "", "[player, _target] Call WFBE_CO_FNC_CanUseUAV2FOB"];
	};

	if ((missionNamespace getVariable "WFBE_C_CAMPS_CREATE") > 0) then { //--- Repair camps.
		// Marty: Only show Repair Camp when the repair truck is near a destroyed camp.
		_unit addAction [localize 'STR_WF_Repair_Camp','Client\Action\Action_RepairCamp.sqf', [], 97, false, true, '', 'alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)'];
	};

	if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_VICTORY_CONDITION") != 1) then { //--- Repair HQ Ability.
		//--- Repair MHQ action.
		//--- Surface the NEXT repair price in the menu label. NOTE: the label string is baked at
		//--- truck-spawn time (repair count is 0 then), so it reflects the FIRST repair price and
		//--- does NOT live-update as the count climbs. The post-repair hint shows the live next price.
		private ["_repCount","_repNextPrice","_repSym"];
		_repCount = missionNamespace getVariable Format ['WFBE_C_BASE_HQ_REPAIR_COUNT_%1', sideJoined];
		_repNextPrice = [
			missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_1ST',
			missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_2ND',
			missionNamespace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_3RD'
		] select (_repCount min 2);
		_repSym = if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {"S"} else {"$"};
		_unit addAction ['Repair Mobile HQ','Client\Action\Action_RepairMHQ.sqf', [], 98, false, true, '', 'alive _target'];
	};
};

//--- B75 (guer-tech FOB): Build-FOB action on a GUER FOB delivery truck. Available to ANY nearby resistance player
//--- (GUER has no commander), gated on the broadcast wfbe_is_guer_fob flag (set at buy in Client_BuildUnit.sqf) so an
//--- AI faction's same-class truck never shows it. Added on every client (this section runs after the local-player
//--- guard), so all GUER players see it. Action_BuildFOB.sqf resolves the factory type from the truck classname.
if (_unit_kind in (missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []])) then {
	_unit addAction [
		"<t color='#76F563'>Build FOB</t>",
		"Client\Action\Action_BuildFOB.sqf",
		[],
		99,
		false,
		true,
		"",
		Format ["(_target getVariable ['wfbe_is_guer_fob', false]) && side group player == resistance && alive _target && player distance _target <= %1", missionNamespace getVariable ["WFBE_C_GUER_FOB_BUILD_RANGE", 30]]
	];
	//--- PR #846 follow-up (fable/fob-polish): one-shot driver-seat deploy hint. Each client attaches its own
	//--- EH instance (this file runs on every client); the _fobWho == player guard picks the driver's machine
	//--- and the LOCAL-ONLY wfbe_fob_seat_hinted flag (setVariable WITHOUT broadcast) keeps it one-shot per
	//--- client without extra network traffic. Mirrors the VBIED GetIn idiom in Client_BuildUnit.sqf.
	_unit addEventHandler ["GetIn", {
		private ["_fobTrk","_fobSeat","_fobWho"];
		_fobTrk  = _this select 0;
		_fobSeat = _this select 1;
		_fobWho  = _this select 2;
		if ((_fobSeat == "driver") && {_fobWho == player} && {side group player == resistance} && {_fobTrk getVariable ["wfbe_is_guer_fob", false]} && {!(_fobTrk getVariable ["wfbe_fob_seat_hinted", false])}) then {
			_fobTrk setVariable ["wfbe_fob_seat_hinted", true];
			hintSilent parseText "<t color='#76F563'>FOB Delivery Truck</t> - drive to where you want your forward base (not too close to enemy towns or the enemy base), then use the action menu (mouse scroll) -> <t color='#76F563'>Build FOB</t>. The truck is consumed on deploy.";
		};
	}];
};

if (_unit isKindOf "Tank") then { //--- Tanks.
	//--- Valhalla Low gear.
	_unit addAction ["<t color='#FFBD4C'>"+(localize "STR_ACT_LowGearOn")+"</t>","Client\Module\Valhalla\LowGear_Toggle.sqf", [], 91, false, true, "", "(vehicle player == _target) && !(_target getVariable ['WFBE_HighClimbingEnabled', missionNamespace getVariable ['WFBE_HighClimbingDefaultEnabled', false]]) && canMove _target"];
	_unit addAction ["<t color='#FFBD4C'>"+(localize "STR_ACT_LowGearOff")+"</t>","Client\Module\Valhalla\LowGear_Toggle.sqf", [], 91, false, true, "", "(vehicle player == _target) && (_target getVariable ['WFBE_HighClimbingEnabled', missionNamespace getVariable ['WFBE_HighClimbingDefaultEnabled', false]]) && canMove _target"];
	//--- Manual flip: on-demand righting, bypasses AutoFlip stuck-timer/cooldown.
	_unit addAction ["Flip Vehicle", "WASP\actions\FlipVehicle.sqf", [], 5, false, true, "", "(vectorUp _target select 2) < 0.35 && _target distance player < 10"];
};

if (_unit isKindOf "Car") then { //--- Lights vehicles.
	//--- Valhalla Low gear.
	_unit addAction ["<t color='#FFBD4C'>"+(localize "STR_ACT_LowGearOn")+"</t>","Client\Module\Valhalla\LowGear_Toggle.sqf", [], 91, false, true, "", "(player==driver _target) && !(_target getVariable ['WFBE_HighClimbingEnabled', missionNamespace getVariable ['WFBE_HighClimbingDefaultEnabled', false]]) && canMove _target"];
	_unit addAction ["<t color='#FFBD4C'>"+(localize "STR_ACT_LowGearOff")+"</t>","Client\Module\Valhalla\LowGear_Toggle.sqf", [], 91, false, true, "", "(player==driver _target) && (_target getVariable ['WFBE_HighClimbingEnabled', missionNamespace getVariable ['WFBE_HighClimbingDefaultEnabled', false]]) && canMove _target"];
	//--- Manual flip: on-demand righting, bypasses AutoFlip stuck-timer/cooldown.
	_unit addAction ["Flip Vehicle", "WASP\actions\FlipVehicle.sqf", [], 5, false, true, "", "(vectorUp _target select 2) < 0.35 && _target distance player < 10"];
};

if (_unit_kind == 'An2_TK_EP1') then { //--- AN-2 fast-lift: player high-climb/low-gear boost (no Flip — nonsensical for a plane).
	//--- Valhalla Low gear.
	_unit addAction ["<t color='#FFBD4C'>"+(localize "STR_ACT_LowGearOn")+"</t>","Client\Module\Valhalla\LowGear_Toggle.sqf", [], 91, false, true, "", "(player==driver _target) && !(_target getVariable ['WFBE_HighClimbingEnabled', missionNamespace getVariable ['WFBE_HighClimbingDefaultEnabled', false]]) && canMove _target"];
	_unit addAction ["<t color='#FFBD4C'>"+(localize "STR_ACT_LowGearOff")+"</t>","Client\Module\Valhalla\LowGear_Toggle.sqf", [], 91, false, true, "", "(player==driver _target) && (_target getVariable ['WFBE_HighClimbingEnabled', missionNamespace getVariable ['WFBE_HighClimbingDefaultEnabled', false]]) && canMove _target"];
};

if (_unit isKindOf "Ship") then { //--- Boats.
	//--- Push action.
	_unit addAction [localize "STR_WF_Push","Client\Action\Action_Push.sqf", [], 93, false, true, "", 'driver _target == _this && alive _target && speed _target < 30'];
};

if (_unit isKindOf "Air") then { //--- Air units.
	if ((getNumber (configFile >> 'CfgVehicles' >> _unit_kind >> 'transportSoldier')) > 0) then { //--- Transporters only.
		//--- HALO action.
		_unit addAction ['HALO','Client\Action\Action_HALO.sqf', [], 97, false, true, '', Format['getPos _target select 2 >= %1 && alive _target', missionNamespace getVariable 'WFBE_C_PLAYERS_HALO_HEIGHT']];
		//--- Cargo Eject action.
		_unit addAction [localize 'STR_WF_Cargo_Eject','Client\Action\Action_EjectCargo.sqf', [], 99, false, true, '', 'driver _target == _this && alive _target'];
	};

	if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") > 0 && WF_A2_Vanilla) then { //--- Use of a custom CM parameter (Vanilla Only).
		switch (missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") do {
			case 1: { //--- Enabled with upgrades.
				if ((_upgrades select WFBE_UP_FLARESCM) > 0) then {
					(_unit) ExecVM 'Client\Module\CM\CM_Set.sqf';
					_unit addEventHandler ['incomingMissile',{_this Spawn CM_Countermeasures}];
				};
			};
			case 2: { //--- Enabled.
				(_unit) ExecVM 'Client\Module\CM\CM_Set.sqf';
				_unit addEventHandler ['incomingMissile',{_this Spawn CM_Countermeasures}];
			};
		};
	};

	if (!WF_A2_Vanilla && (missionNamespace getVariable ["WFBE_C_MODULE_AUTO_CM_OA", 0]) > 0) then { //--- OA opt-in: AUTO-deploy flares on incoming IR missile (native OA flares are manual). Default OFF; shares the FLARES master switch + FlareCount budget.
		if (isNil "WFBE_CL_FNC_AutoCM_OA") then {WFBE_CL_FNC_AutoCM_OA = compile preprocessFileLineNumbers "Client\Module\CM\CM_AutoCM_OA.sqf"};
		switch (missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") do {
			case 1: { //--- Enabled with upgrades.
				if ((_upgrades select WFBE_UP_FLARESCM) > 0) then {
					(_unit) ExecVM 'Client\Module\CM\CM_Set.sqf';
					_unit addEventHandler ['incomingMissile',{_this Spawn WFBE_CL_FNC_AutoCM_OA}];
				};
			};
			case 2: { //--- Enabled.
				(_unit) ExecVM 'Client\Module\CM\CM_Set.sqf';
				_unit addEventHandler ['incomingMissile',{_this Spawn WFBE_CL_FNC_AutoCM_OA}];
			};
		};
	};

	if ((missionNamespace getVariable "WFBE_C_STRUCTURES_ANTIAIRRADAR") > 0 || (missionNamespace getVariable ["WFBE_C_AWACS", 0]) > 0) then { //--- AAR Tracking. fable/awacs-radar: the AWACS air picture reads the same registry, so feed it when either flag is on.
		if (sideJoined != _side) then { //--- Track the unit via AAR System, skip if the unit side is the same as the player one.
			_perfAARStarted = 1;
			[_unit, _side, _sideID] ExecVM 'Common\Common_AARadarMarkerUpdate.sqf';
		};
	};

	if (_unit isKindOf "Plane") then { //--- Planes.
		_unit addAction [localize "STR_WF_TaxiReverse","Client\Action\Action_TaxiReverse.sqf", [], 92, false, true, "", 'driver _target == _this && alive _target && speed _target < 4 && speed _target > -4 && getPos _target select 2 < 4'];
		_unit addEventHandler ['Fired', {_this Spawn HandleShootBombs;}]; //--- Marty : Handle missiles and bombs.
	};
	
};

if !(_isMan) then { //--- Vehicle Specific.
	if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_MISSILES_RANGE") != 0) then { //--- Max missile range.
		_unit addEventHandler ['incomingMissile', {_this Spawn HandleIncomingMissile}]; //--- Handle incoming missiles.
	};

	if !(WF_A2_Vanilla) then { //--- Only run on non-vanilla versions.
		if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_THERMAL_IMAGING") < 2) then {Call Compile '_unit disableTIEquipment true;'}; //--- Call Compile the variable to prevent errors on Vanilla.
	};
};

//--- B67 (Ray 2026-06-21) item #3: attach the IED anti-farm Fired EH on the LOCAL PLAYER man unit at INITIAL
//--- spawn / JIP first life. The death-respawn path adds it via Client_OnRespawnHandler.sqf, but that is NOT
//--- called on first life, so without this the first-life IED kills paid the full bounty (0.5) instead of the
//--- 30% IED coef. Idempotent via wfbe_ied_eh_added (the respawn copy uses the same flag); gated on GUER playable
//--- + resistance. Stamps wfbe_ied_recent (broadcast) on a BAF_ied detonation so RequestOnUnitKilled.sqf pays
//--- only WFBE_C_GUER_IED_KILL_COEF. Mirrors the Client_OnRespawnHandler.sqf block exactly.
if (_isMan && {isPlayer _unit} && {local _unit} && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0} && {side _unit == resistance}) then {
	if !(_unit getVariable ["wfbe_ied_eh_added", false]) then {
		_unit setVariable ["wfbe_ied_eh_added", true];
		_unit addEventHandler ["Fired", {
			private ["_shooter","_mag"];
			_shooter = _this select 0;
			_mag = _this select 5;
			if (!isNil "_mag" && {typeName _mag == "STRING"} && {_mag in ["BAF_ied_v1","BAF_ied_v2","BAF_ied_v3","BAF_ied_v4"]}) then {
				_shooter setVariable ["wfbe_ied_recent", time, true];
			};
		}];
	};
	//--- fable/guer-barrelbomb: WF-scroll "Call Barrel Bomb" action on the player's own Man body (not
	//--- vehicle-attached - this is a town-center location capability, not a vehicle one). The condition
	//--- string re-evaluates every frame so WFBE_C_GUER_HELIBOMB_ENABLE + the kill-tier gate are live-
	//--- togglable without a respawn; town-center proximity mirrors Client_CanUseTownCenterEASA.sqf via
	//--- WFBE_CL_FNC_CanUseTownCenterBarrelBomb (same "GUER-held or neutral town" idiom). Idempotent via
	//--- wfbe_helibomb_action_added (mirrors the IED EH guard immediately above).
	if !(_unit getVariable ["wfbe_helibomb_action_added", false]) then {
		_unit setVariable ["wfbe_helibomb_action_added", true];
		_unit addAction ["<t color='#ffcc33'>Call Barrel Bomb</t>","Client\Action\Action_GuerHeliBombCall.sqf", [], 6, false, true, "",
			'alive _target && {(missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_ENABLE", 0]) > 0} && {(missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0]) >= (missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_HELIBOMB", 60])} && {!isNil "WFBE_CL_FNC_CanUseTownCenterBarrelBomb"} && {_target Call WFBE_CL_FNC_CanUseTownCenterBarrelBomb}'];
	};
};

// --- 				[Side specific initialization] (Run on the desired client team).
_perfSideMatch = sideID == _sideID;
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["init_unit_client_setup", diag_tickTime - _perfStart, Format["type:%1;side:%2;isMan:%3;sideMatch:%4;aar:%5;trackInf:%6", _unit_kind, _sideID, _isMan, _perfSideMatch, _perfAARStarted, missionNamespace getVariable ["WFBE_C_UNITS_TRACK_INFANTRY", -1]], "CLIENT"] Call PerformanceAudit_Record;
	};
};
if (!_perfSideMatch) exitWith {};

Private ["_color","_markerName","_params","_size","_txt","_type"];

//--- Map Marker tracking.
_type = "Vehicle";
_color = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR", _side]);
_size = [5,5];
_txt = "";
_params = [];

unitMarker = unitMarker + 1;
_markerName = Format ["unitMarker%1", unitMarker];

if (_isMan) then { //--- Man.
	_type = "mil_dot";
	_size = [0.5,0.5];
	if (group _unit == group player) then {
		_color = "ColorOrange";
		_txt = (_unit) Call GetAIDigit;
	};
	_params = [_type,_color,_size,_txt,_markerName,_unit,1,true,"DestroyedVehicle",_color,false,_side,[1,1]];
} else { //--- Vehicle.
	//--- GUER MARKER FIX (claude 2026-07-01): the seven side-keyed reads below (SUPPLY/REPAIR/ARTY/AMMO/LIFT/
	//--- AMBULANCE/SALVAGE) previously used the BARE `getVariable Format[...]` form with NO default. For the
	//--- playable GUER (resistance) faction, WFBE_GUERARTYVEHICLE / WFBE_GUERAMMOTRUCKS / WFBE_GUERLIFTVEHICLE are
	//--- never registered (only the WEST/EAST army roots set them), so `_unit_kind in nil` threw a type error that
	//--- HALTED this scheduled Init_Unit run BEFORE `_params Spawn MarkerUpdate` (below) - so a GUER player's own
	//--- vehicles got NO map marker at all. This stayed hidden while resistance was the AI defender (Init_Unit is
	//--- skipped for the defender) and surfaced when GUER became a playable three-way side. Fix: read every side
	//--- list nil-safely with the [Format[...], []] default - the SAME form the sibling consumers already use
	//--- (Client_UIFillListBuyUnits.sqf:41-46, GUI_Menu_BuyUnits.sqf:696, updateavailableactions.fsm:59). Also
	//--- covers Takistan (resistance = TKGUE, missing the same three keys). A2-OA-1.64-safe (two-arg getVariable).
    if (_unit isKindOf "Bicycle") then {_color = "ColorWhite"};
	if (_unit isKindOf "Plane") then {_color = "ColorPink"}; // Placeholder, change to light blue later, if it's possible?
	if (_unit isKindOf "Helicopter") then {_color = "ColorPink"};
	if (local _unit && isMultiplayer) then {_color = "ColorOrange"};
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1SUPPLYTRUCKS',str _side], []])) then {_type = "SupplyVehicle";_size = [1,1]};//--- Supply.
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1REPAIRTRUCKS',str _side], []])) then {_color = "ColorBrown";_type = "RepairVehicle";};//--- Repair.
	
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1ARTYVEHICLE',str _side], []])) then {_color = "ColorPink";};//--- Arty.
	
	
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1AMMOTRUCKS',str _side], []])) then {_size=[0.4,0.4];_type = "Attack";_color = "ColorRed";};//--- Ammotruck.
	
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1LIFTVEHICLE',str _side], []])) then {_color = "ColorWhite";};//---Lifter
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1AMBULANCES',str _side], []])) then {_color = "ColorYellow";};//--- Medical.
	//
	if (_unit_kind in (missionNamespace getVariable [Format['WFBE_%1SALVAGETRUCK',str _side], []])) then {_color = "ColorKhaki";_type = "SalvageVehicle";};//--- Salvage.
        _params = [_type,_color,_size,_txt,_markerName,_unit,1,true,"DestroyedVehicle",_color,false,_side,[2,2]];	
        if (_unit == ((_side) Call WFBE_CO_FNC_GetSideHQ)) then {_color = "ColorPink";_params = ['Headquarters',_color,[1,1],'','HQUndeployed',_unit,0.2,false,'','',false,_side]};//--- HQ.	
};
 
// Marty: Only attach the combat marker blinking Fired EH when the mission parameter enables the feature.
if ((missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) == 1) then {
	_perfBlinkingEH = 1;
	// Marty: Store the EH handle so the consolidated marker loop can remove it on death (EH hygiene).
	_unit setVariable ["WFBE_BlinkFiredEH", _unit addEventHandler ["Fired", {
		_u = _this select 0;                 // unit that fired
		_u Call WFBE_CL_FNC_SetMapIconStatusInCombat;
	}], false];
	//--- fable/marker-combat-flash-fixes (owner 2026-07-09) BEING-SHOT-AT TRIGGER: also flash when
	//--- the unit TAKES fire from an enemy, not just when they fire. Hit stacks safely (unlike
	//--- HandleDamage, which this codebase already uses for the player rearmor system -
	//--- Init_Client.sqf:102 - and which REPLACES rather than adds a second handler; Hit is the
	//--- only A2-OA-safe damage-taken signal here). Reuses the same LFTB flag + 1Hz bookkeeping
	//--- loop, no new per-frame cost. Filters to a hostile causer only (excludes self-damage/fall
	//--- damage/friendly fire) to match "being shot at".
	_unit setVariable ["WFBE_BlinkHitEH", _unit addEventHandler ["Hit", {
		_u = _this select 0;
		_causedBy = _this select 1;
		if (!isNull _causedBy && {side _causedBy != side _u}) then {
			_u Call WFBE_CL_FNC_SetMapIconStatusInCombat;
		};
	}], false];
};

_unit setVariable ["OriginalMarkerColor", _color, false];

//--- fable/marker-double-fix (owner 2026-07-07): the LOCAL player already carries the orange own-arrow
//--- (GUER%1AdvancedSquadOWNMarker, updateteamsmarkers.sqf) at his position; the unitMarker mil_dot here
//--- draws a SECOND orange icon on top of it = doubled self-marker (visible for GUER, which has no team-slot
//--- arrow to mask it). Skip the dot for the OWN body only; remote teammates + AI + vehicles keep theirs.
if (_unit != player) then {_params Spawn MarkerUpdate}; //--- own-body dot suppressed (== player); rest of Init_Unit MUST still run for the player, so gate ONLY this line - never exitWith here
_perfMarkerType = _params select 0;
_perfMarkerRefresh = _params select 6;

// Marty: Count side-specific marker script spawns separately from their periodic update cost.
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["init_unit_marker_spawn", 0, Format["type:%1;side:%2;isMan:%3;markerType:%4;refresh:%5;groupPlayer:%6;blinkingEH:%7", _unit_kind, _sideID, _isMan, _perfMarkerType, _perfMarkerRefresh, group _unit == group player, _perfBlinkingEH], "CLIENT"] Call PerformanceAudit_Record;
	};
};

//--- naval-air-spawn-easa: apply a pending EASA preset stamped by the server
//--- during CAP spawn (Init_NavalHVT.sqf sets wfbe_naval_easa_pending = randIdx).
//--- Runs on every joining client so JIP players also equip the hull correctly.
//--- Guard: !isNil check avoids errors on non-CAP vehicles; EASA_Equip is a no-op
//--- for classnames not in WFBE_EASA_Vehicles (safe for unknown airframes).
if (!(_unit isKindOf "Man") && {!isNil {_unit getVariable "wfbe_naval_easa_pending"}}) then {
	private ["_easaPendingIdx"];
	_easaPendingIdx = _unit getVariable ["wfbe_naval_easa_pending", -1];
	if (_easaPendingIdx >= 0) then {
		[_unit, _easaPendingIdx] call EASA_Equip;
		["INFORMATION", Format ["Init_Unit.sqf: naval EASA pending preset %1 applied to %2.", _easaPendingIdx, typeOf _unit]] Call WFBE_CO_FNC_LogContent;
	};
};

// Marty : eventHandler for glitch rocket detection
if (_unit isKindOf "Tank" || _unit isKindOf "Car" || _unit isKindOf "Air") then {
	if (isNil {_unit getVariable "WFBE_MissileTerrainMaskingEH_Added"}) then { // the WFBE_MissileTerrainMaskingEH_Added is just to make sure the eventhandler has not been added already to this unit, in order to prevent creating multiple useless eventhandler (but its more a security than a necessity actually...
		_unit setVariable ["WFBE_MissileTerrainMaskingEH_Added", true, false];
		// Marty: Store the EH handle so the consolidated marker loop can remove it on death (EH hygiene).
		_unit setVariable ["WFBE_MissileTerrainMaskingEH", _unit addEventHandler ['Fired', {_this Spawn HandleShootMissiles;}], false];
	};
};
