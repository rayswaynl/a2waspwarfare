Private["_commanderTeam","_income","_incomeSystem","_side","_cmdPct","_divisor"];

_side = _this;
_incomeSystem = missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_SYSTEM", 1];
if (isNil "_incomeSystem" || {typeName _incomeSystem != "SCALAR"}) then {_incomeSystem = 1};
_income = (_side) Call GetTownsIncome;
if (isNil "_income" || {typeName _income != "SCALAR"}) then {_income = 0};

//--- r68 nil/scalar: commander_percent must be SCALAR for all arithmetic paths (case 3/4).
//--- Line 14 already defaulted 70; lines 16/28 used bare getVariable — nil destroys (100-nil) and /nil.
//--- Same default as Init_Client seed / GUI_Menu_Economy dashboard.
_cmdPct = WFBE_Client_Logic getVariable ["wfbe_commander_percent", 70];
if (isNil "_cmdPct" || {typeName _cmdPct != "SCALAR"}) then {_cmdPct = 70};

switch (_incomeSystem) do {
	case 2: {_income = round(_income /2)};
	case 3: {
		Private["_ply"];
		_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _commanderTeam) then {_commanderTeam = grpNull};
		private "_tc"; _tc = WFBE_Client_Teams_Count; if (isNil "_tc" || {_tc < 1}) then {_tc = 1};   //--- guard div-by-zero: WFBE_Client_Teams_Count is 0 for a JIP joiner before the player-team roster syncs -> "Error in expression .../WFBE_Client_Teams_Count" every income tick (found in Ray's client RPT 2026-06-27). Fall back to a 1-team (lone-player) share.
		_divisor = missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_DIVIDED", 1];
		if (isNil "_divisor" || {typeName _divisor != "SCALAR"} || {_divisor <= 0}) then {_divisor = 1};
		_ply = round(_income * (((100 - _cmdPct)/100)/_tc));
		if (_commanderTeam == group player) then {
			_income = round((_income * (_cmdPct/100)) / _divisor) + _ply;
		} else {
			_income = _ply;
		};
	};
	case 4: {
		Private["_ply","_incomeDisplayMult","_tc"];
		_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _commanderTeam) then {_commanderTeam = grpNull};
		_incomeDisplayMult = 1;
		if ((missionNamespace getVariable ["WFBE_C_FIX_INCOME_SYSTEM4_DISPLAY", 0]) > 0) then {_incomeDisplayMult = 1.5};
		_income = _income * _incomeDisplayMult;
		_ply = round(_income * (100 - _cmdPct) / 100);
		//--- r68: case 4 used bare WFBE_Client_Teams_Count (case 3 already guarded JIP zero).
		_tc = WFBE_Client_Teams_Count; if (isNil "_tc" || {_tc < 1}) then {_tc = 1};
		if (_commanderTeam == group player) then {
			_income = _ply + round((_income - _ply)*_tc);
		} else {
			_income = _ply;
		};
	};
};

_income
