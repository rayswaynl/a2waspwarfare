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

_sv = _town getVariable ["supplyValue", 0];
_town_airactive = _town getVariable ["wfbe_active_air", false];

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

//--- Commander Town Ledger (fable/ctl-impl-v1) materialization overlay (B2). Flag-off
//--- (AICOMV2_LANE_CMD_TOWN_LEDGER=0) => this whole block is skipped, byte-identical to HEAD.
if ((_side == west || {_side == east}) && {!_aa_get} && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
	private ["_ctlStr","_ctlMinStr","_ctlEff","_ctlBudgetMax","_ctlLogik","_ctlCached"];
	_ctlStr      = _town getVariable ["wfbe_ctl_str", 1];
	_ctlMinStr   = missionNamespace getVariable ["AICOMV2_CTL_SPAWN_MIN_STR", 0.25];
	_ctlEff      = _ctlStr max _ctlMinStr;
	_groups_max  = round (_groups_max * _ctlEff);
	if (_groups_max < 1) then {_groups_max = 1};
	//--- B5: group-budget clamp using the existing 60s groupsGC cache (no new scans).
	_ctlBudgetMax = missionNamespace getVariable ["AICOMV2_CTL_GROUP_BUDGET_MAX", 120];
	_ctlCached    = if (_side == west) then {missionNamespace getVariable ["wfbe_grpcnt_west", -1]} else {missionNamespace getVariable ["wfbe_grpcnt_east", -1]};
	if (_ctlCached >= 0 && {_ctlCached + _groups_max > _ctlBudgetMax}) then {
		private ["_ctlFit"];
		_ctlFit = _ctlBudgetMax - _ctlCached;
		if (_ctlFit < 1) then {_ctlFit = 1};
		_groups_max = _ctlFit;
		_ctlLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		_ctlLogik setVariable ["WFBE_CTL_DENY_COUNT", (_ctlLogik getVariable ["WFBE_CTL_DENY_COUNT", 0]) + 1];
		diag_log Format ["CTLSTAT|v1|%1|SPAWN|town=%2|str=%3|groups=%4|deny=groupBudgetExceeded", str _side, _town getVariable ["name", "?"], _ctlStr, _groups_max];
	} else {
		diag_log Format ["CTLSTAT|v1|%1|SPAWN|town=%2|str=%3|groups=%4|deny=none", str _side, _town getVariable ["name", "?"], _ctlStr, _groups_max];
	};
	//--- lastSpawnUnits (ledger field [3]) is written further below, once the real per-unit
	//--- roster (_contents) exists - writing the GROUP count (_groups_max) here would make
	//--- field [3] dimensionally wrong for the per-UNIT survivor ratio read at deactivation
	//--- (fix: unit-vs-group dimension).
};


if (_aa_get) then {if (_groups_max > 3) then {_groups_max = 3}};

_unit_infantry = [];
_unit_vehicles = [];

{
	if (!isNil {missionNamespace getVariable Format ["WFBE_%1_GROUPS_%2",_side,_x select 0]}) then {
		_add = true;
		if (_aa_get) then {
			if !((_x select 0) in ["AA_Light","AA_Heavy","Team_AA"]) then {_add = false}
		} else {
			if (_town_airactive && (_x select 0) in ["AA_Light","AA_Heavy","Team_AA"]) then {_add = false}; //--- A2 (lane 800) re-enables air detection: wfbe_active_air IS now reachable when AICOMV2_LANE_GUER_DIRECTOR>0. This exclusion correctly strips AA from the ground garrison when the AA-only tier is already active (avoids double-spawn).
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

//--- B757 cross-faction vehicle sprinkle: rare, one vehicle per wave, no artillery.
//--- The shared planner remains side-owned; only the occasional hull crosses the roster boundary.
private ["_rareVehicle"];
if (!_aa_get && {(random 1) < 0.08}) then {
    _rareVehicle = switch (true) do {
        case (_side == west): {["BRDM2_TK_GUE_EP1"]};
        case (_side == east): {["HMMWV_M1151_M2_DES_EP1"]};
        case (_side == resistance): {if (worldName == "Chernarus") then {["Pickup_PK_GUE"]} else {["Pickup_PK_TK_GUE_EP1"]}};
        default {[]};
    };
    if (count _rareVehicle > 0) then {
        [_contents, _rareVehicle] Call WFBE_CO_FNC_ArrayPush;
        [_contentsKind, 1] Call WFBE_CO_FNC_ArrayPush;
    };
};

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

//--- Commander Town Ledger (fable/ctl-impl-v1) unit-count fix v2 (PR #886 review: crew
//--- undercounting). lastSpawnUnits (ledger field [3]) must be a REAL Man-unit count incl.
//--- vehicle crew (driver/gunner/commander) - matching the survivor tally basis
//--- (server_town_ai.sqf sums units of each _grp, which includes auto-crew). Counting
//--- _contents roster CLASSNAMES (the v1 fix above) undercounts every vehicle roster: one
//--- vehicle classname is one roster entry, but Common_CreateTeam.sqf spawns that hull PLUS
//--- up to 3 crew into the SAME group. No units exist yet at this point - Server_GetTownGroups.sqf
//--- is a pure roster PLANNER called before any group/unit is spawned - so the real count can
//--- only be known once Common_CreateTeam.sqf actually creates the groups. This block now only
//--- RESETS field [3] to 0 for this wave; the real, crew-inclusive count is ADDED once creation
//--- completes, at the two places the created group objects become known: server_town_ai.sqf
//--- (server-direct creation, synchronous) and Server_HandleSpecial.sqf update-town-delegation
//--- (client/HC-delegated creation, reported back once creation finishes remotely).
//--- Flag-off (AICOMV2_LANE_CMD_TOWN_LEDGER=0) => this whole block is skipped, byte-identical to HEAD.
if ((_side == west || {_side == east}) && {!_aa_get} && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
	//--- CTL single-writer (fable/ctl-readback-singlewriter): reset the per-town spawn
	//--- accumulator SCALAR instead of RMW-ing the shared WFBE_CTL_LEDGER array. The CTL tick
	//--- (Server_CmdTownLedger.sqf) is now the SOLE writer of the ledger array; external sites
	//--- publish per-town scalars it reads. Flag-off => skipped, byte-identical to HEAD.
	_town setVariable ["wfbe_ctl_lastspawn", 0];
};

_contents
