/*
	LS_Tickets.sqf — Last Stand co-op ticket system (ISOLATED; touches no existing systems).
	Server-side. Decrements LS_Tickets on WEST player death so the mode can be LOST
	(LS_WaveManager's loop ends when LS_Tickets reaches 0).
	Mechanism: poll for WEST players and attach an MPKilled EH to each fresh player object
	(re-attaches after respawn, since respawn creates a NEW object). Counts DEATHS, not
	spawns, so the initial spawn is never miscounted. Worst case (EH never fires) = the
	mode is simply unloseable, never broken. A2-dialect (no select{}/pushBack/params[/inline-private).
*/
if (!isServer) exitWith {};
waitUntil {!isNil "LS_Tickets"};
diag_log "[WFBE-LS] LS_Tickets.sqf: WEST-death ticket watcher started.";

while {!WFBE_GameOver && {LS_Tickets > 0}} do {
	{
		if (isPlayer _x && {side _x == west} && {isNil {_x getVariable "LS_killEH"}}) then {
			_x setVariable ["LS_killEH", true];
			_x addMPEventHandler ["MPKilled", {
				if (isServer && {!isNil "LS_Tickets"} && {LS_Tickets > 0} && {IS_laststand_event}) then {
					LS_Tickets = LS_Tickets - 1;
					publicVariable "LS_Tickets";
					diag_log Format ["[WFBE-LS] WEST player down - ticket lost. Remaining: %1", LS_Tickets];
				};
			}];
		};
	} forEach allUnits;
	sleep 3;
};
