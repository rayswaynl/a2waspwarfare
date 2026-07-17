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

	Parameters: none.
	Returns: leader of the least-loaded live HC, or objNull if there is no live HC
	         (callers MUST check isNull and fall back / drop, exactly like before).
*/

private ["_hcs", "_live", "_owners", "_counts", "_o", "_idx", "_bestLoad", "_ties", "_pick", "_x"];

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
leader (_live select _pick)
