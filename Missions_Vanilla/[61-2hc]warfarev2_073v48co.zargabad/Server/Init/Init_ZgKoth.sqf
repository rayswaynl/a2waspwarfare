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

WFBE_ZGKOTH_ANCHOR = [
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

//--- fable/zg-koth-reweight-visibility (owner 2026-07-10) LIVE STATE MARKER: server-authoritative poll
//--- loop that reflects the shared hold's state on zg_koth_marker every RadiusHold tick or on change, so
//--- players get a visual read of the objective even with WF_LOG_CONTENT compiled off (no reliance on
//--- WFBE_CO_FNC_LogContent). Reads ONLY variables Common_RadiusHold.sqf already publishes on the anchor
//--- it returns (wfbe_rh_holder_side/_progress/_cooldown_until - Common_RadiusHold.sqf lines 173-174 and
//--- 178-182; wfbe_rh_holdsecs - line 83) - Common_RadiusHold.sqf itself is NOT modified, so the
//--- naval-bubble consumer (Init_NavalHVT.sqf ~L1182-1191, same primitive) is byte-identical.
//---
//--- 4-state derivation (owner spec), checked in this priority order:
//---   COOLDOWN  : time < wfbe_rh_cooldown_until.                          -> grey   "KotH - cooldown"
//---   HOLDING   : wfbe_rh_holder_side is a solely-present eligible side.  -> side   "KotH - <SIDE> mm:ss/mm:ss"
//---   CONTESTED : holder_side==-1, not cooling down, progress>0.          -> orange "KotH - CONTESTED"
//---   NEUTRAL   : holder_side==-1, not cooling down, progress==0.         -> black  "King of the Hill"
//--- CONTESTED is a published-state PROXY, not a direct read: Common_RadiusHold.sqf does not publish a
//--- present-sides count (only the resolved holder), so "progress stalled above zero while nobody solely
//--- holds" is the best available signal that something is interrupting the hold - matches the common
//--- real case (a hold gets contested mid-accrual) and also correctly reads a lone ineligible GUER raid
//--- on a WEST/EAST hold as CONTESTED (this file's own header above: "GUER can raid/contest presence").
//--- Known false readings from this proxy, both cosmetic-only (the marker never gates game logic):
//---   - a simultaneous multi-side rush on a NEVER-held zone (progress still 0) displays NEUTRAL, not
//---     CONTESTED, until at least one side has accrued progress once.
//---   - a sole holder fully vacating (0 present) freezes progress exactly like a contest does, so the
//---     marker keeps showing CONTESTED until the state next actually changes.
if (!isNil "WFBE_ZGKOTH_ANCHOR" && {!isNull WFBE_ZGKOTH_ANCHOR}) then {
	[] spawn {
		if (!isServer) exitWith {}; //--- defense-in-depth, matches Common_RadiusHold.sqf's own dispatcher guard.
		private ["_anchor","_westId","_eastId","_tickSecs","_holderSide","_progress","_holdSecs","_cooldownUntil","_holdMM","_holdSS","_holdSSStr","_state","_mm","_ss","_ssStr","_sideStr","_text","_color","_lastText","_lastColor"];
		_anchor    = WFBE_ZGKOTH_ANCHOR;
		_westId    = west call WFBE_CO_FNC_GetSideID;
		_eastId    = east call WFBE_CO_FNC_GetSideID;
		_lastText  = "";
		_lastColor = "";

		while {!WFBE_GameOver} do {
			_tickSecs      = missionNamespace getVariable ["WFBE_C_RADIUSHOLD_TICK_SECS", 5];
			_holderSide    = _anchor getVariable ["wfbe_rh_holder_side", -1];
			_progress      = floor (_anchor getVariable ["wfbe_rh_progress", 0]);
			_holdSecs      = floor (_anchor getVariable ["wfbe_rh_holdsecs", 0]);
			_cooldownUntil = _anchor getVariable ["wfbe_rh_cooldown_until", 0];

			_holdMM    = floor (_holdSecs / 60);
			_holdSS    = _holdSecs - (_holdMM * 60);
			_holdSSStr = if (_holdSS < 10) then {Format ["0%1", _holdSS]} else {Format ["%1", _holdSS]};

			if (time < _cooldownUntil) then {
				_state = "cooldown";
			} else {
				if (_holderSide != -1) then {
					_state = "holding";
				} else {
					if (_progress > 0) then {_state = "contested"} else {_state = "neutral"};
				};
			};

			switch (_state) do {
				case "cooldown": {
					_color = "ColorGray";
					_text  = "KotH - cooldown";
				};
				case "holding": {
					_mm = floor (_progress / 60);
					_ss = _progress - (_mm * 60);
					_ssStr = if (_ss < 10) then {Format ["0%1", _ss]} else {Format ["%1", _ss]};
					_sideStr = if (_holderSide == _westId) then {"WEST"} else {"EAST"};
					_color   = if (_holderSide == _westId) then {"ColorWest"} else {"ColorEast"};
					_text    = Format ["KotH - %1 %2:%3/%4:%5", _sideStr, _mm, _ssStr, _holdMM, _holdSSStr];
				};
				case "contested": {
					_color = "ColorOrange";
					_text  = "KotH - CONTESTED";
				};
				default {
					_color = "ColorBlack";
					_text  = "King of the Hill";
				};
			};

			if (_text != _lastText) then {
				"zg_koth_marker" setMarkerText _text;
				_lastText = _text;
			};
			if (_color != _lastColor) then {
				"zg_koth_marker" setMarkerColor _color;
				_lastColor = _color;
			};

			sleep _tickSecs;
		};
	};
};

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
	wildcard function itself, per design doc S0.2's explicit correction). fable/zg-koth-reweight-visibility
	(owner 2026-07-10): vehicle_wave/air_support are unwired TODO stubs (their case bodies below spawn
	nothing) - excluded from the active _weights draw below so no completion pays out zero. cash:supply
	keeps the original 50:30 (5:3) ratio, rescaled to sum 100 (62.5:37.5, rounded to the nearest clean
	integer pair 63:37):
		common (weight 63): cash injection to the winning side (mirrors wildcard W1's ChangeAICommanderFunds shape)
		common (weight 37): supply crate (mirrors wildcard W2's ChangeSideSupply shape)
	vehicle_wave/air_support case bodies are left in place, NOT deleted - re-adding
	["vehicle_wave",12]/["air_support",8] to _weights below is the entire re-activation diff once their
	reward spawn paths are wired (see the TODO comments on those two cases).
	Escalating the tier with overheld duration (ZARGABAD-OBJECTIVE.md) needs the dispatcher itself to
	track "time held past threshold" - that is a primitive change, not a consumer change, so it is
	deliberately NOT implemented here.
*/
WFBE_FNC_ZgKoth_OnComplete = {
	private ["_holdId","_anchor","_winningSide","_weights","_tier","_bonus","_fundsStart","_supply","_maxSupply","_supplyGrant"];
	_holdId      = _this select 0;
	_anchor      = _this select 1;
	_winningSide = _this select 2;

	_weights = [["cash",63],["supply",37]]; //--- fable/zg-koth-reweight-visibility: vehicle_wave/air_support excluded (TODO stubs, see cases below) - ratio preserved from 50:30.
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
			//--- fable/zg-koth-reweight-visibility (2026-07-10): unreachable while _weights above stays
			//--- cash/supply-only - add ["vehicle_wave",12] back into _weights once wired. Case body unchanged.
			//--- TODO before merge: wire into the existing vehicle-wave/QRF spawn path (design doc cites
			//--- AI_Commander_Wildcard.sqf's W6/W19/W23 founding path as the reuse target). Deliberately
			//--- not stubbing further here - inventing new spawn/materialization code is against the
			//--- owner's "reuse, don't reimplement" framing for this feature.
			["ZGKOTH-TODO", "WFBE_FNC_ZgKoth_OnComplete: vehicle_wave tier drawn but reward spawn path not wired - see TODO comment."] Call WFBE_CO_FNC_LogContent;
		};
		case "air_support": {
			//--- fable/zg-koth-reweight-visibility (2026-07-10): unreachable while _weights above stays
			//--- cash/supply-only - add ["air_support",8] back into _weights once wired. Case body unchanged.
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
