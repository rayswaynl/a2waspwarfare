/*
	Triggered whenever the HQ is killed.
	 Parameters:
		- HQ
		- Shooter
*/

Private ["_wreckObject", "_building","_dammages","_dammages_current","_get","_killer","_logik","_origin","_structure","_structure_kind","_killerGroup"];

_structure = _this select 0;
_killer = _this select 1;

//--- DR-20: server-local killed EHs plus client process-killed-hq relays can replay the same HQ death.
//--- Keep redundant detection, but let this consumer process each HQ object once.
if (_structure getVariable ["wfbe_hq_killed_done", false]) exitWith {};
_structure setVariable ["wfbe_hq_killed_done", true, true];

// Marty : object that must be tracked by the HQ wreck marker.
_wreckObject = _structure;

_structure_kind = typeOf _structure;
_side = _structure getVariable "wfbe_side";
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
_killerGroup = group _killer;

_killer_group = group _killer;
// HQ kill price ($30,000) / 100 * building kill coef
_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF;

//--- If HQ was mobibilized, spawn a dead hq.
if ((_side) Call WFBE_CO_FNC_GetSideHQDeployStatus) then {
	Private ["_hq"];
	_hq = [missionNamespace getVariable Format["WFBE_%1MHQNAME", _side], getPos _structure, (_side) Call WFBE_CO_FNC_GetSideID, getDir _structure, false, false, false] Call WFBE_CO_FNC_CreateVehicle;
	_hq setPos (getPos _structure);
	_hq setVariable ["wfbe_trashable", false];
	_hq setVariable ["wfbe_side", _side];
	_hq setDamage 1;

	// Marty : from now on, the marker must track the newly created dead MHQ wreck,
	// not the deployed HQ structure that will be deleted after 10 seconds.
	_wreckObject = _hq;

	//--- HQ is now considered mobilized.
	_logik setVariable ["wfbe_hq_deployed", false, true];
	_logik setVariable ["wfbe_hq",_hq,true];

	//--- Release fix: delete the deployed-HQ shield walls too. They are created on deploy
	//--- (Construction_HQSite.sqf) and were previously cleaned ONLY on mobilize, so a DESTROYED
	//--- deployed HQ left ~23 concrete objects orphaned on the map every destroy/redeploy cycle.
	{if (!isNull _x) then {deleteVehicle _x}} forEach (_structure getVariable ["wfbe_hq_walls", _structure getVariable ["WFBE_Walls", []]]);

	//--- Remove the structure after the burial.
	(_structure) Spawn {sleep 10; deleteVehicle _this};
};

//--- B69 S6 : base-fall spectacle. This fires ONCE per (rare) HQ destruction, so spawning
//--- a single server-side black smoke column on the wreck is count-safe (one object, no loop).
//--- _wreckObject already tracks the persistent wreck (the dead MHQ for a deployed HQ, else the
//--- structure itself). SmokeShellBlack is a vanilla A2-OA class. Toggleable via a missionNamespace
//--- constant so the dedicated constants agent can default/disable it without touching this file;
//--- the [name,default] getVariable form is reliable on missionNamespace.
if (isServer && (missionNamespace getVariable ["WFBE_C_BASEFALL_SMOKE_ENABLED", true])) then {
	Private ["_smoke"];
	_smoke = "SmokeShellBlack" createVehicle (getPos _wreckObject);
	_smoke setPos (getPos _wreckObject);
};

//--- Teamkill? [_side, "SendMessage", ["command", "tkill", [name _killer, _structure_kind]]] Call WFBE_CO_FNC_SendToClients
//--- DR-50 (cmdcon41-w3f): compute the teamkill flag BEFORE any score award (it was computed below,
//--- AFTER the award, so the award fired even on a teamkill). Same test as the old inline form.
_teamkill = if (side _killer == _side) then {true} else {false};

//--- DR-50 (cmdcon41-w3f): award the HQ-kill points EXACTLY ONCE, and ONLY on a clean enemy kill.
//--- Previously this award was UNCONDITIONAL (paid on teamkills too), and a SECOND guarded award of a
//--- hardcoded 900 fired below on clean kills - so a clean enemy HQ kill paid TWICE and a teamkill paid
//--- ONCE. Gate the single canonical (coef-scaled _points) award on non-teamkill; the duplicate 900
//--- block below is removed. Net: clean enemy kill pays _points once; teamkill pays nothing.
if (!_teamkill) then {
	if (isServer) then {
		['SRVFNCREQUESTCHANGESCORE',[leader _killer_group, (score leader _killer_group) + _points]] Spawn WFBE_SE_FNC_HandlePVF;
	} else {
		["RequestChangeScore", [leader _killer_group, (score leader _killer_group) + _points]] Call WFBE_CO_FNC_SendToServer;
	};
};

//--- Spawn a radio message.
[_side, "Destroyed", ["Base", _structure]] Spawn SideMessage;


_killer_uid = getPlayerUID _killer;
//if (!paramShowUID) then {_killer_uid = "xxxxxxx"};

if ((!isNull _killer) && (isPlayer _killer)) then
{
    if (_teamkill) then
    {
        [_side, "LocalizeMessage", ["BuildingTeamkill", name _killer, _killer_uid, _structure_kind]] call WFBE_CO_FNC_SendToClients;
    }
    else
    {
        [nil, "LocalizeMessage", ["HeadHunterReceiveBounty", (name _killer), 30000, _structure_kind, _side]] call WFBE_CO_FNC_SendToClients;
        //--- B74.2: leaderboard HQ-kill credit to the destroying player (real UID; _killer_uid is unmasked here).
        if (_killer_uid != "") then {[_killer_uid, WFBE_STAT_KILLS_HQ, 1] call WFBE_SE_FNC_RecordStat};
    };
};

//--- B69 S6 : server-wide audible sting for the base fall. Reuses the exact SendToClients idiom
//--- already used above (nil recipient = all clients) and the existing LocalizeMessage dispatch.
//--- "inbound" is a confirmed CfgSounds class (Sounds/description.ext; also used by
//--- Common_HandleAlarm.sqf and CampCaptured.sqf). The client plays the sound; no chat line.
//--- REQUIRED COMPANION EDIT (do NOT make it here — different owner's file):
//---   Client/PVFunctions/LocalizeMessage.sqf must add a matching case BEFORE this ships:
//---     case "BaseFallSting": { playSound ["inbound", true]; _commandChat = false; };
//---   (_txt stays "" + _commandChat=false => the sound plays with NO chat line.)
//---   WITHOUT that case the switch falls through with _commandChat still true and _txt="",
//---   which would print a BLANK command-chat line on every client per HQ kill — so the
//---   companion case is a hard prerequisite, not optional. The broadcast itself uses the same
//---   nil-recipient SendToClients idiom as the HeadHunter bounty broadcast above.
[nil, "LocalizeMessage", ["BaseFallSting"]] call WFBE_CO_FNC_SendToClients;

//--- DR-50 (cmdcon41-w3f): the duplicate "award 900 on non-teamkill" block that used to live here was
//--- removed - it double-paid a clean HQ kill on top of the (now teamkill-gated) _points award above.
//--- The single canonical award is the coef-scaled _points, paid once, only when !_teamkill.

// Marty : HQ wreck marker data.
// The marker itself is created locally on allied clients only.
// Do not create a global marker here, otherwise the enemy team may see it too.
_marker_name 		= "HQ_WRECK_" + str(_side);
_marker_position 	= getPos _wreckObject;
_markerType 		= "Flag";
_markerText 		= "HQ WRECK must be repaired";
_markerColor 		= "ColorRed";
_markerSide			= _side;

//[_marker_name, _marker_position, _markerType, _markerText, _markerColor, _markerSide] call WF_createMarker ;

// Marty : Public variables about hq state are broadcasted for the future player joining the game :
if (_side == west) then 
{
	missionNamespace setVariable ["IS_WEST_HQ_ALIVE", false];
	publicVariable "IS_WEST_HQ_ALIVE";

	_hq_west_marker_infos = [_marker_name, _marker_position, _markerType, _markerText, _markerColor, _markerSide, _wreckObject]; 
	missionNamespace setVariable ["HQ_WEST_MARKER_INFOS", _hq_west_marker_infos];
	publicVariable "HQ_WEST_MARKER_INFOS";
};

if (_side == east) then 
{
	missionNamespace setVariable ["IS_EAST_HQ_ALIVE", false];
	publicVariable "IS_EAST_HQ_ALIVE";

	_hq_east_marker_infos = [_marker_name, _marker_position, _markerType, _markerText, _markerColor, _markerSide, _wreckObject]; 
	missionNamespace setVariable ["HQ_EAST_MARKER_INFOS", _hq_east_marker_infos];
	publicVariable "HQ_EAST_MARKER_INFOS";
};
// Marty end.

["INFORMATION", Format["Server_OnHQKilled.sqf : [%1] HQ [%2] has been destroyed by [%3], Teamkill? [%4], Side Teamkill? [%5]", _side, _structure_kind, name _killer, _teamkill, side _killer]] Call WFBE_CO_FNC_LogContent;

//--- MATCH|v1|MILESTONE|HQ_DESTROYED|: narrative beat for HQ kills (teamkills excluded).
//--- _side = the side whose HQ was destroyed (the losing side for this milestone).
if ((!_teamkill) && {(missionNamespace getVariable ["WFBE_C_MATCH_TELEMETRY", 1]) > 0}) then {
	diag_log ("MATCH|v1|MILESTONE|HQ_DESTROYED|side=" + str _side + "|tMin=" + str (round (time / 60)));
};
