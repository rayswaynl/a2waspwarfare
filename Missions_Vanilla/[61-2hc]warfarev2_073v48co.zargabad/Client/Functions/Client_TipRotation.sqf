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
	//--- ~ CORE LOOP ~
	["Town capture works on numbers, not flags: push more of your side into the 40m ring around the town centre than the enemy and hold it until it flips.", ""],
	["You can only attack a town that borders ground your side already controls. Hatched-yellow towns are still locked in peace-time and cannot be assaulted yet.", ""],
	["Defenders respawn ONCE when a friendly unit crosses the 600m perimeter of a town - commit a real push, not a lone scout.", ""],
	["Two currencies run the war. Cash is personal - you buy gear and units with it. Supply is the side pool - your commander spends it on structures and upgrades.", ""],
	["MHQ (Mobile HQ) is not just a spawn point - drive it forward and deploy it to plant your factories closer to the front and cut your reinforcement time.", ""],
	["Service points fully rearm, refuel, repair and heal. Use them before the next push - an empty mag or a red-engine vehicle is not a fighting asset.", ""],
	["The buy queue cap is per-factory: Barracks 10, Light Factory 5, Heavy and Air Factory 3 each. Cancel Last refunds the most recently queued order.", ""],
	["A Command Center lets you buy infantry and vehicles remotely from anywhere on the map. Without one you have to stand at the factory yourself.", ""],
	["Capturing an airfield gives a permanent 2000m counter-battery radar, a repair depot, and access to jet-tier aircraft at that location.", ""],
	["The Anti-Air Radar is a prerequisite for the Counter-Battery Radar. CB radar reveals firing artillery positions for 75 seconds - use it to plan counter-fire.", ""],
	["Bank (Federal Reserve): while your HQ stands it pays $6,000 every 5 minutes split among living players. Destroying the enemy Bank pays a lump sum.", ""],
	["Patrols grow over 4 upgrade levels; each active patrol reduces every player's AI recruit cap by 1. Do not over-invest in patrols at the cost of your own squad.", ""],
	["Auto Wall Construction (scroll-wheel action 14) places defensive barriers around your base structures. Turn it on after deploying the MHQ.", ""],
	["A MEV ambulance or Redeployment Truck parked within 500m of the front gives medics and their teammates a forward respawn at that vehicle.", ""],
	["Salvage trucks recover value from destroyed vehicles on the field. Run them after a large engagement - leaving wrecks is leaving money behind.", ""],
	["Supply trucks pay out when driven to a town centre within 30m. The town's Supply Value goes up, increasing its cash output and making it harder to take.", ""],
	["Class tags (SOL/SUP/MED/ENG/SNI) appear on the map and in the Notes tab so your team can see where specialists are without calling it on voice.", ""],
	["The Tactical Center fast-travels you and nearby squad members to a map point - use it to redeploy after a push instead of driving halfway across the map.", ""],
	["Gear you buy from a Barracks or town centre is saved per-session. On respawn it is automatically restored if a Barracks is still standing.", ""],
	["AI teams you command count against your AI slot budget, not the side's. Assign command only when you intend to actually direct the team.", ""],
	["Vote in a human Commander early. The AI Commander will build and spend the side economy autonomously, but a human can redirect that spending immediately.", ""],
	["Patrol level 3 completion pays an instant cash bonus to the whole side. Patrol level 4 completion pays an instant supply bonus.", ""],


	//--- ~ VETERAN / NON-OBVIOUS ~
	["Town ring count: game counts all living units of each side inside the 40m radius. Vehicles with crew count. Dead infantry do not.", ""],
	["A town flips immediately once the ring count tips - you do not wait for a timer if your side outnumbers the defender in the ring.", ""],
	["The Tactical Center's fast-travel has a range limit per destination. If a point is grayed out, it is out of reach from your current position.", ""],
	["Salvage payout scales with the vehicle's buy cost, not its current condition. A fully wrecked enemy MBT still pays near its full salvage rate.", ""],
	["Counter-battery radar triggers on live artillery fire. Mortars with short ranges and rockets both register - the readout is a 75s window, plan around that.", ""],
	["Strategic spawn pads (Command -> Constructions -> Strategic) place faction-specific spawn nodes in the field. Placement matters - out of cover means they get shelled.", ""],
	["Paradrop accuracy degrades with altitude. A lower, slower aircraft drops sticks closer together but exposes the plane longer to AA fire.", ""],
	["You can airlift your own HQ vehicle. Use it to relocate a threatened MHQ without driving it through enemy lines.", "WFBE_C_AIRLIFT_OWN_HQ"],
	["EASA (aircraft editor) saves per-aircraft loadout presets. Pre-arm your CAS slot before a push and you reload to that exact loadout after a rearm at service.", ""],
	["AI team kills pay into the side war chest and into that team's squad wallet - not your personal cash. Run teams for economy, not for your own K/D.", ""],

	//--- ~ FLAG-GATED FEATURES ~
	["OILFIELD (Takistan only): becomes contestable after ~1 hour. Hold it with your units to earn passive supply income. Watch your map for the marker.", "WFBE_C_OILFIELD_ENABLE"],
	["OILFIELD sabotage: an enemy that dwells inside the capture radius while your units are absent will knock the field offline. Repair it by holding it again.", "WFBE_C_OILFIELD_SABOTAGE"],
	["Skin selector: open the WF menu and use the SKIN button to pick your soldier's appearance. Your choice persists through respawns.", "WFBE_C_SKINSEL"],
	["Naval HVT carriers (Chernarus): three offshore LHDs are capturable. The central carrier holds the SCUD - control it to access carrier SCUD strikes.", "WFBE_C_NAVAL_HVT"],
	["SCUD STRIKE: capture the carrier SCUD and the Tactical Center gets a map-click strike option. It fires the carrier's warhead payload at your target.", "WFBE_C_SCUD_MENU"],
	["Land SCUD TEL unlocks at SCUD research L1. It can be destroyed before launch - the 5-minute countdown gives the enemy time to hunt it. Guard it or stay mobile.", "WFBE_C_ICBM_TEL"],
	["TEL shared cooldown: all five TEL munitions (Saturation, Recon Flash, FASCAM, Steel Rain, Bunker Buster) share one cooldown. One shot locks the others out.", "WFBE_C_ICBM_TEL"],
	["RECON FLASH (TEL): airburst reveals every enemy unit in an 800m radius for 45 seconds with temp map markers. Use it immediately before a planned assault.", "WFBE_C_ICBM_TEL_RECON_COST"],
	["FASCAM (TEL): scatters 24 AT mines across a 150m radius. They self-clear after 20 minutes and there is a cap of 2 live fields per side at once.", "WFBE_C_ICBM_TEL_FASCAM_COST"],
	["STEEL RAIN (TEL): rolling airbursts across a 300m area. Effective against infantry in the open; does not penetrate vehicles or structures.", "WFBE_C_ICBM_TEL_RAIN_COST"],
	["BUNKER BUSTER (TEL): precision single warhead. Guarantees destruction of the nearest enemy structure within 30m of impact. Most expensive TEL shot.", "WFBE_C_ICBM_TEL_BUSTER_COST"],
	["GUER insurgents are a third playable faction. They are a harassment side - no heavy base building, but mobile raid capability behind both frontlines.", "WFBE_C_GUER_PLAYERSIDE"],
	["GUER VBIED: arm it in range of the target and detonate. Cash is paid to your GUER team for every kill inside the blast radius.", "WFBE_C_GUER_VBIED_TYPE"],
	["GUER escalates with kills: more kills unlock higher vehicle tiers including the M113 VBIED. A low-kill GUER team is limited; a high-kill one is a real threat.", "WFBE_C_GUER_PLAYERSIDE"],
	["GUER Ka-137 carries flares - its countermeasure stock grows as the GUER side racks up kills. Early in a round the drone has few; late it is much harder to missile.", "WFBE_C_GUER_KA137_FLARE_LAUNCHER"],
	["GUER drones can spawn in swarms of two or three on the same target. One AA launcher may not be enough - coordinate if the drone count climbs.", "WFBE_C_GUER_KA137_SWARM"],
	["Command menu RALLY, REFIT and HOLD let you steer AI teams without a full command order. Any player can request AI support to pull a nearby squad.", "WFBE_C_CMD_MENU_V2"],
	["AI airmobile: the AI commander can fly its assault teams directly into contested towns via transport helicopter. Expect infantry drops on any contested flank.", "WFBE_C_AICOM_AIRMOBILE"],
	["AI vehicle lift: at sufficient air-factory research the AI can sling-lift ground vehicles behind your lines. A quiet flank can become an armoured threat fast.", "WFBE_C_AICOM_VEHLIFT"],

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
