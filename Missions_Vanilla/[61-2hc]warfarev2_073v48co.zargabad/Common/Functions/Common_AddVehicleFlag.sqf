/*
	Common_AddVehicleFlag.sqf
	Per-side FACTION FLAG for freshly-created vehicles. A FlagCarrier pole is attached to the
	vehicle so each side's machines visibly fly that side's flag.
	Input : [_vehicle, _side]   (_side = numeric side id; WEST 0 / EAST 1 / GUER 2)
	Output: _vehicle

	Mirrors Common_AddVehicleMarking.sqf: the flag is APPENDED to the vehicle's wfbe_pending_texture
	so it rides the single Init_Unit processInitCommands broadcast in Common_CreateVehicle.sqf
	(JIP-safe) and never clobbers a per-class tint/skin/marking set elsewhere. setVehicleInit keeps
	only the LAST string set, so APPEND (never overwrite) is mandatory here.

	The cosmetic command string runs on EVERY machine (incl. JIP), so createVehicleLocal makes one
	LOCAL flag pole per client (no network object), attached to the hull.

	Gate: WFBE_C_VEHICLE_FLAGS (Init_CommonConstants.sqf). DEFAULT 0 (opt-in): it attaches a flag
	OBJECT per vehicle, so it is FPS-sensitive on heavy-AI servers. Flip to 1 to enable.

	NEEDS-IN-ENGINE-VERIFY: the attach offset [0,-1.6,1.0] (behind+above the hull origin) and the
	pole orientation are first-guesses and must be checked in-engine per vehicle class.
	enableSimulation false gives a STATIC (non-waving) flag - the FPS/physics-safe choice; removing
	it would let the flag wave (more eye-candy, more cost).
*/

Private ["_vehicle","_side","_flagClass","_fk","_pending"];
_vehicle = _this select 0;
_side    = _this select 1;

//--- Master gate (independent of WFBE_C_VEHICLE_MARKINGS so flags can be A/B'd on their own).
if ((missionNamespace getVariable ["WFBE_C_VEHICLE_FLAGS", 0]) != 1) exitWith {_vehicle};

//--- Resolve the side to its (tunable) FlagCarrier class. Each class is read via missionNamespace
//--- so a host can override it in mission setup to match their faction set-up.
_flagClass = "";
switch (_side) do {
	case WFBE_C_WEST_ID: {_flagClass = missionNamespace getVariable ["WFBE_C_VEHICLE_FLAG_WEST", "FlagCarrierNATO_EP1"]};
	case WFBE_C_EAST_ID: {_flagClass = missionNamespace getVariable ["WFBE_C_VEHICLE_FLAG_EAST", "FlagCarrierRU"]};
	case WFBE_C_GUER_ID: {_flagClass = missionNamespace getVariable ["WFBE_C_VEHICLE_FLAG_GUER", "FlagCarrierGUE"]};
};

//--- No flag for this side (or host blanked the class) -> nothing to attach.
if (_flagClass == "") exitWith {_vehicle};

//--- Build the cosmetic command string with the resolved class baked in (single-quoted SQF inside,
//--- like the marking strings). createVehicleLocal -> one LOCAL flag pole per client; attachTo rides
//--- the hull; enableSimulation false keeps it static (see header note).
_fk = "this setVariable ['wfbe_veh_flag', '" + _flagClass + "' createVehicleLocal (position this)]; (this getVariable 'wfbe_veh_flag') attachTo [this,[0,-1.6,1.0]]; (this getVariable 'wfbe_veh_flag') enableSimulation false";

//--- Append to wfbe_pending_texture (NEVER overwrite - preserves any salvage tint / side-skin / marking).
_pending = _vehicle getVariable ["wfbe_pending_texture", ""];
if (_pending != "") then {_pending = _pending + "; " + _fk} else {_pending = _fk};
_vehicle setVariable ["wfbe_pending_texture", _pending];

_vehicle
