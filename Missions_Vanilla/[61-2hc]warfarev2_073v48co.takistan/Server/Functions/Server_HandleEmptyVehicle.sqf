/*
	Handle a vehicle emptiness.
	 Parameters:
		- Vehicle.
		- {Delay override}.
*/

Private ["_delay", "_maxReapAttempts", "_maxReapRounds", "_reapAttempts", "_reapRounds", "_timer", "_vehicle"];

_vehicle = _this select 0;

// Nil-guard: _vehicle can be nil if the caller passes no argument or passes nil explicitly.
// isNull covers the case where a valid object reference has since been deleted (objNull).
// Skip-iteration pattern: exit the entire script scope — there is nothing useful to do
// without a vehicle reference, and silently defaulting to objNull would let typeOf/alive
// run against a null object and produce wrong results rather than a clean no-op.
if (isNil "_vehicle") exitWith {};
if (isNull _vehicle) exitWith {emptyQueu = emptyQueu - [_vehicle];};

_delay = if (count _this > 1) then {_this select 1} else {if (typeOf _vehicle in ['HMMWV_Ambulance','HMMWV_Ambulance_DES_EP1','UH60M_MEV_EP1','M1133_MEV_EP1','GAZ_Vodnik_MedEvac','Mi17_medevac_RU','M113Ambul_TK_EP1','V3S_Gue','V3S_TK_GUE_EP1']) then {(missionNamespace getVariable "WFBE_C_UNITS_EMPTY_TIMEOUT")*2} else {missionNamespace getVariable "WFBE_C_UNITS_EMPTY_TIMEOUT"};};

_timer = 0;
_reapAttempts = 0;
_maxReapAttempts = 3;
_reapRounds = 0;
//--- fable/gc-remote-hull-retry-20260727: outer retry-round cap. A non-local (HC-owned) hull whose delete
//--- dispatch is fire-and-forget (Common_SendToClient, no ack) previously got 3 attempts total, then was
//--- UNCONDITIONALLY dropped from emptyQueu even if still alive - a permanent leak (soak evidence:
//--- VEHDEL attempt=1/3,2/3,3/3 then never again, hull confirmed alive hours later). Bounded to 5 rounds
//--- of 3 attempts each (15 dispatch attempts max) so a genuinely unreachable HC cannot retry forever.
_maxReapRounds = 5;

// Added double timer for the repair trucks too
if (typeOf _vehicle in ['MtvrRepair','WarfareRepairTruck_Gue','V3S_Repair_TK_GUE_EP1','UralRepair_CDF','UralRepair_INS','KamazRepair','UralRepair_TK_EP1','MtvrRepair_DES_EP1']) then {
    _delay = (missionNamespace getVariable "WFBE_C_UNITS_EMPTY_TIMEOUT")*2;
};

// Added 24 hours timer for the supply trucks
if (typeOf _vehicle in ['V3S_Supply_TK_GUE_EP1','WarfareSupplyTruck_RU', 'WarfareSupplyTruck_USMC', 'WarfareSupplyTruck_INS', 'WarfareSupplyTruck_Gue', 'WarfareSupplyTruck_CDF', 'UralSupply_TK_EP1', 'MtvrSupply_DES_EP1']) then {
    _delay = 86400;
};

while {alive _vehicle && {_reapRounds < _maxReapRounds}} do {
	sleep 20;
	
	//--- fable/watch-timer-undefined: the vehicle can be DELETED during the 20s sleep - a null object's 2-arg
	//--- getVariable IGNORES the default (engine-verified XWT45-P4, same mechanism fixed in Server_HandleDefense.sqf
	//--- 118fcda4a) - the wfbe_airlifted read below would come up nil, undefining _timer at the next line's
	//--- '> _delay' check (live RPT: Undefined variable in expression: _timer, ~6x/window after MISSINIT).
	//--- Block-exit falls through to the while condition, which ends the loop cleanly on the dead/deleted vehicle.
	if (isNull _vehicle) exitWith {emptyQueu = emptyQueu - [_vehicle];};
	
	_timer = if (({alive _x} count crew _vehicle) > 0 || {_vehicle getVariable ["wfbe_airlifted", false]} || {_vehicle getVariable ["wfbe_is_guer_fob", false]}) then {0} else {_timer + 20}; //--- fable/airlift-gc-exempt: an airlifted hull is crewless by design - do not run down the empty-vehicle fuse while slung. guer-fob-empty-exempt: a GUER FOB truck is a dismount-by-design base/spawn structure - never reap it as an abandoned empty hull
	if (_timer > _delay) then {
		_reapAttempts = _reapAttempts + 1;
		["empty-timeout-hull", _vehicle, Format ["delay=%1 attempt=%2/%3 round=%4/%5", _delay, _reapAttempts, _maxReapAttempts, _reapRounds + 1, _maxReapRounds]] Call WFBE_CO_FNC_LogVehDelete;
		if (local _vehicle) then {
			//--- r66: dead crew still seated blocks A2 deleteVehicle (crewed-hull refusal). Purge non-player corpses first, then hull.
			{ if (!isNull _x && {!alive _x} && {!isPlayer _x}) then { deleteVehicle _x } } forEach (crew _vehicle);
			if (!isNull _vehicle) then { deleteVehicle _vehicle };
		} else {
			if ((missionNamespace getVariable ["WFBE_C_TRASH_REMOTE_DELETE", 0]) > 0) then {
				_vehicle setVariable ["wfbe_empty_vehicle_reap", true, true];
				[_vehicle, "HandleSpecial", ["cleanup-empty-vehicle", _vehicle]] Call WFBE_CO_FNC_SendToClient;
			};
		};
		//--- fable/gc-remote-hull-retry-20260727: this round of 3 attempts is used up. If the vehicle is already
		//--- gone (the local deleteVehicle above, or a remote receiver that caught up on a prior round) the
		//--- outer while condition's `alive _vehicle` ends the loop on the next check, no extra action needed.
		//--- If it is STILL alive - the observed HC-owned failure mode, a fire-and-forget SendToClient with no
		//--- ack - start a fresh round instead of permanently dropping it: reset the attempt counter AND
		//--- _timer, which reuses _delay itself as the inter-round backoff (the next attempt cannot fire until
		//--- the hull has been empty past _delay again). Bounded by _maxReapRounds so an unreachable HC cannot
		//--- retry forever.
		if (_reapAttempts >= _maxReapAttempts) then {
			_reapAttempts = 0;
			_timer = 0;
			_reapRounds = _reapRounds + 1;
		};
	};
};

//--- fable/gc-remote-hull-retry-20260727: every retry round is spent and the hull is STILL alive - a
//--- genuinely undeletable (or unreachable-HC) hull. Stop spending work on it, but do not let it vanish
//--- from accounting the way the old unconditional drop below used to: log it once, under its own reason
//--- code, so a future soak can see it was abandoned rather than mistaking it for a normal successful reap.
if (alive _vehicle) then {
	["empty-timeout-hull-abandoned", _vehicle, Format ["delay=%1 rounds=%2/%3", _delay, _reapRounds, _maxReapRounds]] Call WFBE_CO_FNC_LogVehDelete;
};

emptyQueu = emptyQueu - [_vehicle];