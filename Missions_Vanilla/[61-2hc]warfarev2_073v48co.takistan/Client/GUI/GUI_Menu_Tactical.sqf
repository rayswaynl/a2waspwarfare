private ["_enemy_side"];

disableSerialization;

_display = _this select 0;
_lastRange = artyRange;
_lastUpdate = 0;
_listBox = 17019;

sliderSetRange[17005, 10, missionNamespace getVariable "WFBE_C_ARTILLERY_AREA_MAX"];
sliderSetPosition[17005, artyRange];

ctrlSetText [17025,localize "STR_WF_TACTICAL_ArtilleryOverview" + ":"];

_markers = [];
_FTLocations = [];
_checks = [];
_fireTime = 0;
_status = 0;
_canFT = false;
_forceReload = true;
_ft = missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL";
_ftr = missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE";
_startPoint = objNull;

_marker = "artilleryMarker";
createMarkerLocal [_marker,artyPos];
_marker setMarkerTypeLocal "mil_destroy";
_marker setMarkerColorLocal "ColorRed";
_marker setMarkerSizeLocal [1,1];

_area = "artilleryAreaMarker";
createMarkerLocal [_area,artyPos];
_area setMarkerShapeLocal "Ellipse";
_area setMarkerColorLocal "ColorRed";
_area setMarkerSizeLocal [artyRange,artyRange];

_map = _display DisplayCtrl 17002;
_listboxControl = _display DisplayCtrl _listBox;

_pard = missionNamespace getVariable "WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY";
// Marty: Show each artillery type's effective min-max range next to its name (Trello #115).
// Effective max uses the same WFBE_C_ARTILLERY divisor the menu applies for _maxRange below,
// so the printed number matches the in/out-of-range coloring in the cannon list.
_artyNames    = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_DISPLAY_NAME",sideJoinedText];
_artyRangeMin = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MIN",sideJoinedText];
_artyRangeMax = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX",sideJoinedText];
_artyDivisor  = missionNamespace getVariable "WFBE_C_ARTILLERY";
for "_artyI" from 0 to (count _artyNames) - 1 do {
	_artyRowName = _artyNames select _artyI;
	if (!isNil "_artyRangeMin" && !isNil "_artyRangeMax" && _artyDivisor > 0 && _artyI < (count _artyRangeMin) && _artyI < (count _artyRangeMax)) then {
		_rmin = _artyRangeMin select _artyI;
		_rmax = round ((_artyRangeMax select _artyI) / _artyDivisor);
		_artyRowName = Format ["%1 (%2-%3m)", _artyRowName, _rmin, _rmax];
	};
	lbAdd [17008, _artyRowName];
};
lbSetCurSel[17008,0];

// Marty: Include the artillery ammo selector in the artillery enable/disable state.
_IDCS = [17005,17006,17007,17008,17034];
if ((missionNamespace getVariable "WFBE_C_ARTILLERY") == 0) then {{ctrlEnable [_x,false]} forEach _IDCS};

{ctrlEnable [_x, false]} forEach [17010,17011,17012,17013,17014,17015,17017,17018,17020];

_currentValue = -1;
_currentFee = -1;
_currentSpecial = "";
_currentFee = -1;

//--- Support List.
_lastSel = -1;
_addToList = [localize 'STR_WF_TACTICAL_FastTravel',localize 'STR_WF_ICBM',localize 'STR_WF_TACTICAL_ParadropAmmo',localize 'STR_WF_TACTICAL_ParadropVehicle',localize 'STR_WF_TACTICAL_Paratroop',localize 'STR_WF_TACTICAL_UnitCam',localize 'STR_WF_TACTICAL_UAV',localize 'STR_WF_TACTICAL_UAVDestroy',localize 'STR_WF_TACTICAL_UAVRemoteControl'];
_addToListID = ["Fast_Travel","ICBM","Paradrop_Ammo","Paradrop_Vehicle","Paratroopers","Units_Camera","UAV","UAV_Destroy","UAV_Remote_Control"];
_addToListFee = [0,75000,9500,3500,8500,0,12500,0,0];
_addToListInterval = [0,1000,800,600,_pard,0,0,0,0];	//--- QoL fix: paratrooper cooldown now respects WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY (was hardcoded 900, silently ignoring the mission param)

//--- cmdcon41-w3i (Ray 2026-07-02) SCUD/TEL MUNITIONS moved into the Tactical menu (this is the ONE place all SCUD/TEL
//--- fire calls now live, beside the classic ICBM/NUKE row — the w3g war-room buttons were removed). Each is appended as a
//--- support-list entry with plain-string labels; enable-gated in the switch below; each arms a map-click that sends the
//--- SAME server payload the buttons used (icbm-tel-fire for the 5 TEL munitions; ScudStrike for the carrier). Entries are
//--- feature-flag-gated at BUILD time: the 5 TEL munitions require WFBE_C_ICBM_TEL; the carrier SCUD requires WFBE_C_SCUD_MENU.
//--- Fees pull live from the same cost flags the server charges (server remains authoritative; the client display matches).
if ((missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]) > 0) then {
	_addToList = _addToList + ["SCUD: SATURATION", "SCUD: RECON FLASH", "SCUD: FASCAM (mines)", "SCUD: STEEL RAIN (anti-inf)", "SCUD: BUNKER BUSTER (point)"];
	_addToListID = _addToListID + ["TEL_Saturation","TEL_Recon","TEL_Fascam","TEL_SteelRain","TEL_Buster"];
	_addToListFee = _addToListFee + [
		(missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000]),
		(missionNamespace getVariable ["WFBE_C_ICBM_TEL_RECON_COST", 10000]),
		(missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_COST", 14000]),
		(missionNamespace getVariable ["WFBE_C_ICBM_TEL_RAIN_COST", 9000]),
		(missionNamespace getVariable ["WFBE_C_ICBM_TEL_BUSTER_COST", 18000])
	];
	_addToListInterval = _addToListInterval + [0,0,0,0,0];	//--- server enforces the SHARED TEL cooldown (WFBE_C_ICBM_TEL_COOLDOWN); no client interval gate.
};
if ((missionNamespace getVariable ["WFBE_C_SCUD_MENU", 1]) > 0) then {
	_addToList = _addToList + ["SCUD STRIKE (carrier)"];
	_addToListID = _addToListID + ["SCUD_Carrier"];
	_addToListFee = _addToListFee + [(missionNamespace getVariable ["WFBE_C_SCUD_COST", 25000])];
	_addToListInterval = _addToListInterval + [0];	//--- server enforces the per-carrier cooldown (WFBE_C_SCUD_COOLDOWN).
};

for '_i' from 0 to count(_addToList)-1 do {
	lbAdd [_listBox,_addToList select _i];
	lbSetValue [_listBox, _i, _i];
};

lbSort _listboxControl;

//--- Artillery Mode.
_mode = missionNamespace getVariable 'WFBE_V_ARTILLERYMINMAP';
if (isNil '_mode') then {_mode = 2;missionNamespace setVariable ['WFBE_V_ARTILLERYMINMAP',_mode]};
_trackingArray = [];
_trackingArrayID = [];
_lastArtyUpdate = -60;
_minRange = 100;
_maxRange = 200;
_requestMarkerTransition = false;
_requestRangedList = true;
_startLoad = true;
// Marty: Cache ammo options and remember the last selected ammo per artillery type while the menu is open.
_currentAmmoOptions = [];
_ignoreAmmoComboAction = false;
_selectedAmmoByArtillery = [];
_artilleryDisplayNames = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_DISPLAY_NAME",sideJoinedText];
for "_i" from 0 to (count _artilleryDisplayNames) - 1 do {_selectedAmmoByArtillery set [_i, 0]};

// Marty: Rebuild ammo choices from the selected artillery type and current upgrade level.
_refreshAmmoCombo = {
	Private ["_ammoIndex","_artilleryIndex","_displayName","_i","_selectedAmmoIndex","_selectedComboIndex"];

	_artilleryIndex = lbCurSel 17008;
	lbClear 17034;
	_currentAmmoOptions = [];
	ctrlEnable [17034,false];

	if (_artilleryIndex < 0) exitWith {};

	_currentAmmoOptions = [sideJoinedText, _artilleryIndex] Call WFBE_CO_FNC_GetArtilleryAmmoOptions;
	if (count _currentAmmoOptions == 0) exitWith {};

	for "_i" from 0 to (count _currentAmmoOptions) - 1 do {
		_displayName = (_currentAmmoOptions select _i) select 0;
		lbAdd [17034, _displayName];
		lbSetValue [17034, _i, (_currentAmmoOptions select _i) select 3];
	};

	_selectedAmmoIndex = _selectedAmmoByArtillery select _artilleryIndex;
	_selectedComboIndex = 0;
	for "_i" from 0 to (count _currentAmmoOptions) - 1 do {
		if (((_currentAmmoOptions select _i) select 3) == _selectedAmmoIndex) then {_selectedComboIndex = _i};
	};

	ctrlEnable [17034,true];
	_ignoreAmmoComboAction = true;
	lbSetCurSel [17034, _selectedComboIndex];
};

//--- Startup coloration.
with uinamespace do {
	currentBEDialog = _display;
	switch (_mode) do {
		case 0: {(currentBEDialog displayCtrl 17023) ctrlSetTextColor [1,1,1,1]};
		case 1: {(currentBEDialog displayCtrl 17023) ctrlSetTextColor [0,0.635294,0.909803,1]};
		case 2: {(currentBEDialog displayCtrl 17023) ctrlSetTextColor [0.6,0.850980,0.917647,1]};
	};
};

lbSetCurSel[_listbox, 0];

if ((missionNamespace getVariable "WFBE_C_ARTILLERY") == 0) then {
	(_display displayCtrl 17016) ctrlSetStructuredText (parseText Format['<t align="right" color="#FF4747">%1</t>',localize 'STR_WF_Disabled']);
};

//--- cmdcon41-w3i (Ray 2026-07-02) SHARED ENABLE PREDICATE for the 5 land-TEL munition list entries. Input:
//--- [_currentUpgrades, _currentFee, _funds]. Returns TRUE only when the player is the commander AND holds the SCUD
//--- platform (WFBE_UP_ICBM level >= 1 — L1 conventional; the NUKE separately needs >= 2) AND this side's land TEL is
//--- alive (the WFBE_ICBM_TEL_<sideJoined> broadcast object ref, client-readable, same as the war-room gate used) AND can
//--- afford the fee. The server (WFBE_SE_FNC_IcbmTelFire) independently re-validates every one of these on fire.
WFBE_CL_FNC_TelMuniEnable = {
	private ["_upg","_fee","_fnd","_lvl","_cmd","_telObj","_telAlive"];
	_upg = _this select 0;
	_fee = _this select 1;
	_fnd = _this select 2;
	_lvl = 0;
	if (typeName _upg == "ARRAY" && {!isNil "WFBE_UP_ICBM"} && {WFBE_UP_ICBM < count _upg}) then {_lvl = _upg select WFBE_UP_ICBM};
	_cmd = false;
	if (!isNull commanderTeam) then { if (commanderTeam == group player) then {_cmd = true} };
	_telObj = missionNamespace getVariable [format ["WFBE_ICBM_TEL_%1", str sideJoined], objNull];
	_telAlive = (!isNull _telObj && {alive _telObj});
	if (_lvl >= 1 && _cmd && _telAlive && _fnd >= _fee) then {true} else {false}
};

_textAnimHandler = [] spawn {};

MenuAction = -1;
mouseButtonUp = -1;

while {alive player && dialog} do {
	if (side group player != sideJoined) exitWith {deleteMarkerLocal _marker;deleteMarkerLocal _area;{deleteMarkerLocal _x} forEach _markers;closeDialog 0};
	if (!dialog) exitWith {deleteMarkerLocal _marker;deleteMarkerLocal _area;{deleteMarkerLocal _x} forEach _markers};
	
	_currentUpgrades = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
	
	if (_ft > 0) then {
		_currentLevel = _currentUpgrades select WFBE_UP_FASTTRAVEL;
		if (time - _lastUpdate > 15 && _currentLevel > 0) then {
			{deleteMarkerLocal _x} forEach _markers;
			_markers = [];
			_FTLocations = [];
			_canFT = false;
			_startPoint = objNull;
			_lastUpdate = time;
			_base = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
			_isDeployed = (sideJoined) Call WFBE_CO_FNC_GetSideHQDeployStatus;
				if (isNil "_isDeployed") then {_isDeployed = false}; //--- B751: GetSideHQDeployStatus returns nil before wfbe_hq_deployed replicates (JIP) -> would throw "Undefined variable: _isdeployed".
			if (player distance _base < _ftr && alive _base && vehicle player != _base && _isDeployed) then {
				_canFT = true;
				_startPoint = _base;
			} else {
				_closest = [player,towns] Call WFBE_CO_FNC_GetClosestEntity;
				_sideID = _closest getVariable "sideID";
				_camps = [_closest,sideJoined] Call GetFriendlyCamps;
				_allCamps = _closest getVariable "camps";
				if (_sideID == sideID && player distance _closest < _ftr && (count _camps == count _allCamps)) then {_canFT = true;_startPoint = _closest} else {
					_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
					_checks = [sideJoined,missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE",sideJoinedText],_buildings] Call GetFactories;
					if (count _checks > 0) then {
						_closest = [player,_checks] Call WFBE_CO_FNC_GetClosestEntity;
						if (player distance _closest < _ftr) then {
							_canFT = true;
							_startPoint = _closest;
						};
					};
				};
			};
			if (!canMove (vehicle player)) then {_canFT = false};
			if (_canFT) then {
				_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
				_checks = [sideJoined,missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE",sideJoinedText],_buildings] Call GetFactories;
				_locations = towns + _checks;
				if (alive _base && _isDeployed) then {_locations = _locations + [_base]};
				_i = 0;
				_fee = 0;
				_funds = if (_ft == 2) then {Call GetPlayerFunds} else {0};
				{
					if (_x distance player <= (missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE_MAX") && _x distance player > _ftr) then {
						_skip = false;
						if (_x in towns) then {
							_sideID = _x getVariable "sideID";
							_camps = [_x,sideJoined] Call GetFriendlyCamps;
							_allCamps = _x getVariable "camps";
							if (_sideID != sideID || (count _camps != count _allCamps)) then {_skip = true};
							if (_ft == 2) then {
								_fee = round(((_x distance player)/1000) * (missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM"));
								if (_funds < _fee) then {_skip = true};
							};
						};
						if !(_skip) then {
							_FTLocations = _FTLocations + [_x];
							_markerName = Format ["FTMarker%1",_i];
							_markers = _markers + [_markerName];
							createMarkerLocal [_markerName,getPos _x];
							_markerName setMarkerTypeLocal "mil_circle";
							_markerName setMarkerColorLocal "ColorYellow";
							_markerName setMarkerSizeLocal [1,1];
							//--- Fee, Cheap marker stuff, TBD: Add prompt or something.
							if (_ft == 2) then {
								_markerName = Format ["FTMarker%1%1",_i];
								_markers = _markers + [_markerName];
								createMarkerLocal [_markerName,[(getPos _x select 0)-5,(getPos _x select 1)+75]];
								_markerName setMarkerTypeLocal "mil_circle";
								_markerName setMarkerColorLocal "ColorYellow";
								_markerName setMarkerSizeLocal [0,0];
								_markerName setMarkerTextLocal Format ["$%1",_fee];
							};
							_i = _i + 1;
						};
					};
				} forEach _locations;
			};
		};
	};
	
	_currentSel = lbCurSel(_listBox);
	
	//--- Special changed or a reload is requested.
	if (_currentSel != _lastSel || _forceReload) then {
		_currentValue = lbValue[_listBox, _currentSel];
		
		_currentSpecial = _addToListID select _currentValue;
		_currentFee = _addToListFee select _currentValue;
		_currentInterval = _addToListInterval select _currentValue;
		
		_forceReload = false;
		_controlEnable = false;
		
		_funds = Call GetPlayerFunds;
		
		//ctrlSetText[17021,Format ["%1: $%2",localize 'STR_WF_Price',_currentFee]]; //---old
		ctrlSetText[17021,Format ["$%1",_currentFee]]; //---added-MrNiceGuy
		
		//--- Enabled or disabled?
		switch (_currentSpecial) do {
			case "Fast_Travel": {
				if (_ft > 0) then {
					_currentLevel = _currentUpgrades select WFBE_UP_FASTTRAVEL;
					_controlEnable = if (count _FTLocations > 0 && _currentLevel > 0) then {true} else {false};
				};
			};
			case "ICBM": {
				if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_ICBM") > 0 && !(IS_air_war_event)) then {
					_commander = false;
					if (!isNull(commanderTeam)) then {
						if (commanderTeam == group player) then {_commander = true};
					};
					_currentLevel = _currentUpgrades select WFBE_UP_ICBM;
					//--- cmdcon41-w3h TWO-LEVEL SCUD: the Tactical-Center launch button fires the NUKE (classic ICBM -> MenuAction 8),
					//--- which now requires SCUD level 2 (L1 = platform only). Gate the button ENABLE at >= 2 so it greys out at L1
					//--- instead of enabling then refusing at the fire path (GUI_Menu_Tactical fire block + WFBE_SE_FNC_IcbmTelFire both re-check >= 2).
					_controlEnable = if (_currentLevel >= 2 && _commander && _funds >= _currentFee) then {true} else {false};
				};
			};
			//--- cmdcon41-w3i (Ray 2026-07-02): the 5 land-TEL munitions. ENABLE gate (shared helper) = commander AND SCUD
			//--- platform level >= 1 (the same WFBE_UP_ICBM upgrade the NUKE reads at >= 2; L1 = platform/conventional) AND this
			//--- side's TEL alive (WFBE_ICBM_TEL_<side> broadcast ref) AND funds. Server (WFBE_SE_FNC_IcbmTelFire) re-validates all.
			case "TEL_Saturation": { _controlEnable = [_currentUpgrades, _currentFee, _funds] Call WFBE_CL_FNC_TelMuniEnable };
			case "TEL_Recon":      { _controlEnable = [_currentUpgrades, _currentFee, _funds] Call WFBE_CL_FNC_TelMuniEnable };
			case "TEL_Fascam":     { _controlEnable = [_currentUpgrades, _currentFee, _funds] Call WFBE_CL_FNC_TelMuniEnable };
			case "TEL_SteelRain":  { _controlEnable = [_currentUpgrades, _currentFee, _funds] Call WFBE_CL_FNC_TelMuniEnable };
			case "TEL_Buster":     { _controlEnable = [_currentUpgrades, _currentFee, _funds] Call WFBE_CL_FNC_TelMuniEnable };
			//--- cmdcon41-w3i: the carrier SCUD (migrated from war-room button 14631). ENABLE = commander AND this side owns a
			//--- Khe Sanh carrier HVT (the SAME towns[]-scan ownership read the button used) AND funds. Server re-validates.
			case "SCUD_Carrier": {
				_commander = false;
				if (!isNull(commanderTeam)) then { if (commanderTeam == group player) then {_commander = true} };
				_ownsCarrier = false;
				if (!isNil "towns") then {
					{ if (!isNull _x && {_x getVariable ["wfbe_is_naval_hvt", false]} && {(_x getVariable ["sideID", -1]) == sideID}) exitWith {_ownsCarrier = true} } forEach towns;
				};
				_controlEnable = if (_commander && _ownsCarrier && _funds >= _currentFee) then {true} else {false};
			};
			case "Paratroopers": {
				_currentLevel = _currentUpgrades select WFBE_UP_PARATROOPERS;
				_controlEnable = if (_funds >= _currentFee && _currentLevel > 0 && time - lastParaCall > _currentInterval) then {true} else {false};
			};
			case "Paradrop_Ammo": {
				_currentLevel = _currentUpgrades select WFBE_UP_SUPPLYPARADROP;
				_controlEnable = if (_funds >= _currentFee && _currentLevel > 0 && time - lastSupplyCall > _currentInterval) then {true} else {false};
			};
			case "Paradrop_Vehicle": {
				_currentLevel = _currentUpgrades select WFBE_UP_SUPPLYPARADROP;
				_controlEnable = if (_funds >= _currentFee && _currentLevel > 0 && time - lastSupplyCall > _currentInterval) then {true} else {false};
			};
			case "UAV": {
				_currentLevel = _currentUpgrades select WFBE_UP_UAV;
				_controlEnable = if (_funds >= _currentFee && _currentLevel > 0 && !(alive playerUAV)) then {true} else {false};
			};
			case "UAV_Destroy": {
				_controlEnable = if (alive playerUAV) then {true} else {false};
			};
			case "UAV_Remote_Control": {
				_controlEnable = if (alive playerUAV) then {true} else {false};
			};
			case "Units_Camera": {
				_controlEnable = commandInRange;
			};
		};
		
		ctrlEnable[17020, _controlEnable];
		MenuAction = -1;
	};
	
	//--- Request Asset.
	if (MenuAction == 20) then {
		MenuAction = -1;
		
		//--- Output.
		switch (_currentSpecial) do {
			case "Fast_Travel": {
				MenuAction = 7;
				if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
				_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim;
			};
			case "ICBM": {
				MenuAction = 8;
				if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
				_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim;
			};
			//--- cmdcon41-w3i (Ray 2026-07-02): arm the map-click for each SCUD/TEL munition (unique MenuAction per munition,
			//--- resolved in the map-click block below). Same "click on the map" prompt idiom as the ICBM/paradrop entries.
			case "SCUD_Carrier": { MenuAction = 80; if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler}; _textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim; };
			case "TEL_Saturation": { MenuAction = 81; if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler}; _textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim; };
			case "TEL_Recon": { MenuAction = 82; if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler}; _textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim; };
			case "TEL_Fascam": { MenuAction = 83; if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler}; _textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim; };
			case "TEL_SteelRain": { MenuAction = 84; if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler}; _textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim; };
			case "TEL_Buster": { MenuAction = 85; if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler}; _textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim; };
			case "Paratroopers": {
				MenuAction = 3;
				if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
				_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim;
			};
			case "Paradrop_Ammo": {
				MenuAction = 10;
				if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
				_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim;
			};
			case "Paradrop_Vehicle": {
				MenuAction = 9;
				
				if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
				_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ClickOnMap',10,"ff9900"] spawn SetControlFadeAnim;
			};
			case "UAV": {
				closeDialog 0;
				ExecVM "Client\Module\UAV\uav.sqf";
			};
			case "UAV_Destroy": {
				if !(isNull playerUAV) then {
					{_x setDammage 1} forEach (crew playerUAV);
					playerUAV setDammage 1;
					playerUAV = objNull;
				};
			};
			case "UAV_Remote_Control": {
				closeDialog 0;
				ExecVM "Client\Module\UAV\uav.sqf";
			};
			case "Units_Camera": {
				closeDialog 0;
				createDialog "RscMenu_UnitCamera";
			};
		};
		
		// _forceReload = true;
	};
	
	artyRange = floor (sliderPosition 17005);
	if (_lastRange != artyRange) then {_area setMarkerSizeLocal [artyRange,artyRange];};
	
	if (mouseButtonUp == 0) then {
		mouseButtonUp = -1;
		//--- Set Artillery Marker on map.
		if (MenuAction == 1) then {
			MenuAction = -1;
			artyPos = _map posScreenToWorld[mouseX,mouseY];
			_marker setMarkerPosLocal artyPos;
			_area setMarkerPosLocal artyPos;
			_requestRangedList = true;

		};
		//--- Paratroops.
		if (MenuAction == 3) then {
			MenuAction = -1;
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			_callPos = _map posScreenToWorld[mouseX,mouseY];
			if (!surfaceIsWater _callPos) then {
				lastParaCall = time;
				-(_currentFee) Call ChangePlayerFunds;
				["RequestSpecial", ["Paratroops",sideJoined,_callPos,clientTeam]] Call WFBE_CO_FNC_SendToServer;
				
				hint (localize "STR_WF_INFO_Paratroop_Info");
			};
		};
		//--- Fast Travel.
		if (MenuAction == 7) then {
			MenuAction = -1;
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			_destination = [_callPos,_FTLocations] Call WFBE_CO_FNC_GetClosestEntity;
			if (_callPos distance _destination < 500) then {
				closeDialog 0;
				deleteMarkerLocal _marker;
				deleteMarkerLocal _area;
				
				//--- Remove Markers.
				{
					_track = (_x select 0);
					_vehicle = (_x select 1);
					
					_vehicle setVariable ['WFBE_A_Tracked', nil];

					deleteMarkerLocal Format ["WFBE_A_Large%1",_track];
					deleteMarkerLocal Format ["WFBE_A_Small%1",_track];
				} forEach _trackingArrayID;
				_mode = -1;

				if (_ft == 2) then {
					_fee = (missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_FEE") + round(((player distance _destination)/1000) * (missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM"));
					-(_fee) Call ChangePlayerFunds;
				};
				
				_travelingWith = [];
				{if (_x distance _startPoint < _ftr && !(_x in _travelingWith) && canMove _x && !(vehicle _x isKindOf "StaticWeapon") && !stopped _x && !((currentCommand _x) in ["WAIT","STOP"])) then {_travelingWith = _travelingWith + [vehicle _x]}} forEach units (group player);
				//--- FAST TRAVEL per-vehicle surcharge (Ray 2026-06-28): charge WFBE_C_GAMEPLAY_FAST_TRAVEL_VEH_FEE per DISTINCT real vehicle taken along (dedupe dup crew-seat handles + exclude foot units).
				if (_ft == 2) then {private "_ftSeen"; _ftSeen = []; {if (!(_x in _ftSeen) && !(_x isKindOf "Man")) then {_ftSeen set [count _ftSeen, _x]; -(missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_VEH_FEE") Call ChangePlayerFunds}} forEach _travelingWith;};
				
				ForceMap true;
				_compass = shownCompass;
				_GPS = shownGPS;
				_pad = shownPad;
				_radio = shownRadio;
				_watch = shownWatch;

				showCompass false;
				showGPS false;
				showPad false;
				showRadio false;
				showWatch false;

				mapAnimClear;
				mapAnimCommit;

				_locationPosition = getPos _destination;
				_camera = "camera" camCreate _locationPosition;
				_camera camSetDir 0;
				_camera camSetFov 1;
				_camera cameraEffect["Internal","TOP"];

				_camera camSetTarget _locationPosition;
				_camera camSetPos [_locationPosition select 0,(_locationPosition select 1) + 2,100];
				_camera camCommit 0;
				
				mapAnimAdd [0,0.05,GetPos _startPoint];
				mapAnimCommit;
				
				_delay = ((_startPoint distance _destination) / 50) * (missionNamespace getVariable "WFBE_C_GAMEPLAY_FAST_TRAVEL_TIME_COEF");
				mapAnimAdd [_delay,.18,getPos _destination];
				mapAnimCommit;
				
				waitUntil {mapAnimDone || !alive player};
				_skip = false;
				if (!alive player) then {_skip = true};
				if (!_skip) then {
					{[_x,_locationPosition,120] Call PlaceSafe} forEach _travelingWith;
				};
				sleep 1;
				
				ForceMap false;
				showCompass _compass;
				showGPS _GPS;
				showPad _pad;
				showRadio _radio;
				showWatch _watch;
				
				_camera cameraEffect["TERMINATE","BACK"];
				camDestroy _camera;

				//--- Q9 (B69): arrival confirmation for the dropped squad (all client-local).
				if (!_skip) then {
					_destName = "destination";
					if (!isNull _destination) then {
						_dn = _destination getVariable ["name",""];
						if (typeName _dn == "STRING" && {_dn != ""}) then {_destName = _dn};
					};
					titleText [Format ["Arrived: %1", _destName], "PLAIN DOWN"];
					playSound "cashierSound"; //--- soft confirmation chime (project CfgSounds, already used for FundsTransfer)
					systemChat Format ["Fast travel complete - %1 unit(s) moved to %2.", count _travelingWith, _destName];
				};
			};
		};
		//--- ICBM Strike.
		if (MenuAction == 8) then {
			if (!(["wf_icbm", Format ["<t color='#ff5a5a' size='1.1'>Confirm ICBM strike?</t><br/>Cost $%1. Click the target on the map again to confirm.", _currentFee]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			//--- cmdcon41 LAND ICBM TEL (feature 3, Ray 2026-07-02): when the TEL feature is ON, the classic ICBM fire is
			//--- INTERCEPTED and routed through the side's land TEL. We do NOT deduct funds or spawn the warhead client-side;
			//--- the SERVER (WFBE_SE_FNC_IcbmTelFire) validates TEL-alive + shared cooldown + funds, runs the 5-min NUKE
			//--- countdown at the TEL (destroy-to-cancel), and at T-0 fires the SAME NukeDammage warhead. Munition = "NUKE"
			//--- (the classic ICBM call maps to NUKE per spec; SATURATION/RECON have their own command-menu buttons). Payload
			//--- carries the tactical-menu ICBM fee so the server charges the classic cost for a NUKE. group player = commander team.
			if ((missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]) > 0) exitWith {
				//--- cmdcon41 TWO-LEVEL "SCUD" GATE (Ray 2026-07-02): the NUKE (classic ICBM) now REQUIRES SCUD level >= 2.
				//--- The legacy enable check for this ICBM entry is at GUI_Menu_Tactical.sqf case "ICBM" (_currentLevel > 0,
				//--- i.e. >= 1) — that validator belongs to the PARALLEL upgrade lane (Core_Upgrades/display-name); we do NOT
				//--- change it, but we enforce >= 2 HERE at the fire path (server re-validates in WFBE_SE_FNC_IcbmTelFire).
				//--- _currentUpgrades/WFBE_UP_ICBM are already in scope in this menu loop (the enable switch reads them).
				private ["_scudLvl"];
				_scudLvl = 0;
				if (!isNil "_currentUpgrades" && {!isNil "WFBE_UP_ICBM"} && {WFBE_UP_ICBM < count _currentUpgrades}) then {_scudLvl = _currentUpgrades select WFBE_UP_ICBM};
				if (_scudLvl < 2) exitWith {
					hintSilent parseText "<t color='#F8D664'>The NUKE needs the ICBM tech (SCUD level 2). Research it first.</t>";
				};
				["RequestSpecial", ["icbm-tel-fire", playerSide, [_callPos select 0, _callPos select 1, 0], "NUKE", group player, _currentFee]] Call WFBE_CO_FNC_SendToServer;
				hintSilent parseText "<t color='#F89060'>ICBM launch order sent to your land TEL. Protect it - if it is destroyed before impact, the strike aborts.</t>";
			};
			//--- CLASSIC path (WFBE_C_ICBM_TEL=0): fire immediately from the commander's client as before.
			-_currentFee Call ChangePlayerFunds;
			_obj = "HeliHEmpty" createVehicle _callPos;
			
			//--- Marty : Creating the ICBM marker on map for the commander who give the order:
			_ICBM_marker_name 		= "ICBM_" + str(time) ;
			_ICBM_markerPosition 	= position _obj ;
			_ICBM_markerType 		= "mil_warning";
			_ICBM_markerText 		= "ICBM by commander";
			_ICBM_markerColor 		= "ColorRed";
			_ICBM_markerSide		= playerSide;
			_ICBM_markerRadius      = missionNamespace getVariable "ICBM_DAMAGE_RADIUS";
			_ICBM_marker_elipse_name = format["Elipse_%1", _ICBM_marker_name];

			[_ICBM_marker_name, _ICBM_markerPosition, _ICBM_markerType, _ICBM_markerText, _ICBM_markerColor, _ICBM_markerSide, _ICBM_marker_elipse_name, _ICBM_markerRadius] call WF_createMarker ;


			// Marty : Messages text and audio to be sent : 
			if (playerSide == east) then 
			{
				_enemy_side = west;
			}else 
			{
				_enemy_side = east;
			};

			[playerSide]  call ICBM_FriendySide_Message ;	// Text and audio to be sent to the friendly side. 
			[_enemy_side] call ICBM_EnemySide_Message ;		// Text and audio to be sent to the enemy side. 

			// Initiate the launch
			[_obj,_ICBM_marker_name] Spawn NukeIncoming;
			
			//remove ICBM marker after countdown elapsed
			_time_before_ICBM_impact = missionNamespace getVariable "WFBE_ICBM_TIME_TO_IMPACT"; // time in minutes.
			_time_before_ICBM_impact = _time_before_ICBM_impact * 60 ;							// time in seconds.
			[_ICBM_marker_name,_time_before_ICBM_impact] call WFBE_CL_FNC_Delete_Marker ;			// delete the marker. 
			[_ICBM_marker_elipse_name,_time_before_ICBM_impact] call WFBE_CL_FNC_Delete_Marker ;	// delete the elipse marker.		
		};
		//--- Vehicle Paradrop.
		if (MenuAction == 9) then {
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			lastSupplyCall = time;
			-_currentFee Call ChangePlayerFunds;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["ParaVehi",sideJoined,_callPos,clientTeam]] Call WFBE_CO_FNC_SendToServer;
		};
		//--- Ammo Paradrop.
		if (MenuAction == 10) then {
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			lastSupplyCall = time;
			-_currentFee Call ChangePlayerFunds;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["ParaAmmo",sideJoined,_callPos,clientTeam]] Call WFBE_CO_FNC_SendToServer;
		};
		//--- cmdcon41-w3i (Ray 2026-07-02) CARRIER SCUD fire (migrated from war-room button 14631 / MenuAction 770). Sends the
		//--- EXACT existing ScudStrike payload the deck addAction + old button used; server Support_ScudStrike re-validates carrier
		//--- ownership + per-carrier cooldown + funds + charges (NO client deduction). Two-click map confirm.
		if (MenuAction == 80) then {
			if (!(["wf_scud_carrier", Format ["<t color='#ff5a5a' size='1.1'>Confirm SCUD strike?</t><br/>Cost $%1. Click the target again to confirm.", (missionNamespace getVariable ["WFBE_C_SCUD_COST", 25000])]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["ScudStrike", playerSide, [_callPos select 0, _callPos select 1, 0], group player]] Call WFBE_CO_FNC_SendToServer;
			hintSilent parseText "<t color='#F89060'>SCUD strike requested - saturation inbound (server validates carrier + funds).</t>";
		};
		//--- cmdcon41-w3i (Ray 2026-07-02) TEL SATURATION fire. Two-click map confirm (ICBM idiom); NO client fund deduction
		//--- (server WFBE_SE_FNC_IcbmTelFire re-validates TEL-alive + SCUD level >= 1 + shared cooldown + range + funds + charges).
		if (MenuAction == 81) then {
			if (!(["wf_tel_tel_sat", Format ["<t color='#ff5a5a' size='1.1'>Confirm TEL saturation?</t><br/>Cost $%1. Click the target again to confirm.", (missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000])]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["icbm-tel-fire", playerSide, [_callPos select 0, _callPos select 1, 0], "SATURATION", group player, _currentFee]] Call WFBE_CO_FNC_SendToServer;
			hintSilent parseText "<t color='#F89060'>TEL saturation order sent to your land TEL (server validates TEL + range + funds).</t>";
		};
		//--- cmdcon41-w3i (Ray 2026-07-02) TEL RECON fire. Two-click map confirm (ICBM idiom); NO client fund deduction
		//--- (server WFBE_SE_FNC_IcbmTelFire re-validates TEL-alive + SCUD level >= 1 + shared cooldown + range + funds + charges).
		if (MenuAction == 82) then {
			if (!(["wf_tel_tel_recon", Format ["<t color='#ff5a5a' size='1.1'>Confirm TEL recon flash?</t><br/>Cost $%1. Click the target again to confirm.", (missionNamespace getVariable ["WFBE_C_ICBM_TEL_RECON_COST", 10000])]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["icbm-tel-fire", playerSide, [_callPos select 0, _callPos select 1, 0], "RECON", group player, _currentFee]] Call WFBE_CO_FNC_SendToServer;
			hintSilent parseText "<t color='#F89060'>TEL recon flash order sent to your land TEL (server validates TEL + range + funds).</t>";
		};
		//--- cmdcon41-w3i (Ray 2026-07-02) TEL FASCAM fire. Two-click map confirm (ICBM idiom); NO client fund deduction
		//--- (server WFBE_SE_FNC_IcbmTelFire re-validates TEL-alive + SCUD level >= 1 + shared cooldown + range + funds + charges).
		if (MenuAction == 83) then {
			if (!(["wf_tel_tel_fascam", Format ["<t color='#ff5a5a' size='1.1'>Confirm TEL FASCAM mine barrage?</t><br/>Cost $%1. Click the target again to confirm.", (missionNamespace getVariable ["WFBE_C_ICBM_TEL_FASCAM_COST", 14000])]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["icbm-tel-fire", playerSide, [_callPos select 0, _callPos select 1, 0], "FASCAM", group player, _currentFee]] Call WFBE_CO_FNC_SendToServer;
			hintSilent parseText "<t color='#F89060'>TEL FASCAM mine barrage order sent to your land TEL (server validates TEL + range + funds).</t>";
		};
		//--- cmdcon41-w3i (Ray 2026-07-02) TEL STEELRAIN fire. Two-click map confirm (ICBM idiom); NO client fund deduction
		//--- (server WFBE_SE_FNC_IcbmTelFire re-validates TEL-alive + SCUD level >= 1 + shared cooldown + range + funds + charges).
		if (MenuAction == 84) then {
			if (!(["wf_tel_tel_rain", Format ["<t color='#ff5a5a' size='1.1'>Confirm TEL steel rain?</t><br/>Cost $%1. Click the target again to confirm.", (missionNamespace getVariable ["WFBE_C_ICBM_TEL_RAIN_COST", 9000])]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["icbm-tel-fire", playerSide, [_callPos select 0, _callPos select 1, 0], "STEELRAIN", group player, _currentFee]] Call WFBE_CO_FNC_SendToServer;
			hintSilent parseText "<t color='#F89060'>TEL steel rain order sent to your land TEL (server validates TEL + range + funds).</t>";
		};
		//--- cmdcon41-w3i (Ray 2026-07-02) TEL BUSTER fire. Two-click map confirm (ICBM idiom); NO client fund deduction
		//--- (server WFBE_SE_FNC_IcbmTelFire re-validates TEL-alive + SCUD level >= 1 + shared cooldown + range + funds + charges).
		if (MenuAction == 85) then {
			if (!(["wf_tel_tel_buster", Format ["<t color='#ff5a5a' size='1.1'>Confirm TEL bunker buster?</t><br/>Cost $%1. Click the target again to confirm.", (missionNamespace getVariable ["WFBE_C_ICBM_TEL_BUSTER_COST", 18000])]] call WFBE_CL_FNC_ConfirmAction)) exitWith {};
			_forceReload = true;
			if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
			[17022] Call SetControlFadeAnimStop;
			MenuAction = -1;
			_callPos = _map PosScreenToWorld[mouseX,mouseY];
			["RequestSpecial", ["icbm-tel-fire", playerSide, [_callPos select 0, _callPos select 1, 0], "BUSTER", group player, _currentFee]] Call WFBE_CO_FNC_SendToServer;
			hintSilent parseText "<t color='#F89060'>TEL bunker buster order sent to your land TEL (server validates TEL + range + funds).</t>";
		};
	};
	
	//--- Update the Artillery Status.
	if ((missionNamespace getVariable "WFBE_C_ARTILLERY") > 0) then {
		_fireTime = (missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS") select (_currentUpgrades select WFBE_UP_ARTYTIMEOUT);
		_status = round(_fireTime - (time - fireMissionTime));
		_txt = if (time - fireMissionTime > _fireTime) then {Format['<t align="left" color="#73FF47">%1</t>',localize 'STR_WF_TACTICAL_Available']} else {Format ['<t align="left" color="#4782FF">%1 %2</t>',_status,localize 'STR_WF_Seconds']};
		(_display displayCtrl 17016) ctrlSetStructuredText (parseText _txt);
		_enable = if (_status > 0) then {false} else {true};
		ctrlEnable [17007,_enable];
	};
	
	//--- Request Fire Mission.
	if (MenuAction == 2) then {
		MenuAction = -1;
		_units = [Group player,false,lbCurSel(17008),sideJoinedText] Call GetTeamArtillery;
		if (Count _units > 0) then {
			fireMissionTime = time;
			[GetMarkerPos "artilleryMarker",lbCurSel(17008), _fireTime, artyRange] Spawn RequestFireMission;
			
		} else {
			hint (localize "STR_WF_INFO_NoArty");
		};			
	};
	
	//--- Crew All Artillery (Card #113): mount available group AI into the empty driver/gunner
	//--- seats of the player's own artillery pieces. Player-group AI and player-bought arty are
	//--- buyer-local (see Client\Functions\Client_BuildUnit.sqf moveInDriver/moveInGunner), so the
	//--- moveIn runs client-side here. No new units are spawned; only existing dismounted group AI
	//--- are seated.
	if (MenuAction == 50) then {
		private ["_artyClassnames","_allTypes","_grp","_artyPieces","_available","_seated","_crewed","_piece"];
		MenuAction = -1;

		//--- Flatten every artillery family for this side into one classname list.
		_artyClassnames = [];
		_allTypes = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES",sideJoinedText];
		if (isNil "_allTypes") then {_allTypes = []};
		{_artyClassnames = _artyClassnames + _x} forEach _allTypes;

		_grp = group player;

		//--- Player-owned artillery pieces with at least one empty crew seat (driver or gunner).
		_artyPieces = [];
		{
			_piece = vehicle _x;
			if (typeOf _piece in _artyClassnames && !(_piece in _artyPieces) && canMove _piece) then {
				if (isNull (driver _piece) || isNull (gunner _piece)) then {
					_artyPieces = _artyPieces + [_piece];
				};
			};
		} forEach (units _grp);

		//--- Available, dismounted, alive group AI (never the human player).
		_available = [];
		{
			if (alive _x && !(isPlayer _x) && (vehicle _x == _x)) then {_available = _available + [_x]};
		} forEach (units _grp);

		_seated = 0;
		{
			_piece = _x;
			//--- Driver first, then gunner; pop a free AI for each empty seat.
			if (isNull (driver _piece) && count _available > 0) then {
				_crewed = _available select 0;
				_available = _available - [_crewed];
				[_crewed] allowGetIn true;
				_crewed moveInDriver _piece;
				_seated = _seated + 1;
			};
			if (isNull (gunner _piece) && count _available > 0) then {
				_crewed = _available select 0;
				_available = _available - [_crewed];
				[_crewed] allowGetIn true;
				_crewed moveInGunner _piece;
				_seated = _seated + 1;
			};
		} forEach _artyPieces;

		if (count _artyPieces == 0) then {
			hint (localize "STR_WF_INFO_NoArty");
		} else {
			if (_seated > 0) then {
				hint Format [localize "STR_WF_TACTICAL_CrewArtilleryDone",_seated];
			} else {
				hint (localize "STR_WF_TACTICAL_CrewArtilleryNoAI");
			};
		};
	};

	//--- Arty Combo Change or Script init.
	if (MenuAction == 200 || _startLoad) then {
		MenuAction = -1;
		
		_index = lbCurSel(17008);
		_minRange = (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MIN",sideJoined]) select _index;
		_maxRange = round(((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX",sideJoined]) select _index) / (missionNamespace getVariable "WFBE_C_ARTILLERY"));

		// Marty: Refresh available ammunition whenever the artillery type changes.
		[] Call _refreshAmmoCombo;

		_trackingArray = [group player,true,lbCurSel(17008),sideJoined] Call GetTeamArtillery;
		
		_requestMarkerTransition = true;
		_requestRangedList = true;
		_startLoad = false;
	};

	// Marty: If programmatic combo selection did not fire an event, keep the next real player click active.
	if (_ignoreAmmoComboAction && MenuAction != 201) then {_ignoreAmmoComboAction = false};

	// Marty: Load the selected ammo type on every matching artillery unit owned by the player group.
	if (MenuAction == 201) then {
		MenuAction = -1;

		if (_ignoreAmmoComboAction) then {
			_ignoreAmmoComboAction = false;
		} else {
			_artilleryIndex = lbCurSel 17008;
			_ammoComboIndex = lbCurSel 17034;

			_canLoadAmmo = true;
			if (_artilleryIndex < 0) then {_canLoadAmmo = false};
			if (_ammoComboIndex < 0) then {_canLoadAmmo = false};
			if (_ammoComboIndex >= (count _currentAmmoOptions)) then {_canLoadAmmo = false};

			if (_canLoadAmmo) then {
				_ammoOption = _currentAmmoOptions select _ammoComboIndex;
				_ammoIndex = _ammoOption select 3;
				_ammoName = _ammoOption select 0;
				_units = [Group player,true,_artilleryIndex,sideJoinedText] Call GetTeamArtillery;
				_loadedCount = 0;

				_selectedAmmoByArtillery set [_artilleryIndex, _ammoIndex];
				{
					if ([_x, sideJoinedText, _artilleryIndex, _ammoIndex] Call WFBE_CO_FNC_LoadArtilleryAmmo) then {
						_loadedCount = _loadedCount + 1;
					};
				} forEach _units;

				hintSilent Format [localize "STR_WF_TACTICAL_ArtilleryAmmoRequested", _ammoName, _loadedCount];
				["INFORMATION", Format ["GUI_Menu_Tactical.sqf: Player [%1] requested artillery ammo [%2] for [%3] [%4 unit(s)].", name player, _ammoName, (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_DISPLAY_NAME",sideJoinedText]) select _artilleryIndex, _loadedCount]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};
	
	//--- Focus on an artillery cannon.
	if (MenuAction == 60) then {
		MenuAction = -1;
		
		ctrlMapAnimClear _map;
		_map ctrlMapAnimAdd [1,.475,getPos(_trackingArray select (lnbCurSelRow 17024))];
		ctrlMapAnimCommit _map;
	};
	
	//--- Flush on change.
	if (_requestMarkerTransition) then {
		_requestMarkerTransition = false;
		
		{
			_track = (_x select 0);
			_vehicle = (_x select 1);

			_vehicle setVariable ['WFBE_A_Tracked', nil];
			deleteMarkerLocal Format ["WFBE_A_Large%1",_track];
			deleteMarkerLocal Format ["WFBE_A_Small%1",_track];
		} forEach _trackingArrayID;
		_trackingArrayID = [];
	};
	
	//--- Artillery List.
	if ((missionNamespace getVariable "WFBE_C_ARTILLERY") > 0 && (_requestRangedList || time - _lastArtyUpdate > 3)) then {
		_requestRangedList = false;
		
		//--- No need to update the list all the time.
		if (time - _lastArtyUpdate > 5) then {
			_lastArtyUpdate = time;
			_trackingArray = [group player,true,lbCurSel(17008),sideJoined] Call GetTeamArtillery;
		};
		
		//--- Clear & Fill;
		lnbClear 17024;
		_i = 0;
		{
			_distance = _x distance (getMarkerPos _marker);
			_color = [0, 0.875, 0, 0.8];
			_text = localize 'STR_WF_TACTICAL_ArtilleryInRange'; 																		//---changed-MrNiceGuy //"In Range";
			if (_distance > _maxRange) then {_color = [0.875, 0, 0, 0.8];_text = localize 'STR_WF_TACTICAL_ArtilleryOutOfRange'}; 		 //---changed-MrNiceGuy //"Out of Range"};
			if (_distance <= _minRange) then {_color = [0.875, 0.5, 0, 0.8];_text = localize 'STR_WF_TACTICAL_ArtilleryRangeTooClose'}; //---changed-MrNiceGuy //"Too close"};
			lnbAddRow [17024,[[typeOf _x, 'displayName'] Call GetConfigInfo,_text]];
			lnbSetPicture [17024,[_i,0],[typeOf _x, 'picture'] Call GetConfigInfo];
			
			lnbSetColor [17024,[_i,0],_color];
			lnbSetColor [17024,[_i,1],_color];
			
			_i = _i + 1;
		} forEach _trackingArray;
	};
	
	//--- Artillery map toggle.
	if (MenuAction == 40) then {
		MenuAction = -1;
		if (_mode == -1) then {_mode = 0};
		_mode = if (_mode == 2) then {0} else {_mode + 1};
		with uinamespace do {
			switch (_mode) do {
				case 0: {(currentBEDialog displayCtrl 17023) ctrlSetTextColor [1,1,1,1]};
				case 1: {(currentBEDialog displayCtrl 17023) ctrlSetTextColor [0,0.635294,0.909803,1]};
				case 2: {(currentBEDialog displayCtrl 17023) ctrlSetTextColor [0.6,0.850980,0.917647,1]};
			};
		};
		
		if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
		_textAnimHandler = [17022,localize 'STR_WF_TACTICAL_ArtilleryMinimapInfo',7,"ff9900"] spawn SetControlFadeAnim;
		
		missionNamespace setVariable ['WFBE_V_ARTILLERYMINMAP',_mode];
		
		_requestMarkerTransition = true;
	};
	
	//--- Update artillery display.
	if (_mode != -1) then {
	
		//--- Nothing.
		if (_mode == 0) then {
			_requestMarkerTransition = true;
			_mode = -1;
		};
			
		//--- Filled Content.
		if (_mode == 1 || _mode == 2) then {
			//--- Remove if dead or null or sel changed.
			{
				_track = (_x select 0);
				_vehicle = (_x select 1);
				
				if !(alive _vehicle) then {
					deleteMarkerLocal Format ["WFBE_A_Large%1",_track];
					deleteMarkerLocal Format ["WFBE_A_Small%1",_track];
				};
			} forEach _trackingArrayID;
			
			//--- No need to update the marker all the time.
			if (time - _lastArtyUpdate > 5) then {
				_lastArtyUpdate = time;
				_trackingArray = [group player,true,lbCurSel(17008),sideJoined] Call GetTeamArtillery;
			};
			
			//--- Live Feed.
			_trackingArrayID = [];
			{
				_track = _x getVariable 'WFBE_A_Tracked';
				if (isNil '_track') then {
					_track = buildingMarker;
					buildingMarker = buildingMarker + 1;
					_x setVariable ['WFBE_A_Tracked', _track];
					_dmarker = Format ["WFBE_A_Large%1",_track];
					createMarkerLocal [_dmarker, getPos _x];
					_dmarker setMarkerColorLocal "ColorBlue";
					_dmarker setMarkerShapeLocal "ELLIPSE";
					_brush = "SOLID";
					if (_mode == 1) then {_brush = "SOLID"};
					if (_mode == 2) then {_brush = "BORDER"};
					_dmarker setMarkerBrushLocal _brush;
					_dmarker setMarkerAlphaLocal 0.4;
					_dmarker setMarkerSizeLocal [_maxRange,_maxRange];
					_dmarker = Format ["WFBE_A_Small%1",_track];
					createMarkerLocal [_dmarker, getPos _x];
					_dmarker setMarkerColorLocal "ColorBlack";
					_dmarker setMarkerShapeLocal "ELLIPSE";
					_dmarker setMarkerBrushLocal "SOLID";
					_dmarker setMarkerAlphaLocal 0.4;
					_dmarker setMarkerSizeLocal [_minRange,_minRange];
				} else {
					_dmarker = Format ["WFBE_A_Large%1",_track];
					_dmarker setMarkerPosLocal (getPos _x);
					_dmarker = Format ["WFBE_A_Small%1",_track];
					_dmarker setMarkerPosLocal (getPos _x);
				};
				_trackingArrayID = _trackingArrayID + [[_track,_x]];
			} forEach _trackingArray;
		};
	};
	
	_lastRange = artyRange;
	_lastSel = lbCurSel(_listbox);
	sleep 0.1;
	
	//--- Back Button.
	if (MenuAction == 30) exitWith { //---added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};
};

deleteMarkerLocal _marker;
deleteMarkerLocal _area;
{deleteMarkerLocal _x} forEach _markers;

if !(scriptDone _textAnimHandler) then {terminate _textAnimHandler};
//--- Remove Markers.
{
	_track = (_x select 0);
	_vehicle = (_x select 1);
	
	_vehicle setVariable ['WFBE_A_Tracked', nil];

	deleteMarkerLocal Format ["WFBE_A_Large%1",_track];
	deleteMarkerLocal Format ["WFBE_A_Small%1",_track];
} forEach _trackingArrayID;
