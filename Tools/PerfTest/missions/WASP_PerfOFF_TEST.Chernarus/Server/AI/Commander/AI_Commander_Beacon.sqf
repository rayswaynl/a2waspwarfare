/*
	AI Commander - forward SPAWN BEACON (Approach A: a forward AMBULANCE as a mobile spawn point).

	The ambulance is ALREADY a fully-wired mobile respawn for the side (WFBE_%1AMBULANCES,
	consumed by Client/Functions/Client_GetRespawnAvailable.sqf:34-45 and by AI respawn
	AI_AdvancedRespawn.sqf / AI_SquadRespawn.sqf when WFBE_C_RESPAWN_MOBILE > 0). So when the
	commander buys one and parks it forward, it INSTANTLY becomes a working forward spawn for
	both AI and any human on the side - zero new respawn plumbing, no new structure, no client
	changes.

	Server-side worker, full-command mode only. Parameter: _this = side.
	INERT unless WFBE_C_AICOM_SPAWNBEACON_ENABLE > 0 (the supervisor hook also re-checks the flag,
	so with the flag off this function is never even called). Funds buy (same idiom as the base
	defense block in AI_Commander_Base.sqf): GetAICommanderFunds / ChangeAICommanderFunds, price
	read from the unit's data array at QUERYUNITPRICE.

	A2-OA-safe: array-form private; no isEqualType/params/pushBack/findIf/selectRandom; createVehicle
	+ setVariable broadcast; nearEntities/nearRoads; if/else for bool latches.
*/

private ["_side","_sideText","_logik","_hq","_hqPos","_ambArr","_amb","_max","_standoff","_refwd","_cooldown","_beacons","_targets","_target","_tgtPos","_myID","_fwdTown","_fwdBestD","_townSide","_fwdPos","_dx","_dy","_d","_pos","_dir","_blocked","_price","_data","_funds","_veh","_curBeacon","_curPos","_lastBuilt"];

//--- 0) Gate: enabled + valid side logic + alive deployed HQ (forward standoff is measured from the HQ).
if ((missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_ENABLE", 0]) <= 0) exitWith {};

_side = _this;
_sideText = str _side;
_myID = (_side) Call WFBE_CO_FNC_GetSideID;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (isNull _hq || {!alive _hq}) exitWith {};
_hqPos = getPos _hq;
if (typeName _hqPos != "ARRAY" || {count _hqPos < 2}) exitWith {};

//--- 1) Resolve the side ambulance class (first entry = the cheapest/ground ambulance). Bail if absent.
_ambArr = missionNamespace getVariable Format ["WFBE_%1AMBULANCES", _sideText];
if (isNil "_ambArr") exitWith {};
if (typeName _ambArr != "ARRAY" || {count _ambArr < 1}) exitWith {};
_amb = _ambArr select 0;
if (typeName _amb != "STRING" || {_amb == ""}) exitWith {};

_max      = missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_MAX", 1];
_standoff = missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_STANDOFF", 300];
_refwd    = missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_REFWD", 600];
_cooldown = missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_COOLDOWN", 300];

//--- 2) Count LIVE beacons we own (tagged wfbe_aicom_beacon + owning side ID).
//--- Keep a handle to the (single, or first) current beacon for the re-stand-forward check below.
_beacons = 0;
_curBeacon = objNull;
{
	if (!isNull _x && {alive _x} && {_x getVariable ["wfbe_aicom_beacon", false]} && {(_x getVariable ["wfbe_aicom_beacon_side", -1]) == _myID}) then {
		_beacons = _beacons + 1;
		if (isNull _curBeacon) then {_curBeacon = _x};
	};
} forEach vehicles;

//--- 3) Direction reference = the published spearhead town (the 'fist': the ENEMY/neutral town we are ATTACKING,
//--- per AI_Commander_Allocate.sqf:150). We only use it as a DIRECTION REFERENCE - the beacon is anchored on our
//--- own forward ground, NOT on the enemy's doorstep.
_targets = _logik getVariable ["wfbe_aicom_targets", []];
if (typeName _targets != "ARRAY" || {count _targets < 1}) exitWith {};
_target = _targets select 0;
if (isNull _target) exitWith {};
_tgtPos = getPos _target;
if (typeName _tgtPos != "ARRAY" || {count _tgtPos < 2}) exitWith {};

//--- 4) ANCHOR = our OWNED FORWARD town: among towns where (getVariable "sideID")==_myID, the one NEAREST the fist
//--- (the leading edge of owned territory). Mirror the FWDBASE owned-town preference (AI_Commander_Base.sqf:698-708).
//--- If no owned town qualifies, exit (no beacon this tick) - never drop it on the enemy's doorstep.
_fwdTown  = objNull;
_fwdBestD = 1e9;
{
	if ((_x getVariable ["sideID", -1]) == _myID) then {
		_d = _x distance _tgtPos;   //--- nearest-to-fist owned town = the forward edge of friendly ground.
		if (_d < _fwdBestD) then {_fwdBestD = _d; _fwdTown = _x};
	};
} forEach towns;
if (isNull _fwdTown) exitWith {};
_fwdPos = getPos _fwdTown;
if (typeName _fwdPos != "ARRAY" || {count _fwdPos < 2}) exitWith {};

//--- 5) Standoff point = WFBE_C_AICOM_SPAWNBEACON_STANDOFF metres from the OWNED town, offset TOWARD the fist
//--- (so it sits at the forward edge of friendly ground, not in the town core, not toward the rear HQ).
_dx = (_tgtPos select 0) - (_fwdPos select 0);
_dy = (_tgtPos select 1) - (_fwdPos select 1);
_d  = sqrt (_dx*_dx + _dy*_dy);
if (_d < 1) then {_d = 1};
_pos = [(_fwdPos select 0) + (_dx / _d) * _standoff, (_fwdPos select 1) + (_dy / _d) * _standoff, 0];

//--- 6) Placement gate (applies to BOTH the buy path AND the re-stand path below): reject water + an
//--- ENEMY-HELD town within 500 m (mirror the redeploy-truck gate, Client_GetRespawnAvailable.sqf:69-75).
//--- ONLY enemy-held towns block: neutral (sideID -1) AND our own towns are EXCLUDED from the reject scan
//--- (the anchor is our own forward town, so it must not reject based on our own ground).
if (surfaceIsWater _pos) exitWith {};
_blocked = false;
{
	_townSide = _x getVariable ["sideID", -1];
	if (_townSide != _myID && {_townSide != -1} && {(_pos distance _x) < 500}) exitWith {_blocked = true};
} forEach towns;
if (_blocked) exitWith {};

//--- Direction the beacon faces = toward the fist (cosmetic; respawn does not need a heading).
_dir = ((_tgtPos select 0) - (_pos select 0)) atan2 ((_tgtPos select 1) - (_pos select 1));

//--- 7) Self-heal within the cap. If we already hold the cap, only RE-STAND the current beacon when the front has
//--- advanced > WFBE_C_AICOM_SPAWNBEACON_REFWD metres from where the beacon stands. _pos is ALREADY gate-passed
//--- (water + enemy-town gates ran above), so the re-stand can never teleport into water or next to an enemy.
//--- Re-standing an existing beacon is NOT subject to the re-buy cooldown.
if (_beacons >= _max) exitWith {
	if (!isNull _curBeacon) then {
		_curPos = getPos _curBeacon;
		if ((_curPos distance _pos) > _refwd) then {
			//--- A2-OA-safe relocate: setPos the existing (locked) beacon to the new (gate-passed) standoff, re-aim it.
			_curBeacon setPos _pos;
			_curBeacon setDir _dir;
			["INFORMATION", Format ["AI_Commander_Beacon.sqf: [%1] spawn-beacon RE-STOOD forward to %2 (front advanced > %3m).", _sideText, _pos, _refwd]] Call WFBE_CO_FNC_AICOMLog;
			diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|SPAWNBEACON_RESTOOD|pos=" + str _pos + "|tgt=" + (_target getVariable ["name", "?"]));
		};
	};
};

//--- 8) RE-BUY COOLDOWN: only BUY a fresh beacon when more than WFBE_C_AICOM_SPAWNBEACON_COOLDOWN seconds have
//--- elapsed since the last buy (anti funds-bleed if the enemy keeps killing it). Stamp idiom mirrors the FWDBASE
//--- re-buy guard (AI_Commander_Base.sqf:737/748). Re-stand (step 7) is exempt - this only gates NEW beacons.
_lastBuilt = _logik getVariable ["wfbe_aicom_beaconbuilt", -1e6];
if ((time - _lastBuilt) < _cooldown) exitWith {};

//--- 9) Affordability: pay from AI commander FUNDS (vehicles are a funds buy on this side), SAME idiom as
//--- the base-defense block in AI_Commander_Base.sqf:593-597. _data = the unit's config-cost array.
_data = missionNamespace getVariable _amb;
_price = if (!isNil "_data" && {typeName _data == "ARRAY"} && {count _data > QUERYUNITPRICE}) then {_data select QUERYUNITPRICE} else {0};
_funds = (_side) Call GetAICommanderFunds;
if (_funds < _price) exitWith {};

//--- 10) Field the forward spawn beacon. createVehicle (A2-OA-safe; same as ConstructDefense; it already places the
//--- unit at _pos), aim toward the fist, TAG it so we only manage ours (broadcast so the respawn menus everywhere see
//--- the tag), and pin it (low fuel + locked) so the AI does not drive it off. Stamp the re-buy cooldown on success.
[_side, -_price] Call ChangeAICommanderFunds;
_veh = createVehicle [_amb, _pos, [], 0, "NONE"];
_veh setDir _dir;
_veh setVariable ["wfbe_aicom_beacon", true, true];
_veh setVariable ["wfbe_aicom_beacon_side", _myID, true];
_veh setFuel 0.5;
_veh lock true;
_logik setVariable ["wfbe_aicom_beaconbuilt", time];

["INFORMATION", Format ["AI_Commander_Beacon.sqf: [%1] FORWARD SPAWN-BEACON fielded (%2) at %3 (own town %4, cost %5 funds, standoff %6m toward fist).", _sideText, _amb, _pos, (_fwdTown getVariable ["name", "?"]), _price, _standoff]] Call WFBE_CO_FNC_AICOMLog;
diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|SPAWNBEACON_FIELDED|class=" + _amb + "|cost=" + str _price + "|pos=" + str _pos + "|ownTown=" + (_fwdTown getVariable ["name", "?"]) + "|fist=" + (_target getVariable ["name", "?"]) + "|standoff=" + str _standoff);
