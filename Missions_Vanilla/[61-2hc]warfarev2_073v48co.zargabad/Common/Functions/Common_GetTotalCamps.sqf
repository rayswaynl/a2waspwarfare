/*
	Get all of the camp from a town.
	 Parameters:
		- Town.
*/

Private ['_camps','_total'];

_camps = _this getVariable "camps";
//--- cmdcon44-d (claude-gaming 2026-07-03): nil-safe. A town whose Init_Town server-block has not yet set "camps"
//--- (transplant race) returns nil here, and `count nil` THROWS - which poisoned the server_town.sqf capture-drain
//--- division (_rate came up Undefined -> town never drained -> ZERO flips on Zargabad). Treat nil as no-camps (1),
//--- identical to the existing empty-list branch. A2-OA-safe (isNil, no A3 commands).
if (isNil "_camps") exitWith {1};
if (count _camps == 0) exitWith {1};

//--- fable/camp-null-count (owner live ZG deadlock 2026-07-19): count only LIVE camp logics -
//--- mirroring GetTotalCampsOnSide's own !isNull guard. A camp logic DELETED mid-match (the
//--- cmdcon44q class of loss; deletion source still unidentified) previously stayed in THIS total
//--- while it could never be counted for any side, so every consumer that compares
//--- Total == OnSide (server_town.sqf:275-281 capture gate, Common_GetRespawnThreeway camp-spawn
//--- eligibility, BuyUnits UI) deadlocked FOREVER on that town, and a deleted logic is also
//--- unrepairable (Action_RepairCamp finds camps via nearEntities on the logic). Counting only
//--- non-null camps makes a deleted camp SHRINK the requirement instead of wedging it.
//--- Floor of 1 preserved (matches the nil/empty branches) so the server_town.sqf:295 capture-rate
//--- division can never hit zero even if EVERY logic in a town is lost.
_total = 0;
{if (!isNull _x) then {_total = _total + 1}} forEach _camps;
if (_total == 0) exitWith {1};

_total