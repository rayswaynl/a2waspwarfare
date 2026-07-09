/*
	Server\Init\Init_ZgKoth.sqf - Zargabad King of the Hill, city-core radius-hold consumer.

	fable/radius-hold-primitive (GR-2026-07-08a), stacked consumer (PR #916 base). Registers ONE
	radius-presence-hold at the Zargabad city core via WFBE_CO_FNC_RadiusHold_Register
	(Common\Functions\Common_RadiusHold.sqf) and rewards the winning side on completion via a
	weighted draw (WFBE_CO_FNC_WeightedDraw).

	Owner picks (2026-07-08): city core (~4071,4183), NEUTRAL start, [west,east] eligible to
	accrue/win (GUER can raid/contest presence but is excluded from _eligibleSides so it can never
	win), cash/supply rewards live, vehicle-wave/air-support reward tiers are explicit TODO stubs
	(reuse existing spawn paths, do not invent new ones - see WFBE_FNC_ZgKoth_OnComplete below).
	Master flag WFBE_C_ZG_KOTH_ENABLE defaults 0. ZG-only via worldName gate below.

	Launch pattern mirrors Init_Server.sqf's existing WFBE_C_NAVAL_HVT / WFBE_C_ICBM_TEL blocks
	(flag-gated execVM, called after the DeadspawnWall/NavalHVT/IcbmTel block).

	Guard chain: !isServer -> map-gate (worldName) -> flag-gate (WFBE_C_ZG_KOTH_ENABLE) -> waitUntil
	{townInit} -> register.
*/

private ["_anchorPos","_koth","_probe","_terrainZ"];

if (!isServer) exitWith {};

if (worldName != "Zargabad") exitWith {
	["ZGKOTH", Format ["Init_ZgKoth.sqf: exiting, worldName='%1' is not Zargabad.", worldName]] Call WFBE_CO_FNC_LogContent;
};

if ((missionNamespace getVariable ["WFBE_C_ZG_KOTH_ENABLE", 0]) != 1) exitWith {
	["ZGKOTH", "Init_ZgKoth.sqf: exiting, WFBE_C_ZG_KOTH_ENABLE=0."] Call WFBE_CO_FNC_LogContent;
};

waitUntil {townInit};

//--- City-core anchor. A2 OA has NO getTerrainHeightASL (Arma-3-only command - see
//--- server_heli_terrain_guard.sqf / Common_AICOM_HeliTerrainGuard.sqf headers). Ground a throwaway
//--- probe at z=0 (ATL) and read getPosASL to get the real terrain ASL height, exactly like those
//--- two files do. Common_RadiusHold.sqf's ARRAY-anchor branch takes this Z LITERALLY (setPosASL,
//--- no ground-snap of its own) - passing z=0 here would anchor the hold at sea level and the
//--- presence scan (unitsBelowHeight anchorZ+12) would then filter out every unit standing on the
//--- actual elevated city terrain, permanently. Getting this right is load-bearing.
_probe = "Sign_sphere10cm_EP1" createVehicleLocal [4071, 4183, 0];
_probe hideObject true;
_terrainZ = (getPosASL _probe) select 2;
deleteVehicle _probe;

_anchorPos = [4071, 4183, _terrainZ];

WFBE_ZGKOTH_HOLD_ID = "zg_koth_citycore";

[
	WFBE_ZGKOTH_HOLD_ID,
	_anchorPos,
	missionNamespace getVariable ["WFBE_C_ZG_KOTH_RADIUS", 150],
	missionNamespace getVariable ["WFBE_C_ZG_KOTH_HOLDSECS", 300],
	[west, east],                              //--- eligible to accrue/win: WEST + EAST only.
	0,                                          //--- contestMode 0 = pause-on-multi-presence (matches Common_RadiusHold.sqf's own default and "classic KotH" framing).
	missionNamespace getVariable ["WFBE_C_ZG_KOTH_COOLDOWN", 180],
	"WFBE_FNC_ZgKoth_OnComplete"
] call WFBE_CO_FNC_RadiusHold_Register;

//--- Public marker: NEUTRAL start, server-authoritative (createMarker, not Local - matches the
//--- codebase's other public objective markers, e.g. WFBE_%1_CityMarker).
_koth = createMarker ["zg_koth_marker", _anchorPos];
_koth setMarkerShape "ELLIPSE";
_koth setMarkerSize [(missionNamespace getVariable ["WFBE_C_ZG_KOTH_RADIUS", 150]), (missionNamespace getVariable ["WFBE_C_ZG_KOTH_RADIUS", 150])];
_koth setMarkerColor "ColorBlack";           //--- neutral start (owner pick).
_koth setMarkerText "King of the Hill";
_koth setMarkerAlpha 0.6;

//--- One-time public announcement - hidden-intel safe: generic "hold longer = bigger reward" framing
//--- only, never exact odds/progress/reward-table. Routed via the existing HandleSpecial PVF (a
//--- one-off "ZgKothAnnounce" PVF tag would NOT be in WFBE_CL_PVF_ALLOWED / resolvable by
//--- Client_HandlePVF.sqf and would be silently dropped client-side - HandleSpecial is already
//--- allowlisted; this feature adds the "zg-koth-announce" case to it, mirroring the existing
//--- "icbm-tel-msg" plain-systemChat case verbatim).
[nil, "HandleSpecial", ["zg-koth-announce", "A contested strongpoint has been established in Zargabad city core. Hold it to draw reinforcements."]] Call WFBE_CO_FNC_SendToClients;

["ZGKOTH", Format ["Init_ZgKoth.sqf: registered '%1' at %2, radius=%3 holdSecs=%4 cooldown=%5.", WFBE_ZGKOTH_HOLD_ID, _anchorPos, (missionNamespace getVariable ["WFBE_C_ZG_KOTH_RADIUS", 150]), (missionNamespace getVariable ["WFBE_C_ZG_KOTH_HOLDSECS", 300]), (missionNamespace getVariable ["WFBE_C_ZG_KOTH_COOLDOWN", 180])]] Call WFBE_CO_FNC_LogContent;


/*
	WFBE_FNC_ZgKoth_OnComplete - onComplete callback, per Common_RadiusHold.sqf's contract:
	[_holdId, _anchor, _winningSide] call (missionNamespace getVariable _onCompleteFnName), where
	_winningSide is the SIDE constant that completed the hold. Runs server-side only (the shared
	dispatcher that invokes it is isServer-gated).

	Reward-deck (ZARGABAD-OBJECTIVE.md tiers), rolled via the extracted WFBE_CO_FNC_WeightedDraw
	(single-arg contract: [_weightPairs] call WFBE_CO_FNC_WeightedDraw - NOT the AI-commander
	wildcard function itself, per design doc S0.2's explicit correction):
		common   (weight 50): cash injection to the winning side (mirrors wildcard W1's ChangeAICommanderFunds shape)
		common   (weight 30): supply crate (mirrors wildcard W2's ChangeSideSupply shape)
		uncommon (weight 12): friendly vehicle wave / QRF squad - TODO stub, reuse existing spawn path before merge
		rare     (weight 8):  air-support token / heavy-AA vehicle - TODO stub, same caveat
	Escalating the tier with overheld duration (ZARGABAD-OBJECTIVE.md) needs the dispatcher itself to
	track "time held past threshold" - that is a primitive change, not a consumer change, so it is
	deliberately NOT implemented here.
*/
WFBE_FNC_ZgKoth_OnComplete = {
	private ["_holdId","_anchor","_winningSide","_weights","_tier","_bonus","_fundsStart","_supply","_maxSupply","_supplyGrant"];
	_holdId      = _this select 0;
	_anchor      = _this select 1;
	_winningSide = _this select 2;

	_weights = [["cash",50],["supply",30],["vehicle_wave",12],["air_support",8]];
	_tier = [_weights] call WFBE_CO_FNC_WeightedDraw;

	switch (_tier) do {
		case "cash": {
			_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _winningSide], 0];
			_bonus = round(_fundsStart * 0.15);
			[_winningSide, _bonus] Call ChangeAICommanderFunds;
		};
		case "supply": {
			_supply    = (_winningSide) Call WFBE_CO_FNC_GetSideSupply;
			_maxSupply = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 99999];
			if (isNil "_supply") then {_supply = 0};
			_supplyGrant = 800 min (_maxSupply - _supply);
			if (_supplyGrant > 0) then {
				[_winningSide, _supplyGrant, "ZG KotH reward: supply crate.", false] Call ChangeSideSupply;
			};
		};
		case "vehicle_wave": {
			//--- TODO before merge: wire into the existing vehicle-wave/QRF spawn path (design doc cites
			//--- AI_Commander_Wildcard.sqf's W6/W19/W23 founding path as the reuse target). Deliberately
			//--- not stubbing further here - inventing new spawn/materialization code is against the
			//--- owner's "reuse, don't reimplement" framing for this feature.
			["ZGKOTH-TODO", "WFBE_FNC_ZgKoth_OnComplete: vehicle_wave tier drawn but reward spawn path not wired - see TODO comment."] Call WFBE_CO_FNC_LogContent;
		};
		case "air_support": {
			//--- same TODO as vehicle_wave.
			["ZGKOTH-TODO", "WFBE_FNC_ZgKoth_OnComplete: air_support tier drawn but reward spawn path not wired - see TODO comment."] Call WFBE_CO_FNC_LogContent;
		};
	};

	//--- Marker recolor to the winning side (public core UI, not a hidden-intel leak).
	if (_winningSide == west) then {"zg_koth_marker" setMarkerColor "ColorWest"};
	if (_winningSide == east) then {"zg_koth_marker" setMarkerColor "ColorEast"};

	//--- Broadcast tag other subsystems can branch on without a new registry.
	missionNamespace setVariable ["wfbe_zg_koth_owner", _winningSide];

	//--- Generic public announcement only - never the reward table/odds (hidden-intel rule).
	[nil, "HandleSpecial", ["zg-koth-announce", "The Zargabad strongpoint has been secured. Reinforcements are inbound to the holding side."]] Call WFBE_CO_FNC_SendToClients;

	["ZGKOTH", Format ["WFBE_FNC_ZgKoth_OnComplete: hold '%1' completed, winningSide=%2, tier=%3.", _holdId, _winningSide, _tier]] Call WFBE_CO_FNC_LogContent;
};
