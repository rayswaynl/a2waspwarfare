/*
	Run one AI-commander combat team: create it and execute the brain's orders locally.
	feat/ai-commander V0.3. Runs on a HEADLESS CLIENT (delegate-aicom-team) or on the
	server as fallback - the whole team lifecycle stays on the creating machine so
	waypoints keep locality (the proven side-patrol pattern).

	 Parameters: [ sideID, template (unit class array), spawnPos ]

	The server brain communicates through ONE public group variable:
	  wfbe_aicom_order = [seq, mode, pos]   (mode: "towns-target" | "defense")
	The driver applies an order once per seq bump: MOVE to pos, SAD on arrival
	(towns-target) or a tight defensive SAD at pos (defense). Team wipe releases
	the slot via aicom-team-ended.
*/

Private ["_townOrderArr","_chkVeh","_sideID","_template","_pos","_side","_team","_retVal","_units","_vehicles","_ldr","_alive","_order","_seq","_lastSeq","_mode","_dest","_arrived",
         "_captureDone","_townObj","_townCamps","_campObj","_campRange",
         "_liveUnits","_dismounted","_veh","_u","_settleTimeout","_hasCargo",
         "_townCenter","_capRange","_footInf","_holdEnd","_resNear","_enemyNear","_townFlipped",
         "_unheldCamps","_campFirstEnd","_nearCamp","_campTgtPos",
         "_airVeh","_grndVehs","_footPax","_cargoSeats","_lifted","_walkers","_lzPos","_flat","_pilot","_crewVeh","_pax","_abVeh","_left","_dropPos","_cv","_dismountDest","_cn","_ud","_heliCost","_truckSeq",
         "_rmHasVeh","_rmRoute","_rmWPs","_usTier",
         "_govLdr","_govNz","_govSteep","_govStrk","_govWantSlow","_govIsSlow"];

_sideID = _this select 0;
_template = _this select 1;
_pos = _this select 2;
_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

_pos = [_pos, 30, 120] Call WFBE_CO_FNC_GetRandomPosition;
_pos = [_pos, 40] Call WFBE_CO_FNC_GetEmptyPosition;

_team = [_side, "aicom"] Call WFBE_CO_FNC_CreateGroup;
_retVal = [_template, _pos, _side, true, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
_units = _retVal select 0;
_vehicles = _retVal select 1;
_team = _retVal select 2;

if (isNull _team || {((count _units) + (count _vehicles)) == 0}) exitWith {
	["WARNING", Format ["Common_RunCommanderTeam.sqf: [%1] team creation failed - releasing the slot.", _side]] Call WFBE_CO_FNC_AICOMLog;
	if (isServer) then {
		["aicom-team-ended", _sideID, grpNull] Call HandleSpecial;
	} else {
		["RequestSpecial", ["aicom-team-ended", _sideID, grpNull]] Call WFBE_CO_FNC_SendToServer;
	};
};

_team allowFleeing 0;
//--- STANCE (task #1): set an aggressive posture ONCE at founding so the team is "advance and
//--- engage" before any order. AWARE+RED+FULL = fast, will-engage transit (not banzai - AWARE
//--- still uses cover/returns fire sanely). Covers infantry-only + pure-armour teams whose props
//--- would otherwise stay engine-default. The on-objective SAD waypoints still flip to COMBAT/WEDGE.
_team setCombatMode "RED"; _team setBehaviour "AWARE"; _team setSpeedMode "FULL";
_team setVariable ["wfbe_aicom_hc", true, true];   //--- brain: do not Produce/waypoint this one directly.
_team setVariable ["wfbe_queue", [], false];

if (isServer) then {
	["aicom-team-created", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-created", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] commander team spawned (%2 units, %3 vehicles).", _side, count _units, count _vehicles]] Call WFBE_CO_FNC_AICOMLog;

//--- ARROW-HEADING FEED (task #3, verify BLOCKER fix): the order-execution loop below
//--- sleeps 20s and, mid-capture, blocks on sleep 75 / sleep 25 - far too coarse and starved
//--- to drive a responsive direction arrow. So DO NOT push headings from inside that loop.
//--- Instead run this tiny self-contained loop on its own ~8s cadence. It reads the team's
//--- current objective bearing (leader -> order destination, slot 2 of wfbe_aicom_order) and
//--- ships ["aicom-team-heading",[team, dir]] to the server via the same SendToServer /
//--- RequestSpecial path the create/end messages use. The server re-broadcasts only when the
//--- arrow moved >7 deg. Exits when the team is null or wiped (mirrors the marker lifecycle).
[_team, _side] Spawn {
	Private ["_hTeam","_hSide","_hOrder","_hDest","_hLdr","_hDir"];
	_hTeam = _this select 0;
	_hSide = _this select 1;
	while {!WFBE_GameOver && !isNull _hTeam && {(count ((units _hTeam) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
		_hLdr = leader _hTeam;
		if (!isNull _hLdr && {alive _hLdr}) then {
			//--- Default: face the way the leader is actually pointing.
			_hDir = getDir _hLdr;
			//--- Prefer the objective bearing: leader -> order destination pos (slot 2).
			//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
			_hOrder = _hTeam getVariable "wfbe_aicom_order";
			if (!isNil "_hOrder" && {count _hOrder >= 3}) then {
				_hDest = _hOrder select 2;
				if (!isNil "_hDest" && {(_hLdr distance _hDest) > 5}) then {
					_hDir = ((_hDest select 0) - ((getPosATL _hLdr) select 0)) atan2 ((_hDest select 1) - ((getPosATL _hLdr) select 1)); //--- A2-safe bearing leader->dest (binary getDir is A3-only).
				};
			};
			if (isServer) then {
				["aicom-team-heading", [_hTeam, _hDir]] Call HandleSpecial;
			} else {
				["RequestSpecial", ["aicom-team-heading", [_hTeam, _hDir]]] Call WFBE_CO_FNC_SendToServer;
			};
		};
		sleep 8;
	};
};

//--- HC locality note: this file is spawned exclusively via delegate-aicom-team ->
//--- HandleSpecial.sqf on the Headless Client (AI_Commander_Teams.sqf line 171).
//--- The created group is local to the HC for its entire lifetime, so waypoints,
//--- doMove, assignAsCargo, and orderGetIn all execute with correct locality here.

//--- Order-execution loop: apply each new order seq from the server brain.
_lastSeq = -1;
_arrived = false;
_captureDone = false;     //--- guard: run dismount-capture phase only once per order
_alive = true;

//--- ===================================================================
//--- AIR-INSERTION (task #11) — OWN-HELI architecture. Runs ONCE before the
//--- order loop. Fires only for teams whose OWN template already spawned a
//--- troop-capable AIR transport (e.g. Build-29 UH60M/MV22/Mi17/CH-47F air
//--- squads). We use the team's OWN heli (already spawned, already piloted by
//--- Common_CreateTeam crew pass) — NO second transport is created. The team's
//--- FOOT infantry load into that heli (respect live emptyPositions 'cargo');
//--- overflow walks by ground. Teams with no air transport skip this entirely.
//---
//--- FROZEN-#1 GUARD: ground vehicles + their crews are NOT blocked on the air
//--- flag. They receive an immediate concurrent MOVE toward the objective here,
//--- and the order loop below re-tasks the WHOLE team (MOVE then SAD) regardless.
//--- No crewed hull ever sits un-ordered.
_airVeh   = objNull;
_grndVehs = [];
{
	if (!isNull _x && {alive _x}) then {
		if (_x isKindOf "Air" && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "transportSoldier")) > 0} && {isNull _airVeh}) then {
			_airVeh = _x;
		} else {
			_grndVehs = _grndVehs + [_x];
		};
	};
} forEach _vehicles;

if (!isNull _airVeh && {alive _airVeh} && {!isNull (driver _airVeh)} && {alive (driver _airVeh)}) then {
	//--- Concurrent ground roll-out: never leave crewed hulls idle during the lift.
	{
		if (!isNull _x && {alive _x} && {!isNull (driver _x)}) then {(driver _x) doMove _pos};
	} forEach _grndVehs;

	//--- Load the team's FOOT infantry into the team's own heli (cargo seats only).
	_footPax = [];
	{
		if (alive _x && {vehicle _x == _x} && {_x != (driver _airVeh)}) then {_footPax = _footPax + [_x]};
	} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);

	_cargoSeats = _airVeh emptyPositions "cargo";
	_lifted  = [];
	_walkers = [];
	{
		if (count _lifted < _cargoSeats) then {
			_x assignAsCargo _airVeh;
			[_x] orderGetIn true;
			_lifted = _lifted + [_x];
		} else {
			_walkers = _walkers + [_x];
		};
	} forEach _footPax;

	//--- Overflow that did not fit walks by ground NOW (never idle).
	{if (alive _x) then {_x doMove _pos}} forEach _walkers;

	if (count _lifted > 0) then {
		//--- Pick an LZ: prefer a flat spot at the objective; else para-drop fallback.
		_lzPos = _pos;
		_flat  = _pos isFlatEmpty [12, 0, 2, 12, 0, false, objNull];
		if (count _flat > 0) then {_lzPos = _flat} else {_lzPos = _pos};

		//--- Pre-compute the heli's build cost NOW (clean scope) so the disembark
		//--- Spawn can REFUND it to the AI-commander treasury after a successful
		//--- fly-off to the map edge. Mirrors the canonical price lookup used by
		//--- AI_Commander_Teams.sqf L165 / AI_Commander_Wildcard.sqf L716:
		//--- (missionNamespace getVariable (typeOf _veh)) select QUERYUNITPRICE.
		_heliCost = 0;
		_ud = missionNamespace getVariable (typeOf _airVeh);
		if (!isNil "_ud") then {_heliCost = _ud select QUERYUNITPRICE};
		//--- Mark this hull as an AI-commander transport so the refund path can
		//--- never refund a player-owned or non-aicom heli.
		_airVeh setVariable ["wfbe_aicom_transport", true, true];

		//--- Fly the heli to the objective and unload. doMove + flyInHeight, then
		//--- land+disembark when close (heli-land) OR para-eject if no flat LZ.
		[_airVeh, _lzPos, _flat, _lifted, _team, _pos, _side, _sideID, _heliCost] Spawn {
			private ["_h","_lz","_fl","_pax","_tm","_obj","_t0","_sd","_sID","_cost","_edge","_wsz","_ex","_ey","_offPos","_hcrew"];
			_h    = _this select 0;
			_lz   = _this select 1;
			_fl   = _this select 2;
			_pax  = _this select 3;
			_tm   = _this select 4;
			_obj  = _this select 5;
			_sd   = _this select 6;
			_sID  = _this select 7;
			_cost = _this select 8;
			//--- Let everyone board first.
			_t0 = time + 30;
			waitUntil {sleep 1; time > _t0 || {({alive _x && vehicle _x == _h} count _pax) >= ({alive _x} count _pax)}};
			if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
				//--- Heli lost mid-lift: any survivors still aboard/around get an unconditional move.
				{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
			};
			(driver _h) doMove _lz;
			_h flyInHeight 60;
			//--- Run in until near the LZ (or timeout / loss).
			_t0 = time + 240;
			waitUntil {sleep 2; time > _t0 || isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)} || {(_h distance _lz) < 120}};
			if (isNull _h || {!alive _h} || {isNull (driver _h)} || {!alive (driver _h)}) exitWith {
				{if (alive _x) then {if (vehicle _x != _x) then {unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;
			};
			if (count _fl > 0) then {
				//--- Flat LZ: command a real landing and disembark.
				_h land "GET OUT";
				_h flyInHeight 0;
				_t0 = time + 40;
				waitUntil {sleep 1; time > _t0 || {(getPosATL _h) select 2 < 1.5}};
				{if (alive _x && {vehicle _x == _h}) then {unassignVehicle _x; [_x] orderGetIn false}} forEach _pax;
			} else {
				//--- No flat LZ: para-drop over the objective (eject pattern, Support_Paratroopers).
				_h flyInHeight (120 + random 20);
				{
					if (alive _x && {vehicle _x == _h}) then {
						unassignVehicle _x;
						_x action ["EJECT", _h];
						sleep 0.85;
					};
				} forEach _pax;
			};
			//--- GUARD: dropped pax always get an unconditional ground move to the objective
			//--- (the order loop will then fold them into the team MOVE/SAD).
			{if (alive _x) then {_x doMove _obj}} forEach _pax;

			//--- HELI FLY-OFF + REFUND (user request): the empty team transport now flies
			//--- to the NEAREST MAP EDGE and, on reaching off-map ALIVE, is deleted and its
			//--- build cost is REFUNDED to the side's AI-commander treasury (server-routed).
			//--- If it is destroyed before reaching the edge, NO refund. Player/non-aicom
			//--- helis are guarded out via the wfbe_aicom_transport flag set at lift time.
			if (!isNull _h && {alive _h} && {!isNull (driver _h)} && {alive (driver _h)} && {_h getVariable ["wfbe_aicom_transport", false]}) then {
				//--- Clamp the heli's exit toward the CLOSEST of the four map edges (worldSize box).
				_wsz = 15360;  //--- A2-fix 2026-06-14: worldSize is A3-only in A2 OA (latent bug, fired on heli off-map exit); Chernarus = 15360
				_ex  = (getPos _h) select 0;
				_ey  = (getPos _h) select 1;
				//--- distance to each edge: x=0, x=worldSize, y=0, y=worldSize.
				_offPos = [_ex, _ey, 0];
				//--- Pick the nearest edge explicitly (A2-safe, no isEqualTo dependency).
				if (_ex <= (_wsz - _ex) && {_ex <= _ey} && {_ex <= (_wsz - _ey)}) then {
					_offPos = [-200, _ey, 0];               //--- nearest = west edge (x=0)
				} else {
					if ((_wsz - _ex) <= _ey && {(_wsz - _ex) <= (_wsz - _ey)}) then {
						_offPos = [_wsz + 200, _ey, 0];     //--- nearest = east edge (x=worldSize)
					} else {
						if (_ey <= (_wsz - _ey)) then {
							_offPos = [_ex, -200, 0];       //--- nearest = south edge (y=0)
						} else {
							_offPos = [_ex, _wsz + 200, 0]; //--- nearest = north edge (y=worldSize)
						};
					};
				};
				_h flyInHeight (90 + random 30);
				(driver _h) doMove _offPos;
				//--- Wait until it reaches/crosses the edge (off-map) OR is lost. Cap ~6 min.
				_t0 = time + 360;
				waitUntil {sleep 3; time > _t0 || isNull _h || {!alive _h} || {((getPos _h) select 0) < 0} || {((getPos _h) select 0) > _wsz} || {((getPos _h) select 1) < 0} || {((getPos _h) select 1) > _wsz}};
				//--- REFUND ONLY if it reached the edge ALIVE. Destroyed-en-route = no refund.
				if (!isNull _h && {alive _h} && {(((getPos _h) select 0) < 0) || (((getPos _h) select 0) > _wsz) || (((getPos _h) select 1) < 0) || (((getPos _h) select 1) > _wsz)} && {_h getVariable ["wfbe_aicom_transport", false]}) then {
						private ["_htype"];
						_htype = typeOf _h;          //--- capture BEFORE delete (typeOf of a deleted obj is "").
					_hcrew = crew _h;
					{deleteVehicle _x} forEach _hcrew;
					deleteVehicle _h;
					if (_cost > 0) then {
						if (isServer) then {
							["aicom-heli-refunded", _sID, _cost] Call HandleSpecial;
						} else {
							["RequestSpecial", ["aicom-heli-refunded", _sID, _cost]] Call WFBE_CO_FNC_SendToServer;
						};
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team transport %2 flew off-map, deleted + refunded $%3.", _sd, _htype, _cost]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			};
		};
		["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] AIR-INSERT via own %3 (lifted %4, walked %5).", _side, _team, typeOf _airVeh, count _lifted, count _walkers]] Call WFBE_CO_FNC_AICOMLog;
	};
};
//--- ===================================================================

while {!WFBE_GameOver && _alive} do {
	_alive = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	if (_alive) then {
		//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
		_order = _team getVariable "wfbe_aicom_order";
		if (isNil "_order") then {_order = []};
		if (count _order >= 3) then {
			_seq = _order select 0;
			_mode = _order select 1;
			_dest = _order select 2;

			if (_seq != _lastSeq) then {
				//--- Fresh order: head out.
				_lastSeq = _seq;
				_arrived = false;
				_captureDone = false;

				//--- REAL UNSTUCK (task #14/#16): if this fresh order is a STUCK re-issue
				//--- (server bumped wfbe_aicom_unstuck > 0 because the team sat parked far
				//--- from target, not in contact), the bare re-route below is not enough for
				//--- a hull physically wedged at base (distStart=0). Escalate by strike tier
				//--- BEFORE laying the new route, HC-side where the units are local:
				//---   Tier 1: zero the lead hull's velocity + short reverse to break the wedge.
				//---   Tier 2: rely on the fresh ROAD route below (re-snapped from current pos).
				//---   Tier 3 (>=3): last-resort tiny teleport of the lead hull onto the nearest
				//---           clear non-water road node - ONLY when no player is within 300 m
				//---           (MEMORY guardrail: never a player-visible teleport / frozen AI).
				//--- Every tier still ends in the road route below = the unit always holds a move.
				_usTier = _team getVariable "wfbe_aicom_unstuck";
				if (isNil "_usTier") then {_usTier = 0};
				if (_usTier > 0) then {
					[_team, _usTier, _side] Spawn {
						private ["_uTeam","_uTier","_uSide","_uLdr","_uVeh","_uNode","_uRds","_uPlayerNear"];
						_uTeam = _this select 0;
						_uTier = _this select 1;
						_uSide = _this select 2;
						_uLdr  = leader _uTeam;
						if (isNull _uLdr || {!alive _uLdr}) exitWith {};
						_uVeh = vehicle _uLdr;
						//--- Tier 1: break a physical wedge on the lead hull.
						if (!isNull _uVeh && {_uVeh != _uLdr} && {alive _uVeh} && {canMove _uVeh}) then {
							_uVeh setVelocity [0,0,0];
							_uLdr doMove (_uVeh modelToWorld [0,-14,0]); //--- short reverse-ish nudge.
							sleep 4;
						};
						//--- Tier 3: last-resort teleport-nudge to the nearest clear road node,
						//--- only if no player is close enough to witness it.
						if (_uTier >= 3 && {!isNull _uVeh} && {alive _uVeh}) then {
							_uPlayerNear = false;
							{ if (isPlayer _x && {(_x distance _uVeh) < 300}) then {_uPlayerNear = true} } forEach playableUnits;
							if (!_uPlayerNear) then {
								_uRds = (getPos _uVeh) nearRoads 150;
								if (count _uRds > 0) then {
									_uNode = [getPos _uVeh, _uRds] Call WFBE_CO_FNC_GetClosestEntity;
									if (!isNull _uNode && {!surfaceIsWater (getPos _uNode)}) then {
										_uVeh setVelocity [0,0,0];
										_uVeh setPos (getPos _uNode);
										["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] TIER3 unstuck teleport-nudge to road node.", _uSide, _uTeam]] Call WFBE_CO_FNC_AICOMLog;
									};
								};
							};
						};
					};
				};

				//--- ROAD-MARCH (task #14/#16): the old single bare 'MOVE' to the raw town
				//--- center used EMPTY squad-props, so the engine defaulted armour/trucks to
				//--- AWARE->COMBAT/WEDGE cross-country - A2 PFM's worst case (distStart=0 at
				//--- base). Now: if this team has any ground VEHICLE, lay a ROAD-NODE chain
				//--- (broadcast in wfbe_aicom_route by AssignTowns) with COLUMN/NORMAL props
				//--- and forceFollowRoad on each vehicle, so the convoy takes lanes the engine
				//--- can drive; a final MOVE near the objective hands off to the arrival branch
				//--- which flips to COMBAT/WEDGE SAD. Pure-infantry teams keep the simple MOVE.
				_rmHasVeh = false;
				{ if (!isNull _x && {alive _x} && {!(_x isKindOf "Air")} && {canMove _x}) then {_rmHasVeh = true} } forEach _vehicles;

				if (_rmHasVeh && {(leader _team) distance _dest > 700}) then {
					//--- Road convoy: AWARE+COLUMN road-march posture for the long leg. A2-fix (2026-06-14):
					//--- the A3-only forceFollowRoad was removed (it throws "Unknown operation" on OA); the
					//--- road-bias comes from the road-SNAPPED MOVE nodes below + COLUMN formation (the same
					//--- A2 idiom Server_AI_SetTownAttackPath uses).
					_team setBehaviour "AWARE";
					_team setCombatMode "RED";        //--- STANCE (task #1): advance-and-engage on the march (was YELLOW).
					_team setFormation "COLUMN";
					_team setSpeedMode "FULL";         //--- STANCE (task #1): full road-march speed (was NORMAL).

					//--- Pull the road-node chain the server snapped for this seq (may be empty).
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_rmRoute = _team getVariable "wfbe_aicom_route";
					if (isNil "_rmRoute") then {_rmRoute = []};

					//--- Build the waypoint list: each road node as a COLUMN/NORMAL MOVE, then a
					//--- final MOVE on the destination so the arrival branch (leader<200m) trips.
					_rmWPs = [];
					{
						_rmWPs = _rmWPs + [[_x, 'MOVE', 40, 30, [], [], ["AWARE","RED","","FULL"]]];  //--- STANCE (task #1): RED/FULL advance-and-engage (was YELLOW/NORMAL). A2-fix 2026-06-14: inherit-formation (was COLUMN-locked) + wider completion 30 so columns open through chokepoints instead of bunching
					} forEach _rmRoute;
					_rmWPs = _rmWPs + [[_dest, 'MOVE', 50, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]];  //--- STANCE (task #1): RED/FULL final-approach (was YELLOW/NORMAL).
					[_team, true, _rmWPs] Spawn WFBE_CO_FNC_WaypointsAdd;
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4 ROAD-MARCH (%5 road nodes).", _side, _team, _seq, _mode, count _rmRoute]] Call WFBE_CO_FNC_AICOMLog;
				} else {
					//--- Short leg or pure infantry: direct cross-country MOVE (A2 PFM handles
					//--- short overland fine, and foot squads should not be road-locked).
					//--- (A2-fix: removed the A3-only forceFollowRoad clear; short legs were never road-locked.)
					[_team, _dest, 'MOVE', 50] Spawn WFBE_CO_FNC_WaypointSimple;
					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4.", _side, _team, _seq, _mode]] Call WFBE_CO_FNC_AICOMLog;
				};
			} else {
				//--- CAREFUL-GEAR GOVERNOR (owner refinement, layered on the 20s loop):
				//--- the road-march already drives transit FAST (AWARE/NORMAL, never LIMITED/
				//--- COMBAT), so the DEFAULT stays NORMAL. We only DOWNSHIFT to LIMITED while
				//--- EITHER (a) the lead hull sits on a steep slope (engine grade-crawl zone, a
				//--- careful gear keeps it from sliding/grinding) OR (b) a stuck-strike is active
				//--- (wfbe_aicom_unstuck > 0). Snap back to NORMAL the instant both clear. The
				//--- strike side auto-reverts because AssignTowns resets the strike to 0 on
				//--- progress; the slope side reverts next tick once the hull is back on flat.
				//--- A2-safe: surfaceNormal + setSpeedMode "LIMITED"/"NORMAL" (same primitive
				//--- AI_TownPatrol.sqf uses). Orthogonal to waypoints - never re-lays the route,
				//--- formation, behaviour props, or the 3-tier unstuck. Hysteresis flag fires
				//--- setSpeedMode exactly once per state transition, not every tick.
				//--- MEMORY guardrail: LIMITED still MOVES - never a freeze / standing-still AI.
				_govLdr = leader _team;
				if (!isNull _govLdr && {alive _govLdr}) then {
					//--- Sample the VEHICLE pos (the hull is what climbs); leader rides the hull.
					_govNz   = (surfaceNormal (getPos (vehicle _govLdr))) select 2; //--- 1.0=flat, lower=steeper.
					_govSteep = _govNz < (missionNamespace getVariable ["WFBE_C_AICOM_SLOPE_Z", 0.93]);
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_govStrk = _team getVariable "wfbe_aicom_unstuck";
					if (isNil "_govStrk") then {_govStrk = 0};
					_govWantSlow = _govSteep || {_govStrk > 0};
					_govIsSlow = _team getVariable "wfbe_aicom_gearslow";
					if (isNil "_govIsSlow") then {_govIsSlow = false};
					if (_govWantSlow && {!_govIsSlow}) then {
						_team setSpeedMode "LIMITED";          //--- careful gear (A2-safe, still moving).
						_team setVariable ["wfbe_aicom_gearslow", true];
					};
					if (!_govWantSlow && {_govIsSlow}) then {
						_team setSpeedMode "FULL";             //--- STANCE (task #1): back to the fast default (was NORMAL).
						_team setVariable ["wfbe_aicom_gearslow", false];
					};
				};

				//--- On arrival, switch to the mode's local behaviour once.
				if (!_arrived) then {
					if ((leader _team) distance _dest < 200) then {
						_arrived = true;
						//--- ROAD-MARCH hand-off: at the objective we WANT overland combat, so
						//--- release the road bias and assault with COMBAT/WEDGE (was empty props,
						//--- which left the SAD at engine defaults). Feed real squad-props through
						//--- WaypointsAdd so behaviour/formation actually apply.
						//--- (A2-fix: removed the A3-only forceFollowRoad clear; COMBAT/WEDGE props set the assault posture.)
						_team setSpeedMode "NORMAL";
						if (_mode == "defense") then {
							[_team, true, [[_dest, 'SAD', 100, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						} else {
							[_team, true, [[_dest, 'SAD', 250, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						};
					};
				};

				//--- ===================================================================
				//--- DISMOUNT-CAPTURE PHASE (towns-target). The keystone movement works:
				//--- the team REACHES the town (road-march / air-insert / truck-abandon all
				//--- proven). It then "hung around" and never flipped the town. Root causes,
				//--- all fixed below WITHOUT touching server_town.sqf or the camp scripts:
				//---  (1) BRANCH BUG: the old code chose camp-sweep vs pure-armour on the
				//---      LIVE-MOUNTED _hasCargo flag. By arrival the infantry are already ON
				//---      FOOT (air-insert L210/L224, spawn-on-foot, truck-abandon), so
				//---      _hasCargo was false -> pure-armour else -> only (leader)doMove _dest
				//---      -> nobody ever went to a camp or held the depot. Now we drive on the
				//---      actual ON-FOOT infantry whenever the team has any.
				//---  (2) DEPOT PRESENCE: mode-0 (Classic) flips a town ONLY via server_town.sqf,
				//---      which scans nearEntities within WFBE_C_TOWNS_CAPTURE_RANGE (40m) of the
				//---      TOWN-CENTER DEPOT LOGIC. The old sweep parked infantry AT bunkers
				//---      (outside 40m) and never held the depot, so _west stayed 0 -> no drain.
				//---      PRIMARY FIX: after the camp sweep we HOLD all on-foot infantry at the
				//---      depot center (getPos _townObj) and FIGHT there.
				//---  (3) DEFENDER CLEAR: a bare doMove makes units stand, not seek-and-destroy.
				//---      One live resistance defender within 40m keeps server_town.sqf _skip=true
				//---      (contested) and regenerates supply. So at the depot we lay a real SAD
				//---      waypoint and reveal the garrison, then hold until resistance-near-center
				//---      hits zero (or a hard timeout). Units always hold a live SAD/move order -
				//---      never frozen/idle (MEMORY guardrail).
				//--- RE-ARM: _captureDone is latched ONLY once the town is ours; otherwise the
				//--- 20s loop re-runs this phase next tick (units keep fighting at the center) so
				//--- a single failed pass is never a dead end.
				if (_arrived && !_captureDone && _mode == "towns-target") then {

					//--- Resolve the town object ROBUSTLY. wfbe_aicom_townorder is set server-side
					//--- WITHOUT broadcast (AI_Commander_AssignTowns.sqf L117/L240 use the 2-arg
					//--- setVariable), so on a Headless Client it reads nil. The order dest _dest IS
					//--- the town-logic position (getPos _target), and the global "towns" array is
					//--- populated on every machine (Init_Town.sqf L165) with broadcast "camps"
					//--- (L63). So fall back to the nearest town to _dest for a valid depot+camps.
					_townObj   = objNull;
					_townCamps = [];
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_townOrderArr = _team getVariable "wfbe_aicom_townorder";
					if (isNil "_townOrderArr") then {_townOrderArr = []};
					if (count _townOrderArr > 0) then {_townObj = _townOrderArr select 0};
					if (isNull _townObj && {count towns > 0}) then {
						_townObj = [_dest, towns] Call WFBE_CO_FNC_GetClosestEntity;
					};
					if (!isNull _townObj) then {_townCamps = _townObj getVariable ["camps", []]};

					//--- Depot-center scan point (server_town.sqf scans nearEntities around the
					//--- town LOGIC). Fall back to the order dest if the town object is unknown.
					_townCenter = if (!isNull _townObj) then {getPos _townObj} else {_dest};
					_capRange   = missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_RANGE", 40];
					_campRange  = missionNamespace getVariable ["WFBE_C_CAMPS_RANGE", 10];

					["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] begin capture at [%3] (%4 camps, depot scan %5m).", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, count _townCamps, _capRange]] Call WFBE_CO_FNC_AICOMLog;

					//--- ALWAYS dismount: build the on-foot infantry list from EVERY alive non-crew
					//--- unit, dismounting any that happen to still be in cargo. Crew (driver/gunner)
					//--- stay in their hull (keeps armour ready + parked near center). This replaces
					//--- the broken _hasCargo branch selection entirely.
					_liveUnits = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
					_footInf   = [];
					{
						_u = _x;
						if (alive _u) then {
							if (vehicle _u != _u) then {
								_veh = vehicle _u;
								if (_u == driver _veh || _u == gunner _veh) then {
									//--- Crew stays mounted: hull stays driveable + parked.
								} else {
									unassignVehicle _u;
									[_u] orderGetIn false;
									_footInf = _footInf + [_u];
								};
							} else {
								//--- Already on foot (air-insert / spawn-on-foot / truck-abandon).
								_footInf = _footInf + [_u];
							};
						};
					} forEach _liveUnits;

					if (count _footInf > 0) then {
						//--- ===== PER-CAMP SWEEP (drain-speed bonus + defender soften) =====
						//--- Mode 0: holding camps is NOT a gate, but server_town.sqf L183 multiplies
						//--- the drain rate by (campsOnSide/totalCamps), so taking bunkers ACCELERATES
						//--- the flip. Camp flip needs on-foot Man within WFBE_C_CAMPS_RANGE (10m)
						//--- (server_town_camp.sqf L26), so we close to <=10m and reveal nearby enemy so
						//--- the AI fights instead of standing. NO remount between camps - they stay on
						//--- foot for the depot hold that follows (the real capture step).
						{
							_campObj = _x;
							if (!isNull _campObj) then {
								{if (alive _x) then {_x doMove (getPos _campObj)}} forEach _footInf;
								if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove (getPos _campObj)};

								//--- Settle: up to 30s or leader within camp range (10m). exitWith-in-then
								//--- scope trap avoided: proximity test lives in the while header (lazy &&).
								_settleTimeout = time + 30;
								while {time < _settleTimeout && {!(!isNull leader _team && {alive leader _team} && {(leader _team) distance _campObj < _campRange})}} do {
									//--- Reveal the camp's live enemy so the squad prosecutes them.
									{
										if (alive _x && {side _x != _side} && {side _x != civilian}) then {_team reveal _x}; //--- A2: 2-operand reveal only (array form is A3-only).
									} forEach ((getPos _campObj) nearEntities [["Man"], 60]);
									sleep 3;
								};
								//--- Dwell so the 10m camp scan ticks (presence-based capture).
								sleep 45;
							};
						} forEach _townCamps;

						//--- ===== CAMP-FIRST GATE (BUG A): BOTH CAMPS BEFORE THE CENTER =====
						//--- Owner decision: KEEP Classic capture mode (WFBE_C_TOWNS_CAPTURE_MODE=0
						//--- unchanged) and make the AI take both camps FIRST *behaviourally*. We do
						//--- NOT enter the depot/town-center hold below until every camp this town owns
						//--- is held by our side (sideID == _sideID). Direct the foot infantry to the
						//--- NEAREST un-held camp, lay a live SAD/MOVE order there at WFBE_C_CAMPS_RANGE,
						//--- reveal its garrison (same pattern as the sweep above), and re-evaluate each
						//--- pass. TIME-BOX with the existing _holdEnd-style idiom so a dead/uncapturable
						//--- bunker (server_town_camp.sqf:24 gates on alive _base) can NEVER trap the team:
						//--- after a bounded window we fall through to the center hold anyway. Units always
						//--- hold a live SAD/move order here - never frozen/idle (MEMORY guardrail).
						_unheldCamps = [];
						{ if (!isNull _x && {(_x getVariable ["sideID",-1]) != _sideID}) then {_unheldCamps = _unheldCamps + [_x]} } forEach _townCamps;
						_campFirstEnd = time + 150; //--- same order of magnitude as the center-hold timeout (150s)
						while {count _unheldCamps > 0 && {time < _campFirstEnd} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
							_nearCamp   = [leader _team, _unheldCamps] Call WFBE_CO_FNC_GetClosestEntity;
							if (isNull _nearCamp) exitWith {};
							_campTgtPos = getPos _nearCamp;
							//--- Live SAD/MOVE order onto the camp (COMBAT/RED), foot units + leader in.
							[_team, true, [[_campTgtPos, 'SAD', _campRange max 30, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
							{if (alive _x) then {_x doMove _campTgtPos}} forEach _footInf;
							if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _campTgtPos};
							//--- Reveal the camp's live enemy so the squad prosecutes them (sweep pattern).
							{
								if (alive _x && {side _x != _side} && {side _x != civilian}) then {_team reveal _x}; //--- A2: 2-operand reveal only (array form is A3-only).
							} forEach (_campTgtPos nearEntities [["Man"], 60]);
							sleep 10;
							//--- Re-evaluate: drop any camp that is now ours (or went null).
							_unheldCamps = [];
							{ if (!isNull _x && {(_x getVariable ["sideID",-1]) != _sideID}) then {_unheldCamps = _unheldCamps + [_x]} } forEach _townCamps;
						};
						if (count _unheldCamps > 0) then {
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] camp-first window expired with %3 camp(s) un-held at [%4] - proceeding to center.", _side, _team, count _unheldCamps, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}]] Call WFBE_CO_FNC_AICOMLog;
						};

						//--- ===== PRIMARY: DEPOT-CENTER HOLD + CLEAR (the actual town flip) =====
						//--- Push every on-foot soldier ONTO the depot center and FIGHT there. This is
						//--- the only thing that satisfies server_town.sqf mode-0: a WEST unit within
						//--- 40m of the depot AND no live resistance within that same 40m. Lay a real
						//--- group SAD waypoint over the center (COMBAT/RED), move the foot units in, and
						//--- reveal the garrison so they clear it. Then HOLD until resistance-near-center
						//--- is zero (town drains + flips) OR a hard timeout, re-revealing each tick.
						[_team, true, [[_townCenter, 'SAD', _capRange max 60, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						{if (alive _x) then {_x doMove _townCenter}} forEach _footInf;
						if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _townCenter};

						//--- Hold/fight loop: up to ~150s. Exit early once no live resistance remains
						//--- within the capture radius of the depot (the contested _skip clears -> the
						//--- town drains and flips). Re-reveal enemy each tick. Every iteration leaves
						//--- units on a live SAD order (never idle).
						_holdEnd = time + 150;
						_resNear = 1;
						while {time < _holdEnd && {_resNear > 0} && {(count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)) > 0}} do {
							_enemyNear = (_townCenter nearEntities [["Man"], _capRange]) unitsBelowHeight 10;
							_resNear = 0;
							{
								if (alive _x && {side _x != _side} && {side _x != civilian}) then {
									_resNear = _resNear + 1;
									_team reveal _x; //--- A2: 2-operand reveal only (array form is A3-only).
								};
							} forEach _enemyNear;
							//--- Keep stragglers pressing the center (cheap re-issue, prevents drift).
							{if (alive _x && {(_x distance _townCenter) > (_capRange max 25)}) then {_x doMove _townCenter}} forEach ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
							//--- Early-out if the town already flipped to us.
							if (!isNull _townObj && {(_townObj getVariable ["sideID", -1]) == _sideID}) then {_resNear = 0};
							sleep 10;
						};

						//--- Latch only if the town is now OURS; otherwise leave _captureDone false so
						//--- the 20s order loop re-runs this whole phase next tick and keeps fighting.
						_townFlipped = (!isNull _townObj) && {(_townObj getVariable ["sideID", -1]) == _sideID};
						if (_townFlipped) then {
							_captureDone = true;
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] CAPTURED [%3] - holding center.", _side, _team, _townObj getVariable ["name","?"]]] Call WFBE_CO_FNC_AICOMLog;
							//--- ON-CAPTURE RE-TASK (BUG B): drop the captured-town order so AssignTowns
							//--- retargets THIS team next tick instead of letting it idle ~2 min at the
							//--- center. AssignTowns L168-169 retargets when isNull _goto (=> _needs=true),
							//--- and L164 only enters that gate for mode "towns"/"". So null the goto,
							//--- clear the order bookkeeping, and force the team back into the towns gate.
							//--- Also clear stale strike/relief state so Strategy.sqf doesn't re-grab it.
							//--- Locality matches existing writes: teamgoto/teammode broadcast true (like
							//--- SetTeamMovePos/SetTeamMoveMode); townorder stays 2-arg (like all its writers).
							_team setVariable ["wfbe_teamgoto", objNull, true];        //--- drop captured-town goto -> AssignTowns retargets next tick (isNull _goto => _needs=true)
							_team setVariable ["wfbe_aicom_townorder", [], false];     //--- 2-arg (NOT broadcast) to match existing townorder writes
							_team setVariable ["wfbe_teammode", "towns", true];        //--- ensure strike/relief teams re-enter the towns retarget gate
							_team setVariable ["wfbe_aicom_strike", false, true];      //--- clear stale strike state so Strategy.sqf doesn't re-grab
							_team setVariable ["wfbe_aicom_relief", objNull, true];
						} else {
							//--- Not flipped: keep the SAD-at-center order live (units stay fighting,
							//--- never idle) and retry on the next loop tick. No remount, no dead end.
							["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] capture pass at [%3] did not flip (res-near=%4) - holding + retrying.", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, _resNear]] Call WFBE_CO_FNC_AICOMLog;
						};
					} else {
						//--- Pure-armour team (no infantry at all): crew counts zero for the camp "Man"
						//--- scan, but the HULL still counts for the TOWN scan (server_town.sqf L48
						//--- scans Car/Tank/Air too). Park the hull dead-center so it registers WEST
						//--- presence within 40m, and lay a SAD so it clears defenders. Latch so a
						//--- crewless armour team doesn't spin (nothing more it can do on foot).
						_captureDone = true;
						[_team, true, [[_townCenter, 'SAD', _capRange max 60, 30, [], [], ["COMBAT","RED","WEDGE","NORMAL"]]]] Spawn WFBE_CO_FNC_WaypointsAdd;
						if (!isNull leader _team && {alive leader _team}) then {(leader _team) doMove _townCenter};
					};
				};

				//--- TRUCK-ABANDON (task #16): at the rally, abandon true ground troop-trucks
				//--- (transportSoldier>0, NOT Air/Tank/APC). HOISTED OUT of the _hasCargo gate
				//--- (commander infantry spawn ON FOOT, so _hasCargo is false at the order tick
				//--- and the old placement never fired). Runs in the arrived/same-seq branch,
				//--- once per order via a seq-stamped guard. Dismount driver+crew (+leftover pax)
				//--- and re-task them on foot so no crewed hull and no stranded pax sits idle.
				if (_arrived) then {
					_truckSeq = _team getVariable "wfbe_aicom_trucksabandoned";
					if (isNil "_truckSeq") then {_truckSeq = -1};
					if (_truckSeq != _seq) then {
						_team setVariable ["wfbe_aicom_trucksabandoned", _seq];
						_dismountDest = _dest;
						{
							_abVeh = _x;
							if (!isNull _abVeh && {alive _abVeh}
							    && {!(_abVeh isKindOf "Air")} && {!(_abVeh isKindOf "Tank")} && {!(_abVeh isKindOf "APC")}
							    && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _abVeh) >> "transportSoldier")) > 0}) then {
								_left = [];
								{
									if (alive _x) then {
										unassignVehicle _x;
										[_x] orderGetIn false;
										_left = _left + [_x];
									};
								} forEach (crew _abVeh);
								//--- Re-task every dismounted occupant (driver+crew+any leftover pax).
								{if (alive _x) then {_x doMove _dismountDest}} forEach _left;
								//--- Enroll the abandoned hull with the server husk-collector ONCE per hull.
								if !(_abVeh getVariable ["wfbe_aicom_abandoned", false]) then {
									_abVeh setVariable ["wfbe_aicom_abandoned", true];
									if (isServer) then {
										["aicom-vehicle-abandoned", _abVeh] Call HandleSpecial;
									} else {
										["RequestSpecial", ["aicom-vehicle-abandoned", _abVeh]] Call WFBE_CO_FNC_SendToServer;
									};
								};
							};
						} forEach _vehicles;
					};
				};

				//--- IMMOBILE-ABANDON (task #2): a crewed hull that can no longer move must
				//--- not strand its crew. Dismount and give them an UNCONDITIONAL ground move.
				//--- DEAD-LEADER FIX: destination is the order slot-2 dest (_dest, always in
				//--- scope here); we never unassign/moveOut with no destination. PER-HULL FLAG:
				//--- the husk-enroll RequestSpecial is sent ONCE per hull, not every poll.
				{
					_cv = _x;
					if (!isNull _cv && {alive _cv} && {!(_cv isKindOf "Air")} && {!(canMove _cv)} && {({alive _x} count (crew _cv)) > 0}) then {
						_dropPos = _dest;
						if (!isNull (leader _team) && {alive (leader _team)}) then {
							if (!isNil "_order" && {count _order >= 3}) then {_dropPos = _order select 2};
						};
						{
							if (alive _x) then {
								unassignVehicle _x;
								[_x] orderGetIn false;
								_x doMove _dropPos;
							};
						} forEach (crew _cv);
						//--- Also fall back to a group MOVE waypoint so the team re-forms on the dest.
						if (isNull (leader _team) || {!alive (leader _team)}) then {
							[_team, _dropPos, "MOVE", 50] Spawn WFBE_CO_FNC_WaypointSimple;
						};
						//--- PER-HULL FLAG: enroll the husk ONCE; skip already-flagged hulls so
						//--- RequestSpecial is not re-sent on every 20s poll for the team's lifetime.
						if !(_cv getVariable ["wfbe_aicom_abandoned", false]) then {
							_cv setVariable ["wfbe_aicom_abandoned", true];
							if (isServer) then {
								["aicom-vehicle-abandoned", _cv] Call HandleSpecial;
							} else {
								["RequestSpecial", ["aicom-vehicle-abandoned", _cv]] Call WFBE_CO_FNC_SendToServer;
							};
						};
					};
				} forEach _vehicles;
			};
		};
	};

	sleep 20;
};

//--- Team wiped: release the brain's slot.
if (isServer) then {
	["aicom-team-ended", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-ended", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

if (!isNull _team) then {deleteGroup _team};
