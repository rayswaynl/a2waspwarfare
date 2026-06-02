//============================================================================
//  [CLAUDE FEATURE - REMOVABLE]   Warlord Hunt  -  Zargabad mechanic #2
//  ---------------------------------------------------------------------------
//  Periodically a Takistani warlord (HVT) plus a small guard detail appears at a
//  random town and is flagged on everyone's map. Whichever side (WEST or EAST)
//  kills the warlord earns a funds bounty for their commander. If nobody kills
//  him within the window he slips away (no reward). A risk/reward side-objective
//  that pulls fights toward a shifting point on the map.
//
//  Server-only. Reuses the mission's resistance roster (TK_GUE_*) + the
//  commander-economy (WFBE_CLAUDE_FNC_GiveFunds, defined in Claude_Features_Init).
//  Toggle:  WFBE_C_CLAUDE_WARLORD_ENABLED  (default 1)
//  Remove:  delete this file + its line in Claude_Features_Init.sqf.
//  Arma 2 OA SQF only (no remoteExec / no `select {}` / no while-loop exitWith). ~95 LOC.
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLAUDE_WARLORD_ENABLED", 1]) <= 0) exitWith {};

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};
waitUntil {!isNil "towns" && {count towns > 0}};

#define WL_BOUNTY 9000
WFBE_CLAUDE_WL_GUARDS = ["TK_GUE_Soldier_AR_EP1","TK_GUE_Soldier_MG_EP1","TK_GUE_Soldier_AT_EP1","TK_GUE_Soldier_EP1"];

sleep (240 + random 240);   //--- first warlord 4-8 min in

while {true} do {
	if ((missionNamespace getVariable ["WFBE_C_CLAUDE_WARLORD_ENABLED", 1]) > 0) then {
		//--- pick a random initialised town (A2 has no `select {}` filter -> forEach)
		private ["_pool","_town","_pos"];
		_pool = [];
		{ if (!isNil {_x getVariable "supplyValue"}) then { _pool = _pool + [_x] } } forEach towns;
		if (count _pool > 0) then {
			_town = _pool select (floor random count _pool);
			_pos  = getPos _town;

			//--- spawn the warlord on independent/resistance (enemy to W and E in WFBE's 3-way war)
			private ["_grp","_wl"];
			_grp = createGroup resistance;
			_wl  = _grp createUnit ["TK_GUE_Warlord_EP1", _pos, [], 6, "FORM"];

			if (!isNull _wl) then {
				private ["_g","_gpos","_mk","_t"];
				_wl allowFleeing 0;
				_wl setVariable ["wfbe_claude_warlord", true, true];
				//--- guard detail around him
				{
					_gpos = [(_pos select 0) + (12 - random 24), (_pos select 1) + (12 - random 24), 0];
					_g = _grp createUnit [_x, _gpos, [], 4, "FORM"];
				} forEach WFBE_CLAUDE_WL_GUARDS;
				_grp setBehaviour "AWARE"; _grp setCombatMode "RED"; _grp setSpeedMode "LIMITED";
				(units _grp) doFollow _wl;

				//--- global map marker (createMarker is broadcast in A2)
				_mk = createMarker ["WFBE_Claude_Warlord", _pos];
				_mk setMarkerType "mil_warning"; _mk setMarkerColor "ColorRed"; _mk setMarkerText "Warlord (bounty)";

				//--- bounty to whichever side lands the kill
				_wl addEventHandler ["Killed", {
					private ["_killer","_side"];
					_killer = _this select 1;
					if (!isNull _killer) then {
						_side = side _killer;
						if (_side in [west,east]) then {
							[_side, WL_BOUNTY] call WFBE_CLAUDE_FNC_GiveFunds;
							["INFORMATION", format ["Claude_Warlord.sqf: %1 killed the Warlord -> %2 funds bounty.", _side, WL_BOUNTY]] call WFBE_CO_FNC_LogContent;
						};
					};
				}];
				["INFORMATION", format ["Claude_Warlord.sqf: A Warlord surfaced near %1 - kill him for a %2 bounty.", _town getVariable "name", WL_BOUNTY]] call WFBE_CO_FNC_LogContent;

				//--- wait for the kill or the escape window (~7 min)
				_t = 0;
				while {(!isNull _wl) && (alive _wl) && (_t < 420)} do { sleep 5; _t = _t + 5 };
				if (!isNull _wl && {alive _wl}) then {
					["INFORMATION", format ["Claude_Warlord.sqf: The Warlord near %1 slipped away.", _town getVariable "name"]] call WFBE_CO_FNC_LogContent;
				};
				deleteMarker _mk;
				sleep 30;   //--- let the moment land before the detail despawns
				{ if (!isNull _x) then { deleteVehicle _x } } forEach (units _grp);
			} else {
				deleteGroup _grp;   //--- class missing -> skip this cycle, keep the loop alive
			};
			if (!isNull _grp) then { deleteGroup _grp };
		};
	};
	sleep (600 + random 480);   //--- 10-18 min between warlords
};
