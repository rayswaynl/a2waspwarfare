Private["_localize","_txt","_totalSkillBLUFOR","_totalSkillOPFOR","_attempts", "_commandChat","_object"];

_localize = _this select 0;
_object = if (_localize == "StructureSell") then {_this select 3} else {if (_localize == "StructureSold") then {_this select 2}};
_commandChat = true;
_txt = "";
_totalSkillBLUFOR = "";
_totalSkillOPFOR = "";

switch (_localize) do {
	case "BaseFallSting": { playSound "inbound"; _commandChat = false; }; //--- B69 S6: HQ-fall server-wide audible sting (sound only, no chat text). Companion to the Server_OnHQKilled.sqf SendToClients broadcast. "inbound" is a registered CfgSounds class (also used by CampCaptured/Common_HandleAlarm).
	case "FirstBlood": { playSound "newCommander"; _txt = Format ["FIRST BLOOD!  %1 drew first blood on %2  (+%3 funds).", _this select 1, _this select 2, _this select 3]; if (!isNil "TitleTextMessage") then {[Format ["FIRST BLOOD!  %1 vs %2", _this select 1, _this select 2], "PLAIN DOWN"] Call TitleTextMessage}; }; //--- esports first-kill flourish (server broadcasts once/match from RequestOnUnitKilled.sqf); newCommander = registered CfgSounds; command-chat line + center-screen sting.
	case "BuildingTeamkill": {_txt = Format [Localize "STR_WF_CHAT_Teamkill_Building",_this select 1, _this select 2, [_this select 3, 'displayName'] Call GetConfigInfo]};
    case "AttackModeActivated": {_txt = Format ["Commander has activated heavy attack mode! You get %1 %2 discount from all units for the next %3 minutes!", (100 - floor (_this select 1)), "%", _this select 2]; playSound "attackMode";};
    case "AttackModeActiveJIP": {_txt = Format ["Your team is currently in heavy attack mode! Buy units with discount before the time runs out!"]; playSound "attackMode";};
    case "AttackModeEnd": {_txt = format ["Your team's attack mode has ended."];};
	case "Teamswap": {_txt = Format [Localize "STR_WF_CHAT_Teamswap",_this select 3, _this select 4]};
	case "Teamstack": 
    {
        /*_attempts = 0;
        while {(_totalSkillBLUFOR == "") || (_totalSkillOPFOR == "") || (isNil "_totalSkillBLUFOR") || (isNil "_totalSkillOPFOR") || _attempts < 40} do {
            _totalSkillBLUFOR = missionNamespace getVariable "WFBE_BLUFOR_SCORE_JOIN";
            _totalSkillOPFOR = missionNamespace getVariable "WFBE_OPFOR_SCORE_JOIN";

            diag_log _totalSkillBLUFOR;
	        diag_log _totalSkillOPFOR;

            _attempts = _attempts + 1;
            sleep 0.5;
        };*/

        waitUntil { !(isNil {missionNamespace getVariable "WFBE_BLUFOR_SCORE_JOIN"}) && !(isNil {missionNamespace getVariable "WFBE_OPFOR_SCORE_JOIN"}) };

        _totalSkillBLUFOR = missionNamespace getVariable "WFBE_BLUFOR_SCORE_JOIN";
        _totalSkillOPFOR = missionNamespace getVariable "WFBE_OPFOR_SCORE_JOIN";

        _totalSkillBLUFOR = [_totalSkillBLUFOR, 1] call BIS_fnc_cutDecimals;
        _totalSkillOPFOR = [_totalSkillOPFOR, 1] call BIS_fnc_cutDecimals;

        _txt = Format [Localize "STR_WF_CHAT_Teamstack",str _totalSkillBLUFOR, str _totalSkillOPFOR];

        /*
        if (_attempts >= 40) then {
            diag_log "Couldn't retrieve team skill values to show them for player upon joining ingame!";
            _txt = "ERROR! Couldn't retrieve team skill values for some reason. Try joining again and contact server admin if this happens again.";
        };
        */
    };
	case "CommanderDisconnected": {_txt = Localize "strwfcommanderdisconnected"};
	case "TacticalLaunch": {_txt = Localize "STR_WF_CHAT_ICBM_Launch"};
	case "CBRadarNeedsAAR": {_txt = Localize "CBRadarNeedsAAR"};
	case "AARadarAlreadyBuilt": {_txt = Localize "AARadarAlreadyBuilt"}; //--- fable/ew-economy
	case "CBRadarAlreadyBuilt": {_txt = Localize "CBRadarAlreadyBuilt"}; //--- fable/ew-economy
	case "BankAlreadyBuilt": {_txt = Localize "BankAlreadyBuilt"};
	case "BankTooCloseToBase": {_txt = Localize "BankTooCloseToBase"};
	case "BankDestroyed": {
		//--- _this: [1]=killerName, [2]=sideName — broadcast to all (both sides hear it).
		_txt = Format [Localize "BankDestroyed", _this select 1, _this select 2];
	};
	case "BankDividend": {
		//--- _this: [1]=amount — quiet group-chat notification (side-targeted).
		_txt = Format [Localize "BankDividend", _this select 1];
		_commandChat = false;
	};
	case "SiteClearanceCommanderOnly": {_txt = Localize "SiteClearanceCommanderOnly"};
	case "SiteClearanceNeedsBarracks1": {_txt = Localize "SiteClearanceNeedsBarracks1"};
	case "SiteClearanceNoTrees": {_txt = Localize "SiteClearanceNoTrees"};
	case "SiteClearanceNoSupply": {_txt = Format [Localize "SiteClearanceNoSupply", _this select 1]};
	case "SiteClearanceDone": {_txt = Format [Localize "SiteClearanceDone", _this select 1, _this select 2]};
	case "SiteClearanceOutsideBase": {_txt = Localize "SiteClearanceOutsideBase"};
	case "Teamkill": {_txt = Format [Localize "STR_WF_CHAT_Teamkill",(missionNamespace getVariable "WFBE_C_PLAYERS_PENALTY_TEAMKILL")]}; //--- J1 funds authority: debit moved server-side (RequestOnUnitKilled.sqf); chat text kept.
	case "FundsTransfer": {_txt = Format [Localize "STR_WF_CHAT_FundsTransfer",_this select 1,_this select 2];_commandChat = false;playSound ["cashierSound", true];};
	case "StructureSold": {_txt = Format [Localize "STR_WF_CHAT_Structure_Sold",([_this select 1,'displayName'] Call GetConfigInfo), ([_object, towns] Call GetClosestLocation)]};
	case "StructureSell": {_txt = Format [Localize "STR_WF_CHAT_Structure_Sell",([_this select 1,'displayName'] Call GetConfigInfo), ([_object, towns] Call GetClosestLocation), _this select 2]};
	case "SecondaryAward": {_txt = Format [Localize "STR_WF_CHAT_Secondary_Award",_this select 1, _this select 2]}; //--- J1 funds authority: DEAD-SENDER case (zero senders in tree) - forgeable wallet write removed, message kept.
	case "StructureTK": {_txt = Format [Localize "STR_WF_CHAT_SatchelTK",_this select 1, _this select 2, [_this select 3, 'displayName'] Call GetConfigInfo, _this select 4]};


    case "HeadHunterReceiveBounty":
    {
        _killer_name = _this select 1; // _killer
        _bounty = _this select 2;
        _structure_kind = _this select 3;
        _structure_side = _this select 4;

        if ((name player) == _killer_name) then
        {
            _txt = format [localize "STR_WF_HeadHunterReceiveBounty", _bounty, ([_structure_kind, "displayName"] call GetConfigInfo)];
            //--- J1 funds authority: credit moved server-side (Server_BuildingKilled.sqf / Server_OnHQKilled.sqf).
            _commandChat = false;
        }
        else
        {
            if ((side group player) == _structure_side) then
            {
                _txt = format [localize "STR_WF_HeadHunterReceiveBountyFriendly", _killer_name, _bounty, ([_structure_kind, "displayName"] call GetConfigInfo)];
            }
            else
            {
                _txt = format [localize "STR_WF_HeadHunterReceiveBountyEnemy", _killer_name, _bounty, ([_structure_kind, "displayName"] call GetConfigInfo)];
            };
            _commandChat = true;
        };
    };
    case "HeadHunterReceiveBountyInSupplies":{
        _side_killer = _this select 1;
        _structure_kind = _this select 2;
        _supplies_bounty = _this select 3;
        _structure_side = _this select 4;

        if (_side_killer != _structure_side) then{
            if(_supplies_bounty > 0)then{
                _txt = format [localize "STR_WF_HeadHunterReceiveSuppliesEnemy", _side_killer, _supplies_bounty, ([_structure_kind, "displayName"] call GetConfigInfo)];
                _commandChat = true;
            };
        }

    };

    //--- B75 (guer-tech FOB): distinct message for clearing a GUER FOB field-base. SAME reward as a normal factory
    //--- kill - the cash bounty is paid here exactly like HeadHunterReceiveBounty (the side-supply bonus, if any, is
    //--- granted server-side in Server_BuildingKilled). Only the wording differs ("Guerrilla FOB cleared/overrun").
    case "GuerFobCleared":
    {
        _killer_name = _this select 1; // _killer
        _bounty = _this select 2;
        _structure_kind = _this select 3;
        _structure_side = _this select 4; // resistance (the FOB owner)

        if ((name player) == _killer_name) then
        {
            _txt = format ["You cleared a Guerrilla FOB (%1) and earned %2!", ([_structure_kind, "displayName"] call GetConfigInfo), _bounty];
            //--- J1 funds authority: credit moved server-side (Server_BuildingKilled.sqf).
            _commandChat = false;
        }
        else
        {
            if ((side group player) == _structure_side) then
            {
                _txt = format ["A Guerrilla FOB (%1) has been overrun!", ([_structure_kind, "displayName"] call GetConfigInfo)];
            }
            else
            {
                _txt = format ["%1 cleared a Guerrilla FOB (%2)!", _killer_name, ([_structure_kind, "displayName"] call GetConfigInfo)];
            };
            _commandChat = true;
        };
    };

    case "BuildingKilledByError":
    {
        _structure_kind = _this select 1;
        _structure_side = _this select 2;

        if ((side group player) == _structure_side) then
        {
            _txt = format [localize "STR_WF_BuildingKilledByErrorFriendly", ([_structure_kind, "displayName"] call GetConfigInfo)];
        }
        else
        {
            _txt = format [localize "STR_WF_BuildingKilledByErrorEnemy", ([_structure_kind, "displayName"] call GetConfigInfo)];
        };
        _commandChat = true;
    };

    case "DefenseBudgetFull": {
        // _this: [1]=category string, [2]=used count, [3]=cap,
        //        [4]=refund — NUMBER (refund directly) or classname STRING (look up the
        //        price this client charged; covers entries the server cannot price).
        //--- cmdcon43-d (Build 88 FIX): a COMMANDER defense is now charged from side SUPPLY (see
        //--- coin_interface.sqf "//--- Defense." block) under WFBE_C_CMD_DEF_SUPPLY + dual-currency,
        //--- so the rejection refund must return SUPPLY, not funds - otherwise a rejected commander
        //--- defense would silently convert supply into personal cash. WFBE_CMD_DEF_SUPPLY_REFUND
        //--- routes the refund to the pool that was actually charged.
        private ["_refArg","_refGet","_refAmt"];
        _refArg = _this select 4;
        _refAmt = 0;
        if (typeName _refArg == "STRING") then {
            _refGet = missionNamespace getVariable _refArg;
            if (!isNil "_refGet") then { _refAmt = _refGet select QUERYUNITPRICE };
        } else {
            if (_refArg > 0) then { _refAmt = _refArg };
        };
        if (_refAmt > 0) then { _refAmt Call WFBE_CMD_DEF_SUPPLY_REFUND };
        _txt = Format [Localize "DefenseBudgetFull", _this select 1, _this select 2, _this select 3];
    };

    case "WddmCompositionCapReached": {
        // _this: [1]=current composition count, [2]=cap, [3]=anchor classname
        // The anchor cost IS charged optimistically on the client at placement
        // (coin_interface.sqf: -(price) Call ChangePlayerFunds). The cap rejected the
        // placement, so refund the exact price this client charged for the anchor.
        private ["_anchorClass","_get"];
        _anchorClass = _this select 3;
        _get = missionNamespace getVariable _anchorClass;
        //--- cmdcon43-d (Build 88 FIX): refund to the pool that was charged (supply for a commander under
        //--- WFBE_C_CMD_DEF_SUPPLY, else funds) - see WFBE_CMD_DEF_SUPPLY_REFUND definition below.
        if (!isNil "_get") then { (_get select QUERYUNITPRICE) Call WFBE_CMD_DEF_SUPPLY_REFUND };
        _txt = Format [Localize "WddmCompositionCapReached", _this select 1, _this select 2];
    };

    //--- AI Commander donation broadcast: teammates see generosity; donor's own confirm is a hint (HandleSpecial "aicom-donate-confirm").
    case "AIComDonation": {_txt = Format [Localize "STR_WF_CHAT_AIComDonation", _this select 1, _this select 2]; _commandChat = true;};

    //--- AI Commander Wildcard event announcement: _this select 1 is the already display-ready message text.
    case "Wildcard": {_txt = _this select 1; _commandChat = true;};
    case "QuartermasterRefit": {_txt = _this select 1; _commandChat = true;}; //--- cmdcon42 TOPUP Option B: server-built quartermaster refit-charge line, UID-targeted at the seated human commander only (Client_HandlePVF STRING-destination filter).

    case "DefenseThreatGate": {
        // _this: [1]=refund — NUMBER (refund directly) or classname STRING (look up the
        //        price this client charged for it; covers WDDM anchors whose price the
        //        server cannot resolve from a single global). Refund, then warn.
        //--- cmdcon43-d (Build 88 FIX): refund via WFBE_CMD_DEF_SUPPLY_REFUND so a commander (charged from
        //--- supply under WFBE_C_CMD_DEF_SUPPLY) is refunded in supply, not funds.
        private ["_refArg","_refGet","_refAmt"];
        _refArg = _this select 1;
        _refAmt = 0;
        if (typeName _refArg == "STRING") then {
            _refGet = missionNamespace getVariable _refArg;
            if (!isNil "_refGet") then { _refAmt = _refGet select QUERYUNITPRICE };
        } else {
            if (_refArg > 0) then { _refAmt = _refArg };
        };
        if (_refAmt > 0) then { _refAmt Call WFBE_CMD_DEF_SUPPLY_REFUND };
        _txt = Localize "DefenseThreatGate";
    };
};

if (_commandChat) then {
	//--- GUARD (2026-06-18): CommandChatMessage can be nil on a client where the command-chat
	//--- function hasn't compiled yet (prior RPT logged 37x 'Error position: <CommandChatMessage').
	//--- Skip the call rather than error out; the message is non-critical chat.
	if (!isNil "CommandChatMessage") then {
		_txt Call CommandChatMessage;
	};
} else {
	if (!isNil "GroupChatMessage") then {
		_txt Call GroupChatMessage;
	};
};
