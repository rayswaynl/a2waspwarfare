/*
	RequestAIComDonate.sqf — server-side PVF handler.
	Player donates personal-wallet funds to the AI commander's wallet.

	Parameters (sent from GUI_TransferMenu.sqf via WFBE_CO_FNC_SendToServer):
	  0 - donor unit (object)
	  1 - claimed donor team group (group) - ADVISORY ONLY, never trusted; see C4-drain fix below
	  2 - amount (number)

	Validation (all server-authoritative):
	  - donor team is ALWAYS derived server-side as group _donor (C4-drain fix,
	    mirrors the RequestFundsTransfer N1 pattern) - the client-claimed team param
	    is never used to pick which wallet is debited, only logged on mismatch
	  - amount > 0 (SCALAR integer dollars)
	  - donor team has sufficient funds
	  - player's side genuinely has an AI commander at execution time

	FUNDS-AUTH 20260730:
	  - ARRAY envelope + OBJECT/GROUP/SCALAR type guards
	  - atomic isNil{} balance re-check + debit/credit (HandlePVF Spawn)

	On success:
	  - Debit donor team via ChangeTeamFunds (negative amount)
	  - Credit via ChangeAICommanderFunds
	  - Confirm to donor via HandleSpecial \"aicom-donate-confirm\"
	  - Broadcast side-wide LocalizeMessage \"AIComDonation\" (optional nicety)
	  - AICOMLog [DONATION] line
	  - AICOMSTAT EVENT line
*/

private [\"_donor\",\"_donorTeam\",\"_claimedTeam\",\"_amount\",\"_side\",\"_logik\",\"_teamFunds\",\"_aicomRunning\",
         \"_cmdTeam\",\"_humanCmd\",\"_walletAfter\",\"_donorName\",\"_donorUID\",\"_ok\"];

if (typeName _this != \"ARRAY\") exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected non-array payload type [%1].\", typeName _this]] Call WFBE_CO_FNC_AICOMLog;
};
if (count _this < 3) exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected short payload count [%1].\", count _this]] Call WFBE_CO_FNC_AICOMLog;
};

_donor       = _this select 0;
_claimedTeam = _this select 1;
_amount      = _this select 2;

if (typeName _donor != \"OBJECT\" || {isNull _donor}) exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected invalid donor object [%1].\", _donor]] Call WFBE_CO_FNC_AICOMLog;
};
//--- claimed team is advisory only; still require GROUP type when present so a forge cannot
//--- trip type errors in the mismatch log path.
if (typeName _claimedTeam != \"GROUP\") exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected non-group claimed team type [%1].\", typeName _claimedTeam]] Call WFBE_CO_FNC_AICOMLog;
};
if (typeName _amount != \"SCALAR\") exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected non-scalar amount type [%1].\", typeName _amount]] Call WFBE_CO_FNC_AICOMLog;
};

//--- fix(C4-drain): the donor team must NEVER be trusted from the client. A forged
//--- PVF payload could previously name ANY group as _donorTeam (_this select 1) and
//--- the server would debit THAT team's wallet regardless of who the donor actually
//--- was - draining another team's funds into the AI commander wallet. The donor team
//--- is now ALWAYS derived server-side as group _donor (mirrors the RequestFundsTransfer
//--- N1 fix pattern); the client-claimed team is used only to detect + log a forged
//--- mismatch, never to select which wallet gets debited or credited.
_donorTeam = group _donor;
if (isNull _donorTeam) exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected - donor [%1] has no group.\", _donor]] Call WFBE_CO_FNC_AICOMLog;
};

if (!isNull _claimedTeam && {_claimedTeam != _donorTeam}) then {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] forged-team violation - donor [%1] claimed team %2 but actually belongs to %3; real team used, no other team charged.\", _donor, _claimedTeam, _donorTeam]] Call WFBE_CO_FNC_AICOMLog;
};

//--- ALWAYS-ON (wave0721 hardening extras, owner-deferred C4/C2 ruling): the donor sender check is now
//--- effective REGARDLESS of WFBE_C_SEC_HARDENING, matching the donor-team re-derivation directly above
//--- (already unconditional). The sole honest caller is GUI_TransferMenu.sqf, which always sends the
//--- live local player, so no real donation can trip this; a forged non-player donor could otherwise
//--- still drain a team wallet with the switch dark.
if (!isPlayer _donor || {!alive _donor}) exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected - donor [%1] is not a live player.\", _donor]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Validate amount > 0 (integer dollars).
_amount = floor _amount;
if (!(_amount > 0)) exitWith {
	[\"INFORMATION\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected for %1 - amount %2 not positive.\", name _donor, _amount]] Call WFBE_CO_FNC_AICOMLog;
};

_donorName = name _donor;
_donorUID  = getPlayerUID _donor;
_side      = side (leader _donorTeam);
if (isNull (leader _donorTeam)) exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected for %1 - donor team has no leader.\", _donorName]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Prefer warfare-enrolled side when present (engine side can drift).
private [\"_wfbeSide\"];
_wfbeSide = _donorTeam getVariable \"wfbe_side\";
if (!isNil \"_wfbeSide\" && {typeName _wfbeSide == \"SIDE\"}) then {_side = _wfbeSide};
if (!(_side in [west, east, resistance])) exitWith {
	[\"WARNING\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected for %1 - side %2 not playable.\", _donorName, str _side]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Re-check server-authoritative: side has AI commander active (not human).
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {
	[\"INFORMATION\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected for %1 - side logic null.\", _donorName]] Call WFBE_CO_FNC_AICOMLog;
};

_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_humanCmd = false;
if (!isNull _cmdTeam) then {
	if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
};

if (_humanCmd) exitWith {
	[\"INFORMATION\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected for %1 - human commander active on side %2.\", _donorName, str _side]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Atomic funds move: re-read balance + debit/credit inside isNil{} so concurrent
//--- spawned PVF handlers cannot both pass a stale balance check (HandlePVF uses Spawn).
_ok = false;
isNil {
	_teamFunds = _donorTeam getVariable \"wfbe_funds\";
	if (isNil \"_teamFunds\" || {typeName _teamFunds != \"SCALAR\"}) then {_teamFunds = 0};
	if (_teamFunds >= _amount) then {
		[_donorTeam, -_amount] Call ChangeTeamFunds;
		[_side, _amount] Call ChangeAICommanderFunds;
		_ok = true;
	};
};

if (!_ok) exitWith {
	_teamFunds = _donorTeam getVariable \"wfbe_funds\";
	if (isNil \"_teamFunds\" || {typeName _teamFunds != \"SCALAR\"}) then {_teamFunds = 0};
	[\"INFORMATION\", Format [\"RequestAIComDonate.sqf: [DONATION] rejected for %1 - insufficient funds (has %2, wants %3).\", _donorName, _teamFunds, _amount]] Call WFBE_CO_FNC_AICOMLog;
};

_walletAfter = (_side) Call GetAICommanderFunds;

//--- Confirm to donor.
if (WF_A2_Vanilla) then {
	[_donorUID, \"HandleSpecial\", [\"aicom-donate-confirm\", _amount]] Call WFBE_CO_FNC_SendToClients;
} else {
	[_donor, \"HandleSpecial\", [\"aicom-donate-confirm\", _amount]] Call WFBE_CO_FNC_SendToClient;
};

//--- Optional nicety: side-wide broadcast so teammates see the generosity.
[_side, \"LocalizeMessage\", [\"AIComDonation\", _donorName, _amount]] Call WFBE_CO_FNC_SendToClients;

//--- Audit log — greppable DONATION tag.
[\"INFORMATION\", Format [\"RequestAIComDonate.sqf: [DONATION] side=%1 from=%2 amount=%3 wallet_after=%4\", str _side, _donorName, _amount, _walletAfter]] Call WFBE_CO_FNC_AICOMLog;

//--- AICOMSTAT EVENT so balance-pass can see player-funded swings.
diag_log (\"AICOMSTAT|v2|EVENT|\" + (str _side) + \"|\" + str (round (time / 60)) + \"|DONATION|\" + _donorName + \"|\" + str _amount + \"|wallet_after=\" + str _walletAfter);
