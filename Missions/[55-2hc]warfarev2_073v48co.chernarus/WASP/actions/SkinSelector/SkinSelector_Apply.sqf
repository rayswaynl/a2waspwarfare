/*
	SkinSelector_Apply.sqf
	Swaps the player unit to _chosenClass.
	Parameters: [_chosenClass]
	Preconditions:
	  - player is alive
	  - vehicle player == player  (infantry only)
	  - WFBE_C_SKIN_SELECTOR == 1
	Known limitation: vehicle Fired EHs (HandleAT / HandleRocketTraccer / blinking marker)
	  are attached to (vehicle player) at the time of swap. After the swap the new unit
	  is on foot, so the EHs are re-added on the new unit. If the player entered a vehicle
	  before the first skin swap the old vehicle would retain stale EH entries, but the
	  new unit's vehicle will get fresh EHs on entry from Init_PreRespawn / normal flow.
	  This is acceptable for a first-join swap since the player is at the temp spawn.

	A2 OA 1.64 createUnit note:
	  Array-form createUnit does NOT return the new unit in A2 (it was always nil).
	  We therefore use WFBE_CO_FNC_CreateUnit with _global=false so:
	    - The wrapper uses the same array-form internally but returns the unit reliably
	      via its own post-creation reference (Common_CreateUnit.sqf line 122: _unit).
	    - _global=false skips setVehicleInit/processInitCommands broadcast — the new
	      unit is a player body, not an AI; it needs no global Init_Unit run.
	  Group locality: if the player is subordinate to another group leader the existing
	  group is non-local (leader not local). WFBE_CO_FNC_CreateUnit detects this and
	  auto-falls back to a fresh local group (Common_CreateUnit.sqf lines 33-38).
	  We always pass a fresh createGroup so the player skin unit is never put into
	  a shared AI group regardless of squad state. After selectPlayer the original
	  group membership is restored via joinGroup.
*/

Private ["_chosenClass","_oldUnit","_oldGrp","_swapGrp","_pos","_dir",
         "_unitName","_unitRank","_unitFace","_unitSpeaker",
         "_gear","_newUnit","_wasLeader","_uid"];

_chosenClass = _this select 0;

diag_log format ["[WFBE (SKIN)] B1 Apply entry: class='%1' player='%2' alive=%3 onFoot=%4",
	_chosenClass, name player, alive player, (vehicle player == player)];

//--- Guard: infantry only.
if (!(vehicle player == player)) exitWith {
	hint "Skin swap is only available on foot.";
};

//--- Guard: class exists in config.
if (!(isClass (configFile >> "CfgVehicles" >> _chosenClass))) exitWith {
	diag_log format ["[WFBE (SKIN)] B1 ABORT: class '%1' not in CfgVehicles", _chosenClass];
	hint format ["Skin class %1 not found in config.", _chosenClass];
};

//--- Guard: must be alive AT EXECUTION time — the dialog loop's alive check can race
//--- a lethal hit; a swap on a corpse collides with the OnKilled respawn flow.
if (!(alive player)) exitWith {
	hint "Cannot swap skin while dead.";
};

_oldUnit = player;
_oldGrp  = group _oldUnit;

//--- Capture position / orientation.
_pos = getPosATL _oldUnit;
_dir = getDir _oldUnit;

//--- Capture identity.
_unitName    = name    _oldUnit;
_unitRank    = rank    _oldUnit;
//--- BUG-FIX 2026-06-14: 'face' & 'speaker' are Arma-3-only getters - in A2 OA they fail to parse here
//--- ("Missing ;" at line 67), so the whole identity block + skin apply never compiled (~9.7k errors/session,
//--- a real client-FPS sink). A2 OA cannot READ a unit's face/voice; skip them - the swapped unit keeps a
//--- default face/voice (name + rank are still copied below).

//--- Capture gear before the old unit is altered.
_gear = _oldUnit call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_CopyGear.sqf");

//--- Was this unit the group leader of the original group?
_wasLeader = (leader _oldGrp == _oldUnit);

//--- Create a fresh LOCAL group for the swap unit.
//--- Reason: if the player is subordinate, _oldGrp's leader is not local here;
//--- createUnit into a non-local group fails silently (A2 OA group-locality trap).
//--- A dedicated swap group is deleted after joinGroup restores squad membership.
_swapGrp = createGroup (side _oldUnit);

diag_log format ["[WFBE (SKIN)] B2 createUnit: class='%1' swapGrp=%2 pos=%3 swapGrpLocal=%4",
	_chosenClass, _swapGrp, _pos, local _oldUnit];

//--- WFBE_CO_FNC_CreateUnit: [class, group, pos, sideID, global, placement]
//--- Pass _global=false: skips setVehicleInit/Init_Unit broadcast — this is a
//--- player body, not an AI. The wrapper returns objNull (never nil) on failure.
_newUnit = [_chosenClass, _swapGrp, _pos, WFBE_Client_SideID, false, "NONE"] call WFBE_CO_FNC_CreateUnit;

//--- WFBE_CO_FNC_CreateUnit always returns objNull on failure (never nil in A2),
//--- so a plain isNull check is sufficient here. Keep the isNil belt for safety.
if (isNil "_newUnit") exitWith {
	diag_log format ["[WFBE (SKIN)] B2 ABORT: WFBE_CO_FNC_CreateUnit returned NIL for '%1' (unexpected)", _chosenClass];
	deleteGroup _swapGrp;
	hint "Skin swap failed (unit creation returned nil). Please try again.";
};
if (isNull _newUnit) exitWith {
	diag_log format ["[WFBE (SKIN)] B2 ABORT: WFBE_CO_FNC_CreateUnit returned objNull for '%1' (unit/group cap?)", _chosenClass];
	deleteGroup _swapGrp;
	hint "Skin swap failed (server unit limit). Please try again later.";
};

diag_log format ["[WFBE (SKIN)] B3 newUnit created: %1 class=%2 local=%3",
	_newUnit, typeOf _newUnit, local _newUnit];

_newUnit setPosATL _pos;
_newUnit setDir    _dir;

//--- Copy identity. A2-fix (2026-06-14): setName is Arma-3-only on units (Location-only in A2 OA) and
//--- threw on every skin apply - REMOVED. The player's NAME follows the player object across selectPlayer,
//--- so no setName is needed. Rank is still copied (setRank is A2-valid for units).
_newUnit setRank    _unitRank;
//--- (face/speaker/name NOT script-applied - A2 OA has no per-unit identity setters; name follows the player)

//--- Apply gear to new unit.
//--- ApplyGear calls removeAllWeapons first so NVGoggles / custom loadout from
//--- WFBE_CO_FNC_CreateUnit (EAST/dragon/MVD special cases) are wiped cleanly.
[_newUnit, _gear] call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_ApplyGear.sqf");

//--- Transfer AFK tracking vars before selectPlayer (they are per-unit locals).
_newUnit setVariable ["lastActionTime", time];
_newUnit setVariable ["lastPosition",   getPosATL _newUnit];

//--- Rejoin the original group BEFORE selectPlayer so the player transitions
//--- with the correct group context. If the original group is empty or gone
//--- (edge case: everyone left while selector was open) remain in _swapGrp.
if (!(isNull _oldGrp) && {!(isNull (leader _oldGrp)) || {count units _oldGrp > 0}}) then {
	_newUnit joinGroup _oldGrp;
} else {
	diag_log "[WFBE (SKIN)] B3 original group gone/empty — new unit stays in swapGrp";
};

//--- Switch player.
diag_log format ["[WFBE (SKIN)] B4 selectPlayer -> '%1' grp=%2 wasLeader=%3",
	_chosenClass, group _newUnit, _wasLeader];
selectPlayer _newUnit;

//--- Restore group leadership if the player led the original group.
if (_wasLeader) then {(group _newUnit) selectLeader _newUnit};

//--- swapGrp is now empty (new unit moved to _oldGrp above); clean it up.
if (count units _swapGrp == 0) then {deleteGroup _swapGrp};

//--- Delete old unit.
diag_log format ["[WFBE (SKIN)] B5 deleteVehicle old unit %1", _oldUnit];
deleteVehicle _oldUnit;

//--- Brief pause to let the engine settle before re-adding EHs.
sleep 0.5;

//--- Re-add Killed EH (mirrors Init_Client.sqf:771).
WFBE_PLAYERKEH = player addEventHandler ["Killed", {[_this select 0, _this select 1] Spawn WFBE_CL_FNC_OnKilled; [_this select 0, _this select 1, sideID] Spawn WFBE_CO_FNC_OnUnitKilled}];

//--- Re-add HandleDamage EH (uses global WFBE_CL_VAR_ReArmorCode set in Init_Client.sqf).
player addEventHandler ["HandleDamage", format ["_this Call %1", WFBE_CL_VAR_ReArmorCode]];

//--- Re-add vehicle Fired EHs on the new unit (it is on foot so vehicle player == player).
(vehicle player) addEventHandler ["Fired", {_this Spawn HandleAT}];
(vehicle player) addEventHandler ["Fired", {_this Spawn HandleRocketTraccer}];
if ((missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) == 1) then {
	(vehicle player) addEventHandler ["Fired", {
		_u = _this select 0;
		_u Call WFBE_CL_FNC_SetMapIconStatusInCombat;
	}];
};

//--- Restore WF menu action and skill perks.
player Call WFBE_CL_FNC_AddWFMenuAction;
player Call WFBE_SK_FNC_Apply;
player Call WFBE_CL_FNC_AddPlayerAIActions;
[] execVM "WASP\actions\AddActions.sqf";
player setVariable ["wfbe_player_class", WFBE_SK_V_Type, true];

//--- Re-add the User11 KeyDown EH — it lived on the old (deleted) unit.
player addEventHandler ["KeyDown", WF_SkinSelector_Hotkey];

//--- Restore commander HQ build action if applicable.
if (!(isNull commanderTeam)) then {
	if (commanderTeam == group player) then {
		Private ["_hq"];
		_hq = sideJoined Call WFBE_CO_FNC_GetSideHQ;
		HQAction = player addAction [localize "STR_WF_BuildMenu", "Client\Action\Action_Build.sqf", [_hq], 100, false, true, "", "hqInRange && canBuildWHQ && (_target == player)"];
	};
};

//--- Persist skin choice.
_uid = getPlayerUID player;
missionNamespace setVariable [("WFBE_SkinSelector_Skin_" + _uid), _chosenClass];
WFBE_SkinSelector_Applied = true;

diag_log format ["[WFBE (SKIN)] B6 COMPLETE: player='%1' class='%2' uid='%3'",
	name player, typeOf player, _uid];
hint format ["%1\nSkin applied.", _chosenClass];
