Private ["_cargo","_isHigh","_routeUID","_vehicle"];

_vehicle = _this select 0;
//--- Null/dead hull mid-action: crew/distance reads throw or eject ghosts.
if (isNil "_vehicle" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};

//--- Get the cargo pax (exclude command seats). Null seat slots are fine in the subtract list.
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];

//--- High-altitude cargo eject without HALO freefall leaves players to die on impact.
//--- 50m is deliberately below the menu HALO height: cargo eject must still deploy a chute.
_isHigh = (_vehicle isKindOf "Air") && {((getPos _vehicle) select 2) >= 50};

{
	if (!isNil "_x" && {!isNull _x} && {alive _x} && {!isNull _vehicle} && {_vehicle == vehicle _x}) then {
		if (local _x) then {
			//--- Dealing with a local unit, probably an AI.
			unassignVehicle _x;
			if (!isNull _vehicle && {alive _vehicle}) then {
				if (_isHigh && {isPlayer _x}) then {
					_x setVariable ["wfbe_halo_scripted", true];
					_x action ["EJECT", _vehicle];
					_x setVelocity [0,0,0];
					[_x] Exec "ca\air2\Halo\data\Scripts\HALO_getout.sqs";
				} else {
					_x action ["EJECT", _vehicle];
				};
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
				if (_isHigh && {isPlayer _x}) then {
					//--- High-alt player path: HALO action kind handled in Perform_Action.
					[_routeUID, "HandleSpecial", ["action-perform", _x, "HALO", _vehicle]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[_routeUID, "HandleSpecial", ["action-perform", _x, "EJECT", _vehicle]] Call WFBE_CO_FNC_SendToClients;
				};
			} else {
				//--- AI cargo local to an HC (or any non-player leader) has no UID route. Preserve the
				//--- unit-targeted fallback so the passenger cannot remain stuck aboard.
				[_x, "HandleSpecial", ["action-perform", _x, "EJECT", _vehicle]] Call WFBE_CO_FNC_SendToClient;
			};
		};
	};
	sleep 1;
} forEach _cargo;