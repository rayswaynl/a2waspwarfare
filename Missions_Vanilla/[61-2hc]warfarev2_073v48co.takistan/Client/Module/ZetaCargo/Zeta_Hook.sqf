Private ["_action","_actionID","_caller","_ehq","_whq","_fhq","_index","_isAttached","_lifter","_position","_sorted","_type","_vehicle","_vehicles"];

_lifter = _this select 0;
_caller = _this select 1;
_actionID = _this select 2;
_ehq = ['BTR90_HQ','BMP2_HQ_TK_EP1','BMP2_HQ_INS'];
_whq = ['LAV25_HQ','M1130_CV_EP1','BMP2_HQ_CDF'];

if (_caller != driver _lifter) exitWith {};
//--- Shared reservation: replacement pilots receive their own local Lift action, so reject a second hook while this lifter still carries cargo.
if (_lifter getVariable ["Attached", false]) exitWith {};
//--- fix(exitWith-control-flow g1606): exitWith inside then/else only left that block — speed/height
//--- gates never aborted the hook and airlift still attached cargo. Use top-scope exitWith.
if (((typeOf _lifter) in Zeta_Special) && {speed _lifter > 20}) exitWith {};
if (!((typeOf _lifter) in Zeta_Special) && {(speed _lifter > 20) || ((getpos _lifter select 2) < 2)}) exitWith {};
//--- nearEntities handle living units.
_vehicles = _lifter nearObjects ["LandVehicle", 10];
//--- Build83 (Ray 2026-07-01): airlifting your OWN HQ is RE-ENABLED (was disabled by Trello #87). Flag-gated: set WFBE_C_AIRLIFT_OWN_HQ=0 to restore the old exclusion. Enemy-HQ-wreck guard below unchanged.
if ((missionNamespace getVariable ["WFBE_C_AIRLIFT_OWN_HQ", 1]) == 0) then {
	_fhq = (side _caller) Call WFBE_CO_FNC_GetSideHQ;
	if (!isNull _fhq) then {_vehicles = _vehicles - [_fhq]};
};
if (count _vehicles < 1) exitWith {};

_vehicle = [_lifter,_vehicles] Call WFBE_CO_FNC_GetClosestEntity;
//--- Cargo reservation is globally visible; do not steal a hull already in another lifter's transit lifecycle.
if (_vehicle getVariable ["wfbe_airlifted", false]) exitWith {};

if ((typeOf _vehicle in _ehq) && (!(alive _vehicle)) && (side _caller == WEST)) exitWith {hint "You can't airlift ennemy HQ wreck because someone thought it was a bit too much"};
if ((typeOf _vehicle in _whq) && (!(alive _vehicle)) && (side _caller == EAST)) exitWith {hint "You can't airlift ennemy HQ wreck because someone thought it was a bit too much"};
_type = typeOf _lifter;
_position = Zeta_DefaultPos;
_index = Zeta_Special find _type;
if (_index != -1) then {_position = Zeta_SpecialPosition select _index};

if (count crew(_vehicle) > 0) exitWith {hint (localize 'STR_WF_INFO_Hook_Manned')};

_vehicle attachTo [_lifter,_position];
_vehicle setVariable ["wfbe_airlifted", true, true]; //--- fable/airlift-gc-exempt: mark cargo so Server_HandleEmptyVehicle does not delete the (necessarily crewless) lifted hull mid-flight
_lifter setVariable ["Attached",true,true];
_lifter removeAction _actionID;

//--- B66 pass the hooked vehicle as the addAction args array; Zeta_Unhook reads (_this select 3) select 0 and threw on the empty [] arg list.
_action = _lifter addAction [localize "STR_WF_Lift_Detach","Client\Module\ZetaCargo\Zeta_Unhook.sqf",[_vehicle]];

while {!gameOver} do {
	sleep 2;
	//--- watch/big-pass (3rd instance of the XWT45-P4 defect class - see 118fcda4a Server_HandleDefense.sqf
	//--- and c2145e750/#896 Server_HandleEmptyVehicle.sqf): _lifter can be DELETED during this 2s sleep by
	//--- Server_HandleEmptyVehicle's own crew-empty GC (spawned per-vehicle from Server_BuyUnit.sqf) - only
	//--- the hooked cargo _vehicle is exempted via wfbe_airlifted, NOT the lifter itself, so a pilot-less
	//--- lifter's empty timer keeps advancing while airlifting. A null object's getVariable read below would
	//--- come up Void, undefining _isAttached at the next line's '!_isAttached' check (LATENT - not yet fired
	//--- live). Block-exit falls through to the while condition; mirror the loop's own cleanup (detach +
	//--- wfbe_airlifted reset) so the cargo is not left glued/flagged to a deleted lifter.
	//--- r50 fail-clean: cargo can also vanish during the sleep (combat/GC). Guard both sides.
	if (isNull _lifter || {isNull _vehicle}) exitWith {
		if (!isNull _vehicle) then {
			detach _vehicle;
			_vehicle setVariable ["wfbe_airlifted", false, true];
		};
	};
	_isAttached = _lifter getVariable "Attached";
	if ((getDammage _lifter > 0.3)||!_isAttached||isNull (driver _lifter)||{isNull _vehicle}) exitWith {
		if (!isNull _vehicle) then {
			detach _vehicle;
			_vehicle setVariable ["wfbe_airlifted", false, true];
		};
		if (!isNull _lifter) then {
			_lifter setVariable ["Attached",false,true];
			_lifter removeAction _action;
			if (alive _lifter) then {_lifter addAction [localize "STR_WF_Lift","Client\Module\ZetaCargo\Zeta_Hook.sqf"]};
		};
	};
};