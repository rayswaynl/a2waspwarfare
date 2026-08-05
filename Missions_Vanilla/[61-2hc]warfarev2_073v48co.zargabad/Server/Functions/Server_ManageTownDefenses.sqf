/*
	Manage or spawn defenses in a town if needed.
	 Parameters:
		- Town.
		- Side.
*/

Private ["_defense","_defs","_gunner","_op","_side","_side_old","_sideID","_spawn","_town"];

_town = _this select 0;
_side = _this select 1;
_sideID_old = _this select 2;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;

//--- r80: nil/non-array town defenses must not throw on forEach (aborts whole side-flip AA rebuild).
_defs = _town getVariable ["wfbe_town_defenses", []];
if (isNil "_defs" || {typeName _defs != "ARRAY"}) exitWith {
	["WARNING", Format ["Server_ManageTownDefenses.sqf: Town [%1] wfbe_town_defenses missing/non-array - manage aborted.", _town getVariable ["name","?"]]] Call WFBE_CO_FNC_LogContent;
};

//--- Browse all the defenses of the town.
{
	_defense = _x getVariable "wfbe_defense";
	_spawn = false;
	if (isNil '_defense') then {
		_spawn = true;
	} else {
		if (!alive _defense || _sideID_old != _sideID) then { //--- Remove if non-null.
			//--- r80 AA site lifecycle: deman AI gunner/operator BEFORE hull delete so side-flip
			//--- does not leave orphan AA crew (or fail-clean partial statics).
			if !(isNull _defense) then {
				_gunner = gunner _defense;
				if (!(isNull _gunner) && {alive _gunner} && {isNil {(group _gunner) getVariable "wfbe_funds"}}) then {
					if (local _gunner) then {deleteVehicle _gunner} else {[_gunner, "HandleSpecial", ["cleanup-town-defense-gunner", _gunner, "manage-sideflip"]] Call WFBE_CO_FNC_SendToClient};
				};
				_op = _x getVariable "wfbe_defense_operator";
				if (!(isNil "_op") && {!isNull _op} && {alive _op} && {_op != _gunner}) then {
					if (local _op) then {deleteVehicle _op} else {[_op, "HandleSpecial", ["cleanup-town-defense-gunner", _op, "manage-sideflip-op"]] Call WFBE_CO_FNC_SendToClient};
				};
				_x setVariable ["wfbe_defense_operator", nil];
				deleteVehicle _defense;
			};
			_spawn = true;
		};
	};
	
	if (_spawn) then { //--- Spawn a defense according to the types (if it exists).
		[_x, _side] Call WFBE_SE_FNC_SpawnTownDefense;
	};
} forEach _defs;
//--- AI2: town-mortar checkup removed. The feature was never wired -- no town ever set "wfbe_town_mortars", and Server_SpawnTownMortars.sqf had no compile registration (orphan, deleted).