//--- Trello #76: ambulance / medic-redeploy redeploy-range circles.
//--- For every friendly ambulance (WFBE_%1AMBULANCES) and medic redeploy truck (WFBE_%1REDEPLOYTRUCKS),
//--- paint a client-LOCAL yellow Ellipse showing the mobile-respawn radius
//--- (WFBE_C_RESPAWN_RANGES select side's WFBE_UP_RESPAWNRANGE upgrade level), so players see where
//--- they can redeploy. Pure local markers (createMarkerLocal/setMarker*Local); no PV, no authority.
//--- Self-gates on WFBE_C_RESPAWN_MOBILE>0 and own side only. Mirrors the Init_BaseStructure CBR watcher:
//--- a single periodic watch block re-positions live circles, adds rings for new vehicles, re-sizes on
//--- upgrade change, and removes rings for dead/null vehicles.

Private ["_sideText","_side","_ambList","_truckList","_typeList","_range","_rings","_lvl","_upgrades","_v","_typeOf","_mk","_known","_lastLvl"];

if ((missionNamespace getVariable ["WFBE_C_RESPAWN_MOBILE", 0]) <= 0) exitWith {};

_side     = sideJoined;
_sideText = str _side;
_ambList   = missionNamespace getVariable [Format ["WFBE_%1AMBULANCES",   _sideText], []];
_truckList = missionNamespace getVariable [Format ["WFBE_%1REDEPLOYTRUCKS", _sideText], []];
_typeList = _ambList + _truckList;
if (count _typeList == 0) exitWith {};

//--- _rings: array of [vehicle, markerName] pairs we currently maintain.
_rings   = [];
_known   = [];
_lastLvl = -1;

//--- Helper: current redeploy radius for this side from the respawn-range upgrade level.
_range = 0;

while {true} do {
	_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
	_lvl = 0;
	if (!isNil "WFBE_UP_RESPAWNRANGE" && count _upgrades > WFBE_UP_RESPAWNRANGE) then {
		_lvl = _upgrades select WFBE_UP_RESPAWNRANGE;
	};
	_range = (missionNamespace getVariable "WFBE_C_RESPAWN_RANGES") select _lvl;

	//--- Add rings for newly-seen friendly redeploy vehicles.
	{
		_v = _x;
		_typeOf = typeOf _v;
		if ((side _v == _side) && {_typeOf in _typeList} && {!(_v in _known)}) then {
			_mk = Format ["AmbRange_%1", _v];
			createMarkerLocal [_mk, getPos _v];
			_mk setMarkerShapeLocal "Ellipse";
			_mk setMarkerBrushLocal "Border";
			_mk setMarkerColorLocal "ColorYellow";
			_mk setMarkerSizeLocal [_range, _range];
			_rings = _rings + [[_v, _mk]];
			_known = _known + [_v];
		};
	} forEach vehicles;

	//--- Update existing rings: reposition, drop dead/null, re-size on upgrade change.
	{
		_v  = _x select 0;
		_mk = _x select 1;
		if (isNull _v || {!alive _v}) then {
			deleteMarkerLocal _mk;
			_rings = _rings - [_x];
			_known = _known - [_v];
		} else {
			_mk setMarkerPosLocal (getPos _v);
			if (_lvl != _lastLvl) then {_mk setMarkerSizeLocal [_range, _range]};
		};
	} forEach (+_rings);

	_lastLvl = _lvl;
	sleep 5;
};
