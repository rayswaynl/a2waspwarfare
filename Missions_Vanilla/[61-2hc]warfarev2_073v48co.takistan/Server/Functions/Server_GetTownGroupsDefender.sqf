/*
	Return a list of groups to spawn in a town (defender / resistance).
	 Parameters:
		- Town Entity.
		- Side.
*/

Private ["_aa_get","_get","_groups","_infantry","_infantry_aux","_infantry_primary","_kind","_maxgroups","_ratio_inf","_ratio_inf_aux","_ratio_veh","_ratio_veh_aux","_side","_remove","_sv","_town","_types","_vehicles","_vehicles_aux","_vehicles_primary"];

_town = _this select 0;
_side = _this select 1;
_aa_get = if (count _this > 2) then {_this select 2} else {false};

_sv = _town getVariable ["supplyValue", 0];
_town_airactive = _town getVariable ["wfbe_active_air", false];

_units = [];
_percentage_inf = 50;
_groups_max = 0;
_randomize = 0;

//--- Get the defender teams depending on the town type.
switch (_town getVariable "wfbe_town_type") do { // _units = [[group type, force (chance multiplier), group kind (0 inf, 1 veh)]]
	case "TinyTown1": {
		_units = [["Squad", 1, 0], ["Team", 1, 0],["Squad_Advanced", 1, 0],["Team_MG", 1, 0]];
		_percentage_inf = 100;
		_groups_max = 3;
	};
	case "SmallTown1": {
		_units = [["Squad", 1, 0],["Team", 1, 0],["Squad_Advanced", 1, 0], ["Team", 1, 0],["Team_AT", 1, 0],["AA_Light", 1, 1],["Motorized", 1, 1],["Mechanized", 1, 1]];
		_percentage_inf = 80;
		_groups_max = 5;
	};
	case "SmallTown2": {
		_units = [["Squad_Advanced", 1, 0],["Team", 1, 0],["Team_MG", 1, 0],["Team_AT", 2, 0],["Motorized", 1, 1],["AA_Light", 1, 1],["Armored_Light", 1, 1]];
		_percentage_inf = 80;
		_groups_max = 5;
	};
	case "MediumTown1": {
		_units = [["Team", 3, 0],["Team_Sniper", 1, 0],["Team_MG", 1, 0],["Team_AT", 1, 0],["Motorized", 1, 1],["Mechanized", 1, 1],["AA_Light", 1, 1],["Mechanized_Heavy", 2, 1],["Armored_Light", 1, 1]];
		_percentage_inf = 80;
		_groups_max = 6;
	};
	case "MediumTown2": {
		_units = [["Team", 3, 0],["Team_Sniper", 1, 0],["Team_MG", 1, 0],["Team_AT", 1, 0],["Motorized", 1, 1],["Mechanized", 2, 1],["AA_Light", 1, 1],["Mechanized_Heavy", 1, 1],["Armored_Light", 1, 1]];
		_percentage_inf = 80;
		_groups_max = 6;
	};
	case "LargeTown1": {
		//--- cmdcon35 (role-diversity): shifted 1 weight off bland Team (2->1) onto specialist Team_AT (1->2).
		//--- Net infantry weight is unchanged, so _groups_max stays 7; the LARGE garrison just skews toward AT.
		_units = [["Squad", 1, 0],["Team", 1, 0],["Team_Sniper", 1, 0],["Team_MG", 1, 0],["Squad_Contractor", 1, 0],["AA_Light", 2, 1],["Team_AT", 2, 0],["Mechanized_Heavy", 2, 1],["Armored_Light", 2, 1],["Armored_Heavy", 1, 1]];
		_percentage_inf = 75;
		_groups_max = 7;
	};
	case "LargeTown2": {
		_units = [["Squad_Advanced", 1, 0],["Team", 2, 0],["Team_Sniper", 1, 0],["Team_MG", 1, 0],["Squad_Contractor", 1, 0],["AA_Light", 2, 1],["Team_AT", 2, 0],["Mechanized_Heavy", 1, 1],["Armored_Light", 1, 1],["Armored_Heavy", 2, 1]];
		_percentage_inf = 75;
		_groups_max = 7;
	};
	case "HugeTown1": {
		_units = [["Squad", 3, 0],["Team", 2, 0],["Squad_Advanced",2, 0],["Team_Sniper", 1, 0],["Team_MG", 1, 0],["Squad_Contractor", 1, 0],["AA_Heavy", 2, 0],["Team_AT", 2, 0],["Mechanized_Heavy", 1, 1],["Armored_Light", 2, 1],["Armored_Heavy", 2, 1]];
		_percentage_inf = 75;
		_groups_max = 8;
	};
	case "HugeTown2": {
		//--- cmdcon35 (role-diversity): shifted 1 weight off bland Team (3->2) onto the elite Squad_Contractor (1->2).
		//--- Net infantry weight is unchanged, so _groups_max stays 8; the HUGE garrison just skews toward the PMC squad.
		_units = [["Squad", 2, 0],["Team", 2, 0],["Squad_Advanced",2, 0],["Team_Sniper", 1, 0],["Team_MG", 1, 0],["Squad_Contractor", 2, 0],["AA_Heavy", 2, 0],["Team_AT", 2, 0],["Mechanized_Heavy", 1, 1],["Armored_Light", 2, 1],["Armored_Heavy", 2, 1]];
		_percentage_inf = 75;
		_groups_max = 8;
	};
	case "PMCAirfield": { //--- Airfield capture point: mid-game defended objective with PMC garrison
		_units = [["Squad", 1, 0],["Team", 1, 0],["Team_AT", 1, 0],["Team_Sniper", 1, 0],["Motorized", 2, 1],["AA_Light", 1, 1]];
		_percentage_inf = 70;
		_groups_max = 6;
	};
	default { //--- If nothing is set...
		_units = [["Squad", 1, 0], ["Team", 1, 0],["Team_AT", 1, 0],["Motorized", 1, 1]];
		_percentage_inf = 80;
		_groups_max = 3;
	};
};

if (_randomize != 0) then {_groups_max = _groups_max + round(random _randomize - random _randomize)};
//--- B74.2: re-derive the defender unit coef from the LIVE pop-tier instead of the static
//--- WFBE_C_TOWNS_UNITS_DEFENDER_COEF (which was computed once at init from WFBE_C_TOWNS_DEFENDER).
//--- WFBE_C_TOWNS_DEFENDER_BY_TIER is the tiered version of that same difficulty knob, so scaling the
//--- coef per tier shrinks garrisons under load (FULL) and keeps them full at LOW. This builder is the
//--- town-DEFENDER pool only (called solely when _side==WFBE_DEFENDER in server_town_ai.sqf); the WEST/EAST
//--- AI-commander town pushes go through Server_GetTownGroups.sqf and are untouched.
private "_defCoef"; _defCoef = missionNamespace getVariable "WFBE_C_TOWNS_UNITS_DEFENDER_COEF"; //--- fallback: the static init-time coef
private "_defByTier"; _defByTier = missionNamespace getVariable "WFBE_C_TOWNS_DEFENDER_BY_TIER";
if (!isNil "_defByTier") then {
	private "_pt"; _pt = missionNamespace getVariable ["WFBE_PopTier", 0]; if (_pt < 0) then {_pt = 0};
	if (_pt <= ((count _defByTier) - 1)) then {
		private "_diff"; _diff = _defByTier select _pt;
		_defCoef = switch (_diff) do {case 1: {1}; case 2: {1.5}; case 3: {2}; case 4: {2.5}; default {1}};
	};
};
_groups_max = round(_groups_max * _defCoef);

//--- Tier-1 (flag WFBE_C_GDIR_GARRISON_GAIN, default 0): a GUER town the Director judges REINFORCED
//--- (ledger current/baseline ratio > 1, published as wfbe_gdir_str) wakes with a bigger real garrison.
//--- Additive / no-nerf: the bonus is >= 0, so _groups_max is never reduced below the V1 count.
private ["_gdirGain"];
_gdirGain = missionNamespace getVariable ["WFBE_C_GDIR_GARRISON_GAIN", 0];
if (_gdirGain > 0 && {(missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0}) then {
	private ["_gdRatio","_gdBonus"];
	_gdRatio = _town getVariable ["wfbe_gdir_str", 1];
	if (_gdRatio > 1) then {
		_gdBonus = (round (_groups_max * (_gdRatio - 1) * _gdirGain)) min _groups_max;
		if (_gdBonus > 0) then {_groups_max = _groups_max + _gdBonus};
	};
};

//--- EXPERIMENT (fable/ctl-garrison-link): connect the DEFENDER garrison to the CTL ledger strength,
//--- mirroring the attacker materialization in Server_GetTownGroups.sqf. Flag-off (AICOMV2_CTL_GARRISON_LINK=0
//--- OR AICOMV2_LANE_CMD_TOWN_LEDGER=0) => this block is skipped, byte-identical to HEAD. wfbe_ctl_str defaults
//--- to 1 for non-CTL (GUER/neutral) towns, so those stay at their V1 count even when armed; a WEST/EAST town
//--- garrisons in proportion to its ledger strength: fresh/depleted -> thin (floored at CTL_SPAWN_MIN_STR),
//--- invested/regenerated -> up toward CTL_PAID_MAX. A2-OA-1.64-legal (getVariable / round / plain arithmetic).
if ((missionNamespace getVariable ["AICOMV2_CTL_GARRISON_LINK", 0]) > 0 && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {
	private ["_ctlStr","_ctlEff","_ctlBase"];
	_ctlBase = _groups_max;
	_ctlStr  = _town getVariable ["wfbe_ctl_str", 1];
	_ctlEff  = _ctlStr max (missionNamespace getVariable ["AICOMV2_CTL_SPAWN_MIN_STR", 0.25]);
	_groups_max = round (_groups_max * _ctlEff);
	if (_groups_max < 1) then {_groups_max = 1};
	//--- BUDGET-CLAMP FIX (owner order 2026-07-17, round-2 bughunt item 3 / ledger-map CTL-W2 + improvement #3):
	//--- the attacker path (Server_GetTownGroups.sqf:152-165) clamps its CTL-scaled group count against the
	//--- owning side's live groupsGC budget cache before returning it; this defender-path CTL block applied the
	//--- SAME unbounded str multiplier with NO cap check at all - the only unclamped garrison multiplier in the
	//--- whole ledger system, and the mechanism a stale/inflated wfbe_ctl_str (see item 3's server_town.sqf fix)
	//--- could otherwise exploit without limit. Port the identical clamp, keyed off the town's ACTUAL current
	//--- owning side (not the WFBE_DEFENDER pseudo-side this function receives as _side) - the CTL budget model
	//--- is W/E-only (mirrors AICOMV2_CTL_GROUP_BUDGET_MAX's attacker-path scope), so a non-W/E owner (stale-bleed's
	//--- own failure mode, now closed separately) is left unclamped here by design, same as the attacker path.
	private ["_ctlBudgetMax","_ctlOwnerSID","_ctlOwnerSide","_ctlCacheVar","_ctlCached","_ctlFit"];
	_ctlBudgetMax = missionNamespace getVariable ["AICOMV2_CTL_GROUP_BUDGET_MAX", 120];
	_ctlOwnerSID  = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
	_ctlOwnerSide = (_ctlOwnerSID) Call WFBE_CO_FNC_GetSideFromID;
	_ctlCacheVar  = "";
	if (_ctlOwnerSide == west) then {_ctlCacheVar = "wfbe_grpcnt_west"};
	if (_ctlOwnerSide == east) then {_ctlCacheVar = "wfbe_grpcnt_east"};
	if (_ctlCacheVar != "") then {
		_ctlCached = missionNamespace getVariable [_ctlCacheVar, -1];
		if (_ctlCached >= 0 && {_ctlCached + _groups_max > _ctlBudgetMax}) then {
			_ctlFit = _ctlBudgetMax - _ctlCached;
			if (_ctlFit < 1) then {_ctlFit = 1};
			_groups_max = _ctlFit;
			diag_log Format ["CTLSTAT|v1|DEF|SPAWN|town=%1|str=%2|groups=%3|deny=groupBudgetExceeded", _town getVariable ["name", "?"], _ctlStr, _groups_max];
		};
	};
	if (_groups_max != _ctlBase) then {
		diag_log Format ["CTLSTAT|v1|DEF|GARRISON|town=%1|str=%2|groups=%3|base=%4", _town getVariable ["name", "?"], _ctlStr, _groups_max, _ctlBase];
	};
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

//--- GROUP-COUNT REDUCTION (claude-gaming 2026-06-13): spawn-time infantry consolidation (resistance/defender garrison).
//--- Each _contents element is a flat classname roster; CreateTeam (Common_CreateTeam.sqf:23/85)
//--- instantiates EVERY classname in one passed list into the ONE group. Fusing infantry rosters
//--- into fewer flat arrays => SAME units/classes in FEWER server group-brains (the ~2.1 units/group
//--- fragmentation drives the FPS cliff), IDENTICAL defenders a player sees & fights. Vehicle rosters
//--- (kind 1) are NEVER merged (preserves the CreateTeam addVehicle/crew path). Cap merged groups at 10
//--- classnames. WFBE_C_TOWNS_MERGE_TARGET <= 0 disables (instant rollback).
//--- GUER GROUP-CONDENSE (task #12): defender-specific target (9) > WEST/EAST (5). Fallback to global if unset/<=0.
_mergeTarget = missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_TARGET_DEFENDER", 0];
if (_mergeTarget <= 0) then {_mergeTarget = missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_TARGET", 5]};
private "_mergeCap"; _mergeCap = missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_CAP_DEFENDER", 10]; //--- GUER condense A/B: defender-specific merged-group size cap (12); falls back to the historical 10.
if (_mergeCap <= 0) then {_mergeTarget = 0}; //--- disabled cap must disable packing; never emit empty groups.
if (_mergeTarget > 0 && {count _contents > 1}) then {
	_infRosters = [];
	_vehRosters = [];
	_ci = 0;
	{
		if ((_contentsKind select _ci) == 0) then {[_infRosters, _x] Call WFBE_CO_FNC_ArrayPush} else {[_vehRosters, _x] Call WFBE_CO_FNC_ArrayPush};
		_ci = _ci + 1;
	} forEach _contents;

	//--- PACKED-SEGMENTS: selected infantry rosters are condensed without adding AI. Preserve
	//--- the source roster's forced-first spawn contract by retaining each roster fragment as a
	//--- segment; Common_CreateTownUnits creates all segments in one shared engine group.
	//--- Vehicle rosters remain atomic because CreateTeam must keep its vehicle/crew path intact.
	private ["_forceFirst", "_packedCount", "_packedSegments", "_segment", "_segmentCount", "_segmentIndex", "_segmentStart"];
	if (_mergeTarget > _mergeCap) then {_mergeTarget = _mergeCap};
	_merged = [];
	_packedSegments = [];
	_packedCount = 0;
	{
		_roster = _x;
		_segmentStart = 0;
		_forceFirst = true;
		while {_segmentStart < count _roster} do {
			_segmentCount = (_mergeTarget - _packedCount) min ((count _roster) - _segmentStart);
			_segment = [];
			for '_segmentIndex' from _segmentStart to ((_segmentStart + _segmentCount) - 1) do {[_segment, _roster select _segmentIndex] Call WFBE_CO_FNC_ArrayPush};
			[_packedSegments, [_segment, _forceFirst]] Call WFBE_CO_FNC_ArrayPush;
			_packedCount = _packedCount + _segmentCount;
			_segmentStart = _segmentStart + _segmentCount;
			_forceFirst = false;
			if (_packedCount >= _mergeTarget) then {[_merged, [_packedSegments, "WFBE_TOWN_PACKED_SEGMENTS"]] Call WFBE_CO_FNC_ArrayPush; _packedSegments = []; _packedCount = 0};
		};
	} forEach _infRosters;
	if (_packedCount > 0) then {[_merged, [_packedSegments, "WFBE_TOWN_PACKED_SEGMENTS"]] Call WFBE_CO_FNC_ArrayPush};
	{[_merged, _x] Call WFBE_CO_FNC_ArrayPush} forEach _vehRosters; //--- vehicles unchanged, appended

	_contents = _merged;
};

_contents
