/*
	Side patrol driver (Patrols upgrade).
	Every ~20s, per present side: if the side has researched Patrols (level 1-3) and
	is under the concurrent cap, spawn one patrol at the friendly town nearest the
	side's HQ. Tier follows the upgrade level (1=LIGHT, 2=MEDIUM, 3=HEAVY pools from
	the faction Root configs - the pools are server-only, so the TEMPLATE is resolved
	here and shipped to the runner). The patrol itself runs on a live headless client
	when one is registered, otherwise on the server (Common_RunSidePatrol.sqf).
	Replaces the old fixed-random-towns patrol system (Init_Towns flagging retired).
*/

scriptName "Server\FSM\server_side_patrols.sqf";

private ["_side","_sideID","_logik","_upgrades","_lvl","_active","_last","_hq","_owned","_home","_tier","_pool","_template","_hcs","_live","_delay","_max"];

waitUntil {townInitServer};
sleep 30;

if (isNil "WFBE_ACTIVE_PATROLS") then {WFBE_ACTIVE_PATROLS = []; publicVariable "WFBE_ACTIVE_PATROLS"};

_delay = missionNamespace getVariable "WFBE_C_PATROLS_DELAY_SPAWN";
_max = missionNamespace getVariable "WFBE_C_SIDE_PATROLS_MAX";

while {!WFBE_GameOver} do {
	{
		_side = _x;
		_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
		_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _logik) then {
			_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
			_lvl = if (count _upgrades > WFBE_UP_PATROLS) then {_upgrades select WFBE_UP_PATROLS} else {0};
			if (_lvl > 0) then {
				_active = _logik getVariable ["wfbe_side_patrols", 0];
				_last = _logik getVariable ["wfbe_side_patrol_last", -(_delay)];
				if (_active < _max && {time - _last > _delay}) then {
					_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
					_owned = [];
					{if ((_x getVariable "sideID") == _sideID) then {_owned = _owned + [_x]}} forEach towns;
					//--- V0.5.1: observability - say WHY a researched patrol is not spawning (once).
					if (count _owned == 0 && {!(_logik getVariable ["wfbe_patrol_waitlog", false])}) then {
						_logik setVariable ["wfbe_patrol_waitlog", true];
						["INFORMATION", Format ["server_side_patrols.sqf: [%1] Patrols %2 researched but NO owned towns yet - waiting for the first capture.", _side, _lvl]] Call WFBE_CO_FNC_AICOMLog;
					};
					if (!isNull _hq && count _owned > 0) then {
						_home = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity;
						_tier = switch (_lvl) do {case 1: {"LIGHT"}; case 2: {"MEDIUM"}; default {"HEAVY"}};
						_pool = missionNamespace getVariable Format["WFBE_%1_PATROL_%2", _side, _tier];
						if (!isNil "_pool" && {count _pool > 0}) then {
							_template = _pool select floor(random count _pool);
							//--- Book the slot synchronously; the started/ended events keep the
							//--- public marker list, the ended event re-arms the cooldown.
							_logik setVariable ["wfbe_side_patrols", _active + 1];
							_logik setVariable ["wfbe_side_patrol_last", time];
							//--- Run on a live HC when available (server FPS ~ 0), else locally.
							_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
							_live = [];
							{if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]}} forEach _hcs;
							if (count _live > 0) then {
								[leader(_live select floor(random count _live)), "HandleSpecial", ['delegate-sidepatrol', _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
							};
							_logik setVariable ["wfbe_patrol_waitlog", false];
							["INFORMATION", Format["server_side_patrols.sqf: [%1] %2 patrol dispatched from [%3] (active %4/%5, HC:%6).", _side, _tier, _home getVariable "name", _active + 1, _max, count _live > 0]] Call WFBE_CO_FNC_AICOMLog;
							if (!isNil "PerformanceAudit_Record") then {
								if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
									["side_patrol_spawn", 0, Format["side:%1;tier:%2;active:%3;hc:%4", _side, _tier, _active + 1, count _live > 0], "SERVER"] Call PerformanceAudit_Record;
								};
							};
						};
					};
				};
			};
		};
	} forEach WFBE_PRESENTSIDES;

	sleep 20;
};
