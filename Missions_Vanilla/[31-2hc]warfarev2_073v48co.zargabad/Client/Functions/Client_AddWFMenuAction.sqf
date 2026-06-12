/*
	Author: Marty
	Adds or refreshes the player's WF menu mouse wheel action.
*/

Private ["_actionID","_oldActionID","_unit"];

_unit = _this;

if (isNull _unit || !(alive _unit)) exitWith {-1};

// Marty: Store the addAction ID on the current player object.
// This prevents stale global IDs from removing another action after respawn.
_oldActionID = _unit getVariable ["WFBE_WFMenu_Action", -1];
if (_oldActionID >= 0) then {_unit removeAction _oldActionID};

_actionID = _unit addAction ["<t color='#42b6ff'>" + (localize "STR_WF_Options") + "</t>","Client\Action\Action_Menu.sqf", "", 1, false, true, "", "_target == player"];
_unit setVariable ["WFBE_WFMenu_Action", _actionID, false];

// Marty: Keep the legacy Options variable updated for older scripts that still read it.
Options = _actionID;

_actionID
