Private ['_amount','_change','_currentSupply','_side','_maxSupplyLimit','_reason','_includeStagnation','_supplyServerFix'];

_side = _this select 0;
_amount = _this select 1;
_includeStagnation = false;
_reason = "ERROR! No reason specified. This should not happen! Check logs.";

if (count _this > 3) then {
	_includeStagnation = _this select 3;
};

if (count _this > 2) then { //--- wiki-wins: _reason is index 2; 3-arg callers (e.g. AttackWave) were dropping it (was > 3)
	_reason = _this select 2;
};

if (_amount > 0 && _includeStagnation) then {
	_amount = [_amount, _side] call WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers;
};

//--- B66: removed dead clamp arithmetic (_maxSupplyLimit/_currentSupply/_change). It was never
//--- consumed — only the temp-channel publish below matters; the server-side handler in
//--- Server_ChangeSideSupply.sqf recomputes + clamps the authoritative value.

//--- fix(supplyfix): publicVariableServer never fires the SENDING machine's own PVEH, so on a
//--- dedicated server every server/AI-originated call above was a silent no-op — the same trap
//--- already documented + repaired for the wave channel (Server\PVFunctions\AttackWave.sqf) and
//--- for Server\Module\supplyMission\supplyMissionCompleted.sqf. Remote clients/HC are unaffected;
//--- their publish still reaches the server's PVEH normally and keeps using the path below unchanged.
//--- WFBE_C_SUPPLY_SERVER_FIX (Common\Init\Init_CommonConstants.sqf) gates the server-side repair:
//--- 0 = off (default) — byte-identical to before, no server-side apply; 1 = shadow — diag_logs the
//--- would-be pre/post delta without applying it; 2 = apply — calls the handler directly with its
//--- full event envelope, the same shape already proven at Server\PVFunctions\AttackWave.sqf:73.
_supplyServerFix = missionNamespace getVariable ["WFBE_C_SUPPLY_SERVER_FIX", 0];
if (isServer && (_supplyServerFix > 0)) then {
	if (_supplyServerFix == 2) then {
		[[format ["wfbe_supply_temp_%1", _side], [_side, _amount, _reason]], _side] Call WFBE_SE_FNC_HandleSideSupplyChange;
	} else {
		_currentSupply = _side Call GetSideSupply;
		if (isNil "_currentSupply") then {_currentSupply = 0};
		_maxSupplyLimit = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 40000];
		_change = _currentSupply + _amount;
		if (_change < 0) then {_change = 0};
		if (_change > _maxSupplyLimit) then {_change = _maxSupplyLimit};
		diag_log format ["SUPPLYFIX|v1|SHADOW|side=%1|amount=%2|reason=%3|pre=%4|wouldbe=%5", _side, _amount, _reason, _currentSupply, _change];
	};
} else {
	missionNamespace setVariable [format ["wfbe_supply_temp_%1", _side], [_side, _amount, _reason]];

	publicVariableServer format ["wfbe_supply_temp_%1", _side];
};

// (_side Call WFBE_CO_FNC_GetSideLogic) setVariable ["wfbe_supply", _change, true];