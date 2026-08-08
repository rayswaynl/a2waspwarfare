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
if (!isNil "_destination" && {typeName _destination == "SIDE"}) then { //--- LIVE HOTFIX wave0808b (2026-08-08): 54 call sites pass nil as the legacy broadcast destination, and on A2OA typeName on a NIL local is a hard error - the whole statement died and the packet was NEVER sent (town/camp captures, dashboard + restart announces, base-area JIP sync, ICBM countdown all silently dropped; RPT: 17x undefined _destination in the first 21 min of the first wave0808a match). isNil must be checked BEFORE typeName; nil now falls through to the else branch = the legacy global publicVariable, exactly the scope the r212 rewrite documented for nil routes.
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
