/*
	Support_GuerHeliDrop.sqf - GUER Barrel Bomb flight + release (fable/guer-barrelbomb). Directory
	convention + calling shape mirror Support_Paratroopers.sqf (KAT_Paratroopers) exactly: registered as
	KAT_GuerHeliDrop in Server\Init\Init_Server.sqf, invoked as [nil, resistance, _pos, _team]
	Spawn KAT_GuerHeliDrop from Server_HandleSpecial.sqf's "guer-heli-bomb" case, which already
	validated the kill-tier gate + funds and debited cost BEFORE spawning this - same debit-then-fire
	ordering "guer-mortar-strike" uses.

	Flow:
	  1. Spawn a WFBE_%1PARACARGO-class heli (side-parameterized lookup - resolves Mi17_Civilian for GUE
	     on Chernarus per Root_GUE.sqf:28; NOT hardcoded, so a TK/ZG generator repoint stays correct) with
	     a single WFBE_%1PILOT crew at a random map-boundary spawn point (same 4-corner table
	     Support_Paratroopers.sqf uses). A2-safe crew: createVehicle + WFBE_CO_FNC_CreateUnit +
	     moveInDriver, no createVehicleCrew.
	  2. AIMoveTo the group toward the designated drop position; loop until arrival (<300m), pilot/vehicle
	     death, or a 500s hard timeout (identical shape to Support_Paratroopers.sqf:98-112).
	  3. On arrival ("overhead"): RELEASE. Deliberately does NOT attachTo/detach a physical bomb object
	     under the moving heli (the original design's free-fall-spike section flagged that as needing an
	     in-editor prototype first) - instead reuses the mortar's own proven, zero-risk idiom
	     (Server_HandleSpecial.sqf "guer-mortar-strike": createVehicle the ordnance directly at the
	     target XY, lifted to Z=120 via setPosATL so it falls onto real terrain). The heli still visibly
	     flies the mission and the drop is timed to its arrival; only the literal object-detaches-from-
	     airframe animation is skipped, for zero physics risk and no prototype gate needed.
	     Kill-credit snapshot/payout mirrors the mortar's cash-for-kills block, PLUS (new here, gated by
	     WFBE_C_GUER_HELIDROP_CREDIT_KILLS) an idempotent single-pass WFBE_GUER_PLAYER_KILLS increment -
	     see GUER-BARRELBOMB-REVISED.md Section 4 for why this is the ONLY kill-credit path (no
	     wfbe_lasthitby stamp is set here, deliberately, to avoid double-counting via
	     RequestOnUnitKilled.sqf's delayed-hit attribution).
	  4. Fly home via the same spawn-corner entry; loop until arrival/death/500s timeout.
	  5. Cleanup: delete crew + vehicle + group in all cases (mirrors Support_Paratroopers.sqf:150-157).

	A2 OA 1.64 safe: array-form private only, `_arr + [x]` (no pushBack), no params/isEqualType.
	_this = [kind(unused, calling-convention symmetry with Support_Paratroopers.sqf), side, destination, playerTeam]
*/
Private ["_bd","_built","_cargoType","_coef","_destination","_get","_greenlight","_grp","_off2d","_payout","_pilot","_playerTeam","_positionCoord","_radius","_ran","_ranDir","_ranPos","_returnStart","_shells","_side","_sideID","_sp","_spread","_starttime","_vehicle","_vehicleCoord","_victims","_i"];

_side = _this select 1;
_destination = _this select 2;
_playerTeam = _this select 3;
_sideID = _side Call GetSideID;
_starttime = time;

["INFORMATION", Format["Support_GuerHeliDrop.sqf : [%1] Team [%2] has called in a Barrel Bomb at %3.", _side, _playerTeam, _destination]] Call WFBE_CO_FNC_LogContent;

//--- Determine a random spawn location (same 4-corner table Support_Paratroopers.sqf uses).
_ranPos = [];
_ranDir = [];
_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
if !(isNil '_bd') then {
	_ranPos = [
		[0+random(200),0+random(200),400+random(200)],
		[0+random(200),_bd-random(200),400+random(200)],
		[_bd-random(200),_bd-random(200),400+random(200)],
		[_bd-random(200),0+random(200),400+random(200)]
	];
	_ranDir = [45,145,225,315];
} else {
	_ranPos = [[0+random(200),0+random(200),400+random(200)],[15000+random(200),0+random(200),400+random(200)]];
	_ranDir = [45,315];
};

_cargoType = missionNamespace getVariable Format ["WFBE_%1PARACARGO", str _side];
if (isNil '_cargoType') exitWith {["ERROR", Format["Support_GuerHeliDrop.sqf : [%1] Heli-drop cargo vehicle is not defined.", _side]] Call WFBE_CO_FNC_LogContent};

_ran = floor(random count _ranPos);
_grp = [_side, "helibomb"] Call WFBE_CO_FNC_CreateGroup;
_built = 0;

//--- Spawn the heli + single pilot.
_vehicle = createVehicle [_cargoType, (_ranPos select _ran), [], (_ranDir select _ran), "FLY"];
_vehicle addEventHandler ['killed', Format["[_this select 0, _this select 1, %1] Spawn WFBE_CO_FNC_OnUnitKilled", _sideID]];
_vehicle setVehicleInit Format["[this, %1] ExecVM 'Common\Init\Init_Unit.sqf';", _sideID];

_pilot = [missionNamespace getVariable Format ["WFBE_%1PILOT", str _side], _grp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
_pilot moveInDriver _vehicle;
_pilot doMove _destination;
_grp setBehaviour 'CARELESS';
_grp setCombatMode 'STEALTH';
{_pilot disableAI _x} forEach ["AUTOTARGET","TARGET"];
_built = _built + 1;

_vehicle flyInHeight (300 + random 15);
_vehicle lockDriver true;

[str _side, 'VehiclesCreated', _built] Call UpdateStatistics;
[str _side, 'UnitsCreated', _built] Call UpdateStatistics;

//--- Global Init.
processInitCommands;

//--- Tell the group to move.
[_grp, _destination, "MOVE", 10] Call AIMoveTo;

//--- Loop until death or arrival.
_greenlight = false;
while {true} do {
	sleep 1;

	if (!alive _vehicle) exitWith {};      //--- Vehicle destruction.
	if (!alive _pilot) exitWith {};        //--- Pilot dead.
	if (time - _starttime > 500) exitWith {};   //--- Hard transit timeout.

	_vehicleCoord = [(getPos _vehicle) select 0, (getPos _vehicle) select 1];
	_positionCoord = [_destination select 0, _destination select 1];
	if (_vehicleCoord distance _positionCoord < 300) exitWith {_greenlight = true};   //--- Destination reached.
};

//--- RELEASE.
if (_greenlight) then {
	//--- INCOMING WARNING (counter-play + atmosphere): global marker at RELEASE time (not at call time),
	//--- so the flight itself isn't a multi-minute spoiler. Mirrors Server_HandleSpecial.sqf:1474-1490.
	Private "_mname";
	_mname = Format ["wfbe_guerhelibomb_%1", round (diag_tickTime * 1000)];
	createMarker [_mname, _destination];
	_mname setMarkerType "mil_destroy";
	_mname setMarkerColor "ColorRed";
	_mname setMarkerText "Incoming";
	_mname setMarkerSize [1, 1];
	[_mname] spawn {
		Private "_m";
		_m = _this select 0;
		sleep 12;
		deleteMarker _m;
	};

	//--- KILL CREDIT + ORDNANCE: same shape as Server_HandleSpecial.sqf "guer-mortar-strike" (snapshot
	//--- living enemy Men/crewed-vehicles BEFORE the drop, settle, pay/credit after). No wfbe_lasthitby
	//--- stamp is set (see file header - avoids a WFBE_GUER_PLAYER_KILLS double-count via
	//--- RequestOnUnitKilled's delayed-hit attribution).
	_shells = missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_SHELLS", 1];
	if (_shells < 1) then {_shells = 1};
	_spread = missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_SPREAD", 15];
	_radius = missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_RADIUS", 60];
	_coef = missionNamespace getVariable ["WFBE_C_GUER_KILL_BOUNTY_COEF", 0.5];

	_victims = [];
	{
		Private "_cand";
		_cand = _x;
		if (alive _cand && {(side _cand == east) || (side _cand == west)}) then {
			if (_cand isKindOf "Man") then {
				_victims = _victims + [_cand];
			} else {
				if (({alive _x} count (crew _cand)) > 0) then {_victims = _victims + [_cand]};
			};
		};
	} forEach (nearestObjects [_destination, ["Man","LandVehicle","Air"], _radius]);

	for "_i" from 1 to _shells do {
		_off2d = [(_destination select 0) + (-_spread + random (2 * _spread)), (_destination select 1) + (-_spread + random (2 * _spread))];
		_sp = "Sh_82_HE" createVehicle _off2d;
		_sp setPosATL [(_off2d select 0), (_off2d select 1), 120];   //--- 120m ABOVE GROUND so it falls onto terrain.
		sleep (0.3 + random 0.4);
	};

	sleep 4;   //--- settle before scoring kills.

	if (!isNull _playerTeam) then {
		_payout = 0;
		{
			if (!alive _x) then {
				_get = missionNamespace getVariable (typeOf _x);
				if (!isNil "_get") then {_payout = _payout + round ((_get select QUERYUNITPRICE) * _coef)};

				//--- Idempotent kill-tier credit: ONE increment per confirmed victim, this single pass only.
				if ((missionNamespace getVariable ["WFBE_C_GUER_HELIDROP_CREDIT_KILLS", 1]) > 0) then {
					WFBE_GUER_PLAYER_KILLS = (missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0]) + 1;
					publicVariable "WFBE_GUER_PLAYER_KILLS";
					//--- Same milestone/unlock check RequestOnUnitKilled.sqf:151-164 runs against - small,
					//--- bounded duplication here rather than touching that hot kill-path for this feature.
					//--- NOTE: keep in sync manually if the tiers in RequestOnUnitKilled.sqf ever change.
					Private ["_gMilestones","_gMsg"];
					_gMilestones = [
						[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_1", 30], "BRDM-2 + T-34 unlocked  -  Ka-137 flares up to 120"],
						[missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 50], "M113 VBIED unlocked  -  armoured suicide APC at 2x speed"],
						[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_HELIBOMB", 60], "Barrel Bomb unlocked  -  heli-delivered call-in strike"],
						[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_2", 80], "T-55 unlocked  -  Ka-137 flares up to 240"],
						[missionNamespace getVariable ["WFBE_C_GUER_KILLTIER_3", 160], "T-72 + BMP-2 unlocked"]
					];
					_gMsg = "";
					{ if (WFBE_GUER_PLAYER_KILLS == (_x select 0)) then {_gMsg = _x select 1} } forEach _gMilestones;
					if (_gMsg != "") then {
						WFBE_GUER_UNLOCK_MSG = [WFBE_GUER_PLAYER_KILLS, _gMsg];
						publicVariable "WFBE_GUER_UNLOCK_MSG";
					};
				};
			};
		} forEach _victims;
		if (_payout > 0) then {
			[_playerTeam, _payout] Call WFBE_CO_FNC_ChangeTeamFunds;
			["INFORMATION", Format ["Support_GuerHeliDrop.sqf: Barrel bomb cash-for-kills paid [%1] to [%2] (%3 targets snapshotted).", _payout, _playerTeam, count _victims]] Call WFBE_CO_FNC_LogContent;
		};
	};

	//--- Fly home.
	[_grp, (_ranPos select _ran), "MOVE", 10] Call AIMoveTo;

	_returnStart = time;
	while {true} do {
		sleep 1;

		if (!alive _vehicle) exitWith {};
		if (!alive _pilot) exitWith {};
		if (time - _returnStart > 500) exitWith {};

		_vehicleCoord = [(getPos _vehicle) select 0, (getPos _vehicle) select 1];
		_positionCoord = [(_ranPos select _ran) select 0, (_ranPos select _ran) select 1];
		if (_vehicleCoord distance _positionCoord < 300) exitWith {};   //--- Destination reached.
	};
};

//--- In any case, cleanup the transporter.
{deleteVehicle _x} forEach crew _vehicle;   //--- Remove the crew.
deleteVehicle _vehicle;                     //--- Remove the vehicle.
deleteGroup _grp;
