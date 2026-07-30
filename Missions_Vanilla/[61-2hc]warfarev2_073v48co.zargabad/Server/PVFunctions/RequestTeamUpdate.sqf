Private["_args","_challenge","_commanderTeam","_consumeResult","_minted","_properties","_rejected","_requester","_requesterSide","_secHardening","_team","_teamOwned","_token","_validProps"];

_args = _this;

//--- ORDER-AUTH 20260730: always reject non-array / empty. Previously only under SEC_HARDENING.
if (typeName _args != "ARRAY" || {count _args < 1}) exitWith {
	["WARNING", "RequestTeamUpdate.sqf: rejected non-array or empty payload."] Call WFBE_CO_FNC_LogContent;
};
_team = _args select 0;

_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;

//--- ORDER-AUTH 20260730 BASELINE (always-on, unflagged): when SEC_HARDENING=0 the entire commander /
//--- side-scope / property-whitelist block below was skipped, so ANY client could forge
//--- RequestTeamUpdate [enemySide|enemyGroups, behaviour, combat, formation, speed] and re-task
//--- the victim side's AI formations. Apply a minimal always-on gate: live player requester who is
//--- the commander of the claimed side, and team scope owned by that side. Capability token mint/
//--- consume remains behind SEC_HARDENING only (C4 residual: object possession is not crypto bind).
_rejected = false;
_requester = objNull;
if (count _args > 5) then {_requester = _args select 5};
if (typeName _requester != "OBJECT" || {isNull _requester} || {!isPlayer _requester} || {!alive _requester}) then {
	//--- Legacy short payloads (no requester slot): reject under baseline auth. Honest clients using
	//--- the capability-reply path always send requester at select 5.
	_rejected = true;
	["WARNING", "RequestTeamUpdate.sqf: rejected update with missing/invalid requester (baseline auth)."] Call WFBE_CO_FNC_LogContent;
};
if (!_rejected) then {
	_requesterSide = side (group _requester);
	_commanderTeam = _requesterSide Call WFBE_CO_FNC_GetCommanderTeam;
	if (isNull _commanderTeam || {group _requester != _commanderTeam} || {leader _commanderTeam != _requester}) then {
		_rejected = true;
		["WARNING", Format ["RequestTeamUpdate.sqf: rejected non-commander requester [%1] (baseline auth).", _requester]] Call WFBE_CO_FNC_LogContent;
	};
};
if (!_rejected) then {
	if (count _args < 5) then {
		_rejected = true;
		["WARNING", "RequestTeamUpdate.sqf: rejected short update payload (baseline auth)."] Call WFBE_CO_FNC_LogContent;
	} else {
		_validProps = ((_args select 1) in ["CARELESS","SAFE","AWARE","COMBAT","STEALTH"])
			&& {(_args select 2) in ["BLUE","GREEN","WHITE","YELLOW","RED"]}
			&& {(_args select 3) in ["COLUMN","STAG COLUMN","WEDGE","ECH LEFT","ECH RIGHT","ECH  RIGHT","VEE","LINE","FILE","DIAMOND","NO CHANGE"]}
			&& {(_args select 4) in ["LIMITED","NORMAL","FULL"]};
		if (!_validProps) then {
			_rejected = true;
			["WARNING", "RequestTeamUpdate.sqf: rejected invalid team property value(s) (baseline auth)."] Call WFBE_CO_FNC_LogContent;
		};
	};
};
if (!_rejected) then {
	_teamOwned = true;
	if (typeName _team == "ARRAY") then {
		{
			if (isNil "_x") then {
				_teamOwned = false;
			} else {
				if (typeName _x != "GROUP" || {isNull _x} || {side _x != _requesterSide}) then {_teamOwned = false};
			};
		} forEach _team;
	} else {
		if (typeName _team != "SIDE" || {_team != _requesterSide}) then {_teamOwned = false};
	};
	if (!_teamOwned) then {
		_rejected = true;
		["WARNING", Format ["RequestTeamUpdate.sqf: rejected team scope outside requester side [%1] (baseline auth).", _requester]] Call WFBE_CO_FNC_LogContent;
	};
};
if (_rejected) exitWith {};

//--- Security hardening (optional, capability token layer): mint/consume still behind the dark flag.
//--- Baseline commander+side+props already applied above.
_rejected = false;
if (_secHardening) then {
	_requester = objNull;
	_token = "";
	_challenge = "";
	if (count _args > 5) then {_requester = _args select 5};
	if (count _args > 6) then {_token = _args select 6};
	if (count _args > 7) then {_challenge = _args select 7};
	if (count _args < 6 || {typeName _requester != "OBJECT"} || {isNull _requester} || {!isPlayer _requester} || {!alive _requester}) then {
		_rejected = true;
		["WARNING", "RequestTeamUpdate.sqf: rejected update with invalid requester."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected) then {
		_requesterSide = side (group _requester);
		_commanderTeam = _requesterSide Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _commanderTeam || {group _requester != _commanderTeam} || {leader _commanderTeam != _requester}) then {
			_rejected = true;
			["WARNING", Format ["RequestTeamUpdate.sqf: rejected non-commander requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
		};
	};
	_validProps = count _args >= 5;
	if (!_rejected && {!_validProps}) then {
		_rejected = true;
		["WARNING", "RequestTeamUpdate.sqf: rejected short update payload."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected) then {
		_validProps = ((_args select 1) in ["CARELESS","SAFE","AWARE","COMBAT","STEALTH"])
			&& {(_args select 2) in ["BLUE","GREEN","WHITE","YELLOW","RED"]}
			&& {(_args select 3) in ["COLUMN","STAG COLUMN","WEDGE","ECH LEFT","ECH RIGHT","ECH  RIGHT","VEE","LINE","FILE","DIAMOND","NO CHANGE"]}
			&& {(_args select 4) in ["LIMITED","NORMAL","FULL"]};
		if (!_validProps) then {
			_rejected = true;
			["WARNING", "RequestTeamUpdate.sqf: rejected invalid team property value(s)."] Call WFBE_CO_FNC_LogContent;
		};
	};
	_teamOwned = true;
	if (!_rejected) then {
		if (typeName _team == "ARRAY") then {
			{
				if (isNil "_x") then {
					_teamOwned = false;
				} else {
					if (typeName _x != "GROUP" || {isNull _x} || {side _x != _requesterSide}) then {_teamOwned = false};
				};
			} forEach _team;
		} else {
			if (typeName _team != "SIDE" || {_team != _requesterSide}) then {_teamOwned = false};
		};
		if (!_teamOwned) then {
			_rejected = true;
			["WARNING", Format ["RequestTeamUpdate.sqf: rejected team scope outside requester side [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
		};
	};
	if (!_rejected && {typeName _token != "STRING"}) then {
		_rejected = true;
		["WARNING", "RequestTeamUpdate.sqf: rejected malformed capability token."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {_token == ""}) then {
		if (typeName _challenge != "STRING" || {_challenge == ""}) then {
			_rejected = true;
			["WARNING", "RequestTeamUpdate.sqf: rejected missing capability challenge."] Call WFBE_CO_FNC_LogContent;
		} else {
			_minted = false;
			if (!isNil "WFBE_SE_FNC_MintCapability") then {
				_minted = ["team-update", _requester, "team-update-capability", _challenge, 15, 1] Call WFBE_SE_FNC_MintCapability;
			};
			if (!_minted) then {
				_rejected = true;
				["WARNING", Format ["RequestTeamUpdate.sqf: capability mint failed for [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
			} else {
				_rejected = true;
			};
		};
	};
	if (!_rejected && {_token != ""}) then {
		_consumeResult = [false, "missing"];
		if (!isNil "WFBE_SE_FNC_ConsumeCapability") then {
			_consumeResult = ["team-update", _requester, _token] Call WFBE_SE_FNC_ConsumeCapability;
		};
		if (typeName _consumeResult != "ARRAY" || {count _consumeResult < 1} || {!(_consumeResult select 0)}) then {
			_rejected = true;
			["WARNING", Format ["RequestTeamUpdate.sqf: capability consume failed for [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
		};
	};
};
if (_rejected) exitWith {};

//--- One team.
if (typeName _team == "ARRAY") then {
	{
		_x setBehaviour (_args select 1);
		_x setCombatMode (_args select 2);
		_x setFormation (_args select 3);
		_x setSpeedMode (_args select 4);
		["INFORMATION", Format ["RequestTeamUpdate.sqf: Team [%1] properties were updated.", _x]] Call WFBE_CO_FNC_LogContent;
	} forEach _team;
};

//--- The whole team.
if (typeName _team == "SIDE") then {
	{
		_x setBehaviour (_args select 1);
		_x setCombatMode (_args select 2);
		_x setFormation (_args select 3);
		_x setSpeedMode (_args select 4);
	} forEach (missionNamespace getVariable Format["WFBE_%1TEAMS",str _team]);
	["INFORMATION", Format ["RequestTeamUpdate.sqf: [%1] Teams properties were updated.", _team]] Call WFBE_CO_FNC_LogContent;
};
