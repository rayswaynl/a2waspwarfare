/*
	Grok idea #28 (player QoL): when the AI commander's stuck-recovery ladder fires tier 2+ on
	one of a side's AI teams (UNSTUCK_FIRED, see Common_RunCommanderTeam.sqf and
	Common_RunUnstuckRecovery.sqf), a human commander watching that squad teleport/reverse has
	no idea why. This sends ONE brief advisory line to the seated HUMAN COMMANDER OF THAT SIDE
	ONLY, rate-limited per team.

	Flag-gated: WFBE_C_AICOM_RECOVERY_NOTIFY default 0. At default this function still compiles
	(cheap, no loop) but every call exitWiths on the first line - zero effect, zero side-channel
	traffic, byte-identical runtime behaviour to before this file existed.

	Reuses the EXISTING "cmdv2-receipt" HandleSpecial channel (already used by
	Server_CmdSupportAir.sqf / Server_HandleSpecial.sqf to deliver plain advisory strings to a
	single seated human commander, e.g. "Suggested X doctrine to AI team N.") via the existing
	WFBE_CO_FNC_SendToClient single-client PVF dispatcher - no new PV endpoint is added.

	isServer-gated (see call sites): Common_RunCommanderTeam.sqf's recovery Spawn and the
	Common_RunUnstuckRecovery.sqf bridge both explicitly document that they may run on ANY
	machine the team is local to (server or an HC), mirroring the file's existing isServer-only
	side-effect blocks (funds, disband, etc.) rather than assuming publicVariableClient behaves
	identically off the server. Net effect: a team local to the server gets notified; a team
	currently delegated to an HC does not get a notify from that HC cycle (byte-identical to how
	every other isServer-gated effect in Common_RunCommanderTeam.sqf already behaves) - this is a
	scoped QoL notification, not a data path that legitimately needs HC-side delivery.

	Params: [_team, _tier, _side].
*/

Private ["_nTeam","_nTier","_nSide","_nMinTier","_nCd","_nNow","_nLast","_nLogic","_nCmdTeam","_nCmdLdr","_nTeams","_nIdx","_nLabel","_nMsg"];

if ((missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOTIFY", 0]) <= 0) exitWith {};
if (!isServer) exitWith {};

_nTeam = _this select 0;
_nTier = _this select 1;
_nSide = _this select 2;

if (isNull _nTeam || {_nSide == civilian}) exitWith {};

_nMinTier = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOTIFY_MIN_TIER", 2];
if (_nTier < _nMinTier) exitWith {};

//--- Rate-limit: at most one notify per TEAM per cooldown window. Groups reject the 2-arg
//--- [name,default] getVariable form (G1 house doctrine) - plain get + isNil.
_nCd = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOTIFY_COOLDOWN", 300];
_nNow = time;
_nLast = _nTeam getVariable "wfbe_aicom_recovery_notify_last"; if (isNil "_nLast") then {_nLast = -1e6};
if ((_nNow - _nLast) < _nCd) exitWith {};

_nLogic = (_nSide) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _nLogic) exitWith {};

//--- wfbe_commander is the side's currently-seated commander TEAM (grpNull when AI-run); its
//--- leader is the human player, when one is seated. No seated human commander = nothing to
//--- notify (this is a commander-facing QoL line, not a general side broadcast).
_nCmdTeam = _nLogic getVariable "wfbe_commander"; if (isNil "_nCmdTeam") then {_nCmdTeam = grpNull};
if (isNull _nCmdTeam) exitWith {};
_nCmdLdr = leader _nCmdTeam;
if (isNull _nCmdLdr || {!isPlayer _nCmdLdr} || {!alive _nCmdLdr}) exitWith {};

//--- Stamp BEFORE the send so a same-tick re-entrant fire on the same team cannot double-send.
_nTeam setVariable ["wfbe_aicom_recovery_notify_last", _nNow];

_nTeams = _nLogic getVariable "wfbe_teams"; if (isNil "_nTeams") then {_nTeams = []};
_nIdx = _nTeams find _nTeam;
_nLabel = if (_nIdx >= 0) then {"AI team " + str _nIdx} else {"An AI-commanded squad"};
_nMsg = _nLabel + " got stuck and the AI commander repositioned it (tier " + str _nTier + " recovery).";

[_nCmdLdr, "HandleSpecial", ["cmdv2-receipt", [_nMsg]]] Call WFBE_CO_FNC_SendToClient;
