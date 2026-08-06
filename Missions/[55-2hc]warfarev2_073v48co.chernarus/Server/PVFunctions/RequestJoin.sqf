private ["_canJoin","_name","_player","_side","_uid","_skillBLUFOR","_skillOPFOR","_hasConnectedAtLaunchToSide","_teamJoinedConfirmed"];

_player = _this select 0;
_side = _this select 1;
//--- r70: reject null/non-object player before name/UID.
if (isNil "_player" || {typeName _player != "OBJECT"} || {isNull _player}) exitWith {
	["WARNING", "RequestJoin.sqf: null player - join request ignored."] Call WFBE_CO_FNC_LogContent;
};
_name = name _player;

_uid = getPlayerUID(_player);
//--- Invalid/local-host UIDs are not identities: never allow them into shared JIP keyspace.
if (_uid == "" || {_uid == "0"}) exitWith {};
_canJoin = true;

_teamJoinedConfirmed = missionNamespace getVariable Format["WFBE_JIP_USER%1_TEAM_JOINED", _uid];
_hasConnectedAtLaunchToSide = missionNamespace getVariable format ["WFBE_PLAYER_%1_CONNECTED_AT_LAUNCH", _uid];
//--- CASTER SEATS ARE NOT A TEAM (owner live repro 2026-08-02: sat in the CIV caster seat, then was
//--- denied "teamswap from CIV to WEST" and lobby-bounced). CIV is an OBSERVER seat: a stored CIV
//--- side must never lock a player out of a real team, and moving INTO the caster seat is always
//--- allowed. Treat any stored civilian as "no previous side" (protection still applies between the
//--- real teams W/E), and a civilian JOIN target skips the checks entirely.
if (!(isNil "_teamJoinedConfirmed") && {_teamJoinedConfirmed == civilian}) then {_teamJoinedConfirmed = nil};
if (!(isNil "_hasConnectedAtLaunchToSide") && {_hasConnectedAtLaunchToSide == civilian}) then {_hasConnectedAtLaunchToSide = nil};
if (_side == civilian) then {
	["INFORMATION", Format["RequestJoin.sqf: [%1] [%2] entering the CIV caster/observer seat - teamswap checks skipped (not a team).", _name, _uid]] Call WFBE_CO_FNC_LogContent;
};

_skillBLUFOR = 0;
_skillOPFOR = 0;
_reason = "";

if ( !(isNil "_teamJoinedConfirmed")) then { //--- Retrieve JIP Information if there's any.

	if (_teamJoinedConfirmed != _side) then {

		_canJoin = false;
		[_player, "LocalizeMessage", ['Teamswap',_name,_uid,_teamJoinedConfirmed,_side]] Call WFBE_CO_FNC_SendToClient; //--- r70: address the joining unit (leader group can be null/wrong).
		["INFORMATION", Format["RequestJoin.sqf: Player [%1] [%2] has been sent back to the lobby for teamswapping, original side [%3], joined side [%4].", _name,_uid,_teamJoinedConfirmed,_side]] Call WFBE_CO_FNC_LogContent;

	} else {

		_canJoin = true;

	};

} else {

	if (!(isNil "_hasConnectedAtLaunchToSide")) then {

		if (_hasConnectedAtLaunchToSide != _side) then {

			_canJoin = false;
			[_player, "LocalizeMessage", ['Teamswap',_name,_uid,_hasConnectedAtLaunchToSide,_side]] Call WFBE_CO_FNC_SendToClient; //--- r70: address the joining unit (leader group can be null/wrong).
			["INFORMATION", Format["RequestJoin.sqf: Player [%1] [%2] has been sent back to the lobby for teamswapping, original side [%3], attempted side [%4].", _name,_uid,_hasConnectedAtLaunchToSide,_side]] Call WFBE_CO_FNC_LogContent;
		} else {

			_canJoin = true;

		};

	} else {

		call {
			// Marty: Keep teamswap protection active, but skip only the AntiStack skill DB check when the module is disabled.
			if ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 0) exitWith {
				_canJoin = true;
				_reason = " (AntiStack skill balancing disabled. Joining allowed without skill check.)";
				["INFORMATION", Format["RequestJoin.sqf: AntiStack skill balancing is disabled; player [%1] (UID: [%2]) can join side [%3] without team skill check.", _name, _uid, _side]] Call WFBE_CO_FNC_LogContent;
			};

			["INFORMATION", Format["RequestJoin.sqf: Player [%1] (UID: [%2]) hasn't joined either side in this match. Checking team skills...", _name, _uid]] Call WFBE_CO_FNC_LogContent;

			_skillBLUFOR = [west, _uid] Call WFBE_SE_FNC_GetTeamScore;
			_skillOPFOR = [east, _uid] Call WFBE_SE_FNC_GetTeamScore;

			_canJoin = [_side, _name, _uid, _player, _skillBLUFOR, _skillOPFOR] call WFBE_SE_FNC_CompareTeamScores;

			if (_canJoin) then {
				_reason = " (Player joined the weaker team. Joining allowed.)";
			} else {
				_reason = " (Player attempted to join the stronger team. Joining denied.)";
			}
		};

	};
};

if (WF_A2_Vanilla) then {

	//--- caster seat target: always allowed regardless of any check above (observer, not a team).
	if (_side == civilian) then {_canJoin = true};
	[_uid, "HandleSpecial", ["join-answer", _canJoin, _skillBLUFOR, _skillOPFOR]] Call WFBE_CO_FNC_SendToClients;

} else {

	[_player, "HandleSpecial", ["join-answer", _canJoin, _skillBLUFOR, _skillOPFOR]] Call WFBE_CO_FNC_SendToClient;

};

["INFORMATION", Format["RequestJoin.sqf: Player [%1] [%2] can join? [%3].%4", _name, _uid, _canJoin, _reason]] Call WFBE_CO_FNC_LogContent;


if (_canJoin) then {

	//--- caster seats are not a team: never record CIV as the joined side (see header note).
	if (_side != civilian) then {
		missionNamespace setVariable [Format["WFBE_JIP_USER%1_TEAM_JOINED", _uid], _side];
	};
	_result = ["STORE_SIDE", [_uid, _side]] call WFBE_SE_FNC_CallDatabaseStoreSide;

	//--- B748.1 (Ray 2026-06-24): hand the actual player body to the enrollment handler so it never has to HUNT
	//--- for the seat in playableUnits (the scan race that intermittently stranded JIP joiners with no team/markers).
	//--- Server_OnPlayerConnected's resolution loop reads this body FIRST. _player is the real networked unit, so
	//--- group _player is the wired slot group server-side. Idempotent: re-stored on every RequestJoin retry.
	missionNamespace setVariable [Format ["WFBE_JIP_BODY_%1", _uid], _player];
	diag_log Format ["[WFBE][B748.1 REQUESTJOIN] stored body for [%1] [%2] side %3 (slot-group=%4)", _name, _uid, _side, !isNil {(group _player) getVariable "wfbe_side"}];

};
