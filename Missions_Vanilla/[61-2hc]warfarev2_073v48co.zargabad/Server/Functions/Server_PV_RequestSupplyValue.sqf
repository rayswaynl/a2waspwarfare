"REQUEST_SUPPLY_VALUE" addPublicVariableEventHandler {
	private ["_player", "_id"];

	_player = _this select 1;
	if (typeName _player != "OBJECT" || {isNull _player}) exitWith {
		diag_log "[WFBE][SUPPLY-PV] dropped request with an unusable player object.";
	};
	_id = owner _player;
	if (_id <= 0) exitWith {
		diag_log Format ["[WFBE][SUPPLY-PV] dropped request with owner %1.", _id];
	};

	SUPPLY_VALUE_REQUESTED = (side _player) call WFBE_CO_FNC_GetSideSupply;

	_id publicVariableClient "SUPPLY_VALUE_REQUESTED";
};
