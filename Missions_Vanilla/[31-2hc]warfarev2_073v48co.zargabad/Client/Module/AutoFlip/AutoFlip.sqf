/*
	Author: Marty
	Description:
		Automatically rights nearby flipped ground vehicles after they remain stuck for a short time.
*/

private ["_scanDelay","_tiltLimit","_stuckDelay","_cooldown","_maxSpeed","_processVehicle","_vehicles","_playerVehicle","_unitVehicle","_now"];

_scanDelay = 3;
_tiltLimit = 0.35;
_stuckDelay = 10;
_cooldown = 45;
_maxSpeed = 2;

// Marty: Keep the per-vehicle checks linear so future tuning stays readable.
_processVehicle = {
	private ["_vehicle","_now","_upZ","_velocity","_speed","_lastFlip","_since","_pos","_isWrongType","_isTilted","_isSlow","_isGrounded","_isDry","_isReady","_vehicleName","_message"];

	_vehicle = _this select 0;
	_now = _this select 1;

	if (isNull _vehicle) exitWith {};
	if (!alive _vehicle) exitWith {};

	_isWrongType = (_vehicle isKindOf "Motorcycle") || (_vehicle isKindOf "Air") || (_vehicle isKindOf "Ship");
	if (_isWrongType) exitWith {};

	_upZ = (vectorUp _vehicle) select 2;
	_velocity = velocity _vehicle;
	_speed = sqrt (((_velocity select 0) * (_velocity select 0)) + ((_velocity select 1) * (_velocity select 1)) + ((_velocity select 2) * (_velocity select 2)));
	_lastFlip = _vehicle getVariable ["WFBE_AutoFlip_LastFlip", -999];

	_isTilted = _upZ < _tiltLimit;
	_isSlow = _speed < _maxSpeed;
	_isGrounded = (getPos _vehicle select 2) < 3;
	_isDry = !surfaceIsWater (getPos _vehicle);
	_isReady = (_now - _lastFlip) > _cooldown;

	if (!_isTilted) exitWith {_vehicle setVariable ["WFBE_AutoFlip_StuckSince", -1, false]};
	if (!_isSlow) exitWith {_vehicle setVariable ["WFBE_AutoFlip_StuckSince", -1, false]};
	if (!_isGrounded) exitWith {_vehicle setVariable ["WFBE_AutoFlip_StuckSince", -1, false]};
	if (!_isDry) exitWith {_vehicle setVariable ["WFBE_AutoFlip_StuckSince", -1, false]};
	if (!_isReady) exitWith {_vehicle setVariable ["WFBE_AutoFlip_StuckSince", -1, false]};

	_since = _vehicle getVariable ["WFBE_AutoFlip_StuckSince", -1];

	if (_since < 0) exitWith {
		_vehicle setVariable ["WFBE_AutoFlip_StuckSince", _now, false];

		if (WF_Debug) then {
			["AUTOFLIP", Format ["AutoFlip: tracking %1 at %2, upZ %3, speed %4.", typeOf _vehicle, getPos _vehicle, _upZ, _speed]] Call WFBE_CO_FNC_LogContent;
		};
	};

	if ((_now - _since) < _stuckDelay) exitWith {};

	_pos = getPos _vehicle;
	_vehicle setVectorUp [0,0,1];
	_vehicle setPos [_pos select 0, _pos select 1, 0.5];
	_vehicle setVelocity [0,0,-0.5];
	_vehicle setVariable ["WFBE_AutoFlip_LastFlip", _now, true];
	_vehicle setVariable ["WFBE_AutoFlip_StuckSince", -1, false];

	// Marty: Notify only this client when its local AutoFlip watcher actually rights a vehicle.
	_vehicleName = [typeOf _vehicle, "displayName"] Call GetConfigInfo;
	_message = localize "STR_WF_INFO_AutoFlip_Righted";
	if (_message == "") then {_message = "Auto-flip: %1 was righted."};
	systemChat Format [_message, _vehicleName];

	if (WF_Debug) then {
		["AUTOFLIP", Format ["AutoFlip: righted %1 at %2 after %3 seconds.", typeOf _vehicle, _pos, round (_now - _since)]] Call WFBE_CO_FNC_LogContent;
	};
};

while {true} do {
	sleep _scanDelay;

	if (alive player && !gameOver) then {
		_vehicles = [];
		_playerVehicle = vehicle player;

		// Marty: Only watch the player's own vehicle and vehicles currently used by units in the player's group.
		if (_playerVehicle != player) then {
			_vehicles set [count _vehicles, _playerVehicle];
		};

		{
			_unitVehicle = vehicle _x;

			if (_unitVehicle != _x && !(_unitVehicle in _vehicles)) then {
				_vehicles set [count _vehicles, _unitVehicle];
			};
		} forEach units group player;

		_now = time;

		{
			[_x, _now] Call _processVehicle;
		} forEach _vehicles;
	};
};
