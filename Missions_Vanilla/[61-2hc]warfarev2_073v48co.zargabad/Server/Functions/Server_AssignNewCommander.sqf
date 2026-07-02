Private ["_logic", "_side", "_commander"];

// Marty: The direct commander assignment receives [side, commanderTeam]; keep the side scalar for GetSideLogic and client broadcasts.
_side = _this select 0;
_commander = _this select 1;
_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;


//--- Notify the clients.
[_side, "HandleSpecial", ["new-commander-assigned", _commander]] Call WFBE_CO_FNC_SendToClients;

//--- Process the AI Commander FSM if it's not running.
if !(isNull _commander) then {
	if (_logic getVariable "wfbe_aicom_running") then {_logic setVariable ["wfbe_aicom_running", false]};
};
