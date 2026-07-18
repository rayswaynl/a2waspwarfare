/*
	Server-authoritative command-menu queue. One pending entry per team means last-order-wins under spam.
*/
private ["_logic","_queue","_keep","_entry","_team","_type","_target","_issuer","_seq","_queuedAt","_last","_cool","_drop","_sides","_side","_cmd","_directAtEnqueue"];
_sides = [west, east];
while {true} do {
	{
		_side = _x;
		_logic = _side Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _logic) then {
			_queue = _logic getVariable "wfbe_aicom_cmd_order_queue"; if (isNil "_queue" || {typeName _queue != "ARRAY"}) then {_queue = []}; _keep = [];
			_cool = missionNamespace getVariable ["WFBE_C_AICOM_DIRECT_COOLDOWN", 1.5]; if (typeName _cool != "SCALAR" || {_cool < 0}) then {_cool = 1.5};
			{
				_entry = _x; _drop = "";
				if (typeName _entry != "ARRAY" || {count _entry < 6}) then {_drop = "malformed"} else {
					_team = _entry select 0; _type = _entry select 1; _target = _entry select 2; _issuer = _entry select 3; _seq = _entry select 4; _queuedAt = _entry select 5; _directAtEnqueue = false;
					if (count _entry > 6 && {typeName (_entry select 6) == "BOOL"}) then {_directAtEnqueue = _entry select 6};
					if (typeName _team != "GROUP") then {_drop = "teamType"};
					if (_drop == "" && {isNull _team || {isPlayer (leader _team)} || {({alive _x} count units _team) <= 0}}) then {_drop = "deadTeam"};
					if (_drop == "" && {typeName _issuer != "OBJECT"}) then {_drop = "issuer"};
					_cmd = _side Call WFBE_CO_FNC_GetCommanderTeam;
					if (_drop == "" && {(isNull _issuer) || {!isPlayer _issuer} || {isNull _cmd} || {!isPlayer (leader _cmd)} || {group _issuer != _cmd}}) then {_drop = "staleIssuer"};
					if (_drop == "" && {typeName _type != "STRING"}) then {_drop = "type"};
					if (_drop == "" && {!(_type in ["move","defense","patrol","release"])}) then {_drop = "type"};
					if (_drop == "" && {typeName _seq != "SCALAR"}) then {_drop = "sequence"};
					if (_drop == "" && {typeName _queuedAt != "SCALAR"}) then {_drop = "queuedAt"};
					if (_drop == "" && {(time - _queuedAt) > 20}) then {_drop = "stale"};
					if (_drop == "" && {_type in ["move","defense","patrol"]}) then {if (typeName _target != "ARRAY" || {count _target < 2} || {typeName (_target select 0) != "SCALAR"} || {typeName (_target select 1) != "SCALAR"}) then {_drop = "target"}};
				};
				if (_drop != "") then {diag_log ("AICOM2|v1|ORDER|QUEUE|DROP|reason=" + _drop)} else {
					_last = _team getVariable "wfbe_aicom_cmd_order_last"; if (isNil "_last" || {typeName _last != "SCALAR"}) then {_last = -1e9};
					if ((time - _last) < _cool) then {_keep = _keep + [_entry]} else {
						if (_type == "release") then {[_team, "towns"] Call SetTeamMoveMode; [_team, true] Call SetTeamAutonomous; _team setVariable ["wfbe_aicom_manualpin", nil, true]} else {[_team, _target] Call SetTeamMovePos; [_team, _type] Call SetTeamMoveMode; [_team, false] Call SetTeamAutonomous; _team setVariable ["wfbe_aicom_manualpin", time, true]};
						if ((missionNamespace getVariable ["WFBE_C_CMD_HANDOFF_PRESERVE", 0]) > 0 && {_directAtEnqueue}) then {_team setVariable ["wfbe_direct_owned", true, true]};
						_team setVariable ["wfbe_aicom_cmd_order_last", time]; _team setVariable ["wfbe_aicom_cmd_order_seq", _seq, true];
						diag_log ("AICOM2|v1|ORDER|QUEUE|APPLY|type=" + _type + "|seq=" + str _seq + "|issuer=" + str (getPlayerUID _issuer));
					};
				};
			} forEach _queue;
			_logic setVariable ["wfbe_aicom_cmd_order_queue", _keep];
		};
	} forEach _sides;
	sleep 0.2;
};
