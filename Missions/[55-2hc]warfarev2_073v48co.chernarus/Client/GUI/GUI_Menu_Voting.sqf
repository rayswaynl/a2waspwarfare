scriptName "Client\GUI\GUI_Menu_Voting.sqf";

/*
	Voting page dialog loop (idd 25000).
	Lists 5 vote types. When a vote is ACTIVE the button text changes to "Vote YES".
	One YES vote per player per active vote — tracked server-side by name.
	Commander re-vote short-circuits: fires the existing RequestCommanderVote path directly.

	WFBE_VOTE_STATE (missionNamespace, publicVariable'd by server on every change):
		[]                         — idle / no vote active
		[type, yes, needed, endTime, side]
			type    — string  e.g. "skip-night"
			yes     — number  current yes-count
			needed  — number  threshold
			endTime — number  server time when window closes
			side    — side or objNull for global votes
*/

Private ["_display","_selected","_state","_yes","_needed","_endTime",
         "_cooldowns","_cooldownSec","_remaining","_statusTxt","_countTxt",
         "_cooldownTxt","_footerTxt","_btnTxt","_i","_opts",
         "_vSide","_onCooldown","_activeType","_canAct","_isActive","_isVoter",
         "_now"];

//--- Register display reference.
uiNamespace setVariable ["WFBE_Display_VotingMenu", _this select 0];

//--- Vote option list (order determines index used as key below).
_opts = [
	"skip-night",
	"commander",
	"surrender",
	"weather",
	"mission-restart"
];

lbClear 25100;
{
	Private ["_lbl"];
	//--- Key pattern matches the server side: STR_WF_VOTE_OPT_<type-string>
	_lbl = Localize (Format ["STR_WF_VOTE_OPT_%1", _x]);
	if (_lbl == "") then {_lbl = _x};
	lbAdd [25100, _lbl];
} forEach _opts;
lbSetCurSel [25100, 0];

WFBE_MenuAction = -1;

while {alive player && dialog} do {

	//--- Read shared vote state broadcast by server.
	_state = missionNamespace getVariable ["WFBE_VOTE_STATE", []];

	_activeType = "";
	_yes        = 0;
	_needed     = 0;
	_endTime    = 0;
	_vSide      = objNull;
	_isActive   = false;

	if (count _state >= 5) then {
		_activeType = _state select 0;
		_yes        = _state select 1;
		_needed     = _state select 2;
		_endTime    = _state select 3;
		_vSide      = _state select 4;
		_isActive   = true;
	};

	//--- Read cooldown timestamps (array of [type, unlockTime] pairs).
	_cooldowns    = missionNamespace getVariable ["WFBE_VOTE_COOLDOWNS", []];
	_cooldownSec  = missionNamespace getVariable ["WFBE_C_VOTE_COOLDOWN_FAILED", 300];

	//--- Determine currently selected type.
	_i        = lbCurSel 25100;
	if (_i < 0) then {_i = 0};
	_selected = _opts select _i;

	//--- Check if selected type is on cooldown.
	_onCooldown = false;
	_remaining  = 0;
	{
		if ((_x select 0) == _selected) then {
			_remaining = (_x select 1) - (missionNamespace getVariable ["WFBE_SERVER_TIME", 0]);
			if (_remaining > 0) then {_onCooldown = true};
		};
	} forEach _cooldowns;

	//--- Is the active vote the selected type, and has this player already voted YES?
	_isVoter = false;
	if (_isActive && (_activeType == _selected)) then {
		Private ["_voters"];
		_voters = missionNamespace getVariable ["WFBE_VOTE_VOTERS", []];
		{if (_x == name player) then {_isVoter = true}} forEach _voters;
	};

	//--- Build UI text.
	_statusTxt   = "";
	_countTxt    = "";
	_cooldownTxt = "";
	_footerTxt   = "";
	_btnTxt      = Localize "STR_WF_VOTE_StartVote";
	_canAct      = true;

	if (_isActive) then {
		if (_activeType == _selected) then {
			//--- An active vote of this type is running.
			_now       = missionNamespace getVariable ["WFBE_SERVER_TIME", 0];
			_remaining = _endTime - _now;
			if (_remaining < 0) then {_remaining = 0};
			_statusTxt = Format [Localize "STR_WF_VOTE_Status", _yes, _needed];
			_countTxt  = Format [Localize "STR_WF_VOTE_Countdown", floor _remaining];
			if (_isVoter) then {
				_btnTxt  = Localize "STR_WF_VOTE_AlreadyVoted";
				_canAct  = false;
			} else {
				_btnTxt  = Localize "STR_WF_VOTE_VoteYes";
				_canAct  = true;
			};
		} else {
			//--- A different vote is running — cannot start another.
			_footerTxt = Format [Localize "STR_WF_VOTE_OtherActive", Localize (Format ["STR_WF_VOTE_OPT_%1", _activeType])];
			_canAct    = false;
		};
	} else {
		if (_onCooldown) then {
			_cooldownTxt = Format [Localize "STR_WF_VOTE_Cooldown", ceil _remaining];
			_canAct      = false;
		};
	};

	ctrlSetText [25101, _statusTxt];
	ctrlSetText [25102, _countTxt];
	ctrlSetText [25103, _cooldownTxt];
	ctrlSetText [25104, _btnTxt];
	ctrlSetText [25105, _footerTxt];
	ctrlEnable  [25104, _canAct];

	//--- Handle button press.
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;

		if (_selected == "commander") then {
			//--- Commander re-vote: use the existing mechanism directly.
			closeDialog 0;
			["RequestCommanderVote", [sideJoined, name player]] Call WFBE_CO_FNC_SendToServer;
		} else {
			//--- Submit request to server (start vote OR cast YES if one is already running).
			["RequestVote", [sideJoined, name player, _selected]] Call WFBE_CO_FNC_SendToServer;
		};
	};

	sleep 0.15;
};

//--- Release display reference.
uiNamespace setVariable ["WFBE_Display_VotingMenu", nil];
