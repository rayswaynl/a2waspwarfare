/*
	Common_RadiusHold.sqf
	WFBE_CO_FNC_RadiusHold_Register

	fable/radius-hold-primitive (GR-2026-07-08a): shared server-authoritative radius-presence-hold
	primitive. Design doc: RADIUS-HOLD-DESIGN.md. Registers ONE hold (e.g. a carrier bubble, or a
	future Zargabad KotH point) and lazily starts the single shared dispatcher thread that ticks
	every registered hold on a WFBE_C_RADIUSHOLD_TICK_SECS cadence. Server-only; NEVER
	HC-delegated (design doc S2.1) - HC add/remove/crash cannot touch hold state.

	Master gate: WFBE_C_RADIUSHOLD_ENABLE=0 (default) refuses every registration (warn-only diag_log)
	and the dispatcher never spawns - the mission is byte-identical to HEAD regardless of any
	consumer-side flag.

	Params:
		0: _holdId            STRING  unique hold id, e.g. "naval_Khe Sanh Alpha" - namespace key + diag tag.
		1: _anchor             OBJECT|ARRAY  an existing logic object (reused as-is), OR a position
		                        [x,y] / [x,y,z] to synthesize an invisible-but-alive HeliHEmpty logic at.
		2: _radius               NUMBER  metres.
		3: _holdSecs               NUMBER  seconds of uncontested eligible presence to complete.
		4: _eligibleSides           ARRAY  of SIDE constants (west/east/resistance) that may accrue/win.
		                             Does NOT affect who counts toward CONTEST - every side always
		                             counts for contest purposes (design doc S3.4/S4).
		5: _contestMode               NUMBER  0 = pause progress on multi-side presence (default),
		                               1 = decay progress at WFBE_C_RADIUSHOLD_CONTEST_DECAY sec/tick.
		6: _cooldownSecs               NUMBER  re-arm cooldown after completion; 0 = none.
		7: _onCompleteFnName             STRING  name of a global compiled function, called as
		                                 [_holdId, _anchor, _winningSide] call (missionNamespace getVariable _onCompleteFnName)
		                                 where _winningSide is the SIDE constant that completed the hold.

	Returns: the anchor OBJECT, or nil if registration was refused (master flag off / registry full).
*/

private ["_holdId","_anchorArg","_radius","_holdSecs","_eligibleSides","_contestMode","_cooldownSecs","_onCompleteFnName","_anchor","_maxActive"];

_holdId           = _this select 0;
_anchorArg        = _this select 1;
_radius           = _this select 2;
_holdSecs         = _this select 3;
_eligibleSides    = _this select 4;
_contestMode      = _this select 5;
_cooldownSecs     = _this select 6;
_onCompleteFnName = _this select 7;

if (!isServer) exitWith { nil };

if !((missionNamespace getVariable ["WFBE_C_RADIUSHOLD_ENABLE",0]) > 0) exitWith {
	diag_log Format ["RADIUSHOLD-WARN: register(%1) refused - WFBE_C_RADIUSHOLD_ENABLE=0.", _holdId];
	nil
};

if (isNil "WFBE_RADIUSHOLD_REGISTRY") then { WFBE_RADIUSHOLD_REGISTRY = []; };

_maxActive = missionNamespace getVariable ["WFBE_C_RADIUSHOLD_MAX_ACTIVE",8];
if ((count WFBE_RADIUSHOLD_REGISTRY) >= _maxActive) exitWith {
	diag_log Format ["RADIUSHOLD-WARN: register(%1) refused - WFBE_C_RADIUSHOLD_MAX_ACTIVE (%2) reached.", _holdId, _maxActive];
	nil
};

if (typeName _anchorArg == "ARRAY") then {
	_anchor = "HeliHEmpty" createVehicle [_anchorArg select 0, _anchorArg select 1, 0];
	_anchor setPosASL [_anchorArg select 0, _anchorArg select 1, if (count _anchorArg > 2) then {_anchorArg select 2} else {0}];
	_anchor enableSimulation false;
	_anchor allowDamage false;
} else {
	_anchor = _anchorArg;
};

if (isNull _anchor) exitWith {
	diag_log Format ["RADIUSHOLD-WARN: register(%1) refused - anchor is null.", _holdId];
	nil
};

//--- Registration-time warn-only overlap sanity check (design doc S7); never a hard block.
{
	if ((_x distance _anchor) < (_radius + (_x getVariable ["wfbe_rh_radius",0]))) then {
		diag_log Format ["RADIUSHOLD-WARN: register(%1) overlaps existing hold %2 (centers %3m apart, radii %4+%5).", _holdId, _x getVariable ["wfbe_rh_id","?"], _x distance _anchor, _radius, _x getVariable ["wfbe_rh_radius",0]];
	};
} forEach WFBE_RADIUSHOLD_REGISTRY;

_anchor setVariable ["wfbe_rh_id", _holdId, true];
_anchor setVariable ["wfbe_rh_radius", _radius, true];
_anchor setVariable ["wfbe_rh_holdsecs", _holdSecs, true];
_anchor setVariable ["wfbe_rh_eligible", _eligibleSides, true];
_anchor setVariable ["wfbe_rh_contest_mode", _contestMode, true];
_anchor setVariable ["wfbe_rh_holder_side", -1, true];
_anchor setVariable ["wfbe_rh_progress", 0, true];
_anchor setVariable ["wfbe_rh_cooldown_until", 0, true];
_anchor setVariable ["wfbe_rh_last_complete_side", -1, true];
_anchor setVariable ["wfbe_rh_last_complete_time", -1, true];
_anchor setVariable ["wfbe_rh_cooldownsecs", _cooldownSecs, false];
_anchor setVariable ["wfbe_rh_oncomplete", _onCompleteFnName, false];

WFBE_RADIUSHOLD_REGISTRY set [count WFBE_RADIUSHOLD_REGISTRY, _anchor];

["INFORMATION", Format ["Common_RadiusHold.sqf: registered hold id=%1 radius=%2 holdSecs=%3 eligible=%4 contestMode=%5 cooldown=%6 onComplete=%7.", _holdId, _radius, _holdSecs, _eligibleSides, _contestMode, _cooldownSecs, _onCompleteFnName]] Call WFBE_CO_FNC_LogContent;

//--- Lazily start the ONE shared dispatcher on first successful registration (design doc S2.1/S3.1.4).
//--- Never HC-delegated; never re-spawned; isServer-guarded again inside for defense-in-depth.
if (isNil "WFBE_RADIUSHOLD_DISPATCHER_STARTED") then {
	WFBE_RADIUSHOLD_DISPATCHER_STARTED = true;
	[] spawn {
		if (!isServer) exitWith {};
		private ["_tickSecs","_tickHold"];

		//--- Per-hold tick: presence scan -> contest resolution -> accrual -> completion.
		//--- Inline (not a separate WFBE_CO_FNC_*) so this file compiles to exactly one global,
		//--- matching the task's single-registration scope.
		_tickHold = {
			private ["_anchor","_id","_radius","_holdSecs","_eligible","_contestMode","_cooldownSecs","_onComplete",
			         "_cooldownUntil","_progress","_objects","_westN","_eastN","_guerN","_presentSides",
			         "_holderSideNum","_soleSide","_decayRate","_tick","_winnerSideType","_winnerSideNum"];
			_anchor = _this;
			if (isNull _anchor) exitWith {};

			_id            = _anchor getVariable ["wfbe_rh_id","?"];
			_radius        = _anchor getVariable ["wfbe_rh_radius",0];
			_holdSecs      = _anchor getVariable ["wfbe_rh_holdsecs",0];
			_eligible      = _anchor getVariable ["wfbe_rh_eligible",[]];
			_contestMode   = _anchor getVariable ["wfbe_rh_contest_mode",0];
			_cooldownSecs  = _anchor getVariable ["wfbe_rh_cooldownsecs",0];
			_onComplete    = _anchor getVariable ["wfbe_rh_oncomplete",""];
			_cooldownUntil = _anchor getVariable ["wfbe_rh_cooldown_until",0];
			_progress      = _anchor getVariable ["wfbe_rh_progress",0];
			_tick          = missionNamespace getVariable ["WFBE_C_RADIUSHOLD_TICK_SECS",5];

			//--- Presence scan: same type filter + idiom as server_town.sqf's proven town-capture scan
			//--- (design doc S0.1/S3). Height filter generalizes server_town.sqf's B755 deckZ+12 fix by
			//--- using the ANCHOR's own ASL Z (== deckZ for the carrier consumer, since the naval town
			//--- logic is already raised to deckZ before registration) + the same 12 m tolerance.
			_objects = (_anchor nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"], _radius]) unitsBelowHeight ((getPosASL _anchor select 2) + 12);
			_westN = west countSide _objects;
			_eastN = east countSide _objects;
			_guerN = resistance countSide _objects;

			_presentSides = [];
			if (_westN > 0) then { _presentSides set [count _presentSides, west]; };
			if (_eastN > 0) then { _presentSides set [count _presentSides, east]; };
			if (_guerN > 0) then { _presentSides set [count _presentSides, resistance]; };

			_holderSideNum = -1;

			if (time < _cooldownUntil) then {
				//--- Cooling down post-completion: scan/broadcast only, never accrue (design doc S5.1.4).
				_holderSideNum = -1;
			} else {
				if ((count _presentSides) >= 2) then {
					//--- Contested (design doc S4).
					_holderSideNum = -1;
					if (_contestMode == 1) then {
						_decayRate = missionNamespace getVariable ["WFBE_C_RADIUSHOLD_CONTEST_DECAY",0];
						_progress = (_progress - _decayRate) max 0;
					};
				} else {
					if ((count _presentSides) == 1) then {
						_soleSide = _presentSides select 0;
						if (_soleSide in _eligible) then {
							_holderSideNum = _soleSide Call WFBE_CO_FNC_GetSideID;
							_winnerSideType = _soleSide;
							_progress = (_progress + _tick) min _holdSecs;
						} else {
							//--- Present but ineligible (e.g. a lone GUER at a WEST/EAST-only hold): idle-hold,
							//--- neither accrues nor resets (design doc S4 bullet 5).
							_holderSideNum = -1;
						};
					} else {
						//--- Empty.
						_holderSideNum = -1;
					};
				};
			};

			_anchor setVariable ["wfbe_rh_holder_side", _holderSideNum, true];
			_anchor setVariable ["wfbe_rh_progress", _progress, true];

			if (_holderSideNum != -1 && {_holdSecs > 0} && {_progress >= _holdSecs}) then {
				_winnerSideNum = _holderSideNum;
				_anchor setVariable ["wfbe_rh_progress", 0, true];
				_anchor setVariable ["wfbe_rh_holder_side", -1, true];
				_anchor setVariable ["wfbe_rh_cooldown_until", time + _cooldownSecs, true];
				_anchor setVariable ["wfbe_rh_last_complete_side", _winnerSideNum, true];
				_anchor setVariable ["wfbe_rh_last_complete_time", time, true];
				["INFORMATION", Format ["Common_RadiusHold.sqf: hold id=%1 COMPLETE winner=%2 onComplete=%3.", _id, _winnerSideNum, _onComplete]] Call WFBE_CO_FNC_LogContent;
				if (_onComplete != "") then {
					[_id, _anchor, _winnerSideType] call (missionNamespace getVariable _onComplete);
				};
			};
		};

		["INFORMATION", "Common_RadiusHold.sqf: shared dispatcher started (WFBE_C_RADIUSHOLD_ENABLE=1)."] Call WFBE_CO_FNC_LogContent;
		while {!WFBE_GameOver} do {
			_tickSecs = missionNamespace getVariable ["WFBE_C_RADIUSHOLD_TICK_SECS",5];
			{ _x call _tickHold; } forEach WFBE_RADIUSHOLD_REGISTRY;
			sleep _tickSecs;
		};
		["INFORMATION", "Common_RadiusHold.sqf: shared dispatcher exiting (WFBE_GameOver)."] Call WFBE_CO_FNC_LogContent;
	};
};

_anchor