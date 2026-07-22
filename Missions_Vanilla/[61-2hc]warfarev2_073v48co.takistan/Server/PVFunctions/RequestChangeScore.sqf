Private["_oldScore","_newScore","_playerChanged","_rejected"];

_playerChanged = _this select 0;
_newScore = _this select 1;

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- The PVEH carries no trusted sender. Honest callers target a living player/team-leader with
//--- a SMALL per-event award ([player, score player + delta]); a forger can target any player or
//--- set an absurd absolute score. We cannot bind the request to its sender without an actor in
//--- the payload (callers are SHARED files outside this cluster - see clientSendChanges), so the
//--- server-side guard rejects dead targets and clamps the single-event magnitude. Note: some
//--- legit awards come from server-side AI events (e.g. Server_OnHQKilled with an AI team leader),
//--- so we do NOT require isPlayer here - that would drop honest AI-team kill credit.
//--- fix(hunt): the two rejections were exitWith INSIDE the then{} - on A2-OA that exits only the block
//--- and FALLS THROUGH to the score write below, so every "rejected" forge was still applied. Latch +
//--- top-scope exit (same repair as RequestVehicleLock.sqf / RequestEnqueue.sqf).
//--- ALWAYS-ON (wave0721 hardening extras, owner-deferred C4/C2 ruling): these score guards are now
//--- effective REGARDLESS of WFBE_C_SEC_HARDENING. The switch stays the master for the rest of the DR-55
//--- cluster; only the score-payload safety below is unconditional, because an audit of EVERY in-tree
//--- caller (Client/PVFunctions/CampCaptured + TownCaptured, Client_FNC_Special, supplyMissionCompleted-
//--- Message, coin_interface, RequestOnUnitKilled, Server_OnHQKilled, Server_HandleSpecial) shows each one
//--- always targets a real player / team-leader object with a small delta - the largest legitimate single
//--- award in the tree is the HQ kill (900 pts), two orders of magnitude under the 50000 ceiling. So no
//--- honest path can trip these, while a forged null target or a jump-to-millions is refused with the
//--- switch dark. This matches how RequestFundsTransfer.sqf / RequestVehicleSell.sqf / RequestGDirPanel.sqf
//--- / RequestClaimCommander.sqf already treat their equivalent sender/amount checks: unconditionally.
_rejected = false;
if (isNull _playerChanged) then {
	_rejected = true;
	["WARNING", Format ["RequestChangeScore.sqf: rejected forged score change on null target [%1].", _playerChanged]] Call WFBE_CO_FNC_LogContent;
};
//--- Type guard AHEAD of the clamp: the magnitude arithmetic is now on the always-taken path, so a
//--- non-numeric forged payload must be refused before `abs (_newScore - _oldScore)` evaluates it.
//--- Honest callers always pass a number (score player + delta), so this cannot fire on a real award.
if (!_rejected && {typeName _newScore != "SCALAR"}) then {
	_rejected = true;
	["WARNING", Format ["RequestChangeScore.sqf: rejected non-numeric score payload on [%1] (type=%2).", _playerChanged, typeName _newScore]] Call WFBE_CO_FNC_LogContent;
};
//--- Clamp the magnitude of a single change. Largest LEGIT single award is a structure/HQ
//--- kill (Server_AwardScorePlayer.sqf: price*0.55/100*BUILDINGS_SCORE_COEF, a few thousand);
//--- this ceiling sits well above that yet blocks the gross forge (jump to millions / zero-out).
if (!_rejected) then {
	_oldScore = score _playerChanged;
	if ((abs (_newScore - _oldScore)) > 50000) then {
		_rejected = true;
		["WARNING", Format ["RequestChangeScore.sqf: rejected oversized score delta on [%1] (old=%2 new=%3).", _playerChanged, _oldScore, _newScore]] Call WFBE_CO_FNC_LogContent;
	};
};
if (_rejected) exitWith {};

_oldScore = score _playerChanged;
_playerChanged addScore -_oldScore;
_playerChanged addScore _newScore;

// WFBE_ChangeScore = [nil,'CLTFNCCHANGESCORE',[_playerChanged,_newScore]];
// publicVariable 'WFBE_ChangeScore';
// if (isHostedServer) then {[nil,'CLTFNCCHANGESCORE',[_playerChanged,_newScore]] Spawn HandlePVF};
[nil, "ChangeScore", [_playerChanged,_newScore]] Call WFBE_CO_FNC_SendToClients;