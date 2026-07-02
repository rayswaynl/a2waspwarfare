scriptName "Client\GUI\GUI_RespawnMenu.sqf";
disableSerialization; //--- cmdcon42 (Ray 2026-07-02): scheduled dialog loop touches display/controls across sleep; guard against "does not support serialization" (matches the convention already in the other GUI_Menu_* handlers).

uiNamespace setVariable ["wfbe_display_respawn", _this select 0];

//--- cmdcon42 BUG-8 ANTI-STRAND (Ray 2026-07-02): WFBE_DeathLocation is a GLOBAL set by
//--- Client_OnKilled.sqf:54 (= getPos _body). If the fatal body's Killed EH never ran OnKilled
//--- (e.g. a skin-swapped body whose EH re-add was missed), this menu can open with
//--- WFBE_DeathLocation nil/undefined - the RPT showed exactly that (Undefined variable
//--- wfbe_deathlocation at lines 7 & 49), which broke ctrlMapAnimAdd here AND the GetRespawnAvailable
//--- base-spawn query below, so the player saw NO base spawn and got stranded on close. Reconstruct a
//--- safe death location from the current player position (or [0,0,0] worst case) so the map anim,
//--- camera and the [side, WFBE_DeathLocation] Call GetRespawnAvailable list all get a valid ARRAY.
//--- A2-OA-1.64 safe (isNil / typeName / getPos). Idempotent: only fills when actually missing.
if (isNil "WFBE_DeathLocation" || {typeName WFBE_DeathLocation != "ARRAY"} || {count WFBE_DeathLocation < 3}) then {
	WFBE_DeathLocation = if (!isNull player) then {getPos player} else {[0,0,0]};
};

//--- respawn-ui-v2: read master flag once at open into a local; every v2 branch tests _uiV2.
_uiV2 = if (isNil "WFBE_C_RESPAWN_UI_V2") then {0} else {WFBE_C_RESPAWN_UI_V2};

//--- Focus on the player death location.
//--- v2 feature 5: use tunable zoom (WFBE_C_RESPAWN_MAP_ZOOM, default 0.03); v1: legacy 0.095.
_v2MapZoom = if (_uiV2 > 0 && {!(isNil "WFBE_C_RESPAWN_MAP_ZOOM")}) then {WFBE_C_RESPAWN_MAP_ZOOM} else {0.095};
((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511001) ctrlMapAnimAdd [0, _v2MapZoom, WFBE_DeathLocation];
ctrlMapAnimCommit ((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511001);

//--- Recall the last gear mode.
//--- v2 feature 7: unambiguous "Gear: DEFAULT" / "Gear: KEEP CURRENT" labels.
if (_uiV2 > 0) then {
	ctrlSetText [511004, if (WFBE_RespawnDefaultGear) then {localize "STR_WF_RESPAWN_GearV2Default"} else {localize "STR_WF_RESPAWN_GearV2Current"}];
} else {
	ctrlSetText [511004, if (WFBE_RespawnDefaultGear) then {localize "STR_WF_RESPAWN_GearDefault"} else {localize "STR_WF_RESPAWN_GearCurrent"}];
};

//--- v2 feature 6: show or hide the legend strip (IDC 511005) based on the master flag.
if (_uiV2 > 0) then {
	((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511005) ctrlShow true;
} else {
	((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511005) ctrlShow false;
};

//--- Register the UI (if needed).
if (isNil 'WFBE_RespawnTime') then {
	WFBE_RespawnTime = missionNamespace getVariable "WFBE_C_RESPAWN_DELAY";
	//--- cmdcon42 BUG-8: never let a nil/non-number param leave WFBE_RespawnTime undefined - the RPT
	//--- showed "Undefined variable wfbe_respawntime" at line 19, which meant the countdown loop and the
	//--- whole spawn-list `while` never ran, freezing the menu. Fall back to the config default (10).
	if (isNil "WFBE_RespawnTime" || {typeName WFBE_RespawnTime != "SCALAR"}) then {WFBE_RespawnTime = 10};
	if (WF_Debug) then {WFBE_RespawnTime = 5};

	[] Spawn {
		while {WFBE_RespawnTime > 0} do {
			sleep 1;
			WFBE_RespawnTime = WFBE_RespawnTime - 1;
		};
	};
};

_spawn_time = -1;_spawn_last_get = 0;
_spawn_at = objNull;_spawn_at_current = objNull;
_spawn_locations = [];_spawn_locations_last = [];_spawn_markers = [];
WFBE_MenuAction = -1;mouseButtonDown = -1;mouseButtonUp = -1;

//--- respawn-ui-v2: type-detection helpers (read once before the loop for efficiency).
_v2SideText = str sideJoined;
_v2AmbulanceTypes = missionNamespace getVariable [Format["WFBE_%1AMBULANCES", _v2SideText], []];
_v2RedeployTypes = missionNamespace getVariable [Format["WFBE_%1REDEPLOYTRUCKS", _v2SideText], []];
_v2ContestRadius = if (!(isNil "WFBE_C_RESPAWN_CONTESTED_RADIUS")) then {WFBE_C_RESPAWN_CONTESTED_RADIUS} else {500};
_v2SideID = sideJoined Call GetSideID;

//--- respawn-ui-v2 feature 8: attempt last-spawn pre-select on the first refresh only.
_v2LastSpawnPending = true;

//--- Start the tracker.
WFBE_MarkerTracking = objNull;
[] Spawn WFBE_CL_FNC_UI_Respawn_Selector;

while {WFBE_RespawnTime > 0 && dialog && alive player} do {

	//--- Toggle default gear.
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		WFBE_RespawnDefaultGear = if (WFBE_RespawnDefaultGear) then {false} else {true};
		if (_uiV2 > 0) then {
			ctrlSetText [511004, if (WFBE_RespawnDefaultGear) then {localize "STR_WF_RESPAWN_GearV2Default"} else {localize "STR_WF_RESPAWN_GearV2Current"}];
			//--- v2 feature 7: tint button to signal state (blue = default kit; green = keep current).
			if (WFBE_RespawnDefaultGear) then {
				((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511004) ctrlSetBackgroundColor [0.1, 0.2, 0.5, 0.9];
			} else {
				((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511004) ctrlSetBackgroundColor [0.1, 0.4, 0.2, 0.9];
			};
		} else {
			ctrlSetText [511004, if (WFBE_RespawnDefaultGear) then {localize "STR_WF_RESPAWN_GearDefault"} else {localize "STR_WF_RESPAWN_GearCurrent"}];
		};
	};
	
	//--- Refresh all
	if (time - _spawn_last_get > 1) then {
		_spawn_last_get = time;
		
		//--- Return the available spawn locations
		_spawn_locations = [sideJoined, WFBE_DeathLocation] Call GetRespawnAvailable; if (isNil "_spawn_locations" || {typeName _spawn_locations != "ARRAY"}) then {diag_log Format ["WFBE RESPAWN b754-guard: GetRespawnAvailable returned non-array for side %1 - using [] this tick.", str sideJoined]; _spawn_locations = []}; //--- B754: stop the respawn-menu _x cascade + capture the root side in the RPT.
			//--- cmdcon15 element-guard: drop any non-OBJECT / null / dead handle before the marker forEach loops + GetClosestEntity touch it.
			{ if (isNil "_x" || {typeName _x != "OBJECT"} || {isNull _x}) then {_spawn_locations = _spawn_locations - [_x]} } forEach (+_spawn_locations);

		//--- v2 feature 8: first-refresh pre-select of last remembered spawn.
		if (_uiV2 > 0 && {_v2LastSpawnPending}) then {
			_v2LastSpawnPending = false;
			if (!(isNil "WFBE_LastSelectedSpawn") && {!(isNull WFBE_LastSelectedSpawn)} && {alive WFBE_LastSelectedSpawn} && {WFBE_LastSelectedSpawn in _spawn_locations}) then {
				_spawn_at_current = WFBE_LastSelectedSpawn;
			};
		};

		//---No spawn available at first? get one!
		if (isNull _spawn_at_current) then {
			_spawn_at_current = [WFBE_DeathLocation, _spawn_locations] Call WFBE_CO_FNC_GetClosestEntity;
		};
		
		//--- Remove some old spawn location if needed.
		_found = false;
		{
			if !(_x in _spawn_locations) then {
				_marker_id = _x getVariable 'wfbe_respawn_marker';
				_spawn_markers = _spawn_markers - [_marker_id];
				deleteMarkerLocal _marker_id;
				_x setVariable ['wfbe_respawn_marker', nil];
				if (_x == _spawn_at_current && !_found) then {
					_found = true;
					_spawn_at_current = [WFBE_DeathLocation, _spawn_locations] Call WFBE_CO_FNC_GetClosestEntity;
				};
			};
		} forEach _spawn_locations_last;
		
		//--- Add/update markers to the spawns.
		{
			if !(_x in _spawn_locations_last) then {
				_marker = createMarkerLocal [Format ["wfbe_cli_respawn_m%1", unitMarker], getPos _x];
				unitMarker = unitMarker + 1;
				[_spawn_markers, _marker] Call WFBE_CO_FNC_ArrayPush;
				_marker setMarkerSizeLocal [1,1];

				//--- v2 feature 4: leader gets a distinct marker type + side colour.
				if (_uiV2 > 0 && {!isNull player} && {_x == leader group player} && {_x != player}) then {
					_marker setMarkerTypeLocal "mil_triangle";
					_marker setMarkerColorLocal WFBE_Client_Color;
				} else {
					_marker setMarkerTypeLocal "Select";
					_marker setMarkerColorLocal "ColorYellow"; //--- default; safety-color block below updates it.
				};
				_x setVariable ['wfbe_respawn_marker', _marker];
			} else {
				_marker_id = _x getVariable 'wfbe_respawn_marker';
				if (getMarkerPos _marker_id distance _x > 1) then {_marker_id setMarkerPosLocal (getPos _x)};
			};

			//--- v2 feature 3: safety color non-leader markers green (safe) or orange (contested).
			if (_uiV2 > 0) then {
				_v2Mid = _x getVariable 'wfbe_respawn_marker';
				if (!(isNil "_v2Mid")) then {
					_v2IsLeader = (!isNull player && {_x == leader group player} && {_x != player});
					if (!_v2IsLeader) then {
						_v2Contested = false;
						{
							_v2TownSID = _x2 getVariable ["sideID", -1];
							if (_v2TownSID != _v2SideID && {_x distance _x2 < _v2ContestRadius}) then {_v2Contested = true};
						} forEach towns;
						if (_v2Contested) then {
							_v2Mid setMarkerColorLocal "ColorOrange";
						} else {
							_v2Mid setMarkerColorLocal "ColorGreen";
						};
					};
				};
			};
		} forEach _spawn_locations;
		
		_spawn_locations_last = _spawn_locations;
	};

	//--- Update timer.
	if (_spawn_time != WFBE_RespawnTime) then {
		_spawn_time = WFBE_RespawnTime;
		((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511002) ctrlSetStructuredText parseText Format[localize "STR_WF_RESPAWN_Status", WFBE_RespawnTime];
	};
	
	//--- Update spawn location label.
	if (_spawn_at != _spawn_at_current) then {
		_spawn_at = _spawn_at_current;
		_spawn_label = getText(configFile >> 'CfgVehicles' >> typeOf _spawn_at >> 'displayname');
		if ((missionNamespace getVariable ["WFBE_C_UNITS_REDEPLOYTRUCK",0]) > 0 && typeOf _spawn_at in (missionNamespace getVariable [Format["WFBE_%1REDEPLOYTRUCKS",_v2SideText],[]]) ) then {
			_spawn_label = "Redeploy Truck";
		};

		//--- v2 features 1+2: type-tag prefix + distance suffix.
		if (_uiV2 > 0) then {
			_v2Tag = "";
			if (!(isNull _spawn_at)) then {
				_v2StructType = _spawn_at getVariable ["wfbe_structure_type", ""];
				if (_v2StructType == "Headquarters") then {
					_v2Tag = "[BASE] ";
				} else {
					if (_v2StructType in ["Barracks","Light","Heavy","Aircraft","CommandCenter"]) then {
						_v2Tag = "[FACTORY] ";
					} else {
						//--- Camp: presence of 'wfbe_camp_bunker' variable identifies a camp logic object.
						if (!(isNil {_spawn_at getVariable "wfbe_camp_bunker"})) then {
							_v2Tag = "[CAMP] ";
						} else {
							//--- Mobile: ambulance or redeploy truck.
							if ((typeOf _spawn_at in _v2AmbulanceTypes) || {typeOf _spawn_at in _v2RedeployTypes}) then {
								_v2Tag = "[MOBILE] ";
							} else {
								//--- Leader (a living player who leads our group).
								if (!isNull player && {_spawn_at == leader group player} && {_spawn_at != player}) then {
									_v2Tag = "[LEADER] ";
								} else {
									//--- Town / naval HVT / GUER town — all live in the `towns` array.
									if (_spawn_at in towns) then {
										_v2Tag = "[TOWN] ";
									};
								};
							};
						};
					};
				};
			};

			//--- v2 feature 2: append distance from death location.
			_v2DistStr = "";
			if (!(isNil "WFBE_DeathLocation") && {typeName WFBE_DeathLocation == "ARRAY"} && {count WFBE_DeathLocation >= 3} && {!(isNull _spawn_at)}) then {
				_v2DistStr = Format [" * %1m", round (_spawn_at distance WFBE_DeathLocation)];
			};

			_spawn_label = Format ["%1%2%3", _v2Tag, _spawn_label, _v2DistStr];
		};

		((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511003) ctrlSetStructuredText parseText Format[localize "STR_WF_RESPAWN_Status_AT", _spawn_label];
		WFBE_MarkerTracking = _spawn_at;
	};
	
	//--- A Minimap click has been performed.
	if (mouseButtonDown == 0 && mouseButtonUp == 0) then {
		mouseButtonDown = -1;
		mouseButtonUp = -1;
		//--- Attempt to get the nearest respawn of the click.
		_clicked_at = ((uiNamespace getVariable "wfbe_display_respawn") displayCtrl 511001) ctrlMapScreenToWorld [mouseX, mouseY];
		_nearest = [_clicked_at, _spawn_locations] Call WFBE_CO_FNC_GetClosestEntity;
		if (_nearest distance _clicked_at < 500) then {
			_spawn_at_current = _nearest;
			//--- v2 feature 8: persist the explicit click-selection for the next death.
			if (_uiV2 > 0) then {WFBE_LastSelectedSpawn = _nearest};
		};
	};
	
	sleep .01;
};

//--- Process if alive.
if (alive player) then {
	//--- Exit mode.
	if (WFBE_RespawnTime > 0) then {
		//--- Premature exit.
		(_spawn_at_current) Spawn {
			sleep 1;
			if (WFBE_RespawnTime > 0) then {
				createDialog "WFBE_RespawnMenu";
			} else {
				//--- Normal exit.
				WFBE_DeathLocation = nil;
				WFBE_RespawnTime = nil;
				
				//--- Execute actions on respawn.
				[player,_this] Call OnRespawnHandler;
				
				//--- Destroy the camera.
				if !(isNil 'WFBE_DeathCamera') then {
					WFBE_DeathCamera cameraEffect ["TERMINATE", "BACK"];
					camDestroy WFBE_DeathCamera;
				};
				
				//--- Remove PP FX.
				"dynamicBlur" ppEffectEnable false;
				"colorCorrections" ppEffectEnable false;
				
				//--- Fade out.
				titleCut["","BLACK IN",1];
				
				//--- Reload the overlay if enabled.
				[currentFX] Spawn FX;
			};
		};
	} else {
		//--- Normal exit.
		WFBE_DeathLocation = nil;
		WFBE_RespawnTime = nil;
		
		//--- Execute actions on respawn.
		[player,_spawn_at_current] Call OnRespawnHandler;
		
		//--- Destroy the camera.
		if !(isNil 'WFBE_DeathCamera') then {
			WFBE_DeathCamera cameraEffect ["TERMINATE", "BACK"];
			camDestroy WFBE_DeathCamera;
		};
		
		//--- Remove PP FX.
		"dynamicBlur" ppEffectEnable false;
		"colorCorrections" ppEffectEnable false;
		
		//--- Fade out.
		titleCut["","BLACK IN",1];
		
		//--- Reload the overlay if enabled.
		[currentFX] Spawn FX;
	};
} else {
	//--- Died while respawning.
	WFBE_DeathLocation = nil;
	WFBE_RespawnTime = nil;
	
	//--- Destroy the camera.
	if !(isNil 'WFBE_DeathCamera') then {
		WFBE_DeathCamera cameraEffect ["TERMINATE", "BACK"];
		camDestroy WFBE_DeathCamera;
	};
	
	//--- Remove PP FX.
	"dynamicBlur" ppEffectEnable false;
	"colorCorrections" ppEffectEnable false;
	
	//--- Reload the overlay if enabled.
	[currentFX] Spawn FX;
};

WFBE_MarkerTracking = nil;
{deleteMarkerLocal _x} forEach _spawn_markers;

//--- Close dialog if opened.
if (dialog) then {closeDialog 0};

//--- Release the UI.
uiNamespace setVariable ["wfbe_display_respawn", nil];