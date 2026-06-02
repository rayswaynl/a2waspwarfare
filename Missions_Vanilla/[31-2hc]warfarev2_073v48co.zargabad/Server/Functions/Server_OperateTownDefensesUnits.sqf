/*
	Oeprate the defenses in a town, spawn or despawn.
	 Parameters:
		- Town.
		- Side.
		- Action ("spawn"/"remove").
*/

Private ["_action","_ai_delegation_enabled","_defense","_groups","_perfActive","_perfDelegated","_perfItemStart","_perfRemoved","_perfScope","_perfSpawned","_perfStart","_perfTotal","_positions","_side","_spawn","_team","_town","_unit","_units","_use_server","_sideID"];

_town = _this select 0;
_side = _this select 1;
_action = _this select 2;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
// Marty: Performance Audit measures town defense unit spawn/remove bursts separately from server_town_ai.
_perfStart = diag_tickTime;
_perfActive = 0;
_perfSpawned = 0;
_perfRemoved = 0;
_perfDelegated = 0;
_perfTotal = 0;


if (_sideID != WFBE_C_GUER_ID) exitWith {};
switch (_action) do {
	case "spawn": {
		//_side_group = createGroup _side;
		//--- Man the defenses.
		{
			_perfItemStart = diag_tickTime;
			_perfTotal = _perfTotal + 1;
			_defense = _x getVariable "wfbe_defense";
			_use_server = true;
			if !(isNil '_defense') then {
				_positions = [];
				_groups = [];
				if !(alive gunner _defense) then { //--- Make sure that the defense gunner is null or dead.
					_ai_delegation_enabled = missionNamespace getVariable "WFBE_C_AI_DELEGATION";
					if(_ai_delegation_enabled > 0)then{
						switch (_ai_delegation_enabled) do {
							case 2: { //--- Headless Client delegation.
								[_positions, getPos _x] call WFBE_CO_FNC_ArrayPush;
								[_groups, missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side]] call WFBE_CO_FNC_ArrayPush;


								_team = missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side];

								if (isNull _team) then {
									_team = createGroup _side;
									missionNamespace setVariable [format["WFBE_%1_DefenseTeam", _side], _team];
								};

								if (count(missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID") > 0) then {
									// Marty: Delegated town static gunners are also defender AI for town activation filtering.
									[_side, _groups, _positions, _team, _defense, true, true] Call WFBE_CO_FNC_DelegateAIStaticDefenceHeadless;
									_use_server = false;
									_perfDelegated = _perfDelegated + 1;
								};
							};
						};
					};

					if (_use_server) then {
						_unit = [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side],missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side], getPos _x, _side] Call WFBE_CO_FNC_CreateUnit;
						// Marty: Mark town static gunners so nearby enemy towns do not activate from them.
						_unit setVariable ["WFBE_IsTownDefenderAI", true, true];
						(group _unit) setVariable ["WFBE_IsTownDefenderAI", true];
						_unit assignAsGunner _defense;
						[_unit] orderGetIn true;
						_unit moveInGunner _defense;
						[group _unit, 175, getPos _defense] spawn WFBE_CO_FNC_RevealArea;
						_x setVariable ["wfbe_defense_operator", _unit]; //--- Track the original gunner.
						_perfSpawned = _perfSpawned + 1;
					};
				};

			};
			_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
			
			// Added small delay to avoid the lag spike when spawning all units at once
			sleep 0.5;
		} forEach (_town getVariable "wfbe_town_defenses");

		//--- Reveal the town area to the statics.
		if (count (_town getVariable "wfbe_town_defenses") > 0) then {
			[missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side], _town getVariable "range", _town] Call RevealArea;
		};

		["INFORMATION", Format ["Server_OperateTownDefensesUnits.sqf : Town [%1] defenses were manned for [%2] defenses on [%3].", _town getVariable "name", count (_town getVariable "wfbe_town_defenses"),_side]] Call WFBE_CO_FNC_LogContent;
	};
	case "remove": {
		//--- De-man the defenses.
		{
			_perfItemStart = diag_tickTime;
			_perfTotal = _perfTotal + 1;
			_defense = _x getVariable "wfbe_defense";

			if !(isNil '_defense') then {
				_unit = gunner _defense;
				if !(isNull _unit) then { //--- Make sure that we do not remove a player's unit.
					if (alive _unit) then {
						if (isNil {(group _unit) getVariable "wfbe_funds"}) then {_unit setPos (getPos _x);	deleteVehicle _unit;_perfRemoved = _perfRemoved + 1};
					} else {
						_unit setPos (getPos _x); deleteVehicle _unit;_perfRemoved = _perfRemoved + 1;
					};
				};
			};
			if !(isNil {_x getVariable "wfbe_defense_operator"}) then { //--- Delete the original gunner if he's still around.
				if (alive(_x getVariable "wfbe_defense_operator")) then {deleteVehicle (_x getVariable "wfbe_defense_operator");_perfRemoved = _perfRemoved + 1};
				_x setVariable ["wfbe_defense_operator", nil];
			};
			_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		} forEach (_town getVariable "wfbe_town_defenses");

		["INFORMATION", Format ["Server_OperateTownDefensesUnits.sqf : Town [%1] defenses units were removed for [%2] defenses.", _town getVariable "name", count (_town getVariable "wfbe_town_defenses")]] Call WFBE_CO_FNC_LogContent;
	};
};

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["town_defenses_units", _perfActive, Format["town:%1;side:%2;action:%3;defenses:%4;spawned:%5;delegated:%6;removed:%7;cycleMs:%8", _town getVariable "name", _side, _action, _perfTotal, _perfSpawned, _perfDelegated, _perfRemoved, round ((diag_tickTime - _perfStart) * 1000)], _perfScope] Call PerformanceAudit_Record;
	};
};
