//--- Client_ArtyRangeRings.sqf -- Trello #90.
//--- Client-local orange ELLIPSE markers on the map around each friendly artillery piece,
//--- showing its WFBE_%1_ARTILLERY_RANGES_MAX firing radius. Mirrors Client_AmbulanceRedeployCircles.sqf:
//--- pure createMarkerLocal, no PV, no server authority. 8-second poll; markers reposition on move,
//--- auto-delete on kill/null. Self-gates on WFBE_C_ARTY_RING > 0 (default 1, owner-ordered ON).

Private ["_side","_sideText","_artyNames","_artyRanges","_rings","_known","_v","_artIdx","_range","_mk","_artyCooldownActive","_artyIntervals","_artyUps","_artyFireTime","_artyLastFire","_artyLogik","_artySharedLast","_artyElapsed"];

if ((missionNamespace getVariable ["WFBE_C_ARTY_RING", 1]) <= 0) exitWith {};

_side     = sideJoined;
_sideText = str _side;
_rings    = [];
_known    = [];

while {true} do {
	//--- P2 map clarity: player-local opt-out deletes the local ring ledger so repeated toggles cannot leak markers.
	if !(missionNamespace getVariable ["WFBE_CL_ShowRangeRings", true]) then {
		{deleteMarkerLocal (_x select 1)} forEach (+_rings);
		_rings = []; _known = [];
		waitUntil {sleep 1; missionNamespace getVariable ["WFBE_CL_ShowRangeRings", true]};
	};
	//--- Re-read per tick: late-joiners resolve CLASSNAMES after their own init.
	_artyNames  = missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_CLASSNAMES",  _sideText], []];
	_artyRanges = missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_RANGES_MAX",   _sideText], []];

	//--- fable/ew-markers WIN3: live per-8s cooldown colour, duplicated from Client_UpdateRHUD.sqf's
	//--- _RHUDUpdateArty block (:267-295) so the ring itself carries the cooldown info, not just the
	//--- RHUD text. Same side-wide inputs: WFBE_C_ARTILLERY_INTERVALS / WFBE_UP_ARTYTIMEOUT /
	//--- fireMissionTime / WFBE_C_ARTY_SHARED_COOLDOWN / wfbe_arty_last_fire (all plain globals --
	//--- no new networked state). Ready => ColorOrange (unchanged default); on cooldown => ColorRed.
	//--- If the interval table is not initialized yet, fail open to "ready" (orange) rather than a
	//--- perpetual false "on cooldown" red.
	_artyCooldownActive = false;
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
			_mk setMarkerColorLocal (if (_artyCooldownActive) then {"ColorRed"} else {"ColorOrange"});
		};
	} forEach (+_rings);

	sleep 8;
};
