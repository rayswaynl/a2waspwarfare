//--- Client_GuerPatrolMarkers.sqf (owner 2026-07-07): resistance players see their friendly
//--- AI groups as small green dots on the map (patrols, garrisons, QRF cells - anything the
//--- Director or town system fields). Client-LOCAL markers only - zero network traffic, and
//--- WEST/EAST never see them. 20s refresh; markers rebuilt each pass (no yield in between,
//--- so no visible flicker). allGroups on a client is an established idiom here
//--- (Client_GroupsGC.sqf, Client_CleanupDelegatedTownAI.sqf).
private ["_known","_grp","_lead","_name","_i","_aliveCnt"]; //--- town-intel locals declared at use site below

if ((missionNamespace getVariable ["WFBE_C_GUER_PATROL_MARKERS", 1]) <= 0) exitWith {};
waitUntil {!isNil "sideJoined"};
if (sideJoined != resistance) exitWith {};

_known = [];
while {true} do {
	{ deleteMarkerLocal _x } forEach _known;
	_known = [];
	_i = 0;
	{
		_grp = _x; //--- capture BEFORE any inner count/forEach rebinds _x
		if (side _grp == resistance) then {
			_lead = leader _grp;
			_aliveCnt = {alive _x} count units _grp;
			if (!isNull _lead && {alive _lead} && {!isPlayer _lead} && {!(player in units _grp)} && {_aliveCnt > 0}) then {
				_name = Format ["guer_patrol_%1", _i];
				_name = createMarkerLocal [_name, getPos _lead];
				_name setMarkerTypeLocal "mil_dot";
				_name setMarkerColorLocal "ColorGreen";
				_name setMarkerSizeLocal [0.6, 0.6];
				_name setMarkerTextLocal Format ["%1", _aliveCnt];
				_known = _known + [_name];
				_i = _i + 1;
			};
		};
	} forEach allGroups;

	//--- fable/guer-town-intel (owner): GUER-owned town status + inbound reinforcements.
	//--- Flag per owned town, colored by Director ledger health (str vs base from the JIP snap:
	//--- green = holding, yellow = pressured, red = critical). "+N inbound" dot when virtual
	//--- cells are in transit to the town (snap index 5, appended this build - guarded).
	private ["_snapT","_snapN","_town","_tName","_tPos","_tIdx","_tStr","_tBase","_tCol","_tTransit"];
	_snapT = missionNamespace getVariable ["AICOMV2_GDIR_JIP_SNAP", []];
	_snapN = if (count _snapT > 0) then {_snapT select 0} else {[]};
	{
		_town = _x; //--- capture before nested code
		if ((_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID) then {
			_tName = _town getVariable ["name", ""];
			_tPos  = getPos _town;
			_tIdx  = _snapN find _tName;
			_tCol  = "ColorGreen";
			_tTransit = 0;
			if (_tIdx >= 0) then {
				_tStr  = (_snapT select 1) select _tIdx;
				_tBase = (_snapT select 2) select _tIdx;
				if (_tBase > 0 && {_tStr < _tBase * 0.9}) then {_tCol = "ColorYellow"};
				if (_tBase > 0 && {_tStr < _tBase * 0.5}) then {_tCol = "ColorRed"};
				if (count _snapT > 5) then {_tTransit = (_snapT select 5) select _tIdx};
			};
			_name = Format ["guer_townintel_%1", _i];
			_name = createMarkerLocal [_name, _tPos];
			_name setMarkerTypeLocal "mil_flag";
			_name setMarkerColorLocal _tCol;
			_name setMarkerSizeLocal [0.8, 0.8];
			_known = _known + [_name];
			_i = _i + 1;
			if (_tTransit > 0.05) then {
				_name = Format ["guer_townintel_%1", _i];
				_name = createMarkerLocal [_name, [(_tPos select 0), (_tPos select 1) + 220, 0]];
				_name setMarkerTypeLocal "mil_arrow";
				_name setMarkerColorLocal "ColorGreen";
				_name setMarkerSizeLocal [0.6, 0.6];
				_name setMarkerTextLocal "reinforcements inbound";
				_known = _known + [_name];
				_i = _i + 1;
			};
		};
	} forEach towns;
	sleep 20;
};
