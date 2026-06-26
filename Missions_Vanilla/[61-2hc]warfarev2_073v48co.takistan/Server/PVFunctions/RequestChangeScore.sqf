Private["_oldScore","_newScore","_playerChanged"];

_playerChanged = _this select 0;
_newScore = _this select 1;

//--- Anti-cheat (Layer 6c / T7): reject structurally-invalid score writes. The full fix
//--- (server-owned award deltas) needs the DR-55 sender-auth redesign; this stops the
//--- egregious forgeries (null target, non-numeric or absurd absolute score).
if (isNull _playerChanged) exitWith {
	["WARNING", "RequestChangeScore.sqf: rejected - null target."] Call WFBE_CO_FNC_LogContent;
};
if (typeName _newScore != "SCALAR") exitWith {
	["WARNING", "RequestChangeScore.sqf: rejected - non-scalar score."] Call WFBE_CO_FNC_LogContent;
};
if (_newScore < -100000 || {_newScore > 1000000}) exitWith {
	["WARNING", Format ["RequestChangeScore.sqf: rejected - score [%1] out of bounds for [%2].", _newScore, _playerChanged]] Call WFBE_CO_FNC_LogContent;
};

_oldScore = score _playerChanged;
_playerChanged addScore -_oldScore;
_playerChanged addScore _newScore;

// WFBE_ChangeScore = [nil,'CLTFNCCHANGESCORE',[_playerChanged,_newScore]];
// publicVariable 'WFBE_ChangeScore';
// if (isHostedServer) then {[nil,'CLTFNCCHANGESCORE',[_playerChanged,_newScore]] Spawn HandlePVF};
[nil, "ChangeScore", [_playerChanged,_newScore]] Call WFBE_CO_FNC_SendToClients;