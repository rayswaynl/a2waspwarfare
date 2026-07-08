scriptName "Client\GUI\GUI_VoteMenu.sqf";
disableSerialization; //--- cmdcon42 (Ray 2026-07-02): scheduled dialog loop touches display/controls across sleep; guard against "does not support serialization" (matches the convention already in the other GUI_Menu_* handlers).

//--- Register the UI.
uiNamespace setVariable ["wfbe_display_vote", _this select 0];

_u = 1;
lnbClear 500100;
lnbAddRow[500100, ["AI Commander", "0"]];
lnbSetValue[500100, [0, 0], -1];
//--- B74.2.5: LIVE-group roster is authoritative once any team has a player leader; until then render from the
//--- JIP primitive roster push (names only) so a JIP joiner whose wfbe_teams group objects are nil/broken still
//--- sees the commander candidates. WFBE_VOTE_USING_PRIMS gates the refresh loop below so it does NOT prune the
//--- primitive rows (whose value-key is -1, an index that does not resolve a live team).
WFBE_VOTE_USING_PRIMS = false;
WFBE_VOTE_HasLive = false;
for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
	if (!isNil {WFBE_Client_Teams select _i} && {isPlayer leader (WFBE_Client_Teams select _i)}) exitWith {WFBE_VOTE_HasLive = true};
};
if (WFBE_VOTE_HasLive) then {
	for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
		if (isPlayer leader (WFBE_Client_Teams select _i)) then {
			lnbAddRow[500100, [name leader (WFBE_Client_Teams select _i), "0"]];
			lnbSetValue[500100, [_u, 0], _i];
			_u = _u + 1;
		};
	};
} else {
	if (!isNil "WFBE_JIP_ROSTER_PRIMS") then {
		{
			//--- _x = [name, isPlayer, funds, groupId]; value-key -1 = primitive placeholder (not a live index).
			lnbAddRow[500100, [(_x select 0), "0"]];
			lnbSetValue[500100, [_u, 0], -1];
			_u = _u + 1;
		} forEach WFBE_JIP_ROSTER_PRIMS;
		if (_u > 1) then {WFBE_VOTE_USING_PRIMS = true};
	};
};

WFBE_MenuAction = -1;

_update_list = -5;
_voteArray = [];

while {alive player && dialog} do {
	_voteTime = WFBE_Client_Logic getVariable "wfbe_votetime";

	//--- Exit when the timeout is reached.
	if (_voteTime < 0) exitWith {closeDialog 0};

	for '_i' from 0 to WFBE_Client_Teams_Count do {_voteArray set [_i , 0]};

	//--- The client has voted for x.
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		_index = lnbValue [500100,[lnbCurSelRow 500100, 0]];
		if ((WFBE_Client_Team getVariable "wfbe_vote") != _index) then {WFBE_Client_Team setVariable ["wfbe_vote", _index, true]};
	};

	//--- Update the votes.
	_playerCount = 0;
	{
		if (isPlayer leader _x) then {
			_vote = (_x getVariable "wfbe_vote") + 1;
			_voteArray set [_vote, (_voteArray select _vote) + 1];
			_playerCount = _playerCount + 1;
		};
	} forEach WFBE_Client_Teams;

	_highestId = 0;
	for '_i' from 0 to WFBE_Client_Teams_Count do {if ((_voteArray select _i) > (_voteArray select _highestId)) then {_highestId = _i}}; //--- Get the most voted person.

	if (time - _update_list > 1) then { //--- Refresh the list.
		_update_list = time;

		//--- B74.2.5: detect live-group arrival. While still on the primitive roster, do NOT run the prune/add
		//--- pass (it walks WFBE_Client_Teams which is empty/broken and would delete every primitive row within 1s
		//--- = the flash-then-vanish bug). The moment a live team carries a player leader, rebuild ONCE from live
		//--- and hand over (vote casting then works against real group objects).
		_liveNow = false;
		for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
			if (!isNil {WFBE_Client_Teams select _i} && {isPlayer leader (WFBE_Client_Teams select _i)}) exitWith {_liveNow = true};
		};
		if (WFBE_VOTE_USING_PRIMS && _liveNow) then {
			WFBE_VOTE_USING_PRIMS = false;
			lnbClear 500100;
			lnbAddRow[500100, ["AI Commander", "0"]];
			lnbSetValue[500100, [0, 0], -1];
			_u = 1;
			for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
				if (!isNil {WFBE_Client_Teams select _i} && {isPlayer leader (WFBE_Client_Teams select _i)}) then {
					lnbAddRow[500100, [name leader (WFBE_Client_Teams select _i), "0"]];
					lnbSetValue[500100, [_u, 0], _i];
					_u = _u + 1;
				};
			};
		};

		//--- Live maintenance pass only when NOT on primitives (otherwise leave the primitive rows untouched).
		if (!WFBE_VOTE_USING_PRIMS) then {
			_list_present = [];
			if ((missionNamespace getVariable ["WFBE_C_FIX_VOTE_LIST_PRUNE", 0]) > 0) then {
				for '_i' from (((lnbSize 500100) select 0) - 1) to 1 step -1 do {
					_value = lnbValue [500100,[_i, 0]];
					_valid = false;
					if (_value >= 0 && {_value < count(WFBE_Client_Teams)}) then {
						_team = WFBE_Client_Teams select _value;
						if !(isNil "_team") then {_valid = isPlayer leader _team};
					};
					if !(_valid) then {lnbDeleteRow [500100, _i]} else {[_list_present, _value] Call WFBE_CO_FNC_ArrayPush};
				};
			} else {
				for '_i' from 1 to ((lnbSize 500100) select 0)-1 do { //--- Remove potential non-player controlled slots.
					_value = lnbValue [500100,[_i, 0]];
					_team = WFBE_Client_Teams select _value;
					if !(isPlayer leader _team) then {lnbDeleteRow [500100, _i]} else {[_list_present, _value] Call WFBE_CO_FNC_ArrayPush};
				};
			};

			for '_i' from 0 to WFBE_Client_Teams_Count do { //--- Add potential new player controlled slots.
				_team = WFBE_Client_Teams select _i;
				if(!(isNil "_team"))then{
					if (isPlayer leader _team && !(_i in _list_present)) then {
						lnbAddRow[500100, [name leader _team, "0"]];
						lnbSetValue[500100, [((lnbSize 500100) select 0)-1, 0], _i];
					};
				};
			};
		};
	};

	//--- B74.2.5 CRITICAL GATE: while showing primitive rows, SKIP the entire per-0.05s name/vote/color update
	//--- block. Without this gate the loop iterates by row position (_i) and executes
	//--- `WFBE_Client_Teams select _value` (_value=-1 on primitives -> nil) -> `name leader nil` -> "" -> blanks
	//--- the primitive leader name within 0.05s; and `(WFBE_Client_Teams select _i) getVariable "wfbe_vote"`
	//--- on an empty array -> nil getVariable -> RPT error every tick. The primitive names set at build are static
	//--- and correct; no per-tick refresh is needed until the live handover flips WFBE_VOTE_USING_PRIMS=false.
	if (!WFBE_VOTE_USING_PRIMS) then {
		if ((((uiNamespace getVariable "wfbe_display_vote") displayCtrl 500100) lnbText [0, 1]) != str(_voteArray select 0)) then {lnbSetText [500100, [0, 1], str(_voteArray select 0)]}; //--- No Commander

		for '_i' from 1 to ((lnbSize 500100) select 0)-1 do { //--- Update the UI list properties (name / votes) for players.
			_value = lnbValue [500100,[_i, 0]];
			if ((missionNamespace getVariable ["WFBE_C_FIX_VOTE_QA_EXECUTION", 0]) > 0) then {
				_valid = false;
				if (_value >= 0 && {_value < count(WFBE_Client_Teams)}) then {
					_team = WFBE_Client_Teams select _value;
					if !(isNil "_team") then {_valid = true};
				};
				if (_valid) then {
					if ((((uiNamespace getVariable "wfbe_display_vote") displayCtrl 500100) lnbText [_i, 0]) != name leader _team) then {lnbSetText [500100, [_i, 0], name leader _team]};
					if ((((uiNamespace getVariable "wfbe_display_vote") displayCtrl 500100) lnbText [_i, 1]) != str(_voteArray select _value+1)) then {lnbSetText [500100, [_i, 1], str(_voteArray select _value+1)]};
					if ((_team getVariable "wfbe_vote") != -1) then {
						lnbSetColor [500100, [_i,0], [0.9,0.5,0.1,1]]
					} else {
						lnbSetColor [500100, [_i,0], [1,1,1,1]]
					};
				};
			} else {
				_team = WFBE_Client_Teams select _value;
				if ((((uiNamespace getVariable "wfbe_display_vote") displayCtrl 500100) lnbText [_i, 0]) != name leader _team) then {lnbSetText [500100, [_i, 0], name leader _team]};
				if ((((uiNamespace getVariable "wfbe_display_vote") displayCtrl 500100) lnbText [_i, 1]) != str(_voteArray select _value+1)) then {lnbSetText [500100, [_i, 1], str(_voteArray select _value+1)]};
				if (((WFBE_Client_Teams select _i) getVariable "wfbe_vote") != -1) then {
					lnbSetColor [500100, [_i,0], [0.9,0.5,0.1,1]]
				} else {
					lnbSetColor [500100, [_i,0], [1,1,1,1]]
				};
			};

		};

		//--- Update the text
		_voted_commander = if ((_voteArray select _highestId) <= (_playerCount/2) || _highestId == 0) then {localize "STR_WF_AI"} else {name leader (WFBE_Client_Teams select _highestId-1)};
		ctrlSetText [500101, _voted_commander];
		ctrlSetText [500102, Format ["%1",_voteTime]];
	};

	sleep 0.05;
};

//--- Release the UI.
uiNamespace setVariable ["wfbe_display_vote", nil];
