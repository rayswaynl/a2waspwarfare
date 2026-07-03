/*
	Get all of the camp from a town.
	 Parameters:
		- Town.
*/

Private ['_camps'];

_camps = _this getVariable "camps";
//--- cmdcon44-d (claude-gaming 2026-07-03): nil-safe. A town whose Init_Town server-block has not yet set "camps"
//--- (transplant race) returns nil here, and `count nil` THROWS - which poisoned the server_town.sqf capture-drain
//--- division (_rate came up Undefined -> town never drained -> ZERO flips on Zargabad). Treat nil as no-camps (1),
//--- identical to the existing empty-list branch. A2-OA-safe (isNil, no A3 commands).
if (isNil "_camps") exitWith {1};
if (count _camps == 0) exitWith {1};

count _camps