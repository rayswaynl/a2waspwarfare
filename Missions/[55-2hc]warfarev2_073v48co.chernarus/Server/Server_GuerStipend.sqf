/*
	Server_GuerStipend.sqf — GUER "Insurgents" player economy loop (SERVER-only).

	1) Stipend: 150/min base, +10/min per GUER-held town below the starting count, capped at 3x base
	   (~450/min at deep town deficit). Paid to each living GUER player's team (wfbe_funds).
	2) Broadcasts WFBE_GUER_VEHICLE_TIER (0/1/2/3) by elapsed match time so the buy menu can time-gate
	   ground vehicles (technicals=0 / BRDM @30m=1 / T-55 @1.5h=2 / T-72 @3h=3) — resolves Open Flag C
	   (dynamic delivery) without a second loop.

	Spawned from Init_Server.sqf when WFBE_C_GUER_PLAYERSIDE > 0. A2 OA 1.62/1.63 safe (no inline private,
	no params/pushBack/isEqualType). Uses `towns` (global town array) and WFBE_C_GUER_ID (=2, resistance).
*/
if !(isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) < 1) exitWith {};

private ["_interval","_baseRate","_townBonus","_startTownCount","_curTowns","_deficit","_rate","_tier","_elapsed"];

_interval  = 60;
_baseRate  = 150;
_townBonus = 10;

//--- Wait for towns to be built + the GUER side logic to exist, then let town ownership settle.
waitUntil {
	(!isNil "towns") && {(count towns) > 0}
	&& {!isNil "WFBE_L_GUE"} && {!(isNull (missionNamespace getVariable ["WFBE_L_GUE", objNull]))}
};
sleep 30;

_startTownCount = {(_x getVariable ["sideID", -1]) == WFBE_C_GUER_ID} count towns;
["INITIALIZATION", Format ["Server_GuerStipend.sqf: GUER player economy started (start towns=%1).", _startTownCount]] Call WFBE_CO_FNC_LogContent;

while {!WFBE_GameOver} do {
	sleep _interval;

	//--- (1) Vehicle time-tier broadcast — buy menu reads WFBE_GUER_VEHICLE_TIER.
	_elapsed = time;
	_tier = 0;
	if (_elapsed >= 1800)  then {_tier = 1};
	if (_elapsed >= 5400)  then {_tier = 2};
	if (_elapsed >= 10800) then {_tier = 3};
	if ((missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", -1]) != _tier) then {
		missionNamespace setVariable ["WFBE_GUER_VEHICLE_TIER", _tier];
		publicVariable "WFBE_GUER_VEHICLE_TIER";
	};

	//--- (2) Stipend, scaled by GUER town deficit.
	_curTowns = {(_x getVariable ["sideID", -1]) == WFBE_C_GUER_ID} count towns;
	_deficit  = (_startTownCount - _curTowns) max 0;
	_rate     = (_baseRate + (_deficit * _townBonus)) min (_baseRate * 3);

	{
		if ((alive _x) && {side _x == resistance} && {isPlayer _x}) then {
			private "_g";
			_g = group _x;
			if (isNil {_g getVariable "wfbe_funds"}) then {_g setVariable ["wfbe_funds", 0, true]};
			[_g, _rate] Call WFBE_CO_FNC_ChangeTeamFunds;
		};
	} forEach allPlayers;
};
