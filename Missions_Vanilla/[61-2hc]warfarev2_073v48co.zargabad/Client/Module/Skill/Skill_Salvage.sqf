private["_get","_hqs","_isNeeded","_overAllCost","_percentage","_playerSideID","_salvageCost","_salvagerRange","_salvageTruckTypes","_vehicles","_wrecks","_wreckSideID"];

WFBE_SK_V_LastUse_Salvage = time;

_salvagerRange = missionNamespace getVariable "WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE";
_percentage = missionNamespace getVariable "WFBE_C_UNITS_SALVAGER_SCAVENGE_RATIO";
_playerSideID = sideID;

//--- Trello #15: block engineer manual salvage when a FRIENDLY salvage truck is already in range
//--- (it auto-salvages via Client\FSM\updatesalvage.sqf). Reuse the per-side truck class list.
_salvageTruckTypes = missionNamespace getVariable [Format ["WFBE_%1SALVAGETRUCK", sideJoinedText], []];
if (((count _salvageTruckTypes) > 0) && {({ alive _x && (side _x == side player) } count (nearestObjects [getPos player, _salvageTruckTypes, _salvagerRange])) > 0}) exitWith {
	(localize "STR_WF_CHAT_Salvage_Truck_InRange") Call GroupChatMessage;
};

_vehicles = nearestObjects [getPos player, ['Car','Motorcycle','Ship','Air','Tank','StaticWeapon'],_salvagerRange];

_wrecks = [];
{
	if (!(alive _x) && {!(side _x == side player)}) then {_wrecks = _wrecks + [_x]};
} forEach _vehicles;

_hqs = [];
{_hqs = _hqs + [_x Call WFBE_CO_FNC_GetSideHQ]} forEach WFBE_PRESENTSIDES;

_wrecks = _wrecks - _hqs;

_overAllCost = 0;
{
	_wreckSideID = _x getVariable ["wfbe_side_id", -1];
	if (_wreckSideID < 0) then {_wreckSideID = _x getVariable ["sideID", -1]};
	_isNeeded = _x getVariable 'keepAlive';

	if ((isNil '_isNeeded') && {(_wreckSideID < 0) || {_wreckSideID != _playerSideID}}) then {
		_get = missionNamespace getVariable (typeOf _x);
		_salvageCost = 250;
		if !(isNil '_get') then {
			_salvageCost = round(((_get select QUERYUNITPRICE)*_percentage) / 100);
		};

		//--- Ka-137 reward nerf: salvaging a Ka-137 wreck (all PMC variants) yields only the coef (default 0.4) of normal.
		if ((_x isKindOf "Ka137_MG_PMC") || (_x isKindOf "Ka137_PMC")) then {
			_salvageCost = round(_salvageCost * (missionNamespace getVariable ["WFBE_C_KA137_REWARD_COEF", 0.4]));
		};

		_overAllCost = _overAllCost + _salvageCost;
		(Format [localize 'STR_WF_CHAT_Salvaged_Unit',_salvageCost,[typeOf _x,'displayName'] Call GetConfigInfo]) Call GroupChatMessage;

		deleteVehicle _x;
	};
} foreach _wrecks;

if (_overAllCost > 0) then {(_overAllCost) Call ChangePlayerfunds};
