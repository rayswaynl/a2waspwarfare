/*
	Rotating gameplay-tip feed (cmdcon42-q, claude-gaming 2026-07-02).

	Ray request: "add 50 more hints that come by on rotation in the chat."

	Pure client-side cosmetic. Every WFBE_C_TIPS_PERIOD seconds this posts ONE short
	gameplay tip into the player's chat log via `systemChat` (the same A2-OA 1.64-safe
	chat call the mission already uses, e.g. Client\Init\Init_Client.sqf:270 and
	Client\GUI\GUI_Menu_Tactical.sqf:562). Nothing is broadcast, nothing touches
	player / team / vote / money / AI state - it only paints text locally.

	Spawned ONCE from Init_Client.sqf AFTER clientInitComplete, right next to the
	Common_Onboarding.sqf call (same guarded-spawn pattern). It first uiSleep's an
	initial WFBE_C_TIPS_INITIAL delay so a fresh joiner is NOT spammed on top of the
	onboarding cards.

	--- TIP POOL ---
	Each entry is a [tipText, gateFlagName] pair:
	  - tipText       : the chat line (systemChat has no colour markup; we prefix "TIP: ").
	  - gateFlagName  : "" = always eligible.
	                    Otherwise the tip is shown only while
	                    (missionNamespace getVariable [gateFlagName, 0]) >= 1.
	                    These are NUMBER feature-flags (Init_CommonConstants idiom). This
	                    is what makes a feature-tip auto-DISAPPEAR the moment Ray shelves a
	                    feature by flipping its flag to 0 - and it also hides tips for
	                    features that only exist in an UNMERGED PR: if the PR is never
	                    merged the flag is never registered, so getVariable returns the
	                    default 0 and the tip stays hidden. We only ever gate on REAL flag
	                    names (verified in Init_CommonConstants.sqf on this branch, or in
	                    the registering PR diff for the unmerged ones) - never an invented
	                    name.

	--- SHUFFLE ---
	Shuffle-without-repeat: we build an index deck [0..n-1], draw a RANDOM index
	(floor random count - NO selectRandom, that is A3-only), remove the drawn index,
	and refill the deck once it empties. The last-shown index is remembered across a
	refill so the same tip never appears twice in a row even at the deck boundary.

	--- A2-OA 1.64 SAFETY ---
	systemChat / uiSleep (real-time waits, still tick while a JIP client's sim is
	briefly paused) / missionNamespace getVariable [name,default] / private [] decls /
	set [count _arr,_v] to append (NO pushBack) / numeric-only comparisons and if/else
	latches (NEVER == / != on booleans). No isEqualType / isEqualTo / params / pushBack /
	findIf / selectRandom / apply / forEachIndex - none of those exist in OA 1.64.
*/

private ["_enable","_period","_initial","_tips","_gate","_flag","_deck","_n","_i","_last","_pick","_idx","_pair","_text","_ok"];

//--- Master toggle (default ON). Registered in Common\Init\Init_CommonConstants.sqf (cmdcon42-q).
_enable = missionNamespace getVariable ["WFBE_C_TIPS_ENABLE", 1];
if (_enable < 1) exitWith {};

//--- Cadence + first-line delay (both real-time seconds). Defaults mirror Init_CommonConstants.
_period  = missionNamespace getVariable ["WFBE_C_TIPS_PERIOD", 900];
_initial = missionNamespace getVariable ["WFBE_C_TIPS_INITIAL", 420];
if (_period < 30) then {_period = 30};       //--- floor so a mis-set param can't hammer the chat.
if (_initial < 0) then {_initial = 0};

//--- Wait for a real, alive player before we start (covers a slow JIP spawn). Bounded so a
//--- never-spawning edge case can never wedge this spawn. uiSleep is real-time.
private "_t0"; _t0 = time;
waitUntil { uiSleep 1; (!isNull player && {alive player}) || ((time - _t0) > 120) };
if (isNull player) exitWith {};

//--- Let onboarding cards / join titles clear before the first tip.
uiSleep _initial;

//================================================================ TIP POOL (50)
//--- [tipText, gateFlagName]. gateFlagName "" = always shown. Every claim verified against
//--- the mission code / Client\GUI\GUI_Menu_Help.sqf on this branch (cmdcon42-q).
_tips = [
	//--- ~ CORE GAMEPLAY (always eligible) ~
	["Capture a town: clear its strongpoints, then win the numbers fight in the 40m ring around the town centre until it flips to your side.", ""],
	["Defenders only spawn once a friendly unit crosses a town's 600m line - cross it deliberately, with support, not by accident.", ""],
	["You can only attack a town that borders ground you already hold. Blue/red rings are capturable; hatched-yellow towns are still in peace-time.", ""],
	["Two economies run the war: cash (you spend it on gear and units) and supply (the side pool your commander spends on structures and upgrades).", ""],
	["Shuttle supply trucks between a service point and a town centre's 30m range to raise its Supply Value - a pushed town pays more and defends harder.", ""],
	["Buy gear at the Barracks (or a captured town centre's stairs); buy infantry, vehicles and aircraft at the matching Factory in range.", ""],
	["A Command Center lets you remote-buy infantry and vehicles from anywhere on the map - not just standing next to the factory.", ""],
	["The buy queue shows N/CAP. Caps: Barracks 10, Light Factory 5, Heavy/Air Factory 3. Cancel Last refunds your most recent queued order.", ""],
	["Everything lives in the WF Menu: scroll-wheel action menu, blue Options. Buy, build, order AI, request support - it's always one scroll away.", ""],
	["No human commander in the first 5 minutes and the AI takes over building. You can claim Commander any time - any team you order becomes yours.", ""],
	["The MHQ (Mobile HQ) is where a base is built. Drive it forward and deploy to plant your factories closer to the fight.", ""],
	["Base buildings (MHQ, Barracks, all Factories) are unlimited-range respawns. A MEV/ambulance gives a forward spawn within 500m - drive one up.", ""],
	["Fast-travel your squad from the Tactical Center - it moves you and your nearby units to a chosen point instead of a long drive back.", ""],
	["Read the map: your units are orange, friendly towns green, enemy towns blue/red, an attack-in-progress ring is orange.", ""],
	["Service points rearm, refuel, repair and heal - roll in before the next push instead of dying to an empty mag or a cracked engine.", ""],
	["Build the Bank (Federal Reserve): while your HQ stands it pays $6,000 every 5 minutes split among living players. Kill the enemy's for a huge payout.", ""],
	["Hold Krasnostav to unlock the Czech T-72 at Heavy Factory L4; hold the NW Airfield for RM-70 rocket artillery at Light Factory L4.", ""],
	["Capturing an airfield gives a repair point, a free permanent 2,000m counter-battery radar, and a hangar with unique aircraft.", ""],
	["Anti-Air Radar tracks enemy planes above ~30m and is the prerequisite for the Counter Battery Radar that pins enemy artillery for 75s.", ""],
	["Patrols upgrade over 4 levels; up to 2 active patrols per side. Each active patrol drops every player's max AI by 1 - don't over-commit.", ""],
	["Auto Wall Construction (scroll action 14) throws up defensive walls around your base structures - toggle it on after you deploy.", ""],
	["Vote a side Commander and give orders - the AI commander spends the side economy and leads HQ teams; even under a human it keeps its squads fighting.", ""],

	//--- ~ BUILD 86/87 FEATURES (gated on their real feature flag) ~
	["OILFIELD (Takistan): after it unlocks ~1 hour in, hold it with your units to earn passive supply income. Check your map for the marker.", "WFBE_C_OILFIELD_ENABLE"],
	["Takistan OILFIELD can be sabotaged and repaired - deny the enemy the income by knocking it offline, or fix your own to keep it paying.", "WFBE_C_OILFIELD_SABOTAGE"],
	["SKIN SELECTOR: pick your soldier's look from the WF menu SKIN button - your choice is restored automatically every time you respawn.", "WFBE_C_SKINSEL"],
	["Capture the offshore carrier's SCUD and open SCUD STRIKE in the Tactical Center: click the map to drop a warhead where the enemy is massing.", "WFBE_C_SCUD_MENU"],
	["Research the land SCUD TEL to unlock long-range strikes - but it can be killed before launch, so guard your launcher and hunt theirs.", "WFBE_C_ICBM_TEL"],
	["SATURATION strike (from the TEL): a carrier-style MIRV set that saturates a target zone - drop it on a stacked enemy assault.", "WFBE_C_ICBM_TEL_SAT_COST"],
	["RECON FLASH: a SCUD airburst that reveals every enemy in an 800m radius for ~45s and temp-marks them - blind-spot buster before a push.", "WFBE_C_ICBM_TEL_RECON_COST"],
	["FASCAM strike scatters a field of AT mines across a chokepoint that self-clears after ~20 min - seal a road the enemy armour needs.", "WFBE_C_ICBM_TEL_FASCAM_COST"],
	["STEEL RAIN: a rolling airburst barrage that shreds EXPOSED infantry in the open - punish a dug-out assault caught without cover.", "WFBE_C_ICBM_TEL_RAIN_COST"],
	["BUNKER BUSTER: a single precision SCUD that guarantees the nearest enemy structure at the impact point dies - crack a hardened base.", "WFBE_C_ICBM_TEL_BUSTER_COST"],
	["The SCUD TEL shares one cooldown across all its munitions - pick your shot; you can't chain a recon flash straight into a bunker buster.", "WFBE_C_ICBM_TEL"],
	["GUER Insurgents are playable as a harass faction - pick the resistance slots to raid supply lines and objectives behind the frontline.", "WFBE_C_GUER_PLAYERSIDE"],
	["As GUER you can buy a VBIED - drive it into a target, arm it and detonate; every kill in the blast pays your team cash.", "WFBE_C_GUER_PLAYERSIDE"],
	["Your GUER Ka-137 recon drone ships with flares - the more enemy kills your side racks up, the bigger its countermeasure load.", "WFBE_C_GUER_PLAYERSIDE"],
	["Watch the skies: enemy Ka-137 drones can now roll in as a swarm - two or three in one group hunting your armour. Keep AA up.", "WFBE_C_GUER_KA137_SWARM"],
	["The command menu has steering verbs: RALLY, REFIT and HOLD a team - and any player can REQUEST AI SUPPORT to nudge a nearby squad over.", "WFBE_C_CMD_MENU_V2"],
	["Air cavalry: the AI commander can now airlift its assault teams straight into a contested town - expect enemy helis dropping troops on your flank.", "WFBE_C_AICOM_AIRMOBILE"],
	["Heads up: the enemy AI can sling-lift vehicles under helicopters to relocate armour fast - a quiet flank can turn into a tank in your rear.", "WFBE_C_AICOM_VEHLIFT"],

	//--- ~ COMMUNITY / META / ECONOMY-TRUTH (always eligible unless a real flag applies) ~
	["Commanding? Delegated AI teams' kills pay their own squad wallet and the side war chest - not your personal funds. Play the whole board, not your K/D.", ""],
	["Support your commander: capturing and pushing towns, running convoys and holding the Bank are what actually grow the side's supply and cash.", ""],
	["GUER gets MORE dangerous the more towns it loses - a cornered resistance escalates to armour with AT/AA. Don't treat it as a mop-up.", "WFBE_C_GUER_PLAYERSIDE"],
	["Random wildcard events fire through the round - veteran companies, town uprisings, heliborne QRF. Stay flexible; the map isn't static.", ""],
	["Track your stats, MVPs and full match replays on the leaderboard at miksuu.com - every round is recorded there.", ""],
	["Join the community on Discord: discord.me/warfare - ask how anything works, find squads, and follow patch changelogs.", ""],
	["Found a bug or a broken mechanic? Report it on our Discord (discord.me/warfare) with what you were doing - it genuinely helps us fix it.", ""],
	["New here? Open Help in the WF menu - full pages on economy, capturing, commanding the AI and the factions, written for this exact mission.", ""],
	["Running an optional mods setup? Check the community guide on Discord (discord.me/warfare) so you load only what this server actually supports.", ""],
	["Class tags (SOL/SPEC/MED/ENG/SNI) show on the map and in your Notes - a medic's Redeployment Truck even gives medics a forward spawn.", ""]
];

//================================================================ ROTATION LOOP
_n = count _tips;
if (_n <= 0) exitWith {};

_deck = [];
_last = -1;   //--- index of the last tip shown, so we never repeat back-to-back across a refill.

while {true} do {

	//--- (Re)fill the deck when empty: [0 .. _n-1].
	if ((count _deck) <= 0) then {
		_deck = [];
		_i = 0;
		while {_i < _n} do {
			_deck set [count _deck, _i];
			_i = _i + 1;
		};
		//--- Guard against showing the same tip twice in a row at the refill boundary: if the
		//--- only remaining card would repeat _last (n==1 edge or a freak deck), we still show it,
		//--- but for n>1 we bias the first draw off _last below.
	};

	//--- Draw a random index from the deck (floor random count - A2-OA-safe, NOT selectRandom).
	_pick = floor (random (count _deck));
	if (_pick >= (count _deck)) then {_pick = (count _deck) - 1};   //--- paranoia: random can graze the top.
	_idx = _deck select _pick;

	//--- Avoid an immediate repeat across a refill (only meaningful when more than one card is left).
	if (_idx == _last && {(count _deck) > 1}) then {
		_pick = _pick + 1;
		if (_pick >= (count _deck)) then {_pick = 0};
		_idx = _deck select _pick;
	};

	//--- Remove the drawn index from the deck (rebuild without _pick - no deleteAt reliance).
	private ["_nd","_j"];
	_nd = [];
	_j = 0;
	while {_j < (count _deck)} do {
		if (_j != _pick) then {_nd set [count _nd, (_deck select _j)]};
		_j = _j + 1;
	};
	_deck = _nd;

	//--- Resolve + gate the chosen tip.
	_pair = _tips select _idx;
	_text = _pair select 0;
	_flag = _pair select 1;

	_ok = true;
	if (typeName _flag == "STRING" && {_flag != ""}) then {
		private ["_fval"];
		_fval = missionNamespace getVariable [_flag, 0];
		if (typeName _fval == "SCALAR" && {_fval < 1}) then {_ok = false};
		if (typeName _fval == "BOOL" && {!_fval}) then {_ok = false};
	};

	//--- Only a gated-out tip is skipped silently; an eligible tip is posted and counts as "last".
	if (_ok) then {
		systemChat ("TIP: " + _text);
		_last = _idx;
	};

	uiSleep _period;
};
