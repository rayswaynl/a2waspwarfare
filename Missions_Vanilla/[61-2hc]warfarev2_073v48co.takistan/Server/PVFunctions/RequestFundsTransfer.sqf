/*
	RequestFundsTransfer.sqf -- server-side PVF handler.
	Player transfers team-wallet funds from their own team to another team on
	the same side. This is the player-to-player row of GUI_TransferMenu.sqf
	(and the equivalent \"classic WF menu\" transfer slider in GUI_Menu_Team.sqf)
	- distinct from the AI Commander donation row, which uses the already
	server-authoritative RequestAIComDonate.sqf (\"E2 fix\").

	N1 fix (GR-2026-07-08a): both client call sites used to debit/credit
	wfbe_funds directly (WFBE_CL_FNC_ChangeClientFunds + WFBE_CO_FNC_ChangeTeamFunds,
	both executed on the CALLER's own machine, broadcast public) with zero server
	validation - any modified client could forge the target team and/or the
	amount and mint funds out of nothing. This handler mirrors the
	RequestAIComDonate server-revalidation pattern: the server is now the sole
	arbiter of the transfer.

	FUNDS-AUTH 20260730 (economy funds transfer authority bughunt):
	  - ARRAY envelope + OBJECT/GROUP/SCALAR type guards before bare selects
	  - target must be a warfare-enrolled GROUP (wfbe_side) same as donor
	  - amount floored to integer dollars; non-SCALAR rejected
	  - atomic isNil{} re-read + debit/credit (HandlePVF Spawns handlers)

	Parameters (sent from GUI_TransferMenu.sqf / GUI_Menu_Team.sqf via
	WFBE_CO_FNC_SendToServer):
	  0 - donor unit (object)
	  1 - target team (group) - the recipient team selected in the client list
	  2 - amount (number)

	Validation (all server-authoritative):
	  - donor is a live player (rejects a forged/dead-object donor)
	  - donor team is ALWAYS derived server-side as group _donor - the
	    client never gets to claim which team it is transferring FROM
	  - target team is non-null GROUP, has a valid leader, is not the donor's
	    own team, and carries matching wfbe_side (blocks cross-side forge and
	    non-warfare group credit sinks)
	  - amount is positive SCALAR integer dollars
	  - donor team actually has >= amount funds (no unbacked credit / dupe)

	On success:
	  - Debit donor team, credit target team via ChangeTeamFunds - a single
	    authoritative amount moves both sides; no client-supplied delta is
	    ever trusted directly
	  - Notify the target leader (if a player) via the existing LocalizeMessage
	    \"FundsTransfer\" path
	  - LogContent line (greppable [TRANSFER] tag) for audit
*/

private [\"_donor\",\"_target\",\"_amount\",\"_donorTeam\",\"_donorSide\",\"_targetSide\",\"_teamFunds\",\"_donorName\",\"_ok\"];

if (typeName _this != \"ARRAY\") exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected non-array payload type [%1].\", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (count _this < 3) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected short payload count [%1].\", count _this]] Call WFBE_CO_FNC_LogContent;
};

_donor  = _this select 0;
_target = _this select 1;
_amount = _this select 2;

if (typeName _donor != \"OBJECT\" || {isNull _donor}) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected invalid donor object [%1].\", _donor]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _target != \"GROUP\" || {isNull _target}) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected invalid target group [%1].\", _target]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _amount != \"SCALAR\") exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected non-scalar amount type [%1].\", typeName _amount]] Call WFBE_CO_FNC_LogContent;
};

//--- Reject a forged/dead-object donor - the PVEH carries no trusted sender.
if (!isPlayer _donor || {!alive _donor}) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected - donor [%1] is not a live player.\", _donor]] Call WFBE_CO_FNC_LogContent;
};

//--- Integer dollars only (client GUI already floors parseNumber).
_amount = floor _amount;
if (!(_amount > 0)) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - amount %2 not positive.\", name _donor, _amount]] Call WFBE_CO_FNC_LogContent;
};

//--- Donor team is ALWAYS derived from the donor object itself, never taken
//--- from a client-supplied parameter - the client is never trusted to name
//--- its own team.
_donorTeam = group _donor;
if (isNull _donorTeam) exitWith {};

_donorName = name _donor;

//--- Target must be a real, distinct warfare team with a valid leader.
if (isNull (leader _target)) exitWith {};

if (_target == _donorTeam) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - self-transfer.\", _donorName]] Call WFBE_CO_FNC_LogContent;
};

//--- Warfare side bind: engine side alone can be CIV/transient on empty or
//--- non-enrolled groups. Require matching wfbe_side on both groups so a forge
//--- cannot credit a non-warfare same-engine-side group or cross-faction sink.
_donorSide = _donorTeam getVariable \"wfbe_side\";
_targetSide = _target getVariable \"wfbe_side\";
if (isNil \"_donorSide\" || {typeName _donorSide != \"SIDE\"}) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - donor team has no warfare wfbe_side.\", _donorName]] Call WFBE_CO_FNC_LogContent;
};
if (isNil \"_targetSide\" || {typeName _targetSide != \"SIDE\"}) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - target team has no warfare wfbe_side.\", _donorName]] Call WFBE_CO_FNC_LogContent;
};
if (_targetSide != _donorSide) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - target side %2 does not match donor side %3.\", _donorName, str _targetSide, str _donorSide]] Call WFBE_CO_FNC_LogContent;
};
if (!(_donorSide in [west, east, resistance])) exitWith {
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - donor side %2 is not a playable faction.\", _donorName, str _donorSide]] Call WFBE_CO_FNC_LogContent;
};

//--- Atomic re-check + move: HandlePVF Spawns every handler; isNil{} runs unscheduled
//--- and cannot interleave with a sibling transfer/donate on the same wallet.
_ok = false;
isNil {
	_teamFunds = _donorTeam getVariable \"wfbe_funds\";
	if (isNil \"_teamFunds\" || {typeName _teamFunds != \"SCALAR\"}) then {_teamFunds = 0};
	if (_teamFunds >= _amount) then {
		[_donorTeam, -_amount] Call ChangeTeamFunds;
		[_target, _amount] Call ChangeTeamFunds;
		_ok = true;
	};
};

if (!_ok) exitWith {
	_teamFunds = _donorTeam getVariable \"wfbe_funds\";
	if (isNil \"_teamFunds\" || {typeName _teamFunds != \"SCALAR\"}) then {_teamFunds = 0};
	[\"WARNING\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] rejected for %1 - insufficient funds (has %2, wants %3).\", _donorName, _teamFunds, _amount]] Call WFBE_CO_FNC_LogContent;
};

//--- Notify the recipient's leader if a player (matches prior client-side UX).
if (isPlayer (leader _target)) then {
	[getPlayerUID (leader _target), \"LocalizeMessage\", [\"FundsTransfer\", _amount, _donorName]] Call WFBE_CO_FNC_SendToClients;
};

//--- Audit log - greppable TRANSFER tag.
[\"INFORMATION\", Format [\"RequestFundsTransfer.sqf: [TRANSFER] side=%1 from=%2 to=%3 amount=%4\", str _donorSide, _donorName, name (leader _target), _amount]] Call WFBE_CO_FNC_LogContent;
