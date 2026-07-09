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

Private ["_hcUnit", "_groups", "_positions", "_side", "_teams"];

_side = _this select 0;
_groups = +(_this select 1);
_positions = +(_this select 2);
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;

//--- Delegate The groups to the LEAST-LOADED live headless client (re-evaluated per group).
//--- NOTE: this previously used the RAW registry with no live/alive filter, so it could route
//--- to a dead/null leader; the shared picker filters to live HCs like every other site.
for '_i' from 0 to count(_groups) -1 do {
	_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;

	if (!isNull _hcUnit) then {
		[_hcUnit, "HandleSpecial", ['delegate-ai-static-defence', _side, [_groups select _i], [_positions select _i], _team, _defence, _moveInGunner]] Call WFBE_CO_FNC_SendToClient;
	};
};