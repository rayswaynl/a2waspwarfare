/*
	Common_VectSurfaceNormal.sqf
	WFBE_CO_FNC_VectSurfaceNormal

	Terrain surface normal estimator, part of the SQF utility library (card #25). A2 OA has no
	native `surfaceNormal` command (that is an Arma 3 addition), so this samples ground height
	at two offset points around the queried position with the already-in-tree local-probe pattern
	(`setPos [x,y,0]`, then `getPosASL`; see Common_AICOM_HeliTerrainGuard.sqf /
	server_heli_terrain_guard.sqf) and derives the normal from two
	tangent vectors via WFBE_CO_FNC_VectCross. No gameplay consumer in this PR - cited by future
	card #12/#14 work and any future roof/slope placement logic.

	Params:
		0: _pos     ARRAY [x,y] (or [x,y,z] - z ignored), the world position to sample around.
		1: _radius  NUMBER, optional, sample offset in metres for the two tangent points.
		            Defaults to 2. Smaller values track local terrain detail more tightly;
		            larger values smooth over small bumps.

	Returns: ARRAY [x,y,z], a unit-length normal vector (z component always >= 0 - the surface
	         is assumed upward-facing, i.e. the two sample offsets are chosen so the cross
	         product already points "up"). Returns [0,0,1] (flat-ground fallback) if the
	         computed magnitude is ~0 (degenerate sample).
*/

private ["_pos","_radius","_center","_east","_north","_probe","_h0","_hE","_hN","_tE","_tN","_normal","_mag"];

_pos = _this select 0;
_radius = if (count _this > 1) then {_this select 1} else {2};

//--- A2 OA has no getTerrainHeightASL. Ground a local invisible probe at each XY sample and
//--- read its ASL Z, matching the terrain-sampling pattern used by the helicopter guard.
_probe = "Sign_sphere10cm_EP1" createVehicleLocal [0, 0, 0];
if (isNull _probe) exitWith {[0, 0, 1]};
_probe hideObject true;

_center = [_pos select 0, _pos select 1];
_probe setPos [_center select 0, _center select 1, 0];
_h0 = (getPosASL _probe) select 2;

_east = [(_pos select 0) + _radius, _pos select 1];
_probe setPos [_east select 0, _east select 1, 0];
_hE = (getPosASL _probe) select 2;

_north = [_pos select 0, (_pos select 1) + _radius];
_probe setPos [_north select 0, _north select 1, 0];
_hN = (getPosASL _probe) select 2;
deleteVehicle _probe;

//--- tangent vectors from the center sample toward the east/north samples.
_tE = [_radius, 0, _hE - _h0];
_tN = [0, _radius, _hN - _h0];

//--- cross(east-tangent, north-tangent) points up for a right-handed east/north/up frame.
_normal = [_tE, _tN] call WFBE_CO_FNC_VectCross;
_mag = [_normal] call WFBE_CO_FNC_VectMagnitude;

if (_mag < 0.0001) then {
	_normal = [0, 0, 1];
} else {
	_normal = [(_normal select 0) / _mag, (_normal select 1) / _mag, (_normal select 2) / _mag];
};

_normal
