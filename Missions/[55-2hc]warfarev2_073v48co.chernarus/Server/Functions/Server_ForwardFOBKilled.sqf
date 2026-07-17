/*
	Server_ForwardFOBKilled.sqf - Forward FOB tent 'killed' handler (flag WFBE_C_STRUCTURES_FOB).

	Attached to the tent in Server\PVFunctions\RequestForwardFOB.sqf. The tent IS the FOB: forward respawn,
	gear resupply and the repair bubble all key on `alive (campLogic getVariable "wfbe_camp_bunker")`, so they
	collapse on their own the tick it dies - this handler owns the rest of the teardown.

	It deletes the camp logic straight away rather than after a delay. That is deliberate: it stops
	nearEntities returning a dead camp, and it closes the Action_RepairCamp.sqf resurrect path, which selects
	ANY in-range camp logic whose bunker is dead with no side check - i.e. an ENEMY repair truck could
	otherwise rebuild our $25k FOB as a WFBE_C_CAMP watchtower and flip it to their side via the
	Server_HandleSpecial.sqf:1341 "repair-camp" branch. v1 rule: a destroyed FOB is rebuilt from a new repair
	truck (OWNER CORRECTION 2026-07-17: was "supply truck"), not field-repaired. (Field repair is a
	phase-2 candidate - it needs its own side gate first.)

	A2 OA 1.64 safe: array-form private only, no params/pushBack, no exitWith inside forEach.

	_this = [tent(structure), killer]
*/
private ["_tent","_side","_logic","_antenna","_sideKey","_reg","_keep","_mk"];

_tent = _this select 0;
if (isNull _tent) exitWith {};

_side    = _tent getVariable ["wfbe_side", sideUnknown];
_logic   = _tent getVariable ["wfbe_fob_logic", objNull];
_antenna = _tent getVariable ["wfbe_fob_antenna", objNull];

//--- Drop the side-scoped proximity marker (same deterministic name the worker builds).
_mk = Format ["wfbe_fob_ping_%1_%2", floor ((getPos _tent) select 0), floor ((getPos _tent) select 1)];
[_side, "WildcardMarker", ["delete", _mk]] Call WFBE_CO_FNC_SendToClients;

//--- Kill the camp contract immediately - no dead-bunker window for Action_RepairCamp to grab.
if (!isNull _logic) then {deleteVehicle _logic};

//--- Registry + broadcast cap count (frees the slot for a rebuild).
_sideKey = Format ["WFBE_FOB_%1", str _side];
_reg  = missionNamespace getVariable [_sideKey, []];
_keep = [];
{if (!isNull _x && {alive _x} && {_x != _tent}) then {_keep = _keep + [_x]}} forEach _reg;
missionNamespace setVariable [_sideKey, _keep];
missionNamespace setVariable [Format ["%1_COUNT", _sideKey], count _keep];
publicVariable Format ["%1_COUNT", _sideKey];

["INFORMATION", Format ["Server_ForwardFOBKilled.sqf: [%1] Forward FOB destroyed. Alive now %2.", str _side, count _keep]] Call WFBE_CO_FNC_LogContent;

[_side, "Destroyed", ["Base", _tent]] Spawn SideMessage;

//--- Same wreck-removal delay every other structure gets (Server_BuildingKilled.sqf tail).
sleep 10;
if (!isNull _antenna) then {deleteVehicle _antenna};
if (!isNull _tent) then {deleteVehicle _tent};
