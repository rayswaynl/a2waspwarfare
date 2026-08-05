/*
	Structure damage gate. Parameters (from a HandleDamage EH): [_this select 0, _this select 2,
	_this select 3, _this select 4] = [building, damage, origin, ammo]. Callers MUST pass all four
	args (see Construction_HQSite.sqf deployed-HQ site); a 3-arg call leaves _ammo nil and the
	B_30mm_HE/B_23mm_AA reduction in Server_HandleBuildingDamage.sqf can never engage.
*/
Private ['_building','_dammages','_origin','_side','_sideBuilding','_side'];

_building = _this select 0;
_dammages = _this select 1;
_origin = _this select 2;
_ammo = _this select 3;


_sideBuilding = _building getVariable "wfbe_side";
_side = side _origin;

//--- cmdcon41 (REAL-BASE-ASSAULT part 1): the legacy `_side in [_sideBuilding, sideEnemy]` gate zeroes
//--- BOTH owner AND enemy fire (sideEnemy is the mission OPFOR alias), so enemy weapons genuinely can't
//--- kill the base - forcing the scripted siege-raze. When WFBE_C_STRUCTURES_ENEMY_DESTROYABLE (default 1)
//--- is on, drop damage ONLY for true friendly fire (side == owner) or unattributed engine damage
//--- (isNull _origin); let genuine enemy fire route into HandleBuildingDamage. Side == is A2-safe.
//--- Flag off -> legacy verbatim (one-flip rollback).
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_ENEMY_DESTROYABLE", 1]) > 0) then {
	if ((isNull _origin) || {_side == _sideBuilding}) then {
		_dammages = false;
	} else {
		_dammages = [_building, _dammages, _ammo] Call HandleBuildingDamage;
	};
} else {
	if (_side in [_sideBuilding, sideEnemy]) then {
		_dammages = false;
	} else {
		_dammages = [_building, _dammages, _ammo] Call HandleBuildingDamage;
	};
};

_dammages