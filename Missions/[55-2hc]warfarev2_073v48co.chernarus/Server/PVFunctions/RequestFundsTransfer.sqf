/*
	RequestFundsTransfer.sqf -- server-side PVF handler.
	Player transfers team-wallet funds from their own team to another team on
	the same side. This is the player-to-player row of GUI_TransferMenu.sqf
	(and the equivalent "classic WF menu" transfer slider in GUI_Menu_Team.sqf)
	- distinct from the AI Commander donation row, which uses the already
	server-authoritative RequestAIComDonate.sqf ("E2 fix").

	N1 fix (GR-2026-07-08a): both client call sites used to debit/credit
	wfbe_funds directly (WFBE_CL_FNC_ChangeClientFunds + WFBE_CO_FNC_ChangeTeamFunds,
	both executed on the CALLER's own machine, broadcast public) with zero server
	validation - any modified client could forge the target team and/or the
	amount and mint funds out of nothing. This handler mirrors the
	RequestAIComDonate server-revalidation pattern: the server is now the sole
	arbiter of the transfer.

	Parameters (sent from GUI_TransferMenu.sqf / GUI_Menu_Team.sqf via
	WFBE_CO_FNC_SendToServer):
	  0 - donor unit (object)
	  1 - target team (group) - the recipient team selected in the client list
	  2 - amount (number)

	Validation (all server-authoritative):
	  - donor is a live player (rejects a forged/dead-object donor)
	  - donor team is ALWAYS derived server-side as `group _donor` - the
	    client never gets to claim which team it is transferring FROM
	  - target team is non-null, has a valid leader, is not the donor's own
	    team, and is on the donor's own side (matches the same-side pool the
	    client menus offer - blocks a forged cross-side/forged-target drain)
	  - amount > 0
	  - donor team actually has >= amount funds (no unbacked credit / dupe)

	On success:
	  - Debit donor team, credit target team via ChangeTeamFunds - a single
	    authoritative amount moves both sides; no client-supplied delta is
	    ever trusted directly
	  - Notify the target leader (if a player) via the existing LocalizeMessage
	    "FundsTransfer" path
	  - LogContent line (greppable [TRANSFER] tag) for audit
*/

private ["_donor","_target","_amount","_donorTeam","_donorSide","_targetSide","_teamFunds","_donorName"];

_donor  = _this select 0;
_target = _this select 1;
_amount = _this select 2;

//--- Basic nil guards.
if (isNil "_donor")  exitWith {};
if (isNil "_target") exitWith {};
if (isNil "_amount") exitWith {};

if (isNull _donor)  exitWith {};
if (isNull _target) exitWith {};

//--- Reject a forged/dead-object donor - the PVEH carries no trusted sender.
if (!isPlayer _donor || {!alive _donor}) exitWith {
	["WARNING", Format ["RequestFundsTransfer.sqf: [TRANSFER] rejected - donor [%1] is not a live player.", _donor]] Call WFBE_CO_FNC_LogContent;
};

//--- Validate amount > 0.
if (!(_amount > 0)) exitWith {
	["WARNING", Format ["RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - amount %2 not positive.", name _donor, _amount]] Call WFBE_CO_FNC_LogContent;
};

//--- Donor team is ALWAYS derived from the donor object itself, never taken
//--- from a client-supplied parameter - the client is never trusted to name
//--- its own team.
_donorTeam = group _donor;
if (isNull _donorTeam) exitWith {};

_donorName = name _donor;

//--- Target must be a real, distinct, same-side team with a valid leader -
//--- matches the pool the client menus offer (own side's team list only).
if (isNull (leader _target)) exitWith {};

if (_target == _donorTeam) exitWith {
	["WARNING", Format ["RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - self-transfer.", _donorName]] Call WFBE_CO_FNC_LogContent;
};

_donorSide  = side _donorTeam;
_targetSide = side _target;
if (_targetSide != _donorSide) exitWith {
	["WARNING", Format ["RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - target side %2 does not match donor side %3.", _donorName, str _targetSide, str _donorSide]] Call WFBE_CO_FNC_LogContent;
};

//--- Validate donor team has sufficient funds (server-authoritative check).
//--- A2 OA 1.64: getVariable with default is unreliable on groups; use plain
//--- get + isNil guard (matches the cmdcon43-h / RequestAIComDonate convention).
_teamFunds = _donorTeam getVariable "wfbe_funds";
if (isNil "_teamFunds") then {_teamFunds = 0};
if (_teamFunds < _amount) exitWith {
	["WARNING", Format ["RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - insufficient funds (has %2, wants %3).", _donorName, _teamFunds, _amount]] Call WFBE_CO_FNC_LogContent;
};

//--- Execute transfer - single authoritative amount moves both sides.
[_donorTeam, -_amount] Call ChangeTeamFunds;
[_target, _amount] Call ChangeTeamFunds;

//--- Notify the recipient's leader if a player (matches prior client-side UX).
if (isPlayer (leader _target)) then {
	[getPlayerUID (leader _target), "LocalizeMessage", ["FundsTransfer", _amount, _donorName]] Call WFBE_CO_FNC_SendToClients;
};

//--- Audit log - greppable TRANSFER tag.
["INFORMATION", Format ["RequestFundsTransfer.sqf: [TRANSFER] side=%1 from=%2 to=%3 amount=%4", str _donorSide, _donorName, name (leader _target), _amount]] Call WFBE_CO_FNC_LogContent;
