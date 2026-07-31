Private ["_cargo","_isHigh","_minH","_routeUID","_vehicle"];

_vehicle = _this select 0;

if (isNil "_vehicle" || {isNull _vehicle}) exitWith {};

//--- Get the crew (cargo only).
_cargo = (crew _vehicle) - [driver _vehicle, gunner _vehicle, commander _vehicle];

//--- High-altitude cargo eject without HALO freefall leaves players to die on impact.
_minH = missionNamespace getVariable ["WFBE_C_PLAYERS_HALO_HEIGHT", 200];
if (typeName _minH != "SCALAR") then {_minH = 200};
//--- Trigger HALO path well below menu HALO height (50m still lethal freefall without chute).
_isHigh = (_vehicle isKindOf "Air") && {((getPos _vehicle) select 2) >= 50};

{
	//--- Vehicle may despawn mid-loop (sleep 1); re-validate each iteration.
	if (isNull _vehicle) exitWith {};
	if (alive _x && {_vehicle == vehicle _x}) then {
		if (local _x) then {
			if (_isHigh && {isPlayer _x}) then {
				_x setVariable ["wfbe_halo_scripted", true];
				unassignVehicle _x;
				_x action ["EJECT", _vehicle];
				_x setVelocity [0,0,0];
				[_x] Exec "ca\air2\Halo\data\Scripts\HALO_getout.sqs";
			} else {
				unassignVehicle _x;
				_x action ["EJECT", _vehicle];
			};
		} else {
			//--- Route to the client where the unit is local (player UID or AI leader).
			_routeUID = "";
			if (isPlayer _x) then {
				_routeUID = getPlayerUID _x;
			} else {
				if (isPlayer (leader (group _x))) then {_routeUID = getPlayerUID (leader (group _x))};
			};
			if (_routeUID != "") then {
				//--- High-alt player path: "HALO" action kind handled in Perform_Action.
				if (_isHigh && {isPlayer _x}) then {
					[_routeUID, "HandleSpecial", ["action-perform", _x, "HALO", _vehicle]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[_routeUID, "HandleSpecial", ["action-perform", _x, "EJECT", _vehicle]] Call WFBE_CO_FNC_SendToClients;
				};
			};
		};
	};
	sleep 1;
} forEach _cargo;