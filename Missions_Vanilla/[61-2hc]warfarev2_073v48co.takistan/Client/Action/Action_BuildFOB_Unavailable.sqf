/*
	Action_BuildFOB_Unavailable.sqf — GUER "Build FOB" unavailable-truck hint (fable/fob-wrong-truck-feedback).

	Added in Common\Init\Init_Unit.sqf alongside the real Build FOB action (Action_BuildFOB.sqf), on the SAME
	eligible truck classnames (WFBE_C_GUER_FOB_TRUCKS) but gated on the OPPOSITE of the wfbe_is_guer_fob flag, so
	the two addActions are mutually exclusive - never both visible on the same truck at once. Without this, a GUER
	player who captures a battlefield EAST truck sharing the same classname as a real FOB truck (the flag is only
	ever set when the truck is bought from the GUER Depot - Client_BuildUnit.sqf) saw NO scroll option and no hint
	at all: a silent dead end. This gives that player a menu entry explaining why instead of nothing.

	A2 OA 1.62/1.63 safe: array-form private only, no params/isEqualType, hintSilent/parseText.

	_this = [target(truck), caller(player), actionId, args]
*/
private ["_truck"];
_truck = _this select 0;

if (isNull _truck || {!alive _truck}) exitWith {};

hintSilent parseText "<t color='#FF6B6B'>Build FOB</t> - this truck can't build a FOB. Only a FOB truck bought from the GUER Depot works; a captured or other truck of the same type won't.";
