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

private ["_enable","_period","_initial","_tips","_gate","_flag","_gateValue","_deck","_n","_i","_last","_pick","_idx","_pair","_text","_ok"];

//--- Master toggle (default ON). Registered in Common\Init\Init_CommonConstants.sqf (cmdcon42-q).
_enable = missionNamespace getVariable ["WFBE_C_TIPS_ENABLE", 1];
if (typeName _enable != "SCALAR") exitWith {};
if (_enable < 1) exitWith {};

//--- Cadence + first-line delay (both real-time seconds). Defaults mirror Init_CommonConstants.
_period  = missionNamespace getVariable ["WFBE_C_TIPS_PERIOD", 900];
_initial = missionNamespace getVariable ["WFBE_C_TIPS_INITIAL", 420];
if (typeName _period != "SCALAR") then {_period = 900};
if (typeName _initial != "SCALAR") then {_initial = 420};
if (_period < 30) then {_period = 30};       //--- floor so a mis-set param can't hammer the chat.
if (_initial < 0) then {_initial = 0};

//--- Wait for a real, alive player before we start (covers a slow JIP spawn). Bounded so a
//--- never-spawning edge case can never wedge this spawn. uiSleep is real-time.
private "_t0"; _t0 = time;
waitUntil { uiSleep 1; (!isNull player && {alive player}) || ((time - _t0) > 120) };
if (isNull player) exitWith {};

//--- Let onboarding cards / join titles clear before the first tip.
uiSleep _initial;

//================================================================ TIP POOL (21)
//--- REDONE 2026-07-08 (GR-2026-07-08a, governance section 14 owner directive: "kind of
//--- suck -- redo them"). Replaces the prior 61-entry pool (this header had been
//--- stale at "(50)" since the pool grew past its original size). Full rewrite, not an
//--- append: veteran-aware, non-obvious-mechanic focus, zero patch-history phrasing in
//--- any tip string. Every claim + every gate flag name re-verified against source on
//--- this branch before writing (GUI_Menu_Command.sqf, Rsc/Dialogs.hpp button text=,
//--- Client_ModDetect.sqf, Common/Init/Init_CommonConstants.sqf, Rsc/Parameters.hpp,
//--- Client_QOL_Advisor.sqf, Client/GUI/GUI_Menu_Help.sqf). No unreleased/unmerged
//--- mechanic is referenced.
//--- [tipText, gateFlagName]. gateFlagName "" = always shown. Every claim verified against
//--- the mission code / Client\GUI\GUI_Menu_Help.sqf on this branch (cmdcon42-q).
_tips = [
	//--- ~ COMMANDING WITHOUT THE SEAT ~
	["Not commanding? Click AI: FOCUS TOWN in the Command menu, then click a town on the map - it points the still-running AI commander's whole strategy at that objective without you taking the seat.", ""],
	["Pinned down and not commanding? REQUEST AI SUPPORT in the Command menu calls the nearest free same-side AI team to your position - a real reinforcement, not just a marker ping.", "WFBE_C_CMD_MENU_V2"],
	["Not commanding? The Command menu's PUSH/HOLD posture buttons and the Split Up/Push Together/Harass/Fall Back field orders are quick nudges for the still-running AI - cheaper than taking the seat, but they only bite while no human holds command.", ""],
	["The Command menu shows a live readout of what the AI commander is actually doing right now - its objective and focus town - even while you are not commanding. Read it before deciding whether to take the seat.", ""],

	//--- ~ THE WAR ROOM (COMMANDER) ~
	["Taking command does not mean going it alone: the AI becomes your quartermaster, founding and refilling teams for you, while you personally direct every squad from the war room.", ""],
	["Commanding but drowning in micromanagement? The war room's Squad Command toggle can hand maneuver back to the AI (AI Strategy mode) while you keep running the economy and requesting units.", ""],
	["Commanding? Select a team in the war-room roster, then RALLY, REFIT, or HOLD to steer that one squad directly instead of waiting on the AI's own judgment.", "WFBE_C_CMD_MENU_V2"],
	["Commander in a hurry? ALL PUSH releases every AI team to autonomous town-pushing; ALL HOLD pulls them all back to the nearest road to dig in. One click, whole roster.", ""],
	["A stuck or useless AI team does not have to sit there forever - DISBAND (all teams, or just the one you have selected) is a two-click-confirm failsafe that stands teams down safely, away from players.", ""],
	["If the war room's Artillery button is lit, click it then a map point to request AI-assisted fire - it only lands if your side actually has artillery pieces standing.", "WFBE_C_AICOM_PLAYER_ARTY"],

	//--- ~ NEW MUNITIONS (LAND TEL) ~
	["SCUD research Level 1 unlocks the conventional land TEL platform in the Tactical Center list; Level 2 is what unlocks the old nuclear shot. The TEL is destroyable before it fires, so guard it or keep it moving.", "WFBE_C_ICBM_TEL"],
	["All five TEL strikes - Saturation, Recon Flash, FASCAM, Steel Rain, Bunker Buster - share ONE cooldown. Fire any one of them and the other four lock out until it resets.", "WFBE_C_ICBM_TEL"],
	["Saturation is the carrier-sourced MIRV strike fired through the land TEL - the single most expensive shot in the TEL kit, and it still burns the one shared TEL cooldown like everything else.", "WFBE_C_ICBM_TEL_SAT_COST"],

	//--- ~ LOGISTICS, REPAIR & REARM ~
	["Supply trucks and supply-capable helicopters only pay out at your Command Center (the C marker) - cargo sitting in a parked vehicle anywhere else is money you have not earned yet.", ""],
	["Service points fully rearm, refuel, repair and heal in one visit. Use one before your next push, not after - an empty mag or a smoking engine is not a fighting asset.", ""],
	["Salvage trucks pay out on wrecks by the vehicle's original buy cost, not its current condition - even a fully dead enemy MBT is still worth the drive to salvage it.", ""],
	["Park a MEV ambulance or Redeployment Truck within 500m of the front and it becomes a forward respawn point for medics and their teammates - cuts the walk back into the fight.", ""],
	["EASA-capable aircraft save per-loadout presets at service points. Set your CAS loadout once and every rearm restores that exact configuration instead of the default.", "WFBE_C_MODULE_WFBE_EASA"],

	//--- ~ TACTICAL CENTER & FIELD PLACEMENT ~
	["The Tactical Center fast-travels you and nearby squadmates to a map point, but every destination has a range limit - a greyed-out point is not broken, it is just out of reach from where you are standing.", ""],
	["The Strategic build category places faction-specific spawn nodes out in the field. They die to shelling just like anything else, so cover matters as much as the drop location itself.", ""],

	//--- ~ QUALITY OF LIFE ~
	["The mission auto-detects a curated set of optional client mods on join - JSRS sound, Blastcore/JTD visual FX, ShackTac HUD - acks it once, and quietly suppresses its own overlapping effects for you. Running none of them costs you nothing.", "WFBE_C_MODHOOKS"]
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
