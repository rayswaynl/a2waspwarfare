/*
	AI Commander - HC-team TOP-UP pass  [DRAFT - claude-gaming 2026-06-20, B58 soak]

	STATUS: DRAFT / NOT WIRED. This file is referenced by NOTHING in the live mission
	(no loader, no spawn, no FSM). Committing it changes ZERO live behaviour - it exists
	for AM review on branch claude/b57-soak-proposals. Do NOT add it to a loader until the
	HC-side consumer (below) is written and the whole path is live-verified.

	WHY: live CMDRSTAT shows unitsPerTeam dribbling to 4.9-7 (target band 8-12) because
	AI_Commander_Produce.sqf:63 skips wfbe_aicom_hc teams - i.e. 100% of live teams are
	NEVER refilled after founding. The founding-pad (B57) sets size AT founding; attrition
	then drags the live average below the floor with no recovery. Produce can't fix it:
	AIBuyUnit spawns the refill at a SERVER-side factory, but HC teams' units are LOCAL on
	the Headless Client, so the refill must be created HC-side and join-ed there (same
	locality rule Common_RunCommanderTeam.sqf / Common_CreateTeam.sqf rely on).

	DESIGN (two halves):
	  (A) THIS server worker: scan a side's HC teams, find ONE under-strength team that is
	      safe to reinforce (not in contact, near a friendly supply town), charge funds, and
	      hand the HC a top-up request via the existing RequestSpecial / HandleSpecial bus
	      that the create/end/heading messages already use.
	  (B) HC-side consumer (TO WRITE - see the commented spec at the bottom): on
	      "aicom-team-topup" the owning HC createUnit's the shortfall NEXT TO the team leader
	      and joinSilent's them into the group, mirroring Common_CreateTeam's spawn pass.

	A2-OA 1.64 SAFE:
	  - no isEqualType / isEqualTo / worldSize / forceFollowRoad (typeName + string compares only);
	  - NO sim-gating and NO distance-gating that could freeze AI: this worker only ADDS units;
	    it never stops, sleeps, or sim-disables a team. Teams keep their live orders untouched.
	  - does NOT touch antistack.
	  - default-OFF behind WFBE_C_AICOM_HC_TOPUP_ENABLE (absent => false => early exit), so even
	    if someone wires it, it is inert until explicitly switched on.
	  - throttled to ONE team per call (avoids the town-activation spike the old per-group HC
	    pick caused) - the supervisor would call it on a slow cadence, like Produce.

	Parameter: _this = side.
*/

private ["_side","_sideText","_logik","_enable","_teams","_sizeMin","_floor","_funds",
         "_perUnitCost","_picked","_team","_ldr","_aliveNow","_nearSupply","_myID",
         "_shortBy","_classes","_template","_templates","_type","_man","_want","_inContact","_isArmour"];

//--- HARD GATE: inert unless explicitly enabled (absent variable => false).
_enable = missionNamespace getVariable ["WFBE_C_AICOM_HC_TOPUP_ENABLE", false];
if (typeName _enable != "BOOL" || {!_enable}) exitWith {};

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

_sizeMin = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MIN", 8];
//--- reinforce only teams that have fallen clearly below the band (not every 7/8 squad).
_floor = round (_sizeMin * (missionNamespace getVariable ["WFBE_C_AICOM_HC_TOPUP_FRAC", 0.6]));

_myID = (_side) Call WFBE_CO_FNC_GetSideID;
_templates = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];

//--- Pick ONE eligible team this call (throttle = 1/team per cadence).
_picked = objNull;
{
	_team = _x;
	if (isNull _picked && {!isNull _team}) then {
		//--- HC-founded teams only (server-local teams are handled by Produce already).
		if (_team getVariable ["wfbe_aicom_hc", false]) then {
			_ldr = leader _team;
			if (!isNull _ldr && {alive _ldr}) then {
				_aliveNow = {alive _x} count (units _team);
				//--- Skip MBT / attack-heli teams: their punch is the hull+crew, never pad with rifles.
				//--- (A non-infantry template is identified the same way Produce does: any Tank in it.)
				_type = _team getVariable ["wfbe_teamtype", -1];
				_isArmour = false;
				if (!isNil "_templates" && {_type >= 0} && {_type < count _templates}) then {
					{ if (_x isKindOf "Tank") exitWith {_isArmour = true} } forEach (_templates select _type);
				};
				//--- In-contact guard: do NOT reinforce a team that is mid-firefight (cosmetic pop-in
				//--- next to players/enemies + it should be fighting, not waiting on spawns). Behaviour
				//--- COMBAT is the A2-safe "in contact" read used elsewhere in this codebase.
				_inContact = (behaviour _ldr) == "COMBAT";
				//--- Near a friendly supply town (resupply makes sense at the front/rear, not in open field).
				_nearSupply = false;
				{
					if (((_x getVariable ["sideID",-1]) == _myID) && {(_ldr distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_HC_TOPUP_RANGE", 900])}) exitWith {_nearSupply = true};
				} forEach towns;

				if (!_isArmour && {!_inContact} && {_nearSupply} && {_aliveNow > 0} && {_aliveNow < _floor}) then {
					_picked = _team;
				};
			};
		};
	};
} forEach _teams;

if (isNull _picked) exitWith {};

//--- Compute the shortfall class list. Top up toward SIZE_MIN (clamped by the per-side AI cap
//--- the same way Produce.sqf:123 does). Pad with the LAST Man-class in the team template
//--- (a basic rifleman) - never duplicate a vehicle (mirrors Produce.sqf:155-157 FILL-TO-FLOOR).
_team = _picked;
_aliveNow = {alive _x} count (units _team);
_want = (_sizeMin min (missionNamespace getVariable "WFBE_C_AI_MAX"));
_shortBy = _want - _aliveNow;
if (_shortBy <= 0) exitWith {};

_man = "";
_type = _team getVariable ["wfbe_teamtype", -1];
if (!isNil "_templates" && {_type >= 0} && {_type < count _templates}) then {
	_template = _templates select _type;
	{ if (_x isKindOf "Man") then {_man = _x} } forEach _template;   //--- last Man-class = basic dismount.
};
if (_man == "") exitWith {};   //--- all-vehicle template => nothing to pad with (armour exempt anyway).

//--- Funds gate (charge up-front for the batch; per-unit price via the canonical query lookup).
_perUnitCost = 0;
private ["_ud"]; _ud = missionNamespace getVariable _man;
if (!isNil "_ud") then {_perUnitCost = _ud select QUERYUNITPRICE};
_funds = (_side) Call GetAICommanderFunds;
if (_perUnitCost > 0 && {_funds < (_perUnitCost * _shortBy)}) then {
	//--- Trim the batch to what we can afford rather than skip entirely (still >=1).
	_shortBy = floor (_funds / _perUnitCost);
};
if (_shortBy <= 0) exitWith {};

_classes = [];
for "_i" from 1 to _shortBy do { _classes = _classes + [_man] };
if (_perUnitCost > 0) then { [_side, -(_perUnitCost * (count _classes))] Call ChangeAICommanderFunds };

//--- Hand the top-up to the OWNING machine. HC teams are remote, so route via the same bus the
//--- create/end/heading messages use; the server-local fallback (no HC) joins directly.
//--- [team, classnames] -> consumer createUnit's each near the leader + joinSilent into _team.
if (isServer && {local (leader _team)}) then {
	//--- server-local team (HC down / fallback path): do it inline, HC-side spec mirrors this.
	["aicom-team-topup", [_team, _classes]] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-topup", [_team, _classes]]] Call WFBE_CO_FNC_SendToServer; //--- server -> all; the owning HC acts on locality.
};

diag_log ("AICOMSTAT|v1|EVENT|" + str _myID + "|" + str (round (time / 60)) + "|HC_TOPUP|team=" + (str _team) + "|alive=" + str _aliveNow + "|add=" + str (count _classes) + "|class=" + _man);
["INFORMATION", Format ["AI_Commander_HCTopUp.DRAFT.sqf: [%1] top-up team [%2] alive=%3 -> +%4 x %5 (floor=%6).", _sideText, _team, _aliveNow, count _classes, _man, _floor]] Call WFBE_CO_FNC_AICOMLog;

/* ----------------------------------------------------------------------------------------
   (B) HC-SIDE CONSUMER - TO WRITE, then wire BOTH halves and live-verify before enabling.

   In Server/Functions/HandleSpecial.sqf add a case "aicom-team-topup" => [team, classes]:
   only act where the team is LOCAL (the owning HC). Spawn each class next to the leader and
   join it in, reusing the Common_CreateTeam idiom so locality + skills stay consistent:

       _team = _p select 0; _classes = _p select 1;
       if (isNull _team || {!local (leader _team)}) exitWith {};   //--- only the owner acts
       _ldr = leader _team; _sp = _ldr modelToWorld [0,-6,0];
       { _u = (group _ldr) createUnit [_x, _sp, [], 8, "FORM"]; _u setSkill ... ;
         [_u] joinSilent _team; } forEach _classes;               //--- joinSilent => no leader churn

   Then have AI_Commander.sqf call this worker on a SLOW gated cadence (like Produce), and set
   WFBE_C_AICOM_HC_TOPUP_ENABLE=true only after watching unitsPerTeam recover toward 8-12 in a
   test round. Keep the 1-team/call throttle to avoid a spawn/town-activation spike.

   NO-FROZEN-AI NOTE: this path only ADDS units and joins them; it never stops the team, never
   sim-disables, never distance-gates the team's own behaviour. The newly-joined units inherit
   the group's live waypoints/orders, so nobody stands idle. A2-OA safe: createUnit + joinSilent
   + setSkill are all 1.64 primitives (Common_CreateTeam uses the same).
---------------------------------------------------------------------------------------- */
