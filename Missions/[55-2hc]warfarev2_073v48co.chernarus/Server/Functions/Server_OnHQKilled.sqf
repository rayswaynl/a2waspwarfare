/*
	Triggered whenever the HQ is killed.
	 Parameters:
		- HQ
		- Shooter
*/

Private ["_wreckObject", "_building","_dammages","_dammages_current","_get","_killer","_logik","_origin","_structure","_structure_kind","_killerGroup"];

_structure = _this select 0;
_killer = _this select 1;

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

//--- wiki-wins (Ray's call: single 900, teamkills score 0): removed the UNCONDITIONAL _points award here.
//--- It double-paid a legit HQ kill (_points + the 900 _score below = ~1800) and still paid teamkillers _points.
//--- The single, teamkill-guarded 900 award now lives solely in the `_side != side _killer` block further down.

//--- Spawn a radio message.
[_side, "Destroyed", ["Base", _structure]] Spawn SideMessage;

//--- Teamkill? [_side, "SendMessage", ["command", "tkill", [name _killer, _structure_kind]]] Call WFBE_CO_FNC_SendToClients
_teamkill = if (side _killer == _side) then {true} else {false};


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

// Only awards score for non-teamkills of the HQ
if (_side != side _killer) then
{
    Private ["_score"];
    _score = 900; // HQ bounty award / 100*3

    // Change the score of the leader of the group upon killing the hq
    ['SRVFNCREQUESTCHANGESCORE',[leader _killerGroup, score leader _killerGroup + _score]] Spawn WFBE_SE_FNC_HandlePVF;
};

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
