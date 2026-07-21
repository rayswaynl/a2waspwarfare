/* Description: Creates Defenses. */
Private ["_area","_availweapons","_buildings","_builtByRepairTruck","_defense","_direction","_isAIQuery","_isArtillery","_manned","_manRange","_position","_reqPlayer","_side","_sideID","_type","_wddmChild"];
_type = _this select 0;
_side = _this select 1;
_position = _this select 2;
_direction = _this select 3;
_manned = _this select 4;
_isAIQuery = _this select 5;
_manRange = if (count _this > 6) then {_this select 6} else {missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE"};
_builtByRepairTruck = if (count _this > 7) then {_this select 7} else {false};
_wddmChild = if (count _this > 8) then {_this select 8} else {false};
_reqPlayer = if (count _this > 9) then {_this select 9} else {objNull};
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
		_defense setVariable ["wfbe_side", _side, true];	//--- broadcast owner so the client repair-truck-SP side filter can read it
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
//--- fix/aicom-arty-cap (2026-07-21, owner-live report: destroyed GRAD/artillery husks persist on the
//--- map). ROOT CAUSE: Common_CreateVehicle.sqf wires BOTH a "Killed" AND a "hit" EH on every vehicle it
//--- creates (the "hit" EH stamps wfbe_lasthitby/wfbe_lasthittime via Common_OnUnitHit.sqf); this raw
//--- createVehicle construction path never went through that helper, so it wired ONLY the "Killed" EH
//--- above and never the matching "hit" EH. RequestOnUnitKilled.sqf exits the whole kill handler -
//--- including the wfbe_trashed/TrashObject cleanup enrollment further down - whenever the immediate
//--- killer is already dead/null (L62), falling back to wfbe_lasthitby ONLY when that was stamped. A
//--- real artillery shell has real flight time (Common_FireArtillery.sqf ARTY_Prep/fire/burst/reload),
//--- so a base-built gun killed by incoming fire aimed at its own side's HQ - while its own side's gun is
//--- ALSO trading fire with the enemy HQ at the same time - frequently outlives its own killer, and with
//--- no wfbe_lasthitby fallback available the wreck never gets event-driven cleanup enrollment, leaving
//--- it dependent entirely on the slower/independent allDead poll (server_collector_garbage.sqf). Wire
//--- the SAME "hit" EH Common_CreateVehicle.sqf uses so every base-built defense (including artillery)
//--- gets last-hit tracking too, closing the enrollment gap at its source.
_defense addEventHandler ["hit", {_this Spawn WFBE_CO_FNC_OnUnitHit}];

if (!isNull _area) then {
	if (_defense emptyPositions "gunner" > 0 && (((missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MAX_AI") > 0) || _isAIQuery)) then {
		_availweapons = _area getVariable "weapons";
		//--- nil-guard: area logic has weapons set on HQ deploy; player-built statics in a pre-HQ or
		//--- fresh area have weapons=nil. Treat nil as WFBE_C_BASE_DEFENSE_MAX_AI (the same value HQ
		//--- deploy would stamp) so the count-vs-availweapons gate does not throw Undefined.
		if (isNil "_availweapons") then {_availweapons = missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MAX_AI"};
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
				//--- For player-built statics (!_isAIQuery), respect the WFBE_C_PLAYER_DEFENSE_AUTOMAN flag
				//--- (default 1 = on). At flag 0 player guns are never registered for AI manning (current
				//--- behaviour). For AI-issued builds (_isAIQuery) the flag is irrelevant - always man.
				if (_isAIQuery || {(missionNamespace getVariable ["WFBE_C_PLAYER_DEFENSE_AUTOMAN", 1]) > 0}) then {
					[_defense,_side,_team,_closest] Spawn HandleDefense;
					//--- AUTOMAN|v1 telemetry: one line per player-built static registered for manning.
					//--- Always-on (not gated by WF_LOG_CONTENT) so the RPT confirms the registration.
					if (!_isAIQuery) then {
						private ["_autoUID"];
						_autoUID = if (!isNull _reqPlayer) then {getPlayerUID _reqPlayer} else {"srv"};
						diag_log ("AUTOMAN|v1|side=" + str _side + "|type=" + _type + "|by=" + _autoUID);
					};
				};
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

