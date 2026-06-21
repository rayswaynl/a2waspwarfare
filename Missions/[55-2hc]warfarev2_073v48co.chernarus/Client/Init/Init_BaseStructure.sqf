if(isNil 'commonInitComplete')then{
	commonInitComplete = false;
};

waitUntil {commonInitComplete}; //--- Wait for the common part.

if (local player) then {
	Private["_color","_hq","_marker","_markercc","_structure","_text","_type","_side","_sideID","_voteTime","_radius",
	        "_isCBR","_cbrMarker","_cbrRadius","_cbrUp","_cbrUps","_cbrLvl","_cbrTiers","_cbrPrevR","_bsT0"];

	_structure = _this select 0;
	_hq = _this select 1;
	_sideID = _this select 2;
	_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;
    _radius = missionNameSpace getVariable "WFBE_C_STRUCTURES_COMMANDCENTER_RANGE";
	//--- B64 (Ray 2026-06-21): BOUNDED gate (mirrors the B63 arrow-loop fix). B63 left this one-shot
	//--- structure-marker draw on an UNBOUNDED waitUntil {clientInitComplete}; if client init ever
	//--- stalls, the factory/HQ marker would never paint. Proceed after 90s of in-game time at the
	//--- latest (time is paused on the loading screen, so this can't fire during a genuine load). The
	//--- diag_log makes the next RPT conclusively show whether the gate was ever the cause for factories.
	_bsT0 = time;
	waitUntil {(!isNil "clientInitComplete" && {clientInitComplete}) || ((time - _bsT0) > 90)};
	diag_log format ["[WFBE][B64 STRUCT-MARK] Init_BaseStructure proceeding type=%1 hq=%2 sideID=%3 mySideID=%4 after %5s cic=%6", typeOf (_this select 0), (_this select 1), (_this select 2), (if (isNil "WFBE_Client_SideID") then {-99} else {WFBE_Client_SideID}), round (time - _bsT0), (!isNil "clientInitComplete" && {clientInitComplete})];
	//--- B62 (Ray 2026-06-21): own-side gate uses the STABLE WFBE_Client_SideID (set once at client init,
	//--- mirrors updateaicommarkers.sqf), NOT WFBE_Client_SideJoined. WFBE_Client_SideJoined / (side player)
	//--- can drift on respawn/JIP-settle; because this script is a ONE-SHOT setVehicleInit, any drift at this
	//--- instant PERMANENTLY skipped the own-side marker (Ray RPT: OPFOR/insurgent JIP could not see own FACTORY
	//--- markers). _sideID is the server-fed structure side; compare it directly to the joined side id.
	waitUntil {!isNil "WFBE_Client_SideID"};
	if (_sideID != WFBE_Client_SideID) exitWith {};
	//--- B62 (Ray 2026-06-21): compare-and-claim so the Init_Client reconciliation rescan and the original
	//--- setVehicleInit spawn never BOTH draw a marker for the same structure (no duplicate BaseMarker). Whichever
	//--- reaches here first claims the structure; a second run for an already-claimed structure exits. The rescan
	//--- only re-fires this script for structures still UNclaimed, so a slow-sync miss self-heals exactly once.
	if (_structure getVariable ["wfbe_b62_marker_built", false]) exitWith {};
	_structure setVariable ["wfbe_b62_marker_built", true];

	sleep 2;

	_marker = Format["BaseMarker%1",buildingMarker];
	buildingMarker = buildingMarker + 1;
	_markercc= Format["CCrange%1",CCMarker];
    CCMarker = CCMarker + 1;
	createMarkerLocal [_marker,getPos _structure];
	if(typeOf _structure isKindOf "Base_WarfareBUAVterminal") then {

	          createMarkerLocal [_markercc,getPos _structure];
			  _markercc setMarkerBrushLocal "Border";
			  _markercc setMarkerShapeLocal "Ellipse";
              _markercc setMarkerColorLocal "ColorBlack";
              _markercc setMarkerSizeLocal [_radius,_radius];
	};
	_type = "mil_box";
	_color = "colorBlack";
	if (_hq) then {_type = "Headquarters"};
	_marker setMarkerTypeLocal _type;
	private "_text";
	_text = "";
	if (!_hq) then {_text = [_structure, _side] Call GetStructureMarkerLabel;_marker setMarkerSizeLocal [0.5,0.5]};
	if (isNil "_text") then {_text = ""};
	if (_text != "") then {_marker setMarkerTextLocal _text};
	_marker setMarkerColorLocal _color;

	//--- ServicePoint: use a distinct mil_objective marker with side color and "SP" label.
	if (!_hq && _text == "S") then {
		_marker setMarkerTypeLocal "mil_objective";
		_marker setMarkerTextLocal "SP";
		_marker setMarkerColorLocal (missionNamespace getVariable (Format ["WFBE_C_%1_COLOR", _side]));
	};

	//--- CBR range circle: spawn a separate watch block for Land_Antenna CBR structures.
	//--- Guard: structure must be a Land_Antenna (CBR radar type used by both buildable and airfield CBRs),
	//---   NOT a UAV terminal (which is also a Base_WarfareBUAVterminal and not a CBR), and CBR feature enabled.
	_isCBR = (typeOf _structure == "Land_Antenna" && !(typeOf _structure isKindOf "Base_WarfareBUAVterminal")
	           && (missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) > 0);
	if (_isCBR) then {
		_cbrMarker = Format ["CBRrange%1", CBRCircleMarker];
		CBRCircleMarker = CBRCircleMarker + 1;

		//--- Determine initial radius: prefer the wfbe_cbr_radius variable (airfield radars set it);
		//--- for upgrade-derived buildable radars, derive from CBR upgrade tier [750, 1500, 2000].
		_cbrRadius = _structure getVariable ["wfbe_cbr_radius", -1];
		_cbrTiers = [750, 1500, 2000];
		if (_cbrRadius < 0) then {
			_cbrUps = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
			_cbrLvl = 0;
			if (!isNil "WFBE_UP_CBRADAR" && count _cbrUps > WFBE_UP_CBRADAR) then {
				_cbrLvl = _cbrUps select WFBE_UP_CBRADAR;
			};
			_cbrLvl = (_cbrLvl min 2) max 0;
			_cbrRadius = _cbrTiers select _cbrLvl;
		};

		createMarkerLocal [_cbrMarker, getPos _structure];
		_cbrMarker setMarkerShapeLocal "Ellipse";
		_cbrMarker setMarkerBrushLocal "Border";
		_cbrMarker setMarkerColorLocal "ColorRed";
		_cbrMarker setMarkerSizeLocal [_cbrRadius, _cbrRadius];

		//--- Watch loop (sleep 5): live-resize for upgrade-derived case; clean up when structure gone.
		[_structure, _cbrMarker, _cbrTiers, _sideID, _side] spawn {
			Private ["_s","_m","_tiers","_sID","_sd","_ups","_lvl","_r","_prev","_fixed"];
			_s     = _this select 0;
			_m     = _this select 1;
			_tiers = _this select 2;
			_sID   = _this select 3;
			_sd    = _this select 4;
			//--- "Fixed" radius: set by server on airfield radars via wfbe_cbr_radius.
			//--- These radars do NOT live-resize (radius is authoritative from spawn).
			_fixed = (_s getVariable ["wfbe_cbr_radius", -1]) >= 0;
			_prev  = -1;

			while {!isNull _s && alive _s} do {
				if (!_fixed) then {
					_ups = (_sd) Call WFBE_CO_FNC_GetSideUpgrades;
					_lvl = 0;
					if (!isNil "WFBE_UP_CBRADAR" && count _ups > WFBE_UP_CBRADAR) then {
						_lvl = _ups select WFBE_UP_CBRADAR;
					};
					_lvl = (_lvl min 2) max 0;
					_r   = _tiers select _lvl;
					if (_r != _prev) then {
						_m setMarkerSizeLocal [_r, _r];
						_prev = _r;
					};
				};
				sleep 5;
			};

			deleteMarkerLocal _m;
		};
	};

	while {!isNull _structure && alive _structure} do {sleep 2};

	deleteMarkerLocal _marker;
	if(typeOf _structure isKindOf "Base_WarfareBUAVterminal") then {deleteMarkerLocal _markercc};
};