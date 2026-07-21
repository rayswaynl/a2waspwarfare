/*
	Client towns markers initialization.
*/

scriptName "Client\Init\Init_Markers.sqf";

{
	Private ["_townColor", "_townMarker", "_townSide", "_wSideID", "_wCamps"];

	//--- J6 HANGGUARD: town sideID must not stall the client marker pass forever.
	_wSideID = 0;
	while {isNil {_x getVariable "sideID"} && (_wSideID < 240)} do { uiSleep 0.25; _wSideID = _wSideID + 1; };
	if (isNil {_x getVariable "sideID"}) then {
		diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Markers.sqf: town sideID was not ready after 60s - defaulting to unknown side (name=%1).", (_x getVariable ["name", "?"])];
	};
	_townSide = _x getVariable ["sideID", WFBE_C_UNKNOWN_ID];
	
	//--- Determine the coloration method.
	_townColor = missionNamespace getVariable "WFBE_C_UNKNOWN_COLOR";
	if ((missionNamespace getVariable ["WFBE_C_FIX_NEUTRAL_MAP_COLOR", 1]) > 0) then {
		if (_townSide == WFBE_C_UNKNOWN_ID) then {
			_townColor = missionNamespace getVariable ["WFBE_C_NEUTRAL_COLOR", _townColor];
		};
	};
	if ((_townSide == WFBE_Client_SideID) || (_townSide == WFBE_C_GUER_ID)) then {
		_townColor = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR",(_townSide) Call WFBE_CO_FNC_GetSideFromID]);
	};

	//--- Place a marker over the logic.
	_townMarker = Format ["WFBE_%1_CityMarker", str _x];
	createMarkerLocal [_townMarker, getPos _x];
	_townMarker setMarkerTypeLocal "Depot";
	_townMarker setMarkerColorLocal _townColor;
	
	//--- J6 HANGGUARD: town camps must not stall the client marker pass forever.
	_wCamps = 0;
	while {isNil {_x getVariable "camps"} && (_wCamps < 240)} do { uiSleep 0.25; _wCamps = _wCamps + 1; };
	if (isNil {_x getVariable "camps"}) then {
		diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Markers.sqf: town camps were not ready after 60s - skipping camp markers (name=%1).", (_x getVariable ["name", "?"])];
	};
	
	//--- The town may have some camps.
	{
		Private ["_campColor","_campMarker","_campSide","_wCampSideID"];
		
		//--- J6 HANGGUARD: camp sideID must not stall the client marker pass forever.
		_wCampSideID = 0;
		while {isNil {_x getVariable "sideID"} && (_wCampSideID < 240)} do { uiSleep 0.25; _wCampSideID = _wCampSideID + 1; };
		if (isNil {_x getVariable "sideID"}) then {
			diag_log "[WFBE (INIT)] HANGGUARD| Init_Markers.sqf: camp sideID was not ready after 60s - defaulting to unknown side.";
		};
		_campSide = _x getVariable ["sideID", WFBE_C_UNKNOWN_ID];
		
		// --- Determine the coloration method.
		_campColor = missionNamespace getVariable "WFBE_C_UNKNOWN_COLOR";
		if ((missionNamespace getVariable ["WFBE_C_FIX_NEUTRAL_MAP_COLOR", 1]) > 0) then {
			if (_campSide == WFBE_C_UNKNOWN_ID) then {
				_campColor = missionNamespace getVariable ["WFBE_C_NEUTRAL_COLOR", _campColor];
			};
		};
		if ((_campSide == WFBE_Client_SideID) || (_campSide == WFBE_C_GUER_ID)) then {
			_campColor = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR",(_campSide) Call WFBE_CO_FNC_GetSideFromID]);
		};

		//--- Place a marker over the logic.
		_campMarker = _x getVariable "wfbe_camp_marker";
		createMarkerLocal [_campMarker, getPos _x];
		_campMarker setMarkerTypeLocal "Strongpoint";
		_campMarker setMarkerColorLocal _campColor;
		_campMarker setMarkerSizeLocal [0.5,0.5];
	} forEach (_x getVariable ["camps", []]);
} forEach towns;

//--- ============================================================================
//--- SHOP POI: small YELLOW TRIANGLE over every AIRFIELD and every CARRIER/naval-HVT
//--- (the aircraft buy-shops). Ray 2026-06-29.
//---
//--- WHAT identifies a shop:
//---   • AIRFIELD = town logic with the baked wfbe_is_airfield flag (NWAF/NEAF/Balota on
//---     Chernarus, set in mission.sqm town init — present from the very start).
//---   • CARRIER  = naval-HVT town logic wired by Server\Init\Init_NavalHVT.sqf with
//---     wfbe_is_carrier_hvt / wfbe_is_naval_hvt (Khe Sanh Alpha/Bravo/Charlie). These are the
//---     aircraft-buy carriers (same air-roster shop as a captured airfield).
//--- Both are entries in the global towns[] array (Init_Town.sqf appends every logic), and both
//--- are STATIC once placed — the carrier hull/logic is pinned to z=0 ASL server-side and 2D map
//--- markers ignore Z — so each marker is created exactly once and never has to move.
//---
//--- WHY a bounded re-scan watcher (not an inline pass): the airfield flag is baked and present
//--- immediately, but the carrier flags are set SERVER-side after townInit and publicVariable'd,
//--- so on a fast / JIP client this Init_Markers run can reach here BEFORE the carrier flags have
//--- replicated. A single inline forEach would then miss the carriers. Instead one lightweight
//--- thread re-scans towns[] every second until it has marked all current shop logics, then exits
//--- after a short grace period — it catches late-replicating carrier flags without one thread
//--- per town and without ever busy-spinning forever.
//---
//--- Marker type "mil_triangle" is A2-OA-valid (already used by Common\Init\Init_Airports.sqf).
//--- Marker size is read from an optional missionNamespace tunable so the parent can retune it
//--- without a code change; the default keeps the icon small (matches the camp 0.5 marker scale).
//--- Local markers only — purely a client-side map icon.
[] Spawn {
	private ["_sz","_deadline","_loc","_isShop","_mk","_mkPos","_afLogicChecks"];
	_sz       = missionNamespace getVariable ["WFBE_C_SHOP_POI_MARKER_SIZE", 0.6];
	//--- Stop re-scanning ~60s after init: carriers are wired immediately after townInit, so any
	//--- replication lag is comfortably covered; airfields are already flagged on the first pass.
	_deadline = time + 60;

	while { time < _deadline } do {
		{
			_loc = _x;
			_isShop = (_loc getVariable ["wfbe_is_airfield", false]) || {(_loc getVariable ["wfbe_is_naval_hvt", false])} || {(_loc getVariable ["wfbe_is_carrier_hvt", false])};
			if (_isShop) then {
				_mk = Format ["WFBE_%1_ShopPOI", str _loc];
				//--- Only create once (markerType of a non-existent marker is "", so this is the create-guard).
				if ((markerType _mk) == "") then {
					//--- fable/fix-hangar-aircraft-buy: anchor on the actual LocationLogicAirport, not the
					//--- town/depot logic - the hangar/buy-point sits there (~80m away), so the town position
					//--- put the triangle off the real shop bubble. Carriers/naval HVTs are their own airfield
					//--- ref (Init_NavalHVT.sqf) - getPos _loc is already correct for those, left unchanged.
					_mkPos = getPos _loc;
					if (_loc getVariable ["wfbe_is_airfield", false]) then {
						_afLogicChecks = (getPos _loc) nearEntities [["LocationLogicAirport"], 1500];
						if (count _afLogicChecks > 0) then { _mkPos = getPos (_afLogicChecks select 0) };
					};
					createMarkerLocal [_mk, _mkPos];
					_mk setMarkerTypeLocal "mil_triangle";
					_mk setMarkerColorLocal "ColorYellow";
					_mk setMarkerSizeLocal [_sz, _sz];
				};
			};
		} forEach towns;
		sleep 1;
	};
};