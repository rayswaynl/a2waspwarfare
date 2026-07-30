/*
	Send a PVF to the server ([>1.62] needed for publicVariableServer).
	 Parameters:
		- Server PVF.
*/

Private ["_func","_pvf"];

_pvf = _this;
_func = _pvf select 0;

_pvf set [0, Format["SRVFNC%1",_func]];

//--- LOCALITY/PV (g1606 2026-07-30): isHostedServer is FALSE on dedicated, so the old branch
//--- always publicVariableServer'd from the server. publicVariableServer never fires the SENDING
//--- machine's own PVEH - every server-originated Call WFBE_CO_FNC_SendToServer was a silent
//--- no-op (Common_OnUnitKilled for server-local AI, Common_FireArtillery CounterBattery, etc.).
//--- isServer covers dedicated + listen host; pure clients/HC still PVS.
if (isServer) then {
	_pvf Spawn WFBE_SE_FNC_HandlePVF;
} else {
	Call Compile Format ["WFBE_PVF_%1 = _pvf; publicVariableServer 'WFBE_PVF_%1';", _func];
};