/*
	Skill_Bulldoze.sqf — Engineer bulldozer: slow-roll tree clearing inside a friendly base area.

	ENGINE NOTE (deferred): in-engine verification that setDamage 1 actually fells A2 terrain trees
	and that fallen trunks sync to JIP is DEFERRED to the integration smoke test.  The worst-case
	outcome of the engine refusing setDamage (unknown object type) is benign: the charge-ordering
	block only deducts supply AFTER confirming getDammage >= 1, so a tree that doesn't fall costs
	nothing.

	Launched from Client\Functions\Client_BuildUnit.sqf, mirroring the updatesalvage.sqf pattern
	for repair/salvage-class trucks.  _this select 0 = the spawned vehicle object.

	Parameters:
		- _this select 0 : vehicle (repair/salvage truck)
*/

private ["_veh","_baseRange","_inBase","_trees","_s","_side","_startPos","_baseAreas","_centers",
         "_nearBase","_candidates","_tree","_isTree","_upgrades","_barrackLvl"];

_veh = _this select 0;

// Gate: feature must be enabled.
if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) == 0) exitWith {};

// Gate: local client must be an Engineer.
if (WFBE_SK_V_Type != "Engineer") exitWith {};

_baseRange = missionNamespace getVariable ["WFBE_C_BASE_AREA_RANGE", 250];

// One-time activation hint.
hintSilent "Bulldozer active: slow roll inside base to clear trees — 10 supply each.";

while {alive _veh} do {

	if (!(isNull (driver _veh)) && {driver _veh == player} && {!gameOver}) then {

		// Speed gate: ~12 km/h → ~3.3 m/s.  abs(speed) is in km/h in A2.
		if (abs (speed _veh) < 12) then {

			// Client-side base-area proximity check.
			// Reuse the same mechanism used in Init_Client.sqf and coin_interface.sqf:
			//   WFBE_Client_Logic getVariable "wfbe_basearea"  → array of area logic objects
			//   WFBE_Client_Logic getVariable "wfbe_startpos"  → start-position object/pos
			_baseAreas = WFBE_Client_Logic getVariable ["wfbe_basearea", []];
			_startPos   = WFBE_Client_Logic getVariable ["wfbe_startpos", objNull];

			_centers = [];
			if !(isNull _startPos) then { _centers = _centers + [getPos _startPos] };
			{_centers = _centers + [getPos _x]} forEach _baseAreas;

			_inBase = false;
			{
				if ((getPos _veh) distance _x < _baseRange) exitWith { _inBase = true };
			} forEach _centers;

			if (_inBase) then {

				// Barracks gate (client-side pre-check — prevents request spam before Barracks 1).
				// Mirrors Server_CounterBattery.sqf pattern: side logic → wfbe_upgrades → WFBE_UP_BARRACKS.
				// WFBE_CO_FNC_GetSideUpgrades reads wfbe_upgrades from the side logic; WFBE_UP_BARRACKS = 0.
				_upgrades = sideJoined Call WFBE_CO_FNC_GetSideUpgrades;
				_barrackLvl = 0;
				if (!(isNil "_upgrades") && {count _upgrades > WFBE_UP_BARRACKS}) then {
					_barrackLvl = _upgrades select WFBE_UP_BARRACKS;
				};

				if (_barrackLvl >= 1) then {

				// Detect nearby terrain trees.
				// nearestObjects in A2 returns terrain objects within range.
				// str of a terrain object yields e.g. "123456: t_picea2s.p3d" — we match
				// on ": t_" (dominant Chernarus prefix) and ": str_" (legacy models).
				// Bushes (prefix "b_") are excluded intentionally (v1: trees only).
				// A2OA string find works on substrings; no select[start] needed.
				_candidates = nearestObjects [getPos _veh, [], 8];

				{
					_tree = _x;
					_isTree = false;

					if (getDammage _tree < 1) then {
						_s = str _tree;
						if ((_s find ": t_") >= 0 || {(_s find ": str_") >= 0}) then {
							_isTree = true;
						};
					};

					if (_isTree) then {
						// Send to server for validated fell + supply deduction.
						// Pattern: [funcName, params] Call WFBE_CO_FNC_SendToServer
						// (mirrors every other client→server call in Client\*)
						["RequestBulldoze", [_tree, _veh, player]] Call WFBE_CO_FNC_SendToServer;
					};
				} forEach _candidates;

				}; // _barrackLvl >= 1
			}; // _inBase
		}; // speed gate
	}; // driver check

	sleep 2;
};
