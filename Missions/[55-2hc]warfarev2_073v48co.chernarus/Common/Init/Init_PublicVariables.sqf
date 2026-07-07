/*
	Global Public Variable Functions Initialization, this file initialize PVF files for both the client and the server
*/

scriptName "Common\Init\Init_PublicVariables.sqf";

Private ['_clientCommandPV','_l','_serverCommandPV'];

_l		= ["RequestVehicleLock"];
_l = _l + ["RequestOnUnitKilled"];
_l = _l + ["RequestChangeScore"];
_l = _l + ["RequestCommanderVote"];
_l = _l + ["RequestNewCommander"];
_l = _l + ["RequestClaimCommander"]; //--- mid-round "TAKE COMMAND" claim of an empty (AI-run) commander seat (Server\PVFunctions\RequestClaimCommander.sqf).
_l = _l + ["RequestStructure"];
_l = _l + ["RequestFOBStructure"]; //--- B75 (guer-tech): GUER FOB field-factory build (Server\PVFunctions\RequestFOBStructure.sqf).
_l = _l + ["RequestDefense"];
_l = _l + ["RequestJoin"];
_l = _l + ["RequestFundsResend"]; //--- B76 (Ray 2026-06-29): JIP funds self-heal - client asks the server to re-broadcast its own-group wfbe_funds when a slow team-sync left it with $0 (Server\PVFunctions\RequestFundsResend.sqf).
_l = _l + ["RequestFundsRecord"]; //--- Ray pick A (2026-07-03): funds-record lock-step - after a CLIENT-side spend/credit the client asks the server to snapshot its own-group (broadcast, authoritative) wfbe_funds into WFBE_JIP_USER<uid> so a later record-based JIP zero-recovery is provably safe (Server\PVFunctions\RequestFundsRecord.sqf).
_l = _l + ["RequestTeamsResend"]; //--- cmdcon26 (Game 2026-06-29): JIP teams/structure self-heal - client asks the server to re-broadcast its own-side side-logic wfbe_teams (+ wfbe_hq/wfbe_structures) when a slow side-logic sync left own-side arrows + HQ marker missing (Server\PVFunctions\RequestTeamsResend.sqf).
_l = _l + ["RequestMHQRepair"];
_l = _l + ["RequestSpecial"];
_l = _l + ["RequestTeamUpdate"];
_l = _l + ["RequestUpgrade"];
_l = _l + ["RequestAutoWallConstructinChange"];
_l = _l + ["RequestEnqueue"];
_l = _l + ["RequestDequeue"];
_l = _l + ["CounterBatteryFired"];
_l = _l + ["RequestSiteClearance"];
_l = _l + ["RequestAIComDonate"];
_l = _l + ["HCStat"];
_l = _l + ["RequestAFKKick"]; //--- SG14: client reports AFK threshold exceeded; server validates and issues the BE kick.
_l = _l + ["RequestGDirPanel"]; //--- A1 (Commissar Panel): GUER player buy/contract request -> server validates, debits wallet, emits GDIR_ORDER, pushes result to caller (Server\PVFunctions\RequestGDirPanel.sqf).

_serverCommandPV = _l;

_l =      ["AllCampsCaptured"];
_l = _l + ["AwardBounty"];
_l = _l + ["AwardBountyPlayer"];
_l = _l + ["CampCaptured"];
_l = _l + ["ChangeScore"];
//_l = _l + ["DatabaseDebug"];
_l = _l + ["HandleSpecial"];
_l = _l + ["HandleParatrooperMarkerCreation"];
_l = _l + ["LocalizeMessage"];
_l = _l + ["WildcardMarker"]; //--- wildcard map markers: side-restricted local marker create/delete (Client\PVFunctions\WildcardMarker.sqf).
_l = _l + ["SetTask"];
_l = _l + ["SetVehicleLock"];
_l = _l + ["TownCaptured"];
_l = _l + ["SetMHQLock"];
_l = _l + ["Available"];
_l = _l + ["RequestBaseArea"];
_l = _l + ["NukeIncoming"];
_l = _l + ["SpotterMarkContact"]; //--- team-intel-pack: side-scoped spotter mark (Client\PVFunctions\SpotterMarkContact.sqf).
_l = _l + ["CounterBatteryContact"];
_l = _l + ["BankPayout"];
_l = _l + ["RestartAnnounce"];
_l = _l + ["DashboardAnnounce"];
_l = _l + ["GDirPanelResult"]; //--- A1 (Commissar Panel): server pushes action result back to the requesting GUER client (Client\PVFunctions\GDirPanelResult.sqf).

_clientCommandPV = _l;

WFBE_CL_PVF_ALLOWED = [];
WFBE_SE_PVF_ALLOWED = [];

{
	Call Compile Format["CLTFNC%1 = compile preprocessFileLineNumbers 'Client\PVFunctions\%1.sqf'", _x];
	WFBE_CL_PVF_ALLOWED = WFBE_CL_PVF_ALLOWED + [Format["CLTFNC%1", _x]];
	if (!isServer || local player) then {Format['WFBE_PVF_%1',_x] addPublicVariableEventHandler {(_this select 1) Spawn WFBE_CL_FNC_HandlePVF}};
} forEach _clientCommandPV;

{
	Call Compile Format["SRVFNC%1 = compile preprocessFileLineNumbers 'Server\PVFunctions\%1.sqf'", _x];
	WFBE_SE_PVF_ALLOWED = WFBE_SE_PVF_ALLOWED + [Format["SRVFNC%1", _x]];
	if (isServer) then {Format['WFBE_PVF_%1',_x] addPublicVariableEventHandler {(_this select 1) Spawn WFBE_SE_FNC_HandlePVF}};
} forEach _serverCommandPV;

["INITIALIZATION", Format ["Init_PublicVariables.sqf : Initialized [%1] Client PV and [%2] Server PV", count _clientCommandPV, count _serverCommandPV]] Call WFBE_CO_FNC_LogContent;

//--- P2 (fable/gdir-harden-shop): GDIR JIP snapshot seed + PVEH.
//--- Server publishes AICOMV2_GDIR_JIP_SNAP each director tick (throttled).
//--- Clients cache the last snapshot in WFBE_COMM_GDIR_SNAP for the commissar panel list.
//--- TODO (OnPlayerConnected): add publicVariableClient "AICOMV2_GDIR_JIP_SNAP" to
//--- Server/Functions/Server_OnPlayerConnected.sqf after line 161 (WFBE_GUER_FOB_AVAIL block)
//--- so late joiners get the snapshot immediately rather than waiting for the next Director tick.
//--- 185 (HQ repair scaling): seed avg on all machines; server overwrites via publicVariable at init.
WFBE_HQ_REPAIR_AVG_SEC = 21600;
if (!isServer || {local player}) then {
    "WFBE_HQ_REPAIR_AVG_SEC" addPublicVariableEventHandler {
        WFBE_HQ_REPAIR_AVG_SEC = _this select 1;
    };
};

AICOMV2_GDIR_JIP_SNAP = [];
if (!isServer || {local player}) then {
    "AICOMV2_GDIR_JIP_SNAP" addPublicVariableEventHandler {
        WFBE_COMM_GDIR_SNAP = _this select 1;
    };
};
