/*
	Action_CancelQueue.sqf
	Called via addAction on a factory building.
	Cancels the calling player's last not-yet-spawned queued unit and issues a refund.

	Refund rule:
	  - Normal: refund the price paid at order time (stored in queu_costs).
	  - Attack-wave active (ATTACK_WAVE_PRICE_MODIFIER < 1.0): cap refund at 50% of BASE price.
	    Base price = paid_price / (ATTACK_WAVE_PRICE_MODIFIER * UNIT_COST_MODIFIER).
	    The cap is a DEFENSIVE CEILING and does not trigger in standard config (the refund
	    never exceeds the amount paid, so no arbitrage exists at normal ATTACK_WAVE_PRICE_MODIFIER
	    values). It is kept as a safeguard against future config edge cases.
*/

private ["_building","_factory","_args"];

//--- addAction _this = [target, caller, id, args]. Target is the factory (not the caller).
//--- Lost fix 4aaafe2dea (select 0) never landed on master; select 1 always no-op'd cancel/refund.
if (typeName _this != "ARRAY" || {count _this < 4}) exitWith {};
_building = _this select 0;
if (isNull _building || {!alive _building}) exitWith {};
_args = _this select 3;
if (typeName _args != "ARRAY" || {count _args < 1}) exitWith {};
_factory = _args select 0;
if (typeName _factory != "STRING" || {_factory == ""}) exitWith {};

//--- The factory queue is side-shared.  A client-side read/remove/write can overwrite a
//--- neighbour's concurrent purchase or cancellation, so the server owns the transaction and
//--- returns the exact accepted cpt/refund before this client adjusts its local HUD counter.
["RequestCancelQueue", [player, _building, _factory]] Call WFBE_CO_FNC_SendToServer;
