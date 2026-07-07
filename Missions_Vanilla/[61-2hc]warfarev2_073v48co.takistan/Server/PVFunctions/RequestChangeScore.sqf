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
_rejected = false;
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	if (isNull _playerChanged) then {
		_rejected = true;
		["WARNING", Format ["RequestChangeScore.sqf: rejected forged score change on null target [%1].", _playerChanged]] Call WFBE_CO_FNC_LogContent;
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
};
if (_rejected) exitWith {};

_oldScore = score _playerChanged;
_playerChanged addScore -_oldScore;
_playerChanged addScore _newScore;

// WFBE_ChangeScore = [nil,'CLTFNCCHANGESCORE',[_playerChanged,_newScore]];
// publicVariable 'WFBE_ChangeScore';
// if (isHostedServer) then {[nil,'CLTFNCCHANGESCORE',[_playerChanged,_newScore]] Spawn HandlePVF};
[nil, "ChangeScore", [_playerChanged,_newScore]] Call WFBE_CO_FNC_SendToClients;