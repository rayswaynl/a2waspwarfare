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
		//---   aicom-field-hospital      = AI_Commander_Wildcard (server-local + owner-local healing)
		//---   cleanup-commander-arty-wreck = server_groupsGC.sqf (fix/aicom-arty-lifecycle 2026-07-21; deletes a
		//---        dead commander-artillery hull that is local to this HC - the reaper cannot delete it directly)
		//---   cleanup-commander-heli-wreck = server_groupsGC.sqf (fix/heli-husk-reaper; deletes a dead
		//---        commander-attack-heli hull that is local to this HC - the reaper cannot delete it directly)
		//---   aicom-team-merge          = AI_Commander_HCTopUp (same-owner depleted-team consolidation)
		//---   cleanup-trash-object      = Common_TrashObject.sqf (2026-07-21 locality gate, WFBE_C_TRASH_REMOTE_DELETE
		//---        default 1; deletes a DEAD, reap-stamped body/hull that is local to this HC - the server cannot)
		//---   cleanup-empty-vehicle      = Server_HandleEmptyVehicle.sqf (locality-aware empty-hull reaper; the server cannot
		//---        delete a HC-local alive hull directly, so the owner re-checks the empty/idle state before deleting)
		//---   cleanup-town-defense-gunner = server_town.sqf (fix/alife proper #1370) + Server_OperateTownDefensesUnits.sqf
		//---        "remove" case; deletes a town-defense static gunner (dead OR alive) that is local to this HC -
		//---        the equivalent server-side deletion call on an HC-delegated gunner would silently no-op
		//---   hc-force-reseat            = server_hcreg_heal.sqf (fable/hc-registry-heal-v2; orders a
		//---        registry-orphaned HC to ReseatCivilian + re-announce - group joins are locality-bound
		//---        so the server cannot repair the HC's group itself)
		//---   sidepatrol-watchdog        = server_side_patrols.sqf (WFBE_C_SIDE_PATROL_UNSTUCK; routes the
		//---        external stuck watchdog to this HC when the wedged patrol's leader is HC-local - the
		//---        receiver case already exists in HandleSpecial.sqf; this key was the missing wire-up)
		_hcAllowed = ((_parameters select 0) in ["delegate-townai","delegate-ai-static-defence","cleanup-townai","cleanup-airfield-garrison","delegate-aicom-team","delegate-sidepatrol","aicom-field-hospital","aicom-team-disband-execute","aicom-team-merge","cleanup-commander-arty-wreck","cleanup-commander-heli-wreck","cleanup-trash-object","cleanup-empty-vehicle","cleanup-town-defense-gunner","sidepatrol-watchdog","hc-force-reseat"]);
	};
	if (_hcAllowed) then {_exit = false};
};
//--- fable/wreck-hygiene (owner 2026-07-28 "some hulls still dont get reaped (player owned)"): the
//--- cleanup dispatches route by OBJECT locality, so a player-bought hull's cleanup lands on a REAL
//--- client - where the HC-only bypass above never runs, and the payload's destination field is ""
//--- (getPlayerUID of a VEHICLE, set in Common_SendToClient.sqf), which the UID match below can
//--- never equal for a connected human. The dispatch was therefore PERMANENTLY dropped, and the
//--- wfbe_trashed pre-stamp then blocks every later safety-net sweep - the exact "lingers forever".
//--- Allow the two SELF-VALIDATING cleanup cases through on normal clients: their receivers
//--- (Client\PVFunctions\HandleSpecial.sqf) re-check local + dead/empty + reap-stamp + zero live
//--- crew + airlift/GUER-FOB protections before deleting, so a stale or mis-routed dispatch cannot
//--- touch a live or re-crewed vehicle. Correctness fix: this path executing was always the design
//--- (WFBE_C_TRASH_REMOTE_DELETE default 1) - only the HC-era gate made it HC-exclusive.
if (!_isHeadless && {_script == "CLTFNCHandleSpecial"} && {(typeName _parameters) == "ARRAY"} && {(count _parameters) > 0}) then {
	if ((_parameters select 0) in ["cleanup-trash-object","cleanup-empty-vehicle"]) then {_exit = false};
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
