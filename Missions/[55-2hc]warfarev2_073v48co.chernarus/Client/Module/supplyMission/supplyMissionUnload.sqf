private ["_associatedSupplyTruck","_candidate","_cash","_cc","_cp","_dx","_dy","_friendlyCommandCenterInProximity","_i","_loadedHelis","_needsLookup","_ok","_vp"];

_associatedSupplyTruck = vehicle player;
if (_associatedSupplyTruck == player) then {_associatedSupplyTruck = cursorTarget};

_needsLookup = false;
if (isNull _associatedSupplyTruck) then {_needsLookup = true};
if (!_needsLookup) then {
	if !((typeOf _associatedSupplyTruck) in WFBE_C_SUPPLY_HELI_TYPES) then {_needsLookup = true};
};
if (!_needsLookup) then {
	if !(_associatedSupplyTruck getVariable ["SupplyByHeli", false]) then {_needsLookup = true};
};
if (!_needsLookup) then {
	if ((_associatedSupplyTruck getVariable ["SupplyAmount", 0]) <= 0) then {_needsLookup = true};
};

if (_needsLookup) then {
	_loadedHelis = nearestObjects [player, WFBE_C_SUPPLY_HELI_TYPES, 30];
	_associatedSupplyTruck = objNull;
	{
		_candidate = _x;
		if ((typeOf _candidate) in WFBE_C_SUPPLY_HELI_TYPES) then {
			if (_candidate getVariable ["SupplyByHeli", false]) then {
				if ((_candidate getVariable ["SupplyAmount", 0]) > 0) exitWith {
					_associatedSupplyTruck = _candidate;
				};
			};
		};
	} forEach _loadedHelis;
};

if (isNull _associatedSupplyTruck) exitWith {format ["No loaded supply helicopter selected."] call GroupChatMessage};
if !((typeOf _associatedSupplyTruck) in WFBE_C_SUPPLY_HELI_TYPES) exitWith {format ["UNLOAD SUPPLIES only works with loaded supply helicopters."] call GroupChatMessage};
if !(_associatedSupplyTruck getVariable ["SupplyByHeli", false]) exitWith {format ["This helicopter is not carrying helicopter supplies."] call GroupChatMessage};
if ((_associatedSupplyTruck getVariable ["SupplyAmount", 0]) <= 0) exitWith {format ["This helicopter is not carrying supplies."] call GroupChatMessage};

_friendlyCommandCenterInProximity = false;
{
	if (_x isKindOf "Base_WarfareBUAVterminal") then {
		_vp = getPos _associatedSupplyTruck;
		_cp = getPos _x;
		_dx = (_vp select 0) - (_cp select 0);
		_dy = (_vp select 1) - (_cp select 1);
		if (((_dx * _dx) + (_dy * _dy)) < 6400) then {_friendlyCommandCenterInProximity = true};
	};
} forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 400]);

if (!_friendlyCommandCenterInProximity) exitWith {format ["Land or hover within 80m horizontal distance of your Command Center to unload supplies."] call GroupChatMessage};

["INFORMATION", Format ["SupplyMissionUnload.sqf: Player %1 started helicopter unload timer for %2.", name player, _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
_ok = true;
_i = 0;
while {_i < WFBE_C_SUPPLY_HELI_UNLOAD_TIME} do {
	if (!alive _associatedSupplyTruck) exitWith {_ok = false};
	if (((getPos _associatedSupplyTruck) select 2) > 35) exitWith {_ok = false};
	titleText [format ["Unloading supplies at the Command Center... %1 / %2 s", _i, WFBE_C_SUPPLY_HELI_UNLOAD_TIME], "PLAIN DOWN", 0.05];
	sleep 1;
	_i = _i + 1;
};

if (!_ok) exitWith {
	["INFORMATION", Format ["SupplyMissionUnload.sqf: Player %1 helicopter unload cancelled for %2.", name player, _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
	format ["Supply unload cancelled. Keep the helicopter alive and low over the Command Center."] call GroupChatMessage;
};

["INFORMATION", Format ["SupplyMissionUnload.sqf: Player %1 requested helicopter unload for %2.", name player, _associatedSupplyTruck]] Call WFBE_CO_FNC_LogContent;
WFBE_Server_PV_SupplyMissionCompleted = [player, _associatedSupplyTruck, sideJoined];
publicVariableServer "WFBE_Server_PV_SupplyMissionCompleted";
