/*
	Server\Init\Init_ZgKoth.sqf - Zargabad King of the Hill, city-core radius-hold consumer.

	fable/radius-hold-primitive (GR-2026-07-08a), stacked consumer (PR #916 base). Registers ONE
	radius-presence-hold at the Zargabad city core via WFBE_CO_FNC_RadiusHold_Register
	(Common\Functions\Common_RadiusHold.sqf) and rewards the winning side on completion via a
	weighted draw (WFBE_CO_FNC_WeightedDraw).

	Owner picks (2026-07-08): city core (~4071,4183), NEUTRAL start, [west,east] eligible to
	accrue/win (GUER can raid/contest presence but is excluded from _eligibleSides so it can never
	win), all four reward tiers wired and live (d023 WIRE-4-TIER, owner 2026-07-12): cash/supply plus
	vehicle-wave/air-support, the last two founding ONE free commander team via the existing W6/W19
	spawn path (WFBE_CO_FNC_RunCommanderTeam) - see WFBE_FNC_ZgKoth_OnComplete below.
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

	Reward-deck rolled via the extracted WFBE_CO_FNC_WeightedDraw (single-arg contract:
	[_weightPairs] call WFBE_CO_FNC_WeightedDraw - NOT the AI-commander wildcard function itself,
	per design doc S0.2's explicit correction). d023 WIRE-4-TIER (owner 2026-07-12): all four tiers
	are wired at the ORIGINAL design weights (PR #916 commit 5cbb20578), superseding the
	fable/zg-koth-reweight-visibility cash/supply-only 63:37 interim:
		common   (weight 50): cash injection - 15% of FUNDS_START (mirrors wildcard W1's ChangeAICommanderFunds shape)
		common   (weight 30): supply crate - +800 capped (mirrors wildcard W2's ChangeSideSupply shape)
		uncommon (weight 12): vehicle wave - ONE free ground-vehicle commander team founded at the winning-side HQ
		rare     (weight  8): air support  - ONE free helicopter commander team founded at the winning-side HQ
	The last two REUSE the exact W6 Air Cavalry / W19 Heliborne QRF founding path via the local
	_foundRewardTeam helper (defined at the top of this function) - no new spawn code. If the winning
	side has no matching template the tier falls back to the cash injection so a hold never pays zero.
	Escalating the tier with overheld duration (ZARGABAD-OBJECTIVE.md) needs the dispatcher itself to
	track "time held past threshold" - that is a primitive change, not a consumer change, so it is
	deliberately NOT implemented here.
*/
WFBE_FNC_ZgKoth_OnComplete = {
	private ["_holdId","_anchor","_winningSide","_weights","_tier","_bonus","_fundsStart","_supply","_maxSupply","_supplyGrant","_foundRewardTeam"];
	_holdId      = _this select 0;
	_anchor      = _this select 1;
	_winningSide = _this select 2;

	//--- d023 WIRE-4-TIER reward-team founder (vehicle_wave / air_support). REUSE, NOT REINVENT:
	//--- resolve ONE template from the winning side's OWN AI-commander pool (WFBE_<SIDE>AITEAMTEMPLATES)
	//--- and found ONE FREE team at that side's HQ through the EXACT path W6 Air Cavalry / W19 Heliborne
	//--- QRF use (AI_Commander_Wildcard.sqf:829-837): a least-loaded live HC via 'delegate-aicom-team',
	//--- else the server-local WFBE_CO_FNC_RunCommanderTeam 3-arg fallback. No new spawn code - the team
	//--- registers in wfbe_teams, rides the normal team GC, and the brain orders it forward. Free (no
	//--- funds debited, mirrors W6). Fixed-wing leads are excluded from the air pick: the 3-arg founding
	//--- path cannot pass a runway heading (slots 7/8), so a heli air-inserts where a Plane would not.
	//--- _this: [_side, _wantAir]  _wantAir true = air support (Air, non-Plane), false = ground vehicle.
	//--- Returns TRUE when a team was founded, FALSE when the side has no matching template.
	_foundRewardTeam = {
		private ["_rSide","_wantAir","_rSideID","_rSideText","_rHq","_rTmpls","_rPick","_rLead","_rSpawn","_rHc"];
		_rSide   = _this select 0;
		_wantAir = _this select 1;
		_rHq     = _rSide call WFBE_CO_FNC_GetSideHQ;
		if (isNull _rHq || {!alive _rHq}) exitWith {false};
		_rSideID   = _rSide call WFBE_CO_FNC_GetSideID;
		_rSideText = str _rSide;
		_rTmpls    = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _rSideText], []];
		_rPick     = [];
		{
			if (count _rPick == 0 && {count _x > 0}) then {
				_rLead = _x select 0;
				if (isClass (configFile >> "CfgVehicles" >> _rLead)) then {
					if (_wantAir) then {
						if (_rLead isKindOf "Air" && {!(_rLead isKindOf "Plane")}) then {_rPick = _x};
					} else {
						if (_rLead isKindOf "LandVehicle" && {!(_rLead isKindOf "Man")}) then {_rPick = _x};
					};
				};
			};
		} forEach _rTmpls;
		if (count _rPick == 0) exitWith {false};
		_rSpawn = getPos _rHq;
		_rHc    = call WFBE_CO_FNC_PickLeastLoadedHC;
		if (!isNull _rHc) then {
			[_rHc, "HandleSpecial", ['delegate-aicom-team', _rSideID, _rPick, _rSpawn, 0]] Call WFBE_CO_FNC_SendToClient;
		} else {
			[_rSideID, _rPick, _rSpawn] Spawn WFBE_CO_FNC_RunCommanderTeam;
		};
		true
	};

	_weights = [["cash",50],["supply",30],["vehicle_wave",12],["air_support",8]]; //--- d023 WIRE-4-TIER (owner 2026-07-12): full 4-tier deck at the ORIGINAL design weights (PR #916 commit 5cbb20578); supersedes the fable/zg-koth-reweight-visibility cash/supply-only 63:37 interim.
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
			if (!([_winningSide, false] call _foundRewardTeam)) then {
				//--- No ground-vehicle template for this side: fall back to the cash injection (case "cash"
				//--- primitive) so a held objective never pays out nothing. 15% of FUNDS_START, mirrors W1.
				_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _winningSide], 0];
				_bonus = round(_fundsStart * 0.15);
				[_winningSide, _bonus] Call ChangeAICommanderFunds;
				_tier = "cash(vehicle_wave-fallback)";
			};
		};
		case "air_support": {
			if (!([_winningSide, true] call _foundRewardTeam)) then {
				//--- No helicopter template for this side: same cash fallback as vehicle_wave above.
				_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _winningSide], 0];
				_bonus = round(_fundsStart * 0.15);
				[_winningSide, _bonus] Call ChangeAICommanderFunds;
				_tier = "cash(air_support-fallback)";
			};
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
