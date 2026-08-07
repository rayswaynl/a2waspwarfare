/*
	AICOM HELI SLING-LIFT executor (w807-L8). Parameter: _this = ["HeliLift", side, targetTown,
	crewGroup, heliClass, vehClass, aicomCost].

	Spawns ONE transport helicopter (its own pilot/group, deleted at RTB - the delivery asset)
	and ONE fresh armed ground vehicle (crewless at spawn, crewed on landing into the CALLER'S
	group so it persists as a normal AICOM asset). Slings the vehicle below the heli
	(attachTo [0,0,-7] - the SAME offset Common_AICOMAirLeg.sqf's live organic VEHLIFT sling
	uses for this exact MH60/UH60/CH47/Mi17 hull family), flies to a safe LZ near (not inside)
	the target town, hover-descends to a low sling height, detaches + ground-snaps, crews the
	hull, tasks it at the objective, then flies the (now empty) heli home and deletes it.

	GC EXEMPTION: the slung vehicle is crewless in flight, so it is stamped wfbe_airlifted=true
	(Server_HandleEmptyVehicle.sqf's empty-timer exemption - the SAME flag Zeta_Hook.sqf uses for
	the player sling-load feature) for the duration of the flight, cleared once crewed/settled.
	wfbe_aicom_slung is ALSO stamped (Common_AICOMAirLeg.sqf convention) for AICOM-internal reads.

	Failure handling:
	  - Heli lost while the vehicle is still attached: detach + setVelocity [0,0,0] (falls, acceptable) + log.
	  - Target town flips owner mid-flight: re-read wfbe_aicom_targets (naval-guarded) for a fresh
	    target; if none, divert to the nearest OWN town instead of delivering into a town we no
	    longer need (or still do not own) blind.
*/

private ["_args","_side","_target","_grp","_heliClass","_vehClass","_aicomCost","_sideID","_sideText",
	"_release","_released",
	"_baseHQ","_basePos","_spawnPos","_dir",
	"_transportGrp","_heli","_pilot",
	"_veh","_offset",
	"_origSideID","_lzPos","_flat","_t0","_approachLimited","_hoverFloor",
	"_settled","_settleTries","_crewClass","_drv","_gun","_cmd",
	"_newTarget","_newTargets","_ownTowns","_release2"];

_args      = _this;
_side      = _args select 1;
_target    = _args select 2;
_grp       = _args select 3;
_heliClass = _args select 4;
_vehClass  = _args select 5;
_aicomCost = if (count _args > 6) then {_args select 6} else {0};
if (typeName _aicomCost != "SCALAR") then {_aicomCost = 0};
_sideID   = _side Call GetSideID;
_sideText = str _side;

//--- r127 AICOM setup-abort refund precedent (Support_CargoAirdrop.sqf): a PRE-DELIVERY setup abort
//--- hands back the debit + releases the cooldown + the concurrency slot, mirroring the commander
//--- worker's own group-null refund - a non-delivered call is not a charged call.
_released = false;
_release = {
	if (!_released) then {
		_released = true;
		if (_aicomCost > 0) then {
			[_side, _aicomCost] Call ChangeAICommanderFunds;
			private "_rLogik";
			_rLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNil "_rLogik" && {!isNull _rLogik}) then {
				_rLogik setVariable ["wfbe_aicom_helilift_last", -1e9];
				_rLogik setVariable ["wfbe_aicom_helilift_active", ((_rLogik getVariable ["wfbe_aicom_helilift_active", 1]) - 1) max 0];
			};
			["WARNING", Format ["Support_HeliLift.sqf: [%1] heli-lift aborted before delivery - refunded %2 to the AI treasury and released the AICOM cooldown/slot.", _sideText, _aicomCost]] Call WFBE_CO_FNC_LogContent;
		} else {
			private "_rLogik2";
			_rLogik2 = (_side) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNil "_rLogik2" && {!isNull _rLogik2}) then {_rLogik2 setVariable ["wfbe_aicom_helilift_active", ((_rLogik2 getVariable ["wfbe_aicom_helilift_active", 1]) - 1) max 0]};
		};
	};
};
//--- Terminal (delivered-or-lost-in-flight) release: same slot decrement, no fund refund (the call WAS delivered/attempted).
_release2 = {
	if (!_released) then {
		_released = true;
		private "_rLogik3";
		_rLogik3 = (_side) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNil "_rLogik3" && {!isNull _rLogik3}) then {_rLogik3 setVariable ["wfbe_aicom_helilift_active", ((_rLogik3 getVariable ["wfbe_aicom_helilift_active", 1]) - 1) max 0]};
	};
};

if (isNull _target) exitWith {Call _release};

//--- Use the current HQ rather than the immutable start-position snapshot: MHQ relocation replaces
//--- the deployed site and a completed delivery must return to the base that exists now.
_baseHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (isNull _baseHQ) exitWith {Call _release};
_basePos = getPos _baseHQ;

//--- Spawn heading: atan2 position-delta bearing toward the target (binary getDir is A3-only; same
//--- idiom Common_AICOMAirLeg.sqf/Common_RunCommanderTeam.sqf use elsewhere in this tree). Cosmetic
//--- only - the AI immediately reissues doMove below, so this only affects the initial spawn facing.
_dir = ((getPos _target select 0) - (_basePos select 0)) atan2 ((getPos _target select 1) - (_basePos select 1));
_spawnPos = [(_basePos select 0) + 20, (_basePos select 1) + 20, (_basePos select 2) + 40];

_heli = [_heliClass, _spawnPos, _sideID, _dir, false, true, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;
if (isNull _heli) exitWith {
	["WARNING", Format ["Support_HeliLift.sqf: [%1] transport heli [%2] failed to create.", _sideText, _heliClass]] Call WFBE_CO_FNC_LogContent;
	Call _release;
};
_transportGrp = [_side, "aicom_helilift_transport"] Call WFBE_CO_FNC_CreateGroup;
if (isNull _transportGrp) exitWith {
	deleteVehicle _heli;
	Call _release;
};
_pilot = [(missionNamespace getVariable Format ["WFBE_%1PILOT", _sideText]), _transportGrp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
if (isNull _pilot) exitWith {
	deleteVehicle _heli;
	deleteGroup _transportGrp;
	Call _release;
};
_pilot moveInDriver _heli;
if (driver _heli != _pilot) exitWith {
	deleteVehicle _pilot;
	deleteVehicle _heli;
	deleteGroup _transportGrp;
	["WARNING", Format ["Support_HeliLift.sqf: [%1] transport pilot seat failed; aborting heli-lift.", _sideText]] Call WFBE_CO_FNC_LogContent;
	Call _release;
};
_heli flyInHeight (90 + random 30);
_transportGrp setBehaviour "CARELESS";
_transportGrp setCombatMode "STEALTH";
_pilot disableAI "AUTOTARGET";
_pilot disableAI "TARGET";
Call Compile Format ["_heli addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]", _sideID];
_heli setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';", _sideID];
processInitCommands;

//--- SLING: spawn the fresh armed vehicle at the heli's own position and attach immediately (mirrors
//--- Support_CargoAirdrop.sqf's cargo-vehicle-then-attachTo sequencing). Crewless by construction, so
//--- it is exempted from Server_HandleEmptyVehicle.sqf's empty-hull GC via wfbe_airlifted (the SAME
//--- flag Zeta_Hook.sqf uses for the player sling-load feature) for the duration of the flight.
_veh = [_vehClass, _spawnPos, _sideID, 0, false] Call WFBE_CO_FNC_CreateVehicle;
if (isNull _veh) exitWith {
	{deleteVehicle _x; sleep 0} forEach crew _heli;
	deleteVehicle _heli;
	deleteGroup _transportGrp;
	["WARNING", Format ["Support_HeliLift.sqf: [%1] lift vehicle [%2] failed to create; aborting heli-lift.", _sideText, _vehClass]] Call WFBE_CO_FNC_LogContent;
	Call _release;
};
_veh allowDamage false;
_veh setVariable ["wfbe_airlifted", true, true];
_veh setVariable ["wfbe_aicom_slung", true, true];
//--- UNVERIFIED (offset VALUE only - the attachTo mechanism + axis convention are verified by direct,
//--- ARMED, live precedent): [0,0,-7] is Common_AICOMAirLeg.sqf's own reasoned choice for this exact
//--- MH60/UH60/CH47/Mi17 hull family ("conservative fixed -7 clears every hull's rotor/skid geometry,
//--- well under the terrain guard's 60m climb clearance"). Reused verbatim rather than re-guessed.
//--- AICOMSTAT HELILIFT_ATTACHED below logs the achieved clearance so a live run can confirm it holds
//--- for the specific hulls this worker's roster intersection actually picks.
_offset = [0, 0, -7];
_veh attachTo [_heli, _offset];
diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_ATTACHED|heli=" + _heliClass + "|veh=" + _vehClass);

//--- Capture the target's ownership AT DISPATCH so a later flip (captured by either side) can be detected.
_origSideID = _target getVariable ["sideID", -1];

//--- LZ: near (not inside) the target town - same scatter+flatten idiom as Common_RunCommanderTeam.sqf's
//--- air-insert LZ pick (GetRandomPosition/GetEmptyPosition + isFlatEmpty), widened so the drop lands
//--- clear of the town's own structures/defences rather than in the middle of them.
_lzPos = [getPos _target, 80, 220] Call WFBE_CO_FNC_GetRandomPosition;
_lzPos = [_lzPos, 40] Call WFBE_CO_FNC_GetEmptyPosition;
_flat = _lzPos isFlatEmpty [12, 0, 2, 12, 0, false, objNull];
if (count _flat > 0) then {_lzPos = _flat};

_approachLimited = (missionNamespace getVariable ["WFBE_C_AICOM_HELI_APPROACH_LIMITED", 0]) > 0;
if (_approachLimited) then {_transportGrp setSpeedMode "LIMITED"};
(driver _heli) doMove _lzPos;
_heli flyInHeight (90 + random 20);
_t0 = time + 300;
waitUntil {
	sleep 2;
	time > _t0 || isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)} || {(_heli distance _lzPos) < 150}
};
if (_approachLimited) then {_transportGrp setSpeedMode "FULL"};

//--- Heli lost en route while the vehicle is still attached: detach + zero velocity (falls, acceptable
//--- per design), log, and let the (now uncrewed, ground-snapped-by-gravity) hull sit for AICOM/salvage
//--- to deal with normally. No RTB, no crew - this call did not deliver.
if (isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)}) exitWith {
	if (!isNull _veh && {alive _veh}) then {
		detach _veh;
		_veh setVelocity [0,0,0];
		_veh allowDamage true;
		_veh setVariable ["wfbe_airlifted", false, true];
		_veh setVariable ["wfbe_aicom_slung", false, true];
	};
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_ABORT|heli-lost");
	["WARNING", Format ["Support_HeliLift.sqf: [%1] heli-lift transport lost en route; slung vehicle released to fall.", _sideText]] Call WFBE_CO_FNC_LogContent;
	Call _release2;
};

//--- TARGET-FLIP RECHECK: the town's ownership can change during a long flight (captured by either
//--- side). If it flipped, re-read wfbe_aicom_targets (naval-guarded, PR #2199 pattern) for a fresh
//--- target; if none is available, divert to the NEAREST OWN town instead of delivering blind.
if ((_target getVariable ["sideID", -1]) != _origSideID) then {
	_newTarget = objNull;
	private "_flipLogik";
	_flipLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;
	if (!isNull _flipLogik) then {
		_newTargets = _flipLogik getVariable "wfbe_aicom_targets";
		if (!isNil "_newTargets" && {typeName _newTargets == "ARRAY"}) then {
			{
				if (isNull _newTarget && {!isNull _x} && {_x != _target} && {!((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_AIR_ONLY", 1]) > 0 && {_x getVariable ["wfbe_is_naval_hvt", false]})}) then {
					_newTarget = _x;
				};
			} forEach _newTargets;
		};
	};
	if (isNull _newTarget) then {
		//--- Fallback: nearest town this side already owns.
		_ownTowns = [];
		{ if (_x getVariable ["sideID", -1] == _sideID) then {_ownTowns = _ownTowns + [_x]} } forEach towns;
		if (count _ownTowns > 0) then {_newTarget = [getPos _heli, _ownTowns] Call WFBE_CO_FNC_GetClosestEntity};
	};
	if (!isNull _newTarget) then {
		diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_DIVERT|from=" + (_target getVariable ["name","?"]) + "|to=" + (_newTarget getVariable ["name","?"]));
		["INFORMATION", Format ["Support_HeliLift.sqf: [%1] heli-lift target flipped owner mid-flight; diverting to [%2].", _sideText, _newTarget getVariable ["name","?"]]] Call WFBE_CO_FNC_AICOMLog;
		_target = _newTarget;
		_lzPos = [getPos _target, 80, 220] Call WFBE_CO_FNC_GetRandomPosition;
		_lzPos = [_lzPos, 40] Call WFBE_CO_FNC_GetEmptyPosition;
		_flat = _lzPos isFlatEmpty [12, 0, 2, 12, 0, false, objNull];
		if (count _flat > 0) then {_lzPos = _flat};
		(driver _heli) doMove _lzPos;
		_t0 = time + 180;
		waitUntil {
			sleep 2;
			time > _t0 || isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)} || {(_heli distance _lzPos) < 150}
		};
	};
};

if (isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)}) exitWith {
	if (!isNull _veh && {alive _veh}) then {
		detach _veh;
		_veh setVelocity [0,0,0];
		_veh allowDamage true;
		_veh setVariable ["wfbe_airlifted", false, true];
		_veh setVariable ["wfbe_aicom_slung", false, true];
	};
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_ABORT|heli-lost-divert");
	Call _release2;
};

//--- HOVER-DESCEND: floor tuned so the SLUNG VEHICLE ends up <= 2m AGL while the heli itself stays
//--- clear of the ground by the attach offset magnitude (UNVERIFIED exact touchdown precision - AI
//--- flyInHeight tracking is approximate, not exact; HELILIFT_DROPPED below logs the vehicle's actual
//--- ATL at detach so a live run can confirm the tolerance holds).
_hoverFloor = 2 + abs (_offset select 2);
(driver _heli) doMove _lzPos;
_heli flyInHeight _hoverFloor;
_t0 = time + 60;
waitUntil {sleep 1; time > _t0 || isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)} || {!isNull _veh && {((getPosATL _veh) select 2) < (2 + abs (_offset select 2) + 1)}}};

if (isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)}) exitWith {
	if (!isNull _veh && {alive _veh}) then {
		detach _veh;
		_veh setVelocity [0,0,0];
		_veh allowDamage true;
		_veh setVariable ["wfbe_airlifted", false, true];
		_veh setVariable ["wfbe_aicom_slung", false, true];
	};
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_ABORT|heli-lost-descent");
	Call _release2;
};

//--- DETACH + ground-snap (Common_AICOMAirLeg.sqf's proven vehicle-sling idiom: z=0.5 so it settles on
//--- wheels, not buried/launched) + brief invulnerability hold through the settle poll (mirrors
//--- Support_CargoAirdrop.sqf's Stage B mount-on-landing settle-detect).
if (!isNull _veh && {alive _veh}) then {
	detach _veh;
	_veh setVelocity [0,0,0];
	_veh setPos [(getPos _veh) select 0, (getPos _veh) select 1, 0.5];
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_DROPPED|veh=" + _vehClass + "|atl=" + str ((getPosATL _veh) select 2));

	_settled = false;
	_settleTries = 0;
	while {!_settled && {_settleTries < 15} && {!isNull _veh} && {alive _veh}} do {
		if (((getPosATL _veh) select 2) < 2 && {abs ((velocity _veh) select 2) < 0.5}) then {
			_settled = true;
		} else {
			sleep 1;
			_settleTries = _settleTries + 1;
		};
	};

	if (_settled && {!isNull _veh} && {alive _veh} && {!isNull _grp}) then {
		_crewClass = missionNamespace getVariable Format ["WFBE_%1SOLDIER", _sideText];
		if (_veh isKindOf "Tank") then {_crewClass = missionNamespace getVariable Format ["WFBE_%1CREW", _sideText]};
		if (!isNil "_crewClass") then {
			if ((_veh emptyPositions "driver") > 0) then {
				_drv = [_crewClass, _grp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
				if (!isNull _drv) then {_drv moveInDriver _veh};
			};
			if ((_veh emptyPositions "gunner") > 0) then {
				_gun = [_crewClass, _grp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
				if (!isNull _gun) then {_gun moveInGunner _veh};
			};
			if ((_veh emptyPositions "commander") > 0) then {
				_cmd = [_crewClass, _grp, [100,12000,0], _sideID] Call WFBE_CO_FNC_CreateUnit;
				if (!isNull _cmd) then {_cmd moveInCommander _veh};
			};
			//--- Fold into normal AICOM tasking: task the crewed hull at the objective (mirrors
			//--- Support_CargoAirdrop.sqf's post-drop AIPatrol/COMBAT tasking for AI-run calls). The
			//--- wfbe_side_id stamp every WFBE_CO_FNC_CreateVehicle hull carries is what lets the
			//--- rest of AICOM's vehicle accounting (AI_Commander_CargoAirdrop.sqf's own air-cap
			//--- count is the same idiom) recognise this hull as a side asset from here on.
			if (!isNull (driver _veh)) then {
				(driver _veh) doMove (getPos _target);
				_grp setBehaviour "COMBAT";
				_grp setCombatMode "RED";
				_grp setSpeedMode "FULL";
			};
			["INFORMATION", Format ["Support_HeliLift.sqf: [%1] heli-lift delivered + crewed [%2] near [%3]; tasked on the objective.", _sideText, _vehClass, _target getVariable ["name","?"]]] Call WFBE_CO_FNC_AICOMLog;
			diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|HELILIFT_CREWED|veh=" + _vehClass + "|town=" + (_target getVariable ["name","?"]));
		};
	} else {
		["INFORMATION", Format ["Support_HeliLift.sqf: [%1] heli-lift vehicle [%2] never settled; delivered empty.", _sideText, _vehClass]] Call WFBE_CO_FNC_LogContent;
	};
	_veh allowDamage true;
	_veh setVariable ["wfbe_airlifted", false, true];
	_veh setVariable ["wfbe_aicom_slung", false, true];
};

//--- Heli RTB: re-read the current HQ so a relocation during the flight cannot send it to the old base.
//--- The lump cost still covers both delivery hulls; no refund after a delivered attempt.
_baseHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _baseHQ) then {_basePos = getPos _baseHQ};
if (!isNull _heli && {alive _heli} && {!isNull (driver _heli)} && {alive (driver _heli)}) then {
	(driver _heli) doMove _basePos;
	_heli flyInHeight (90 + random 20);
	_t0 = time + 300;
	waitUntil {sleep 2; time > _t0 || isNull _heli || {!alive _heli} || {isNull (driver _heli)} || {!alive (driver _heli)} || {(_heli distance _basePos) < 200}};
};
if (!isNull _heli) then {
	{deleteVehicle _x; sleep 0} forEach crew _heli; //--- crash 014EFCF4 sweep: sleep 0 between crew deletes (order-dependent on the deleteGroup below).
	deleteVehicle _heli;
};
if (!isNull _pilot) then {deleteVehicle _pilot};
if (!isNull _transportGrp) then {if (({isPlayer _x} count (units _transportGrp)) == 0) then {deleteGroup _transportGrp}};

Call _release2;
