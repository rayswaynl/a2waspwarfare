/*
	Client OnFired events.
	 Scope: Client.
*/

/*
	Triggered whenever the player place a satchel.
	 Parameters:
		- unit: Object - Object the event handler is assigned to
		- projectile: object - Object of the projectile that was shot
*/
WFBE_CL_FNC_OnFiredSatchel = {
	Private ["_closest", "_projectile", "_side_structures", "_tkPayload", "_uid", "_unit"];

	_unit = _this select 0;
	_projectile = _this select 1;

	//--- Retrieve the side structures.
	_side_structures = (WFBE_Client_SideJoined Call WFBE_CO_FNC_GetSideStructures) + [WFBE_Client_SideJoined Call WFBE_CO_FNC_GetSideHQ];

	//--- Get the closest structure.
	_closest = [_unit, _side_structures] Call WFBE_CO_FNC_GetClosestEntity;

	//--- Check the distance between the _unit and the closest friendly building.
	if (_closest distance _unit < 30) then {
		deleteVehicle _projectile;

		//--- Show ID?
		_uid = if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_UID_SHOW") == 0) then {"xxxxxxx"} else {getPlayerUID _unit};

		//--- Notify about the TK attempt (r29 notify fan-out):
		//--- SIDE-scoped only - nil destination leaked satchel/base TK intel to the enemy via global PV.
		//--- Local echo required: A2 publicVariable does not re-fire the EH on the sending client, so the
		//--- offender would otherwise never see their own warning (economy StructureSell uses side-scope only).
		_tkPayload = ['StructureTK', name _unit, _uid, _closest, WFBE_Client_SideJoinedText];
		[WFBE_Client_SideJoined, "LocalizeMessage", _tkPayload] Call WFBE_CO_FNC_SendToClients;
		//--- Dedicated/remote client originator: PV does not echo locally. Hosted already Spawns in SendToClients.
		if (!isHostedServer) then { if (!isNil "CLTFNCLocalizeMessage") then {_tkPayload Spawn CLTFNCLocalizeMessage} };
	};
};

//--- Handle the client Firing.
WFBE_CL_FNC_OnFired = {
	if ((_this select 4) == "PipeBomb") then {[_this select 0, _this select 6] Spawn WFBE_CL_FNC_OnFiredSatchel}; //--- Satchel Handler.
};