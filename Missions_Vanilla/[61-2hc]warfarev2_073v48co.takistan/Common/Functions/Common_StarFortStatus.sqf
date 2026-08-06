/*
	Common_StarFortStatus.sqf
	Star Fortress Phase 1 (MVP) - alive-tracking / breach-signal / keepalive watcher (spec B.6).
	Spawned SERVER-side by Server\Construction\Construction_StarFortSite.sqf at build completion
	(needs the gate + bastions to exist before the breach math is meaningful).

	Polls alive-count against the shared WFBE_WDDMPositionAnchor placement-ID every fort child carries
	(the same mechanism the commander sell-exploit fix uses to answer "how much of this composition is
	still standing"). Publishes:
	  wfbe_starfort_breached_<side>  -> true (latched) when the gate segment is gone AND at least
	     WFBE_C_STARFORT_BREACH_BASTIONS_LOST of WFBE_C_STARFORT_BASTIONS bastion main guns are dead.
	     Mirrors the WFBE_RADIOTOWER_*_ALIVE publicVariable/DashboardAnnounce pattern - no new plumbing.
	  wfbe_starfort_keepalive_<side> -> false when the keep dies. This single flag is what the
	     consumers read: it kills the respawn privilege (Client\Functions\Client_GetRespawnAvailable.sqf)
	     and is the flag the DEFERRED Phase-2 territorial-clock gate will read
	     (Server\FSM\server_victory_threeway.sqf - deliberately untouched in Phase 1).
	     Also clears the WFBE_STARFORT_<side> registry (razed-and-rebuildable, Bank-style) and removes
	     the permanent map marker.

	GC note: fort pieces carry no wfbe_trashable tag ON PURPOSE - server_collector_garbage.sqf reaps
	UNTAGGED dead objects via TrashObject; a tag would EXEMPT them (HQ/MHQ/Bank opt OUT with =false).
	JIP: the flags + registry are replayed to joiners in Server\Functions\Server_OnPlayerConnected.sqf;
	the marker is a server createMarker (global, JIP-durable) so it needs no replay.

	Parameters:
		_this select 0 - side (west/east).
		_this select 1 - placementID (the WFBE_WDDMPositionAnchor stamp on every child).
		_this select 2 - keep object.
		_this select 3 - fort center position.
		_this select 4 - fort radius (scan bound).
*/
Private ["_side","_placementID","_keep","_pos","_radius","_regKey","_aliveKey","_breachKey","_markerName",
         "_sideText","_nB","_breachLost","_scanCls","_breached","_objs","_gateAlive","_bastAlive","_part","_lost"];

_side        = _this select 0;
_placementID = _this select 1;
_keep        = _this select 2;
_pos         = _this select 3;
_radius      = _this select 4;

_regKey    = if (_side == west) then {"WFBE_STARFORT_WEST"} else {"WFBE_STARFORT_EAST"};
_aliveKey  = if (_side == west) then {"wfbe_starfort_keepalive_west"} else {"wfbe_starfort_keepalive_east"};
_breachKey = if (_side == west) then {"wfbe_starfort_breached_west"} else {"wfbe_starfort_breached_east"};
_markerName = Format ["wfbe_starfort_%1", if (_side == west) then {"west"} else {"east"}];
_sideText   = if (_side == west) then {"WEST"} else {"EAST"};

_nB = missionNamespace getVariable ["WFBE_C_STARFORT_BASTIONS", 4];
_breachLost = missionNamespace getVariable ["WFBE_C_STARFORT_BREACH_BASTIONS_LOST", 2];
//--- Scan bound covers every fort class of both factions (the union of the builder's class lists).
_scanCls = ["Concrete_Wall_EP1","Fort_RazorWire","Hedgehog","Land_CncBlock_Stripes","Land_fort_bagfence_round",
            "Land_CamoNetVar_NATO","Land_CamoNetVar_EAST","Land_fortified_nest_big_EP1",
            "M2StaticMG","DSHKM_TK_INS_EP1","TOW_TriPod_US_EP1","Metis_TK_EP1"];

_breached = false;
while {!WFBE_GameOver} do {
	sleep 5;
	if (isNull _keep || {!alive _keep}) exitWith {};
	_objs = nearestObjects [_pos, _scanCls, _radius + 25];
	_gateAlive = 0;
	_bastAlive = 0;
	{
		if (alive _x && {(_x getVariable ["WFBE_WDDMPositionAnchor", ""]) == _placementID}) then {
			_part = _x getVariable ["wfbe_starfort_part", ""];
			if (_part == "gate") then {_gateAlive = _gateAlive + 1};
			if (_part == "bastion") then {_bastAlive = _bastAlive + 1};
		};
	} forEach _objs;
	if (!_breached) then {
		_lost = _nB - _bastAlive;
		if ((_gateAlive == 0) && {_lost >= _breachLost}) then {
			_breached = true;
			missionNamespace setVariable [_breachKey, true];
			publicVariable _breachKey;
			[nil, "DashboardAnnounce", [Format ["%1 STAR FORTRESS BREACHED - the gate has fallen and the bastions are cracking!", _sideText]]] Call WFBE_CO_FNC_SendToClients;
			["WARNING", Format ["Common_StarFortStatus.sqf: [%1] fort breached (gate down, %2/%3 bastions lost).", str _side, _lost, _nB]] Call WFBE_CO_FNC_LogContent;
		};
	};
};

//--- Keep is down (or game over): respawn privilege dies here, the registry opens for a rebuild,
//--- the marker goes away. Guard the announcements so a normal game-over end does not cry "fallen".
if (!WFBE_GameOver) then {
	missionNamespace setVariable [_aliveKey, false];
	publicVariable _aliveKey;
	missionNamespace setVariable [_regKey, objNull];
	publicVariable _regKey;
	deleteMarker _markerName;
	[nil, "DashboardAnnounce", [Format ["%1 STAR FORTRESS HAS FALLEN - the keep is destroyed!", _sideText]]] Call WFBE_CO_FNC_SendToClients;
	["WARNING", Format ["Common_StarFortStatus.sqf: [%1] keep destroyed - fort razed, rebuild allowed.", str _side]] Call WFBE_CO_FNC_LogContent;
};
