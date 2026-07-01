private ["_requester", "_requestTeam", "_supply", "_side"];

_supply = _this select 3 select 0;
_side = _this select 3 select 1;
_requester = player;
_requestTeam = group player;

ATTACK_WAVE_INIT = [_supply, _side, _requester, _requestTeam];

publicVariableServer "ATTACK_WAVE_INIT";
