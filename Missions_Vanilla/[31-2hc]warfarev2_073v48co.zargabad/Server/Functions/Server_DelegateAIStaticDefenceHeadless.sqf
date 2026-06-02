/*
	Delegate town AI creation to an headless client.
	 Parameters:
		- Side
		- Groups
		- Spawn positions
		- Teams
		- Defence
		- Move In Gunner immidietly or not
*/

Private ["_clients", "_defence", "_groups", "_moveInGunner", "_positions", "_side", "_team", "_townDefenderAI"];

_side = _this select 0;
_groups = +(_this select 1);
_positions = +(_this select 2);
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;
// Marty: Optional flag lets town static gunners be filtered from enemy town activation scans.
_townDefenderAI = if (count _this > 6) then {_this select 6} else {false};

//--- Delegate The groups to the miscelleanous headless clients.
for '_i' from 0 to count(_groups) -1 do {
	_clients = missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID";

	if (count _clients > 0) then {
		[leader(_clients select floor(random count _clients)), "HandleSpecial", ['delegate-ai-static-defence', _side, [_groups select _i], [_positions select _i], _team, _defence, _moveInGunner, _townDefenderAI]] Call WFBE_CO_FNC_SendToClient;
	};
};
