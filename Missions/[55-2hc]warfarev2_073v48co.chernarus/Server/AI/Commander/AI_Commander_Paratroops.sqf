/*
	AI Commander - PARATROOP REINFORCEMENT (claude-gaming 2026-06-29).
	Server-side. Parameter: _this = side.

	Purpose: let the AI commander call a PARATROOP drop to reinforce a friendly town that is under attack
	(or, failing that, push its current offensive target) - using the EXACT SAME support function a human
	player uses from the Tactical Center menu (KAT_Paratroopers == Server\Support\Support_Paratroopers.sqf).
	The drop spawns the side's transport plane/heli + a stick of the side's paratroop infantry at the side's
	current PARATROOPERS upgrade level, flies to the objective, and ejects the stick - reinforcing the front.

	HARD GATING (Ray, emphatic): the AI may use a capability ONLY once it has actually UNLOCKED it via the
	matching upgrade tier - exactly like a player. The Tactical Center menu's Paratroop entry is enabled iff
	(GetSideUpgrades select WFBE_UP_PARATROOPERS) > 0 (GUI_Menu_Tactical.sqf:278). We require the SAME thing,
	PLUS a live Tactical Center (CommandCenter) structure on the side - the structure you research that tier AT.
	No structure or no researched tier => no drop, ever (the worker early-exits).

	Gates (all must pass):
	  - WFBE_C_AICOM_PARATROOPS_ENABLE > 0 (the live constant default is 1; set 0 to disable).
	  - The AI actually COMMANDS this side now (no human commander, or LOCK on) - never spends a human's drop.
	  - TIER:      (side upgrades) select WFBE_UP_PARATROOPERS > 0   (the unlock the player path checks).
	  - STRUCTURE: at least one live CommandCenter (Tactical Center) of the side exists.
	  - COOLDOWN:  >= WFBE_C_AICOM_PARATROOPS_COOLDOWN since this side's last AI drop (per-side stamp).
	  - OBJECTIVE: a sensible friendly target exists (own town under live enemy attack, else offensive primary).
	Never drops on a random/unsupported spot: the objective is always a real friendly/target town centre.

	A2-OA-1.64 safe: typeName ==/!=, ==/!= on numbers/objects/sides, if/else, isNil, forEach, count; no
	isEqualType/isEqualTo/findIf/pushBack/selectRandom/hashMap/params; bool && {code} lazy-eval; group reads
	use plain getVariable + isNil (no 2-arg getVariable on a GROUP); 2-arg getVariable only on OBJECTS/namespaces.
*/

private ["_side","_logik","_sideID","_now","_cool","_last","_upgrades","_paraLvl","_structs","_ccType","_cc","_hasCC","_humanCmd","_cmdTeam","_attacked","_atkTown","_target","_targets","_grp","_objName"];

_side = _this;

//--- Feature flag: the live constant defaults to 1; set 0 to keep this capability inert.
if ((missionNamespace getVariable ["WFBE_C_AICOM_PARATROOPS_ENABLE", 0]) <= 0) exitWith {};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
if (isNull _logik) exitWith {};
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_now = time;

//--- AI-RUN gate: never call a drop while a human commands this side (rule A: the AI does not spend a human's
//--- support). LOCK forces AI command regardless of an occupied slot (mirrors AI_Commander.sqf:145).
_humanCmd = false;
_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
if (!isNull _cmdTeam) then { if (isPlayer (leader _cmdTeam)) then {_humanCmd = true} };
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {_humanCmd = false};
if (_humanCmd) exitWith {};

//--- COOLDOWN: per-side last-drop stamp on the side logic. Default cooldown falls back to the player support
//--- delay (WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY, 1200) so the AI is no spammier than a player by default.
_cool = missionNamespace getVariable ["WFBE_C_AICOM_PARATROOPS_COOLDOWN", (missionNamespace getVariable ["WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY", 1200])];
_last = _logik getVariable "wfbe_aicom_para_last";
if (isNil "_last") then {_last = -1e9};
if ((_now - _last) < _cool) exitWith {};

//--- TIER GATE (HARD): the side must have RESEARCHED the Paratroopers upgrade. This is the SAME check the
//--- player's Tactical Center menu uses to enable the Paratroop entry (GUI_Menu_Tactical.sqf:278). The AI
//--- commander researches PARATROOPERS via its AI_ORDER program, so this is reached organically mid/late game.
_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
if (isNil "_upgrades") exitWith {};
if (typeName _upgrades != "ARRAY") exitWith {};
if (count _upgrades <= WFBE_UP_PARATROOPERS) exitWith {};
_paraLvl = _upgrades select WFBE_UP_PARATROOPERS;
if (_paraLvl <= 0) exitWith {};

//--- STRUCTURE GATE: a live Tactical Center (CommandCenter) must exist for the side. The upgrade tree is
//--- researched AT the CommandCenter, so a researched tier already implies it was built - this is the
//--- belt-and-braces structure presence check the feature asks for (and survives a CC that is later lost).
_ccType = missionNamespace getVariable Format ["WFBE_%1COMMANDCENTERTYPE", str _side];
_hasCC = false;
if (!isNil "_ccType") then {
	_structs = (_side) Call WFBE_CO_FNC_GetSideStructures;
	_cc = [_side, _ccType, _structs] Call GetFactories; //--- returns alive structures of the CommandCenter type
	if (count _cc > 0) then {_hasCC = true};
};
if (!_hasCC) exitWith {};

//--- OBJECTIVE: pick a sensible friendly target - NEVER a random spot.
//--- 1) A friendly town under LIVE enemy attack (same detection the Strategy reactive-defense block uses:
//---    own + active + a live hostile within RELIEF_ENEMY_DIST). Reinforce the most-threatened front town.
//--- 2) Else the AI's current OFFENSIVE primary (wfbe_aicom_targets select 0) - drop ON the town it is taking.
_target = objNull;
_attacked = [];
{
	_atkTown = _x;
	if ((_atkTown getVariable ["sideID", -1]) == _sideID && {_atkTown getVariable ["wfbe_active", false]}) then {
		if (({alive _x && {(side _x) != _side && {(side _x) != civilian}}} count ((getPos _atkTown) nearEntities [["Man","LandVehicle","Air"], (missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500])])) > 0) then {
			_attacked = _attacked + [_atkTown];
		};
	};
} forEach towns;
if (count _attacked > 0) then {
	_target = _attacked select 0;
} else {
	_targets = _logik getVariable "wfbe_aicom_targets";
	if (!isNil "_targets" && {typeName _targets == "ARRAY"} && {count _targets > 0}) then {
		if (!isNull (_targets select 0)) then {_target = _targets select 0};
	};
};
if (isNull _target) exitWith {}; //--- nothing worth reinforcing this tick; try again next cooldown window.

_objName = _target getVariable ["name", "?"];

//--- Stamp the cooldown BEFORE the drop so a long in-flight drop can never double-fire on the next tick.
_logik setVariable ["wfbe_aicom_para_last", _now];

//--- Fire the drop through the SAME player-support function (now AI-aware). _playerTeam is a fresh, empty
//--- paradrop group on this side; Support_Paratroopers.sqf creates the stick INTO it and (because its leader
//--- is not a player) keeps only the 500s transit timeout and skips the client marker-send. CreateGroup tags
//--- the group server-side; the function flies it to the objective, ejects, then flies the transport home.
_grp = [_side, "aicom_paradrop"] Call WFBE_CO_FNC_CreateGroup;
["Paratroops", _side, getPos _target, _grp] Spawn KAT_Paratroopers;

["INFORMATION", Format ["AI_Commander_Paratroops.sqf: [%1] PARATROOP DROP called (lvl %2) to reinforce [%3] (%4).", str _side, _paraLvl, _objName, if (count _attacked > 0) then {"under attack"} else {"offensive target"}]] Call WFBE_CO_FNC_AICOMLog;
diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (_now / 60)) + "|PARATROOP_DROP|" + _objName + "|lvl" + str _paraLvl);
