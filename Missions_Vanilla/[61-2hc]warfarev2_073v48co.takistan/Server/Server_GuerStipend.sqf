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
//--- B74.2: plain INITIALIZATION LogContent is FILTERED on this build (same filter the Init_Server GUER
//--- team-registration tail flags with its own diag_log), so this economy loop was previously INVISIBLE in the
//--- RPT - there was no way to tell START/pay/tier ever happened. Add a diag_log breadcrumb using the same
//--- convention as GuerAirDef's GUERAIRDEF| lines so START + the per-tick pay/tier are actually observable.
diag_log format ["GUERSTIPEND|START|startTowns=%1|baseRate=%2|townBonus=%3|interval=%4", _startTownCount, _baseRate, _townBonus, _interval];

//--- Seed + broadcast the current tier IMMEDIATELY (before the first interval sleep) so already-connected GUER
//--- players don't wait a whole cycle for tier 0; the per-loop re-broadcast inside the while then keeps any JIP
//--- joiner in sync (publicVariable is NOT JIP-replayed in A2-OA - same gotcha GuerAirDef notes for its feed).
_tier = 0;
if (time >= 1800)  then {_tier = 1};
if (time >= 5400)  then {_tier = 2};
if (time >= 10800) then {_tier = 3};
missionNamespace setVariable ["WFBE_GUER_VEHICLE_TIER", _tier];
publicVariable "WFBE_GUER_VEHICLE_TIER";
diag_log format ["GUERSTIPEND|TIERSEED|tier=%1|t=%2", _tier, round time];

while {!WFBE_GameOver} do {
	sleep _interval;

	//--- (1) Vehicle time-tier broadcast — buy menu reads WFBE_GUER_VEHICLE_TIER.
	_elapsed = time;
	_tier = 0;
	if (_elapsed >= 1800)  then {_tier = 1};
	if (_elapsed >= 5400)  then {_tier = 2};
	if (_elapsed >= 10800) then {_tier = 3};
	//--- B74.2 JIP DURABILITY: re-broadcast EVERY loop, not just on change. publicVariable is NOT JIP-replayed in
	//--- A2-OA, and the GUER buy overlay (Root_GUE_PlayerOverlay.sqf) reads WFBE_GUER_VEHICLE_TIER with a default
	//--- of 0 - so a GUER player who JIPs after a tier transition was silently stuck at tier 0 (no BRDM/T-55/T-72).
	//--- A single int once per interval is negligible bandwidth; this guarantees every joiner converges within one
	//--- cycle. setVariable is unconditional so the server-side value always tracks elapsed time.
	missionNamespace setVariable ["WFBE_GUER_VEHICLE_TIER", _tier];
	publicVariable "WFBE_GUER_VEHICLE_TIER";

	//--- (2) Stipend, scaled by GUER town deficit.
	_curTowns = {(_x getVariable ["sideID", -1]) == WFBE_C_GUER_ID} count towns;
	_deficit  = (_startTownCount - _curTowns) max 0;
	_rate     = (_baseRate + (_deficit * _townBonus)) min (_baseRate * 3);

	//--- C3 (double-pay fix): pay per UNIQUE GUER group, not per player. Two GUER players in one group
	//--- share a single team treasury (wfbe_funds), so the old per-playableUnits loop credited that
	//--- group's funds once for EACH member. Dedupe to distinct living-GUER-player groups and pay once.
	private "_paidGroups";
	_paidGroups = [];
	{
		if ((alive _x) && {side _x == resistance} && {isPlayer _x}) then {
			private "_g";
			_g = group _x;
			if !(_g in _paidGroups) then {
				_paidGroups = _paidGroups + [_g];
				if (isNil {_g getVariable "wfbe_funds"}) then {_g setVariable ["wfbe_funds", 0, true]};
				[_g, _rate] Call WFBE_CO_FNC_ChangeTeamFunds;
			};
		};
	} forEach playableUnits;

	//--- B74.2 observability: one compact line per tick so the economy is verifiable from the RPT. Shows the
	//--- pay rate, town deficit, how many distinct GUER player groups were credited this tick, the live tier, and
	//--- a sample treasury (first paid group's wfbe_funds) so a flat/zero funds trend is immediately visible.
	//--- A2-OA gotcha: getVariable[name,default] is unreliable on GROUPS, so use the single-arg form (the just-paid
	//--- group is guaranteed to carry wfbe_funds - the pay loop's nil-guard + ChangeTeamFunds both set it above).
	private "_sampleFunds";
	_sampleFunds = -1;
	if ((count _paidGroups) > 0) then {_sampleFunds = (_paidGroups select 0) getVariable "wfbe_funds"};
	diag_log format ["GUERSTIPEND|PAY|rate=%1|deficit=%2|paidGroups=%3|tier=%4|sampleFunds=%5|t=%6", _rate, _deficit, count _paidGroups, _tier, _sampleFunds, round time];
};
