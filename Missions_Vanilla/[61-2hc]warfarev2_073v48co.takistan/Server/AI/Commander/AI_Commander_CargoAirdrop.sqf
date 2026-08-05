/*
    AI Commander - CARGO AIRDROP Stage A.
    Server-side. Parameter: _this = side.

    One AI cargo plane carries the researched infantry stick and up to two empty
    side-configured para-vehicles. The vehicles use the shipping ParaVehicles
    attachTo/parachute mechanism, but detach on a three-second stagger so the
    two full-size payloads do not share one touchdown point. Stage B escort jets
    are deliberately not part of this worker.
*/

private ["_side","_logik","_sideID","_now","_cool","_last","_humanCmd","_cmdTeam","_upgrades","_paraLvl","_factoryNames","_factoryTypes","_factoryIdx","_factoryClass","_structures","_hasAirFactory","_target","_attacked","_atkTown","_targets","_reliefDist","_sideText","_airMax","_airAlive","_airSideOK","_funds","_cost","_grp","_objName","_escortEnable","_escortCost","_spawnEscort"];

_side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_ENABLE", 0]) <= 0) exitWith {};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik" || {isNull _logik}) exitWith {};
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_now = time;

//--- AI-RUN gate: the AI never spends a human commander's treasury. LOCK mirrors the existing Paratroops gate.
_humanCmd = false;
_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
if (!isNull _cmdTeam) then {if (isPlayer (leader _cmdTeam)) then {_humanCmd = true}};
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {_humanCmd = false};
if (_humanCmd) exitWith {};

//--- Per-side cooldown is stamped before debit/spawn, so a long flight cannot double-fire.
_cool = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_COOLDOWN", 1800];
_last = _logik getVariable "wfbe_aicom_cargo_last";
if (isNil "_last") then {_last = -1e9};
if ((_now - _last) < _cool) exitWith {};

//--- Infantry tier gate: the same researched Paratroopers unlock used by the player support entry.
_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
if (isNil "_upgrades" || {typeName _upgrades != "ARRAY"} || {count _upgrades <= WFBE_UP_PARATROOPERS}) exitWith {};
_paraLvl = _upgrades select WFBE_UP_PARATROOPERS;
if (_paraLvl <= 0) exitWith {};

//--- Factory gate: require one live Aircraft structure, using the existing AICOM air-factory idiom.
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

//--- Objective: reinforce a friendly town under live attack, otherwise the current offensive primary.
_target = objNull;
_attacked = [];
_reliefDist = missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500];
{
	_atkTown = _x;
	if ((_atkTown getVariable ["sideID", -1]) == _sideID && {_atkTown getVariable ["wfbe_active", false]}) then {
		if (({alive _x && {(side _x) != _side && {(side _x) != civilian}}} count ((getPos _atkTown) nearEntities [["Man","LandVehicle","Air"], _reliefDist])) > 0) then {
			_attacked = _attacked + [_atkTown];
		};
	};
} forEach towns;
if (count _attacked > 0) then {
	_target = _attacked select 0;
} else {
	_targets = _logik getVariable "wfbe_aicom_targets";
	if (!isNil "_targets" && {typeName _targets == "ARRAY"} && {count _targets > 0}) then {
		//--- NAVAL-HVT GUARD (adversarial review 2026-08-05, extends 5ee41de464): the never-idle fallbacks may
		//--- publish naval-HVT towns as LAST objectives - ground vehicle payloads dropped at an offshore deck
		//--- sink. First non-naval published target; WFBE_C_AICOM_NAVAL_AIR_ONLY 0 restores the old slot-0 read.
		private "_cadTgtStop"; _cadTgtStop = false;
		{
			if (!_cadTgtStop && {!((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) > 0 && {!isNull _x} && {_x getVariable ["wfbe_is_naval_hvt", false]})}) then {
				if (!isNull _x) then {_target = _x};
				_cadTgtStop = true;
			};
		} forEach _targets;
	};
};
if (isNull _target) exitWith {};

//--- Shared air-budget reservation. Stage A adds one Air hull (the cargo plane); vehicles are ground payloads.
//--- Match AI_Commander_Teams.sqf: count alive side-resolved Air hulls, including crewless wfbe_side_id-stamped hulls (r101: wfbe_side is never stamped on vehicle hulls).
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
			if ((_x getVariable ["wfbe_side_id", -1]) == ((_side) Call WFBE_CO_FNC_GetSideID)) then {_airSideOK = true};
		};
		if (_airSideOK) then {_airAlive = _airAlive + 1};
	};
} forEach vehicles;
if (_airMax > 0 && {_airAlive + 1 > _airMax}) exitWith {
	["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop skipped at shared air cap (alive %2, cap %3).", _sideText, _airAlive, _airMax]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|CARGO_AIRDROP_SKIP|air-headroom|alive=" + str _airAlive + "|cap=" + str _airMax);
};

//--- Stage B: an escort is a SECOND air hull for this call. Reserve room for cargo+escort together;
//--- if that doesn't fit but cargo ALONE still does (already proven true by the exitWith above), degrade
//--- to no-escort-this-call rather than skip the whole drop - the escort is a "should probably have",
//--- the delivery is the actual payload (design SS3.5).
_escortEnable = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_ENABLE", 0];
_spawnEscort = false;
if (_escortEnable > 0) then {
	if (_airMax <= 0 || {_airAlive + 2 <= _airMax}) then {
		_spawnEscort = true;
	} else {
		["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop escort dropped this call at shared air cap (alive %2, cap %3, needs 2).", _sideText, _airAlive, _airMax]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|CARGO_AIRDROP_ESCORT_SKIP|air-headroom|alive=" + str _airAlive + "|cap=" + str _airMax);
	};
};

//--- Server-side AICOM treasury gate. No yield occurs between this check, the stamp, debit, and dispatch.
_cost = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_COST", 60000];
_escortCost = missionNamespace getVariable ["WFBE_C_AICOM_CARGO_AIRDROP_ESCORT_COST", 35000];
_funds = (_side) Call GetAICommanderFunds;
if (_funds < _cost) exitWith {
	["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop skipped for funds (%2 < %3).", _sideText, _funds, _cost]] Call WFBE_CO_FNC_AICOMLog;
};
if (_spawnEscort) then {
	if (_funds >= (_cost + _escortCost)) then {
		_cost = _cost + _escortCost;
	} else {
		_spawnEscort = false;
		["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop escort dropped this call for funds (%2 < %3).", _sideText, _funds, _cost + _escortCost]] Call WFBE_CO_FNC_AICOMLog;
	};
};
if (isNil "KAT_CargoAirdrop") exitWith {};

_logik setVariable ["wfbe_aicom_cargo_last", _now];
[_side, -_cost] Call ChangeAICommanderFunds;

_grp = [_side, "aicom_cargo_airdrop"] Call WFBE_CO_FNC_CreateGroup;
if (isNull _grp) then {
	//--- A group-cap refusal is not a delivered call: refund the debit and release the cooldown reservation.
	[_side, _cost] Call ChangeAICommanderFunds;
	_logik setVariable ["wfbe_aicom_cargo_last", -1e9];
	["WARNING", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop aborted because the infantry group could not be created; funds refunded.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
} else {
	_objName = _target getVariable ["name", "?"];
	//--- Flag-off (no escort this call) keeps the EXACT Stage A log text; the extended escort/air
	//--- fields only appear on a call that actually spawns one, so a Stage-B-armed-but-escort-off
	//--- run stays byte-identical in its RPT/AICOMLog output as well as its gameplay effect.
	if (!_spawnEscort) then {
		["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop called to [%2] (para level %3, cost %4, air %5/%6).", _sideText, _objName, _paraLvl, _cost, _airAlive + 1, _airMax]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|CARGO_AIRDROP|" + _objName + "|para=" + str _paraLvl + "|cost=" + str _cost + "|air=" + str (_airAlive + 1) + "/" + str _airMax);
	} else {
		["INFORMATION", Format ["AI_Commander_CargoAirdrop.sqf: [%1] cargo drop called to [%2] (para level %3, cost %4, escort %5, air %6/%7).", _sideText, _objName, _paraLvl, _cost, _spawnEscort, _airAlive + 2, _airMax]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (_now / 60)) + "|CARGO_AIRDROP|" + _objName + "|para=" + str _paraLvl + "|cost=" + str _cost + "|escort=" + str _spawnEscort + "|air=" + str (_airAlive + 2) + "/" + str _airMax);
	};
	//--- r127: pass the exact debit (6th arg) so the worker refunds it and releases the cooldown
	//--- if the drop aborts during setup before any delivery (mirrors the group-null refund above).
	["CargoAirdrop", _side, getPos _target, _grp, _spawnEscort, _cost] Spawn KAT_CargoAirdrop;
};
