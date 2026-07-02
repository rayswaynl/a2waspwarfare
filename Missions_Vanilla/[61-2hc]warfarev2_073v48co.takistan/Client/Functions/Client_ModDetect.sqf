//====================================================================================================
//  Client_ModDetect.sqf  —  optional client-mod detection (cmdcon42-m)
//----------------------------------------------------------------------------------------------------
//  Shared, per-client helper. Detects whether the joining player has any of the curated OPTIONAL
//  client mods loaded (sound / visual / HUD), using the core A2-OA-1.64 primitive
//  `isClass (configFile >> "CfgPatches" >> "<class>")`. This mirrors the LIVE graceful-detect pattern
//  in WASP\actions\SkinSelector\SkinSelector_Data.sqf (which drops mks_* skins unless @MiksuuSkins
//  is loaded). Runs on the joining player only; a player WITHOUT any mod gets all-false flags and every
//  downstream hook no-ops identically to today.
//
//  Whole feature is gated by the mission param WFBE_C_MODHOOKS (Rsc\Parameters.hpp; default 1). When
//  the param is 0 this function reports "no mods" so all hooks fall through to the vanilla mission path.
//
//  Sets, ONCE per session (cached in missionNamespace):
//    WFBE_MODHOOKS_DONE      : Bool  — guard so detection runs a single time.
//    WFBE_HAS_FX_MOD         : Bool  — any explosion/particle FX mod present (Blastcore / JTD).
//                                       Read by the FX-suppression hooks (nuke.sqf, rocket tracer).
//    WFBE_HAS_SOUND_MOD      : Bool  — any sound mod present (JSRS).
//    WFBE_HAS_HUD_MOD        : Bool  — any HUD/UI mod present (STHUD).
//    WFBE_MOD_DETECTED_LIST  : Array — display names of detected optional mods (for ack + RPT).
//
//  A2-OA-1.64 SAFE: isClass / configFile >> / count / +  are all core commands. No A3-only commands
//  (no isEqualType / isEqualTo / allMapMarkers) per host notes.
//
//  CfgPatches class names are EVIDENCE-BASED (recon doc docs/design/OPTIONAL-CLIENT-MODS.md + web
//  confirmation). Where a mod has known aliases across releases, they are OR'd so any packaging variant
//  is caught; unknown/unconfirmed aliases are omitted rather than guessed (a wrong class silently never
//  fires, so only confirmed strings are used).
//====================================================================================================

private ["_enabled","_detected","_hasFX","_hasSound","_hasHUD","_isLoaded"];

//--- Idempotent: only detect once per client session.
if (missionNamespace getVariable ["WFBE_MODHOOKS_DONE", false]) exitWith {};

//--- Param gate. Default 1 (feature ON). If the param is missing on some map/build, default to ON so
//--- the graceful behaviour still applies, but a value of 0 hard-disables every hook.
_enabled = missionNamespace getVariable ["WFBE_C_MODHOOKS", 1];
if (isNil "_enabled") then { _enabled = 1 };

//--- Helper: true iff the given CfgPatches class exists on THIS client (any alias in the array).
_isLoaded = {
	private ["_hit"];
	_hit = false;
	{ if (isClass (configFile >> "CfgPatches" >> _x)) exitWith { _hit = true }; } forEach _this;
	_hit
};

_detected  = [];
_hasFX     = false;
_hasSound  = false;
_hasHUD    = false;

if (_enabled != 0) then {

	//--- SOUND: JSRS 1.5 (LordJarhead). Root patch class "JSRS".
	if (["JSRS"] call _isLoaded) then {
		_detected set [count _detected, "JSRS"];
		_hasSound = true;
	};

	//--- VISUAL FX: Blastcore / WarFX (Opticalsnare). Root patch historically "WarFXPE"; aliases OR'd.
	if (["WarFXPE","blastcore","Blastcore_Visuals"] call _isLoaded) then {
		_detected set [count _detected, "Blastcore"];
		_hasFX = true;
	};

	//--- VISUAL FX: JTD FireAndSmoke (JTD team). Root patch "JTD_FireAndSmoke".
	if (["JTD_FireAndSmoke"] call _isLoaded) then {
		_detected set [count _detected, "JTD FireAndSmoke"];
		_hasFX = true;
	};

	//--- HUD/UI: ShackTac Fireteam HUD (STHUD). Root patch "sthud" (CBA-dependent).
	if (["sthud","STHUD"] call _isLoaded) then {
		_detected set [count _detected, "STHUD"];
		_hasHUD = true;
	};
};

//--- Publish flags (client-local). All false when param off or no mod loaded -> hooks no-op.
missionNamespace setVariable ["WFBE_HAS_FX_MOD",    _hasFX];
missionNamespace setVariable ["WFBE_HAS_SOUND_MOD", _hasSound];
missionNamespace setVariable ["WFBE_HAS_HUD_MOD",   _hasHUD];
missionNamespace setVariable ["WFBE_MOD_DETECTED_LIST", _detected];
missionNamespace setVariable ["WFBE_MODHOOKS_DONE", true];

_detected
