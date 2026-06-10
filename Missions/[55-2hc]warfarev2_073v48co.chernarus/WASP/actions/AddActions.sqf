
While {!(Alive Player)} do {sleep 2;};

//player addAction [localize "STR_WF_Gear", "WASP\actions\GearYouUnit.sqf", [], 1, false, false, "", "cursorTarget distance player < 3 && cursorTarget in units player"];

//player addAction [localize "STR_WASP_actions_ChangeWheels", "WASP\actions\car_wheel_new.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Car')&&(player distance cursorTarget<5)"];


//OnArmor
//player addAction [localize "STR_WASP_actions_OnArmor-GetOnArmor", "WASP\actions\OnArmor\GetOnArmor.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Tank')&&(player distance cursorTarget<7)"];
//player addAction [localize "STR_WASP_actions_OnArmor-GetOnArmor-group", "WASP\actions\OnArmor\GetOnArmorBots.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Tank')&&(player distance cursorTarget<30)"];
//player addAction [localize "STR_WASP_actions_OnArmor-GetOutArmor-group", "WASP\actions\OnArmor\GetOutBots.sqf", [], 1, false, true, "", "(cursorTarget isKindOf 'Tank')&&(player distance cursorTarget<30)"];

//player addEventHandler ["HandleDamage", {false;if (player != (_this select 3)) then {(_this select 3) setDammage 0}}]; //--- God-Slayer mode.
208 = player addAction ["<t color='#FF0000'>"+ "RECOVER HQ" + "  " + str (missionNameSpace getVariable 'WFBE_C_BASE_HQ_REPAIR_PRICE_CASH') +"$" +"</t>", "WASP\actions\Action_RepairMHQDepot.sqf", [], 1, false, true, "", "!(alive ((SideJoined) Call WFBE_CO_FNC_GetSideHQ))&&(leader  (SideJoined call GetCommanderTeam) == leader (vehicle player))&&(typeOf cursorTarget in ['Land_fortified_nest_big_EP1','WFBE_C_DEPOT'])&&(cursorTarget distance player < 100)"];

//--- Earplugs: persistent toggle. AddActions.sqf is re-execVM'd on each respawn (via OnKilled.sqf),
//--- so the action is re-registered. The title reflects current state via the missionNamespace flag.
//--- fadeSound persists across respawn independently.
private ["_earplugTitle"];
_earplugTitle = if (missionNamespace getVariable ["WFBE_WASP_EarplugActive", false]) then {"Earplugs OUT"} else {"Earplugs IN"};
player addAction [_earplugTitle, "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];

//--- Vehicle mirror: spawn a monitor loop that keeps an earplug action on the
//--- player's current vehicle so the toggle is reachable while mounted.
//--- Guard flag prevents a second loop spawning on respawn (AddActions re-execVM).
if (!(missionNamespace getVariable ["WFBE_WASP_EarplugVehLoop", false])) then {
	missionNamespace setVariable ["WFBE_WASP_EarplugVehLoop", true];
	[] spawn {
		private ["_lastVeh","_vehActionID","_title"];
		_lastVeh = objNull;
		_vehActionID = -1;
		while {alive player} do {
			sleep 2;
			private ["_curVeh"];
			_curVeh = vehicle player;
			//--- Player is mounted and the vehicle has changed since last check.
			if (_curVeh != player && _curVeh != _lastVeh) then {
				//--- Remove old vehicle action if we still have one.
				if (_vehActionID != -1 && !isNull _lastVeh) then {
					_lastVeh removeAction _vehActionID;
					_vehActionID = -1;
				};
				//--- Add action to new vehicle with current state title.
				_title = if (missionNamespace getVariable ["WFBE_WASP_EarplugActive", false]) then {"Earplugs OUT"} else {"Earplugs IN"};
				_vehActionID = _curVeh addAction [_title, "WASP\actions\EarplugToggle.sqf", [], 1, false, false, "", ""];
				player setVariable ["WFBE_WASP_EarplugVehID",  _vehActionID];
				player setVariable ["WFBE_WASP_EarplugVehRef", _curVeh];
				_lastVeh = _curVeh;
			};
			//--- Player has dismounted — remove action from old vehicle.
			if (_curVeh == player && _vehActionID != -1) then {
				if (!isNull _lastVeh) then {_lastVeh removeAction _vehActionID};
				_vehActionID = -1;
				player setVariable ["WFBE_WASP_EarplugVehID",  -1];
				player setVariable ["WFBE_WASP_EarplugVehRef", objNull];
				_lastVeh = objNull;
			};
		};
	};
};