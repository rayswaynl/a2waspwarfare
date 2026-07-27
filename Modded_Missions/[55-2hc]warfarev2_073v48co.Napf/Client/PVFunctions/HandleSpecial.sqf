Private['_args', '_request'];

_request = _this select 0;
_args = +_this;
_args set [0, "**NIL**"];
_args = _args - ["**NIL**"]; //--- Strip the action request from the arguments.

switch (_request) do {
	case "action-perform": {_args spawn WFBE_CL_FNC_Perform_Action};
	case "commander-vote": {_args spawn WFBE_CL_FNC_Commander_VoteEnd};
	case "commander-vote-start": {_args spawn WFBE_CL_FNC_Commander_VoteStart};
	case "new-commander-assigned": {_args spawn WFBE_CL_FNC_Commander_Assigned};
	case "team-update-capability": {
		Private ["_teamChallenge","_teamExpectedChallenge","_teamExpires","_teamPending","_teamPendingKey","_teamPurpose","_teamToken"];
		if (count _args != 4) exitWith {};
		_teamPurpose = _args select 0;
		_teamToken = _args select 1;
		_teamExpires = _args select 2;
		_teamChallenge = _args select 3;
		if (_teamPurpose != "team-update") exitWith {};
		if (typeName _teamToken != "STRING" || {_teamToken == ""}) exitWith {};
		if (typeName _teamExpires != "SCALAR" || {_teamExpires <= time}) exitWith {};
		if (typeName _teamChallenge != "STRING" || {_teamChallenge == ""}) exitWith {};
		_teamPendingKey = Format ["wfbe_team_update_pending_%1", getPlayerUID player];
		_teamPending = missionNamespace getVariable [_teamPendingKey, []];
		if (typeName _teamPending != "ARRAY" || {count _teamPending != 7}) exitWith {};
		_teamExpectedChallenge = _teamPending select 6;
		if (typeName _teamExpectedChallenge != "STRING" || {_teamChallenge != _teamExpectedChallenge}) exitWith {};
		missionNamespace setVariable [_teamPendingKey, []];
		_teamPending set [6, _teamToken];
		["RequestTeamUpdate", _teamPending] Call WFBE_CO_FNC_SendToServer;
	};
	case "delegate-townai": {_args spawn WFBE_CL_FNC_DelegateTownAI};
	case "delegate-ai": {_args spawn WFBE_CL_FNC_DelegateAI};
	case "delegate-ai-static-defence": {_args spawn WFBE_CL_FNC_DelegateAIStaticDefence};
	case "endgame": {_args spawn WFBE_CL_FNC_EndGame};
	case "group-join-accept": {_args call WFBE_CL_FNC_Groups_JoinAccepted};
	case "group-join-deny": {_args call WFBE_CL_FNC_Groups_JoinDenied};
	case "group-kick": {_args call WFBE_CL_FNC_Groups_KickedOff};
	case "group-join-request": {_args call WFBE_CL_FNC_Groups_ReceiveRequest};
	case "hq-setstatus": {_args spawn WFBE_CL_FNC_HQ_SetStatus};
	case "icbm-display": {_args spawn WFBE_CL_FNC_Display_ICBM};
	case "irsmoke-createfx": {{_x spawn WFBE_CO_MOD_IRS_CreateSmoke} forEach (_args select 0)};
	case "join-answer": {missionNamespace setVariable ['WFBE_P_CANJOIN', (_args select 0)]};
	case "uav-reveal": {_args spawn WFBE_CL_FNC_Reveal_UAV};
	case "upgrade-started": {_args spawn WFBE_CL_FNC_Upgrade_Started};
	case "upgrade-complete": {_args spawn WFBE_CL_FNC_Upgrade_Complete};
	case "building-started": {_args spawn WFBE_CL_FNC_Building_Started};
	case "set-hq-killed-eh": {if !(isServer) then {(_args select 0) addEventHandler ["killed", {["RequestSpecial", ["process-killed-hq", _this]] Call WFBE_CO_FNC_SendToServer}]};};
	case "auto-wall-constructing-changed":{ isAutoWallConstructingEnabled = (_args select 0)};
};
