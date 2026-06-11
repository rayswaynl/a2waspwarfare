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
*/

Private ["_chosenClass","_oldUnit","_grp","_pos","_dir",
         "_unitName","_unitRank","_unitFace","_unitSpeaker",
         "_gear","_newUnit","_wasLeader","_uid"];

_chosenClass = _this select 0;

//--- Guard: infantry only.
if (!(vehicle player == player)) exitWith {
	hint "Skin swap is only available on foot.";
};

//--- Guard: class exists in config.
if (!(isClass (configFile >> "CfgVehicles" >> _chosenClass))) exitWith {
	hint format ["Skin class %1 not found in config.", _chosenClass];
};

//--- Guard: must be alive AT EXECUTION time — the dialog loop's alive check can race
//--- a lethal hit; a swap on a corpse collides with the OnKilled respawn flow.
if (!(alive player)) exitWith {
	hint "Cannot swap skin while dead.";
};

_oldUnit = player;
_grp     = group _oldUnit;

//--- Capture position / orientation.
_pos = getPosATL _oldUnit;
_dir = getDir _oldUnit;

//--- Capture identity.
_unitName    = name    _oldUnit;
_unitRank    = rank    _oldUnit;
_unitFace    = face    _oldUnit;
_unitSpeaker = speaker _oldUnit;

//--- Capture gear.
_gear = _oldUnit call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_CopyGear.sqf");

//--- Was this unit the group leader?
_wasLeader = (leader _grp == _oldUnit);

//--- Create new unit in the same group at the same position.
_newUnit = _grp createUnit [_chosenClass, _pos, [], 0, "NONE"];

//--- Guard: createUnit can fail (group/unit caps) and return objNull.
//--- selectPlayer objNull would permanently softlock this client — abort cleanly instead.
if (isNull _newUnit) exitWith {
	diag_log format ["[WFBE (SKIN)] createUnit FAILED for '%1' (unit/group cap?) - swap aborted", _chosenClass];
	hint "Skin swap failed (server unit limit). Please try again later.";
};

_newUnit setPosATL _pos;
_newUnit setDir    _dir;

//--- Copy identity.
_newUnit setName    _unitName;
_newUnit setRank    _unitRank;
_newUnit setFace    _unitFace;
_newUnit setSpeaker _unitSpeaker;

//--- Apply gear to new unit.
[_newUnit, _gear] call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_ApplyGear.sqf");

//--- Transfer AFK tracking vars before selectPlayer (they are per-unit locals).
_newUnit setVariable ["lastActionTime", time];
_newUnit setVariable ["lastPosition",   getPosATL _newUnit];

//--- Switch player.
selectPlayer _newUnit;

//--- Restore group leadership.
if (_wasLeader) then {_grp selectLeader _newUnit};

//--- Delete old unit.
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

hint format ["%1\nSkin applied.", _chosenClass];
