Private["_side","_sideID","_totalSupply"];

_side = _this;
_sideID = _side Call GetSideID;
_totalSupply = 0;

{
	if ((_x getVariable "sideID") == _sideID) then	{
		_totalSupply = _totalSupply + (_x getVariable ["supplyValue", 0]);
	};
} forEach towns;

_totalSupply