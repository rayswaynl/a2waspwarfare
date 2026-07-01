Private["_commanderTeam","_income","_incomeSystem","_side"];

_side = _this;
_incomeSystem = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM";
_income = (_side) Call GetTownsIncome;

switch (_incomeSystem) do {
	case 2: {_income = round(_income /2)};
	case 3: {
		Private["_ply"];
		_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _commanderTeam) then {_commanderTeam = grpNull};
		private "_tc"; _tc = WFBE_Client_Teams_Count; if (isNil "_tc" || {_tc < 1}) then {_tc = 1};   //--- guard div-by-zero: WFBE_Client_Teams_Count is 0 for a JIP joiner before the player-team roster syncs -> "Error in expression .../WFBE_Client_Teams_Count" every income tick (found in Ray's client RPT 2026-06-27). Fall back to a 1-team (lone-player) share.
		_ply = round(_income * (((100 - (WFBE_Client_Logic getVariable ["wfbe_commander_percent", 70]))/100)/_tc));
		if (_commanderTeam == group player) then {
			_income = round((_income * ((WFBE_Client_Logic getVariable "wfbe_commander_percent")/100)) / (missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_DIVIDED")) + _ply;
		} else {
			_income = _ply;
		};
	};
	case 4: {
		Private["_ply"];
		_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _commanderTeam) then {_commanderTeam = grpNull};
		_ply = round(_income * (100 - (WFBE_Client_Logic getVariable "wfbe_commander_percent")) / 100);
		if (_commanderTeam == group player) then {
			_income = _ply + round((_income - _ply)*WFBE_Client_Teams_Count);
		} else {
			_income = _ply;
		};
	};
};

_income