//--- Init_LandHVT.sqf — Takistan land SCUD-site capturable HVT objective.
//--- TK-DEEP-PARITY action #5 (S-tier). Mirrors the CH carrier HVT idiom for a land context:
//--- one capturable GUER-owned "Rasman SCUD Site" depot logic; on capture the owning side gains
//--- a SCUD saturation-strike platform (reuses Support_ScudStrike.sqf unchanged).
//--- Flag: WFBE_C_LAND_HVT (default 1 on Takistan). Default 0 disables all land-HVT content.
//--- Map gate: worldName == "Takistan" — inert on Chernarus (CH has naval HVTs instead).
//--- Called from Init_Server.sqf after townInit (mirrors the Init_NavalHVT.sqf launch pattern).

if (!isServer) exitWith {};
if (toLower worldName != "takistan") exitWith {
    ["INFORMATION", "Init_LandHVT.sqf : not Takistan — land HVT skipped (CH uses naval HVTs)."] Call WFBE_CO_FNC_LogContent;
};
if ((missionNamespace getVariable ["WFBE_C_LAND_HVT", 1]) != 1) exitWith {
    ["INFORMATION", "Init_LandHVT.sqf : WFBE_C_LAND_HVT=0 — feature OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Init_LandHVT.sqf : Takistan land HVT feature ENABLED."] Call WFBE_CO_FNC_LogContent;

//--- Wait for town init (same waitUntil pattern as Init_NavalHVT.sqf).
waitUntil { !isNil "townInit" && townInit };
waitUntil { !isNil "towns" };

//--- Locate the pre-placed "Rasman SCUD Site" LocationLogicDepot in towns[].
//--- It must be in mission.sqm (TK only) and registered by Init_Town.sqf.
private ["_siteLogic","_x","_tName"];
_siteLogic = objNull;
{
    _tName = _x getVariable ["name", ""];
    if (_tName == "Rasman SCUD Site") then { _siteLogic = _x };
} forEach towns;

if (isNull _siteLogic) exitWith {
    ["WARNING", "Init_LandHVT.sqf : 'Rasman SCUD Site' logic not found in towns[] — check TK mission.sqm."] Call WFBE_CO_FNC_LogContent;
};

//--- Tag the logic as an HVT platform. wfbe_is_naval_hvt=true is required by Support_ScudStrike.sqf
//--- validation (line 41: checks this flag on every WFBE_NAVAL_HVT_PLATFORMS entry). wfbe_is_land_hvt=true
//--- distinguishes it from a CH carrier in server_town.sqf's capture block (land path vs carrier path).
//--- No wfbe_naval_deckz is set -> capH defaults to 22+12=34m (acceptable for a ground site).
//--- No wfbe_is_carrier_hvt: skips the hangar-respawn path in server_town.sqf line 317 (land site has no hangar).
//--- No wfbe_hvt_scud: Support_ScudStrike theatrics guard is null-safe (logs + continues without it).
_siteLogic setVariable ["wfbe_is_naval_hvt", true];     //--- required by Support_ScudStrike validation
_siteLogic setVariable ["wfbe_is_land_hvt", true];      //--- land-HVT path tag for server_town.sqf
_siteLogic setVariable ["wfbe_naval_marker", "wfbe_landhvt_site_marker"];

//--- Create the site map marker (server-side createMarker replicates globally).
//--- Coloured GUER (initial owner is resistance / GUER) until capture flips it.
private ["_siteMkrName","_sitePos"];
_siteMkrName = "wfbe_landhvt_site_marker";
_sitePos = getPos _siteLogic;
createMarker [_siteMkrName, [_sitePos select 0, _sitePos select 1, 0]];
_siteMkrName setMarkerType "mil_triangle";
_siteMkrName setMarkerColor (missionNamespace getVariable ["WFBE_C_GUER_COLOR", "ColorGreen"]);
_siteMkrName setMarkerText "SCUD Site";
_siteMkrName setMarkerSize [0.8, 0.8];

//--- Register as a SCUD strike platform. On Takistan, WFBE_NAVAL_HVT_PLATFORMS is NOT set by
//--- Init_NavalHVT.sqf (which exits early on TK). We set it here to [_siteLogic].
//--- On CH this file never runs (worldName gate above) so no double-write risk.
missionNamespace setVariable ["WFBE_NAVAL_HVT_PLATFORMS", [_siteLogic]];

["INITIALIZATION", Format ["Init_LandHVT.sqf : Rasman SCUD Site wired as land HVT platform at %1.", getPos _siteLogic]] Call WFBE_CO_FNC_LogContent;
