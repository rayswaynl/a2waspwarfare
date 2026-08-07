/*
	AI Commander - HELI SLING-LIFT (w807-L8, owner-requested 2026-08-07: "helicopter or plane
	lifting of vehicle" - owner wants to SEE AI airlifting vehicles). Server-side. Parameter: _this = side.

	Dedicated AICOM support call (CargoAirdrop-sibling pattern): buys ONE side-appropriate
	transport helicopter (Zeta_Lifter roster - Client\Module\ZetaCargo\Zeta_Init.sqf - the SAME
	lift-capable hulls the player Airlift upgrade already slings from: MH60S/UH60M_EP1/
	UH60M_MEV_EP1/CH_47F_EP1/CH_47F_BAF/BAF_Merlin_HC3_D for WEST, Mi17_Ins/Mi17_medevac_RU/
	Mi17_TK_EP1/Mi17_Civilian for EAST) plus ONE fresh armed light ground vehicle (never unarmed
	utility, owner doctrine), slings the vehicle below the heli (attachTo [0,0,-7] - the SAME
	offset Common_AICOMAirLeg.sqf's live WFBE_C_AICOM_VEHLIFT organic-team sling already proved
	clears every MH60/UH60/CH47/Mi17 hull's rotor/skid geometry), and flies it to a safe LZ near
	the side's current assault target town. The landed hull is then crewed (CargoAirdrop Stage B
	mount-on-landing idiom) and folds into normal AICOM tasking via the same wfbe_side_id stamp
	every WFBE_CO_FNC_CreateVehicle hull already carries.

	NOTE for reviewers: this is a DELIBERATE, cost/cooldown-gated, periodic "watch the AI airlift a
	vehicle" support call - distinct from, and complementary to, the ALREADY-LIVE organic sling
	Common_AICOMAirLeg.sqf performs on an AICOM team's OWN transport during an ordered leg (flag
	WFBE_C_AICOM_VEHLIFT, default ON: deep-drops a team's spare vehicle 1-2km BEHIND enemy lines for
	a flanking maneuver). That path only fires when a team already has BOTH its own transport heli AND
	a spare tiered ground vehicle mid-order; this worker fires independently off the AICOM tick, so the
	spectacle is visible even when no team happens to meet those conditions.

	Executor: Server\Support\Support_HeliLift.sqf (KAT_HeliLift).
*/

private ["_side","_logik","_sideID","_now","_cool","_last","_humanCmd","_cmdTeam","_sideText",
	"_factoryNames","_factoryTypes","_factoryIdx","_factoryClass","_structures","_hasAirFactory",
	"_upgrades","_liftLvl","_targets","_target","_objName",
	"_airMax","_airAlive","_airSideOK",
	"_active","_maxConcurrent",
	"_baseLogikPos","_basePos","_baseDist","_minDist",
	"_heliCandidates","_heliRoster","_heliClass",
	"_vehCandidates","_vehRoster","_vehClass",
	"_funds","_cost","_grp"];

_side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM_HELILIFT_ENABLE", 1]) <= 0) exitWith {};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik" || {isNull _logik}) exitWith {};
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_now = time;

//--- AI-RUN gate: the AI never spends a human commander's treasury. Mirrors CargoAirdrop's gate.
_humanCmd = false;
_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
if (!isNull _cmdTeam) then {if (isPlayer (leader _cmdTeam)) then {_humanCmd = true}};
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {_humanCmd = false};
if (_humanCmd) exitWith {};

//--- Per-side cooldown is stamped before debit/spawn, so a long flight cannot double-fire.
_cool = missionNamespace getVariable ["WFBE_C_AICOM_HELILIFT_COOLDOWN", 1500];
_last = _logik getVariable "wfbe_aicom_helilift_last";
if (isNil "_last") then {_last = -1e9};
if ((_now - _last) < _cool) exitWith {};

//--- Concurrency gate: at most WFBE_C_AICOM_HELILIFT_MAX_CONCURRENT lifts in flight per side at once.
_maxConcurrent = missionNamespace getVariable ["WFBE_C_AICOM_HELILIFT_MAX_CONCURRENT", 1];
_active = _logik getVariable "wfbe_aicom_helilift_active";
if (isNil "_active") then {_active = 0};
if (_maxConcurrent > 0 && {_active >= _maxConcurrent}) exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|concurrent-cap|active=" + str _active + "|cap=" + str _maxConcurrent);
};

//--- Tier gate: the SAME WFBE_UP_AIRLIFT research level that unlocks the player's Zeta_Hook sling-load action (Init_Unit.sqf).
_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
if (isNil "_upgrades" || {typeName _upgrades != "ARRAY"} || {count _upgrades <= WFBE_UP_AIRLIFT}) exitWith {};
_liftLvl = _upgrades select WFBE_UP_AIRLIFT;
if (_liftLvl <= 0) exitWith {};

//--- Factory gate: require one live Aircraft structure, using the existing AICOM air-factory idiom (mirrors CargoAirdrop).
_factoryNames = missionNamespace getVariable [Format ["WFBE_%1STRUCTURENAMES", _sideText], []];
_factoryTypes = missionNamespace getVariable [Format ["WFBE_%1STRUCTURES", _sideText], []];
_factoryIdx = _factoryTypes find "Aircraft";
_hasAirFactory = false;
if (_factoryIdx >= 0 && {_factoryIdx < count _factoryNames}) then {
	_factoryClass = _factoryNames select _factoryIdx;
	_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;
	{if (typeOf _x == _factoryClass && {alive _x}) then {_hasAirFactory = true}} forEach _structures;
};
if (!_hasAirFactory) exitWith {};

//--- Target: the side's current assault target, naval-guarded to the FIRST NON-naval entry (PR #2199 pattern; flag WFBE_C_AICOM_NAVAL_AIR_ONLY).
_target = objNull;
_targets = _logik getVariable "wfbe_aicom_targets";
if (!isNil "_targets" && {typeName _targets == "ARRAY"}) then {
	{
		if (isNull _target && {!isNull _x} && {!((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) > 0 && {_x getVariable ["wfbe_is_naval_hvt", false]})}) then {
			_target = _x;
		};
	} forEach _targets;
};
if (isNull _target) exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|no-target");
};

//--- Distance gate: only worth the spectacle/cost for a genuinely distant assault (a near target is faster/cheaper by ground convoy).
_minDist = missionNamespace getVariable ["WFBE_C_AICOM_HELILIFT_MIN_DIST", 2000];
_baseLogikPos = _logik getVariable "wfbe_startpos";
_basePos = getPos _logik;
if (!isNil "_baseLogikPos") then {
	if (typeName _baseLogikPos == "OBJECT") then {
		if (!isNull _baseLogikPos) then {_basePos = getPos _baseLogikPos};
	} else {
		if (typeName _baseLogikPos == "ARRAY" && {count _baseLogikPos >= 2}) then {_basePos = [_baseLogikPos select 0, _baseLogikPos select 1, 0]};
	};
};
_baseDist = (getPos _target) distance _basePos;
if (_baseDist < _minDist) exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|too-close|dist=" + str (round _baseDist) + "|min=" + str _minDist);
};

//--- Shared air-budget reservation: the lift heli is ONE Air hull, same accounting idiom as CargoAirdrop.
_airMax = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_TOTAL", 3];
if ((time / 60) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_LATE_MINS", 45])) then {
	_airMax = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_LATE", _airMax];
};
_airAlive = 0;
{
	if (alive _x && {_x isKindOf "Air"}) then {
		_airSideOK = false;
		if ((count crew _x) > 0) then {
			if (side ((crew _x) select 0) == _side) then {_airSideOK = true};
		} else {
			if ((_x getVariable ["wfbe_side_id", -1]) == _sideID) then {_airSideOK = true};
		};
		if (_airSideOK) then {_airAlive = _airAlive + 1};
	};
} forEach vehicles;
if (_airMax > 0 && {_airAlive + 1 > _airMax}) exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|air-headroom|alive=" + str _airAlive + "|cap=" + str _airMax);
};

//--- Heli class: Zeta_Lifter roster (Client\Module\ZetaCargo\Zeta_Init.sqf - the same proven lift-capable
//--- hulls the player Airlift upgrade slings from), narrowed to Helicopter-kind entries only (never a
//--- plane/tiltrotor in v1 - C130J/C130J_US_EP1/MV22/An2_TK_EP1 excluded), intersected with this side's
//--- own registered aircraft roster so the pick is always side-safe/reachable (same idiom
//--- Support_CargoAirdrop.sqf uses for its Stage B escort-jet pick).
_heliCandidates = ["MH60S","UH60M_EP1","UH60M_MEV_EP1","CH_47F_EP1","CH_47F_BAF","BAF_Merlin_HC3_D","Mi17_Ins","Mi17_medevac_RU","Mi17_TK_EP1","Mi17_Civilian"];
_heliRoster = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
_heliClass = "";
{ if (_heliClass == "" && {_x in _heliRoster}) then {_heliClass = _x} } forEach _heliCandidates;
if (_heliClass == "") exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|no-heli-class");
};

//--- Vehicle class: armed light-vehicle candidates ONLY (owner doctrine: armed vehicles only, never
//--- unarmed utility), intersected with this side's own light-vehicle roster, then belt-and-braces
//--- confirmed armed via config (non-empty "weapons" array) so a roster edit can never silently
//--- smuggle an unarmed hull into the candidate pool.
_vehCandidates = ["HMMWV_M2","HMMWV_MK19_DES_EP1","HMMWV_TOW_DES_EP1","HMMWV_Avenger_DES_EP1","LAV25","UAZ_MG_INS","UAZ_AGS30_RU","UAZ_SPG9_INS","BRDM2_ATGM_INS","BRDM2_ATGM_TK_EP1","GAZ_Vodnik_HMG"];
_vehRoster = missionNamespace getVariable [Format ["WFBE_%1LIGHTUNITS", _sideText], []];
_vehClass = "";
{
	if (_vehClass == "" && {_x in _vehRoster} && {count (getArray (configFile >> "CfgVehicles" >> _x >> "weapons")) > 0}) then {_vehClass = _x};
} forEach _vehCandidates;
if (_vehClass == "") exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|no-vehicle-class");
};

//--- Server-side AICOM treasury gate. No yield occurs between this check, the stamp, debit, and dispatch.
_cost = missionNamespace getVariable ["WFBE_C_AICOM_HELILIFT_COST", 40000];
_funds = (_side) Call GetAICommanderFunds;
if (_funds < _cost) exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_SKIP|funds|have=" + str _funds + "|need=" + str _cost);
};
if (isNil "KAT_HeliLift") exitWith {};

_logik setVariable ["wfbe_aicom_helilift_last", _now];
_logik setVariable ["wfbe_aicom_helilift_active", _active + 1];
[_side, -_cost] Call ChangeAICommanderFunds;

_grp = [_side, "aicom_helilift"] Call WFBE_CO_FNC_CreateGroup;
if (isNull _grp) then {
	//--- A group-cap refusal is not a delivered call: refund the debit, release the cooldown reservation and the concurrency slot.
	[_side, _cost] Call ChangeAICommanderFunds;
	_logik setVariable ["wfbe_aicom_helilift_last", -1e9];
	_logik setVariable ["wfbe_aicom_helilift_active", _active];
	["WARNING", Format ["AI_Commander_HeliLift.sqf: [%1] heli-lift aborted because the crew group could not be created; funds refunded.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
} else {
	_objName = _target getVariable ["name", "?"];
	["INFORMATION", Format ["AI_Commander_HeliLift.sqf: [%1] heli-lift called to [%2] (heli %3, vehicle %4, cost %5, air %6/%7).", _sideText, _objName, _heliClass, _vehClass, _cost, _airAlive + 1, _airMax]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|HELILIFT_CALLED|" + _objName + "|heli=" + _heliClass + "|veh=" + _vehClass + "|cost=" + str _cost + "|air=" + str (_airAlive + 1) + "/" + str _airMax);
	["HeliLift", _side, _target, _grp, _heliClass, _vehClass, _cost] Spawn KAT_HeliLift;
};
