/*
	RequestFOBStructure.sqf — SERVER PVF: build a GUER field FOB factory from a FOB delivery truck (B75 guer-tech).

	Sent by Client\Action\Action_BuildFOB.sqf. AUTHORITATIVE: re-validates the FOB token + the enemy-town/base no-build
	zone (the client pre-check is advisory only and spoofable), reserves one FOB token while the STANDARD GUER construction
	path acknowledges its start, then registers the factory in WFBE_L_GUE wfbe_structures - which makes it a GUER spawn
	point + a forward production point via the existing systems - and consumes the truck only after construction starts.

	No commander / no base-area cap is involved (GUER has none): FOB amounts are unlimited, gated only by earned tokens.

	A2 OA 1.62/1.63 safe: array-form private only, no exitWith inside then{} (uses a _reject flag), no params/pushBack.

	_this = [facType("Barracks"/"Light"/"Heavy"), pos, dir, truck, player]
*/
private ["_secHardening","_facType","_pos","_dir","_truck","_player","_idx","_avail","_reject","_structures","_index","_classname","_script","_structureNames","_structureScripts","_structureDistances","_flatRadius","_fobTrucks","_startResultKey","_completionResultKey","_startResult","_startMessage","_buildHandle","_currentAvail"];
_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;

if (_secHardening && {!((typeName _this) in ["ARRAY"])}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=malformed-payload|payloadType=%1", typeName _this];
	["WARNING", Format ["RequestFOBStructure.sqf: malformed payload type [%1] - rejected.", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((count _this) > 4)}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=short-payload|count=%1", count _this];
	["WARNING", Format ["RequestFOBStructure.sqf: short payload [%1] - rejected.", _this]] Call WFBE_CO_FNC_LogContent;
};

_facType = _this select 0;
_pos     = _this select 1;
_dir     = _this select 2;
_truck   = _this select 3;
_player  = _this select 4;

//--- Always-on round evidence: WFBE_CO_FNC_LogContent is compiled out on normal release servers, so it cannot
//--- distinguish a missing PV request from an authoritative reject. Keep this concise and avoid player identity.
diag_log Format ["GUERFOB|v1|request|type=%1|pos=%2", _facType, _pos];

if (!((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0)) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=guer-disabled|type=%1|pos=%2", _facType, _pos];
};

if (_secHardening && {!((typeName _player) in ["OBJECT"]) || {isNull _player} || {!isPlayer _player} || {!alive _player}}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=invalid-player|type=%1|pos=%2", _facType, _pos];
	["WARNING", Format ["RequestFOBStructure.sqf: caller [%1] is not a live player - rejected.", _player]] Call WFBE_CO_FNC_LogContent;
};
if (_secHardening && {!((side group _player) in [resistance])}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=non-guer-player|type=%1|pos=%2", _facType, _pos];
	["WARNING", Format ["RequestFOBStructure.sqf: caller [%1] is not GUER - rejected.", _player]] Call WFBE_CO_FNC_LogContent;
};

_idx = (missionNamespace getVariable ["WFBE_C_GUER_FOB_STRUCTS", ["Barracks","Light","Heavy"]]) find _facType;
if (_idx < 0) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=unknown-type|type=%1|pos=%2", _facType, _pos];
	["WARNING", Format ["RequestFOBStructure.sqf: unknown FOB type [%1] - rejected.", _facType]] Call WFBE_CO_FNC_LogContent;
};

//--- A truck can be committed only once. The pending mark is server-visible before the constructor yields,
//--- so a repeated action/PV cannot consume multiple tokens while the final factory is still building.
if ((typeName _truck) != "OBJECT" || {isNull _truck} || {!alive _truck}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=invalid-truck|type=%1|pos=%2", _facType, _pos];
	if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
		[_player, "HandleSpecial", ["guer-fob-result", false, "FOB build rejected: the delivery truck is no longer available."]] Call WFBE_CO_FNC_SendToClient;
	};
};
if !(_truck getVariable ["wfbe_is_guer_fob", false]) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=unflagged-truck|type=%1|pos=%2", _facType, _pos];
};
if (_truck getVariable ["wfbe_guer_fob_pending", false]) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=truck-pending|type=%1|pos=%2", _facType, _pos];
};
_fobTrucks = missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []];
if (_idx >= (count _fobTrucks) || {typeOf _truck != (_fobTrucks select _idx)}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=wrong-truck-type|type=%1|pos=%2", _facType, _pos];
};

//--- Resolve the configured factory before any token/truck mutation. All valid GUER FOB types map to SmallSite or
//--- MediumSite; its structure-distance entry is the footprint used by both client and server placement gates.
_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES', str resistance];
_index = _structures find _facType;
if (_index < 0) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=missing-structure|type=%1|pos=%2", _facType, _pos];
	if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
		[_player, "HandleSpecial", ["guer-fob-result", false, "FOB build rejected: this factory type is unavailable. No token or truck was consumed."]] Call WFBE_CO_FNC_SendToClient;
	};
	["WARNING", Format ["RequestFOBStructure.sqf: GUER structure [%1] not found in WFBE_GUERSTRUCTURES - rejected before token spend.", _facType]] Call WFBE_CO_FNC_LogContent;
};
_structureNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES', str resistance];
_structureScripts = missionNamespace getVariable Format ['WFBE_%1STRUCTURESCRIPTS', str resistance];
if (_index >= (count _structureNames) || {_index >= (count _structureScripts)}) exitWith {
	diag_log Format ["GUERFOB|v1|reject|reason=invalid-structure-config|type=%1|pos=%2", _facType, _pos];
	if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
		[_player, "HandleSpecial", ["guer-fob-result", false, "FOB build rejected: this factory type is unavailable. No token or truck was consumed."]] Call WFBE_CO_FNC_SendToClient;
	};
	["WARNING", Format ["RequestFOBStructure.sqf: GUER structure [%1] has incomplete configuration - rejected before token spend.", _facType]] Call WFBE_CO_FNC_LogContent;
};
_classname = _structureNames select _index;
_script = _structureScripts select _index;
_flatRadius = missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_RADIUS", 10];
_structureDistances = missionNamespace getVariable Format ['WFBE_%1STRUCTUREDISTANCES', str resistance];
if (_index < (count _structureDistances) && {(typeName (_structureDistances select _index)) == "SCALAR"}) then {
	_flatRadius = _flatRadius max (_structureDistances select _index);
};

_avail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]);
_reject = false;

//--- (1) authoritative token check.
if (_idx >= (count _avail) || {(_avail select _idx) <= 0}) then {
	_reject = true;
	diag_log Format ["GUERFOB|v1|reject|reason=no-token|type=%1|pos=%2|avail=%3", _facType, _pos, _avail];
	if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
		[_player, "HandleSpecial", ["guer-fob-result", false, "FOB build rejected: no matching FOB token is available."]] Call WFBE_CO_FNC_SendToClient;
	};
	["WARNING", Format ["RequestFOBStructure.sqf: no FOB token for [%1] (avail %2) - rejected.", _facType, _avail]] Call WFBE_CO_FNC_LogContent;
};

//--- (2) authoritative placement check (enemy-held town / enemy base + the actual configured factory footprint).
//--- The client pre-checks the same gate, so a server reject here is only a spoof/race - log it for the RPT.
if (!_reject && {[_pos, _flatRadius] Call WFBE_FNC_GuerFobBlocked}) then {
	_reject = true;
	diag_log Format ["GUERFOB|v1|reject|reason=blocked-placement|type=%1|pos=%2", _facType, _pos];
	if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
		[_player, "HandleSpecial", ["guer-fob-result", false, "FOB build rejected: choose dry, flat ground outside enemy town and base areas."]] Call WFBE_CO_FNC_SendToClient;
	};
	["WARNING", Format ["RequestFOBStructure.sqf: FOB [%1] placement in a restricted (enemy town/base) area - rejected.", _facType]] Call WFBE_CO_FNC_LogContent;
};

if (!_reject) then {
	//--- Register a one-shot server-local result before reserving the token. Server_HandlePVF runs PVFs in a scheduled
	//--- scope, so this can wait briefly for the constructor's pre-wait acknowledgement without stalling the PV bus.
	_startResultKey = Format ["wfbe_guer_fob_start_%1_%2", floor (diag_tickTime * 1000), floor (random 1000000000)];
	_completionResultKey = Format ["wfbe_guer_fob_complete_%1_%2", floor (diag_tickTime * 1000), floor (random 1000000000)];
	missionNamespace setVariable [_startResultKey, [0, ""]];
	missionNamespace setVariable [_completionResultKey, [0, ""]];

	//--- Reserve the token + broadcast (depot FOB-truck pool + RHUD read this). A failed constructor refunds from the
	//--- current shared array below, preserving concurrent deductions on other FOB types.
	_avail set [_idx, (_avail select _idx) - 1];
	missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _avail];
	publicVariable "WFBE_GUER_FOB_AVAIL";
	_truck setVariable ["wfbe_guer_fob_pending", true, true];
	_truck setVariable ["wfbe_is_guer_fob", false, true];

	//--- The Small/Medium worker publishes [1, ""] before its first construction wait, or [-1, reason] on an
	//--- unavailable LocationLogicStart. It later reports the final factory result through a second key.
	_buildHandle = [_classname, resistance, _pos, _dir, _index, _startResultKey, _completionResultKey] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _script]);
	_startResult = [0, ""];
	waitUntil {
		sleep 0.05;
		_startResult = missionNamespace getVariable [_startResultKey, [0, ""]];
		((typeName _startResult) == "ARRAY" && {(count _startResult) > 0} && {(_startResult select 0) != 0}) || {scriptDone _buildHandle}
	};
	if ((typeName _startResult) != "ARRAY" || {(count _startResult) < 1}) then {_startResult = [-1, "construction start did not report a result"]};

	if ((_startResult select 0) == 1) then {
		//--- A confirmed start hides the committed truck from the action/respawn path, but the real
		//--- factory, marker, ledger, and truck deletion all wait for the worker's terminal receipt.
		[resistance, "HandleSpecial", ['building-started', _facType, _pos]] Call WFBE_CO_FNC_SendToClients;
		diag_log Format ["GUERFOB|v1|start|type=%1|pos=%2|avail=%3", _facType, _pos, _avail];
		["INFORMATION", Format ["RequestFOBStructure.sqf: GUER FOB [%1] (%2) construction started at %3. Avail now %4.", _facType, _classname, _pos, _avail]] Call WFBE_CO_FNC_LogContent;
		[_completionResultKey, _buildHandle, _idx, _facType, _pos, _truck, _player] Spawn {
		private ["_completionResultKey","_buildHandle","_idx","_facType","_pos","_truck","_player","_completionResult","_completionMessage","_currentAvail","_truckRestored","_completionSite","_completionLogic","_completionRegistered"];
			_completionResultKey = _this select 0;
			_buildHandle = _this select 1;
			_idx = _this select 2;
			_facType = _this select 3;
			_pos = _this select 4;
			_truck = _this select 5;
			_player = _this select 6;
			_completionResult = [0, ""];
			waitUntil {
				sleep 0.5;
				_completionResult = missionNamespace getVariable [_completionResultKey, [0, ""]];
				((typeName _completionResult) == "ARRAY" && {(count _completionResult) > 0} && {(_completionResult select 0) != 0}) || {scriptDone _buildHandle}
			};
			if ((typeName _completionResult) != "ARRAY" || {(count _completionResult) < 1} || {(_completionResult select 0) == 0}) then {_completionResult = [-1, "construction did not report a final result"]};
			_completionSite = objNull;
			_completionLogic = objNull;
			_completionRegistered = false;
			if ((_completionResult select 0) == 1) then {
				if ((count _completionResult) > 1 && {(typeName (_completionResult select 1)) == "OBJECT"}) then {
					_completionSite = _completionResult select 1;
				};
				if (!isNull _completionSite && {alive _completionSite}) then {
					_completionLogic = resistance Call WFBE_CO_FNC_GetSideLogic;
					if (!isNull _completionLogic && {!(isNil {_completionLogic getVariable "wfbe_structures"})}) then {
						_completionRegistered = _completionSite in (_completionLogic getVariable "wfbe_structures");
					};
				};
				if (isNull _completionSite || {!alive _completionSite} || {!_completionRegistered}) then {
					_completionResult = [-1, "completed factory did not remain active"];
				};
			};
			if ((_completionResult select 0) == 1) then {
				//--- fable/fob-marker (owner 2026-07-07): resistance-only map marker once the real FOB is active.
				//--- Side-scoped via the WildcardMarker createMarkerLocal idiom - WEST/EAST never see it.
				//--- Name is deterministic from position so the destroy path can delete without shared state.
				[resistance, "WildcardMarker", ["create", Format ["guer_fob_%1_%2", floor (_pos select 0), floor (_pos select 1)], _pos, "ColorGreen", "mil_objective", Format ["FOB %1", _facType], "forward base active - spawn and resupply here"]] Call WFBE_CO_FNC_SendToClients;
				//--- fable/fob-polish (2026-07-07): record the active FOB in the server-side ledger so
				//--- Server_OnPlayerConnected can replay the marker to late joiners (#846 known gap).
				missionNamespace setVariable ["WFBE_GUER_FOB_ACTIVE", (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]) + [[Format ["guer_fob_%1_%2", floor (_pos select 0), floor (_pos select 1)], _pos, _facType]]];
				if (!isNull _truck) then {deleteVehicle _truck};
				diag_log Format ["GUERFOB|v1|accept|type=%1|pos=%2", _facType, _pos];
			} else {
				_completionMessage = "FOB construction failed; your token was restored.";
				_currentAvail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", []]);
				if (_idx < (count _currentAvail) && {(typeName (_currentAvail select _idx)) == "SCALAR"}) then {
					_currentAvail set [_idx, (_currentAvail select _idx) + 1];
					missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _currentAvail];
					publicVariable "WFBE_GUER_FOB_AVAIL";
				};
				_truckRestored = false;
				if (!isNull _truck && {alive _truck}) then {
					_truck setVariable ["wfbe_guer_fob_pending", false, true];
					_truck setVariable ["wfbe_is_guer_fob", true, true];
					_truckRestored = true;
				};
				if (_truckRestored) then {_completionMessage = "FOB construction failed; your token was restored and the delivery truck is available again."};
				diag_log Format ["GUERFOB|v1|reject|reason=construction-completion-failed|type=%1|pos=%2", _facType, _pos];
				if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
					[_player, "HandleSpecial", ["guer-fob-result", false, _completionMessage]] Call WFBE_CO_FNC_SendToClient;
				};
				["WARNING", Format ["RequestFOBStructure.sqf: GUER FOB [%1] final construction failed at %2 - token restored; truck restored=%3.", _facType, _pos, _truckRestored]] Call WFBE_CO_FNC_LogContent;
			};
			missionNamespace setVariable [_completionResultKey, []];
		};
	} else {
		_startMessage = "construction start did not complete";
		if ((count _startResult) > 1 && {(typeName (_startResult select 1)) == "STRING"} && {(_startResult select 1) != ""}) then {_startMessage = _startResult select 1};
		_currentAvail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", []]);
		if (_idx < (count _currentAvail) && {(typeName (_currentAvail select _idx)) == "SCALAR"}) then {
			_currentAvail set [_idx, (_currentAvail select _idx) + 1];
			missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _currentAvail];
			publicVariable "WFBE_GUER_FOB_AVAIL";
		};
		if (!isNull _truck && {alive _truck}) then {
			_truck setVariable ["wfbe_guer_fob_pending", false, true];
			_truck setVariable ["wfbe_is_guer_fob", true, true];
		};
		if (_startMessage == "LocationLogicStart missing") then {
			diag_log Format ["GUERFOB|v1|reject|reason=missing-start-logic|type=%1|pos=%2", _facType, _pos];
		} else {
			diag_log Format ["GUERFOB|v1|reject|reason=construction-start-failed|type=%1|pos=%2", _facType, _pos];
		};
		if ((typeName _player) == "OBJECT" && {!isNull _player}) then {
			[_player, "HandleSpecial", ["guer-fob-result", false, "FOB build rejected: construction could not start; your token was restored and truck preserved."]] Call WFBE_CO_FNC_SendToClient;
		};
		["WARNING", Format ["RequestFOBStructure.sqf: GUER FOB [%1] construction start failed at %2 (%3) - token restored and truck preserved.", _facType, _pos, _startMessage]] Call WFBE_CO_FNC_LogContent;
		missionNamespace setVariable [_completionResultKey, []];
	};
	missionNamespace setVariable [_startResultKey, []];
};
