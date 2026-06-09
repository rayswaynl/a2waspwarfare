/*
	Commander upgrade-queue auto-start driver.
	Every few seconds, for each side: if no upgrade is running and the queue head
	is affordable (full price, per currency mode) with its prerequisites met and a
	commander exists, deduct server-side and start it via WFBE_SE_FNC_ProcessUpgrade
	(server-initiated, full-timer path) exactly like the AI commander.
	Server_ProcessUpgrade.sqf is NOT modified.
*/

scriptName "Server\FSM\upgradeQueue.sqf";

private ["_interval","_logik","_queue","_id","_upgrades","_current","_levels","_costs","_cost","_comTeam","_lnk","_li","_clink","_linkNeeded","_canStart","_dual"];

_interval = 5;
_dual = (missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0;

while {!gameOver} do {
	{
		_logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
		//--- getVariable defaults guard a present-but-uninitialized side (e.g. resistance in a future
		//--- three-way setup): WFBE_PRESENTSIDES can include a side whose logic never got these vars,
		//--- and the bare-string reads would make !(nil) / + nil throw.
		if (!isNull _logik && {!(_logik getVariable ["wfbe_upgrading", false])}) then {
			_queue = + (_logik getVariable ["wfbe_upgrade_queue", []]);
			if (count _queue > 0) then {
				_id = _queue select 0;
				_upgrades = (_x) Call WFBE_CO_FNC_GetSideUpgrades;
				_current = _upgrades select _id;
				_levels = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", str _x];

				if (_current >= (_levels select _id)) then {
					//--- Stale/maxed head: drop it and move on next tick.
					_queue = _queue - [_id];
					_logik setVariable ["wfbe_upgrade_queue", _queue, true];
				} else {
					_comTeam = (_x) Call WFBE_CO_FNC_GetCommanderTeam;
					if (!isNull _comTeam) then {
						_costs = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", str _x];
						_cost = (_costs select _id) select _current;   // [supply, funds]

						_canStart = true;
						if (_dual && {((_x) Call WFBE_CO_FNC_GetSideSupply) < (_cost select 0)}) then {_canStart = false};
						if (_canStart && {(_comTeam Call WFBE_CO_FNC_GetTeamFunds) < (_cost select 1)}) then {_canStart = false};

						//--- Prerequisites for this level (for-loop, NOT a nested forEach — _x is the side).
						if (_canStart) then {
							_lnk = (missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS", str _x]) select _id;
							_lnk = _lnk select _current;
							_linkNeeded = false;
							if (count _lnk > 0) then {
								if (typeName (_lnk select 0) == "ARRAY") then {
									for "_li" from 0 to (count _lnk - 1) do {
										_clink = _lnk select _li;
										if ((_upgrades select (_clink select 0)) < (_clink select 1)) exitWith {_linkNeeded = true};
									};
								} else {
									if ((_upgrades select (_lnk select 0)) < (_lnk select 1)) then {_linkNeeded = true};
								};
							};
							if (_linkNeeded) then {_canStart = false};
						};

						if (_canStart) then {
							//--- Pop head + replicate.
							_queue = _queue - [_id];
							_logik setVariable ["wfbe_upgrade_queue", _queue, true];
							//--- Gate synchronously so the next tick can't double-start (mirrors Server_AI_Com_Upgrade.sqf:43-44).
							_logik setVariable ["wfbe_upgrading", true, true];
							_logik setVariable ["wfbe_upgrading_id", _id, true];
							//--- Deduct (correct indices: cost = [supply, funds]). Result is >=0 because we checked affordability.
							if (_dual) then {
								[_x, -(_cost select 0), "Queued tech upgrade.", false] Call ChangeSideSupply;
							};
							[_comTeam, -(_cost select 1)] Call WFBE_CO_FNC_ChangeTeamFunds;
							//--- Start (server-initiated => full-timer path, like the AI commander).
							[_x, _id, _current, false] Spawn WFBE_SE_FNC_ProcessUpgrade;
							["INFORMATION", Format ["upgradeQueue.sqf: [%1] auto-started queued upgrade [%2] to level [%3].", _x, _id, _current + 1]] Call WFBE_CO_FNC_LogContent;
						};
					};
				};
			};
		};
	} forEach WFBE_PRESENTSIDES;

	sleep _interval;
};
