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
	"_stickyLoad", "_totalLoad", "_maxRatio", "_fpsReg", "_hcKey", "_fidx", "_slot", "_fresh"];

//--- Optional town argument. A unary `Call ...` does NOT clear _this: the called scope INHERITS
//--- the CALLER's _this. AI_Commander_Teams.sqf's own _this IS the side, and the town / static-
//--- defence / side-patrol callers hold arrays whose element 0 is a side - so `isNil "_this"` is
//--- FALSE at every unary call site and the reads below threw there (`count _this` -> "Type Side,
//--- expected Array,Config entry"; `isNull (_this select 0)` -> "Type Side, expected Object,..."),
//--- aborting this picker before it ever selected an HC. It then returned nil, and
//--- Common_SendToClient.sqf's `owner (_pvf select 0)` read 0 for that nil target and DROPPED the
//--- delegation. Live wave0725c 2026-07-26: 121/121 SendToClient HandleSpecial sends dropped, zero
//--- `delegate-aicom-team` ever reached an HC, every HCDISPATCH aged out to ack-timeout and both
//--- commanders sat at foundedTeams=0 with ~520k unspent funds for the whole match.
//--- Guard on typeName (A2-OA-safe; the A3-only isEqualType is banned in this fork) AND only parse
//--- the argument when the sticky feature is actually armed, so flag-off is genuinely byte-
//--- identical to the pre-sticky always-argmin behaviour the header above promises.
_stickyOn = (missionNamespace getVariable ["WFBE_C_HC_DELEGATE_STICKY", 0]) > 0;
_town = objNull;
if (_stickyOn && {!isNil "_this"} && {typeName _this == "ARRAY"} && {count _this > 0}) then {
	private ["_t0"];
	_t0 = _this select 0;
	if (typeName _t0 == "OBJECT" && {!isNull _t0}) then {_town = _t0};
};

_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
_fpsReg = missionNamespace getVariable ["WFBE_HCFPS_REG", []];

//--- Only LIVE HC groups: a stale registry entry (HC dropped between prunes) would route
//--- the delegation to a dead channel and silently lose the AI command. owner()>0 is not enough:
//--- A2 can retain the dropped HC body/group and its old owner id while the engine has already
//--- removed the network channel. HC_StatLoop is unconditional and refreshes this server-side
//--- row every 60s, so require its same <=150s freshness window before making the group routable.
_live = [];
{
	_fresh = false;
	if (!isNull _x && {!isNull leader _x} && {alive leader _x} && {(owner (leader _x)) > 0}) then {
		_hcKey = Format ["HC-%1", netId (leader _x)];
		_fidx = -1;
		{ if ((_x select 0) == _hcKey) exitWith {_fidx = _forEachIndex} } forEach _fpsReg;
		if (_fidx >= 0) then {
			_slot = _fpsReg select _fidx;
			if ((time - (_slot select 2)) <= 150) then {_fresh = true};
		};
	};
	if (_fresh) then {_live = _live + [_x]};
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
//--- _stickyOn is resolved in the argument prologue at the top of this file (it now gates the
//--- optional-argument parse as well), so it is not re-read here.
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
