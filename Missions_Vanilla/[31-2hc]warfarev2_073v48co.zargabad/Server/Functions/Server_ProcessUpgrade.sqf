/*
	Start an upgrade.
	 Parameters:
		- Side
		- Upgrade ID
		- Upgrade Level
		- Player's call
*/

Private ["_artilleryIndex","_artilleryTypes","_artilleryTypesByIndex","_logic","_ownedBySide","_refreshedArtillery","_side","_sideText","_stime","_upgrades","_upgrade_id","_upgrade_isplayer","_upgrade_level","_upgrade_time","_vehicle"];

_side = _this select 0;
_upgrade_id = _this select 1;
_upgrade_level = _this select 2;
_upgrade_isplayer = _this select 3;

_upgrade_time = ((missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_TIMES",str _side]) select _upgrade_id) select _upgrade_level;
_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
// Marty: Publish only the active upgrade ID from the server; the menu computes its own display countdown without touching the upgrade flow.
_logic setVariable ["wfbe_upgrading", true, true];
_logic setVariable ["wfbe_upgrading_id", _upgrade_id, true];

if (_upgrade_isplayer) then {
	[_side, "HandleSpecial", ['upgrade-started', _upgrade_id, _upgrade_level + 1]] Call WFBE_CO_FNC_SendToClients;
	//--- Store the sync.
	missionNamespace setVariable [Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level], false];

	_stime = 0;
	while {!(missionNamespace getVariable Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level]) && _stime < _upgrade_time} do {
		_stime = _stime + 1;
		sleep 1;
	};

	//--- Release the Sync
	missionNamespace setVariable [Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level], nil];
} else {
	sleep _upgrade_time;
};

_upgrades = +(_side Call WFBE_CO_FNC_GetSideUpgrades);
_upgrades set [_upgrade_id, (_upgrades select _upgrade_id) + 1];

_logic setVariable ["wfbe_upgrades", _upgrades, true];
_logic setVariable ["wfbe_upgrading", false, true];
// Marty: Clear the active upgrade ID once the running upgrade has completed.
_logic setVariable ["wfbe_upgrading_id", -1, true];

// Marty: Existing artillery, such as pre-upgrade M119 static guns, does not pass through buy/build equipment init again.
// Scan every vehicle known by the server because artillery pieces may be deployed far away from the base.
if (_upgrade_id == WFBE_UP_ARTYAMMO) then {
	_sideText = str _side;
	_refreshedArtillery = [];
	_artilleryTypesByIndex = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES", _sideText];

	for "_artilleryIndex" from 0 to (count _artilleryTypesByIndex)-1 do {
		_artilleryTypes = _artilleryTypesByIndex select _artilleryIndex;
		{
			_vehicle = _x;
			if ((local _vehicle) && ((typeOf _vehicle) in _artilleryTypes) && !(_vehicle in _refreshedArtillery)) then {
				_ownedBySide = true;
				if !(isNil {_vehicle getVariable "side"}) then {_ownedBySide = (_vehicle getVariable "side") == _side};

				if (_ownedBySide) then {
					[_vehicle, _artilleryIndex, _side] Call EquipArtillery;
					// Marty: Mark refreshed artillery globally so client-side upgrade notifications do not add the same magazines again.
					_vehicle setVariable ["wfbe_arty_ammo_refreshed", true, true];
					_refreshedArtillery = _refreshedArtillery + [_vehicle];

					// Marty: The BIS artillery command menu is initialized from the vehicle's current magazines; rerun it after adding new ammo.
					if ((missionNamespace getVariable "WFBE_C_ARTILLERY_UI") > 0) then {
						// Marty: Clear any previous init command on this artillery piece so rerunning the BIS UI init does not stack menu actions.
						clearVehicleInit _vehicle;
						_vehicle setVehicleInit "[this] ExecVM 'Common\Common_InitArtillery.sqf'";
						processInitCommands;
						clearVehicleInit _vehicle;
					};
				};
			};
		} forEach vehicles;
	};

	["INFORMATION", Format ["Server_ProcessUpgrade.sqf: [%1] Refreshed [%2] existing artillery pieces after Artillery Ammunition upgrade.", _sideText, count _refreshedArtillery]] Call WFBE_CO_FNC_LogContent;
};

[_side, "NewIntelAvailable"] Spawn SideMessage;
// [_side, "LocalizeMessage", ['UpgradeComplete', _upgrade_id, _upgrade_level + 1]] Call WFBE_CO_FNC_SendToClients;
[_side, "HandleSpecial", ['upgrade-complete', _upgrade_id, _upgrade_level + 1]] Call WFBE_CO_FNC_SendToClients;

//todo log.
