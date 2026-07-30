
While {!(Alive Player)} do {sleep 2;};




//OnArmor
//player addAction [localize "STR_WASP_actions_OnArmor-GetOnArmor", "WASP\actions\OnArmor\GetOnArmor.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Tank')&&(player distance cursorTarget<7)"];
//player addAction [localize "STR_WASP_actions_OnArmor-GetOnArmor-group", "WASP\actions\OnArmor\GetOnArmorBots.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Tank')&&(player distance cursorTarget<30)"];
//player addAction [localize "STR_WASP_actions_OnArmor-GetOutArmor-group", "WASP\actions\OnArmor\GetOutBots.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Tank')&&(player distance cursorTarget<30)"];

//player addEventHandler ["HandleDamage", {false;if (player != (_this select 3)) then {(_this select 3) setDammage 0}}]; //--- God-Slayer mode.
//--- fix(code-as-string r33): condition must embed the LIVE depot classname (WFBE_C_DEPOT), not the
//--- literal key string 'WFBE_C_DEPOT'. Title price is still attach-time (constant); condition re-checks
//--- HQ/commander/cursor every frame.
player addAction ["<t color='#FF0000'>"+ "RECOVER HQ" + "  " + str (missionNameSpace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_CASH') +"$" +"</t>", "WASP\actions\Action_RepairMHQDepot.sqf", [], 1, false, true, "", Format ["!(alive ((SideJoined) Call WFBE_CO_FNC_GetSideHQ))&&(leader (SideJoined call GetCommanderTeam) == leader (vehicle player))&&(typeOf cursorTarget in ['Land_fortified_nest_big_EP1','%1'])&&(cursorTarget distance player < 100)", missionNamespace getVariable ["WFBE_C_DEPOT", "Land_fortified_nest_big_EP1"]]];

//--- Earplugs: persistent toggle. AddActions.sqf is re-execVM'd on each respawn (via OnKilled.sqf),
//--- so the action is re-registered. The title reflects current state via the missionNamespace flag.
//--- fadeSound persists across respawn independently.
private ["_earplugTitle","_earplugFootID"];
_earplugTitle = if (missionNamespace getVariable ["WFBE_WASP_EarplugActive", false]) then {"Earplugs OUT"} else {"Earplugs IN"};
_earplugFootID = player addAction [_earplugTitle, "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
player setVariable ["WFBE_WASP_EarplugFootID", _earplugFootID];

//--- Vehicle mirror: spawn a monitor loop that keeps an earplug action on the
//--- player's current vehicle so the toggle is reachable while mounted.
//--- Guard flag prevents a second loop spawning on respawn (AddActions re-execVM).
//--- The loop is PERMANENT (while true, alive-gated inside): a `while {alive player}`
//--- loop would exit on first death with the guard flag still set and kill vehicle
//--- mirroring for the rest of the session.
//--- The action id is read from the player variable each tick — EarplugToggle.sqf
//--- re-adds the vehicle action (new id) on every in-vehicle toggle, so a loop-local
//--- copy would go stale and leak an orphan action on dismount.
if (!(missionNamespace getVariable ["WFBE_WASP_EarplugVehLoop", false])) then {
	missionNamespace setVariable ["WFBE_WASP_EarplugVehLoop", true];
	[] spawn {
		private ["_lastVeh","_lastID","_curVeh","_vehID","_title"];
		_lastVeh = objNull;
		_lastID  = -1;
		while {true} do {
			sleep 2;
			if (alive player) then {
				_curVeh = vehicle player;
				_vehID  = player getVariable ["WFBE_WASP_EarplugVehID", -1];
				//--- Mounted a (new) vehicle: move the mirror action onto it.
				if (_curVeh != player && {_curVeh != _lastVeh}) then {
					if (_vehID != -1 && {!isNull _lastVeh}) then {_lastVeh removeAction _vehID};
					_title = if (missionNamespace getVariable ["WFBE_WASP_EarplugActive", false]) then {"Earplugs OUT"} else {"Earplugs IN"};
					_vehID = _curVeh addAction [_title, "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
					player setVariable ["WFBE_WASP_EarplugVehID",  _vehID];
					player setVariable ["WFBE_WASP_EarplugVehRef", _curVeh];
					_lastVeh = _curVeh;
				};
				//--- Dismounted: clean the mirror action off the old vehicle.
				if (_curVeh == player && {_vehID != -1}) then {
					if (!isNull _lastVeh) then {_lastVeh removeAction _vehID};
					player setVariable ["WFBE_WASP_EarplugVehID",  -1];
					player setVariable ["WFBE_WASP_EarplugVehRef", objNull];
					_lastVeh = objNull;
				};
				_lastID = player getVariable ["WFBE_WASP_EarplugVehID", -1];
			} else {
				//--- Died (possibly while mounted): the new body's vars reset, so clean
				//--- the old vehicle via the loop-local copies to avoid an orphan action.
				if (!isNull _lastVeh && {_lastID != -1}) then {_lastVeh removeAction _lastID};
				_lastVeh = objNull;
				_lastID  = -1;
			};
		};
	};
};