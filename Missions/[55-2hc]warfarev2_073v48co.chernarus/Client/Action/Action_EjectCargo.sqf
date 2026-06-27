Private ["_cargo","_vehicle"];

_vehicle = _this select 0;

//--- Get the crew.
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];

{
	if (alive _x && _vehicle == vehicle _x) then {
		if (local _x) then {
			//--- Dealing with a local unit, probably an AI.
			unassignVehicle _x;
			_x action ["EJECT", _vehicle];
		} else {
			//--- Dealing with a player or a non local unit.
			//--- wiki-wins (N-FEATUREBUG-1): the action MUST run on the client where _x is LOCAL, not on
			//--- the leader's client. A passenger who is HIMSELF a player owns his own unit, so route to his
			//--- OWN UID; an AI subordinate is local to the player leading its group, so route to that leader.
			private "_routeUID";
			_routeUID = "";
			if (isPlayer _x) then {
				_routeUID = getPlayerUID _x;
			} else {
				if (isPlayer(leader (group _x))) then {_routeUID = getPlayerUID(leader(group _x))};
			};
			if (_routeUID != "") then {
				[_routeUID, "HandleSpecial", ["action-perform", _x, "EJECT", _vehicle]] Call WFBE_CO_FNC_SendToClients;
			};
		};
	};
	sleep 1;
} forEach _cargo;