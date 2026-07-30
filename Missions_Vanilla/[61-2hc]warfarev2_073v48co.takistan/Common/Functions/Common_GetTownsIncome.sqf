Private ["_income","_incomeCoef","_incomeSystem","_side"];
_side = (_this) Call GetSideID;

_income = 0;
_incomeSystem = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM";
_incomeCoef = 0;
if (_incomeSystem == 3) then {_incomeCoef = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_COEF"};

{
	//--- 2-arg sideID: same class as GetTownsSupply — never credit a nil-owned town.
	private "_sid";
	_sid = _x getVariable ["sideID", WFBE_C_UNKNOWN_ID];
	if (!(isNil "_sid") && {_sid == _side}) then {
		switch (_incomeSystem) do {
			case 3: {_income = _income + ((_x getVariable ["supplyValue", 0])*_incomeCoef)};
			default {_income = _income + (_x getVariable ["supplyValue", 0])};
		};
	};
} forEach towns;

_income
