/*
	Client towns markers initialization.
*/

scriptName "Client\Init\Init_Markers.sqf";

{
	Private ["_townColor", "_townMarker", "_townSide"];

	//--- Wait for the sideID to be initialized.
	waitUntil {!isNil {_x getVariable "sideID"}};
	_townSide = _x getVariable "sideID";
	
	//--- Determine the coloration method.
	_townColor = missionNamespace getVariable "WFBE_C_UNKNOWN_COLOR";
	if (_townSide == WFBE_Client_SideID) then {
		_townColor = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR",(_townSide) Call WFBE_CO_FNC_GetSideFromID]);
	};

	//--- Place a marker over the logic.
	_townMarker = Format ["WFBE_%1_CityMarker", str _x];
	createMarkerLocal [_townMarker, getPos _x];
	_townMarker setMarkerTypeLocal "Depot";
	_townMarker setMarkerColorLocal _townColor;
	
	//--- Wait for the camps to be initialized.
	waitUntil {!isNil {_x getVariable "camps"}};
	
	//--- The town may have some camps.
	{
		Private ["_campColor","_campMarker","_campSide"];
		
		//--- Wait for the sideID to be initialized.
		waitUntil {!isNil {_x getVariable "sideID"}};
		_campSide = _x getVariable "sideID";
		
		// --- Determine the coloration method.
		_campColor = missionNamespace getVariable "WFBE_C_UNKNOWN_COLOR";
		if (_campSide == WFBE_Client_SideID) then {
			_campColor = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR",(_campSide) Call WFBE_CO_FNC_GetSideFromID]);
		};

		//--- Place a marker over the logic.
		_campMarker = _x getVariable "wfbe_camp_marker";
		createMarkerLocal [_campMarker, getPos _x];
		_campMarker setMarkerTypeLocal "Strongpoint";
		_campMarker setMarkerColorLocal _campColor;
		_campMarker setMarkerSizeLocal [0.5,0.5];
	} forEach (_x getVariable "camps");
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
	private ["_sz","_deadline","_loc","_isShop","_mk"];
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
					createMarkerLocal [_mk, getPos _loc];
					_mk setMarkerTypeLocal "mil_triangle";
					_mk setMarkerColorLocal "ColorYellow";
					_mk setMarkerSizeLocal [_sz, _sz];
				};
			};
		} forEach towns;
		sleep 1;
	};
};