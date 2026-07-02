/*
	cmdcon42-o INTEL-LEAK SANITIZER (Ray 2026-07-02): "using Command menu in wf menu, players can
	see where enemy base is when they have their ai squads push". The AI-commander HQ-strike (and any
	order whose destination lands in the enemy base) sets a team's wfbe_teamgoto = getPos enemyHQ. That
	goto is BROADCAST (Common_SetTeamMovePos setVariable [...,true]) and surfaces on the player's OWN
	side in the war-room roster ("Target" column) AND is script-sniffable off any team group var - a
	pin on the hidden enemy base the player never scouted.

	This helper computes a DISPLAY-SAFE substitute for a would-be-leaky destination, PRODUCER-SIDE
	(server/HC), so no client ever receives the true enemy-HQ position for rendering:
	  - If sanitize is OFF (WFBE_C_CMD_INTEL_SANITIZE == 0) -> return [] (no substitution; caller shows
	    the true destination, legacy behaviour).
	  - If the destination is NOT within WFBE_C_CMD_INTEL_HQ_RADIUS (800m) of ANY ENEMY side's HQ ->
	    return [] (a normal town/field order is not an intel leak; show it truthfully).
	  - If the destination IS within that radius of an enemy HQ -> return the CLAMPED reference:
	    the nearest ENEMY-HELD town centre to the true destination, so the player sees their squads
	    are pushing toward enemy territory but gets NO pin on the hidden base. The caller labels it
	    "(advancing)".

	Parameters: [ _team (group; its OWN side is friendly, all OTHER real sides are enemy),
	              _movePos (the TRUE destination position array) ]
	Returns: [] when no sanitization needed, else [ _clampPos, _clampName ] where _clampName is the
	         enemy-held town name (or "enemy lines" when none resolvable) to render as "<name> (advancing)".

	A2-OA 1.64 safe: no params / isEqualType / isEqualTo / worldSize / BIS_fnc. Plain distance / getPos /
	count / typeName / getVariable-with-default. Nil-guarded throughout (side logics / HQ may be objNull).
*/

private ["_team","_movePos","_sanitize","_radius","_mySide","_enemySides","_leak","_hqPos","_hq","_es","_best","_bestD","_t","_tName"];

_team    = _this select 0;
_movePos = _this select 1;

//--- OFF-switch: sanitize disabled -> never substitute.
_sanitize = missionNamespace getVariable ["WFBE_C_CMD_INTEL_SANITIZE", 1];
if (_sanitize <= 0) exitWith { [] };

//--- Guard the inputs. A null team or a non-array/degenerate pos is nothing to sanitize.
if (isNull _team) exitWith { [] };
if (typeName _movePos != "ARRAY") exitWith { [] };
if (count _movePos < 2) exitWith { [] };
//--- The [0,0,0] "no destination" sentinel is never a leak.
if (((_movePos select 0) == 0) && {(_movePos select 1) == 0}) exitWith { [] };

_radius = missionNamespace getVariable ["WFBE_C_CMD_INTEL_HQ_RADIUS", 800];

//--- The team's own side is friendly; every OTHER real side (west/east/resistance) is an enemy whose
//--- HQ must stay hidden. Test the destination against each enemy HQ.
_mySide = side _team;
_enemySides = [];
{ if (_x != _mySide) then {_enemySides = _enemySides + [_x]} } forEach [west, east, resistance];

_leak = false;
{
	_hq = _x Call WFBE_CO_FNC_GetSideHQ;   //--- objNull for a side with no logic/HQ (nil-guarded inside the fn)
	if (!isNull _hq) then {
		_hqPos = getPos _hq;
		if ((_movePos distance _hqPos) < _radius) then {_leak = true};
	};
} forEach _enemySides;

if (!_leak) exitWith { [] };   //--- destination is not in an enemy base -> show it truthfully.

//--- LEAK: clamp to the nearest ENEMY-HELD town centre to the true destination. towns is populated on
//--- server + HC (Init_Town.sqf); each town carries sideID (owner) and name. Pick the closest town whose
//--- owner is one of the enemy sides, so the player sees a friendly-known reference toward enemy lines.
_best = objNull; _bestD = 1e9;
if (!isNil "towns" && {typeName towns == "ARRAY"}) then {
	{
		_t = _x;
		if (!isNull _t) then {
			private "_tSid"; _tSid = _t getVariable ["sideID", -1];
			private "_enemyOwned"; _enemyOwned = false;
			{ if (_tSid == (_x Call WFBE_CO_FNC_GetSideID)) then {_enemyOwned = true} } forEach _enemySides;
			if (_enemyOwned) then {
				private "_d"; _d = _movePos distance (getPos _t);
				if (_d < _bestD) then {_bestD = _d; _best = _t};
			};
		};
	} forEach towns;
};

_tName = "enemy lines";
if (!isNull _best) then {
	_tName = _best getVariable ["name", "enemy lines"];
	[getPos _best, _tName]
} else {
	//--- No enemy-held town resolvable (e.g. enemy down to just its base). Do NOT fall back to the true
	//--- HQ pos - that is the leak. Clamp the POSITION to the destination pulled HALF the HQ radius back
	//--- toward the team's own HQ (a vague "toward enemy lines" reference, never the base pin), label generic.
	private ["_ownHq","_cp"];
	_cp = _movePos;
	_ownHq = _mySide Call WFBE_CO_FNC_GetSideHQ;
	if (!isNull _ownHq) then {
		private ["_ehqNearest","_ehqD","_ehq2","_ox","_oy","_dx","_dy","_len","_pull"];
		//--- Direction from the true (hidden) destination back toward our own HQ; step the clamp _radius back
		//--- along it so the rendered point sits well outside the enemy base bubble.
		_ox = getPos _ownHq;
		_dx = (_ox select 0) - (_movePos select 0);
		_dy = (_ox select 1) - (_movePos select 1);
		_len = sqrt ((_dx * _dx) + (_dy * _dy));
		if (_len > _radius) then {
			_cp = [(_movePos select 0) + (_dx / _len) * _radius, (_movePos select 1) + (_dy / _len) * _radius, 0];
		} else {
			_cp = _ox;   //--- destination is basically between the bases; fall all the way back to our own HQ reference.
		};
	};
	[_cp, "enemy lines"]
};
