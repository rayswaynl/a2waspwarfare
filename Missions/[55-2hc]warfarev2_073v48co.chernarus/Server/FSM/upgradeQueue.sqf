/*
	Commander upgrade-queue auto-start driver.
	Every few seconds, for each side: if no upgrade is running and a commander
	exists, scan the queue for the first startable entry, deduct server-side and
	start it via WFBE_SE_FNC_ProcessUpgrade (server-initiated, full-timer path)
	exactly like the AI commander. Server_ProcessUpgrade.sqf is NOT modified.

	Stacking: the same upgrade id may appear several times (each copy = one more
	level; the live level is read at start). Scan rules per tick:
	 - only the FIRST copy of each id is actionable (later copies follow next ticks),
	 - a maxed id's first copy is stale and gets dropped,
	 - a prerequisite-blocked entry is SKIPPED (its link may be queued behind it,
	   so head-blocking could deadlock the queue) - the next entry gets a chance,
	 - an unaffordable entry STOPS the scan (money is saved for the front of the
	   queue; no queue-jumping on funds).
*/

scriptName "Server\FSM\upgradeQueue.sqf";

private ["_interval","_logik","_queue","_id","_upgrades","_current","_levels","_costs","_cost","_comTeam","_lnk","_li","_clink","_linkNeeded","_canStart","_dual","_seen","_startIdx","_stop","_dirty","_k"];

//--- HP-01 CORE-LOOP SUPERVISOR (fable/loop-supervisor-hp01): owner-generation gate (see
//--- server_town.sqf for the full note).
private ["_clOwnerKey","_clOwnerSeq"];
_clOwnerKey = "wfbe_coreloop_owner_upgrade";
_clOwnerSeq = if (typeName _this == "ARRAY" && {count _this > 0}) then {_this select 0} else {missionNamespace getVariable [_clOwnerKey, 0]};

_interval = 5;
_dual = (missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0;

while {!gameOver && {(missionNamespace getVariable [_clOwnerKey, _clOwnerSeq]) == _clOwnerSeq}} do {

	//--- HP-01 SUPERVISOR HEARTBEAT: first statement of every iteration (see server_town.sqf note).
	missionNamespace setVariable ["wfbe_coreloop_hb_upgrade", time];

	{
		_logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
		//--- getVariable defaults guard a present-but-uninitialized side (e.g. resistance in a future
		//--- three-way setup): WFBE_PRESENTSIDES can include a side whose logic never got these vars,
		//--- and the bare-string reads would make !(nil) / + nil throw.
		if (!isNull _logik && {!(_logik getVariable ["wfbe_upgrading", false])}) then {
			_queue = + (_logik getVariable ["wfbe_upgrade_queue", []]);
			if (count _queue > 0) then {
				_comTeam = (_x) Call WFBE_CO_FNC_GetCommanderTeam;
				if (!isNull _comTeam) then {
					_upgrades = (_x) Call WFBE_CO_FNC_GetSideUpgrades;
					_levels = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", str _x];
					_costs = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", str _x];

					_seen = [];
					_startIdx = -1;
					_stop = false;
					_dirty = false;

					for "_k" from 0 to (count _queue - 1) do {
						if (!_stop && {_startIdx < 0}) then {
							_id = _queue select _k;
							if !(_id in _seen) then {
								_seen = _seen + [_id];
								_current = _upgrades select _id;

								if (_current >= (_levels select _id)) then {
									//--- Stale first copy of a maxed id: mark for removal, keep scanning.
									_queue set [_k, objNull];
									_dirty = true;
								} else {
									//--- Prerequisites for this level (for-loop, NOT a nested forEach - _x is the side).
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

									//--- Link not live yet: SKIP (it may be queued behind this entry); try the next id.
									if (!_linkNeeded) then {
										_cost = (_costs select _id) select _current;   // [supply, funds]
										_canStart = true;
										if (_dual && {((_x) Call WFBE_CO_FNC_GetSideSupply) < (_cost select 0)}) then {_canStart = false};
										if (_canStart && {(_comTeam Call WFBE_CO_FNC_GetTeamFunds) < (_cost select 1)}) then {_canStart = false};
										if (_canStart) then {
											_startIdx = _k;
										} else {
											//--- Unaffordable: stop - the queue saves up for this entry (no jumping on funds).
											_stop = true;
										};
									};
								};
							};
						};
					};

					if (_startIdx >= 0) then {
						_id = _queue select _startIdx;
						_current = _upgrades select _id;
						_cost = (_costs select _id) select _current;
						//--- Pop exactly this copy (subtraction strips ALL copies of a stacked id) + drop any stale marks.
						_queue set [_startIdx, objNull];
						_queue = _queue - [objNull];
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
					} else {
						if (_dirty) then {
							//--- Only stale entries were found this tick: flush them.
							_queue = _queue - [objNull];
							_logik setVariable ["wfbe_upgrade_queue", _queue, true];
						};
					};
				};
			};
		};
	} forEach WFBE_PRESENTSIDES;

	sleep _interval;
};
