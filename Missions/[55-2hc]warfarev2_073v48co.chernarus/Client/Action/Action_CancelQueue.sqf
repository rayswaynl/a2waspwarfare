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

private ["_building","_factory","_queu","_queuCosts","_queuCpts","_queuLabels","_uid","_idx","_paidCost","_cpt","_basePrice","_refund","_maxRefund","_newArr","_i","_uidPrefix"];

_building = _this select 0;               // object the action is attached to (the factory building)
_factory  = (_this select 3) select 0;   // params[0] = factory type string (e.g. "Barracks")

_uid = getPlayerUID player;
_queu      = _building getVariable ["queu",        []];
_queuCosts = _building getVariable ["queu_costs",  []];
_queuCpts  = _building getVariable ["queu_cpts",   []];
_queuLabels = _building getVariable ["queu_labels", []];

//--- A2-fix (2026-06-14): "token starts with UID" test. `string find string` is ARMA-3-only and
//--- throws "find: Type String, expected Array" on A2 OA (it fired every time a player cancelled a
//--- queue item). Compare leading bytes via toArray - same idiom as GUI_Menu_BuyUnits.sqf.
_uidPrefix = {
	private ["_tokA","_uidA","_ul","_ok","_j"];
	_tokA = toArray (_this select 0);
	_uidA = toArray (_this select 1);
	_ul = count _uidA;
	_ok = (_ul > 0) && (_ul <= count _tokA);
	if (_ok) then {
		for "_j" from 0 to (_ul - 1) do {
			if ((_tokA select _j) != (_uidA select _j)) exitWith {_ok = false};
		};
	};
	_ok
};

//--- Find the LAST entry belonging to this player (most recently queued = safest to cancel).
_idx = -1;
{
	if ([_x, _uid] call _uidPrefix) then {_idx = _forEachIndex};
} forEach _queu;

if (_idx == -1) exitWith {
	hint parseText "<t color='#ff9900'>You have no unit in this factory's queue.</t>";
};

//--- Extract stored data (parallel arrays; default to 0/1 if somehow missing).
_paidCost = if (_idx < count _queuCosts) then {_queuCosts select _idx} else {0};
_cpt      = if (_idx < count _queuCpts)  then {_queuCpts  select _idx} else {1};

//--- Compute actual refund with attack-wave cap.
_refund = _paidCost;
if (ATTACK_WAVE_PRICE_MODIFIER < 1.0 && UNIT_COST_MODIFIER > 0) then {
	_basePrice = _paidCost / (ATTACK_WAVE_PRICE_MODIFIER * UNIT_COST_MODIFIER);
	_maxRefund = round (_basePrice * 0.5);
	if (_refund > _maxRefund) then {_refund = _maxRefund};
};

//--- Remove entry from all three parallel arrays by index (costs/cpts may share values, must use index).
_queu = _queu - [_queu select _idx];          // queu tokens are unique; value-remove is safe here.
_newArr = []; _i = 0;
{if (_i != _idx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _queuCosts;
_queuCosts = _newArr;
_newArr = []; _i = 0;
{if (_i != _idx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _queuCpts;
_queuCpts = _newArr;
//--- Task 33: keep queu_labels in sync.
_newArr = []; _i = 0;
{if (_i != _idx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _queuLabels;
_queuLabels = _newArr;
_building setVariable ["queu",        _queu,       true];
_building setVariable ["queu_costs",  _queuCosts,  true];
_building setVariable ["queu_cpts",   _queuCpts,   true];
_building setVariable ["queu_labels", _queuLabels, true];

//--- Decrement queue counters (mirror normal-completion path).
unitQueu = unitQueu - _cpt;
if (unitQueu < 0) then {unitQueu = 0};
missionNamespace setVariable [
	Format ["WFBE_C_QUEUE_%1", _factory],
	((missionNamespace getVariable [Format ["WFBE_C_QUEUE_%1", _factory], 0]) - 1) max 0
];

//--- Issue refund.
if (_refund > 0) then {(_refund) Call ChangePlayerFunds};

//--- Feedback.
hint parseText Format [
	"<t color='#00e83e'>Queue cancelled.</t><br/>Refunded: <t color='#ffe066'>$%1</t>%2",
	_refund,
	if (_paidCost != _refund) then {Format [" (capped from $%1 — attack-wave discount)", _paidCost]} else {""}
];
