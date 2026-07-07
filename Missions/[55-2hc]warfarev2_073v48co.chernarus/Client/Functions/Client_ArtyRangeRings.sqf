//--- Client_ArtyRangeRings.sqf -- Trello #90.
//--- Client-local orange ELLIPSE markers on the map around each friendly artillery piece,
//--- showing its WFBE_%1_ARTILLERY_RANGES_MAX firing radius. Mirrors Client_AmbulanceRedeployCircles.sqf:
//--- pure createMarkerLocal, no PV, no server authority. 8-second poll; markers reposition on move,
//--- auto-delete on kill/null. Self-gates on WFBE_C_ARTY_RING > 0 (default 1, owner-ordered ON).

Private ["_side","_sideText","_artyNames","_artyRanges","_rings","_known","_v","_artIdx","_range","_mk"];

if ((missionNamespace getVariable ["WFBE_C_ARTY_RING", 1]) <= 0) exitWith {};

_side     = sideJoined;
_sideText = str _side;
_rings    = [];
_known    = [];

while {true} do {
	//--- Re-read per tick: late-joiners resolve CLASSNAMES after their own init.
	_artyNames  = missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_CLASSNAMES",  _sideText], []];
	_artyRanges = missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_RANGES_MAX",   _sideText], []];

	//--- Add rings for newly-seen friendly arty pieces not yet tracked.
	{
		_v = _x;
		if ((side _v == _side) && {alive _v} && {!(_v in _known)}) then {
			_artIdx = [typeOf _v, _sideText] call IsArtillery;
			if (_artIdx >= 0) then {
				_range = 0;
				if (_artIdx < count _artyRanges) then {_range = _artyRanges select _artIdx};
				if (_range > 0) then {
					_mk = Format ["ArtyRing_%1", _v];
					createMarkerLocal [_mk, getPos _v];
					_mk setMarkerShapeLocal "Ellipse";
					_mk setMarkerBrushLocal "Border";
					_mk setMarkerColorLocal "ColorOrange";
					_mk setMarkerSizeLocal [_range, _range];
					_rings = _rings + [[_v, _mk]];
					_known = _known + [_v];
				};
			};
		};
	} forEach vehicles;

	//--- Reposition live rings; remove rings for dead/null pieces.
	{
		_v  = _x select 0;
		_mk = _x select 1;
		if (isNull _v || {!alive _v}) then {
			deleteMarkerLocal _mk;
			_rings = _rings - [_x];
			_known = _known - [_v];
		} else {
			_mk setMarkerPosLocal (getPos _v);
		};
	} forEach (+_rings);

	sleep 8;
};
