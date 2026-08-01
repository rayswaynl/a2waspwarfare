Private ["_buildings","_closest","_defense","_groups","_HC","_liveHCs","_manningLoopActive","_moveInGunner","_position","_positions","_side","_sideID","_soldier","_team","_type","_unit","_commander","_sideStillValid","_defenseArea","_areaTeam","_reManPollInterval","_reManPollWaited"];
_defense = _this select 0;
_side = _this select 1;
_team = _this select 2;
_closest = _this select 3;

_manningLoopActive = _defense getVariable "WFBE_DefenseManningLoopActive";
if (isNil "_manningLoopActive") then {_manningLoopActive = false};
if (_manningLoopActive) exitWith {
	["INFORMATION", Format ["Server_HandleDefense.sqf: Skipped duplicate manning loop for [%1].", typeOf _defense]] Call WFBE_CO_FNC_LogContent;
};
_defense setVariable ["WFBE_DefenseManningLoopActive", true, true];

//--- Owner call 2026-06-11: ALL base-defense crews mount instantly (spawn at the gun,
//--- teleport in). No barracks walk = no pathfinding cost, no stalled walk-in boarding.
_moveInGunner = true;
//--- AI16 (lane118): loop exits when the base area that this defense belongs to changes hands.
_sideStillValid = true;
//--- build/defense audit 2026-07-28: bounded re-man poll interval (s). WFBE_C_DEFENSE_REMAN_POLL,
//--- Init_CommonConstants.sqf, default 15 - see the tail poll loop below (replaces sleep 420).
_reManPollInterval = missionNamespace getVariable ["WFBE_C_DEFENSE_REMAN_POLL", 15];
if (typeName _reManPollInterval != "SCALAR" || {_reManPollInterval <= 0}) then {_reManPollInterval = 15};

while {!isNull _defense && {alive _defense} && {_sideStillValid}} do {
	if (isNull(gunner _defense) || !alive gunner _defense) then {

		sleep 7;

		//--- cmdcon44g-era: the gun can be destroyed/DELETED during the 7s sleep - a null object's 2-arg
		//--- getVariable IGNORES the default (engine-verified XWT45-P4), so the read below came up nil and
		//--- '!isNull _defenseArea' threw Undefined (2x live 2026-07-03). Block-exit falls through to the
		//--- while condition, which ends the loop cleanly on the dead gun.
		if (isNull _defense) exitWith {};

		//--- AI16 (lane118): stop re-manning if the base area this defense was built for has changed hands.
		//--- WFBE_DefenseBaseArea is stamped by Construction_StationaryDefense at placement time (non-nil only
		//--- for manned base statics). If the area's DefenseTeam now belongs to a different side, the original
		//--- builder side no longer owns the area — stop producing ghost defenders and let the loop exit.
		_defenseArea = _defense getVariable ["WFBE_DefenseBaseArea", objNull];
		if (!isNull _defenseArea) then {
			_areaTeam = _defenseArea getVariable ["DefenseTeam", grpNull];
			if (!isNull _areaTeam && {side _areaTeam != _side}) then {
				_sideStillValid = false;
				["INFORMATION", Format ["Server_HandleDefense.sqf: [%1] base area changed hands — stopping re-manning for [%2].", str _side, typeOf _defense]] Call WFBE_CO_FNC_LogContent;
			};
		};
		if (!_sideStillValid) exitWith {};

		//--- crash 014EFCF4: the defense can be deleted after the 7s sleep and area checks.
		if (isNull _defense || {!alive _defense}) exitWith {};

		//--- EAST/OPFOR empty-static fix (2026-06-14): this base-static path used to GATE all
		//--- manning behind `alive _closest` (a side-Barracks within WFBE_C_BASE_DEFENSE_MANNING_RANGE
		//--- of the gun). When the AI commander placed EAST guns out of barracks range, or the
		//--- barracks was never built / was destroyed, the gun stayed EMPTY forever and logged
		//--- "Canceled auto manning, the barracks is destroyed" (or nothing at build time). The
		//--- working GUER TOWN path (Server_OperateTownDefensesUnits.sqf) has NO barracks gate - it
		//--- mans unconditionally. Since crews mount INSTANTLY at the gun (_moveInGunner=true, no
		//--- walk), the barracks is irrelevant to whether the gun can be manned. So: man the gun
		//--- ALWAYS (gun alive + gunner slot empty). _moveInGunner is hardcoded true (l.16), so the legacy
		//--- _closest cover-position math never ran; that dead branch has been dropped and crews seat at the gun.
		//--- Null-guard before getPosATL (014EFCF4 class): structure can vanish mid-loop between alive checks.
		if (isNull _defense || {!alive _defense}) exitWith {};
		_position = getPosATL _defense;

		_HC = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
		_liveHCs = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count _HC;
		if (_liveHCs > 0) then {
			_groups = [] + [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side]];
			_positions = [] + [_position];
			[_side, _groups, _positions, _team, _defense, _moveInGunner] Call WFBE_CO_FNC_DelegateAIStaticDefenceHeadless;

			//--- Server-side fallback watchdog (mirrors the working town path's CreateUnit fallback at
			//--- Server_OperateTownDefensesUnits.sqf:72-84). HC delegation here is fire-and-forget to a
			//--- RANDOM HC with no retry; if it is dropped (HC busy/desynced, or an HC-local AI stalls
			//--- boarding a server-local static) the gun would otherwise sit empty until the next 420s
			//--- tick. Give the delegation a grace window; if no gunner is seated, fill server-side.
			[_defense,_side,_team] Spawn {
				Private ["_defense","_side","_team","_deadline","_sideID","_type","_soldier","_position"];
				_defense = _this select 0;
				_side    = _this select 1;
				_team    = _this select 2;
				_deadline = time + 45;
				waitUntil {
					sleep 5;
					(time > _deadline) || {!alive _defense} || {(!isNull (gunner _defense)) && {alive gunner _defense}}
				};
				//--- Respect the existing "gunner already alive" skip - do NOT double-man.
				if (!isNull _defense && {alive _defense} && {isNull (gunner _defense) || {!alive gunner _defense}}) then {
					if (isNull _defense || {!alive _defense}) exitWith {};
					_position = getPosATL _defense;
					_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
					_type = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];
					_soldier = [_type,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;
					if !(isNull _soldier) then {
						_defense setVariable ["WFBE_StaticDefenseAssignedUnit", _soldier, true];
						[_soldier] allowGetIn true;
						_soldier assignAsGunner _defense;
						[_soldier] orderGetIn true;
						_soldier moveInGunner _defense;
						//--- build/defense audit 2026-07-28: wake the re-man poll early on gunner death instead
						//--- of waiting out the bounded poll window. Server-local only (no public flag - the
						//--- manning loop runs server-side, confirmed via the Init_Server.sqf isServer/isDedicated gate).
						_soldier setVariable ["WFBE_DefenseGunRef", _defense];
						_soldier addEventHandler ["Killed", {
							Private ["_gunRef"];
							_gunRef = (_this select 0) getVariable ["WFBE_DefenseGunRef", objNull];
							if (!isNull _gunRef) then {
								_gunRef setVariable ["WFBE_DefenseRecheckDue", true];
							};
						}];
						[_team, 1000, _position] spawn WFBE_CO_FNC_RevealArea;
						["WARNING", Format ["Server_HandleDefense.sqf: [%1] HC delegation did not seat a gunner for [%2] within grace window - filled server-side.", str _side, typeOf _defense]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		}else{
			_position = getPosATL _defense;
			_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
			_type = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];
			_soldier = [_type,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;
			_defense setVariable ["WFBE_StaticDefenseAssignedUnit", _soldier, true];
			[_soldier] allowGetIn true;
			_soldier assignAsGunner _defense;
			[_soldier] orderGetIn true;
			_soldier moveInGunner _defense;
			//--- build/defense audit 2026-07-28: wake the re-man poll early on gunner death (see the
			//--- HC-delegation-fallback branch above for the full rationale).
			_soldier setVariable ["WFBE_DefenseGunRef", _defense];
			_soldier addEventHandler ["Killed", {
				Private ["_gunRef"];
				_gunRef = (_this select 0) getVariable ["WFBE_DefenseGunRef", objNull];
				if (!isNull _gunRef) then {
					_gunRef setVariable ["WFBE_DefenseRecheckDue", true];
				};
			}];
			[_team, 1000, _position] spawn WFBE_CO_FNC_RevealArea;
		};

		[str _side,'UnitsCreated',1] Call UpdateStatistics;
		["INFORMATION", Format ["Server_HandleDefense.sqf: [%1] Unit has been dispatched to a [%2] defense (instant=%3).", str _side,typeOf _defense,_moveInGunner]] Call WFBE_CO_FNC_LogContent;
	};

	//--- build/defense audit 2026-07-28: bounded short-poll replaces the single sleep 420 so a gunner
	//--- killed right after a check is re-manned within ~WFBE_C_DEFENSE_REMAN_POLL seconds instead of
	//--- sitting empty up to ~7 minutes. The seated-gunner Killed EH above sets WFBE_DefenseRecheckDue
	//--- on the gun so the poll can wake early; total idle wait is still capped at 420s, matching the
	//--- original cadence when no death occurs (a 15s poll of one local variable is trivially cheap).
	_defense setVariable ["WFBE_DefenseRecheckDue", false];
	_reManPollWaited = 0;
	while {_reManPollWaited < 420 && {!isNull _defense} && {alive _defense} && {!(_defense getVariable ["WFBE_DefenseRecheckDue", false])}} do {
		sleep _reManPollInterval;
		_reManPollWaited = _reManPollWaited + _reManPollInterval;
	};
};
