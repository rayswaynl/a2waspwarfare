WFBE_SE_FNC_HandleSideSupplyChange = {
	//--- DR-55 forged-PVF hardening (WFBE_C_SEC_HARDENING, Common\Init\Init_CommonConstants.sqf):
	//--- this channel has NO trusted sender (addPublicVariableEventHandler carries no requester
	//--- identity), so historically ANY connected client could broadcast [side, amount, reason] on
	//--- wfbe_supply_temp_west/_east/_GUER to max out its own side's economy or zero out the
	//--- enemy's in one shot - the side/amount were asserted by the caller and never bound to who
	//--- actually sent them. Legit CLIENT callers (coin_interface.sqf, Init_Client.sqf,
	//--- GUI_Menu_Economy.sqf, Action_RepairMHQ.sqf, all funneled through the single
	//--- Common\Functions\Common_ChangeSideSupply.sqf sender) only ever request their OWN
	//--- sideJoined; Common_ChangeSideSupply.sqf now appends the caller's local `player` object as
	//--- payload[3] on that path. When the flag is on, this handler requires that requester to be a
	//--- live player whose (side group) matches the claimed side (mirrors the established
	//--- RequestMHQRepair.sqf / RequestSiteClearance.sqf trust model). The trusted in-process
	//--- server->server call (Common_ChangeSideSupply.sqf's WFBE_C_SUPPLY_SERVER_FIX==2 path, which
	//--- never crosses the network) passes _trusted=true as _this select 2 and is exempt - it never
	//--- had a "requester" to begin with. Flag OFF (default 0): byte-identical to pre-hardening
	//--- behaviour, no new rejections.
	Private ['_amount','_change','_channel','_commanderLeader','_commanderName','_commanderTeam','_currentSupply','_event','_expectedSide','_maxSupplyLimit','_payload','_reason','_rejected','_reqPlayer','_secHardening','_side','_supplyKey','_trusted'];

	_event = _this select 0;
	_expectedSide = _this select 1;
	_trusted = if (count _this > 2) then {_this select 2} else {false};
	_channel = _event select 0;
	_payload = _event select 1;

	if (typeName _payload != "ARRAY") exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected malformed side-supply payload on %1 (type %2): %3.", _channel, typeName _payload, _payload]] call WFBE_CO_FNC_LogContent;
	};

	if (count _payload < 3) exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected short side-supply payload on %1: %2.", _channel, _payload]] call WFBE_CO_FNC_LogContent;
	};

	_side = _payload select 0;
	_amount = _payload select 1;
	_reason = _payload select 2;

	if (typeName _side != "SIDE") exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 with invalid side type %2: %3.", _channel, typeName _side, _payload]] call WFBE_CO_FNC_LogContent;
	};

	if (_side != _expectedSide) exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply channel mismatch on %1. Payload side: %2.", _channel, _side]] call WFBE_CO_FNC_LogContent;
	};

	if (typeName _amount != "SCALAR") exitWith {
		["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 with invalid amount type %2: %3.", _channel, typeName _amount, _payload]] call WFBE_CO_FNC_LogContent;
	};

	if (typeName _reason != "STRING") then {_reason = str _reason};
	if (_reason == "") then {_reason = "No reason provided for supply value update! This might indicate a malicious supply update request. Check stuff if you see this message."};

	_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;

	//--- fix(exitWith-control-flow g1606): same A2-OA trap as RequestChangeScore — exitWith inside then{}
	//--- only left the hardening block and FALLS THROUGH to apply the supply write. Latch + top-scope exit.
	_rejected = false;
	if (_secHardening && !_trusted) then {
		_reqPlayer = if (count _payload > 3) then {_payload select 3} else {objNull};

		if !((typeName _reqPlayer) in ["OBJECT"]) then {
			_rejected = true;
			["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 - requester type %2 (WFBE_C_SEC_HARDENING).", _channel, typeName _reqPlayer]] call WFBE_CO_FNC_LogContent;
		};
		if (!_rejected && {isNull _reqPlayer}) then {
			_rejected = true;
			["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 - null requester (WFBE_C_SEC_HARDENING).", _channel]] call WFBE_CO_FNC_LogContent;
		};
		if (!_rejected && {!(isPlayer _reqPlayer)}) then {
			_rejected = true;
			["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 - non-player requester %2 (WFBE_C_SEC_HARDENING).", _channel, _reqPlayer]] call WFBE_CO_FNC_LogContent;
		};
		if (!_rejected && {!((side group _reqPlayer) in [_side])}) then {
			_rejected = true;
			["WARNING", format ["Server_ChangeSideSupply.sqf: rejected side-supply payload on %1 - requester side %2 does not match claimed side %3 (WFBE_C_SEC_HARDENING).", _channel, side group _reqPlayer, _side]] call WFBE_CO_FNC_LogContent;
		};
	};
	if (_rejected) exitWith {};

	_maxSupplyLimit = missionNameSpace getvariable "WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT";

	_currentSupply = (_side) Call GetSideSupply;
	if (isNil '_currentSupply') then {_currentSupply = 0};
	_change = _currentSupply + _amount;
	if (_change < 0) then {_change = 0}; //--- B66: floor supply at 0 on overdraw (was windfall bug: _currentSupply - _amount).
	if (_change > _maxSupplyLimit) then {_change = _maxSupplyLimit};

	// (_side Call WFBE_CO_FNC_GetSideLogic) setVariable ["wfbe_supply", _change, true];

	//--- A side without a player commander stores objNull; never pass that through leader/name,
	//--- because the engine emits "Error: No vehicle" inside this otherwise successful INFO line.
	_commanderName = "No commander";
	_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
	if (typeName _commanderTeam == "GROUP") then {
		if (!isNull _commanderTeam) then {
			_commanderLeader = leader _commanderTeam;
			if (!isNull _commanderLeader) then {_commanderName = name _commanderLeader};
		};
	};

	["INFORMATION", format ["Server_ChangeSideSupply.sqf: Changing supply value of team %1 with value: %2. New supply value for team: %3. Reason: %4 - Current commander of team: %5.", _side, _amount, _change, _reason, _commanderName]] call WFBE_CO_FNC_LogContent;

	_supplyKey = format ["wfbe_supply_%1", str _side];
	missionNamespace setVariable [_supplyKey,_change];
	publicVariable _supplyKey;

};

"wfbe_supply_temp_west" addPublicVariableEventHandler {
	[_this, west] Call WFBE_SE_FNC_HandleSideSupplyChange;
};

"wfbe_supply_temp_GUER" addPublicVariableEventHandler {
	//--- B67 [guer-side-supply]: wire GUER (resistance) side-supply; mirrors west/east. Additive plumbing, no-op until something credits GUER supply, does not touch west/east behavior.
	//--- wiring-sweep 2026-07-22: handler renamed _resistance -> _GUER; the sender (Common_ChangeSideSupply.sqf) formats "wfbe_supply_temp_%1" with the SIDE, and str resistance is "GUER" - the _resistance name could never fire.
	[_this, resistance] Call WFBE_SE_FNC_HandleSideSupplyChange;
};

"wfbe_supply_temp_east" addPublicVariableEventHandler {
	[_this, east] Call WFBE_SE_FNC_HandleSideSupplyChange;
};
