Private ["_bounty", "_direction", "_global", "_globalInitMode", "_locked", "_perfScope", "_perfStart", "_position", "_side", "_special", "_track", "_type", "_vehicle", "_u"];

_type = _this select 0;
_position = _this select 1;
_side = _this select 2;
_direction = _this select 3;
_locked = _this select 4;
_bounty = if (count _this > 5) then {_this select 5} else {true};
_global = if (count _this > 6) then {_this select 6} else {true};
_special = if (count _this > 7) then {_this select 7} else {"FORM"};
// Marty: Performance Audit tracks vehicle creation and whether it starts client global init.
_perfStart = diag_tickTime;
_globalInitMode = "globalFalse";

if (typeName _position == "OBJECT") then {_position = getPos _position};
if (typeName _side == "SIDE") then {_side = (_side) Call WFBE_CO_FNC_GetSideID};

_vehicle = createVehicle [_type, _position, [], 7, _special];

// Marty: Let callers detect engine-side vehicle creation failures instead of configuring objNull.
if (isNull _vehicle) exitWith {
	["WARNING", Format ["Common_CreateVehicle.sqf: Vehicle [%1] for side [%2] failed to create at [%3].", _type, _side, _position]] Call WFBE_CO_FNC_LogContent;
	objNull
};

if(_vehicle isKindOf "Tank" || _vehicle isKindOf "APC")then{ [_vehicle] Call Compile preprocessFile "Common\Functions\Common_ModifyVehicle.sqf";};

//--- GUER improvised armour: scrappy up-armoured technicals (resistance light vehicles get no per-type handler).
if ((missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR", 0]) > 0 && {_side == WFBE_C_GUER_ID} && {!(_vehicle isKindOf "Tank")} && {!(_vehicle isKindOf "APC")} && {!(_vehicle isKindOf "Air")}) then {
	[_vehicle] Call Compile preprocessFile "Common\Functions\Common_GuerArmor.sqf";
};

//["DEBUG (Common_CreateVehicle)", Format ["Before calling"]] Call WFBE_CO_FNC_LogContent;
//if(_vehicle isKindOf "Air")then{ [_vehicle] Call Compile preprocessFile "Common\Functions\Common_ModifyAirVehicle.sqf";};
//["DEBUG (Common_CreateVehicle2)", Format ["After calling"]] Call WFBE_CO_FNC_LogContent;

//--- Miksuu team markings (experital): stamp the resolved side id + apply per-side recognition
//--- markings BEFORE the texture pass so Common_AddVehicleTexture.sqf can read wfbe_side_id for
//--- its side-gated skins. Both APPEND to wfbe_pending_texture (gate: WFBE_C_VEHICLE_MARKINGS).
[_vehicle, _side] Call Compile preprocessFile "Common\Functions\Common_AddVehicleMarking.sqf";

//--- b67 faction visuals: pass the authoritative numeric _side so the texture pass can resolve the
//--- owning faction. REQUIRED because the vehicle is still CREWLESS here, so `side _vehicle` inside
//--- the texture pass is CIVILIAN and a self-derived side would silently no-op. (wfbe_side_id is only
//--- stamped by AddVehicleMarking above, and only when WFBE_C_VEHICLE_MARKINGS=1 - default 0.)
[_vehicle, _side] Call Compile preprocessFile "Common\Functions\Common_AddVehicleTexture.sqf";

if (_special != "FLY") then {
	_vehicle setVelocity [0,0,-1];
} else {
	_vehicle setVelocity [50 * (sin _direction), 50 * (cos _direction), 0];
};
_vehicle setDir _direction;

if (_locked) then {_vehicle lock _locked};
if (_bounty) then {
	_vehicle addEventHandler ["killed", Format ['[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled', _side]];
	_vehicle addEventHandler ["hit", {_this Spawn WFBE_CO_FNC_OnUnitHit}];
};

if (_global) then {
	if (!isNil "isHeadLessClient" && {isHeadLessClient}) then {
		//--- HC-created (delegated) vehicles skip the global Init_Unit broadcast (see Common_CreateUnit).
		_globalInitMode = "hcSkipped";
	} else {
		if (_side != WFBE_DEFENDER_ID || WFBE_ISTHREEWAY) then {
			_globalInitMode = "vehicleInit";
			//--- If AddVehicleTexture stored a pending texture command (salvage tint etc.),
			//--- append it to the Init_Unit init string so both run in a single
			//--- processInitCommands call.  This is the only way to ensure JIP clients
			//--- also receive the texture — setVehicleInit stores only the LAST string set.
			Private ["_pendingTex","_initStr"];
			_pendingTex = _vehicle getVariable ["wfbe_pending_texture", ""];
			_initStr = Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf'", _side];
			if (_pendingTex != "") then { _initStr = _initStr + "; " + _pendingTex };
			_vehicle setVehicleInit _initStr;
			processInitCommands;
		} else {
			_globalInitMode = "defenderSkipped";
		};
	};
};
 
// Marty: Only globally initialized vehicles have map combat markers, so town AI can stay marker-light.
if (_global && (missionNamespace getVariable ["WFBE_C_MAP_ICON_BLINKING_ENABLED", 0]) == 1) then {
	_vehicle addEventHandler ["Fired", {
		_u = _this select 0;                 // unit that fired
		_u Call WFBE_CL_FNC_SetMapIconStatusInCombat;
	}];
};

["INFORMATION", Format ["Common_CreateVehicle.sqf: [%1] Vehicle [%2] was created at [%3].", _side Call WFBE_CO_FNC_GetSideFromID, _type, _position]] Call WFBE_CO_FNC_LogContent;

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["createvehicle", diag_tickTime - _perfStart, Format["type:%1;side:%2;global:%3;init:%4;bounty:%5;locked:%6;special:%7;isAir:%8;isTank:%9;isCar:%10", _type, _side, _global, _globalInitMode, _bounty, _locked, _special, _vehicle isKindOf "Air", _vehicle isKindOf "Tank", _vehicle isKindOf "Car"], _perfScope] Call PerformanceAudit_Record;
	};
};

_vehicle
