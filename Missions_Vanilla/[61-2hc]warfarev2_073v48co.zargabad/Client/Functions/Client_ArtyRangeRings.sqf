//--- Client_ArtyRangeRings.sqf -- Trello #90 (+ spectator v8 streamer-menu live toggle).
//--- Client-local orange ELLIPSE markers on the map around each friendly artillery piece,
//--- showing its WFBE_%1_ARTILLERY_RANGES_MAX firing radius. Mirrors Client_AmbulanceRedeployCircles.sqf:
//--- pure createMarkerLocal, no PV, no server authority. 8-second poll; markers reposition on move,
//--- auto-delete on kill/null.
//--- v8 (owner rulings 2026-08-01): the WFBE_C_ARTY_RING gate re-checks EVERY pass so the streamer
//--- menu (J) can toggle rings live - off tears every ring down, on redraws them. CASTERS (civilian
//--- side) ship with rings FORCED OFF (the spectator map is a clean broadcast surface); when a
//--- caster opts back in via the menu they see ALL belligerent sides' rings, because a civilian
//--- body has no side artillery table of its own.

Private ["_side","_sideTexts","_st","_artyRanges","_rings","_known","_v","_artIdx","_range","_mk","_artyCooldownActive","_artyIntervals","_artyUps","_artyFireTime","_artyLastFire","_artyLogik","_artySharedLast","_artyElapsed","_visualCap","_drawRange","_isCaster"];

_side = sideJoined;
_isCaster = (_side == civilian);
if (_isCaster) then {
	//--- caster default: clean map. The streamer menu flips WFBE_C_ARTY_RING back on live.
	missionNamespace setVariable ["WFBE_C_ARTY_RING", 0];
};
_sideTexts = [str _side];
if (_isCaster) then {_sideTexts = ["WEST", "EAST", "GUER"]};
_rings = [];
_known = [];

//--- Owner ruling 2026-07-22 19:08: cap the DRAWN ellipse radius (metres) so max-range guns
//--- no longer blanket the whole map. 0 = legacy uncapped. The REAL range survives in the
//--- marker label when capped.
_visualCap = missionNamespace getVariable ["WFBE_C_ARTY_RING_VISUAL_CAP", 2000];

while {true} do {
	if ((missionNamespace getVariable ["WFBE_C_ARTY_RING", 1]) <= 0) then {
		//--- toggled off (or caster default): tear down and idle-poll for a re-enable.
		{deleteMarkerLocal (_x select 1)} forEach _rings;
		_rings = [];
		_known = [];
		sleep 5;
	} else {
		//--- live per-8s cooldown colour (own side only; casters have no upgrade table - skip).
		_artyCooldownActive = false;
		if (!_isCaster) then {
			_artyIntervals = missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS";
			if !(isNil "_artyIntervals") then {
				_artyUps = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
				_artyFireTime = _artyIntervals select (_artyUps select WFBE_UP_ARTYTIMEOUT);
				_artyLastFire = fireMissionTime;
				if (isNil "_artyLastFire") then {_artyLastFire = -1000};
				if ((missionNamespace getVariable ["WFBE_C_ARTY_SHARED_COOLDOWN", 0]) > 0) then {
					_artyLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
					if (!isNull _artyLogik) then {
						_artySharedLast = _artyLogik getVariable ["wfbe_arty_last_fire", _artyLastFire];
						if (typeName _artySharedLast == "SCALAR") then {
							if (_artySharedLast > _artyLastFire) then {_artyLastFire = _artySharedLast};
						};
					};
				};
				_artyElapsed = time - _artyLastFire;
				_artyCooldownActive = (_artyElapsed <= _artyFireTime);
			};
		};

		//--- Add rings for newly-seen arty pieces not yet tracked (own side; all sides for casters).
		//--- Tables re-read per piece: late-joiners resolve CLASSNAMES after their own init.
		{
			_v = _x;
			if (alive _v && {!(_v in _known)} && {(str (side _v)) in _sideTexts}) then {
				_st = str (side _v);
				_artyRanges = missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_RANGES_MAX", _st], []];
				_artIdx = [typeOf _v, _st] call IsArtillery;
				if (_artIdx >= 0) then {
					_range = 0;
					if (_artIdx < count _artyRanges) then {_range = _artyRanges select _artIdx};
					if (_range > 0) then {
						_drawRange = _range;
						if ((_visualCap > 0) && {_range > _visualCap}) then {_drawRange = _visualCap};
						_mk = Format ["ArtyRing_%1", _v];
						createMarkerLocal [_mk, getPos _v];
						_mk setMarkerShapeLocal "Ellipse";
						_mk setMarkerBrushLocal "Border";
						_mk setMarkerColorLocal "ColorOrange";
						_mk setMarkerSizeLocal [_drawRange, _drawRange];
						if (_drawRange < _range) then {
							_mk setMarkerTextLocal Format ["ARTY - RNG %1km", (round (_range / 100)) / 10];
						};
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
				_mk setMarkerColorLocal (if (_artyCooldownActive) then {"ColorRed"} else {"ColorOrange"});
			};
		} forEach (+_rings);

		sleep 8;
	};
};
