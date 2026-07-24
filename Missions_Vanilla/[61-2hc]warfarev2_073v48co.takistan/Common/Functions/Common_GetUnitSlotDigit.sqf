Private ["_unit","_live","_i"];

_unit = _this;

if (_unit == leader (group _unit)) exitWith {"Leader"};

//--- Flag WFBE_C_MARKER_SLOT_DIGIT (default 0): marker/command-bar slot alignment.
//--- 0 = legacy GetAIDigit (engine str-colon CREATION-order id) - byte-identical to HEAD.
//--- >0 = the unit's live COMMAND-BAR slot: 1-based index among the ALIVE members of its
//---      group in `units` order. The A2 bottom group bar renders units in `units`-array
//---      order (live probe wave0723d: units index 0 -> bar #1, index 1 -> bar #2), so this
//---      makes the player's own-squad map-marker number track the F-key command-bar slot,
//---      which the creation-order id diverges from after any group churn (death/buy/rejoin).
//--- A2-OA-1.64-safe: array `find` (GetAIDigit already uses array find), `str`, `units`.
if ((missionNamespace getVariable ["WFBE_C_MARKER_SLOT_DIGIT", 0]) <= 0) exitWith {_unit Call GetAIDigit};

_live = (units group _unit) Call GetLiveUnits;
_i = _live find _unit;
if (_i < 0) exitWith {_unit Call GetAIDigit};

str (_i + 1)
