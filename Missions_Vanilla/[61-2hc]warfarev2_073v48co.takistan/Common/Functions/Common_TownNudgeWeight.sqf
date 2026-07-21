/*
	WFBE_CO_FNC_TownNudgeWeight - aggregated, TTL-decayed player town-nudge weight for ONE town.

	COMMAND V2 pillar (a). Players do not command: they suggest. This returns a small scalar the
	v2 fist scorer adds (times WFBE_C_CMD_TOWN_NUDGE_WEIGHT) to a town score, so a suggestion can
	break a near-tie between two candidate towns but can never force a strategically bad target.

	Owner decision packet 2026-07-18 (item 2): aggregation is sqrt(n) diminishing returns AND a
	hard safety ceiling. Both are applied here:
	  raw   = SUM over live records of (linear TTL decay 1..0) * record priority
	  units = raw min WFBE_C_CMD_TOWN_NUDGE_CAP        <- hard ceiling (owner: "hard safety ceiling")
	  out   = sqrt(units)                              <- diminishing returns (owner: "sqrt(n)")
	So one fresh nudge scores 1.00 units (weight x1.00), two score 1.41, and the ceiling at the
	default CAP of 3 is 1.73 - i.e. five players spamming one town cannot dwarf the supply and
	distance terms, and the whole term stays below WFBE_C_AICOM_GRUDGE_BONUS.

	Record shape is the unified nudge tuple: [type, scope, target, issuerUID, priority, t0]
	  type      "town"
	  scope     "side" | <group>   (team-scope nudges only bias their own team)
	  target    town object
	  issuerUID string            (cooldown / anti-abuse key, kept for receipts)
	  priority  scalar 0..1       (player-issued nudges are soft; reserved for future weighting)
	  t0        time stamp

	Params: [ town (OBJECT), nudgeRing (ARRAY), scope ("side" | GROUP) ]
	  nudgeRing is passed IN (read once per allocator tick by the caller, never re-read per town)
	  so this stays O(ring) per town with no getVariable in the hot loop and no per-frame scan.
	Returns: SCALAR >= 0 (0 when there is no live matching nudge).

	A2 OA 1.64: no params/pushBack/findIf; plain select indexing, guarded nil holes, lazy && {}.
*/
private ["_town","_ring","_scope","_ttl","_cap","_raw","_now","_units","_rec","_age","_dec","_sc"];
_town  = _this select 0;
_ring  = _this select 1;
_scope = _this select 2;

if (isNil "_town" || {isNull _town} || {isNil "_ring"} || {typeName _ring != "ARRAY"}) exitWith {0};
if ((count _ring) == 0) exitWith {0};

_ttl = missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE_TTL", 240];
if (_ttl <= 0) exitWith {0};
_cap = missionNamespace getVariable ["WFBE_C_CMD_TOWN_NUDGE_CAP", 3];
if (_cap <= 0) exitWith {0};

_now = time;
_raw = 0;
{
	//--- nil-hole guard: a ring slot can be nil after an eviction race; never select into it.
	if (!isNil "_x") then {
		_rec = _x;
		if ((typeName _rec == "ARRAY") && {(count _rec) >= 6}) then {
			_sc = _rec select 1;
			//--- scope match: a "side" record counts for the side aggregate; a team record counts only
			//--- for its own group. Comparing a STRING to a GROUP is never done - the typeName gates it.
			private "_scopeOk";
			_scopeOk = false;
			if (typeName _scope == "STRING") then {
				_scopeOk = (typeName _sc == "STRING") && {_sc == _scope};
			} else {
				_scopeOk = (typeName _sc == "GROUP") && {_sc == _scope};
			};
			if (_scopeOk && {(_rec select 2) == _town}) then {
				_age = _now - (_rec select 5);
				if (_age >= 0 && {_age < _ttl}) then {
					_dec = 1 - (_age / _ttl);           //--- linear decay to 0 across the TTL
					_raw = _raw + (_dec * (_rec select 4));
				};
			};
		};
	};
} forEach _ring;

if (_raw <= 0) exitWith {0};
_units = _raw min _cap;                          //--- HARD CEILING first (owner 2026-07-18)
sqrt (_units)                                    //--- then sqrt(n) diminishing returns
