//--- Server_CommsRelay.sqf  ---  Lane 206: Comms-Relay Side Objective
//--- Called once from Init_Server.sqf, guarded by WFBE_C_COMMS_RELAY (default 0).
//--- Chernarus-only: the relay mast has a CH-specific map position; disabled on other maps.
//---
//--- Mechanic:
//---   A pre-placed Land_Antenna radio mast near map centre (confirmed A2 OA classname,
//---   used as the CBR anchor throughout this tree: Structures_CO_*.sqf, Init_Defenses.sqf,
//---   Init_BaseStructure.sqf).
//---   The side that owns the mast (proximity latch, 50 m, same addAction latch idiom
//---   as Init_NavalHVT.sqf SCUD pad) can activate a timed recon sweep reusing the
//---   IcbmTelRecon reveal payload (WFBE_SE_FNC_IcbmTelRecon: enemy reveal + map dots).
//---   A per-side cooldown (WFBE_C_COMMS_RELAY_COOLDOWN, default 600 s) prevents spam.
//---
//--- Ownership latch:
//---   The mast has no town logic.  The server scans playableUnits every 10 s; the first
//---   living player within 50 m gets the recon addAction dispatched to their client via
//---   SendToClients (case comms-relay-action-add in Client/PVFunctions/HandleSpecial.sqf).
//---   The latch expires when the player leaves range or dies.  Cooldown is per-side,
//---   stamped on missionNamespace: wfbe_relay_cd_<sideStr>.
//---
//--- Recon payload:
//---   Calls WFBE_SE_FNC_IcbmTelRecon [_side, _mastPos] (from Init_IcbmTel.sqf).
//---   Radius / duration: WFBE_C_ICBM_TEL_RECON_R / WFBE_C_ICBM_TEL_RECON_SECS (shared constants).
//---
//--- Activation flow:
//---   Client addAction -> RequestSpecial [comms-relay-activate, sideStr, uid]
//---   -> Server_HandleSpecial.sqf case comms-relay-activate
//---   -> WFBE_SE_FNC_CommsRelayActivate (defined here) -> IcbmTelRecon Spawn.
//---
//--- Flags (seeded in Init_CommonConstants.sqf):
//---   WFBE_C_COMMS_RELAY          default 0  (master gate; 0 = byte-identical inert)
//---   WFBE_C_COMMS_RELAY_COOLDOWN default 600 (seconds between activations per side)

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_COMMS_RELAY", 0]) != 1) exitWith {
	["INFORMATION", "Server_CommsRelay.sqf : WFBE_C_COMMS_RELAY=0 - feature OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};
//--- CH-specific mast position: disabled on Takistan / Zargabad.
if (worldName != "Chernarus") exitWith {
	["INFORMATION", Format ["Server_CommsRelay.sqf : worldName=%1 - comms-relay mast position is CH-specific, disabled here.", worldName]] Call WFBE_CO_FNC_LogContent;
};
//--- IcbmTelRecon must exist (compiled by Init_IcbmTel.sqf which runs before this).
if (isNil "WFBE_SE_FNC_IcbmTelRecon") exitWith {
	["WARNING", "Server_CommsRelay.sqf : WFBE_SE_FNC_IcbmTelRecon not found - Init_IcbmTel.sqf must run first."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Server_CommsRelay.sqf : Comms-relay feature ENABLED."] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- SPAWN RELAY MAST near Chernarus map centre.
//--- Land_Antenna: confirmed A2 OA Combined Ops classname used as the CBR radar/antenna
//--- throughout this tree (Structures_CO_US/RU/USMC.sqf CBR entry; Init_Defenses.sqf
//--- line 162 'Core = Land_Antenna at origin'; Init_BaseStructure.sqf CBR range circle).
//--- Position [7500,7900]: approximate mid-map open ridge NW of Mogilevka, away from
//--- the 600 m town zones of Mogilevka (~7320,7080), Novy Sobor (~7050,9200) and
//--- Stary Sobor (~6320,8310) - best-effort; must be confirmed on the box.
//------------------------------------------------------------------------------------
private ["_mastPos","_mast"];
_mastPos = [7500, 7900, 0];
_mast = createVehicle ["Land_Antenna", _mastPos, [], 0, "NONE"];
if (isNull _mast) exitWith {
	["WARNING", "Server_CommsRelay.sqf : Land_Antenna createVehicle returned null - classname missing from this content set."] Call WFBE_CO_FNC_LogContent;
};
_mast setPos _mastPos;
_mast setDir 0;
_mast enableSimulation false;
_mast allowDamage false;
_mast setVariable ["wfbe_comms_relay", true, true];

missionNamespace setVariable ["WFBE_COMMS_RELAY_MAST", _mast, true];
missionNamespace setVariable ["WFBE_COMMS_RELAY_POS",  _mastPos, true];

["INITIALIZATION", Format ["Server_CommsRelay.sqf : Land_Antenna mast spawned at %1.", _mastPos]] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- RECON ACTIVATION HANDLER  (referenced from Server_HandleSpecial.sqf
//---  case "comms-relay-activate").  Defined BEFORE the proximity loop below so the
//---  symbol exists when HandleSpecial.sqf eventually calls it.
//---
//--- Args: _this = ["comms-relay-activate", sideStr, uid]
//---   sideStr: str (side _player) at action-fire time.
//---   uid:     getPlayerUID _player.
//---
//--- Server re-validates cooldown (authority); if OK: stamps, clears latch, fires recon.
//------------------------------------------------------------------------------------
WFBE_SE_FNC_CommsRelayActivate = {
	private ["_sideVal","_uid","_cooldown","_sideCD","_now","_sideObj","_mastPos"];
	_sideVal  = _this select 1;
	_uid      = _this select 2;
	_cooldown = missionNamespace getVariable ["WFBE_C_COMMS_RELAY_COOLDOWN", 600];
	_sideCD   = missionNamespace getVariable [Format ["wfbe_relay_cd_%1", _sideVal], 0];
	_now      = time;
	if ((_now - _sideCD) < _cooldown) exitWith {
		["INFORMATION", Format ["Server_CommsRelay.sqf : activate REJECTED for %1 (%2 s left on cooldown).", _sideVal, round (_cooldown - (_now - _sideCD))]] Call WFBE_CO_FNC_LogContent;
	};
	//--- Stamp cooldown and clear the calling player's latch so the action disappears.
	missionNamespace setVariable [Format ["wfbe_relay_cd_%1", _sideVal], _now];
	{
		if (getPlayerUID _x == _uid) then {
			_x setVariable ["wfbe_relay_action_armed", nil];
		};
	} forEach playableUnits;
	//--- Resolve side object from str-repr (A2-OA: str west == 'West', str east == 'East', etc.).
	_sideObj = west;
	if (_sideVal == str east)       then { _sideObj = east };
	if (_sideVal == str resistance) then { _sideObj = resistance };
	_mastPos = missionNamespace getVariable ["WFBE_COMMS_RELAY_POS", [7500, 7900, 0]];
	//--- Fire the recon sweep (same payload/reveal idiom as the TEL RECON munition).
	[_sideObj, _mastPos] Spawn WFBE_SE_FNC_IcbmTelRecon;
	["INFORMATION", Format ["Server_CommsRelay.sqf : recon sweep launched for %1 at %2.", _sideVal, _mastPos]] Call WFBE_CO_FNC_LogContent;
	diag_log Format ["COMMSRELAY|v1|ACTIVATE|%1|pos=%2", _sideVal, _mastPos];
};

//------------------------------------------------------------------------------------
//--- PROXIMITY LATCH LOOP  (server-side; mirrors the SCUD addAction latch in
//---  Init_NavalHVT.sqf lines 293-320).
//--- Scans playableUnits every 10 s.  The first living player within 50 m gets the
//--- recon addAction dispatched to their client via SendToClients (UID-addressed, so
//--- only that player's client receives it, matching the scud-action-add idiom).
//--- The wfbe_relay_action_armed latch ensures we arm each player only once per
//--- proximity visit.  Expiry: latch cleared when player leaves 60 m or dies, so a
//--- new approach arms the next qualifying player.
//------------------------------------------------------------------------------------
[_mast, _mastPos] spawn {
	private ["_mast","_mastPos","_cooldown","_sideVal","_sideCD","_now","_uid","_x"];
	_mast    = _this select 0;
	_mastPos = _this select 1;

	while { !WFBE_GameOver } do {
		sleep 10;
		_cooldown = missionNamespace getVariable ["WFBE_C_COMMS_RELAY_COOLDOWN", 600];

		//--- Expire latches for players who left range or died.
		{
			if (!(alive _x) || {(_x distance _mastPos) > 60}) then {
				_x setVariable ["wfbe_relay_action_armed", nil];
			};
		} forEach playableUnits;

		//--- Arm the first qualifying player within 50 m whose side is off cooldown.
		{
			if (isPlayer _x && {alive _x} && {(_x distance _mastPos) < 50}) then {
				if (isNil {_x getVariable "wfbe_relay_action_armed"}) then {
					_sideVal = str (side _x);
					_sideCD  = missionNamespace getVariable [Format ["wfbe_relay_cd_%1", _sideVal], 0];
					_now     = time;
					if ((_now - _sideCD) >= _cooldown) then {
						_x setVariable ["wfbe_relay_action_armed", true];
						_uid = getPlayerUID _x;
						//--- Dispatch the addAction to this player's client (UID-addressed, same as scud-action-add).
						[_uid, "HandleSpecial", ["comms-relay-action-add", _sideVal]] Call WFBE_CO_FNC_SendToClients;
						["INFORMATION", Format ["Server_CommsRelay.sqf : recon action armed for UID %1 (side %2).", _uid, _sideVal]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		} forEach playableUnits;
	};
};

["INITIALIZATION", "Server_CommsRelay.sqf : Proximity latch loop started."] Call WFBE_CO_FNC_LogContent;
