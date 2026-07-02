/*
	RequestAIComDonate.sqf — server-side PVF handler.
	Player donates personal-wallet funds to the AI commander's wallet.

	Parameters (sent from GUI_TransferMenu.sqf via WFBE_CO_FNC_SendToServer):
	  0 - donor unit (object)
	  1 - donor team group (group)
	  2 - amount (number)

	Validation (all server-authoritative):
	  - amount > 0
	  - donor team has sufficient funds
	  - player's side genuinely has an AI commander at execution time

	On success:
	  - Debit donor team via ChangeTeamFunds (negative amount)
	  - Credit via ChangeAICommanderFunds
	  - Confirm to donor via HandleSpecial "aicom-donate-confirm"
	  - Broadcast side-wide LocalizeMessage "AIComDonation" (optional nicety)
	  - AICOMLog [DONATION] line
	  - AICOMSTAT EVENT line
*/

private ["_donor","_donorTeam","_amount","_side","_logik","_teamFunds","_aicomRunning",
         "_cmdTeam","_humanCmd","_curFunds","_walletAfter","_donorName","_donorUID"];

_donor     = _this select 0;
_donorTeam = _this select 1;
_amount    = _this select 2;

//--- Basic nil guards.
if (isNil "_donor")     exitWith {};
if (isNil "_donorTeam") exitWith {};
if (isNil "_amount")    exitWith {};

if (isNull _donor)     exitWith {};
if (isNull _donorTeam) exitWith {};

//--- Validate amount > 0.
if (!(_amount > 0)) exitWith {
	["INFORMATION", Format ["RequestAIComDonate.sqf: [DONATION] rejected for %1 - amount %2 not positive.", name _donor, _amount]] Call WFBE_CO_FNC_AICOMLog;
};

_donorName = name _donor;
_donorUID  = getPlayerUID _donor;
_side      = side (leader _donorTeam);

//--- Re-check server-authoritative: side has AI commander active (not human).
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {
	["INFORMATION", Format ["RequestAIComDonate.sqf: [DONATION] rejected for %1 - side logic null.", _donorName]] Call WFBE_CO_FNC_AICOMLog;
};

_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_humanCmd = false;
if (!isNull _cmdTeam) then {
	if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
};

if (_humanCmd) exitWith {
	["INFORMATION", Format ["RequestAIComDonate.sqf: [DONATION] rejected for %1 - human commander active on side %2.", _donorName, str _side]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Validate donor team has sufficient funds (server-authoritative check).
//--- A2 OA 1.64: getVariable with default is unreliable on groups; use plain get + isNil guard.
_teamFunds = _donorTeam getVariable "wfbe_funds";
if (isNil "_teamFunds") then {_teamFunds = 0};
if (_teamFunds < _amount) exitWith {
	["INFORMATION", Format ["RequestAIComDonate.sqf: [DONATION] rejected for %1 - insufficient funds (has %2, wants %3).", _donorName, _teamFunds, _amount]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Execute transfer.
_curFunds = (_side) Call GetAICommanderFunds;

[_donorTeam, -_amount] Call ChangeTeamFunds;
[_side, _amount] Call ChangeAICommanderFunds;

_walletAfter = (_side) Call GetAICommanderFunds;

//--- Confirm to donor.
if (WF_A2_Vanilla) then {
	[_donorUID, "HandleSpecial", ["aicom-donate-confirm", _amount]] Call WFBE_CO_FNC_SendToClients;
} else {
	[_donor, "HandleSpecial", ["aicom-donate-confirm", _amount]] Call WFBE_CO_FNC_SendToClient;
};

//--- Optional nicety: side-wide broadcast so teammates see the generosity.
[_side, "LocalizeMessage", ["AIComDonation", _donorName, _amount]] Call WFBE_CO_FNC_SendToClients;

//--- Audit log — greppable DONATION tag.
["INFORMATION", Format ["RequestAIComDonate.sqf: [DONATION] side=%1 from=%2 amount=%3 wallet_after=%4", str _side, _donorName, _amount, _walletAfter]] Call WFBE_CO_FNC_AICOMLog;

//--- AICOMSTAT EVENT so balance-pass can see player-funded swings.
diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|DONATION|" + _donorName + "|" + str _amount + "|wallet_after=" + str _walletAfter);
