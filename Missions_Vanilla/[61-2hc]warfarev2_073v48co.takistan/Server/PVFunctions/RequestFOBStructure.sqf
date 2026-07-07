/*
	RequestFOBStructure.sqf — SERVER PVF: build a GUER field FOB factory from a FOB delivery truck (B75 guer-tech).

	Sent by Client\Action\Action_BuildFOB.sqf. AUTHORITATIVE: re-validates the FOB token + the enemy-town/base no-build
	zone (the client pre-check is advisory only and spoofable), spends one FOB token of the matching type, then runs the
	STANDARD GUER construction path (side = resistance) so the factory registers in WFBE_L_GUE wfbe_structures - which
	makes it a GUER spawn point + a forward production point via the existing systems - and consumes the truck.

	No commander / no base-area cap is involved (GUER has none): FOB amounts are unlimited, gated only by earned tokens.

	A2 OA 1.62/1.63 safe: array-form private only, no exitWith inside then{} (uses a _reject flag), no params/pushBack.

	_this = [facType("Barracks"/"Light"/"Heavy"), pos, dir, truck, player]
*/
private ["_secHardening","_facType","_pos","_dir","_truck","_player","_idx","_avail","_reject","_structures","_index","_classname","_script"];
_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;

if (_secHardening && {!((typeName _this) in ["ARRAY"])}) exitWith {
	["WARNING", Format ["RequestFOBStructure.sqf: malformed payload type [%1] - rejected.", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((count _this) > 4)}) exitWith {
	["WARNING", Format ["RequestFOBStructure.sqf: short payload [%1] - rejected.", _this]] Call WFBE_CO_FNC_LogContent;
};

_facType = _this select 0;
_pos     = _this select 1;
_dir     = _this select 2;
_truck   = _this select 3;
_player  = _this select 4;

if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) < 1) exitWith {};

if (_secHardening && {!((typeName _player) in ["OBJECT"]) || {isNull _player} || {!isPlayer _player} || {!alive _player}}) exitWith {
	["WARNING", Format ["RequestFOBStructure.sqf: caller [%1] is not a live player - rejected.", _player]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((side group _player) in [resistance])}) exitWith {
	["WARNING", Format ["RequestFOBStructure.sqf: caller [%1] is not GUER - rejected.", _player]] Call WFBE_CO_FNC_LogContent;
};

_idx = (missionNamespace getVariable ["WFBE_C_GUER_FOB_STRUCTS", ["Barracks","Light","Heavy"]]) find _facType;
if (_idx < 0) exitWith {["WARNING", Format ["RequestFOBStructure.sqf: unknown FOB type [%1] - rejected.", _facType]] Call WFBE_CO_FNC_LogContent};

_avail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]);
_reject = false;

//--- (1) authoritative token check.
if (_idx >= (count _avail) || {(_avail select _idx) <= 0}) then {
	_reject = true;
	["WARNING", Format ["RequestFOBStructure.sqf: no FOB token for [%1] (avail %2) - rejected.", _facType, _avail]] Call WFBE_CO_FNC_LogContent;
};

//--- (2) authoritative placement check (enemy-held town / enemy base). The client pre-checks the same gate, so a
//--- server reject here is only a spoof/race - log it (no client message needed, the client already gave feedback).
if (!_reject && {_pos call WFBE_FNC_GuerFobBlocked}) then {
	_reject = true;
	["WARNING", Format ["RequestFOBStructure.sqf: FOB [%1] placement in a restricted (enemy town/base) area - rejected.", _facType]] Call WFBE_CO_FNC_LogContent;
};

if (!_reject) then {
	//--- Spend the token + broadcast (depot FOB-truck pool + RHUD read this).
	_avail set [_idx, (_avail select _idx) - 1];
	missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _avail];
	publicVariable "WFBE_GUER_FOB_AVAIL";

	//--- Resolve the GUER structure classname + construction script for this logical type, then run the
	//--- standard construction (same path RequestStructure.sqf uses). str resistance == "GUER".
	_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES', str resistance];
	_index = _structures find _facType;
	if (_index != -1) then {
		_classname = (missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES', str resistance]) select _index;
		_script    = (missionNamespace getVariable Format ['WFBE_%1STRUCTURESCRIPTS', str resistance]) select _index;
		//--- construction-started feedback (sound/marker), mirroring RequestStructure.sqf.
		[resistance, "HandleSpecial", ['building-started', _facType, _pos]] Call WFBE_CO_FNC_SendToClients;
		[_classname, resistance, _pos, _dir, _index] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _script]);
		["INFORMATION", Format ["RequestFOBStructure.sqf: GUER FOB [%1] (%2) building at %3. Avail now %4.", _facType, _classname, _pos, _avail]] Call WFBE_CO_FNC_LogContent;
		//--- fable/fob-marker (owner 2026-07-07): resistance-only map marker while the FOB is active.
		//--- Side-scoped via the WildcardMarker createMarkerLocal idiom - WEST/EAST never see it.
		//--- Name is deterministic from position so the destroy path can delete without shared state.
		[resistance, "WildcardMarker", ["create", Format ["guer_fob_%1_%2", floor (_pos select 0), floor (_pos select 1)], _pos, "ColorGreen", "mil_objective", Format ["FOB %1", _facType], "forward base active - spawn and resupply here"]] Call WFBE_CO_FNC_SendToClients;
		//--- fable/fob-polish (2026-07-07): record the active FOB in the server-side ledger so
		//--- Server_OnPlayerConnected can replay the marker to late joiners (#846 known gap).
		missionNamespace setVariable ["WFBE_GUER_FOB_ACTIVE", (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]) + [[Format ["guer_fob_%1_%2", floor (_pos select 0), floor (_pos select 1)], _pos, _facType]]];
		//--- Consume the delivery truck - it "became" the FOB.
		if (!isNull _truck) then {deleteVehicle _truck};
	} else {
		//--- Should never happen (the GUER structure config always has Barracks/Light/Heavy). Refund the token.
		_avail set [_idx, (_avail select _idx) + 1];
		missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _avail];
		publicVariable "WFBE_GUER_FOB_AVAIL";
		["WARNING", Format ["RequestFOBStructure.sqf: GUER structure [%1] not found in WFBE_GUERSTRUCTURES - token refunded.", _facType]] Call WFBE_CO_FNC_LogContent;
	};
};
