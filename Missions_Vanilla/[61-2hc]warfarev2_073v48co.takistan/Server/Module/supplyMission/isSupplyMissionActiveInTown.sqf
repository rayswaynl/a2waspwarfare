"WFBE_Client_PV_IsSupplyMissionActiveInTown" addPublicVariableEventHandler {

	private ["_d", "_player", "_sourceTown", "_lastActivationTime", "_supplyMissionCooldownEnabled", "_badTown"];

	_d = _this select 1;
	if (typeName _d != "ARRAY") exitWith {
		["WARNING", Format ["isSupplyMissionActiveInTown.sqf: rejected malformed WFBE_Client_PV_IsSupplyMissionActiveInTown payload: %1", _d]] Call WFBE_CO_FNC_LogContent;
	};
	if (count _d < 2) exitWith {
		["WARNING", Format ["isSupplyMissionActiveInTown.sqf: rejected short WFBE_Client_PV_IsSupplyMissionActiveInTown payload: %1", _d]] Call WFBE_CO_FNC_LogContent;
	};

	_player = _d select 0;
	_sourceTown = _d select 1;

	if ((typeName _player != "OBJECT") || {typeName _sourceTown != "OBJECT"} || {isNull _player} || {isNull _sourceTown} || {!alive _player} || {!isPlayer _player}) exitWith {
		["WARNING", Format ["isSupplyMissionActiveInTown.sqf: rejected invalid WFBE_Client_PV_IsSupplyMissionActiveInTown payload: player=%1 town=%2", _player, _sourceTown]] Call WFBE_CO_FNC_LogContent;
	};
	_badTown = false;
	if (!isNil "towns") then {
		if (!(_sourceTown in towns)) then {_badTown = true};
	};
	if (_badTown) exitWith {
		["WARNING", Format ["isSupplyMissionActiveInTown.sqf: rejected unknown WFBE_Client_PV_IsSupplyMissionActiveInTown town: %1", _sourceTown]] Call WFBE_CO_FNC_LogContent;
	};

	_lastActivationTime = _sourceTown getVariable ["LastSupplyMissionRun", 0];
	if (typeName _lastActivationTime != "SCALAR") exitWith {
		["WARNING", Format ["isSupplyMissionActiveInTown.sqf: rejected invalid LastSupplyMissionRun for town %1: %2", _sourceTown, _lastActivationTime]] Call WFBE_CO_FNC_LogContent;
	};

	_supplyMissionCooldownEnabled = false;

	if (((_lastActivationTime + WFBE_CO_VAR_SupplyMissionRegenInterval) > time) && (_lastActivationTime != 0)) then {
		_supplyMissionCooldownEnabled = true;
	};

	missionNamespace setVariable ["WFBE_Server_PV_IsSupplyMissionActiveInTown", [_sourceTown, _supplyMissionCooldownEnabled]];
	_sourceTown setVariable ["supplyMissionCoolDownEnabled", _supplyMissionCooldownEnabled, true];

	publicVariable "WFBE_Server_PV_IsSupplyMissionActiveInTown";

};
