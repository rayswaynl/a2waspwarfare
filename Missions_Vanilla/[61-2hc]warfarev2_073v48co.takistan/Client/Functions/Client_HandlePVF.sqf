/*
	Client receives PVF Here.
	 Parameters:
		- Client PVF
*/

Private ["_code","_destination","_exit","_hcAllowed","_isHeadless","_parameters","_publicVar","_script"];

_publicVar = _this;
_exit = true;

_destination = _publicVar select 0;
_script = _publicVar select 1;
_parameters = if (count _this > 2) then {_publicVar select 2} else {[]};

_isHeadless = if !(isNil "isHeadLessClient") then {isHeadLessClient} else {!(hasInterface || isDedicated)};
if (_isHeadless) then {
	_hcAllowed = false;
	if (_script == "CLTFNCHandleSpecial" && {(typeName _parameters) == "ARRAY"} && {(count _parameters) > 0}) then {
		//--- HC-targeted HandleSpecial allowlist - ALL HC-destined actions and their server-side senders:
		//---   delegate-townai            = Server_DelegateAITownHeadless (per-town AI ownership)
		//---   delegate-ai-static-defence = Server_DelegateAIStaticDefenceHeadless (garrison posts)
		//---   cleanup-townai             = server_town_ai (nil broadcast; tears down town AI on capture)
		//---   cleanup-airfield-garrison  = server_town + server_town_ai (nil broadcast; clears airfield post)
		//---   delegate-aicom-team        = AI_Commander_Teams + AI_Commander_Wildcard + Init_ZgKoth (team founding)
		//---   delegate-sidepatrol        = server_side_patrols (patrol founding; Wildcard bonus-patrol sender culled 2026-07-08, owner pick B7)
		//---   cleanup-commander-arty-wreck = server_groupsGC.sqf (fix/aicom-arty-lifecycle 2026-07-21; deletes a
		//---        dead commander-artillery hull that is local to this HC - the reaper cannot delete it directly)
		//---   cleanup-commander-heli-wreck = server_groupsGC.sqf (fix/heli-husk-reaper; deletes a dead
		//---        commander-attack-heli hull that is local to this HC - the reaper cannot delete it directly)
		//--- NOTE: aicom-team-merge is intentionally excluded (no active sender; WFBE_C_AICOM_HC_MERGE_ENABLE
		//---        defaults to 0, no DRAFT worker registered, nil-guarded in AI_Commander.sqf).
		//---   cleanup-trash-object      = Common_TrashObject.sqf (2026-07-21 locality gate, WFBE_C_TRASH_REMOTE_DELETE
		//---        default 0; deletes a DEAD, reap-stamped body/hull that is local to this HC - the server cannot)
		_hcAllowed = ((_parameters select 0) in ["delegate-townai","delegate-ai-static-defence","cleanup-townai","cleanup-airfield-garrison","delegate-aicom-team","delegate-sidepatrol","cleanup-commander-arty-wreck","cleanup-commander-heli-wreck","cleanup-trash-object"]);
	};
	if (_hcAllowed) then {_exit = false};
};
//--- fix(hunt): the old `if !(_hcAllowed) exitWith {}` sat INSIDE the then{} above - it exited only that
//--- block and FELL THROUGH, and the nil-destination / side-match re-opens below then re-armed _exit=false
//--- for every broadcast (endgame cameras, irsmoke FX, DashboardAnnounce... all ran on interface-less HCs,
//--- HCs auto-seat a WEST slot so SIDE-scoped sends matched too). Top-scope exit makes the allowlist real.
if (_isHeadless && {!_hcAllowed}) exitWith {};

if (isNil '_destination') then {_destination = 0;_exit = false};
if (typeName(_destination) == 'SIDE') then {if !(isNil "sideJoined") then {if (sideJoined == _destination) then {_exit = false}}};
if (typeName(_destination) == 'STRING') then {if (isMultiplayer) then {if (getPlayerUID player == _destination) then {_exit = false}} else {_exit = true}};

if (_exit) exitWith {};

if (isNil "WFBE_CL_PVF_ALLOWED" || {!(_script in WFBE_CL_PVF_ALLOWED)}) exitWith {
	["WARNING", Format ["Client_HandlePVF.sqf: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};

_code = missionNamespace getVariable _script;
if (isNil "_code" || {typeName _code != "CODE"}) exitWith {
	["WARNING", Format ["Client_HandlePVF.sqf: registered PVF handler [%1] is not CODE.", _script]] Call WFBE_CO_FNC_LogContent;
};

_parameters Spawn _code;
