/*
	RequestAIComDonate.sqf — server-side PVF handler.
	Player donates personal-wallet funds to the AI commander's wallet.

	Parameters (sent from GUI_TransferMenu.sqf via WFBE_CO_FNC_SendToServer):
	  0 - donor unit (object)
	  1 - claimed donor team group (group) - ADVISORY ONLY, never trusted; see C4-drain fix below
	  2 - amount (number)

	Validation (all server-authoritative):
	  - donor team is ALWAYS derived server-side as `group _donor` (C4-drain fix,
	    mirrors the RequestFundsTransfer N1 pattern) - the client-claimed team param
	    is never used to pick which wallet is debited, only logged on mismatch
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

private ["_donor","_donorTeam","_claimedTeam","_amount","_side","_logik","_teamFunds","_aicomRunning",
         "_cmdTeam","_humanCmd","_walletAfter","_donorName","_donorUID"];

_donor       = _this select 0;
_claimedTeam = _this select 1;
_amount      = _this select 2;

//--- Basic nil guards.
if (isNil "_donor")       exitWith {};
if (isNil "_claimedTeam") exitWith {};
if (isNil "_amount")      exitWith {};

if (isNull _donor) exitWith {};

//--- fix(C4-drain): the donor team must NEVER be trusted from the client. A forged
//--- PVF payload could previously name ANY group as _donorTeam (_this select 1) and
//--- the server would debit THAT team's wallet regardless of who the donor actually
//--- was - draining another team's funds into the AI commander wallet. The donor team
//--- is now ALWAYS derived server-side as `group _donor` (mirrors the RequestFundsTransfer
//--- N1 fix pattern); the client-claimed team is used only to detect + log a forged
//--- mismatch, never to select which wallet gets debited or credited.
_donorTeam = group _donor;
if (isNull _donorTeam) exitWith {
	["WARNING", Format ["RequestAIComDonate.sqf: [DONATION] rejected - donor [%1] has no group.", _donor]] Call WFBE_CO_FNC_AICOMLog;
};

if (_claimedTeam != _donorTeam) then {
	["WARNING", Format ["RequestAIComDonate.sqf: [DONATION] forged-team violation - donor [%1] claimed team %2 but actually belongs to %3; real team used, no other team charged.", _donor, _claimedTeam, _donorTeam]] Call WFBE_CO_FNC_AICOMLog;
};

//--- DR-55 forged-PVF hardening (flag-gated; OFF = legacy behavior).
//--- The PVEH carries no trusted sender. Honest callers donate from a live
//--- player; a forged payload can otherwise pass a non-player object.
//--- fix(hunt): this rejection was an exitWith INSIDE the hardening then{} - on A2-OA that exits only the
//--- block and FELL THROUGH to the full donate flow (a forged non-player donor still drained the team).
//--- A single top-scope if+exitWith rejects for real.
//--- ALWAYS-ON (wave0721 hardening extras, owner-deferred C4/C2 ruling): the donor sender check is now
//--- effective REGARDLESS of WFBE_C_SEC_HARDENING, matching the donor-team re-derivation directly above
//--- (already unconditional). The sole honest caller is GUI_TransferMenu.sqf:101, which always sends the
//--- live local `player`, so no real donation can trip this; a forged non-player donor could otherwise
//--- still drain a team wallet with the switch dark.
if (!isPlayer _donor || {!alive _donor}) exitWith {
	["WARNING", Format ["RequestAIComDonate.sqf: [DONATION] rejected - donor [%1] is not a live player.", _donor]] Call WFBE_CO_FNC_AICOMLog;
};

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
