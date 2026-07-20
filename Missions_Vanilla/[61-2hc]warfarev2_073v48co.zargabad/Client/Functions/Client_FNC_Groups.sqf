/*
	Groups Specific Functions.
	 Scope: Client.
*/
//todo call from init_client.sqf

//--- The client join request has been accepted.
WFBE_CL_FNC_Groups_JoinAccepted = {
	Private ["_group"];
	_group = _this select 0;
	WFBE_Client_PendingRequests = [];//--- Flush all existing requests.
	hint parseText Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Your request to join the group <t color='#BD63F5'>%1</t> has been <t color='#B6F563'>Accepted</t>.</t>", _group];
};

//--- The client join request has been denied.
WFBE_CL_FNC_Groups_JoinDenied = {
	Private ["_group"];
	_group = _this select 0;
	hint parseText Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Your request to join the group <t color='#BD63F5'>%1</t> has been <t color='#B6F563'>Denied</t>.</t>", _group];
};

//--- The client get kicked back to his original group.
WFBE_CL_FNC_Groups_KickedOff = {
	Private ["_group"];
	_group = _this select 0;
	
	[player, WFBE_Client_Team, WFBE_Client_SideJoined] Call WFBE_CO_FNC_ChangeUnitGroup;
	if (leader WFBE_Client_Team != player) then {WFBE_Client_Team selectLeader player};
	["kicked", "post-transfer"] Call WFBE_CL_FNC_TeambarProbe; //--- TEAMBAR probe: kicked-off path has neither COLONEL nor rejoin - capture the resulting order
	hint parseText Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>You were kicked from the group <t color='#BD63F5'>%1</t>, you have been transfered back to your <t color='#B6F563'>Original group</t>.</t>", _group];
	["INFORMATION", Format ["WFBE_CL_FNC_Groups_KickedOff: I was kicked from the group [%1].", _group]] Call WFBE_CO_FNC_LogContent;
};

//--- Used to display incomming group join requests.
WFBE_CL_FNC_Groups_ReceiveRequest = {
	Private ["_name","_player","_uid"];
	_player = _this select 0;
	
	_uid = getPlayerUID(_player);
	_name = name _player;
	
	if (alive _player) then {
		_exists = false;
		{if ((_x select 0) == _uid) exitWith {_exists = true}} forEach WFBE_Client_PendingRequests;
		
		if !(_exists) then {
			[_uid, _name] Spawn {
				Private ["_data","_delay","_index","_is_present","_name","_uid"];
				_uid = _this select 0;
				_name = _this select 1;
				
				_delay = missionNamespace getVariable "WFBE_C_PLAYERS_SQUADS_REQUEST_TIMEOUT";
				while {_delay > -1} do {
					sleep 1;
					_is_present = false;
					{
						if ((_x select 0) == _uid && (_x select 1) == _name) exitWith {_is_present = true};
					} forEach WFBE_Client_PendingRequests;
					_delay = _delay - 1;
					if !(_is_present) exitWith {};
				};
				
				if (_delay <= 0) then {
					_index = -1;
					for '_i' from 0 to count(WFBE_Client_PendingRequests)-1 do {
						_data = WFBE_Client_PendingRequests select _i;
						if ((_data select 0) == _uid && (_data select 1) == _name) exitWith {_index = _i};
					};
					if (_index != -1) then {
						WFBE_Client_PendingRequests set [_index, "***NIL***"];
						WFBE_Client_PendingRequests = WFBE_Client_PendingRequests - ["***NIL***"];
					};
				};
			};
			[WFBE_Client_PendingRequests, [_uid, _name]] Call WFBE_CO_FNC_ArrayPush;
			hint parseText Format["<t color='#42b6ff' size='1.2' underline='1' shadow='1'>Information:</t><br /><br /><t>Player <t color='#BD63F5'>%1</t> has been requested to join your squad, you may accept or deny the request in the <t color='#B6F563'>Groups Menu</t>.</t>", _name];
		};
	};
};