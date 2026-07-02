Private ["_buildings","_closest","_defense","_groups","_HC","_liveHCs","_manningLoopActive","_moveInGunner","_position","_positions","_side","_sideID","_soldier","_team","_type","_unit","_commander","_sideStillValid","_defenseArea","_areaTeam"];
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

while {alive _defense && _sideStillValid} do {
	if (isNull(gunner _defense) || !alive gunner _defense) then {

		sleep 7;

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
