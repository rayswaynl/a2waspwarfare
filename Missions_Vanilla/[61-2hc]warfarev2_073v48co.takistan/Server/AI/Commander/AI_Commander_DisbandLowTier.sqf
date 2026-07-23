//--- AI_Commander_DisbandLowTier.sqf
//--- Interval-gated maintenance pass (Ray 2026-06-28): retire ONE idle, rear, FOOT-INFANTRY HC team
//--- per pass once the side already fields higher-tier MOBILE teams (light/heavy/air), keeping the
//--- force modern and freeing group/pop-cap headroom for armour. IMMERSION: one team per long interval
//--- (WFBE_C_AICOM_DISBAND_LOWTIER_INTERVAL), only rear/idle teams, only while a minimum infantry floor remains,
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
private ["_hasMobile","_footCount","_best","_bestN","_bestType"];
_hasMobile = false;
_footCount = 0;
_best = grpNull;
_bestN = 1e9;
_bestType = -1;
{
	private "_team"; _team = _x;
	if (!isNull _team) then {
		private ["_tt","_typeIdx"];
		_tt = _team getVariable "wfbe_teamtype"; if (isNil "_tt") then {_tt = -1};   //--- A2-OA G1-safe: the [name,default] form is A3-only on GROUPS (returns nil/throws); plain get + isNil guard.
		_typeIdx = if (_tt >= 0 && {_tt < count _types}) then {_types select _tt} else {-1};
		if (_typeIdx > 0) then {_hasMobile = true};               //--- light/heavy/air = mobile force fielded
		//--- AI-BEHAVIOR-LOOP-DESIGN.md sec3.2 (weak-team loop, flag WFBE_C_AICOM_WEAKTEAM_ENABLE default 0): reuse
		//--- WFBE_C_AICOM_BREAKOFF_MIN (the SAME "too depleted to keep fighting" floor Common_RunCommanderTeam.sqf's
		//--- depot-hold BREAKOFF already uses tactically) as the strategic idle-layer floor. _isWeak widens which
		//--- teams enter the candidate scan below to ANY type (not just foot); _footCount below stays foot-only so
		//--- WFBE_C_AICOM_DISBAND_INFANTRY_FLOOR keeps its documented "never disband below this many FOOT teams" meaning.
		private ["_weakEnabled","_weakFloor","_n2","_isWeak"];
		_weakEnabled = (missionNamespace getVariable ["WFBE_C_AICOM_WEAKTEAM_ENABLE", 0]) > 0;
		_weakFloor   = missionNamespace getVariable ["WFBE_C_AICOM_BREAKOFF_MIN", 3];
		_n2 = 0; if (_weakEnabled) then {_n2 = count ((units _team) Call WFBE_CO_FNC_GetLiveUnits)};
		_isWeak = _weakEnabled && {_n2 > 0} && {_n2 <= _weakFloor};
		if (_typeIdx == 0) then {_footCount = _footCount + 1};    //--- foot infantry = low-tier (tally unchanged by the weak-team widening below)
		if (_typeIdx == 0 || _isWeak) then {
			private ["_hc","_flagged","_md","_open"];
			_hc      = [_team,"wfbe_aicom_hc",false]              Call WFBE_CO_FNC_GroupGetBool;
			_flagged = [_team,"wfbe_aicom_disband",false]         Call WFBE_CO_FNC_GroupGetBool;
			_md      = _team getVariable "wfbe_teammode"; if (isNil "_md") then {_md = "towns"};
			_open    = [_team,"wfbe_aicom_dispatch_open",false]   Call WFBE_CO_FNC_GroupGetBool;
			//--- candidate = HC-owned, not player-led, idle (auto town-mode, no open dispatch), not flagged.
			if (_hc && {!_flagged} && {!isPlayer (leader _team)} && {_md == "towns"} && {!_open}) then {
				private ["_ldr","_inView","_threat"];
				_ldr = leader _team;
				_inView = ([getPos _ldr, _viewDist] Call WFBE_CO_FNC_RealPlayersNear) > 0;  //--- NEVER retire a team a human can SEE (Ray 2026-06-28)
				//--- also skip a CONTESTED team (in combat, or an enemy within safeDist); the in-view gate above handles players.
				_threat = (behaviour _ldr == "COMBAT")
				       || {({alive _x && {side _x != _side} && {_x distance _ldr < _safeDist}} count allUnits) > 0};
				if (!_inView && {!_threat}) then {
					private "_n"; _n = count ((units _team) Call WFBE_CO_FNC_GetLiveUnits);
					if (_n < _bestN) then {_bestN = _n; _best = _team; _bestType = _typeIdx};   //--- smallest rear foot/weak squad first
				};
			};
		};
	};
} forEach _teams;

//--- gates: mobile force fielded; the infantry floor applies ONLY when the candidate is a FOOT team (a weak mobile/air candidate does not touch foot count); a safe candidate exists.
if (!_hasMobile) exitWith {};
if (_bestType == 0 && {_footCount <= _floor}) exitWith {};
if (isNull _best) exitWith {};

//--- flag it; the HC executor self-deletes with its own re-check, aicom-team-ended deregisters from wfbe_teams.
_best setVariable ["wfbe_aicom_disband", true, true];
//--- AI-BEHAVIOR-LOOP-DESIGN.md sec3.4: distinguish the weak-team trigger from the pre-existing lowtier-cull so soak analysis can separate the two populations. _bestType==0 at flag-off is guaranteed (candidate scan is still foot-only), so this branch is byte-identical to today when WFBE_C_AICOM_WEAKTEAM_ENABLE=0.
if (_bestType == 0) then {
	["INFORMATION", Format ["AI_Commander_DisbandLowTier.sqf: [%1] low-tier TEAM_RETIRED flagged best-team %2 (footTeams %3, units %4); HC self-deletes.", _sideText, _best, _footCount, _bestN]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_RETIRED|reason=lowtier-cull|footTeams=" + str _footCount + "|units=" + str _bestN);
} else {
	["INFORMATION", Format ["AI_Commander_DisbandLowTier.sqf: [%1] weak-team TEAM_RETIRED flagged best-team %2 (type %3, alive %4); HC self-deletes.", _sideText, _best, _bestType, _bestN]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_RETIRED|reason=weakteam-replace|footTeams=" + str _footCount + "|alive=" + str _bestN + "|type=" + str _bestType);
};
