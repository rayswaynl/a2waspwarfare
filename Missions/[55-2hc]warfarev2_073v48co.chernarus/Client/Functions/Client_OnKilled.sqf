/*
	Triggered whenever the player dies.

	Parameters:
		_this select 0: dead player body
		_this select 1: killer
*/

Private ["_body","_killer","_wfMenuAction"];

_body = _this select 0;
_killer = _this select 1;

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
WFBE_DeathKillerLocation = [];
if !(isNull _killer) then {WFBE_DeathKillerLocation = getPos _killer};


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


//--- Card #210: AnimChanged event handlers are flushed when the old unit dies, so re-attach the
//--- auto-bipod-deploy handler to the fresh player unit. Guarded so it is a no-op if the bipod
//--- script has not finished loading yet.
if (!isNil "Bipod_AddAutoDeploy") then {[] call Bipod_AddAutoDeploy};


//--- Call the pre respawn routine.
// This will also re-add the player action menu entries.
(player) Call PreRespawnHandler;


//--- Camera & post-process thread.
[] Spawn {
	Private ["_camEnd","_camStart","_camTarget","_deathX","_deathY","_deathZ","_delay","_dx","_dy","_killerPos","_len"];

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

	//--- Guard: bail if the death position is invalid or camCreate failed to bind (prevents per-frame "Undefined variable wfbe_deathcamera" spam in the waitUntil below).
	if (isNil "WFBE_DeathLocation" || {typeName WFBE_DeathLocation != "ARRAY"} || {count WFBE_DeathLocation < 3}) exitWith {
		"dynamicBlur" ppEffectEnable false;
		"colorCorrections" ppEffectEnable false;
	};

	WFBE_DeathCamera = "camera" camCreate WFBE_DeathLocation;
	if (isNil "WFBE_DeathCamera") exitWith {
		"dynamicBlur" ppEffectEnable false;
		"colorCorrections" ppEffectEnable false;
	};
	WFBE_DeathCamera camSetDir 0;
	WFBE_DeathCamera camSetFov 0.7;
	WFBE_DeathCamera cameraEffect ["Internal", "TOP"];

	_deathX = WFBE_DeathLocation select 0;
	_deathY = WFBE_DeathLocation select 1;
	_deathZ = WFBE_DeathLocation select 2;
	_camTarget = WFBE_DeathLocation;
	_camStart = [_deathX, _deathY + 2, 5];
	_camEnd = [_deathX, _deathY + 2, 30];

	//--- Lane 160: when the killer position is valid, look back along the incoming-fire axis.
	if (!(isNil "WFBE_DeathKillerLocation") && {typeName WFBE_DeathKillerLocation in ["ARRAY"]} && {count WFBE_DeathKillerLocation >= 3}) then {
		_killerPos = WFBE_DeathKillerLocation;
		_dx = _deathX - (_killerPos select 0);
		_dy = _deathY - (_killerPos select 1);
		_len = sqrt ((_dx * _dx) + (_dy * _dy));
		if (_len > 3) then {
			_dx = _dx / _len;
			_dy = _dy / _len;
			_camTarget = [_killerPos select 0, _killerPos select 1, (_killerPos select 2) + 1.5];
			_camStart = [_deathX + (_dx * 8), _deathY + (_dy * 8), _deathZ + 4];
			_camEnd = [_deathX + (_dx * 20), _deathY + (_dy * 20), _deathZ + 28];
		};
	};

	WFBE_DeathCamera camSetTarget _camTarget;
	WFBE_DeathCamera camSetPos _camStart;

	WFBE_DeathCamera camCommit 0;

	waitUntil {
		camCommitted WFBE_DeathCamera
	};

	WFBE_DeathCamera camSetPos _camEnd;

	WFBE_DeathCamera camCommit (_delay + 2);
};

sleep random 1;


//--- Create a respawn menu.
createDialog "WFBE_RespawnMenu";
