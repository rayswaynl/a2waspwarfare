/*
	Send a PVF to one client.
	 Parameters:
		- Client PVF.
*/

Private ["_func","_id","_pvf"];

_pvf = _this;
_func = _pvf select 1;
_id = owner (_pvf select 0);

_pvf set [0, getPlayerUID (_pvf select 0)];
_pvf set [1, Format["CLTFNC%1",_func]];

// Guard: owner() returns 0 when the target HC has disconnected or its unit's
// locality transferred to the server. publicVariableClient with id 0 produces
// "Message not sent - error 0 ID=ffffffff" in the RPT on every call.
// Valid remote client ids are always > 0 (dedicated server own id = 2, clients >= 3).
// We drop only the id=0 case; any id > 0 is a real network peer and must be sent.
// The local hosted-server Spawn path is unaffected by this guard.
if (!isHostedServer) then {
	if (_id > 0) then {
		Call Compile Format ["WFBE_PVF_%1 = _pvf; _id publicVariableClient 'WFBE_PVF_%1';", _func];
	} else {
		//--- OBSERVABILITY (2026-07-17, HC-founding zombie-picker): this drop was previously silent -
		//--- no RPT trace on either the server or the (never-reached) target HC, which is why the
		//--- delegate-aicom-team pipeline break was invisible to RPT archaeology. Correctness-neutral
		//--- (still drops exactly as before); only adds a trace so a future zero-owner drop is provable.
		diag_log (Format ["SENDTOCLIENT|v1|DROPPED|func=%1|owner=0-or-negative", _func]);
	};
} else {
	_pvf Spawn WFBE_CL_FNC_HandlePVF;
	if (isMultiplayer) then {
		if (_id > 0) then {Call Compile Format ["WFBE_PVF_%1 = _pvf; _id publicVariableClient 'WFBE_PVF_%1';", _func]};
	};
};