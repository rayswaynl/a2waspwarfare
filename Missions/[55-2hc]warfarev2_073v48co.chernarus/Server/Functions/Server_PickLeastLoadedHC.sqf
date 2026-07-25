/*
	Server_PickLeastLoadedHC.sqf -- single source of truth for "which HC do we delegate to".

	Returns the LEADER object of the live headless client that currently owns the FEWEST
	units, so delegation spreads roughly evenly across all registered HCs instead of the
	old blind `leader(_live select floor(random count _live))` coin-flip.

	WHY least-loaded (not random / round-robin):
	  - Load arrives as a SMALL number of LARGE atomic batches (whole-town activations of
	    merged groups, whole commander platoons). Blind random over only 2 HCs has high
	    variance and NEVER self-corrects because delegated units are sticky (no migration),
	    so early random luck compounds into a permanent 70-90% pile-up on one HC.
	  - Least-loaded reads CURRENT per-HC unit count every call, so once an HC gets heavy it
	    stops being chosen until the other catches up. Self-correcting by construction.

	HOW load is measured: routing is by `owner leader` (see Common_SendToClient.sqf), so an
	HC "owns" exactly the units whose `owner` equals `owner (leader hcGroup)`. We tally
	allUnits by owner ONCE on the server (no telemetry dependency, no 60s lag, accurate the
	instant a unit is created), then pick argmin. This is server-side and immediate.

	Ties (e.g. both HCs empty at warm-up) are broken RANDOMLY so the picker degrades
	gracefully to uniform-random when loads are genuinely equal, and never lock-steps.

	STICKY DELEGATION (WFBE_C_HC_DELEGATE_STICKY, default 0, feat-hc-sticky-delegation 2026-07-25):
	optional - pass the town object as the sole argument ([_town] Call ...) and, while the flag is
	armed, a still-live/still-healthy sticky HC recorded on that town (within the sticky window and
	under the load-balance guard ratio) is returned directly, WITHOUT re-running the argmin below.
	Flag off, or called with no argument (the other 7 call sites, unchanged unary `Call ...`), is
	byte-identical to the original always-argmin behaviour. See Init_CommonConstants.sqf for the
	full flag doc.

	Parameters: optional [_town] - town object whose sticky HC assignment to honour/update.
	            Omit (unary Call, as before) for callers with no per-town delegation concept.
	Returns: leader of the least-loaded (or sticky) live HC, or objNull if there is no live HC
	         (callers MUST check isNull and fall back / drop, exactly like before).
*/

private ["_hcs", "_live", "_owners", "_counts", "_o", "_idx", "_bestLoad", "_ties", "_pick", "_x",
	"_town", "_stickyOn", "_stickyOwner", "_stickyTs", "_stickyWindow", "_stickyIdx",
	"_stickyLoad", "_totalLoad", "_maxRatio"];

//--- Optional town argument: safe against BOTH the existing unary `Call ...` sites (where _this is
//--- undefined - isNil "_this" catches that without erroring) and the new `[_town] Call ...` site.
//--- All callers pass either nothing (unary) or a 1-element array, so `count _this` never needs an
//--- A3-only isEqualType type-check to stay safe here.
_town = objNull;
if !(isNil "_this") then {
	if (count _this > 0) then {
		if (!isNull (_this select 0)) then {_town = _this select 0};
	};
};

_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];

//--- Only LIVE HC groups: a stale registry entry (HC dropped between prunes) would route
//--- the delegation to a null leader and the AI would silently never spawn.
_live = [];
{
	//--- BUGFIX (2026-07-17, HC-founding zombie-picker): a registered HC group whose leader has
	//--- owner()==0 (disconnected, or its unit locality silently transferred to the server - see
	//--- Common_SendToClient.sqf's own "owner()==0 => drop, no publicVariableClient" guard) is NOT
	//--- a routable delegation target: any send to it is ALREADY silently dropped downstream. Such
	//--- a zombie entry still passes the isNull/alive test below and tallies ZERO owned units, so
	//--- the argmin picker would otherwise select it FOREVER once it appears (it always looks like
	//--- the least-loaded HC). Single-shot callers (AI_Commander_Teams / AI_Commander_Wildcard
	//--- delegate-aicom-team) have no fallback if that happens - unlike the townai/static-defence
	//--- callers, which round-robin past a bad slot. Excluding owner<=0 here can never regress a
	//--- delivery that used to work (Common_SendToClient already dropped it either way).
	if (!isNull _x && {!isNull leader _x} && {alive leader _x} && {(owner (leader _x)) > 0}) then {_live = _live + [_x]};
} forEach _hcs;

if (count _live == 0) exitWith {objNull};
if (count _live == 1) exitWith {leader (_live select 0)};

//--- Tally CURRENT units-per-owner ONCE. Each HC owns the units whose owner matches the
//--- owner of its leader (the same key Common_SendToClient routes on).
_owners = []; //--- parallel array: owner id of each live HC's leader
_counts = []; //--- parallel array: current owned-unit count for that owner id
{
	_owners set [_forEachIndex, owner (leader _x)];
	_counts set [_forEachIndex, 0];
} forEach _live;

{
	_o   = owner _x;
	_idx = _owners find _o;
	if (_idx >= 0) then {_counts set [_idx, (_counts select _idx) + 1]};
} forEach allUnits;

//--- STICKY: reuse the tally just taken above (no extra allUnits scan) to see whether this town's
//--- previously-delegated HC is still a valid pick. Byte-identical no-op when the flag is 0 or no
//--- town was passed in (_stickyIdx stays -1, both `if`s below never enter their then-block).
_stickyOn = (missionNamespace getVariable ["WFBE_C_HC_DELEGATE_STICKY", 0]) > 0;
_stickyIdx = -1;
if (_stickyOn && {!isNull _town}) then {
	_stickyOwner = _town getVariable ["wfbe_town_hc_owner", -1];
	_stickyTs = _town getVariable ["wfbe_town_hc_owner_ts", -1];
	_stickyWindow = missionNamespace getVariable ["WFBE_C_HC_DELEGATE_STICKY_WINDOW", 300];
	//--- Window check only; liveness ("gone/unhealthy") is the _owners find below - the sticky owner
	//--- can only be found there if it survived the SAME liveness filter _live was built with above.
	if (_stickyOwner > 0 && {(diag_tickTime - _stickyTs) < _stickyWindow}) then {
		_stickyIdx = _owners find _stickyOwner;
	};
};

if (_stickyIdx >= 0) then {
	//--- LOAD-BALANCE GUARD: never let stickiness concentrate load onto one HC over a long match.
	//--- Sticky HC's share of ALL currently-tallied HC-owned units must stay under the ceiling, or
	//--- stickiness is broken here and execution falls through to the normal argmin re-pick below.
	_stickyLoad = _counts select _stickyIdx;
	_totalLoad = 0;
	{_totalLoad = _totalLoad + _x} forEach _counts;
	_maxRatio = missionNamespace getVariable ["WFBE_C_HC_DELEGATE_STICKY_MAXRATIO", 0.65];
	if (_totalLoad == 0 || {(_stickyLoad / _totalLoad) <= _maxRatio}) exitWith {
		_town setVariable ["wfbe_town_hc_owner_ts", diag_tickTime];
		leader (_live select _stickyIdx)
	};
};

//--- argmin: find the minimum load, then collect ALL HC indices that tie at it.
_bestLoad = 1e10;
{
	if ((_counts select _forEachIndex) < _bestLoad) then {_bestLoad = _counts select _forEachIndex};
} forEach _live;

_ties = [];
{
	if ((_counts select _forEachIndex) <= _bestLoad) then {_ties = _ties + [_forEachIndex]};
} forEach _live;

//--- RANDOM tie-break among the equally-lightest HCs so that equal loads (warm-up) spread
//--- instead of always favouring the first registered HC, and so the picker never lock-steps.
_pick = _ties select (floor (random (count _ties)));

//--- STICKY: record this fresh pick as the town's new sticky HC (first delegation, expired window,
//--- dead sticky HC, or guard break all fall through to here). No-op write when the flag is off or
//--- no town was passed - harmless (matches the original zero-arg call sites, which never read it).
if (_stickyOn && {!isNull _town}) then {
	_town setVariable ["wfbe_town_hc_owner", _owners select _pick];
	_town setVariable ["wfbe_town_hc_owner_ts", diag_tickTime];
};

leader (_live select _pick)
