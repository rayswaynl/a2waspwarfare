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

//--- Fleet lane 75: keep a cheap authoritative owner-side stamp on mission-created vehicles.
//--- Dead empty vehicles report engine side poorly, so salvage uses this numeric side id to block same-side farming.
_vehicle setVariable ["wfbe_side_id", _side, true];

//--- VEHDEL probe (card wasp-vehicle-crew-fast-despawn-20260719): stamp broadcast player-use/exit
//--- times so the deletion probe can bind "a player just drove this" to the exact cleanup that
//--- deletes it. EHs are local to this (creating) machine; the stamps broadcast so a server-side
//--- delete probe can read HC/client-observed use. Telemetry-only; kill-switch shared with the probe.
if ((missionNamespace getVariable ["WFBE_C_VEH_DELETE_PROBE", 0]) > 0) then {
	//--- Round-2 review: seat role + player identity captured too (driver-aware attribution).
	//--- COVERAGE BOUNDARY (documented, accepted): assets created OUTSIDE this factory (editor-
	//--- placed, direct createVehicle callers) carry no stamps - their VEHDEL lines simply show
	//--- lastPlayerUse=-1, which is itself diagnostic (an unstamped hull a player reports driving
	//--- means an off-factory creation path is involved).
	_vehicle addEventHandler ["GetIn", {if (isPlayer (_this select 2)) then {(_this select 0) setVariable ["wfbe_player_used", round time, true]; (_this select 0) setVariable ["wfbe_player_used_role", _this select 1, true]; (_this select 0) setVariable ["wfbe_player_used_uid", getPlayerUID (_this select 2), true]}}];
	_vehicle addEventHandler ["GetOut", {if (isPlayer (_this select 2)) then {(_this select 0) setVariable ["wfbe_player_exit", round time, true]}}];
};

if(_vehicle isKindOf "Tank" || _vehicle isKindOf "APC")then{ [_vehicle] Call WFBE_CO_FNC_ModifyVehicle;}; //--- PERF: these six were per-spawn Call Compile preprocessFile (disk read + compile EVERY vehicle); now compiled once in Init_Common.sqf.

//["DEBUG (Common_CreateVehicle)", Format ["Before calling"]] Call WFBE_CO_FNC_LogContent;
if(_vehicle isKindOf "Air")then{ [_vehicle] Call WFBE_CO_FNC_ModifyAirVehicle;};
//["DEBUG (Common_CreateVehicle2)", Format ["After calling"]] Call WFBE_CO_FNC_LogContent;

//--- GUER improvised armour (#109, gate WFBE_C_GUER_IMPROVISED_ARMOR, default 0 = OFF): resistance light
//--- vehicles (technicals) get a graded non-AT HandleDamage reduction; AT/HEAT/ATGM pass straight through.
//--- Tank/APC/Air excluded. Inert while the base % is 0, so shipping default-OFF adds no runtime cost.
if ((missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR", 0]) > 0 && {_side == WFBE_C_GUER_ID} && {!(_vehicle isKindOf "Tank")} && {!(_vehicle isKindOf "APC")} && {!(_vehicle isKindOf "Air")}) then {
	[_vehicle] Call WFBE_CO_FNC_GuerArmor;
};

//--- Miksuu team markings (experital): stamp the resolved side id + apply per-side recognition
//--- markings BEFORE the texture pass so Common_AddVehicleTexture.sqf can read wfbe_side_id for
//--- its side-gated skins. Both APPEND to wfbe_pending_texture (gate: WFBE_C_VEHICLE_MARKINGS).
[_vehicle, _side] Call WFBE_CO_FNC_AddVehicleMarking;

//--- Vehicle faction flags (opt-in, gate WFBE_C_VEHICLE_FLAGS): attaches a per-side FlagCarrier pole
//--- by APPENDING to wfbe_pending_texture, so it rides the same Init_Unit broadcast below (JIP-safe).
[_vehicle, _side] Call WFBE_CO_FNC_AddVehicleFlag;

//--- b67 faction visuals: pass the authoritative numeric _side so the texture pass can resolve the
//--- owning faction. REQUIRED because the vehicle is still CREWLESS here, so `side _vehicle` inside
//--- the texture pass is CIVILIAN and a self-derived side would silently no-op. (wfbe_side_id is only
//--- stamped by AddVehicleMarking above, and only when WFBE_C_VEHICLE_MARKINGS=1 - default 0.)
[_vehicle, _side] Call WFBE_CO_FNC_AddVehicleTexture;

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

//--- cmdcon45 (owner order): Ka-137 durability - divide ALL incoming part damage by
//--- WFBE_C_KA137_HP_MULT (default 3 = 3x effective HP on every hit selection). Config armor is
//--- not mission-editable; a HandleDamage divisor is the canonical mission-side buff (CBR {0}
//--- precedent). Reads the constant per hit so it is live-tunable; guarded to >=1.
if ((_type == "Ka137_MG_PMC") || {_type == "Ka137_PMC"}) then {
	private ["_ka137Mult"];
	_ka137Mult = missionNamespace getVariable ["WFBE_C_KA137_HP_MULT", 3];
	if (_ka137Mult > 1) then {
		_vehicle addEventHandler ["HandleDamage", {
			private ["_hdMult"];
			_hdMult = missionNamespace getVariable ["WFBE_C_KA137_HP_MULT", 3];
			if (_hdMult < 1) then {_hdMult = 1};
			(_this select 2) / _hdMult
		}];
	};
};

["INFORMATION", Format ["Common_CreateVehicle.sqf: [%1] Vehicle [%2] was created at [%3].", _side Call WFBE_CO_FNC_GetSideFromID, _type, _position]] Call WFBE_CO_FNC_LogContent;

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["createvehicle", diag_tickTime - _perfStart, Format["type:%1;side:%2;global:%3;init:%4;bounty:%5;locked:%6;special:%7;isAir:%8;isTank:%9;isCar:%10", _type, _side, _global, _globalInitMode, _bounty, _locked, _special, _vehicle isKindOf "Air", _vehicle isKindOf "Tank", _vehicle isKindOf "Car"], _perfScope] Call PerformanceAudit_Record;
	};
};

_vehicle
