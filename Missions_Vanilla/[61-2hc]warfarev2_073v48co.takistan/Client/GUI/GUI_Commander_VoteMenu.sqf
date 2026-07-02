scriptName "Client\GUI\GUI_Commander_VoteMenu.sqf";

//--- Register the UI.
uiNamespace setVariable ["wfbe_display_vote", _this select 0];

_u = 1;
lnbClear 509100;
lnbAddRow[509100, ["AI Commander", "0"]];
lnbSetValue[509100, [0, 0], -1];
//--- B74.2.5: cache-aware build mirroring GUI_VoteMenu. Live groups authoritative once any team is player-led;
//--- else render names from the JIP primitive roster push. WFBE_CVOTE_USING_PRIMS gates the prune loop below.
WFBE_CVOTE_USING_PRIMS = false;
WFBE_CVOTE_HasLive = false;
for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
	if (!isNil {WFBE_Client_Teams select _i} && {isPlayer leader (WFBE_Client_Teams select _i)}) exitWith {WFBE_CVOTE_HasLive = true};
};
if (WFBE_CVOTE_HasLive) then {
	for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
		if (isPlayer leader (WFBE_Client_Teams select _i)) then {
			lnbAddRow[509100, [name leader (WFBE_Client_Teams select _i), "0"]];
			lnbSetValue[509100, [_u, 0], _i];
			_u = _u + 1;
		};
	};
} else {
	if (!isNil "WFBE_JIP_ROSTER_PRIMS") then {
		{
			lnbAddRow[509100, [(_x select 0), "0"]];
			lnbSetValue[509100, [_u, 0], -1];
			_u = _u + 1;
		} forEach WFBE_JIP_ROSTER_PRIMS;
		if (_u > 1) then {WFBE_CVOTE_USING_PRIMS = true};
	};
};

WFBE_MenuAction = -1;
_voteArray = [];
_index = 0;
_voted_commander = "AI Commander";
while {alive player && dialog} do {

	//--- The client has selected a new com.
	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		_index = lnbCurSelRow 509100;
	};

	if (WFBE_MenuAction == 2) then{
		WFBE_MenuAction = -1;

		_player_name = lnbText [509100,[_index, 0]];

		//--- wiki-wins: resolve by the row's stored team index, not a display-name match (duplicate names / mid-dialog renames picked the wrong commander)
		_storedIndex = lnbValue [509100,[_index, 0]];
		_isPrimitivePlaceholder = false;
		if ((missionNamespace getVariable ["WFBE_C_FIX_VOTE_QA_EXECUTION", 0]) > 0) then {
			if (WFBE_CVOTE_USING_PRIMS && _index > 0 && _storedIndex < 0) then {_isPrimitivePlaceholder = true};
		};

		if !(_isPrimitivePlaceholder) then {
			_voted_commander = if (_storedIndex < 0) then {objNull} else {group leader (WFBE_Client_Teams select _storedIndex)};

			["RequestNewCommander", [side group player, _voted_commander]] Call WFBE_CO_FNC_SendToServer;
			voted = true;
			closeDialog 0;
		};
	};

	//--- B74.2.5: while showing primitive rows, suppress the prune/add pass (it would delete every primitive row
	//--- within ~0.05s because their value-key -1 does not resolve a player-led live team). Flip to live ONCE a
	//--- live team carries a player leader, so casting maps the selected name back to a real group object.
	_liveNow = false;
	for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
		if (!isNil {WFBE_Client_Teams select _i} && {isPlayer leader (WFBE_Client_Teams select _i)}) exitWith {_liveNow = true};
	};
	if (WFBE_CVOTE_USING_PRIMS && _liveNow) then {
		WFBE_CVOTE_USING_PRIMS = false;
		lnbClear 509100;
		lnbAddRow[509100, ["AI Commander", "0"]];
		lnbSetValue[509100, [0, 0], -1];
		_uu = 1;
		for '_i' from 0 to count(WFBE_Client_Teams)-1 do {
			if (!isNil {WFBE_Client_Teams select _i} && {isPlayer leader (WFBE_Client_Teams select _i)}) then {
				lnbAddRow[509100, [name leader (WFBE_Client_Teams select _i), "0"]];
				lnbSetValue[509100, [_uu, 0], _i];
				_uu = _uu + 1;
			};
		};
	};

	if (!WFBE_CVOTE_USING_PRIMS) then {
		_list_present = [];
		if ((missionNamespace getVariable ["WFBE_C_FIX_VOTE_LIST_PRUNE", 0]) > 0) then {
			for '_i' from (((lnbSize 509100) select 0) - 1) to 1 step -1 do {
				_value = lnbValue [509100,[_i, 0]];
				_valid = false;
				if (_value >= 0 && {_value < count(WFBE_Client_Teams)}) then {
					_team = WFBE_Client_Teams select _value;
					if !(isNil "_team") then {_valid = isPlayer leader _team};
				};
				if !(_valid) then {lnbDeleteRow [509100, _i]} else {[_list_present, _value] Call WFBE_CO_FNC_ArrayPush};
			};
		} else {
			for '_i' from 1 to ((lnbSize 509100) select 0)-1 do { //--- Remove potential non-player controlled slots.
				_value = lnbValue [509100,[_i, 0]];
				_team = WFBE_Client_Teams select _value;
				if !(isPlayer leader _team) then {lnbDeleteRow [509100, _i]} else {[_list_present, _value] Call WFBE_CO_FNC_ArrayPush};
			};
		};

		for '_i' from 0 to WFBE_Client_Teams_Count do { //--- Add potential new player controlled slots.
			_team = WFBE_Client_Teams select _i;
			if(!(isNil "_team"))then{
				if (isPlayer leader _team && !(_i in _list_present)) then {
					lnbAddRow[509100, [name leader _team, "0"]];
					lnbSetValue[509100, [((lnbSize 509100) select 0)-1, 0], _i];
				};
			};
		};
	};
	sleep 0.05;
};

//--- Release the UI.
uiNamespace setVariable ["wfbe_display_vote", nil];
