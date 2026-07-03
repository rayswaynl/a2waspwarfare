/*
	Return a list of groups to spawn in a town.
	 Parameters:
		- Town Entity.
		- Side.
*/

// Private ["_aa_get","_get","_groups","_infantry","_infantry_aux","_infantry_primary","_kind","_maxgroups","_ratio_inf","_ratio_inf_aux","_ratio_veh","_ratio_veh_aux","_side","_remove","_sv","_town","_types","_vehicles","_vehicles_aux","_vehicles_primary"];

_town = _this select 0;
_side = _this select 1;
_aa_get = if (count _this > 2) then {_this select 2} else {false};

_sv = _town getVariable "supplyValue";
_town_airactive = _town getVariable "wfbe_active_air";

_units = [];
_percentage_inf = 50;
_groups_max = 0;
_randomize = 0;

_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;


_current_infantry_upgrade = _upgrades select WFBE_UP_BARRACKS;
_current_light_upgrade = _upgrades select WFBE_UP_LIGHT;
_current_heavy_upgrade = _upgrades select WFBE_UP_HEAVY;

// _units = [[group type, force (multiplier), raw kind (0 inf, 1 veh)]]
switch (true) do {
	case (_sv < 10): {
		_units = [
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 1, 0]
				];
		_percentage_inf = 100;
		_groups_max = 2;
	};
	case (_sv >= 10 && _sv < 20): {
		_units = [
					[Format ["Team_%1", _current_infantry_upgrade], 2, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 2, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Motorized_%1", _current_light_upgrade], 1, 1]
				 ];
		_percentage_inf = 80;
		_groups_max = 4;
	};
	case (_sv >= 20 && _sv < 40): {
		_units = [
					[Format ["Squad_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 1, 0],
					["Team_AA", 1, 0],
					[Format ["Team_Sniper_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Motorized_%1", _current_light_upgrade], 1, 1],
					[Format ["Mechanized_%1", _current_heavy_upgrade], 1, 1]
				];
		_percentage_inf = 80;
		_groups_max = 4;

	};
	case (_sv >= 40 && _sv < 60): {
		_units = [
					[Format ["Squad_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 1, 0],
					[if(_current_infantry_upgrade == 3)then{"Squad_Advanced"}else{Format ["Squad_%1", _current_infantry_upgrade]}, 2, 0],
					[Format ["Motorized_%1", _current_light_upgrade], 1, 1],
					["AA_Light", 1, 1],
					[Format ["Mechanized_%1", _current_heavy_upgrade], 2, 1]
				];
		_percentage_inf = 75;
		_groups_max = 5;

	};
	case (_sv >= 60 && _sv < 80): {
		_units = [
					[Format ["Squad_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					["Team_AA", 2, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 2, 0],
					[Format ["Team_Sniper_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Motorized_%1", _current_light_upgrade], 2, 1],
					[Format ["Mechanized_%1", _current_heavy_upgrade], 2, 1]
				];
		_percentage_inf = 70;
		_groups_max = 5;

	};
	case (_sv >= 80 && _sv < 100): {
		_units = [
					[Format ["Squad_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 2, 0],
					[if(_current_infantry_upgrade == 3)then{"Squad_Advanced"}else{Format ["Squad_%1", _current_infantry_upgrade]}, 3, 0],
					[Format ["Mechanized_%1", _current_heavy_upgrade], 2, 1],
					[Format ["Armored_%1", _current_heavy_upgrade], 1, 1]
				];
		_percentage_inf = 70;
		_groups_max = 6;

	};
	case (_sv >= 100 && _sv < 120): {
		_units = [
					[Format ["Squad_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					["Team_AA", 1, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 2, 0],
					[if(_current_infantry_upgrade == 3)then{"Squad_Advanced"}else{Format ["Squad_%1", _current_infantry_upgrade]}, 2, 0],
					[Format ["Team_Sniper_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Mechanized_%1", _current_heavy_upgrade], 2,1],
					[Format ["Armored_%1", _current_heavy_upgrade], 3, 1]
				];
		_percentage_inf = 70;
		_groups_max = 6;
	};
	case (_sv >= 120): {
		_units = [
					[Format ["Squad_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_MG_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Team_%1", _current_infantry_upgrade], 1, 0],
					["Team_AA", 1, 0],
					[Format ["Team_AT_%1", _current_infantry_upgrade], 3, 0],
					[if(_current_infantry_upgrade == 3)then{"Squad_Advanced"}else{Format ["Squad_%1", _current_infantry_upgrade]}, 2, 0],
					[Format ["Team_Sniper_%1", _current_infantry_upgrade], 1, 0],
					[Format ["Mechanized_%1", _current_heavy_upgrade], 1, 1],
					[Format ["Armored_%1", _current_heavy_upgrade], 3, 1]
				];
		_percentage_inf = 70;
		_groups_max = 7;
	};
};

if (_randomize != 0) then {_groups_max = _groups_max + round(random _randomize - random _randomize)};
_groups_max = round(_groups_max * (missionNamespace getVariable "WFBE_C_TOWNS_UNITS_COEF"));

if (_aa_get) then {if (_groups_max > 3) then {_groups_max = 3}};

_unit_infantry = [];
_unit_vehicles = [];

{
	if (!isNil {missionNamespace getVariable Format ["WFBE_%1_GROUPS_%2",_side,_x select 0]}) then {
		_add = true;
		if (_aa_get) then {
			if !((_x select 0) in ["AA_Light","AA_Heavy","Team_AA"]) then {_add = false}
		} else {
			if (!(_town_airactive) && (_x select 0) in ["AA_Light","AA_Heavy","Team_AA"]) then {_add = false};
		};
		if (_add) then {
			_array = if ((_x select 2) == 0) then {_unit_infantry} else {_unit_vehicles};
			for '_j' from 1 to (_x select 1) do {[_array, _x select 0] Call WFBE_CO_FNC_ArrayPush};
		};
	};
} forEach _units;

_total_infantry = count _unit_infantry;
_total_vehicles = count _unit_vehicles;

if ((_total_infantry + _total_vehicles) == 0) exitWith {[]};

if (_total_infantry == 0) then {_percentage_inf = 0};
if (_total_vehicles == 0) then {_percentage_inf = 100};

if (_total_infantry > 1) then {_unit_infantry = (_unit_infantry) Call WFBE_CO_FNC_ArrayShuffle};
if (_total_vehicles > 1) then {_unit_vehicles = (_unit_vehicles) Call WFBE_CO_FNC_ArrayShuffle};

_total_infantry_p = round(_groups_max * (_percentage_inf / 100));
_total_vehicles_p = round(_groups_max - _total_infantry_p);

_final = [];
_finalKind = []; //--- claude-gaming: parallel inf(0)/veh(1) tag per _final element, for the spawn-time consolidation pass below
_inf_iterator = 0;
_veh_iterator = 0;
while {_groups_max > 0} do {
	if (_total_infantry_p > 0) then {
		_total_infantry_p = _total_infantry_p - 1;
		if (_inf_iterator > _total_infantry-1) then {_inf_iterator = 0};
		[_final, _unit_infantry select _inf_iterator] Call WFBE_CO_FNC_ArrayPush;
		[_finalKind, 0] Call WFBE_CO_FNC_ArrayPush; //--- claude-gaming: tag infantry
		_groups_max = _groups_max - 1;
		_inf_iterator = _inf_iterator + 1;
	};

	if (_total_vehicles_p > 0) then {
		_total_vehicles_p = _total_vehicles_p - 1;
		if (_veh_iterator > _total_vehicles-1) then {_veh_iterator = 0};
		[_final, _unit_vehicles select _veh_iterator] Call WFBE_CO_FNC_ArrayPush;
		[_finalKind, 1] Call WFBE_CO_FNC_ArrayPush; //--- claude-gaming: tag vehicle
		_groups_max = _groups_max - 1;
		_veh_iterator = _veh_iterator + 1;
	};
};

_contents = [];
_contentsKind = [];
_fi = 0;
{
	_get = missionNamespace getVariable Format ["WFBE_%1_GROUPS_%2", _side, _x];

	if !(isNil '_get') then {
		[_contents, _get select floor(random count _get)] Call WFBE_CO_FNC_ArrayPush;
		[_contentsKind, _finalKind select _fi] Call WFBE_CO_FNC_ArrayPush;
	};
	_fi = _fi + 1;
} forEach _final;

//--- GROUP-COUNT REDUCTION (claude-gaming 2026-06-13): spawn-time infantry consolidation.
//--- Each _contents element is a flat classname roster; CreateTeam (Common_CreateTeam.sqf:23/85)
//--- instantiates EVERY classname in one passed list into the ONE group it is given. So fusing
//--- several infantry rosters into one flat array makes the town spawn the SAME units/classes in
//--- FEWER groups -> fewer server group-brains (the ~2.1 units/group fragmentation is the FPS
//--- cliff), with IDENTICAL defenders a player sees & fights. Vehicle rosters (kind 1) are NEVER
//--- merged (preserves the CreateTeam addVehicle/crew path). Cap each merged group at 10 classnames
//--- so no single squad is unnaturally large. WFBE_C_TOWNS_MERGE_TARGET <= 0 disables (instant rollback).
_mergeTarget = missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_TARGET", 5];
if (_mergeTarget > 0 && {count _contents > 1}) then {
	_infRosters = [];
	_vehRosters = [];
	_ci = 0;
	{
		if ((_contentsKind select _ci) == 0) then {[_infRosters, _x] Call WFBE_CO_FNC_ArrayPush} else {[_vehRosters, _x] Call WFBE_CO_FNC_ArrayPush};
		_ci = _ci + 1;
	} forEach _contents;

	_merged = [];
	_acc = [];
	{
		_roster = _x;
		if (((count _acc) + (count _roster)) > 10 && {count _acc > 0}) then {[_merged, _acc] Call WFBE_CO_FNC_ArrayPush; _acc = []};
		_acc = _acc + _roster;
		if (count _acc >= _mergeTarget) then {[_merged, _acc] Call WFBE_CO_FNC_ArrayPush; _acc = []};
	} forEach _infRosters;
	if (count _acc > 0) then {[_merged, _acc] Call WFBE_CO_FNC_ArrayPush};
	{[_merged, _x] Call WFBE_CO_FNC_ArrayPush} forEach _vehRosters; //--- vehicles unchanged, appended

	_contents = _merged;
};

_contents