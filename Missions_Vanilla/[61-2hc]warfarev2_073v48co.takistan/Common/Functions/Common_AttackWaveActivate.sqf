private ["_supply", "_side", "_requester"];

_supply = _this select 3 select 0;
_side = _this select 3 select 1;
_requester = player;

//--- fix(harden) [#1399]: thread the acting player through ATTACK_WAVE_INIT so the server can bind the
//--- heavy-attack activation (and its full-supply debit) to the requester's own side instead of
//--- trusting the client-asserted _side. Mirrors the C4/C2 always-on identity-bind idiom used for
//--- RequestAIComDonate.sqf and the aicom-team-disband/rally/refit/hold send-sites (PR #1364): the
//--- sole honest caller is this addAction handler, which always sends the live local `player`.
ATTACK_WAVE_INIT = [_supply, _side, _requester];

publicVariableServer "ATTACK_WAVE_INIT";