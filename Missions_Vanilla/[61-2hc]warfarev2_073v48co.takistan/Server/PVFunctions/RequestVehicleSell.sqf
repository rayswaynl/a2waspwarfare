/*
	RequestVehicleSell.sqf -- server-side PVF handler (item #43 hardening).
	Sell-back of a player-purchased vehicle at base for a partial cash refund.

	The client (Client\Action\Action_VehicleSell.sqf) only REQUESTS the sale; no
	client-computed amount crosses the wire. Mirrors the RequestFundsTransfer
	server-revalidation pattern (N1 fix): the server is the sole arbiter of the refund.

	Parameters (sent via WFBE_CO_FNC_SendToServer):
	  0 - seller unit (object)
	  1 - vehicle (object)

	Validation (all server-authoritative):
	  - feature flag WFBE_C_VEHICLE_SELL > 0
	  - seller is a live player, physically near the vehicle
	  - vehicle alive, non-Man, crew empty
	  - vehicle carries the buy-time team tag (wfbe_buyteam, Client_BuildUnit.sqf)
	    and that team IS the seller's own team (derived server-side as group _seller)
	    - untagged hulls (AI/town/enemy) are not sellable
	  - seller is team leader, or the team is the side-commander team (same rule
	    the client action enforces)
	  - refund recomputed HERE from the price table (QUERYUNITPRICE), the sell
	    fraction and server-side hull damage; any client figure is display-only
*/

private ["_seller","_vehicle","_team","_buyTeam","_cmdTeam","_cls","_data","_price","_fraction","_damage","_refund","_vsellLatched"];

_seller  = _this select 0;
_vehicle = _this select 1;

if ((missionNamespace getVariable ["WFBE_C_VEHICLE_SELL", 1]) <= 0) exitWith {};

//--- Basic guards - the PVEH carries no trusted sender.
if (isNil "_seller") exitWith {};
if (isNil "_vehicle") exitWith {};
if (isNull _seller || {!alive _seller} || {!isPlayer _seller}) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected - seller [%1] is not a live player.", _seller]] Call WFBE_CO_FNC_LogContent;
};
if (isNull _vehicle || {!alive _vehicle} || {_vehicle isKindOf "Man"}) exitWith {};

//--- Physical reach: the client action only shows within addAction range; generous slack for big hulls.
if (_seller distance _vehicle > 100) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected for %1 - too far from [%2].", name _seller, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
};

//--- No selling an occupied hull (server-side re-check of the client gate).
if (count crew _vehicle > 0) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected for %1 - [%2] is occupied.", name _seller, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
};

//--- Ownership: only hulls tagged at buy time are sellable, and only by the team that
//--- bought them. Seller team is ALWAYS derived server-side; no client-named team.
_team = group _seller;
if (isNull _team) exitWith {};
_buyTeam = _vehicle getVariable "wfbe_buyteam";
if (isNil "_buyTeam" || {typeName _buyTeam != "GROUP"} || {isNull _buyTeam}) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected for %1 - [%2] carries no buy-team tag.", name _seller, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
};
if (_buyTeam != _team) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected for %1 - [%2] belongs to another team.", name _seller, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
};

//--- Authorization: team leader or side-commander team (same rule as the client action).
_cmdTeam = (side _team) Call WFBE_CO_FNC_GetCommanderTeam;
if (!(_seller == leader _team || (!isNull _cmdTeam && {_cmdTeam == _team}))) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected for %1 - not team leader or commander team.", name _seller]] Call WFBE_CO_FNC_LogContent;
};

//--- One-shot latch: reject a spammed duplicate request racing this handler instance
//--- between validation and delete (no double-credit). Check-and-set runs inside isNil {}
//--- (unscheduled in A2/OA, cannot interleave with a sibling spawned handler - Support_FPV.sqf
//--- idiom). isNil{} read form, NOT 2-arg default: a null object's 2-arg getVariable ignores
//--- the default (see Server_HandleEmptyVehicle.sqf).
_vsellLatched = false;
isNil {
	if (isNil {_vehicle getVariable "wfbe_vsell_done"}) then {
		_vehicle setVariable ["wfbe_vsell_done", true];
		_vsellLatched = true;
	};
};
if (!_vsellLatched) exitWith {};

//--- Server-recomputed refund: price table * sell fraction * hull health. No client figure is read.
_cls  = typeOf _vehicle;
_data = missionNamespace getVariable _cls;
if (isNil "_data" || {typeName _data != "ARRAY"} || {count _data <= QUERYUNITPRICE} || {typeName (_data select QUERYUNITPRICE) != "SCALAR"}) exitWith {
	["WARNING", Format ["RequestVehicleSell.sqf: [VSELL] rejected for %1 - no price data for [%2].", name _seller, _cls]] Call WFBE_CO_FNC_LogContent;
};
_price    = _data select QUERYUNITPRICE;
_fraction = (missionNamespace getVariable ["WFBE_C_VEHICLE_SELL_FRACTION", 0.5]) max 0;
_damage   = (getDammage _vehicle) max 0;
_refund   = round (_price * _fraction * ((1 - _damage) max 0));

if (_refund > 0) then {[_team, _refund] Call ChangeTeamFunds};

//--- Audit log - greppable VSELL tag - then remove the hull (server deleteVehicle of a
//--- client-local purchase is the long-shipping Server_HandleEmptyVehicle GC path).
["INFORMATION", Format ["RequestVehicleSell.sqf: [VSELL] side=%1 seller=%2 class=%3 price=%4 frac=%5 dmg=%6 refund=%7", str (side _team), name _seller, _cls, _price, _fraction, _damage, _refund]] Call WFBE_CO_FNC_LogContent;
deleteVehicle _vehicle;
