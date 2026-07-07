//--- Client_GuerPatrolMarkers.sqf (owner 2026-07-07): resistance players see their friendly
//--- AI groups as small green dots on the map (patrols, garrisons, QRF cells - anything the
//--- Director or town system fields). Client-LOCAL markers only - zero network traffic, and
//--- WEST/EAST never see them. 20s refresh; markers rebuilt each pass (no yield in between,
//--- so no visible flicker). allGroups on a client is an established idiom here
//--- (Client_GroupsGC.sqf, Client_CleanupDelegatedTownAI.sqf).
private ["_known","_grp","_lead","_name","_i","_aliveCnt"];

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
	sleep 20;
};
