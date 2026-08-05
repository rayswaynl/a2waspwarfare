Private ["_flarecount","_i","_isActive","_missile","_type","_vehicle"];
_vehicle = _this select 0;
_missile = _this select 1;

//--- r73b: vehicleChat + FlareActive/FlareCount nil fail-clean.
//--- Bare getVariable returned nil when CM_Set never ran (HC-local hulls, late EH attach) —
//--- `! nil` and `nil > 0` throw and abort the incomingMissile handler (no spoof, no warning chat).
if (isNil "_vehicle" || {isNull _vehicle}) exitWith {};
if (isNil "_missile") exitWith {};

if (alive _vehicle && {(getPos _vehicle) select 2 > 5}) then {
	_isActive = _vehicle getVariable ["FlareActive", false];
	if (isNil "_isActive") then {_isActive = false};
	_type = getNumber (configFile >> "CfgAmmo" >> _missile >> "AirLock");
	if ((_type == 1) && {!_isActive}) then {
		_vehicle setVariable ["FlareActive", true];
		//--- r73b: spelling + driver-local vehicleChat only when player is the driver (radio channel).
		if (!isNull player && {(driver _vehicle) == player}) then {
			_vehicle vehicleChat "WARNING: incoming missile!";
		};
		_flarecount = _vehicle getVariable ["FlareCount", 0];
		if (isNil "_flarecount" || {typeName _flarecount != "SCALAR"}) then {_flarecount = 0};
		if (_flarecount > 0) then {
			_this Spawn CM_Spoofing;
			for [{_i=0}, {_i<8}, {_i=_i+1}] do {
				[_vehicle] Call CM_Flares;
				sleep 0.3;
			};
		};
		_vehicle setVariable ["FlareActive", false];
	};
};
