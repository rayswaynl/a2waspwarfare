private ["_supply", "_side", "_requester", "_args"];

//--- fix(code-as-string r33): never trust addAction args baked at attach-time (stale supply).
//--- Re-read live side + supply; keep optional legacy args only as a soft fallback.
_args = if (count _this > 3) then {_this select 3} else {[]};
_side = sideJoined;
if (typeName _args == "ARRAY" && {count _args > 1}) then {
	if (typeName (_args select 1) == "SIDE") then {_side = _args select 1};
};
_supply = _side call GetSideSupply;
_requester = player;

//--- fix(harden) [#1399]: thread the acting player through ATTACK_WAVE_INIT so the server can bind the
//--- heavy-attack activation (and its full-supply debit) to the requester's own side instead of
//--- trusting the client-asserted _side. Mirrors the C4/C2 always-on identity-bind idiom used for
//--- RequestAIComDonate.sqf and the aicom-team-disband/rally/refit/hold send-sites (PR #1364): the
//--- sole honest caller is this addAction handler, which always sends the live local `player`.
ATTACK_WAVE_INIT = [_supply, _side, _requester];

publicVariableServer "ATTACK_WAVE_INIT";