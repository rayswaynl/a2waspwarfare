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

private ["_building","_factory"];

_building = _this select 1;               // object the action is attached to (the factory building)
_factory  = (_this select 3) select 0;   // params[0] = factory type string (e.g. "Barracks")

//--- The factory queue is side-shared.  A client-side read/remove/write can overwrite a
//--- neighbour's concurrent purchase or cancellation, so the server owns the transaction and
//--- returns the exact accepted cpt/refund before this client adjusts its local HUD counter.
["RequestCancelQueue", [player, _building, _factory]] Call WFBE_CO_FNC_SendToServer;
