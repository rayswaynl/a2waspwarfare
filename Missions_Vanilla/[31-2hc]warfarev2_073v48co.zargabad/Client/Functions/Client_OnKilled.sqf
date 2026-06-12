/*
	Triggered whenever the player dies.

	Parameters:
		_this select 0: dead player body
		_this select 1: killer
*/

Private ["_body","_wfMenuAction"];

_body = _this select 0;

//--- EH are flushed on unit death, still, just make sure.
player removeEventHandler ["killed", WFBE_PLAYERKEH];

WFBE_Client_IsRespawning = true;


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

waitUntil {alive player};


//--- Update the player.
["RequestSpecial", ["update-teamleader", WFBE_Client_Team, player]] Call WFBE_CO_FNC_SendToServer;


//--- Make sure that player is always the leader of his group.
if (group player == WFBE_Client_Team) then {
	if (leader (group player) != player) then {
		(group player) selectLeader player;
	};
};

titleCut ["", "BLACK IN", 1];


//--- Re-add the killed event handler to the new player unit.
WFBE_PLAYERKEH = player addEventHandler [
	"Killed",
	{
		[_this select 0, _this select 1] Spawn WFBE_CL_FNC_OnKilled;
		[_this select 0, _this select 1, sideID] Spawn WFBE_CO_FNC_OnUnitKilled;
	}
];


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

	WFBE_DeathCamera = "camera" camCreate WFBE_DeathLocation;
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
