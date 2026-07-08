Private ['_bankBounty','_bankKey','_bankMarker','_current','_find','_killer','_logik','_structure','_structures','_side','_tked','_type','_killer_uid','_side_killer','_score','_bounty','_supplies','_teamkill'];
_structure = _this select 0;
_killer = _this select 1;
_type = _this select 2;
_side = _structure getVariable "wfbe_side";
if(_side != resistance)then{
  _logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
};
//--- Teamkill?
_teamkill = if (side _killer == _side) then {true} else {false};
_side_killer = side _killer;
_killer_uid = getPlayerUID _killer;
if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_UID_SHOW") == 0) then {_killer_uid = "xxxxxxx"};

//--- B75 (guer-tech FOB): PATH A (normal kills). A resistance kill of an ENEMY (WEST/EAST) Barracks / Light / Heavy
//--- factory grants the GUER side one FOB build token of that type (drives the depot FOB-truck availability + the RHUD
//--- counter). Counts player AND AI GUER kills; excludes teamkills. The null-instigator VBIED case (the FAB-250 blast
//--- carries no killer, so side _killer == civilian here) is EXCLUDED by the resistance gate and credited instead by
//--- PATH B in Server_HandleSpecial.sqf - so there is no double count. Only the three core factory types grant a FOB.
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {!_teamkill} && {_side_killer == resistance} && {_side in [west, east]}) then {
	private ["_fobIdx","_fobAvail"];
	_fobIdx = -1;
	if (_structure isKindOf "Base_WarfareBBarracks") then {_fobIdx = 0};
	if (_structure isKindOf "Base_WarfareBLightFactory") then {_fobIdx = 1};
	if (_structure isKindOf "Base_WarfareBHeavyFactory") then {_fobIdx = 2};
	if (_fobIdx >= 0) then {
		_fobAvail = + (missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]]);
		_fobAvail set [_fobIdx, (_fobAvail select _fobIdx) + 1];
		missionNamespace setVariable ["WFBE_GUER_FOB_AVAIL", _fobAvail];
		publicVariable "WFBE_GUER_FOB_AVAIL";
		["INFORMATION", Format ["Server_BuildingKilled.sqf: GUER FOB token granted (enemy %1 destroyed). Avail now [B %2 | LF %3 | HF %4].", _type, _fobAvail select 0, _fobAvail select 1, _fobAvail select 2]] Call WFBE_CO_FNC_LogContent;
	};
};

if ((!isNull _killer) && (isPlayer _killer)) then
{
    if (_teamkill) then
    {
        [_side, "LocalizeMessage", ["BuildingTeamkill", name _killer, _killer_uid, _type]] call WFBE_CO_FNC_SendToClients;
    }
    else
    {
        Private ['_killerGroup'];
        _killerGroup = group _killer;
        _supplies = 0;
		_bounty = switch (true) do {
        case ( _structure isKindOf "Base_WarfareBBarracks"):{3000};
        case ( _structure isKindOf "Base_WarfareBLightFactory"):{4500};
        case ( _structure isKindOf "Base_WarfareBHeavyFactory"):{7000};
        case ( _structure isKindOf "Base_WarfareBAircraftFactory"):{8000};
        case ( _structure isKindOf "Base_WarfareBUAVterminal"):{5000};
        case ( _structure isKindOf "Base_WarfareBVehicleServicePoint"):{3000};
		case ( _structure isKindOf "BASE_WarfareBAntiAirRadar"):{8000};
        default {3000};
        };

        // Calculate the score gain based on the bounty of the each factory
        _score = switch (true) do {
        case ( _structure isKindOf "Base_WarfareBBarracks"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        case ( _structure isKindOf "Base_WarfareBLightFactory"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        case ( _structure isKindOf "Base_WarfareBHeavyFactory"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        case ( _structure isKindOf "Base_WarfareBAircraftFactory"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        case ( _structure isKindOf "Base_WarfareBUAVterminal"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        case ( _structure isKindOf "Base_WarfareBVehicleServicePoint"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        case ( _structure isKindOf "BASE_WarfareBAntiAirRadar"):{_bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100};
        default {0};
	   };

	   //--- B75 (guer-tech FOB): clearing a GUER (resistance) FOB field-base shows a DISTINCT message with the SAME
	   //--- reward - the GuerFobCleared handler pays the same cash bounty, and a FOB barracks keeps its +500 side-supply
	   //--- bonus (granted silently here). All resistance Barracks/Light/Heavy factories in this mission are FOBs.
	   if ((_side == resistance) && {(_structure isKindOf "Base_WarfareBBarracks") || (_structure isKindOf "Base_WarfareBLightFactory") || (_structure isKindOf "Base_WarfareBHeavyFactory")}) then
	   {
            if (_structure isKindOf "Base_WarfareBBarracks") then {[_side_killer, 500, "GUER FOB barracks cleared", false] Call ChangeSideSupply};
            [_side_killer, "LocalizeMessage", ["GuerFobCleared", (name _killer), _bounty, _type, _side]] call WFBE_CO_FNC_SendToClients;
            //--- fable/fob-marker: drop the resistance-only active-FOB marker (name = deterministic from pos).
            private ["_fobMkPos"];
            _fobMkPos = getPos _structure;
            [resistance, "WildcardMarker", ["delete", Format ["guer_fob_%1_%2", floor (_fobMkPos select 0), floor (_fobMkPos select 1)]]] Call WFBE_CO_FNC_SendToClients;
            //--- fable/fob-polish: retire the FOB from the server-side ledger (the JIP marker-replay source).
            private ["_fobMkName","_fobActive","_fobKeep"];
            _fobMkName = Format ["guer_fob_%1_%2", floor (_fobMkPos select 0), floor (_fobMkPos select 1)];
            _fobActive = missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []];
            _fobKeep = [];
            {if ((_x select 0) != _fobMkName) then {_fobKeep = _fobKeep + [_x]}} forEach _fobActive;
            missionNamespace setVariable ["WFBE_GUER_FOB_ACTIVE", _fobKeep];
       }
       else
       {
	   if(typeof _structure == "Gue_WarfareBBarracks")then
	   {
           	_bounty = 3000;
            _supplies = 500;
            _score = _bounty * (missionNamespace getVariable "WFBE_C_UNITS_BOUNTY_COEF") / 100; // Recalculate the score from the guerilla barracks

            [_side_killer, "LocalizeMessage", ["HeadHunterReceiveBountyInSupplies", _side_killer, _type, _supplies, _side]] call WFBE_CO_FNC_SendToClients;
            [_side_killer, "LocalizeMessage", ["HeadHunterReceiveBounty", (name _killer), _bounty, _type, _side]] call WFBE_CO_FNC_SendToClients;
            [_side_killer, _supplies, "GUER barracks bounty", false] Call ChangeSideSupply;
            }
       else
       {
            [_side_killer, "LocalizeMessage", ["HeadHunterReceiveBounty", (name _killer), _bounty, _type, _side]] call WFBE_CO_FNC_SendToClients;
       };
       };

       //--- B74.2: leaderboard FACTORY-kill credit to the destroying player (real UID, not the display-masked _killer_uid).
       if ((_structure isKindOf "Base_WarfareBLightFactory") || (_structure isKindOf "Base_WarfareBHeavyFactory") || (_structure isKindOf "Base_WarfareBAircraftFactory") || (_structure isKindOf "Base_WarfareBBarracks")) then {private "_facUid"; _facUid = getPlayerUID _killer; if (_facUid != "") then {[_facUid, WFBE_STAT_KILLS_FACTORY, 1] call WFBE_SE_FNC_RecordStat}};

       // Increased the score gain a bit
       _score = _score * 3;

       // Change the score of the leader of the group upon killing a factory
       ['SRVFNCREQUESTCHANGESCORE',[leader _killerGroup, score leader _killerGroup + _score]] Spawn WFBE_SE_FNC_HandlePVF;

       //--- B36 hotfix (Ray 2026-06-15): BUILDINGKILL telemetry for the dashboard "Base Building Kills" board.
       if ((missionNamespace getVariable ["WFBE_C_STATLOG", 0]) == 1) then {
           if (isNil "WFBE_WASPSTAT_SEQ") then { WFBE_WASPSTAT_SEQ = 0 };
           WFBE_WASPSTAT_SEQ = WFBE_WASPSTAT_SEQ + 1;
           diag_log ("WASPSTAT|v1|" + str WFBE_WASPSTAT_SEQ + "|BUILDINGKILL|" + (getPlayerUID _killer) + "|" + (str (side _killer)) + "|" + (str _side) + "|" + (typeOf _structure) + "|" + _type);
       };
    };
};

if (_teamkill) then
{
    ["INFORMATION", Format ["Server_BuildingKilled.sqf: [%1] [%2] has teamkilled a friendly structure.", name _killer, _killer_uid]] Call WFBE_CO_FNC_LogContent;
}
else
{
    ["INFORMATION", Format ["Server_BuildingKilled.sqf: [%1] Structure [%2] has been destroyed by [%3].", str _side, _type, _killer]] Call WFBE_CO_FNC_LogContent;
};

//--- Radio Tower special case: recompute the per-side alive-any registry + re-broadcast the public flag
//--- the client-side WASP\Radio\Radio_Manager.sqf gate reads. No cleanup exists if the flag is off (matches CBR).
if ((_structure getVariable ["wfbe_structure_type", ""]) == "RadioTower" && (missionNamespace getVariable ["WFBE_C_STRUCTURES_RADIOTOWER", 0]) > 0) then {
	private ["_rtKey","_rtAliveVar","_rtRegistry","_rtAnyAlive"];
	_rtKey = if (_side == west) then {"WFBE_RADIOTOWER_WEST"} else {"WFBE_RADIOTOWER_EAST"};
	_rtAliveVar = if (_side == west) then {"WFBE_RADIOTOWER_WEST_ALIVE"} else {"WFBE_RADIOTOWER_EAST_ALIVE"};
	_rtRegistry = missionNamespace getVariable [_rtKey, []];
	_rtAnyAlive = false;
	{if (!isNull _x && {alive _x}) exitWith {_rtAnyAlive = true}} forEach _rtRegistry;
	missionNamespace setVariable [_rtAliveVar, _rtAnyAlive];
	publicVariable _rtAliveVar;
	["INFORMATION", Format ["Server_BuildingKilled.sqf: [%1] RadioTower destroyed. Any-alive now %2.", str _side, _rtAnyAlive]] Call WFBE_CO_FNC_LogContent;
};

//--- Bank special case: raid reward split, global broadcast, registry cleanup + marker delete.
if ((_structure getVariable ["wfbe_structure_type", ""]) == "Bank" && (missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	_bankKey = if (_side == west) then {"WFBE_BANK_WEST"} else {"WFBE_BANK_EAST"};
	missionNamespace setVariable [_bankKey, objNull];
	_bankMarker = _structure getVariable ["wfbe_bank_marker", ""];
	if (_bankMarker != "") then {deleteMarker _bankMarker};
	if ((!isNull _killer) && (isPlayer _killer) && !_teamkill) then {
		//--- Balance review 2026-06-10: a flat 150k to one player was a whale mechanic
		//--- (~4-5 attack helicopters to a single wallet). Split instead: the raiding SIDE
		//--- gains supply (commander resource — mirrors the guerrilla-barracks side-supply
		//--- award above), the killer gets a personal cash bonus. ChangeSideSupply clamps
		//--- at the supply ceiling, so the +40000 is safe near the cap.
		//--- Rebalance (Steff 2026-06-11): supply 40000 -> 10000, killer cash 7500 -> 25000
		//--- (shift the reward from the commander pool to the player who pulls it off).
		_bankBounty = 25000;
		[(side group _killer), 10000, "Bank destruction", false] Call ChangeSideSupply;
		[getPlayerUID _killer, "BankPayout", [_bankBounty]] Call WFBE_CO_FNC_SendToClients; //--- E5: route the $25k payout by the REAL UID, not the display-masked _killer_uid ("xxxxxxx" when WFBE_C_GAMEPLAY_UID_SHOW==0 -> no client matched -> $0 paid)
		//--- Global broadcast: everyone hears the bank fell.
		private ["_sideName"];
		_sideName = if (_side == west) then {"Federal Reserve"} else {"Bank Rossii"};
		[nil, "LocalizeMessage", ["BankDestroyed", name _killer, _sideName]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Server_BuildingKilled.sqf: [%1] Bank destroyed by [%2]. +10000 side supply, $%3 killer bonus.", str _side, name _killer, _bankBounty]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Decrement building limit.
if(_side != resistance)then{
    _find = (missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',_side]) find _type;
    if (_find != -1) then {
    	_current = _logik getVariable "wfbe_structures_live";
    	_current set [_find - 1, (_current select (_find-1)) - 1];
    	_logik setVariable ["wfbe_structures_live", _current, true];
    };

    _logik setVariable ["wfbe_structures", (_logik getVariable "wfbe_structures") - [_structure, objNull], true];

    [_side, "Destroyed", ["Base", _structure]] Spawn SideMessage;
} else {
    //--- B75 (guer-tech FOB): a destroyed GUER FOB factory MUST leave the registry too, or it lingers as a phantom
    //--- spawn/production point (the original code skipped resistance because GUER had no factories before FOBs). No
    //--- commander cap to decrement. WFBE_L_GUE may be a Group -> plain getVariable (A2-OA-safe, mirrors Construction).
    private ["_gLogik"];
    _gLogik = (resistance) Call WFBE_CO_FNC_GetSideLogic;
    if (!isNull _gLogik && {!isNil {_gLogik getVariable "wfbe_structures"}}) then {
        _gLogik setVariable ["wfbe_structures", (_gLogik getVariable "wfbe_structures") - [_structure, objNull], true];
    };
    [resistance, "Destroyed", ["Base", _structure]] Spawn SideMessage;
};
sleep 10;

deleteVehicle _structure;
