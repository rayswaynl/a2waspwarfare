/*
	Client/Action/Action_VehicleSell.sqf  [item #43]
	Sell a player-purchased vehicle for a cash refund (WFBE_C_VEHICLE_SELL).
	Called via addAction on non-Man vehicles; addAction is LOCAL (buyer-time only).
	Authorization: team leader of buying team OR side commander (commanderTeam == clientTeam).
	Proximity gate: player must be near a factory / depot (lightInRange / heavyInRange /
	                depotInRange / aircraftInRange / hangarInRange).
	Refund = round(QUERYUNITPRICE * WFBE_C_VEHICLE_SELL_FRACTION * max(0, 1 - getDammage)).
	Refund shown here is DISPLAY-ONLY; the credit + delete are server-authoritative via the
	RequestVehicleSell PVF (server recomputes price/fraction/damage; no client amount is trusted).
	A2-OA-1.64 safe: no pushBack/isEqualType/findIf/params; getDammage double-m; private [] form.
*/
private ["_vehicle","_cls","_data","_price","_fraction","_damage","_refund","_key","_msg"];

if ((missionNamespace getVariable ["WFBE_C_VEHICLE_SELL", 1]) <= 0) exitWith {};

_vehicle = _this select 0;
if (isNull _vehicle || !alive _vehicle) exitWith {};

//--- Re-check crew (addAction condition string gates this, but re-check to handle the window between clicks).
if (count crew _vehicle > 0) exitWith {
	uiNamespace setVariable ["wfbe_confirm_key", ""];
	uiNamespace setVariable ["wfbe_confirm_time", -1000];
	hintSilent "";
	hint "Cannot sell: vehicle is occupied.";
};

//--- Re-check proximity.
if (!(lightInRange || heavyInRange || depotInRange || aircraftInRange || hangarInRange)) exitWith {
	uiNamespace setVariable ["wfbe_confirm_key", ""];
	uiNamespace setVariable ["wfbe_confirm_time", -1000];
	hintSilent "";
	hint "Must be near a base factory or depot to sell.";
};

//--- Re-check authorization: team leader or side commander.
if !(player == leader clientTeam || (!isNull commanderTeam && {commanderTeam == clientTeam})) exitWith {};

//--- Look up base price from missionNamespace unit-data tuple (keyed by classname; nil for non-bought vehicles).
_cls  = typeOf _vehicle;
_data = missionNamespace getVariable _cls;
if (isNil "_data") exitWith {hint "Cannot determine sell price for this vehicle type."};

_fraction = (missionNamespace getVariable ["WFBE_C_VEHICLE_SELL_FRACTION", 0.5]) max 0;
_damage   = (getDammage _vehicle) max 0;
_price    = _data select QUERYUNITPRICE;
_refund   = round (_price * _fraction * ((1 - _damage) max 0));

//--- Two-click confirm (WFBE_CL_FNC_ConfirmAction: returns true only on the second call within 6s).
_key = format ["wfbe_vsell_%1", _vehicle];
_msg = format ["<t color='#ff5a5a' size='1.1'>Sell %1?</t><br/>Refund <t color='#76f563'>$%2</t> (%3%% health). Activate again to confirm.",
	getText (configFile >> "CfgVehicles" >> _cls >> "displayName"),
	_refund,
	round ((1 - _damage) * 100)
];

if (!([_key, _msg] call WFBE_CL_FNC_ConfirmAction)) exitWith {};

//--- Confirmed: final sanity checks.
if (!alive _vehicle) exitWith {};
if (count crew _vehicle > 0) exitWith {hint "Vehicle sell cancelled: crew boarded during confirm."};

//--- Server-authoritative sell (item #43 hardening): the server recomputes the refund from its
//--- own price table / sell fraction / damage, revalidates crew, ownership and authorization,
//--- credits the buying team and deletes the vehicle (Server\PVFunctions\RequestVehicleSell.sqf).
//--- _refund above is DISPLAY-ONLY (confirm dialog); no client-computed amount crosses the wire.
["RequestVehicleSell", [player, _vehicle]] Call WFBE_CO_FNC_SendToServer;
diag_log format ["WFBE|VEHICLE_SELL_REQ|side=%1|class=%2|refund_est=%3", str sideJoined, _cls, _refund];
