/*
	RequestForwardFOB.sqf - SERVER PVF: build a Forward FOB from a WEST/EAST repair truck (OWNER CORRECTION
	2026-07-17: v1 wrongly built it from the supply truck; corrected to the repair truck before ship).
	  Flag WFBE_C_STRUCTURES_FOB. Owner rulings 2026-07-17; spec FORWARD-FOB-SPEC-20260717.md.

	Sent by Client\Action\Action_BuildForwardFOB.sqf. AUTHORITATIVE: re-validates the per-side alive cap, the
	base-area placement gate and the player's cash (the client pre-checks the same three for instant feedback
	and is spoofable), charges server-side through the WFBE_CO_FNC_ChangeTeamFunds choke-point, then spawns
	the FOB - a LocationLogicCamp + the per-side tent (WFBE_%1FARP) as its wfbe_camp_bunker + the mast.

	WHY a real LocationLogicCamp: it is what buys three of the four v1 effects with no new plumbing.
	Common\Functions\Common_GetRespawnCamps.sqf (forward respawn, incl. the 50m hostile safe-radius) and
	Client\Functions\Client_GetClosestCamp.sqf (gear resupply, via updateavailableactions.fsm) both discover
	camps with `nearEntities [WFBE_Logic_Camp, r]` + sideID + alive(wfbe_camp_bunker) - a type-keyed lookup,
	so a stand-in object (the Init_NavalHVT.sqf:1251 HeliHEmpty trick) would NOT be found by them.

	Runtime-creating the logic is safe by precedent, not by assumption: LocationLogicCamp and
	LocationLogicStart share the LocationLogic parent (CfgVehicles: 12029 / 12077) and this tree already
	createUnit's LocationLogicStart into a sideLogic group at runtime (Construction_SmallSite.sqf:38).
	It is NOT engine-probe-verified that nearEntities returns a runtime-created logic, so the build
	SELF-CHECKS it below and screams into the RPT rather than failing silently.

	A2 OA 1.64 safe: array-form private only, no params/pushBack/isEqualType, 1-arg getVariable on the side
	logic + group wallet (GROUPGETVAR trap), lazy && {} short-circuit, no exitWith inside forEach.

	_this = [pos, dir, truck, player]
*/
private ["_secHardening","_pos","_dir","_truck","_player","_side","_sideKey","_cost","_cap","_reject","_logik","_areas","_near","_minRange","_grp","_logic","_tentCls","_tent","_antenna","_aPos","_reg","_live","_funds","_group","_town","_probeOk"];

_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_FOB", 0]) <= 0) exitWith {};

if (_secHardening && {!((typeName _this) in ["ARRAY"])}) exitWith {
	["WARNING", Format ["RequestForwardFOB.sqf: malformed payload type [%1] - rejected.", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((count _this) > 3)}) exitWith {
	["WARNING", Format ["RequestForwardFOB.sqf: short payload [%1] - rejected.", _this]] Call WFBE_CO_FNC_LogContent;
};

_pos    = _this select 0;
_dir    = _this select 1;
_truck  = _this select 2;
_player = _this select 3;

if (_secHardening && {!((typeName _player) in ["OBJECT"]) || {isNull _player} || {!isPlayer _player} || {!alive _player}}) exitWith {
	["WARNING", Format ["RequestForwardFOB.sqf: caller [%1] is not a live player - rejected.", _player]] Call WFBE_CO_FNC_LogContent;
};

_side = side group _player;
if !(_side in [west, east]) exitWith {
	["WARNING", Format ["RequestForwardFOB.sqf: caller side [%1] is not WEST/EAST - rejected.", str _side]] Call WFBE_CO_FNC_LogContent;
};

_sideKey = Format ["WFBE_FOB_%1", str _side];
_cost    = missionNamespace getVariable ["WFBE_C_FOB_COST", 25000];
_cap     = missionNamespace getVariable ["WFBE_C_FOB_CAP_PER_SIDE", 2];
_group   = group _player;
_reject  = false;

//--- (1) authoritative cap - count only FOBs whose tent is still alive.
_reg  = missionNamespace getVariable [_sideKey, []];
_live = [];
{if (!isNull _x && {alive _x}) then {_live = _live + [_x]}} forEach _reg;
if ((count _live) >= _cap) then {
	_reject = true;
	["WARNING", Format ["RequestForwardFOB.sqf: [%1] already at the Forward FOB cap (%2) - rejected.", str _side, _cap]] Call WFBE_CO_FNC_LogContent;
};

//--- (2) authoritative placement (base-area gate; Construction_HQSite.sqf:43-49 idiom).
if (!_reject) then {
	_minRange = missionNamespace getVariable ["WFBE_C_FOB_MIN_RANGE", 370];
	_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
	_areas = _logik getVariable "wfbe_basearea";
	if (isNil "_areas") then {_areas = []};
	_near = [_pos, _areas] Call WFBE_CO_FNC_GetClosestEntity;
	if (!isNull _near && {(_near distance _pos) < _minRange}) then {
		_reject = true;
		["WARNING", Format ["RequestForwardFOB.sqf: [%1] placement %2m from a base area (min %3) - rejected.", str _side, round (_near distance _pos), _minRange]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- (3) authoritative funds. wfbe_funds on the group is the single funds choke-point
//--- (Common\Functions\Common_ChangeTeamFunds.sqf) - read it here, never trust a client number.
if (!_reject) then {
	_funds = _group getVariable "wfbe_funds";
	if (isNil "_funds" || {typeName _funds != "SCALAR"}) then {_funds = 0};
	if (_funds < _cost) then {
		_reject = true;
		["WARNING", Format ["RequestForwardFOB.sqf: [%1] insufficient funds ($%2 < $%3) - rejected.", str _side, _funds, _cost]] Call WFBE_CO_FNC_LogContent;
	};
};

if (!_reject) then {
	//--- Charge through the server-side choke-point (the same call Server_BuildingKilled.sqf credits with).
	[_group, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;

	//--- Per-side tent. Owner ruling 1 points at the already-declared forward-camp slot: WFBE_%1FARP is
	//--- 'Camp_EP1' (Structures_CO_US.sqf:19), 'CampEast_EP1' (Structures_CO_RU.sqf:19), 'Camp' (USMC).
	//--- It is set by every faction config but read by nothing else in the tree, so this is a pure read.
	_tentCls = missionNamespace getVariable [Format ["WFBE_%1FARP", str _side], ""];
	if (_tentCls == "") then {_tentCls = if (_side == east) then {"CampEast_EP1"} else {"Camp_EP1"}};

	//--- Camp logic (see the header note on the LocationLogicStart precedent + the self-check below).
	_grp   = createGroup sideLogic;
	_logic = _grp createUnit ["LocationLogicCamp", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
	_logic setPos [_pos select 0, _pos select 1, 0];

	_tent = createVehicle [_tentCls, [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
	_tent setDir _dir;
	_tent setPos [_pos select 0, _pos select 1, 0];

	//--- Survivability scaler. Camp_EP1 inherits armor=250 from Strategic; the town-camp models are 2500
	//--- (Land_Fort_Watchtower_EP1) / 20000 (WarfareBCamp), so an un-scaled tent would make a $25k capped
	//--- asset die to a rifle burst. Exact same divisor EH the town camps already use (Init_Town.sqf:137-140).
	_tent addEventHandler ["handleDamage", {getDammage (_this select 0) + ((_this select 2) / (missionNamespace getVariable ["WFBE_C_FOB_HEALTH_COEF", 10]))}];

	//--- Identity mast beside the tent (owner ruling 1). Land_Vysilac_FM is already live in this tree as the
	//--- Radio Tower model (Structures_CO_US.sqf:112) - base-A2 CAStructures, all-map safe.
	_aPos    = _tent modelToWorld [8, 0, 0];
	_antenna = createVehicle [(missionNamespace getVariable ["WFBE_C_FOB_ANTENNA", "Land_Vysilac_FM"]), [_aPos select 0, _aPos select 1, 0], [], 0, "NONE"];
	_antenna setPos [_aPos select 0, _aPos select 1, 0];

	//--- Camp contract (mirrors Init_Town.sqf:149-158). sideID + a living wfbe_camp_bunker are what every
	//--- consumer keys on. `town` is set + BROADCAST because Common_GetRespawnCamps.sqf case 3 dereferences
	//--- it unconditionally (:68-69) and runs client-side too: a nil there aborts the whole respawn sweep
	//--- for EVERY camp in range, not just this one.
	_town = [_pos] Call GetClosestLocation;
	_logic setVariable ["sideID", (_side) Call GetSideID, true];
	_logic setVariable ["supplyValue", 0, true];
	_logic setVariable ["wfbe_camp_bunker", _tent, true];
	_logic setVariable ["town", _town, true];
	_logic setVariable ["wfbe_fob", true, true];
	if (isNull _town) then {
		["WARNING", Format ["RequestForwardFOB.sqf: [%1] no closest location for the FOB camp - mode-3 respawn servers may skip it.", str _side]] Call WFBE_CO_FNC_LogContent;
	};

	_tent setVariable ["wfbe_side", _side, true];
	_tent setVariable ["wfbe_structure_type", "ForwardFOB", true];
	_tent setVariable ["wfbe_fob_logic", _logic];
	_tent setVariable ["wfbe_fob_antenna", _antenna];

	//--- Registry + broadcast count (the client action's cap mirror reads the _COUNT var).
	_reg = _live + [_tent];
	missionNamespace setVariable [_sideKey, _reg];
	missionNamespace setVariable [Format ["%1_COUNT", _sideKey], count _reg];
	publicVariable Format ["%1_COUNT", _sideKey];

	//--- The tent IS the FOB: every effect collapses off alive(wfbe_camp_bunker) the tick it dies.
	_tent addEventHandler ["killed", {_this Spawn WFBE_SE_FNC_ForwardFOBKilled}];

	//--- Per-FOB worker: hostile-proximity ping + vehicle repair bubble.
	[_logic, _tent, _antenna, _side] Spawn WFBE_SE_FNC_ForwardFOBWorker;

	//--- Keep the truck (OWNER CORRECTION 2026-07-17): the repair truck deploys the FOB and drives away,
	//--- it is not consumed - WFBE_C_FOB_CONSUME_TRUCK now defaults to 0. Left as a tunable in case a
	//--- future ruling wants the logistics-cost behaviour back (RequestFOBStructure.sqf:84 precedent).
	if ((missionNamespace getVariable ["WFBE_C_FOB_CONSUME_TRUCK", 0]) > 0 && {!isNull _truck}) then {deleteVehicle _truck};

	["INFORMATION", Format ["RequestForwardFOB.sqf: [%1] Forward FOB built at %2 (tent %3). Alive now %4/%5. Charged $%6.", str _side, _pos, _tentCls, count _reg, _cap, _cost]] Call WFBE_CO_FNC_LogContent;

	//--- SELF-CHECK, always-on. Forward respawn + gear resupply both depend on this runtime-created logic
	//--- being returned by `nearEntities [WFBE_Logic_Camp, r]`. That behaviour could not be settled on an
	//--- offline OA rig during this build, so assert it at the one moment it is cheap to observe: a FAILED
	//--- line here means the FOB is a $25k tent with no respawn/resupply and the flag must stay off.
	_probeOk = _logic in (_pos nearEntities [WFBE_Logic_Camp, 50]);
	if (_probeOk) then {
		["INFORMATION", Format ["RequestForwardFOB.sqf: FOBCAMPPROBE|ok|[%1] camp logic is discoverable by nearEntities - forward respawn + gear resupply are live.", str _side]] Call WFBE_CO_FNC_LogContent;
	} else {
		["WARNING", Format ["RequestForwardFOB.sqf: FOBCAMPPROBE|FAILED|[%1] the runtime LocationLogicCamp is NOT returned by nearEntities - forward respawn and gear resupply WILL NOT WORK. Keep WFBE_C_STRUCTURES_FOB at 0 until this is redesigned.", str _side]] Call WFBE_CO_FNC_LogContent;
	};
};
