scriptName "Client\GUI\GUI_TransferMenu.sqf";
disableSerialization; //--- cmdcon42 (Ray 2026-07-02): scheduled dialog loop touches display/controls across sleep; guard against "does not support serialization" (matches the convention already in the other GUI_Menu_* handlers).

//--- Register the UI.
uiNamespace setVariable ["wfbe_display_transfer", _this select 0];

// Marty : Modifying the script in order to display only human player and not bots in the advanced fund transfer list :

private ["_list_Players","_aicom_row","_teamTotal","_teamTotalLast","_cmdPercent","_cmdPercentLast","_funds_refresh"];
_list_Players = [];
_aicom_row = -1; //--- Sentinel index of the AI Commander row; -1 = not present.

{
	if (isPlayer (leader _x)) then
	{
		_list_Players = _list_Players + [_x] ;
		_name_player = name (leader _x) ;
		lnbAddRow[505001, [Format ["$%1.",_x Call WFBE_CO_FNC_GetTeamFunds], "   " ,_name_player]];
	};

} forEach WFBE_Client_Teams;

//--- Add "AI Commander" entry when this side is AI-commanded (no human commander).
//--- commanderTeam is nil/null when no commander group exists (AI mode), or holds the
//--- human commander's group when a player holds command.  We show the entry only when
//--- commanderTeam is null/nil OR its leader is not a player — matching the wildcard gate.
private ["_showAICom","_aicomCmdTeam"];
_showAICom = false;
_aicomCmdTeam = sideJoined Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _aicomCmdTeam) then {
	_showAICom = true;
} else {
	if !(isPlayer (leader _aicomCmdTeam)) then {_showAICom = true};
};

if (_showAICom) then {
	_aicom_row = count _list_Players; //--- Row index in the LNB (0-based after all player rows).
	lnbAddRow[505001, ["AI wallet", "   ", "AI Commander"]];
};

_funds_last = -1;
_teamTotal = -1;
_teamTotalLast = -1;
_cmdPercent = -1;
_cmdPercentLast = -1;
_last_update = time;
_update_slider = true;

WFBE_MenuAction = -1;

while {alive player && dialog} do {
	if (WFBE_MenuAction == 3) exitWith {WFBE_MenuAction = -1; closeDialog 0; createDialog "WF_Menu";};
	if (WFBE_MenuAction == 2) then {WFBE_MenuAction = -1; _update_slider = true};

	_funds = Call WFBE_CL_FNC_GetClientFunds;
	_funds_refresh = false;

	if (time - _last_update > 1) then {
		_last_update = time;
		for '_i' from 0 to count _list_Players -1 do
		{
			_funds_team = (_list_Players select _i) Call WFBE_CO_FNC_GetTeamFunds;
			_name_leader = name(leader(_list_Players select _i));

			if ((((uiNamespace getVariable "wfbe_display_transfer") displayCtrl 505001) lnbText [_i, 0]) != Format["$%1.",_funds_team]) then
			{
				lnbSetText [505001, [_i, 0], Format ["$%1.",_funds_team]] ;
			};

			if ((((uiNamespace getVariable "wfbe_display_transfer") displayCtrl 505001) lnbText [_i, 2]) != _name_leader) then
			{
				lnbSetText [505001, [_i, 2], _name_leader] ;
			};
		};
		_teamTotal = 0;
		{_teamTotal = _teamTotal + (_x Call WFBE_CO_FNC_GetTeamFunds);} forEach WFBE_Client_Teams;
		_cmdPercent = WFBE_Client_Logic getVariable ["wfbe_commander_percent", 0];
		if ((_teamTotal != _teamTotalLast) || {_cmdPercent != _cmdPercentLast}) then {_funds_refresh = true};
		//reload if everyone funds is different, reload on timer or fund transfer.
	};

	if (_update_slider) then {
		_update_slider = false;
		ctrlSetText[505003, str (floor (sliderPosition 505002))];
	};

	if (WFBE_MenuAction == 1) then {
		WFBE_MenuAction = -1;
		_ui_lnb_currow = lnbCurSelRow 505001;
		_funds_transfering = floor parseNumber(ctrlText 505003);
		_cando = if (_funds_transfering > 0 && _funds_transfering <= _funds) then {true} else {false};
		if (_cando) then {
			if (_ui_lnb_currow != -1) then {

				//--- AI Commander donation path.
				if (_aicom_row >= 0 && {_ui_lnb_currow == _aicom_row}) then {
					//--- E2 fix: server is authoritative. RequestAIComDonate debits the team (wfbe_funds) AND credits
					//--- the AI wallet. The client-side optimistic debit was REMOVED: that helper resolves to
					//--- ChangeTeamFunds on the SAME group (clientTeam), so client + server were two relative
					//--- -amount writes that compounded to -2x (donor over-charged, money destroyed).
					["RequestAIComDonate", [player, clientTeam, _funds_transfering]] Call WFBE_CO_FNC_SendToServer;
					_funds = Call WFBE_CL_FNC_GetClientFunds;
					_last_update = -1;
				} else {
					_selected = _list_Players select _ui_lnb_currow;

					if !(isNull leader _selected) then {
						if (_selected != group player) then {
							hint parseText format [localize "STR_WF_INFO_Funds_Sent", _funds_transfering, name leader _selected];
							//--- N1 fix (GR-2026-07-08a): server is authoritative. The client-side optimistic
							//--- debit+credit (WFBE_CL_FNC_ChangeClientFunds + WFBE_CO_FNC_ChangeTeamFunds, both
							//--- executed on the caller's own machine) let any modified client forge the target
							//--- team and/or amount with zero server validation - same exploit class as the
							//--- donation row, closed the same way (E2 fix, above): RequestFundsTransfer re-derives
							//--- the sender's own team server-side and re-checks the balance before moving a
							//--- single dollar. Hint stays immediate/optimistic (unchanged UX); recipient notify
							//--- + audit log now only fire on a server-confirmed transfer.
							["RequestFundsTransfer", [player, _selected, _funds_transfering]] Call WFBE_CO_FNC_SendToServer;
							_funds = Call WFBE_CL_FNC_GetClientFunds;
							_last_update = -1;
						} else {
							hint parseText localize "STR_WF_INFO_Funds_Self";
						};
					};
				};
			};
		} else {
			_update_slider = true;
		};
	};

	if (_funds != _funds_last) then {
		sliderSetRange[505002, 0, _funds];
		_teamTotal = 0;
		{_teamTotal = _teamTotal + (_x Call WFBE_CO_FNC_GetTeamFunds);} forEach WFBE_Client_Teams;
		_cmdPercent = WFBE_Client_Logic getVariable ["wfbe_commander_percent", 0];
		_funds_refresh = true;
	};

	if (_funds_refresh) then {
		private ["_fundsText"];
		_fundsText = Format [localize "STR_WF_INFO_Funds", _funds];
		_fundsText = _fundsText + Format ["<br />Team: $%1  |  Cmd share: %2%3", _teamTotal, _cmdPercent, "%"];
		//--- Trello #204: surface the price of a new HQ so the commander can weigh a transfer
		//--- against the cost of (re)deploying a base. Reads the same constant the structure
		//--- configs charge for the HQ (Common\Config\Core_Structures\*: WFBE_C_STRUCTURES_HQ_COST_DEPLOY).
		_fundsText = _fundsText + Format ["<br />" + (localize "STR_WF_INFO_NewHQCost"), missionNamespace getVariable "WFBE_C_STRUCTURES_HQ_COST_DEPLOY"];
		((uiNamespace getVariable "wfbe_display_transfer") displayCtrl 505004) ctrlSetStructuredText (parseText _fundsText);
		_teamTotalLast = _teamTotal;
		_cmdPercentLast = _cmdPercent;
	};

	_funds_last = _funds;
	sleep .01;
};

//--- Release the UI.
uiNamespace setVariable ["wfbe_display_transfer", nil];
