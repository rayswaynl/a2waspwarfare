/*
	Return the closest airport of the given entitie.
	 Parameters:
		- Object
*/

Private ["_closest","_near","_pos","_range","_hangar","_afSide"];

_closest = objNull;
_pos = _this select 0;
_range = _this select 1;

_near = _pos nearEntities [WFBE_Logic_Airfield, _range];
{_hangar = _x getVariable ["wfbe_hangar", objNull]; if !(isNil {_x getVariable "wfbe_hangar"}) then {if (alive _hangar) then {if (sideJoined == resistance) then {_afSide = _x getVariable ["wfbe_airfield_side", civilian]; if (_afSide == resistance) then {_closest = _x}} else {_closest = _x}}}} forEach _near;

//--- B74.2: naval carrier air-shop. A captured carrier (wfbe_is_naval_hvt depot logic) acts as an
//--- airfield: Init_NavalHVT spawns the same airfield hangar (wfbe_is_airfield_hangar) on it and sets
//--- wfbe_airfield_side. Treat such a logic exactly like a captured airfield so the existing buy-menu
//--- air-roster gate (GUI_Menu_BuyUnits) and the FSM hangarInRange check light up at the deck.
//--- Only checked when the normal airport scan found nothing (carriers are offshore, never overlapping
//--- a land airfield). Carriers are LocationLogicDepot, so a separate nearEntities scan is needed.
if (isNull _closest) then {
	private ["_nearN","_xn"];
	_nearN = _pos nearEntities [WFBE_Logic_Depot, _range];
	{
		_xn = _x;
		if ((_xn getVariable ["wfbe_is_naval_hvt", false]) && isNull _closest) then {
			_hangar = _xn getVariable ["wfbe_hangar", objNull];
			if (!isNull _hangar && {alive _hangar}) then {
				_afSide = _xn getVariable ["wfbe_airfield_side", civilian];
				//--- Same side-gate idiom as the airfield path: resistance only sees its own carrier;
				//--- WEST/EAST see any carrier whose hangar is present (capture re-spawns it per owner).
				if (sideJoined == resistance) then {
					if (_afSide == resistance) then {_closest = _xn};
				} else {
					if (_afSide == sideJoined) then {_closest = _xn};
				};
			};
		};
	} forEach _nearN;
};

_closest