/*
	Send a PVF to the server.
	 Parameters:
		- Server PVF.
*/

Private ["_func","_pvf"];

_pvf = _this;
_func = _pvf select 0;

_pvf set [0, Format["SRVFNC%1",_func]];

//--- LOCALITY/PV (g1606 2026-07-30): same dedicated self-PV trap as SendToServerOptimized -
//--- publicVariable also does not fire the sender's own PVEH. Route server-local calls direct.
if (isServer) then {
	_pvf Spawn WFBE_SE_FNC_HandlePVF;
} else {
	Call Compile Format ["WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1';", _func];
};