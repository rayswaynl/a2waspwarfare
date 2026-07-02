/*
	SkinSelector_Apply.sqf
	Swaps the player unit to _chosenClass.
	Parameters: [_chosenClass]
	Preconditions:
	  - player is alive
	  - vehicle player == player  (infantry only)
	  - selector enabled (SkinSelector_Enabled.sqf: WFBE_C_SKINSEL default 1, or legacy WFBE_C_SKIN_SELECTOR)
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
         "_gear","_newUnit","_wasLeader","_uid","_waitStart","_verifyStart"];

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

//--- RE-ENTRY GUARD 2026-06-16: a concurrent apply (double-click) or a respawn-race
//--- second invocation would read this _oldUnit AFTER the first selectPlayer already
//--- swapped the body — a stale-handle double-apply that corrupts player state. Block
//--- it with a missionNamespace flag. The flag is set true here (no suspension between
//--- the _oldUnit capture above and this line, so the window is atomic on A2's
//--- cooperative scheduler) and reset false on EVERY exit path below so it never sticks.
if (!(isNil "WFBE_SkinSelector_InProgress") && {WFBE_SkinSelector_InProgress}) exitWith { diag_log "[WFBE (SKIN)] ABORT: concurrent apply blocked"; };
WFBE_SkinSelector_InProgress = true;

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
_swapGrp setVariable ["wfbe_group_src", "skin-swap", true]; //--- audit clarity: transient client-local swap group, deleted < 0.5s later. BROADCAST (3rd arg true) so the SERVER-side GROUPAUDIT/UNTAGLEAK actually sees the tag - a client-local setVariable would be invisible to the server's allGroups audit and the group would read as "untagged".

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
	WFBE_SkinSelector_InProgress = false; //--- release re-entry guard on early exit
	hint "Skin swap failed (unit creation returned nil). Please try again.";
};
if (isNull _newUnit) exitWith {
	diag_log format ["[WFBE (SKIN)] B2 ABORT: WFBE_CO_FNC_CreateUnit returned objNull for '%1' (unit/group cap?)", _chosenClass];
	deleteGroup _swapGrp;
	WFBE_SkinSelector_InProgress = false; //--- release re-entry guard on early exit
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

//--- cmdcon42 SELECTPLAYER HARDENING (Ray 2026-07-02): selectPlayer requires the target unit to be
//--- non-null AND LOCAL to this client, and to have finished initialising. The unit was just created
//--- into a fresh LOCAL swap group (swapGrpLocal true), so it is normally local immediately, but wait
//--- for it explicitly with a ~3s timeout so a slow-init frame never selects a half-built body.
//--- A2-OA-1.64 safe: waitUntil / isNull / local / time. (No && {} lazy operand: nested condition.)
_waitStart = time;
waitUntil {
	if (isNull _newUnit) exitWith {true};
	if (local _newUnit) exitWith {true};
	if (time - _waitStart > 3) exitWith {true};
	false
};

//--- Abort cleanly if the unit vanished or never became local — never selectPlayer a bad handle.
if (isNull _newUnit || !(local _newUnit)) exitWith {
	diag_log format ["[WFBE (SKIN)] B5_FAIL new unit not usable before selectPlayer (isNull=%1 local=%2) — cleaning up, player kept in old body", isNull _newUnit, local _newUnit];
	if (!isNull _newUnit) then {deleteVehicle _newUnit};
	if (!isNull _swapGrp) then {if (count units _swapGrp == 0) then {deleteGroup _swapGrp}};
	WFBE_SkinSelector_InProgress = false; //--- release re-entry guard on failure
	hint "Skin swap failed (unit not ready). Please try again.";
};

//--- Rejoin the original group BEFORE selectPlayer so the player transitions
//--- with the correct group context. If the original group is empty or gone
//--- (edge case: everyone left while selector was open) remain in _swapGrp.
//--- A2-OA fix: && {code} / || {code} lazy-eval operands are Arma-3-only syntax and
//--- produce "Missing ;" parse errors in A2 OA 1.64.  Use nested if instead.
//--- cmdcon42 A2-OA FIX: `joinGroup` is ALSO Arma-3-only and threw "Missing ;" at this line on
//--- EVERY swap (RPT-confirmed), collapsing this whole if/then block. A2 OA uses `[unit] join grp`
//--- (array LHS), matching Common_ChangeUnitGroup.sqf:11 / Server_OnPlayerDisconnected.sqf:105.
if (!(isNull _oldGrp)) then {
	if (!(isNull (leader _oldGrp)) || (count units _oldGrp > 0)) then {
		[_newUnit] join _oldGrp;
	} else {
		diag_log "[WFBE (SKIN)] B3 original group gone/empty — new unit stays in swapGrp";
	};
} else {
	diag_log "[WFBE (SKIN)] B3 original group gone/empty — new unit stays in swapGrp";
};

//--- Switch player.
diag_log format ["[WFBE (SKIN)] B4 selectPlayer -> '%1' grp=%2 wasLeader=%3",
	_chosenClass, group _newUnit, _wasLeader];
selectPlayer _newUnit;

//--- VERIFY the transfer actually took: player must BE the new unit within ~5s. In A2 MP a
//--- selectPlayer into a non-local group (or mid-JIP) can silently fail, leaving the player in the
//--- OLD body while the new unit stands idle. Confirm before we touch/delete anything.
_verifyStart = time;
waitUntil {
	if (player == _newUnit) exitWith {true};
	if (time - _verifyStart > 5) exitWith {true};
	false
};

if (!(player == _newUnit)) exitWith {
	diag_log format ["[WFBE (SKIN)] B5_FAIL selectPlayer did not transfer control (player=%1 newUnit=%2) — deleting spawned unit, restoring old body", player, _newUnit];
	//--- Undo the neutralisation-that-hasn't-happened-yet is N/A (old body untouched here). Just remove the
	//--- orphan skinned unit so no zombie soldier is left standing, and leave the player in the old body.
	if (!isNull _newUnit) then {deleteVehicle _newUnit};
	if (!isNull _swapGrp) then {if (count units _swapGrp == 0) then {deleteGroup _swapGrp}};
	WFBE_SkinSelector_InProgress = false; //--- release re-entry guard on failure
	hint "Skin swap failed (control did not transfer). You are still in your original body.";
};

//--- Restore group leadership if the player led the original group.
if (_wasLeader) then {(group _newUnit) selectLeader _newUnit};

//--- swapGrp is now empty (new unit moved to _oldGrp above); clean it up.
if (count units _swapGrp == 0) then {deleteGroup _swapGrp};

//--- DUPLICATE-SOLDIER FIX 2026-06-15:
//--- In A2/OA, selectPlayer does NOT destroy the previous body — _oldUnit becomes a
//--- LIVING AI unit standing where the player was. The previous code deleteVehicle'd
//--- it in the SAME frame as selectPlayer, before the engine finished detaching the
//--- player from _oldUnit; that delete is unreliable mid-transition, so the old body
//--- survived as the duplicate soldier next to the player. Fix:
//---   1) Immediately neutralise the old body so it can never be seen/acted-on during
//---      the settle window: hideObject (invisible), enableSimulation false (can't
//---      shoot/move and won't ragdoll or fire a Killed EH chain), disableAI (belt),
//---      and sink it far below ground so it is gone visually the instant we swap.
//---   2) Pause to let selectPlayer fully complete BEFORE deleting (settle moved to the
//---      correct side of the delete).
//---   3) deleteVehicle, then re-check and re-delete if the engine deferred the first
//---      delete — guarantees a single active body remains.
if (!isNull _oldUnit) then {
	_oldUnit hideObject true;
	_oldUnit enableSimulation false;
	{_oldUnit disableAI _x} forEach ["MOVE","ANIM","FSM","TARGET","AUTOTARGET"];
	_oldUnit setPosATL [(_pos select 0), (_pos select 1), -500]; //--- sink out of sight as a belt-and-braces measure
};

//--- Brief pause to let the engine settle the player transition BEFORE deleting.
sleep 0.5;

//--- Delete old unit (now safely detached from the player).
diag_log format ["[WFBE (SKIN)] B5 deleteVehicle old unit %1 (alive=%2)", _oldUnit, alive _oldUnit];
if (!isNull _oldUnit) then {deleteVehicle _oldUnit};

//--- Safety net: if the engine deferred the delete (A2/OA mid-transition quirk), the
//--- body can survive the first deleteVehicle. Re-check next frame and force-delete.
if (!isNull _oldUnit) then {
	[_oldUnit] spawn {
		Private ["_o"];
		_o = _this select 0;
		sleep 0.5;
		if (!isNull _o && {_o != player}) then {
			diag_log format ["[WFBE (SKIN)] B5b residual old body survived first delete — force deleteVehicle %1", _o];
			deleteVehicle _o;
		};
	};
};

//--- Re-add Killed EH (mirrors Init_Client.sqf:771).
//--- DEDUPE 2026-06-27: WFBE_CO_FNC_CreateUnit (-> Common_CreateUnit.sqf:125) already attaches a
//--- 'Killed' EH that spawns WFBE_CO_FNC_OnUnitKilled. Re-adding here without clearing first would
//--- fire OnUnitKilled TWICE on death (double kill credit/payout). Mirror the Fired-EH dedupe below:
//--- remove all 'Killed' EHs first, then re-add the single combined OnKilled + OnUnitKilled handler.
player removeAllEventHandlers "Killed";
WFBE_PLAYERKEH = player addEventHandler ["Killed", {[_this select 0, _this select 1] Spawn WFBE_CL_FNC_OnKilled; [_this select 0, _this select 1, sideID] Spawn WFBE_CO_FNC_OnUnitKilled}];

//--- Re-add HandleDamage EH (uses global WFBE_CL_VAR_ReArmorCode set in Init_Client.sqf).
player addEventHandler ["HandleDamage", format ["_this Call %1", WFBE_CL_VAR_ReArmorCode]];

//--- Re-add vehicle Fired EHs on the new unit (it is on foot so vehicle player == player).
//--- DEDUPE 2026-06-16: clear any existing Fired EHs first so repeated swaps do not
//--- stack HandleAT/HandleRocketTraccer/blink (after N swaps the unit fired N+1 instances
//--- per shot). The ONLY Fired EHs ever attached to the on-foot player are these three
//--- (Init_Client.sqf:34/37/302, Client_PreRespawnHandler.sqf:13) — no other system owns
//--- one — so removeAll is safe; the bomb/missile Fired EHs live on vehicles/AI via
//--- Init_Unit.sqf, which the _global=false swap unit deliberately skips.
player removeAllEventHandlers "Fired";
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

//--- cmdcon42 BUG-8 RESPAWN/ENROLLMENT RE-REGISTRATION (Ray 2026-07-02): the swap unit is created with
//--- WFBE_CO_FNC_CreateUnit _global=false, so Common\Init\Init_Unit.sqf NEVER runs on it, and the
//--- engine group-respawn (Header.hpp respawn=3) binds a player to BASE spawns through the enrollment
//--- GLOBALS + the group, NOT through per-unit slot state. Init_Client.sqf sets these once
//--- (sideJoined/WFBE_Client_SideJoined/sideID/WFBE_Client_SideID + clientTeam/WFBE_Client_Team = group
//--- player) and Client_OnKilled re-asserts leadership each death. After selectPlayer into a fresh body
//--- those team GLOBALS can point at the OLD (now-deleted) group object; when the swapped body later
//--- DIES the death chain then reads a stale team and the RespawnMenu's [sideJoined, WFBE_DeathLocation]
//--- Call GetRespawnAvailable produced NO base spawns (RPT: only deadspawn entries, then a stranded
//--- dead player). Re-point the team globals at the player's CURRENT group so the enrollment the respawn
//--- system reads is valid on the new body. sideJoined/sideID are SIDE-derived and unchanged by the swap
//--- (same side), so we leave them; we only fix the GROUP-bound handles. Idempotent, A2-OA-1.64 safe
//--- (isNull / group / plain global assignment - no A3-only commands).
if (!isNull (group player)) then {
	clientTeam = group player;
	WFBE_Client_Team = group player;
};

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
WFBE_SkinSelector_InProgress = false; //--- release re-entry guard on successful completion

diag_log format ["[WFBE (SKIN)] B6 COMPLETE: player='%1' class='%2' uid='%3'",
	name player, typeOf player, _uid];
hint format ["%1\nSkin applied.", _chosenClass];
