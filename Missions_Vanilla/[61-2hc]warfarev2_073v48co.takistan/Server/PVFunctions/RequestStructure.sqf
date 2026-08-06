Private ['_dir','_index','_pos','_script','_side','_structure','_structureType','_structures','_structuresNames','_rlType','_reject','_reqPlayer','_rejectMsg','_capToken']; //--- B66: added _reject; refund-sweep: added _reqPlayer,_rejectMsg; r183: added _capToken

//--- PR #1630: envelope guard (RequestUpgrade pattern) - short/wrong-type PV payloads must not reach construction.
if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestStructure.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (count _this < 4) exitWith {
	["WARNING", Format ["RequestStructure.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_structureType = _this select 1;
_pos = _this select 2;
_dir = _this select 3;
_reqPlayer = if (count _this > 4) then {_this select 4} else {objNull}; //--- refund-sweep: placing player for targeted server-reject refund (mirrors RequestDefense.sqf)

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestStructure.sqf: rejected non-side payload side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _structureType != "STRING") exitWith {
	["WARNING", Format ["RequestStructure.sqf: rejected non-string structure type [%1].", typeName _structureType]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _pos != "ARRAY" || {count _pos < 2}) exitWith {
	["WARNING", Format ["RequestStructure.sqf: rejected invalid position [%1].", _pos]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _dir != "SCALAR") exitWith {
	["WARNING", Format ["RequestStructure.sqf: rejected non-scalar dir [%1].", _dir]] Call WFBE_CO_FNC_LogContent;
};

_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES',str _side];
_structuresNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',str _side];
_index = _structuresNames find _structureType;
if (_index < 0) exitWith {}; //--- WAVE-3 (60-audit): unknown/forged structure type -> find returns -1 and `select -1` yields nil/garbage; ignore the malformed request instead. Legit types are always in the names list, so no effect on normal builds.
_rlType = _structures select _index;

if (WF_Debug) then {["DEBUG (RequestStructure.sqf)", Format ["Building: %1", _rlType]] Call WFBE_CO_FNC_LogContent};

//--- refund-sweep MED: the side-wide 'building-started' broadcast MOVED to after reject resolution
//--- (was here, pre-veto) so a refused CBR/AAR/Bank build no longer announces construction started.

//--- B66: validation now sets a _reject flag instead of exitWith-inside-then{} (which only
//--- escaped the then{} block, so the structure ExecVM-built anyway). Build is gated on !_reject.
_reject = false;
_rejectMsg = ""; //--- refund-sweep: LocalizeMessage case for a rejected build (sent once, post-gating)
_capToken = -1; //--- r183: only accepted server-cap builds receive a release identity

//--- HARDEN u2 (60-audit, RequestStructure side-spoof): re-derive authorization from the requester's
//--- ACTUAL side, never trust the claimed _side alone - mirrors RequestMHQRepair.sqf / RequestSiteClearance.sqf
//--- ("side group _reqPlayer" idiom). Caller trace (coin_interface.sqf): every structure build including
//--- HQ deploy/pack sends the real 'player' object as arg 4. HQ was previously exempt (index 0 without a
//--- verified requester), so a forged RequestStructure with the enemy side + HQ classname could pack or
//--- deploy the enemy MHQ with no player identity. All structure requests (including HQ) now require a
//--- verified same-side player. HQ also re-checks commander-team membership server-side (coin UI is only
//--- a client gate). AI commander still ExecVMs Construction_HQSite.sqf directly and never hits this PVF.
if (isNull _reqPlayer || {!isPlayer _reqPlayer}) then {
	_reject = true;
	_rejectMsg = "StructureRequesterMismatch";
	["WARNING", Format ["RequestStructure.sqf: [%1] rejected - no verified requester for structure [%2] (index %3).", str _side, _structureType, _index]] Call WFBE_CO_FNC_LogContent;
} else {
	if !((side group _reqPlayer) in [_side]) then {
		_reject = true;
		_rejectMsg = "StructureRequesterMismatch";
		["WARNING", Format ["RequestStructure.sqf: [%1] requester side mismatch [%2] for structure [%3] (index %4) - rejected.", str _side, side group _reqPlayer, _structureType, _index]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- HQ deploy/pack (STRUCTURENAMES index 0): only the acting commander team's group may flip HQ state.
//--- Without this, any same-side player could forge RequestStructure and pack/deploy the side HQ.
if (!_reject && _index == 0) then {
	private ["_cmdTeam"];
	_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
	if (isNull _cmdTeam || {group _reqPlayer != _cmdTeam}) then {
		_reject = true;
		_rejectMsg = "StructureRequesterMismatch";
		["WARNING", Format ["RequestStructure.sqf: [%1] HQ deploy/pack rejected - requester not commander team (player=%2).", str _side, _reqPlayer]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- The CoIn preview check is advisory. Re-validate its submitted position server-side before any
//--- pending reservation or construction worker can commit a water/invalid-footprint factory.
if (!_reject && {!([_side, _structureType, _pos] Call WFBE_SE_FNC_ValidatePlayerStructurePlacement)}) then {
	_reject = true;
	_rejectMsg = "StructurePlacementInvalid";
	["WARNING", Format ["RequestStructure.sqf: [%1] %2 build rejected - invalid player placement at %3.", str _side, _rlType, _pos]] Call WFBE_CO_FNC_LogContent;
};

//--- CBR requires an alive AAR on the same side.
if (_rlType == "CBRadar") then {
	private ["_aarClass","_aarAlive","_structs"];
	_aarClass = missionNamespace getVariable [Format ["%1AAR", str _side], ""];
	_aarAlive = false;
	if (_aarClass != "") then {
		_structs = (_side) Call WFBE_CO_FNC_GetSideStructures;
		{if (alive _x && typeOf _x == _aarClass) exitWith {_aarAlive = true}} forEach _structs;
	};
	if (!_aarAlive) then {
		_reject = true; //--- B66: was exitWith (escaped only the then{}).
		_rejectMsg = "CBRadarNeedsAAR";
		["WARNING", Format ["RequestStructure.sqf: [%1] CBRadar build rejected — no alive AAR.", str _side]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- CBRadar/AARadar: one per side + duplicate-build race guard (fable/ew-economy). Mirrors the
//--- Bank pending-reservation guard below: WFBE_C_STRUCTURES_MAX_CBRadar/AARadar (both default 1,
//--- Init_CommonConstants.sqf) is otherwise enforced ONLY client-side via the per-client
//--- wfbe_structures_live counter (coin_interface.sqf), which is racy - two clients (or one client
//--- double-clicking before its own local counter refreshes) can both pass that gate and fire this
//--- PV inside the same ~60s build window, landing two radars. Reject synchronously if a live one
//--- already exists on this side OR a recent pending reservation (another accepted-but-still-
//--- constructing request) is in flight - same shape as the Bank guard immediately below.
if (_rlType in ["CBRadar","AARadar"]) then {
	private ["_rrClassVar","_rrClass","_rrAlive","_rrStructs","_rrPendingKey","_rrPendingTime","_rrPendingWindow","_rrMsg"];
	_rrClassVar = if (_rlType == "AARadar") then {Format ["%1AAR", str _side]} else {Format ["%1CBR", str _side]};
	_rrClass = missionNamespace getVariable [_rrClassVar, ""];
	_rrAlive = false;
	if (_rrClass != "") then {
		_rrStructs = (_side) Call WFBE_CO_FNC_GetSideStructures;
		{if (alive _x && typeOf _x == _rrClass) exitWith {_rrAlive = true}} forEach _rrStructs;
	};
	_rrPendingKey = Format ["WFBE_%1_%2_PENDING", str _side, _rlType];
	_rrPendingWindow = missionNamespace getVariable ["WFBE_C_STRUCTURES_RADAR_PENDING_WINDOW", 180];
	_rrPendingTime = missionNamespace getVariable [_rrPendingKey, -1e11];
	_rrMsg = if (_rlType == "AARadar") then {"AARadarAlreadyBuilt"} else {"CBRadarAlreadyBuilt"};
	if (!_reject && _rrAlive) then {
		_reject = true; //--- B66 idiom: was exitWith (escaped only the then{}).
		_rejectMsg = _rrMsg;
		["WARNING", Format ["RequestStructure.sqf: [%1] %2 build rejected - one already alive.", str _side, _rlType]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_reject && (time - _rrPendingTime) < _rrPendingWindow) then {
		_reject = true; //--- duplicate-click race: a reservation for this side+type is already in flight.
		_rejectMsg = _rrMsg;
		["WARNING", Format ["RequestStructure.sqf: [%1] %2 build rejected - reservation already pending (%3s ago).", str _side, _rlType, (time - _rrPendingTime)]] Call WFBE_CO_FNC_LogContent;
	};
	//--- Reserve the slot synchronously at accept time. Construction_SmallSite.sqf (CBRadar) /
	//--- Construction_MediumSite.sqf (AARadar) clear this flag once the real structure registers.
	if (!_reject) then {
		missionNamespace setVariable [_rrPendingKey, time];
	};
};

//--- Bank: one per side + must be placed outside own base protection area.
if (_rlType == "Bank" && (missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	private ["_bankKey","_existingBank","_logik","_startPos","_baseAreas","_protRange","_tooClose","_checkCenters","_pendingKey","_pendingTime","_pendingWindow"];
	_bankKey = if (_side == west) then {"WFBE_BANK_WEST"} else {"WFBE_BANK_EAST"};
	//--- B66: synchronous duplicate-race guard. Reject if a live bank exists OR a recent
	//--- pending reservation (another accepted-but-still-constructing request) is in flight.
	_pendingKey = _bankKey + "_PENDING";
	_pendingWindow = missionNamespace getVariable ["WFBE_C_ECONOMY_BANK_PENDING_WINDOW", 180];
	_pendingTime = missionNamespace getVariable [_pendingKey, -1e11];
	_existingBank = missionNamespace getVariable [_bankKey, objNull];
	if (!(isNull _existingBank) && alive _existingBank) then {
		_reject = true; //--- B66: was exitWith (escaped only the then{}).
		_rejectMsg = "BankAlreadyBuilt";
		["WARNING", Format ["RequestStructure.sqf: [%1] Bank build rejected — bank already alive.", str _side]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_reject && (time - _pendingTime) < _pendingWindow) then {
		_reject = true; //--- B66: a bank reservation is already in flight (duplicate-click race).
		_rejectMsg = "BankAlreadyBuilt";
		["WARNING", Format ["RequestStructure.sqf: [%1] Bank build rejected — reservation already pending (%2s ago).", str _side, (time - _pendingTime)]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_reject) then {
		_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
		_startPos = _logik getVariable ["wfbe_startpos", [0,0,0]];
		_baseAreas = _logik getVariable ["wfbe_basearea", []];
		_protRange = missionNamespace getVariable ["WFBE_C_BASE_PROTECTION_RANGE", 800];
		_checkCenters = [_startPos];
		{_checkCenters = _checkCenters + [getPos _x]} forEach _baseAreas;
		_tooClose = false;
		{if (_pos distance _x < _protRange) exitWith {_tooClose = true}} forEach _checkCenters;
		if (_tooClose) then {
			_reject = true; //--- B66: was exitWith (escaped only the then{}).
			_rejectMsg = "BankTooCloseToBase";
			["WARNING", Format ["RequestStructure.sqf: [%1] Bank build rejected — placement too close to base (< %2 m).", str _side, _protRange]] Call WFBE_CO_FNC_LogContent;
		};
	};
	//--- B66: reserve the slot synchronously at accept time. Construction_MediumSite.sqf
	//--- clears this flag once the real bank _site is registered.
	if (!_reject) then {
		missionNamespace setVariable [_pendingKey, time];
	};
};

//--- build/defense audit 2026-07-28: server-side cap + duplicate-build race guard for the MULTI-INSTANCE
//--- economy structures (Barracks/Light/Heavy/Aircraft/ServicePoint/CommandCenter). Mirrors the CBRadar/
//--- AARadar (L73-101 above) and Bank (L104-143 above) single-instance PENDING-reservation idiom: those
//--- types are otherwise enforced ONLY client-side via the optimistic wfbe_structures_live counter
//--- (coin_interface.sqf), which races (two commanders, or one client double-clicking before its own
//--- counter refreshes, can both pass the client gate and land two structures over the declared
//--- WFBE_C_STRUCTURES_MAX_<type> cap). The AI commander already obeys these SAME per-type caps
//--- server-side (AI_Commander_Base.sqf ~L686-711: same WFBE_C_STRUCTURES_MAX_%1 lookup + LIVE-structure
//--- count via WFBE_CO_FNC_GetSideStructures/wfbe_structure_type) - that exact idiom is reused verbatim
//--- below as the trusted LIVE-count source. PENDING is a self-expiring array (not a scalar timestamp
//--- like the radar/bank guards) because several concurrent multi-instance builds of the SAME type can
//--- legitimately be in flight at once; each entry is pruned once older than the pending window, which
//--- also bounds any reservation that a construction-side release path failed to clear (see the release
//--- points cited in the PR body). Gate: WFBE_C_STRUCTURES_CAP_SERVER (default 1, armed - it only
//--- rejects what the declared caps already forbid the AI server-side; 0 = legacy client-only, byte-
//--- identical to HEAD).
if (!_reject && (_rlType in ["Barracks","Light","CommandCenter","Heavy","Aircraft","ServicePoint"]) && {(missionNamespace getVariable ["WFBE_C_STRUCTURES_CAP_SERVER", 1]) > 0}) then {
	private ["_capTypeLimit","_capLiveHave","_capPendingKey","_capPendingWindow","_capPendingArr","_capFreshArr","_capEntry","_capI","_capPendingHave","_capSeqKey","_capSeq"];
	_capTypeLimit = missionNamespace getVariable [Format ["WFBE_C_STRUCTURES_MAX_%1", _rlType], 3]; //--- case-insensitive getVariable, same idiom as AI_Commander_Base.sqf / coin_interface.sqf:917.
	if (typeName _capTypeLimit != "SCALAR") then {_capTypeLimit = 3};
	_capLiveHave = {((_x getVariable ["wfbe_structure_type", ""]) == _rlType) && {alive _x}} count ((_side) Call WFBE_CO_FNC_GetSideStructures); //--- same trusted LIVE source AI_Commander_Base.sqf reads.
	_capPendingKey = Format ["WFBE_%1_%2_PENDING", str _side, _rlType];
	_capPendingWindow = missionNamespace getVariable ["WFBE_C_STRUCTURES_PENDING_WINDOW", 180];
	_capPendingArr = missionNamespace getVariable [_capPendingKey, []];
	_capFreshArr = [];
	for "_capI" from 0 to (count _capPendingArr - 1) do {
		_capEntry = _capPendingArr select _capI;
		if (typeName _capEntry == "ARRAY" && {count _capEntry > 1} && {typeName (_capEntry select 0) == "SCALAR"} && {typeName (_capEntry select 1) == "SCALAR"} && {(time - (_capEntry select 1)) < _capPendingWindow}) then {
			_capFreshArr set [count _capFreshArr, _capEntry];
		};
	};
	_capPendingHave = count _capFreshArr;
	if ((_capLiveHave + _capPendingHave) >= _capTypeLimit) then {
		_reject = true; //--- same idiom as the radar/bank guards above: was never exitWith (escaped only the then{}).
		_rejectMsg = "StructureCapReached";
		["WARNING", Format ["RequestStructure.sqf: [%1] %2 build rejected - server cap reached (live=%3, pending=%4, max=%5).", str _side, _rlType, _capLiveHave, _capPendingHave, _capTypeLimit]] Call WFBE_CO_FNC_LogContent;
	} else {
		//--- Reserve the slot synchronously at accept time (pruned array write - see comment block above).
		//--- Each entry is [reservation token, accept time]. The construction worker receives the same
		//--- token and releases only its own entry, so out-of-order completion cannot steal a sibling
		//--- build's reservation.
		_capSeqKey = Format ["WFBE_%1_%2_PENDING_SEQ", str _side, _rlType];
		_capSeq = missionNamespace getVariable [_capSeqKey, 0];
		if (typeName _capSeq != "SCALAR") then {_capSeq = 0};
		_capToken = _capSeq + 1;
		missionNamespace setVariable [_capSeqKey, _capToken];
		missionNamespace setVariable [_capPendingKey, _capFreshArr + [[_capToken, time]]];
	};
};

//--- refund-sweep: a rejected build refunds the placing player (targeted) then skips broadcast + build.
//--- Mirrors RequestDefense.sqf B5 (targeted SendToClient + client-side pool refund). Non-player callers
//--- (objNull _reqPlayer, e.g. HQ redeploy) fall back to the legacy side-wide notify with NO refund.
if (_reject) exitWith {
	if (!isNull _reqPlayer && {isPlayer _reqPlayer}) then {
		private ["_costsArr","_refundPrice"];
		_refundPrice = 0;
		_costsArr = missionNamespace getVariable [Format ["WFBE_%1STRUCTURECOSTS", str _side], []];
		if (_index >= 0 && {_index < count _costsArr}) then {_refundPrice = _costsArr select _index};
		[_reqPlayer, "LocalizeMessage", [_rejectMsg, _refundPrice, _index]] Call WFBE_CO_FNC_SendToClient; //--- base-build r11: pass STRUCTURENAMES index so the client rolls back its optimistic wfbe_structures_live increment on reject.
	} else {
		[_side, "LocalizeMessage", [_rejectMsg]] Call WFBE_CO_FNC_SendToClients;
	};
};

//--- refund-sweep MED: broadcast construction-started only after the build is accepted (moved from top).
if (_rlType in ["Barracks", "Light", "CommandCenter", "Heavy", "Aircraft", "ServicePoint", "AARadar", "CBRadar", "Bank", "ArtilleryRadar", "Reserve"]) then {
	[_side, "HandleSpecial", ['building-started', _rlType, _pos]] Call WFBE_CO_FNC_SendToClients;
};

_index = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",str _side]) find _structureType;
if (_index != -1) then { //--- refund-sweep: reject already exited above; build the accepted structure.
	_script = (missionNamespace getVariable Format ["WFBE_%1STRUCTURESCRIPTS",str _side]) select _index;
	[_structureType,_side,_pos,_dir,_index,"","",_reqPlayer,_capToken] ExecVM (Format["Server\Construction\Construction_%1.sqf",_script]); //--- r31: pass the verified placer through; r183: pass the cap reservation identity.
};
