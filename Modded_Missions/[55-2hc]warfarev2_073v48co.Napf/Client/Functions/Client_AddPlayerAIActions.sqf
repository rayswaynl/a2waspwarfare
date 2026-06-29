/*
	Author: Marty / revised clearer version

	Purpose:
	Add two mouse wheel actions to the player:

	- Diagnose my AI
	- Recover my AI movement

	This file only adds the actions.
	It does not define extra helper functions.

	The action is visible when:
	- the player is alive;
	- the player is the leader of his group.

	The recover and diagnose scripts will later check if there are actual AI units
	in the player's group.
*/

Private [
	"_action_condition",
	"_old_diagnose_action",
	"_old_recover_action",
	"_player_unit"
];

_player_unit = _this;

if (isNull _player_unit) exitWith {};
if (!alive _player_unit) exitWith {};


// ==================================================
// Remove previous actions if they already exist.
// This prevents duplicated menu entries after respawn.
// ==================================================

_old_diagnose_action = _player_unit getVariable ["Player_AI_Diagnose_Action", -1];

if (_old_diagnose_action >= 0) then {
	_player_unit removeAction _old_diagnose_action;
};

_old_recover_action = _player_unit getVariable ["Player_AI_Recover_Action", -1];

if (_old_recover_action >= 0) then {
	_player_unit removeAction _old_recover_action;
};


// ==================================================
// Mouse wheel condition.
// ==================================================
// Keep it simple.
// The detailed AI checks are done inside the scripts themselves.

_action_condition = "_target == player && alive player && (leader (group player) == player)";


// ==================================================
// Add actions.
// ==================================================

if (WF_Debug) then {
	Player_AI_Diagnose_Action = _player_unit addAction [
		"<t color='#ffbd4c'>Diagnose my AI</t>",
		"Client\Functions\Client_DiagnosePlayerAI.sqf",
		[],
		1.2,
		false,
		true,
		"",
		_action_condition
	];

	_player_unit setVariable ["Player_AI_Diagnose_Action", Player_AI_Diagnose_Action, false];
};

Player_AI_Recover_Action = _player_unit addAction [
	"<t color='#11ec52'>Recover my AI movement</t>",
	"Client\Functions\Client_RecoverPlayerAI.sqf",
	[],
	1.1,
	false,
	true,
	"",
	_action_condition
];


// ==================================================
// Store action IDs on the player object.
// This makes them easy to remove after respawn.
// ==================================================

_player_unit setVariable ["Player_AI_Recover_Action", Player_AI_Recover_Action, false];
