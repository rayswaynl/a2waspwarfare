/* 
Author: Benny
Name: uav_spotter.sqf
Parameters:
  0 - UAV
Description:
  This file handle the UAV 'spotting' ability. If the UAV knows about an hostile unit, it'll reveal it's average location on the map.
*/

Private ['_delay','_range','_sensitivity','_uav'];

_uav = _this select 0;
if (isNull _uav) exitWith {};
//--- r35 recon-intel: defaults so a missing constant cannot nil-sleep / nil-range the spotter loop.
_delay = missionNamespace getVariable ["WFBE_C_PLAYERS_UAV_SPOTTING_DELAY", 20];
_range = missionNamespace getVariable ["WFBE_C_PLAYERS_UAV_SPOTTING_RANGE", 1100];
_sensitivity = missionNamespace getVariable ["WFBE_C_PLAYERS_UAV_SPOTTING_DETECTION", 0.21];
if (typeName _delay != "SCALAR" || {_delay < 1}) then {_delay = 20};
if (typeName _range != "SCALAR" || {_range < 1}) then {_range = 1100};
if (typeName _sensitivity != "SCALAR") then {_sensitivity = 0.21};

while {!gameOver} do {
	sleep _delay;
	if (gameOver) exitWith {};
	if !(alive _uav) exitWith {};

	{
		//--- r35 recon-intel: only live hostiles; corpses still sit in nearEntities and would flood side PV with dead pins.
		if (!gameOver && {alive _x} && {_uav knowsAbout _x > _sensitivity} && {!(side _x in [sideJoined, civilian])}) then {
			sleep (0.05 + random 0.05);
			if (!gameOver) then {
				[sideJoined, "HandleSpecial", ["uav-reveal", _uav, _x]] Call WFBE_CO_FNC_SendToClients;
			};
		};
	} forEach (_uav nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"], _range]);
};
