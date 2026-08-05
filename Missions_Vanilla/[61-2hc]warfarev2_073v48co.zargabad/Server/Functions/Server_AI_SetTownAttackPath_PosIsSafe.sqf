/*
	Define whether a location is safe or not for the ai to move on.
	 Parameters:
		- Position.
		- Side ID.
		- Town.

	r78b: fail-clean short/malformed args, non-array position, non-scalar sideID, null town
	before surfaceIsWater / nearEntities / sideID compare.
*/

Private ["_hostile","_safe","_sid","_town","_towns","_wp_sel_pos"];

//--- r78b: arity/type. Returning false (unsafe) matches PathIsSafe fail-closed policy.
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 3}) exitWith {false};

_wp_sel_pos = _this select 0;
_sid = _this select 1;
_town = _this select 2;

if (isNil "_wp_sel_pos" || {typeName _wp_sel_pos != "ARRAY"} || {count _wp_sel_pos < 2}) exitWith {false};
if (isNil "_sid" || {typeName _sid != "SCALAR"}) exitWith {false};
//--- Town may be deleted between dispatch and hop evaluation; treat as unsafe node.
if (isNil "_town" || {typeName _town != "OBJECT"} || {isNull _town}) exitWith {false};

_safe = false;
if !(surfaceIsWater _wp_sel_pos) then {
	_towns = (_wp_sel_pos nearEntities [["LocationLogicCity"], 550]) - [_town];
	if (count _towns == 0) then {
		_safe = true
	} else {
		//--- r78b: sideID on a town logic can be nil/non-scalar during init or after capture race;
		//--- bare != would treat nil as "hostile" forever (blocks all hops near that town).
		//--- Only count towns with a numeric sideID that differs from the attacker.
		_hostile = {
			private ["_tsid"];
			_tsid = _x getVariable "sideID";
			(!isNil "_tsid" && {typeName _tsid == "SCALAR"} && {_tsid != _sid})
		} count _towns;
		if (_hostile == 0) then {_safe = true};
	};
};

_safe
