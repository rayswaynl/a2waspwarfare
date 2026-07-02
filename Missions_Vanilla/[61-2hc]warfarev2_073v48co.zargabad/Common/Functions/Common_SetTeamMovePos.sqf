Private['_movePos','_team'];

_team = _this select 0;
_movePos = _this select 1;

if (isNull _team) exitWith {};

_team setVariable ["wfbe_teamgoto", _movePos, true];

//--- cmdcon42-o ENEMY-BASE INTEL-LEAK CLAMP (Ray 2026-07-02): wfbe_teamgoto (above) is the TRUE destination
//--- the executor drives to - it MUST stay exact (a strike goto = getPos enemyHQ). But that broadcast var is
//--- also read for DISPLAY (the war-room roster "Target" column) and is script-sniffable, so a team ordered
//--- onto the enemy HQ would pin the hidden base. Publish a SEPARATE display-only var: when the destination
//--- lands inside an enemy base (producer-side clamp, no client ever sees the true HQ pos) render the nearest
//--- enemy-held town + "(advancing)"; otherwise clear it so the roster falls back to the true (safe) goto.
//--- Nil-guarded: inert until the sanitizer fn is registered (Init_Common) and on any pre-init call.
if (!isNil "WFBE_CO_FNC_SanitizeGotoDisp") then {
	private "_disp"; _disp = [_team, _movePos] Call WFBE_CO_FNC_SanitizeGotoDisp;
	if (typeName _disp == "ARRAY" && {count _disp >= 2}) then {
		_team setVariable ["wfbe_teamgoto_disp", _disp, true];   //--- [ clampPos, clampTownName ] - a safe reference, never the base.
	} else {
		//--- Not a leak this order -> drop any stale display clamp so the roster shows the true destination again.
		if (!isNil {_team getVariable "wfbe_teamgoto_disp"}) then {_team setVariable ["wfbe_teamgoto_disp", nil, true]};
	};
};