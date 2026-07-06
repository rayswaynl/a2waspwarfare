//--- Dynamic Labels.
_upgrade_paratroopers_xlabel = {
	Private ["_label","_levels"];
	_levels = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_LEVELS", WFBE_Client_SideJoinedText]) select WFBE_UP_PARATROOPERS;
	_label = "";

	for '_i' from 1 to _levels do {
		_label = _label + Format[" - Level <t color='#F5D363'>%1</t>: [<t color='#F5D363'>%2</t>] Units", _i, count(missionNamespace getVariable Format["WFBE_%1PARACHUTELEVEL%2", WFBE_Client_SideJoinedText, _i])];
		if (_i < _levels) then {_label = _label + "<br/>"};
	};

	_label
};
_upgrade_supply_xlabel = {
	Private ["_label","_levels","_rates"];
	_levels = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_LEVELS", WFBE_Client_SideJoinedText]) select WFBE_UP_SUPPLYRATE;
	_label = "";

	_rates = if ((missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_SYSTEM") == 1) then {missionNamespace getVariable "WFBE_C_TOWNS_SUPPLY_LEVELS_TIME"} else {missionNamespace getVariable "WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK"};
	
	for '_i' from 0 to _levels do {
		_label = _label + Format[" - Level <t color='#F5D363'>%1</t>: Increase supply of [<t color='#F5D363'>%2</t>]", _i, _rates select _i];
		if (_i < _levels) then {_label = _label + "<br/>"};
	};

	_label
};
_upgrade_respawn_xlabel = {
	Private ["_label","_levels"];
	_levels = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_LEVELS", WFBE_Client_SideJoinedText]) select WFBE_UP_RESPAWNRANGE;
	_label = "";

	for '_i' from 0 to _levels do {
		_label = _label + Format[" - Level <t color='#F5D363'>%1</t>: [<t color='#F5D363'>%2</t>] Meters", _i, (missionNamespace getVariable "WFBE_C_RESPAWN_RANGES") select _i];
		if (_i < _levels) then {_label = _label + "<br/>"};
	};

	_label
};
_upgrade_artillery_xlabel = {
	Private ["_label","_levels"];
	_levels = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_LEVELS", WFBE_Client_SideJoinedText]) select WFBE_UP_ARTYTIMEOUT;
	_label = "";

	for '_i' from 0 to _levels do {
		_label = _label + Format[" - Level <t color='#F5D363'>%1</t>: [<t color='#F5D363'>%2</t>] Seconds", _i, (missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS") select _i];
		if (_i < _levels) then {_label = _label + "<br/>"};
	};

	_label
};
_upgrade_icbm_xlabel = {
	Private ["_cost","_costs","_dep","_depId","_depLabel","_depText","_deps","_d","_label","_labels","_levels","_links","_time","_times","_unlock","_unlocks"];
	_levels = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_LEVELS", WFBE_Client_SideJoinedText]) select WFBE_UP_ICBM;
	_costs = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_COSTS", WFBE_Client_SideJoinedText]) select WFBE_UP_ICBM;
	_links = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_LINKS", WFBE_Client_SideJoinedText]) select WFBE_UP_ICBM;
	_times = (missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_TIMES", WFBE_Client_SideJoinedText]) select WFBE_UP_ICBM;
	_labels = missionNamespace getVariable "WFBE_C_UPGRADES_LABELS";
	_unlocks = ["SCUD TEL + conventional Command-menu strikes","ICBM nuclear strike from the Tactical Center"];
	_label = "";

	for '_i' from 0 to (_levels - 1) do {
		_cost = if (_i < count _costs) then {_costs select _i} else {[0,0]};
		_time = if (_i < count _times) then {_times select _i} else {0};
		_deps = if (_i < count _links) then {_links select _i} else {[]};
		_depText = "None";
		if (count _deps > 0) then {
			if (typeName (_deps select 0) == "ARRAY") then {
				_depText = "";
				for '_d' from 0 to (count _deps - 1) do {
					_dep = _deps select _d;
					_depId = _dep select 0;
					_depLabel = if (_depId >= 0 && {_depId < count _labels}) then {_labels select _depId} else {Format ["Upgrade %1", _depId]};
					if (_depText != "") then {_depText = _depText + ", "};
					_depText = _depText + Format ["%1 level %2", _depLabel, _dep select 1];
				};
			} else {
				_depId = _deps select 0;
				_depLabel = if (_depId >= 0 && {_depId < count _labels}) then {_labels select _depId} else {Format ["Upgrade %1", _depId]};
				_depText = Format ["%1 level %2", _depLabel, _deps select 1];
			};
		};
		_unlock = if (_i < count _unlocks) then {_unlocks select _i} else {Format ["Upgrade level %1", _i + 1]};
		_label = _label + Format[" - Level <t color='#F5D363'>%1</t>: %2<br/>   Cost: <t color='#F5D363'>%3 S</t> + <t color='#F5D363'>$%4</t>; Time: <t color='#F5D363'>%5s</t>; Requires: %6", _i + 1, _unlock, _cost select 0, _cost select 1, _time, _depText];
		if (_i + 1 < _levels) then {_label = _label + "<br/>"};
	};

	_label
};

//--- UI Labels
missionNamespace setVariable [Format["WFBE_C_UPGRADES_LABELS"], [
	localize 'strwfbarracks',
	localize 'strwflightfactory',
	localize 'strwfheavyfactory',
	localize 'strwfaircraftfactory',
	localize 'STR_WF_TACTICAL_Paratroop',
	localize 'str_dn_uav',
	localize 'STR_WF_UPGRADE_Supply',
	localize 'STR_WF_UPGRADE_RespawnRange',
	localize 'STR_WF_UPGRADE_Airlift',
	localize 'STR_WF_UPGRADE_Countermeasures',
	localize 'STR_WF_UPGRADE_ArtilleryUpgrade',
	localize 'STR_WF_ICBM',
	localize 'STR_WF_TACTICAL_FastTravel',
	localize 'STR_WF_UPGRADE_Gear',
	localize 'STR_WF_Ammo',
	'EASA',
	localize 'STR_WF_TACTICAL_Paradrop', 
	localize 'STR_WF_UPGRADE_ArtilleryAmmo',
	localize 'STR_WF_UPGRADE_IRS',
	localize 'STR_WF_UPGRADE_AirAA',
	localize 'STR_WF_UPGRADE_AntiAirRadar',
	localize 'STR_WF_UPGRADE_UnitCost',
	localize 'STR_WF_UPGRADE_CBRadar',
	'Patrols'
]];

missionNamespace setVariable [Format["WFBE_C_UPGRADES_DESCRIPTIONS"], [
	localize 'STR_WF_UPGRADE_barracks_Desc',
	localize 'STR_WF_UPGRADE_lightfactory_Desc',
	localize 'STR_WF_UPGRADE_heavyfactory_Desc',
	localize 'STR_WF_UPGRADE_aircraftfactory_Desc',
	Format[localize 'STR_WF_UPGRADE_Paratroop_Desc', Format["<t color='#B6F563'>%1</t>",[configFile >> 'CfgVehicles' >> (missionNamespace getVariable Format["WFBE_%1PARACARGO", WFBE_Client_SideJoinedText]), "displayName"] Call WFBE_CO_FNC_GetConfigEntry], call _upgrade_paratroopers_xlabel],
	localize 'STR_WF_UPGRADE_uav_Desc',
	Format[localize 'STR_WF_UPGRADE_Supply_Desc', call _upgrade_supply_xlabel],
	Format[localize 'STR_WF_UPGRADE_RespawnRange_Desc', call _upgrade_respawn_xlabel],
	localize 'STR_WF_UPGRADE_Airlift_Desc',
	localize 'STR_WF_UPGRADE_Countermeasures_Desc',
	Format[localize 'STR_WF_UPGRADE_ArtilleryUpgrade_Desc', call _upgrade_artillery_xlabel],
	Format["%1<br/><br/><t color='#42b6ff' underline='1'>Level costs:</t><br/>%2", localize 'STR_WF_UPGRADE_ICBM_Desc', call _upgrade_icbm_xlabel],
	localize 'STR_WF_UPGRADE_FastTravel_Desc',
	localize 'STR_WF_UPGRADE_Gear_Desc',
	localize 'STR_WF_UPGRADE_Ammo_Desc',
	localize 'STR_WF_UPGRADE_EASA_Desc',
	localize 'STR_WF_UPGRADE_Paradrop_Desc',
    localize 'STR_WF_UPGRADE_ArtilleryAmmo_Desc',
	localize 'STR_WF_UPGRADE_IRS_Desc',
	localize 'STR_WF_UPGRADE_AirAA_Desc',
	localize 'STR_WF_UPGRADE_AntiAirRadar_Desc',
	localize 'STR_WF_UPGRADE_UnitCost_Desc',
	localize 'STR_WF_UPGRADE_CBRadar_Desc',
	"Fields autonomous side patrols (max 3 active per side) that spawn near your HQ and push toward the frontline, capturing towns as they go. Cheap to start — worth rushing early.<br /><br />Level 1: light infantry patrol.<br />Level 2: motorised patrol (requires Light Factory level 1).<br />Level 3: armoured patrol (requires Light Factory level 1) — completing it pays your team a <t color='#F5D363'>cash bonus</t>.<br />Level 4: Convoys (requires Heavy Factory level 1) — grants your side a <t color='#F5D363'>supply bonus</t> on completion, and each patrol fields a supply truck that pays your team <t color='#F5D363'>$750 split equally</t> at every town stop.<br /><br />Patrol equipment scales with your side's tech level. Each active patrol reduces every player's max AI by 1."
]];

missionNamespace setVariable [Format["WFBE_C_UPGRADES_IMAGES"], [
	"Client\Images\upgrade_infantry.paa",
	"Client\Images\upgrade_light.paa",
	"Client\Images\upgrade_heavy.paa",
	"Client\Images\upgrade_air.paa",
	"",
	"",
	"Client\Images\upgrade_supply.paa",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"", 
	"", 
	"", 
	"",
	"Client\Images\icon_wf_building_aa_radar.paa",
	"",
	"",
	""
]];ExecVM "Common\Module\CIPHER\CIPHER_Sort.sqf";
