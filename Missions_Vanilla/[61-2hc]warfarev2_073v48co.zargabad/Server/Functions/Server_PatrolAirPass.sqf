/*
	Server_PatrolAirPass.sqf - fable/patrol-reimagine (owner 2026-07-28: "Reimagine Patrol tiers,
	Remove money and SV rewards from them - but maybe at Tier 3-4 we can do something with air
	units? perhaps even from off-map?").

	The patrol upgrade's T3/T4 payoff, replacing the removed money/SV rewards: when a side patrol
	reaches its objective town (Common_RunSidePatrol arrival hook -> "sidepatrol-airpass" case ->
	server chance/cooldown gate -> here), one (L3) or two (L4) attack aircraft enter FROM OFF-MAP,
	make a single pass over the town, then leave via the nearest map edge and despawn there.

	Assembly is a W13 Gunship Strike clone (AI_Commander_Wildcard.sqf case 13: same attack-class
	allowlist, FLY special for fixed wing so a drawn Plane does not spawn stalled, pilot + the
	flag-gated gunner, AIPatrol run); the exit is Common_RunCommanderTeam.sqf's off-map edge
	discipline (per-map world box - worldSize is A3-only - edge overshoot, waitUntil crossed or
	timeout, then delete). A shot-down airframe is left to the normal wreck pipeline (killed EH ->
	wfbe_trashed -> TrashObject). No standing AI: worst case two airframes exist for ~PASS_TIME
	plus the exit flight, then the map is clean again.

	_this = [_side, _sideID, _townObj, _upgLvl]
*/

Private ["_side","_sideID","_town","_upgLvl","_sideText","_airList","_attackClasses","_passTime","_ships","_shipI","_ang","_spawnPos","_class","_special","_heli","_grp","_pilotClass","_pilot","_gunner","_townPos"];

if (!isServer) exitWith {};

_side    = _this select 0;
_sideID  = _this select 1;
_town    = _this select 2;
_upgLvl  = _this select 3;

if (isNull _town) exitWith {};
_sideText = str _side;
_townPos  = getPos _town;

_airList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
_attackClasses = [];
{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Ka52","Ka52Black","Mi24_D","Mi24_D_TK_EP1","Mi24_V","Mi24_P","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su25_TK_EP1","Su34","Su39"]) then {_attackClasses = _attackClasses + [_x]} } forEach _airList;
if (count _attackClasses < 1) exitWith {diag_log Format ["PATROLAIR|SKIP|side=%1|reason=no_attack_class", _sideText]};

_passTime = missionNamespace getVariable ["WFBE_C_PATROL_AIR_PASS_TIME", 90];
_ships    = if (_upgLvl >= 4) then {2} else {1};

diag_log Format ["PATROLAIR|SPAWN|side=%1|town=%2|ships=%3|lvl=%4", _sideText, _town getVariable ["name","?"], _ships, _upgLvl];
["INFORMATION", Format ["Server_PatrolAirPass.sqf: [%1] off-map air pass on [%2] (ships=%3, L%4).", _sideText, _town getVariable ["name","?"], _ships, _upgLvl]] Call WFBE_CO_FNC_LogContent;

for "_shipI" from 1 to _ships do {
	_ang      = random 360;
	_spawnPos = [(_townPos select 0) + 4000 * sin _ang, (_townPos select 1) + 4000 * cos _ang, 1500];
	_class    = _attackClasses select floor(random count _attackClasses);
	//--- FIXED-WING FLY SPAWN (W13 idiom): a drawn Plane class needs the FLY special or it spawns near-stalled.
	_special  = if (_class isKindOf "Plane") then {"FLY"} else {"FORM"};
	_heli     = [_class, _spawnPos, _side, random 360, true, true, true, _special] Call WFBE_CO_FNC_CreateVehicle;
	if (!isNull _heli) then {
		_grp = [_side, "patrol-airpass"] Call WFBE_CO_FNC_CreateGroup;
		_pilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""];
		if (!isNull _grp && {_pilotClass != ""}) then {
			_pilot = [_pilotClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
			if (!isNull _pilot) then {
				_pilot moveInDriver _heli;
				//--- Attack-heli main armament fires from the GUNNER seat; same flag-gated mount as W13.
				if ((missionNamespace getVariable ["WFBE_C_AIR_ATTACK_GUNNER", 0]) > 0 && {(_heli emptyPositions "gunner") > 0}) then {
					_gunner = [_pilotClass, _grp, _spawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
					if (!isNull _gunner) then {_gunner moveInGunner _heli};
				};
				_heli flyInHeight 200;
				_grp setBehaviour "COMBAT"; _grp setCombatMode "RED";
				[_grp, _townPos, 200] Call AIPatrol;
				//--- Pass window, then EDGE EXIT (Common_RunCommanderTeam idiom): fly to the nearest map
				//--- edge, wait until crossed (or 6 min), delete only a still-live, player-free airframe.
				[_heli, _grp, _passTime] Spawn {
					Private ["_heli","_grp","_passTime","_wsz","_ex","_ey","_offPos","_t0"];
					_heli = _this select 0; _grp = _this select 1; _passTime = _this select 2;
					sleep _passTime;
					if (!isNull _heli && {alive _heli}) then {
						//--- worldSize is A3-ONLY: branch the box off worldName (Common_RunCommanderTeam idiom).
						_wsz = switch (toLower worldName) do {
							case "chernarus": {15360};
							case "takistan":  {12800};
							case "zargabad":  {8192};
							default {15360};
						};
						_ex = (getPos _heli) select 0;
						_ey = (getPos _heli) select 1;
						_offPos = [_ex, _ey, 0];
						if (_ex <= (_wsz - _ex) && {_ex <= _ey} && {_ex <= (_wsz - _ey)}) then {
							_offPos = [-200, _ey, 0];
						} else {
							if ((_wsz - _ex) <= _ey && {(_wsz - _ex) <= (_wsz - _ey)}) then {
								_offPos = [_wsz + 200, _ey, 0];
							} else {
								if (_ey <= (_wsz - _ey)) then {
									_offPos = [_ex, -200, 0];
								} else {
									_offPos = [_ex, _wsz + 200, 0];
								};
							};
						};
						_heli flyInHeight 250;
						if (!isNull (driver _heli)) then {(driver _heli) doMove _offPos};
						_t0 = time + 360;
						waitUntil {sleep 3; time > _t0 || isNull _heli || {!alive _heli} || {((getPos _heli) select 0) < 0} || {((getPos _heli) select 0) > _wsz} || {((getPos _heli) select 1) < 0} || {((getPos _heli) select 1) > _wsz}};
						//--- Timeout without an edge-cross still despawns (a stray attack aircraft must never
						//--- become standing AI); a destroyed one is left to the normal wreck pipeline.
						if (!isNull _heli && {alive _heli} && {({isPlayer _x} count (crew _heli)) == 0}) then {
							diag_log Format ["PATROLAIR|EXIT|class=%1", typeOf _heli];
							//--- r86 group-first: a bailed pilot is no longer in (crew _heli); a crew-only delete left
							//--- him alive and pinned the group (A2 deleteGroup no-ops on a non-empty group).
							if (!isNull _grp) then {{if (!isNull _x && {!isPlayer _x}) then {deleteVehicle _x; sleep 0}} forEach units _grp}; //--- crash 014EFCF4 sweep: sleep 0 between unit deletes (already-scheduled spawn context).
							if (!isNull _heli) then {deleteVehicle _heli};
							if (!isNull _grp) then {deleteGroup _grp};
						};
					};
				};
			} else {
				deleteVehicle _heli; deleteGroup _grp;
			};
		} else {
			deleteVehicle _heli;
		};
	};
	sleep 2;
};
