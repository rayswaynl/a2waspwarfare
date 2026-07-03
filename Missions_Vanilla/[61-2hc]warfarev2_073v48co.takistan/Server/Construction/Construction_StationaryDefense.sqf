/* Description: Creates Defenses. */
Private ["_area","_availweapons","_buildings","_builtByRepairTruck","_defense","_direction","_isAIQuery","_isArtillery","_manned","_manRange","_position","_side","_sideID","_type","_wddmChild"];
_type = _this select 0;
_side = _this select 1;
_position = _this select 2;
_direction = _this select 3;
_manned = _this select 4;
_isAIQuery = _this select 5;
_manRange = if (count _this > 6) then {_this select 6} else {missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE"};
_builtByRepairTruck = if (count _this > 7) then {_this select 7} else {false};
_wddmChild = if (count _this > 8) then {_this select 8} else {false};
_sideID = (_side) Call GetSideID;

//--- Marty 2026-06-13: guard the build position. A malformed _position (e.g. [] from a failed
//--- _findBuildPos ring search, or an undeployed/relocating HQ) makes GetClosestEntity4 below
//--- and the createVehicle/setDir/setPos triple throw, spamming the server RPT ~8x/round. Skip
//--- the placement cleanly and return objNull so callers (which already null-check the result,
//--- per Common_CreateVehicle's convention) treat it as a no-build. Low gameplay impact - one
//--- static defense not placed this tick - but it clears the deploy keep/rollback error gate.
if (isNil "_position" || {typeName _position != "ARRAY"} || {count _position < 2} || {typeName (_position select 0) != "SCALAR"} || {typeName (_position select 1) != "SCALAR"}) exitWith {
	["WARNING", Format ["Construction_StationaryDefense.sqf: [%1] skipped defense [%2] - invalid build position [%3].", str _side, _type, _position]] Call WFBE_CO_FNC_LogContent;
	objNull
};

_area = [_position,((_side) Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea"] Call WFBE_CO_FNC_GetClosestEntity4;

_defense = createVehicle [_type, _position, [], 0, "NONE"];
_defense setDir _direction;
_defense setPos _position;
_defense setVariable ["side" ,_side];
if (_wddmChild) then {
	_defense setVariable ["WFBE_WDDMPositionChild", true, true];
};
if (_builtByRepairTruck) then {
	_defense setVariable ["WFBE_BuiltByRepairTruck", true, true];
	if ((typeOf _defense) isKindOf "Base_WarfareBVehicleServicePoint") then {
		_defense setVariable ["WFBE_RepairTruckServicePoint", true, true];
	};
};
["INFORMATION", Format ["Construction_StationaryDefense.sqf: [%1] Defense [%2] has been constructed.", str _side, _type]] Call WFBE_CO_FNC_LogContent;

//--- If it's a minefield, we exit the script while spawning it.
if (_type == 'Sign_Danger') exitWith {
	Private ["_c","_h","_mine","_mineType","_toWorld"];
	_mineType = if (_side == west) then {'MineMine'} else {'MineMineE'};
	_h = -4;
	_c = 0;
	for [{_z=0}, {_z<9}, {_z=_z+1}] do{
		_array = [((_defense worldToModel (getPos _defense)) select 0) - 16 +_c,((_defense worldToModel (getPos _defense)) select 1) + _h];
		_toWorld = _defense modelToWorld _array;
		_toWorld set[2,0];
		_mine = createMine [_mineType, _toWorld,[], 0];
		mines set [count mines, [_mine, time]];

		_c = _c + 4;
	};

	_h = 0;
	_c = 2;
	for [{_z=0}, {_z<8}, {_z=_z+1}] do{
		_array = [((_defense worldToModel (getPos _defense)) select 0) - 16 +_c,((_defense worldToModel (getPos _defense)) select 1) + _h];
		_toWorld = _defense modelToWorld _array;
		_toWorld set[2,0];
		_mine = createMine [_mineType, _toWorld,[], 0];
		mines set [count mines, [_mine, time]];
		_c = _c + 4;
	};

	_h = 4;
	_c = 0;
	for [{_z=0}, {_z<9}, {_z=_z+1}] do{
		_array = [((_defense worldToModel (getPos _defense)) select 0) - 16 +_c,((_defense worldToModel (getPos _defense)) select 1) + _h];
		_toWorld = _defense modelToWorld _array;
		_toWorld set[2,0];
		_mine = createMine [_mineType, _toWorld,[], 0];
		mines set [count mines, [_mine, time]];
		_c = _c + 4;
	};
	deleteVehicle _defense;
};

_defense setVariable ["wfbe_defense", true]; //--- This is one of our defenses.

/*if (_type == 'Concrete_Wall_EP1') then {
_t= createVehicle [_type, _position, [], 0, "NONE"];
_t setVariable ["wfbe_defense", true];
_t addEventHandler ['handleDamage',{if ((_this select 4) isKindOf "BulletBase") then {getDammage (_this select 0)+(_this select 2)/180}else{getDammage (_this select 0)+(_this select 2)/95}}];
_t setpos (_defense modelToWorld [0,0,1.5]);
_t setVectorDirAndUp  [vectorDir _defense,vectorUP _defense];
_defense addEventHandler ['handleDamage',{if ((_this select 4) isKindOf "BulletBase") then {getDammage (_this select 0)+(_this select 2)/180}else{getDammage (_this select 0)+(_this select 2)/95}}];
};*/

Call Compile Format ["_defense addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]",_sideID];

if (!isNull _area) then {
	if (_defense emptyPositions "gunner" > 0 && (((missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MAX_AI") > 0) || _isAIQuery)) then {
		_availweapons = _area getVariable "weapons";
		Private ["_alives","_check","_closest","_team"];
		_team = _area getVariable "DefenseTeam";

		if (isNil '_team') then {
			_team = [_side, "defense"] Call WFBE_CO_FNC_CreateGroup;
			//--- Per-area DefenseTeam is re-manned over time; flag persistent so the empty-group
			//--- GC (server_groupsGC.sqf) never deletes it in a window between mannings.
			_team setVariable ["wfbe_persistent", true];
			_area setVariable ["DefenseTeam", _team];
		}else{
			if(side _team != _side) then{
				// Group-cap fix: delete the orphaned group before creating the new one.
				if !(isNull _team) then {
					{deleteVehicle _x} forEach (units _team);
					deleteGroup _team;
				};
				_team = [_side, "defense"] Call WFBE_CO_FNC_CreateGroup;
				//--- Re-flag persistent on the replacement group (see above).
				_team setVariable ["wfbe_persistent", true];
			};
			_area setVariable ["DefenseTeam", _team];
		};

		//--- AI16 (lane118): stamp the base-area logic on the defense so Server_HandleDefense can
		//--- recheck ownership at re-man time and stop spawning soldiers if the area has changed hands.
		_defense setVariable ["WFBE_DefenseBaseArea", _area];

		emptyQueu = emptyQueu + [_defense];
		[_defense] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
		if (_manned) then {
			_alives = (units _team) Call GetLiveUnits;
			if (count _alives < _availweapons || _isAIQuery) then {
				_buildings = (_side) Call WFBE_CO_FNC_GetSideStructures;
				_closest = ['BARRACKSTYPE',_buildings,_manRange,_side,_defense] Call BuildingInRange;

				//--- EAST/OPFOR empty-static fix (2026-06-14): manning used to be GATED behind
				//--- `alive _closest` (a side-Barracks within WFBE_C_BASE_DEFENSE_MANNING_RANGE of the
				//--- gun). AI-commander base guns are placed ~25-42m from the HQ, NOT measured from the
				//--- barracks, so if the barracks was destroyed / never built / >250m away, HandleDefense
				//--- was NEVER spawned and the gun sat empty FOREVER - silently (no log on the false
				//--- branch). The working GUER TOWN path has no barracks gate. Since crews mount instantly
				//--- AT the gun (Server_HandleDefense _moveInGunner=true, no walk), the barracks is
				//--- irrelevant to manning. So always spawn the manning loop; fall back to the side HQ as a
				//--- benign anchor when no barracks is in range, and WARN so empties become visible.
				if (isNull _closest || !(alive _closest)) then {
					_closest = (_side) Call WFBE_CO_FNC_GetSideHQ;
					["WARNING", Format ["Construction_StationaryDefense.sqf: [%1] no alive Barracks within %2m of [%3] - manning via HQ anchor instead (gun would previously sit empty).", str _side, _manRange, _type]] Call WFBE_CO_FNC_LogContent;
				};

				//--- Manning Defenses. Always start the loop for a manned gun with a free gunner slot.
				[_defense,_side,_team,_closest] Spawn HandleDefense;
			};
		};
	};

	if ((missionNamespace getVariable "WFBE_C_ARTILLERY_UI") > 0) then {
		Private ["_isAC","_isVeh"];
		_isVeh = getNumber(configFile >> "CfgVehicles" >> typeOf(_defense) >> "ARTY_IsArtyVehicle");
		_isAC = getNumber(configFile >> "CfgVehicles" >> typeOf(_defense) >> "artilleryScanner");
		if (_isVeh == 1 || _isAC == 1) then {
			_defense setVehicleInit "[this] ExecVM 'Common\Common_InitArtillery.sqf'";
			processInitCommands;
			["INFORMATION", Format ["Construction_StationaryDefense.sqf: [%1] Artillery [%2] has been given the BIS ARTY UI interface.", str _side, _type]] Call WFBE_CO_FNC_LogContent;
		};
	};
};

//--- Lane 198 (WFBE_C_FWD_STATIC_MANNING): re-man forward/FOB static guns that have
//--- no base area (_area is null). Without this the first gunner death is permanent -
//--- the re-man loop inside !isNull _area never runs for guns placed outside a base.
//--- Flag default 0 (dark): base guns already covered above; only opt in for FWD guns.
//--- Review fixes (cx-review):
//---   HIGH-1: group stored on gun object + Killed EH frees it — no per-construction group leak.
//---   HIGH-2: respect WFBE_C_BASE_DEFENSE_MAX_AI == 0 operator kill-switch (was bypassed).
//---   MODERATE: stamp WFBE_FwdOwnerSide on gun so HandleDefense (which reads WFBE_DefenseBaseArea)
//---             still exits via !alive _defense; side flag left for future capture logic.
if (isNull _area && (missionNamespace getVariable "WFBE_C_FWD_STATIC_MANNING") > 0) then {
	//--- HIGH-2: honour the operator AI kill-switch identically to the base-area path (line 96).
	if (_defense emptyPositions "gunner" > 0 && _manned && (((missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MAX_AI") > 0) || _isAIQuery)) then {
		Private ["_fwdTeam","_fwdBuildings"];
		//--- HIGH-1: reuse an existing group stored on this gun object if one already exists
		//--- (e.g. double-call guard). On fresh construction the var is nil so we create one.
		_fwdTeam = _defense getVariable "WFBE_FwdDefenseTeam";
		if (isNil "_fwdTeam" || {isNull _fwdTeam}) then {
			_fwdTeam = [_side, "defense"] Call WFBE_CO_FNC_CreateGroup;
			//--- Do NOT stamp wfbe_persistent — the group must be GC-able after gun death.
			//--- Store it on the gun so the Killed EH below can find and delete it.
			_defense setVariable ["WFBE_FwdDefenseTeam", _fwdTeam];
			//--- HIGH-1: Killed EH — drain units then delete group to prevent GC leak.
			_defense addEventHandler ["Killed", {
				Private ["_gun","_grp"];
				_gun = _this select 0;
				_grp = _gun getVariable "WFBE_FwdDefenseTeam";
				if (!isNil "_grp" && {!isNull _grp}) then {
					{deleteVehicle _x} forEach (units _grp);
					deleteGroup _grp;
				};
			}];
		};
		//--- MODERATE: stamp a FWD side marker so future capture-side logic or HandleDefense
		//--- extensions can exit on side mismatch. The current loop exits via !alive _defense.
		_defense setVariable ["WFBE_FwdOwnerSide", _sideID];
		_fwdBuildings = (_side) Call WFBE_CO_FNC_GetSideStructures;
		//--- LOW fix: pass objNull as anchor — _moveInGunner=true makes the anchor unused;
		//--- avoids the barracks/HQ lookup overhead and suppresses the spurious HQ WARNING.
		emptyQueu = emptyQueu + [_defense];
		[_defense] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
		[_defense, _side, _fwdTeam, objNull] Spawn HandleDefense;
		["INFORMATION", Format ["Construction_StationaryDefense.sqf: [%1] FWD static [%2] queued for re-manning (WFBE_C_FWD_STATIC_MANNING).", str _side, _type]] Call WFBE_CO_FNC_LogContent;
	};
};

/* Are we dealing with an artillery unit ? */
_isArtillery = [_type,_side] Call IsArtillery;
if (_isArtillery != -1) then {
	[_defense,_isArtillery,_side] Call EquipArtillery;
	if !(_builtByRepairTruck) then {
		_defense setVariable ["WFBE_CommanderArtillery", true, true];
		_defense setVariable ["WFBE_CommanderArtillerySide", str _side, true];
		_defense setVariable ["WFBE_CommanderArtilleryIndex", _isArtillery, true];
	};
};

_defense
