/* Description: Star Fortress Phase 1 (MVP) - staged construction watcher + PROGRAMMATIC composition.
   kimi/starfort-mvp, flag WFBE_C_STARFORT_ENABLE. Spawned by Server\PVFunctions\RequestStarFort.sqf
   after the 6-gate chain passes and Stage 1 (FOUNDATION) is charged.

   Geometry (spec B.2): the fort layout is computed in code around the keep. This is a first-pass
   FUNCTIONAL geometry, deliberately not hand-authored WDDM JSON (blind-authored JSON was called out
   as error-prone in the Phase-1 tasking; refine via the WDDM tool later). Diamond trace:
   WFBE_C_STARFORT_BASTIONS gun bastions on a ring of WFBE_C_STARFORT_RADIUS around the keep,
   Concrete_Wall_EP1 panels traced along each ring arc at the proven 2.2m overlap pitch (the HQ
   funnel pitch), a chicane+razorwire GATE segment on the arc facing _dir (the fort's front, toward
   the builder's own lines), and a Hedgehog/Fort_RazorWire apron on the remaining arcs. Wall panels
   are the FIRST line item trimmed when the computed layout would exceed WFBE_C_STARFORT_OBJ_CAP
   (hard ceiling WFBE_C_STARFORT_OBJ_CAP_HARD) - all counts stay runtime-tunable via the constants.

   Stages (spec B.5; completion source mirrors Construction_MediumSite.sqf: construction mode 0 =
   elapsed time over WFBE_C_STARFORT_BUILD_TIME, mode 1 = the site logic's WFBE_B_Completion; the
   watcher polls every 1s exactly like the existing file):
     Stage 1 FOUNDATION (charged at request accept): keep + dressing spawn, site commits - per-side
       registry set, keepalive flag published, permanent map marker placed, respawn privilege ON.
       The keep is deliberately the first thing built and the last thing standing: a rushed fort is
       spawn-functional immediately but fully exposed until walls/bastions land.
     Stage 2 WALLS (>= 33.33%): wall ring + apron, sub-batched with sleeps (no single-tick
       createVehicle spike - matches how the existing stages stagger), charged on crossing.
     Stage 3 BASTIONS (>= 66.66%): bastions staggered one per second + gate segment, charged on
       crossing. Bastion guns go through the stock ConstructDefense path (manned via the stock
       DefenseTeam/HandleDefense path wherever a base area covers the site; outside base areas the
       stock path cannot man - player-crewed until then, see PR notes).
   A commander who never funds a later stage keeps what is built (real curtain-wall fort with a live
   keep) - no new payment code path, no refunds. If the site logic or the keep dies mid-build:
   everything spawned is torn down and registry/flags/marker/pending are cleared (mirrors
   MediumSite's constructionLogicLost contract).

   WDDM pool (spec B.3): every child is stamped with the stock WFBE_WDDMPositionAnchor placement-ID
   (minted from the SAME WFBE_WDDMPlacementCounter Server_ConstructPosition.sqf uses) +
   WFBE_WDDMAnchorClass="StarFort" + WFBE_WDDMPositionChild (ConstructDefense arg) - the existing
   composition-cap accounting and the commander sell-exploit aggregate path see this composition
   verbatim. No parallel counter.
   GC note: pieces deliberately carry NO wfbe_trashable tag. server_collector_garbage.sqf reaps
   UNTAGGED dead objects via TrashObject; a tag would EXEMPT them (HQ/MHQ/Bank opt OUT with
   wfbe_trashable=false). Dead fort pieces flow into the standard reaper by design.

   Params: 0 - side, 1 - center position, 2 - orientation (gate faces this dir), 3 - requesting player.
*/
Private ["_side","_pos","_dir","_reqPlayer","_isWest","_mgCls","_atCls","_netCls","_wallCls","_wireCls",
         "_hEdgeCls","_chicCls","_bagCls","_keepCls","_nB","_radius","_objCap","_objHard","_buildTime",
         "_regKey","_pendKey","_aliveKey","_markerName","_markerColor","_placementID",
         "_arcSpan","_arcLen","_idealPanels","_fixedCount","_wallBudget","_panelsArc","_stepDeg",
         "_i","_j","_a","_midA","_keepPlan","_wallPlan","_bastPlan","_spawnPlan","_debit","_announce",
         "_group","_nearLogic","_modeTime","_logik","_spawned","_keep","_startTime","_stage","_completion",
         "_lost","_stalled","_cost","_supply","_costFoundation","_reqName","_breachKey"];

_side      = _this select 0;
_pos       = _this select 1;
_dir       = _this select 2;
_reqPlayer = if (count _this > 3) then {_this select 3} else {objNull};

//--- Per-side class lists (MIXEDPOS-style MG+AT gun points). Every class is already spawned by the
//--- existing WFBE_NEURODEF_* templates in Server\Init\Init_Defenses.sqf - zero new classnames.
_isWest = (_side == west);
_mgCls  = if (_isWest) then {"M2StaticMG"} else {"DSHKM_TK_INS_EP1"};
_atCls  = if (_isWest) then {"TOW_TriPod_US_EP1"} else {"Metis_TK_EP1"};
_netCls = if (_isWest) then {"Land_CamoNetVar_NATO"} else {"Land_CamoNetVar_EAST"};
_wallCls = "Concrete_Wall_EP1";
_wireCls = "Fort_RazorWire";
_hEdgeCls = "Hedgehog";
_chicCls = "Land_CncBlock_Stripes";        //--- proven gate chicane (Init_Defenses.sqf replaced the unverified Land_BarGate2 with it).
_bagCls  = "Land_fort_bagfence_round";
_keepCls = "Land_fortified_nest_big_EP1";  //--- the Bank compound class: HQ-style keep, destructible, ~16x16m.

_nB        = missionNamespace getVariable ["WFBE_C_STARFORT_BASTIONS", 4];
_radius    = missionNamespace getVariable ["WFBE_C_STARFORT_RADIUS", 25];
_objCap    = missionNamespace getVariable ["WFBE_C_STARFORT_OBJ_CAP", 55];
_objHard   = missionNamespace getVariable ["WFBE_C_STARFORT_OBJ_CAP_HARD", 60];
_buildTime = missionNamespace getVariable ["WFBE_C_STARFORT_BUILD_TIME", 300];
if (_buildTime < 1) then {_buildTime = 1};
_costFoundation = missionNamespace getVariable ["WFBE_C_STARFORT_COST_FOUNDATION", 6000];
_reqName = if (isNull _reqPlayer) then {"commander"} else {name _reqPlayer};

_regKey   = if (_isWest) then {"WFBE_STARFORT_WEST"} else {"WFBE_STARFORT_EAST"};
_pendKey  = _regKey + "_PENDING";
_aliveKey = if (_isWest) then {"wfbe_starfort_keepalive_west"} else {"wfbe_starfort_keepalive_east"};
_breachKey = if (_isWest) then {"wfbe_starfort_breached_west"} else {"wfbe_starfort_breached_east"};
_markerName  = Format ["wfbe_starfort_%1", if (_isWest) then {"west"} else {"east"}];
_markerColor = if (_isWest) then {"ColorBlue"} else {"ColorRed"};

//--- Shared WDDM placement-ID (SAME counter Server_ConstructPosition.sqf uses - no parallel counter).
if (isNil "WFBE_WDDMPlacementCounter") then { WFBE_WDDMPlacementCounter = 0 };
WFBE_WDDMPlacementCounter = WFBE_WDDMPlacementCounter + 1;
_placementID = format ["StarFort_%1", str WFBE_WDDMPlacementCounter];

//--- Plan entries: [classname, relAngleDeg, relDist, facingOffset, partTag, manned].
//--- World angle = _dir + relAngleDeg; facing = world angle + facingOffset; world pos = center +
//--- relDist * (sin,cos) of the world angle. Part tags: "keep" / "bastion" / "gate" are the
//--- alive-counted pieces (Common_StarFortStatus.sqf); "" pieces are dressing.

//--- KEEP plan (stage 1): the nest is the alive-tracked respawn core; the rest is dressing.
_keepPlan = [
	[_keepCls, 0, 0, 0, "keep", false],
	[_netCls, 0, 0, 0, "", false],
	[_bagCls, 120, 5, 30, "", false],
	[_bagCls, 240, 5, 330, "", false],
	[_wireCls, 0, 8, 0, "", false]
];

//--- Ring plan: bastion i sits at relative angle (180/_nB) + i*(360/_nB) (diamond trace); wall arc i
//--- is centered on relative angle i*(360/_nB); arc 0 faces _dir and carries the gate gap.
_arcSpan = 360 / _nB;
_arcLen = 2 * 3.14159 * _radius * (_arcSpan / 360);
_idealPanels = floor ((_arcLen - 12) / 2.2);   //--- 12m bastion clearance per arc (6m each end).
if (_idealPanels < 0) then {_idealPanels = 0};

//--- Fixed objects: keep(5) + bastions(4 x _nB) + gate(3) + apron(2 x (_nB-1)). Panels take what is
//--- left of the budget (spec: the wall ring is the first line item cut when the budget is tight).
_fixedCount = 5 + (4 * _nB) + 3 + (2 * (_nB - 1));
_wallBudget = _objCap - _fixedCount;
if (_wallBudget > (_objHard - _fixedCount)) then {_wallBudget = _objHard - _fixedCount};
_panelsArc = _idealPanels;
if (_panelsArc > (floor (_wallBudget / _nB))) then {_panelsArc = floor (_wallBudget / _nB)};
if (_panelsArc < 0) then {_panelsArc = 0};
_stepDeg = 2.2 / _radius * 57.2958;   //--- chord pitch -> arc degrees (the HQ 2.2m overlap pitch).

_wallPlan = [];
for "_i" from 0 to (_nB - 1) do {
	_midA = _i * _arcSpan;
	for "_j" from 0 to (_panelsArc - 1) do {
		_a = _midA + ((_j - ((_panelsArc - 1) / 2)) * _stepDeg);
		//--- The gate arc leaves +/-4 deg open around its midpoint for the gate segment.
		if ((_i != 0) || {(abs (_a - _midA)) > 4}) then {
			_wallPlan = _wallPlan + [[_wallCls, _a, _radius, 90, "", false]];
		};
	};
	if (_i != 0) then {
		//--- Apron on every non-gate arc: hedgehog out, razorwire in.
		_wallPlan = _wallPlan + [[_hEdgeCls, _midA, _radius + 9, 0, "", false]];
		_wallPlan = _wallPlan + [[_wireCls, _midA, _radius + 5, 90, "", false]];
	} else {
		//--- GATE segment (the deliberately-soft breach face): two chicane blocks + razorwire centre.
		_wallPlan = _wallPlan + [[_chicCls, _midA - 5, _radius, 90, "gate", false]];
		_wallPlan = _wallPlan + [[_chicCls, _midA + 5, _radius, 90, "gate", false]];
		_wallPlan = _wallPlan + [[_wireCls, _midA, _radius - 2.5, 90, "gate", false]];
	};
};

//--- Bastion plan (stage 3): AT main gun (the alive-counted "bastion" piece), MG, bagfence, camo net.
_bastPlan = [];
for "_i" from 0 to (_nB - 1) do {
	_a = (180 / _nB) + _i * _arcSpan;
	_bastPlan = _bastPlan + [
		[_atCls, _a, _radius, 0, "bastion", true],
		[_mgCls, _a + 8, _radius, 0, "", true],
		[_bagCls, _a, _radius + 3.5, 0, "", false],
		[_netCls, _a, _radius, 0, "", false]
	];
};

//--- Shared spawn worker: routes every child through the STOCK ConstructDefense (guns get the stock
//--- manning/artillery treatment where a base area covers the site; props get placed) and stamps the
//--- stock WDDM vars + the server-local part tag. _spawned/_keep live in the outer scope on purpose.
_spawned = [];
_keep = objNull;
_spawnPlan = {
	private ["_plan","_stagger","_e","_c","_ra","_rd","_fa","_pt","_m","_o","_wpos"];
	_plan = _this select 0;
	_stagger = _this select 1;
	{
		_e = _x;
		_c = _e select 0;
		_ra = _dir + (_e select 1);
		_rd = _e select 2;
		_fa = _ra + (_e select 3);
		_pt = _e select 4;
		_m = _e select 5;
		_wpos = [(_pos select 0) + _rd * (sin _ra), (_pos select 1) + _rd * (cos _ra), 0];
		_o = [_c, _side, _wpos, _fa, _m, false, missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE", false, true, _reqPlayer] Call ConstructDefense;
		if (!isNil "_o" && {typeName _o == "OBJECT"} && {!isNull _o}) then {
			_o setVariable ["WFBE_WDDMPositionAnchor", _placementID, true];
			_o setVariable ["WFBE_WDDMAnchorClass", "StarFort", true];
			if (_pt != "") then {_o setVariable ["wfbe_starfort_part", _pt]};  //--- server-local: read by the server-side status watcher only.
			_spawned = _spawned + [_o];
			if (_pt == "keep") then {_keep = _o};
		};
		sleep _stagger;
	} forEach _plan;
};

//--- Side-supply debit via the stock handler (direct call: publicVariableServer from server-side
//--- code never fires the server's own PVEH - repo trap list).
_debit = {
	private ["_amt","_why"];
	_amt = _this select 0;
	_why = _this select 1;
	[[Format ["wfbe_supply_temp_%1", str _side], [_side, _amt, _why]], _side] Call WFBE_SE_FNC_HandleSideSupplyChange;
};

//--- Side-scoped chat announce through the generic "Wildcard" LocalizeMessage case (display-ready
//--- text, no stringtable addition needed).
_announce = {
	[_side, "LocalizeMessage", ["Wildcard", _this]] Call WFBE_CO_FNC_SendToClients;
};

//--- Site logic (MediumSite contract). Mode 0 (Time, the lobby-locked default): the logic is just
//--- the destructible construction anchor; mode 1 adds the WFBE_B_* vars + structures_logic entry.
_group = createGroup sideLogic;
_nearLogic = objNull;
if !(isNull _group) then {_nearLogic = _group createUnit ["LocationLogicStart", _pos, [], 0, "NONE"]};
if (isNull _nearLogic) exitWith {
	if !(isNull _group) then {deleteGroup _group};
	missionNamespace setVariable [_pendKey, -1e11];
	[_costFoundation, "Star Fortress aborted: site logic missing (foundation refunded)."] Call _debit;
	diag_log Format ["CONSTRUCTION|v1|reject|reason=missing-start-logic|script=StarFortSite|pos=%1", _pos];
};
_nearLogic setPos _pos;
_modeTime = ((missionNamespace getVariable "WFBE_C_STRUCTURES_CONSTRUCTION_MODE") == 0);
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (!_modeTime) then {
	_nearLogic setVariable ["WFBE_B_Completion", 0];
	_nearLogic setVariable ["WFBE_B_CompletionRatio", 0.6];
	_nearLogic setVariable ["WFBE_B_Direction", _dir];
	_nearLogic setVariable ["WFBE_B_Position", _pos];
	_nearLogic setVariable ["WFBE_B_Repair", false];
	_nearLogic setVariable ["WFBE_B_Type", "StarFort"];
	_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") + [_nearLogic]];
};

//--- STAGE 1 - FOUNDATION: keep + dressing now (already charged at request accept).
[_keepPlan, 0.4] Call _spawnPlan;

if (isNull _keep) exitWith {
	{if !(isNull _x) then {deleteVehicle _x}} forEach _spawned;
	deleteVehicle _nearLogic;
	if !(isNull _group) then {deleteGroup _group};
	missionNamespace setVariable [_pendKey, -1e11];
	[_costFoundation, "Star Fortress aborted: keep could not be created (foundation refunded)."] Call _debit;
	diag_log Format ["CONSTRUCTION|v1|reject|reason=keep-create-failed|script=StarFortSite|pos=%1", _pos];
};

//--- Commit the site (spec B.5 Stage 1): registry + keepalive + permanent marker. Respawn turns ON.
missionNamespace setVariable [_regKey, _keep];
publicVariable _regKey;
missionNamespace setVariable [_aliveKey, true];
publicVariable _aliveKey;
missionNamespace setVariable [_pendKey, -1e11];
//--- Reset the latched breach flag for THIS fort (a razed predecessor leaves it true).
missionNamespace setVariable [_breachKey, false];
publicVariable _breachKey;
createMarker [_markerName, _pos];   //--- global on server: visible to all players AND JIP-durable.
_markerName setMarkerType "mil_warning";
_markerName setMarkerColor _markerColor;
_markerName setMarkerText "STAR FORTRESS";
"STAR FORTRESS foundation laid - the keep is live (respawn active). Walls and bastions await funding." Call _announce;
["INFORMATION", Format ["Construction_StarFortSite.sqf: [%1] keep spawned (%2 objects), site committed, marker [%3] placed (placement %4).", str _side, count _spawned, _markerName, _placementID]] Call WFBE_CO_FNC_LogContent;

//--- One completion watcher advances the staged site (MediumSite thresholds; sleep 1 poll).
_startTime = time;
_stage = 1;
_lost = false;
_stalled = false;
while {_stage < 4 && {!_lost} && {!WFBE_GameOver}} do {
	sleep 1;
	if (isNull _nearLogic || {isNull _keep} || {!alive _keep}) then {
		_lost = true;
	} else {
		if (_modeTime) then {
			_completion = ((time - _startTime) / _buildTime) * 100;
		} else {
			_completion = _nearLogic getVariable "WFBE_B_Completion";
		};
		if ((_stage == 1) && {_completion >= 33.33}) then {
			//--- STAGE 2 - WALLS: stall (do not advance) while the side cannot pay; retry each tick.
			_cost = missionNamespace getVariable ["WFBE_C_STARFORT_COST_WALLS", 15000];
			_supply = _side Call GetSideSupply;
			if (isNil "_supply") then {_supply = 0};
			if (_supply < _cost) then {
				if (!_stalled) then {
					_stalled = true;
					Format ["STAR FORTRESS stalled - walls need %1 supply (have %2).", _cost, _supply] Call _announce;
				};
			} else {
				[0 - _cost, "Star Fortress walls."] Call _debit;
				[_wallPlan, 0.25] Call _spawnPlan;
				_stage = 2;
				_stalled = false;
				"STAR FORTRESS walls complete - bastions await funding." Call _announce;
				["INFORMATION", Format ["Construction_StarFortSite.sqf: [%1] stage 2 (walls) done - %2 objects, %3 supply charged.", str _side, count _spawned, _cost]] Call WFBE_CO_FNC_LogContent;
			};
		} else {
			if ((_stage == 2) && {_completion >= 66.66}) then {
				//--- STAGE 3 - BASTIONS: same stall-until-funded contract.
				_cost = missionNamespace getVariable ["WFBE_C_STARFORT_COST_BASTIONS", 28000];
				_supply = _side Call GetSideSupply;
				if (isNil "_supply") then {_supply = 0};
				if (_supply < _cost) then {
					if (!_stalled) then {
						_stalled = true;
						Format ["STAR FORTRESS stalled - bastions need %1 supply (have %2).", _cost, _supply] Call _announce;
					};
				} else {
					[0 - _cost, "Star Fortress bastions."] Call _debit;
					[_bastPlan, 1] Call _spawnPlan;
					_stage = 3;
					_stalled = false;
					"STAR FORTRESS bastions armed - construction finishing." Call _announce;
					["INFORMATION", Format ["Construction_StarFortSite.sqf: [%1] stage 3 (bastions) done - %2 objects, %3 supply charged.", str _side, count _spawned, _cost]] Call WFBE_CO_FNC_LogContent;
				};
			} else {
				if ((_stage == 3) && {_completion >= 100}) then {_stage = 4};
			};
		};
	};
};

//--- Game ended mid-build (only reachable while stalled on funds): stop silently, keep the fort
//--- as-is for endgame scoring; the status watcher was never started.
if (WFBE_GameOver) exitWith {};

//--- Site logic or keep lost mid-build: tear everything down, release every claim (MediumSite's
//--- constructionLogicLost contract). Stage charges already paid are sunk (attacker's reward).
if (_lost) exitWith {
	{if !(isNull _x) then {deleteVehicle _x}} forEach _spawned;
	if (!isNull _nearLogic) then {deleteVehicle _nearLogic};
	if !(isNull _group) then {deleteGroup _group};
	if (!_modeTime) then {_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") - [_nearLogic]]};
	missionNamespace setVariable [_regKey, objNull];
	publicVariable _regKey;
	missionNamespace setVariable [_aliveKey, false];
	publicVariable _aliveKey;
	missionNamespace setVariable [_pendKey, -1e11];
	deleteMarker _markerName;
	"STAR FORTRESS construction was destroyed before completion." Call _announce;
	diag_log Format ["CONSTRUCTION|v1|reject|reason=construction-logic-destroyed|script=StarFortSite|pos=%1", _pos];
};

//--- Built: retire the site logic (MediumSite contract) and hand over to the alive/breach watcher.
if (!_modeTime) then {_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") - [_nearLogic]]};
_group = group _nearLogic;
deleteVehicle _nearLogic;
if !(isNull _group) then {deleteGroup _group};
"STAR FORTRESS complete." Call _announce;
["INFORMATION", Format ["Construction_StarFortSite.sqf: [%1] Star Fortress complete at %2 (%3 objects, placement %4).", str _side, _pos, count _spawned, _placementID]] Call WFBE_CO_FNC_LogContent;

//--- B.6: alive-tracking / breach signal / keepalive watcher starts now (gate + bastions exist).
[_side, _placementID, _keep, _pos, _radius] Spawn WFBE_CO_FNC_StarFortStatus;
