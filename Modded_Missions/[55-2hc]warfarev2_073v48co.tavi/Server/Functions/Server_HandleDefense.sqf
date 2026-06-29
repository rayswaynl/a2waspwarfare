Private ["_buildings","_closest","_defense","_direction","_distance","_groups","_HC","_index","_manningLoopActive","_moveInGunner","_position","_positions","_side","_sideID","_soldier","_team","_type","_unit","_commander"];
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

while {alive _defense} do {
	if (isNull(gunner _defense) || !alive gunner _defense) then {

		sleep 7;

		//--- EAST/OPFOR empty-static fix (2026-06-14): this base-static path used to GATE all
		//--- manning behind `alive _closest` (a side-Barracks within WFBE_C_BASE_DEFENSE_MANNING_RANGE
		//--- of the gun). When the AI commander placed EAST guns out of barracks range, or the
		//--- barracks was never built / was destroyed, the gun stayed EMPTY forever and logged
		//--- "Canceled auto manning, the barracks is destroyed" (or nothing at build time). The
		//--- working GUER TOWN path (Server_OperateTownDefensesUnits.sqf) has NO barracks gate - it
		//--- mans unconditionally. Since crews mount INSTANTLY at the gun (_moveInGunner=true, no
		//--- walk), the barracks is irrelevant to whether the gun can be manned. So: man the gun
		//--- ALWAYS (gun alive + gunner slot empty), and only use _closest for the legacy
		//--- cover-position math when it happens to be a live, recognised structure (dead code
		//--- under instant mount, but kept guarded against the `find`->-1->`select -1` throw).
		_position = getPosATL _defense;
		if (!_moveInGunner && {alive _closest} && {!(isNull _closest)}) then {
			_type = typeOf _closest;
			_index = (missionNamespace getVariable Format["WFBE_%1STRUCTURENAMES",str _side]) find _type;
			//--- Guard: if _type is not a known structure, _index == -1 and `select -1` THROWS,
			//--- aborting this gun's manning loop permanently. Fall back to the gun position.
			if (_index >= 0) then {
				_distance = (missionNamespace getVariable Format["WFBE_%1STRUCTUREDISTANCES",str _side]) select _index;
				_direction = (missionNamespace getVariable Format["WFBE_%1STRUCTUREDIRECTIONS",str _side]) select _index;
				_position = [getPos _closest,_distance,getDir (_closest) + _direction] Call GetPositionFrom;
			};
		};

		_HC = missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID";
		if (count _HC > 0) then {
			_groups = [] + [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side]];
			_positions = [] + [_position];
			[_side, _groups, _positions, _team, _defense, _moveInGunner] Call WFBE_CO_FNC_DelegateAIStaticDefenceHeadless;

			//--- Server-side fallback watchdog (mirrors the working town path's CreateUnit fallback at
			//--- Server_OperateTownDefensesUnits.sqf:72-84). HC delegation here is fire-and-forget to a
			//--- RANDOM HC with no retry; if it is dropped (HC busy/desynced, or an HC-local AI stalls
			//--- boarding a server-local static) the gun would otherwise sit empty until the next 420s
			//--- tick. Give the delegation a grace window; if no gunner is seated, fill server-side.
			[_defense,_side,_team] Spawn {
				Private ["_defense","_side","_team","_deadline","_sideID","_type","_soldier"];
				_defense = _this select 0;
				_side    = _this select 1;
				_team    = _this select 2;
				_deadline = time + 45;
				waitUntil {
					sleep 5;
					(time > _deadline) || {!alive _defense} || {(!isNull (gunner _defense)) && {alive gunner _defense}}
				};
				//--- Respect the existing "gunner already alive" skip - do NOT double-man.
				if (alive _defense && {isNull (gunner _defense) || {!alive gunner _defense}}) then {
					_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
					_type = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];
					_soldier = [_type,_team,getPosATL _defense,_sideID] Call WFBE_CO_FNC_CreateUnit;
					if !(isNull _soldier) then {
						_defense setVariable ["WFBE_StaticDefenseAssignedUnit", _soldier, true];
						[_soldier] allowGetIn true;
						_soldier assignAsGunner _defense;
						[_soldier] orderGetIn true;
						_soldier moveInGunner _defense;
						[_team, 1000, getPosATL _defense] spawn WFBE_CO_FNC_RevealArea;
						["WARNING", Format ["Server_HandleDefense.sqf: [%1] HC delegation did not seat a gunner for [%2] within grace window - filled server-side.", str _side, typeOf _defense]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		}else{
			_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
			_type = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side];
			_soldier = [_type,_team,getPosATL _defense,_sideID] Call WFBE_CO_FNC_CreateUnit;
			_defense setVariable ["WFBE_StaticDefenseAssignedUnit", _soldier, true];
			[_soldier] allowGetIn true;
			_soldier assignAsGunner _defense;
			[_soldier] orderGetIn true;
			_soldier moveInGunner _defense;
			[_team, 1000, getPosATL _defense] spawn WFBE_CO_FNC_RevealArea;
		};

		[str _side,'UnitsCreated',1] Call UpdateStatistics;
		["INFORMATION", Format ["Server_HandleDefense.sqf: [%1] Unit has been dispatched to a [%2] defense (instant=%3).", str _side,typeOf _defense,_moveInGunner]] Call WFBE_CO_FNC_LogContent;
	};
	sleep 420;
};
