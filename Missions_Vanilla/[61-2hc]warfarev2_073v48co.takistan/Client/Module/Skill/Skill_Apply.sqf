/*
	Script: Skill Application System by Benny.
	Description: Skill Application.
*/

Private ["_unit"];

_unit = _this;

switch (WFBE_SK_V_Type) do {
	
	case 'Engineer': {
		/* Repair Ability */
		_unit addAction [
			("<t color='#f8d664'>" + localize 'STR_WF_ACTION_Repair'+ "</t>"),
			(WFBE_SK_V_Root + 'Engineer' + '.sqf'), 
			[], 
			80, 
			false, 
			true, 
			"", 
			"time - WFBE_SK_V_LastUse_Repair > WFBE_SK_V_Reload_Repair"
		];

		/* Salvage Ability */
		//--- Trello #15: grey out manual salvage while a FRIENDLY salvage truck is in range (it auto-salvages).
		_unit addAction [
			("<t color='#CC00CB'>" + localize 'STR_WF_ACTION_Salvage'+ "</t>"),
			(WFBE_SK_V_Root + 'Salvage' + '.sqf'),
			[],
			80,
			false,
			true,
			"",
			"(time - WFBE_SK_V_LastUse_Salvage > WFBE_SK_V_Reload_Salvage) && !(({ alive _x && (side _x == side player) } count (nearestObjects [getPos player, (missionNamespace getVariable [Format ['WFBE_%1SALVAGETRUCK', sideJoinedText], []]), (missionNamespace getVariable 'WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE')])) > 0)"
		];
	
	// Marty: Only show Repair Camp when the player is near a destroyed camp.
	_unit addAction ["<t color='#11ec52'>" + localize 'STR_WF_Repair_Camp' + "</t>",'Client\Action\Action_RepairCampEngineer.sqf', [], 97, false, true, '', 'alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)'];
	
	};
	
	case 'Officer': {
		//--- MASH deploy ability removed (June bundle). Officers keep the near-camp repair action.
		// Marty: Only show Repair Camp when the player is near a destroyed camp.
		_unit addAction ["<t color='#11ec52'>" + localize 'STR_WF_Repair_Camp' + "</t>",'Client\Action\Action_RepairCampEngineer.sqf', [], 97, false, true, '', 'alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)'];
	};

	case 'SpecOps': {
		// Supply truck mission
		_unit addAction [
			"<t color='#00e83e'>" + 'LOAD SUPPLIES' + "</t>",
			'Client\Module\supplyMission\supplyMissionStart.sqf',
			[], 
			80, 
			false, 
			true, 
			"", 
			"(vehicle player == player) && (player distance (call GetClosestFriendlyLocation) < 70) && ((cursorTarget getVariable ['SupplyAmount',0]) <= 0) && !(cursorTarget getVariable ['SupplyLoading',false]) && ((typeOf cursorTarget in WFBE_C_SUPPLY_TRUCK_TYPES) || ((typeOf cursorTarget in WFBE_C_SUPPLY_HELI_TYPES) && (((sideJoined call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIR) >= 3)))"
		];

		_unit addAction [
			"<t color='#00e83e'>" + 'UNLOAD SUPPLIES' + "</t>",
			'Client\Module\supplyMission\supplyMissionUnload.sqf',
			[],
			81,
			false,
			true,
			"",
			"(((typeOf (vehicle player)) in WFBE_C_SUPPLY_HELI_TYPES) && (((vehicle player) getVariable ['SupplyAmount',0]) > 0) && ((vehicle player) getVariable ['SupplyByHeli',false])) || (((typeOf cursorTarget) in WFBE_C_SUPPLY_HELI_TYPES) && ((cursorTarget getVariable ['SupplyAmount',0]) > 0) && (cursorTarget getVariable ['SupplyByHeli',false])) || (({((typeOf _x) in WFBE_C_SUPPLY_HELI_TYPES) && ((_x getVariable ['SupplyAmount',0]) > 0) && (_x getVariable ['SupplyByHeli',false])} count (nearestObjects [player, WFBE_C_SUPPLY_HELI_TYPES, 30])) > 0)"
		];

		_unit addAction [
			(localize "STR_WASP_actions_fastrep"),
			(WFBE_SK_V_Root + 'LR' + '.sqf'), 
			[], 
			80, 
			false, 
			true, 
			"", 
			"(time - WFBE_SK_V_LastUse_LR > WFBE_SK_V_Reload_LR)&&((cursorTarget isKindOf 'Landvehicle' )|| (cursorTarget isKindOf 'Air'))&&(player distance cursorTarget<5)"
		];
		
	};
	case 'Spotter': {
		/* Spotting Ability */
		_unit addAction [
			("<t color='#f8d664'>" + localize 'STR_WF_ACTION_Spot'+ "</t>"),
			(WFBE_SK_V_Root + 'Sniper' + '.sqf'), 
			[], 
			80, 
			false, 
			true, 
			"", 
			"time - WFBE_SK_V_LastUse_Spot > WFBE_SK_V_Reload_Spot"
		];

		/* Lockpicking Ability */
		_unit addAction [
			("<t color='#f8d664'>" + localize 'STR_WF_ACTION_Lockpick'+ "</t>"),
			(WFBE_SK_V_Root + 'SpecOps' + '.sqf'), 
			[], 
			80, 
			false, 
			true, 
			"", 
			"time - WFBE_SK_V_LastUse_Lockpick > WFBE_SK_V_Reload_Lockpick"
		];
		
		_unit addAction [
				(localize "STR_WASP_actions_fastrep"),
				(WFBE_SK_V_Root + 'LR' + '.sqf'), 
				[], 
				80, 
				false, 
				true, 
				"", 
				"(time - WFBE_SK_V_LastUse_LR > WFBE_SK_V_Reload_LR)&&((cursorTarget isKindOf 'Landvehicle' )|| (cursorTarget isKindOf 'Air'))&&(player distance cursorTarget<5)"
			];
	
		// Marty: Only show Repair Camp when the player is near a destroyed camp.
		_unit addAction ["<t color='#11ec52'>" + localize 'STR_WF_Repair_Camp' + "</t>",'Client\Action\Action_RepairCampEngineer.sqf', [], 97, false, true, '', 'alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)'];
	
	};

	case 'Medic': {
			
		_unit addAction [
			(localize "STR_WASP_actions_fastrep"),
			(WFBE_SK_V_Root + 'LR' + '.sqf'), 
			[], 
			80, 
			false, 
			true, 
			"", 
			"(time - WFBE_SK_V_LastUse_LR > WFBE_SK_V_Reload_LR)&&((cursorTarget isKindOf 'Landvehicle' )|| (cursorTarget isKindOf 'Air'))&&(player distance cursorTarget<5)"
		];
		
		// Marty: Only show Repair Camp when the player is near a destroyed camp.
		_unit addAction ["<t color='#11ec52'>" + localize 'STR_WF_Repair_Camp' + "</t>",'Client\Action\Action_RepairCampEngineer.sqf', [], 97, false, true, '', 'alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)'];
	
	};

	case 'Soldier': {
			
		_unit addAction [
			(localize "STR_WASP_actions_fastrep"),
			(WFBE_SK_V_Root + 'LR' + '.sqf'), 
			[], 
			80, 
			false, 
			true, 
			"", 
			"(time - WFBE_SK_V_LastUse_LR > WFBE_SK_V_Reload_LR)&&((cursorTarget isKindOf 'Landvehicle' )|| (cursorTarget isKindOf 'Air'))&&(player distance cursorTarget<5)"
		];
		
		// Marty: Only show Repair Camp when the player is near a destroyed camp.
		_unit addAction ["<t color='#11ec52'>" + localize 'STR_WF_Repair_Camp' + "</t>",'Client\Action\Action_RepairCampEngineer.sqf', [], 97, false, true, '', 'alive _target && !isNil "WFBE_CL_FNC_CanRepairCampNearby" && (_target Call WFBE_CL_FNC_CanRepairCampNearby)'];
	
	};

};
