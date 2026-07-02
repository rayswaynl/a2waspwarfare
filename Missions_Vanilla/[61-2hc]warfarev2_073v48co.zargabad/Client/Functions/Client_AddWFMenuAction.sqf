/*
	Author: Marty
	Adds or refreshes the player's WF menu mouse wheel actions.
*/

Private ["_actionID","_oldActionID","_oldTransferActionID","_transferActionID","_unit"];

_unit = _this;

if (isNull _unit || !(alive _unit)) exitWith {-1};

// Marty: Store the addAction ID on the current player object.
// This prevents stale global IDs from removing another action after respawn.
_oldActionID = _unit getVariable ["WFBE_WFMenu_Action", -1];
if (_oldActionID >= 0) then {_unit removeAction _oldActionID};

_actionID = _unit addAction ["<t color='#42b6ff'>" + (localize "STR_WF_Options") + "</t>","Client\Action\Action_Menu.sqf", "", 1, false, true, "", "_target == player"];
_unit setVariable ["WFBE_WFMenu_Action", _actionID, false];

//--- Lane 162: keep the existing WF menu path, but expose the transfer dialog directly for frequent use.
_oldTransferActionID = _unit getVariable ["WFBE_TransferMenu_Action", -1];
if (_oldTransferActionID >= 0) then {_unit removeAction _oldTransferActionID};

_transferActionID = _unit addAction ["<t color='#11ec52'>" + (localize "STR_WF_TEAM_TransferButton") + "</t>","Client\Action\Action_TransferMenu.sqf", "", 1.05, false, true, "", "_target in [player] && alive player && !(dialog)"];
_unit setVariable ["WFBE_TransferMenu_Action", _transferActionID, false];

// Marty: Keep the legacy Options variable updated for older scripts that still read it.
Options = _actionID;

_actionID
