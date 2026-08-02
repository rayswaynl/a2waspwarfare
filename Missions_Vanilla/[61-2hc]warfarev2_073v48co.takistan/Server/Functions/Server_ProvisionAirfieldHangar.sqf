/*
	Server_ProvisionAirfieldHangar.sqf

	Spawns (or re-spawns) the aircraft-buy hangar for an airfield town's owning side and
	links it via wfbe_hangar so Client_GetClosestAirport / GUI_Menu_BuyUnits can find it.
	Deletes any prior hangar first. Shared by:
	  - server_town.sqf's Task 12 capture block (real ownership flip, mid-match).
	  - server_town.sqf's boot bootstrap (airfields that start pre-owned via Init_Town.sqf's
	    sideID default never fire a capture event, so they'd otherwise never get a hangar).

	Parameters:
		0: OBJECT - the airfield town/depot logic (wfbe_is_airfield = true)
		1: OBJECT - the nearest LocationLogicAirport for this airfield
		2: SIDE   - the side to record as the new hangar owner

	Returns: nothing
*/
Private ["_location","_airfieldLogic","_newSide","_newHangar","_oldHangar","_wfbeSvcOld","_wfbeSvcClass","_wfbeSvcPos","_wfbeSvcSp","_wfbeSvcLogik"];
_location      = _this select 0;
_airfieldLogic = _this select 1;
_newSide       = _this select 2;

//--- Delete old hangar (previous owner's) and its link on the airport logic. Matches the
//--- original inline block exactly: this always runs when an old hangar exists, even if
//--- _airfieldLogic itself came back null (malformed mission data - defensive, not expected).
_oldHangar = _location getVariable ["wfbe_airfield_hangar_obj", objNull];
if !(isNull _oldHangar) then {
	deleteVehicle _oldHangar;
	if !(isNull _airfieldLogic) then { _airfieldLogic setVariable ["wfbe_hangar", nil, true] };
};

//--- Spawn new hangar on the airport logic so GetClosestAirport can find it.
if !(isNull _airfieldLogic) then {
	_newHangar = (missionNamespace getVariable "WFBE_C_HANGAR") createVehicle (getPos _airfieldLogic);
	if (isNull _newHangar) exitWith {
		["WARNING", "Server_ProvisionAirfieldHangar.sqf: hangar createVehicle failed; airfield hangar link left empty after old hangar teardown."] Call WFBE_CO_FNC_LogContent;
	};
	_newHangar setDir ((getDir _airfieldLogic) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
	_newHangar setPos (getPos _airfieldLogic);
	_newHangar setVariable ["wfbe_is_airfield_hangar", true, true];
	_airfieldLogic setVariable ["wfbe_hangar", _newHangar, true];
	_airfieldLogic setVariable ["wfbe_airfield_side", _newSide, true]; //--- C-1: GUER airfield ownership gate
	_location setVariable ["wfbe_airfield_hangar_obj", _newHangar, true];
};

//--- AIRFIELD SERVICE POINT (fable/airfield-service, GR-2026-07-08a; flag WFBE_C_AIRFIELD_SERVICE,
//--- default 0): reuses the exact WarfareBVehicleServicePoint + WFBE_RepairTruckServicePoint tag
//--- pattern server_town.sqf's Task 12 real-capture block already builds (WFBE_C_AIRFIELDS, default
//--- 1) - GUI_Menu_Service.sqf, Client_GetRepairTruckServicePoints.sqf and updateavailableactions.fsm
//--- already scan for that tag, so nothing client-side needs to change. Idempotent: Task 12 stamps
//--- wfbe_airfield_sp on _location BEFORE calling this function on a real capture, so this only ever
//--- creates one when none exists yet - the boot-bootstrap case (airfields that start pre-owned via
//--- Init_Town.sqf's sideID default never fire a capture transition, so they got a hangar
//--- (fable/fix-hangar-aircraft-buy) but no service point until first captured).
//--- Flag-off (0) = byte-identical to HEAD.
if ((missionNamespace getVariable ["WFBE_C_AIRFIELD_SERVICE", 0]) > 0) then {
	_wfbeSvcOld = _location getVariable ["wfbe_airfield_sp", objNull];
	if (isNull _wfbeSvcOld) then {
		_wfbeSvcClass = switch (_newSide) do {
			case west:    { if (IS_chernarus_map_dependent) then {"USMC_WarfareBVehicleServicePoint"} else {"US_WarfareBVehicleServicePoint_EP1"} };
			case east:    { if (IS_chernarus_map_dependent) then {"INS_WarfareBVehicleServicePoint"} else {"TK_WarfareBVehicleServicePoint_EP1"} };
			default       { if (IS_chernarus_map_dependent) then {"Gue_WarfareBVehicleServicePoint"} else {"TK_GUE_WarfareBVehicleServicePoint_EP1"} };
		};
		_wfbeSvcPos = if !(isNull _airfieldLogic) then {
			[(getPos _airfieldLogic select 0), ((getPos _airfieldLogic select 1) + 80), 0]
		} else {
			[(getPos _location select 0), ((getPos _location select 1) + 80), 0]
		};
		_wfbeSvcSp = _wfbeSvcClass createVehicle _wfbeSvcPos;
		if (isNull _wfbeSvcSp) exitWith {
			["WARNING", Format ["Server_ProvisionAirfieldHangar.sqf: airfield service-point createVehicle FAILED class=%1 for side %2 at %3.", _wfbeSvcClass, str _newSide, _wfbeSvcPos]] Call WFBE_CO_FNC_LogContent;
		};
		_wfbeSvcSp setPos _wfbeSvcPos;
		_wfbeSvcSp setVariable ["WFBE_RepairTruckServicePoint", true, true];
		_wfbeSvcSp setVariable ["wfbe_side", _newSide, true];

		_wfbeSvcLogik = (_newSide) Call WFBE_CO_FNC_GetSideLogic;
		_wfbeSvcLogik setVariable ["wfbe_structures", (_wfbeSvcLogik getVariable "wfbe_structures") + [_wfbeSvcSp], true];

		_wfbeSvcSp setVehicleInit Format ["[this,false,%1] ExecVM 'Client\Init\Init_BaseStructure.sqf'", (_newSide Call GetSideID)];
		processInitCommands;

		_wfbeSvcSp addEventHandler ["hit", {_this Spawn BuildingDamaged}];
		Call Compile Format ["_wfbeSvcSp AddEventHandler ['killed',{[_this select 0,_this select 1,'%1'] Spawn BuildingKilled}];", "ServicePoint"];

		_location setVariable ["wfbe_airfield_sp", _wfbeSvcSp, true];
		["INFORMATION", Format ["Server_ProvisionAirfieldHangar.sqf: airfield service point (%1) provisioned for side %2 (WFBE_C_AIRFIELD_SERVICE).", _wfbeSvcClass, str _newSide]] Call WFBE_CO_FNC_LogContent;
	};
};
