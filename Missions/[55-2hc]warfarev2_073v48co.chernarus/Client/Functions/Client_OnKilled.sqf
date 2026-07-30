/*
	Triggered whenever the player dies.

	Parameters:
		_this select 0: dead player body
		_this select 1: killer
*/

Private ["_body","_deathText","_killer","_killerName","_killerVehicle","_killerVehicleName","_wfMenuAction","_sideTag","_dist","_distStr","_weapon","_weaponName","_extra","_isTeamKill"];

_body = _this select 0;
_killer = objNull;
_deathText = "Killed by unknown cause.";

if (count _this > 1) then {
	_killer = _this select 1;
};

if !((typeName _killer) in ["OBJECT"]) then {
	_killer = objNull;
};

//--- Killed-by polish (Ray): killer name + side tag, weapon/vehicle, and distance on one line.
//--- All lookups guard nil/empty; null killer keeps the existing "unknown cause" fallback.
if !(isNull _killer) then {
	if (_killer == _body) then {
		//--- Suicide / self-inflicted (e.g. own explosive): no attacker to name.
		_deathText = "You died.";
	} else {
		//--- Side tag, e.g. [EAST]. Guarded so a civilian-side killer still renders cleanly.
		_sideTag = switch (str (side _killer)) do {
			case "WEST": {"[WEST] "};
			case "EAST": {"[EAST] "};
			case "GUER": {"[GUER] "};
			default {""};
		};

		//--- Team-kill flag: killer on the same side as the victim.
		_isTeamKill = (side _killer == side _body);

		//--- Distance victim<->killer at time of death, rounded to whole metres.
		_dist = round (_body distance _killer);
		_distStr = Format ["%1m", _dist];

		//--- Killer label: player name, else the AI unit class display name.
		if (isPlayer _killer) then {
			_killerName = name _killer;
		} else {
			_killerName = [typeOf _killer, "displayName"] Call GetConfigInfo;
		};
		if (isNil "_killerName") then {_killerName = ""};
		if (count (toArray _killerName) < 1) then {_killerName = "someone"};

		//--- Weapon vs vehicle: if the killer is mounted, credit the vehicle; else the current weapon.
		_killerVehicle = vehicle _killer;
		if (isNull _killerVehicle) then {_killerVehicle = _killer};
		_extra = "";
		if (_killerVehicle != _killer) then {
			_killerVehicleName = [typeOf _killerVehicle, "displayName"] Call GetConfigInfo;
			if (isNil "_killerVehicleName") then {_killerVehicleName = ""};
			if (count (toArray _killerVehicleName) < 1) then {_killerVehicleName = typeOf _killerVehicle};
			if (count (toArray _killerVehicleName) > 0) then {_extra = _killerVehicleName};
		} else {
			_weapon = currentWeapon _killer;
			if (isNil "_weapon") then {_weapon = ""};
			if (count (toArray _weapon) > 0) then {
				_weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
				if (count (toArray _weaponName) > 0) then {_extra = _weaponName};
			};
		};

		//--- Assemble: "Killed by [EAST] SniperGuy (M24, 320m)"; drop the weapon token if unknown.
		if (count (toArray _extra) > 0) then {
			_deathText = Format ["Killed by %1%2 (%3, %4)", _sideTag, _killerName, _extra, _distStr];
		} else {
			_deathText = Format ["Killed by %1%2 (%3)", _sideTag, _killerName, _distStr];
		};

		if (_isTeamKill) then {_deathText = Format ["[TEAMKILL] %1", _deathText]};
	};
};

//--- EH are flushed on unit death, still, just make sure.
if (!isNil "WFBE_PLAYERKEH") then {player removeEventHandler ["killed", WFBE_PLAYERKEH]};

WFBE_Client_IsRespawning = true;

//--- TEAMBAR probe (wasp-squad-renumber-on-death-20260724): the BEFORE snapshot of the
//--- death/respawn cycle - the corpse still holds its pre-death roster id; correlate with the
//--- rejoin-check / ensure-done / deadunit-eject lines after the waitUntil to name the exact
//--- renumber transition in the RPT.
["respawn", "death"] Call WFBE_CL_FNC_TeambarProbe;


// ==================================================
// Remove old action menu entries from the dead body.
// ==================================================
// The actions were attached to the old player unit.
// At this point, _body is the safest reference to that old unit.

{_body removeAction _x} forEach [0,1,2,3,4,5];

if !(isNil "HQAction") then {
	_body removeAction HQAction;
};

// Marty: Remove the WF menu from the dead body using the ID stored on that body.
// This avoids reusing a stale global Options ID on the next player unit.
_wfMenuAction = _body getVariable ["WFBE_WFMenu_Action", -1];
if (_wfMenuAction >= 0) then {_body removeAction _wfMenuAction};
_body setVariable ["WFBE_WFMenu_Action", -1, false];
Options = Nil;

if !(isNil "Player_AI_Diagnose_Action") then {
	_body removeAction Player_AI_Diagnose_Action;
	Player_AI_Diagnose_Action = nil;
};

if !(isNil "Player_AI_Recover_Action") then {
	_body removeAction Player_AI_Recover_Action;
	Player_AI_Recover_Action = nil;
};


//--- Close any existing dialogs.
if (dialog) then {
	closeDialog 0;
};

WFBE_DeathLocation = getPos _body;


//--- Fade transition.
titleCut ["", "BLACK OUT", 1];

private ["_respawnWaitT0"]; _respawnWaitT0 = time;
//--- SCHEDULER-LEAK: sleep + 10 min bound if respawn never restores alive player.
waitUntil {sleep 0.2; alive player || {(time - _respawnWaitT0) > 600}};

//--- fable/onkilled-team-resync (owner report "units kept renumbering themselves after I die",
//--- correctness fix): resync WFBE_Client_Team to the player's POST-RESPAWN group BEFORE the
//--- leader-reassert and TEAMBAR slot-1 guards below evaluate it. GROUP respawn (respawn=3) can
//--- seat the player in a different group object than the one WFBE_Client_Team was last pointed
//--- at (Init_Client.sqf / a prior sync), so without this the guards below compare against a STALE
//--- pre-death reference and silently skip both the selectLeader reassert and the slot-1 rejoin,
//--- leaving the roster in whatever order the engine produced (PR #1323's 61s heartbeat then
//--- self-heals it, which is why the symptom is intermittent rather than permanent). Mirrors the
//--- identical resync SkinSelector_Apply.sqf:392 and Client_OnRespawnHandler.sqf:26 already perform.
if (!isNull (group player)) then {WFBE_Client_Team = group player};


//--- Update the player.
["RequestSpecial", ["update-teamleader", WFBE_Client_Team, player]] Call WFBE_CO_FNC_SendToServer;


//--- Make sure that player is always the leader of his group.
if (group player == WFBE_Client_Team) then {
	if (leader (group player) != player) then {
		(group player) selectLeader player;
	};
};

//--- TEAMBAR-FIRST (fable/player-teambar-slot): re-assert COLONEL after respawn so the command bar
//--- resorts correctly even though the engine creates a new unit on respawn.
if ((missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0) then {
	player setRank "COLONEL";
	diag_log "[WFBE|TEAMBAR] Client_OnKilled: player rank set to COLONEL for command-bar slot 1.";
	//--- wasp-squad-renumber-on-death-20260724 (player report 07-24 (777) "units kept renumbering
	//--- themselves after I die"): rank sets the star sort but A2 command-bar SLOT numbers follow
	//--- sticky roster ids - the engine seats the respawned body at the roster TAIL while the
	//--- corpse still holds id 1 (ejected ~1s later by the dead-units watchdog, compacting every
	//--- subordinate one slot up). The old inline "rejoin the AI" dance never moved the player, so
	//--- the whole bar stayed shifted after every death. Route through the shared stable-reorder
	//--- primitive (Client_TeambarEnsureSlot1.sqf): it re-seats the PLAYER at the lowest free id,
	//--- then re-joins the local AI in WFBE_TB_Roster order (stable across respawn). The legacy
	//--- rejoin-* phase names are preserved by mapping the primitive reason code; the primitive
	//--- also emits its own ensure-* phases with evt=respawn.
		["respawn", "rejoin-check"] Call WFBE_CL_FNC_TeambarProbe; //--- TEAMBAR probe: every guard input the line below evaluates
		if (group player == WFBE_Client_Team && {leader (group player) == player} && {((units group player) select 0) != player}) then {
			Private ["_slot1Result"];
			_slot1Result = ["respawn"] Call WFBE_CL_FNC_TeambarEnsureSlot1;
			if (_slot1Result == "done") then {
				//--- legacy log marker "slot1-rejoin" kept for RPT grep continuity (pinned by test_skinswap_slot1_rejoin.py);
				//--- the squadmate count is on the primitive's own ensure-slot1 (respawn) line.
				diag_log "[WFBE|TEAMBAR] slot1-rejoin (respawn): stable reorder completed - player re-seated at slot 1, AI order stable.";
				["respawn", "rejoin-done"] Call WFBE_CL_FNC_TeambarProbe;
			};
			if (_slot1Result == "creategroup-null") then {["respawn", "rejoin-creategroup-null"] Call WFBE_CL_FNC_TeambarProbe};
			if (_slot1Result == "no-local-others") then {["respawn", "rejoin-no-local-others"] Call WFBE_CL_FNC_TeambarProbe};
		};
	};

titleCut ["", "BLACK IN", 1];
titleText [_deathText, "PLAIN DOWN", 5];


//--- Re-add the killed event handler to the new player unit.
//--- DEDUPE (idle-bughunt 20260722; mirrors the SkinSelector_Apply.sqf Killed dedupe): a GROUP
//--- respawn can hand this client a reused squad-AI body that still carries the client-local
//--- WFBE_CO_FNC_CreateUnit 'Killed' EH from its buy (Common_CreateUnit.sqf) - re-adding below
//--- without clearing fires OnUnitKilled TWICE per death (double kill credit/payout). The only
//--- client-local 'Killed' EHs on the player body are that one and ours, so removeAll is safe.
player removeAllEventHandlers "Killed";
WFBE_PLAYERKEH = player addEventHandler [
	"Killed",
	{
		[_this select 0, _this select 1] Spawn WFBE_CL_FNC_OnKilled;
		[_this select 0, _this select 1, sideID] Spawn WFBE_CO_FNC_OnUnitKilled;
	}
];


//--- Card #210: AnimChanged event handlers are flushed when the old unit dies, so re-attach the
//--- auto-bipod-deploy handler to the fresh player unit. Guarded so it is a no-op if the bipod
//--- script has not finished loading yet.
if (!isNil "Bipod_AddAutoDeploy") then {[] call Bipod_AddAutoDeploy};


//--- Call the pre respawn routine.
// This will also re-add the player action menu entries.
(player) Call PreRespawnHandler;


//--- Camera & post-process thread.
[] Spawn {
	Private ["_delay"];

	_delay = missionNamespace getVariable "WFBE_C_RESPAWN_DELAY";

	"dynamicBlur" ppEffectEnable true;
	"dynamicBlur" ppEffectAdjust [1];
	"dynamicBlur" ppEffectCommit _delay / 3;

	"colorCorrections" ppEffectAdjust [
		1,
		1,
		0,
		[0.1, 0.0, 0.0, 1],
		[1.0, 0.5, 0.5, 0.1],
		[0.199, 0.587, 0.114, 0.0]
	];

	"colorCorrections" ppEffectCommit 0.1;
	"colorCorrections" ppEffectEnable true;

	"colorCorrections" ppEffectAdjust [
		1,
		1,
		0,
		[0.1, 0.0, 0.0, 0.5],
		[1.0, 0.5, 0.5, 0.1],
		[0.199, 0.587, 0.114, 0.0]
	];

	"colorCorrections" ppEffectCommit _delay / 3;

	//--- Spectator owns the view while active; tear it down before the death camera is created.
	if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false]) then {
		[] Call WFBE_CL_FNC_SpectatorExit;
	};

	//--- Guard: bail if the death position is invalid or camCreate failed to bind (prevents per-frame "Undefined variable wfbe_deathcamera" spam in the waitUntil below).
	if (isNil "WFBE_DeathLocation" || {typeName WFBE_DeathLocation != "ARRAY"} || {count WFBE_DeathLocation < 3}) exitWith {
		"dynamicBlur" ppEffectEnable false;
		"colorCorrections" ppEffectEnable false;
	};

	WFBE_DeathCamera = "camera" camCreate WFBE_DeathLocation;
	//--- camCreate always assigns; failure is a null object, not an undefined var. isNil never fired.
	if (isNull WFBE_DeathCamera) exitWith {
		WFBE_DeathCamera = nil;
		"dynamicBlur" ppEffectEnable false;
		"colorCorrections" ppEffectEnable false;
	};
	WFBE_DeathCamera camSetDir 0;
	WFBE_DeathCamera camSetFov 0.7;
	WFBE_DeathCamera cameraEffect ["Internal", "TOP"];

	WFBE_DeathCamera camSetTarget WFBE_DeathLocation;
	WFBE_DeathCamera camSetPos [
		WFBE_DeathLocation select 0,
		(WFBE_DeathLocation select 1) + 2,
		5
	];

	WFBE_DeathCamera camCommit 0;

	waitUntil {
		camCommitted WFBE_DeathCamera
	};

	WFBE_DeathCamera camSetPos [
		WFBE_DeathLocation select 0,
		(WFBE_DeathLocation select 1) + 2,
		30
	];

	WFBE_DeathCamera camCommit (_delay + 2);
};

sleep random 1;


//--- Create a respawn menu.
createDialog "WFBE_RespawnMenu";
