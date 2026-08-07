/*
	Send a PVF to client(s).
	 Parameters:
		- Client PVF.
*/

Private ["_destination","_func","_id","_pvf","_recipient"];

_pvf = _this;
_destination = _pvf select 0;
_func = _pvf select 1;

_pvf set [1, Format["CLTFNC%1",_func]];

//--- A SIDE destination is confidentiality-bearing, not merely a client UI filter.
//--- publicVariable reaches every client before Client_HandlePVF can reject the packet,
//--- exposing side-only recon, markers and purchase state to the enemy. Deliver those
//--- packets directly to matching human clients; nil/UID routes retain their legacy scope.
if (typeName _destination == "SIDE") then {
	{
		_recipient = _x;
		if (isPlayer _recipient && {side _recipient == _destination}) then {
			_id = owner _recipient;
			if (_id > 2) then {Call Compile Format ["WFBE_PVF_%1 = _pvf; _id publicVariableClient 'WFBE_PVF_%1';", _func]};
		};
	} forEach playableUnits;
	if (isHostedServer) then {_pvf Spawn WFBE_CL_FNC_HandlePVF};
} else {
	if (!isHostedServer) then {
		Call Compile Format ["WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1';", _func];
	} else {
		_pvf Spawn WFBE_CL_FNC_HandlePVF;
		if (isMultiplayer) then {Call Compile Format ["WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1';", _func]};
	};
};
