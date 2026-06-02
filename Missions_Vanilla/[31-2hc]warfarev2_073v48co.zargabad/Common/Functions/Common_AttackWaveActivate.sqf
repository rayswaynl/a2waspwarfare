private ["_supply", "_side"];

_supply = _this select 3 select 0;
_side = _this select 3 select 1;

ATTACK_WAVE_INIT = [_supply, _side];

publicVariableServer "ATTACK_WAVE_INIT";