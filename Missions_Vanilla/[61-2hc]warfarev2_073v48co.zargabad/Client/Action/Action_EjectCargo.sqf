Private ["_cargo","_vehicle","_routeUID"];

_vehicle = _this select 0;
//--- Null/dead hull mid-action: crew/distance reads throw or eject ghosts.
if (isNull _vehicle || {!alive _vehicle}) exitWith {};

//--- Get the cargo pax (exclude command seats). Null seat slots are fine in the subtract list.
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];

{
	if (!isNil "_x" && {!isNull _x} && {alive _x} && {_vehicle == vehicle _x}) then {
		if (local _x) then {
			//--- Dealing with a local unit, probably an AI.
			unassignVehicle _x;
			//--- Re-check hull between sleep ticks / multi-pax loop.
			if (!isNull _vehicle && {alive _vehicle}) then {
				_x action ["EJECT", _vehicle];
			};
		} else {
			//--- Dealing with a player or a non local unit.
			//--- wiki-wins (N-FEATUREBUG-1): the action MUST run on the client where _x is LOCAL, not on
			//--- the leader's client. A passenger who is HIMSELF a player owns his own unit, so route to his
			//--- OWN UID; an AI subordinate is local to the player leading its group, so route to that leader.
			_routeUID = "";
			if (isPlayer _x) then {
				_routeUID = getPlayerUID _x;
			} else {
				if (isPlayer (leader (group _x))) then {_routeUID = getPlayerUID (leader (group _x))};
			};
			if (_routeUID != "" && {!isNull _vehicle}) then {
				[_routeUID, "HandleSpecial", ["action-perform", _x, "EJECT", _vehicle]] Call WFBE_CO_FNC_SendToClients;
			};
		};
	};
	sleep 1;
} forEach _cargo;
