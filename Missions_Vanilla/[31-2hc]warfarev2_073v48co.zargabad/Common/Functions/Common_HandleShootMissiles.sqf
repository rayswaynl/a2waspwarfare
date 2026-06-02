/*
	Creator : Marty. 
	Function that handles the missile glitch restriction to avoid exploit when players shoot guided missiles while using terrain masking.
*/

Private [
	"_unit_who_shot",
	"_weapon",
	"_ammo",
	"_magazine",
	"_projectile",
	"_vehicle",
	"_unit_targeted",
	"_limit_distance",
	"_distance_target_player",
	"_fromPos",
	"_targetPos",
	"_terrainMasked",
	"_toleranceAboveGround",
	"_isRestrictedMissileAmmo"
];

_unit_who_shot = _this select 0; 	// Unit or vehicle that fired.
_weapon        = _this select 1; 	// Weapon used.
_ammo          = _this select 4;	// Ammo class.
_magazine      = _this select 5;	// Magazine class.
_projectile    = _this select 6;	// Projectile object.

// Marty:
// Only monitor the local player.
// Depending on where the Fired eventHandler is attached, _unit_who_shot can be either the player unit or the vehicle itself, so we check both cases.
_vehicle = vehicle player;

if (_vehicle == player) exitWith {}; // Infantry is not concerned by this restriction.
if !(player in crew _vehicle) exitWith {};
if !(_unit_who_shot == player || _unit_who_shot == _vehicle) exitWith {};

// Marty:
// Automatically detect guided / lockable missile-like ammo classes.
// This avoids maintaining a manual ammo classname list and covers more missiles.
_isRestrictedMissileAmmo = {
	Private [
		"_ammo",
		"_ammoCfg",
		"_simulation",
		"_canLock",
		"_irLock",
		"_laserLock",
		"_airLock",
		"_manualControl",
		"_isMissileOrRocket",
		"_isGuided"
	];

	_ammo = _this select 0;
	_ammoCfg = configFile >> "CfgAmmo" >> _ammo;

	if !(isClass _ammoCfg) exitWith {false};

	_simulation = getText (_ammoCfg >> "simulation");

	_canLock = getNumber (_ammoCfg >> "canLock");
	_irLock = getNumber (_ammoCfg >> "irLock");
	_laserLock = getNumber (_ammoCfg >> "laserLock");
	_airLock = getNumber (_ammoCfg >> "airLock");
	_manualControl = getNumber (_ammoCfg >> "manualControl");

	/*
		Most missiles / rockets in Arma 2 use missile-like or rocket-like simulations.
		We do not want bullets, shells, grenades or bombs to be affected.
	*/
	_isMissileOrRocket = _simulation in [
		"shotMissile",
		"shotRocket"
	];

	/*
		Guided / lockable missiles usually expose one or more of these config values.
		manualControl covers wire-guided / SACLOS style missiles.

		For the Fired eventHandler restriction, canLock can be kept because the projectile has already been fired.
		This is less likely to create false positives than in the pre-shot warning script.
	*/
	_isGuided = (
		_canLock > 0 ||
		_irLock > 0 ||
		_laserLock > 0 ||
		_airLock > 0 ||
		_manualControl > 0
	);

	(_isMissileOrRocket && _isGuided)
};

if !([_ammo] call _isRestrictedMissileAmmo) exitWith {};

// Marty:
// cursorTarget is local to the player and allows us to retrieve the currently aimed / targeted object.
// In Arma 2 OA, there is no reliable universal command to retrieve the player's actual missile lock target
// for all relevant vehicle weapons, so cursorTarget is used as the practical solution.
_unit_targeted = cursorTarget;
if (isNull _unit_targeted) exitWith {}; // If there is no target, we quit.

// Only vehicles are relevant targets here.
if !(_unit_targeted isKindOf "LandVehicle" || _unit_targeted isKindOf "Air") exitWith {};

/*
_limit_distance = missionNamespace getVariable "WFBE_C_GAMEPLAY_MISSILE_TERRAIN_MASKING_DISTANCE";
_distance_target_player = player distance _unit_targeted;

// Marty:
// Restriction only applies under the configured distance.
// Example: 3500 meters.
if (_distance_target_player > _limit_distance) exitWith {};

systemChat format ["point passage 3"];
*/

// Marty:
// Check if terrain blocks the line between the firing vehicle and the target.
// Slight vertical offsets are added to avoid detecting tiny ground contact near the vehicle or target.
// It adds a small vertical tolerance to avoid false terrain masking detection.
_toleranceAboveGround = 2.5; // tolerance in meters added above ground, corresponding roughly to visual sight height of a tank.

_fromPos = getPosASL _vehicle;
_fromPos set [2, (_fromPos select 2) + _toleranceAboveGround]; // tolerance only on the z axis (= altitude), in meters.

_targetPos = getPosASL _unit_targeted;
_targetPos set [2, (_targetPos select 2) + _toleranceAboveGround];

_terrainMasked = terrainIntersectASL [_fromPos, _targetPos];

if !(_terrainMasked) exitWith {};

// If we reach this point, the player fired a restricted guided missile while masked by terrain.
deleteVehicle _projectile;

// Warn the player that the missile launch has been blocked.
hint localize "STR_WF_MESSAGE_MissileTerrainMaskingRestriction";
playSound "MissileLaunchBlocked";