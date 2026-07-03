//--- AI_Commander_DisbandLowTier.sqf
//--- Interval-gated maintenance pass (Ray 2026-06-28): retire ONE idle, rear, FOOT-INFANTRY HC team
//--- per pass once the side already fields higher-tier MOBILE teams (light/heavy/air), keeping the
//--- force modern and freeing group/pop-cap headroom for armour. IMMERSION: one team per long interval
//--- (WFBE_C_AICOM_DISBAND_INTERVAL), only rear/idle teams, only while a minimum infantry floor remains,
//--- only when mobile force is actually fielded.
//---
//--- SELECTOR ONLY. It sets the proven wfbe_aicom_disband flag (publicVariable'd); the HC-LOCAL executor
//--- in Common_RunCommanderTeam.sqf (~L530-547) does the actual deleteVehicle with its OWN final
//--- proximity/combat re-check (and stands the team back down if a player wandered near), then the
//--- existing aicom-team-ended path deregisters it from wfbe_teams. NEVER deleteGroup an HC-local team
//--- from the server - teams are HC-local for their whole life.
//---
//--- A2-OA-1.64 safe: ==/!= only on numbers/strings/sides (never Bool); if/else + &&/|| latches only.

private "_side"; _side = _this;
if ((missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_LOWTIER_ENABLE", 0]) <= 0) exitWith {};

private ["_logik","_teams"];
_logik = _side Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_teams = _logik getVariable ["wfbe_teams", []];
if (count _teams < 1) exitWith {};

private ["_sideText","_types","_safeDist","_floor","_viewDist"];
_sideText = str _side;
//--- authoritative per-template type (0=inf/foot, 1=light, 2=heavy, 3=air) - the bucket-classifier source,
//--- correct for motorized (counts as light=mobile, NOT foot) unlike the upgrade-mask telemetry cascade.
_types    = missionNamespace getVariable Format ["WFBE_%1AITEAMTYPES", _sideText];
if (isNil "_types") exitWith {};
_safeDist = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_SAFE_DIST", 900];
_floor    = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR", 3];
_viewDist = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_VIEW_DIST", 1500];

//--- single sweep: detect mobile force, count foot teams, pick the SMALLEST rear/idle foot candidate.
private ["_hasMobile","_footCount","_best","_bestN"];
_hasMobile = false;
_footCount = 0;
_best = grpNull;
_bestN = 1e9;
{
	private "_team"; _team = _x;
	if (!isNull _team) then {
		private ["_tt","_typeIdx"];
		_tt = _team getVariable "wfbe_teamtype"; if (isNil "_tt") then {_tt = -1};   //--- A2-OA G1-safe: the [name,default] form is A3-only on GROUPS (returns nil/throws); plain get + isNil guard.
		_typeIdx = if (_tt >= 0 && {_tt < count _types}) then {_types select _tt} else {-1};
		if (_typeIdx > 0) then {_hasMobile = true};               //--- light/heavy/air = mobile force fielded
		if (_typeIdx == 0) then {                                  //--- foot infantry = low-tier
			_footCount = _footCount + 1;
			private ["_hc","_flagged","_md","_open"];
			_hc      = [_team,"wfbe_aicom_hc",false]              Call WFBE_CO_FNC_GroupGetBool;
			_flagged = [_team,"wfbe_aicom_disband",false]         Call WFBE_CO_FNC_GroupGetBool;
			_md      = _team getVariable "wfbe_teammode"; if (isNil "_md") then {_md = "towns"};
			_open    = [_team,"wfbe_aicom_dispatch_open",false]   Call WFBE_CO_FNC_GroupGetBool;
			//--- candidate = HC-owned, not player-led, idle (auto town-mode, no open dispatch), not flagged.
			if (_hc && {!_flagged} && {!isPlayer (leader _team)} && {_md == "towns"} && {!_open}) then {
				private ["_ldr","_inView","_threat"];
				_ldr = leader _team;
				_inView = ({alive _x && {isPlayer _x} && {_x distance _ldr < _viewDist}} count allUnits) > 0;  //--- NEVER retire a team a human can SEE (Ray 2026-06-28)
				//--- also skip a CONTESTED team (in combat, or an enemy within safeDist); the in-view gate above handles players.
				_threat = (behaviour _ldr == "COMBAT")
				       || {({alive _x && {side _x != _side} && {_x distance _ldr < _safeDist}} count allUnits) > 0};
				if (!_inView && {!_threat}) then {
					private "_n"; _n = count ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
					if (_n < _bestN) then {_bestN = _n; _best = _team};   //--- smallest rear foot squad first
				};
			};
		};
	};
} forEach _teams;

//--- gates: only trim foot when mobile force is fielded, we stay above the infantry floor, and a safe candidate exists.
if (!_hasMobile) exitWith {};
if (_footCount <= _floor) exitWith {};
if (isNull _best) exitWith {};

//--- flag it; the HC executor self-deletes with its own re-check, aicom-team-ended deregisters from wfbe_teams.
_best setVariable ["wfbe_aicom_disband", true, true];
["INFORMATION", Format ["AI_Commander_DisbandLowTier.sqf: [%1] low-tier TEAM_RETIRED flagged best-team %2 (footTeams %3, units %4); HC self-deletes.", _sideText, _best, _footCount, _bestN]] Call WFBE_CO_FNC_AICOMLog;
diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_RETIRED|reason=lowtier-cull|footTeams=" + str _footCount + "|units=" + str _bestN);
