/*
	New-player onboarding cards (claude-gaming 2026-06-29).

	Lightweight, robust A2-OA 1.64 first-spawn welcome for new players - assessed the #1
	release gap. Pure client cosmetic: a short SEQUENCE of skippable structuredText `hint`
	cards explaining what WASP Warfare is, the win goal, the 3 core actions, where the
	scroll-wheel WF menu lives, commander/supply basics, EASA refits, and what happens on
	death/respawn. A mid-round joiner also gets a brief "you joined an in-progress match" note.

	Spawned ONCE from Init_Client.sqf AFTER clientInitComplete (see the guarded call there).
	Never blocks input or enrollment: it only paints `hint` cards on a real-time `uiSleep`
	cadence (so it still ticks even while a JIP client's sim is briefly paused) and touches
	no player/team/vote/money state.

	Gating:
	  - Fires ONCE per game-client session via a uiNamespace flag (survives respawn /
	    round restart within the same client launch, so it does not re-spam every round).
	  - Default-ON, A/B'able via WFBE_C_ONBOARDING_ENABLE (read here with getVariable
	    [name,1] so we do NOT have to touch the shared Init_CommonConstants).

	JIP vs fresh detection:
	  - No explicit JIP boolean exists in this mission; the convention is mission-`time`
	    based (Init_Client uses `time < 30` / `time > 7` as fresh-vs-late heuristics). We
	    capture mission `time` at the moment of the call: a fresh round starts near 0, so a
	    join above WFBE_CL_VAR_OnboardingJipThreshold (default 60s) is treated as mid-round.

	A2-OA 1.64 safe: hint/parseText, uiSleep, uiNamespace/missionNamespace getVariable
	[name,default], numbers/booleans via if/else latches. No isEqualType / isEqualTo /
	A3-only commands.
*/

private ["_commandHint","_easaEnabled","_easaHint","_enable","_guerNote","_isGuer","_isJip","_jipThreshold","_jipNote","_respawnNote","_scrollHint","_welcome"];

//--- Master toggle (default ON). Read locally so we never edit the shared Init_CommonConstants.
_enable = missionNamespace getVariable ["WFBE_C_ONBOARDING_ENABLE", 1];
if (_enable < 1) exitWith {};

//--- ONCE per game-client session. uiNamespace survives mission restart / respawn within the
//--- same client launch, so a returning player is not re-onboarded every round.
if (uiNamespace getVariable ["WFBE_CL_VAR_OnboardingShown", false]) exitWith {};
uiNamespace setVariable ["WFBE_CL_VAR_OnboardingShown", true];

//--- JIP heuristic: mission time at the moment of (post-init) call. Fresh round ~ 0; a late
//--- join sits well above the threshold. Mirrors the existing time<30 / time>7 conventions.
_jipThreshold = missionNamespace getVariable ["WFBE_CL_VAR_OnboardingJipThreshold", 60];
_isJip = (time > _jipThreshold);
_isGuer = false;
_easaEnabled = (missionNamespace getVariable ["WFBE_C_MODULE_WFBE_EASA", 0]) > 0;

//--- Wait until the player object is real and alive before showing anything (covers a slow JIP
//--- spawn). uiSleep is real-time so this still advances if the sim is briefly paused. Bounded
//--- so a never-spawning edge case can never wedge this spawn.
private "_t0"; _t0 = time;
waitUntil { uiSleep 1; (!isNull player && {alive player}) || ((time - _t0) > 120) };
if (isNull player) exitWith {};
if !(isNil "sideJoined") then {
	if (sideJoined in [resistance] && {(missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0}) then {
		_isGuer = true;
	};
};

//--- Let the join / BLACK-IN loading titles and the legacy v-stamp hint clear first.
uiSleep 7;

//--- CARD 1: WELCOME + win goal + the 3 core actions.
_welcome = parseText (
	"<t size='1.35' color='#28ff14'>Welcome to WASP Warfare, soldier.</t><br/><br/>"
	+ "<t color='#42b6ff'>The goal:</t> push the frontline by capturing towns and break the enemy HQ. The side that holds the map (or destroys the enemy headquarters) wins the round.<br/><br/>"
	+ "<t color='#42b6ff'>Your three core moves:</t><br/>"
	+ "<t color='#FFAC1C'>1. BUY</t> - drive to a friendly factory / your base and use the action menu to buy gear, vehicles and AI squads.<br/>"
	+ "<t color='#FFAC1C'>2. COMMAND / VOTE</t> - vote a side commander and give orders; the AI commander spends the side economy.<br/>"
	+ "<t color='#FFAC1C'>3. CAPTURE</t> - take a town by clearing & holding its camps, then standing on the town center until it flips to <t color='#1ff026'>green</t>."
);
hint _welcome;
uiSleep 16;

//--- CARD 2: SCROLL-ACTION hint (where build / buy / interact lives).
_scrollHint = parseText (
	"<t size='1.2' color='#28ff14'>The action menu is your toolbox.</t><br/><br/>"
	+ "Roll your <t color='#42b6ff'>mouse scroll-wheel</t> to open the action menu. The <t color='#42b6ff'>WF menu</t> in there is where you build structures, buy units, manage your AI and interact with the world.<br/><br/>"
	+ "Press <t color='#FFAC1C'>M</t> for the map - your units are <t color='#FFAC1C'>orange</t>, friendly towns are <t color='#1ff026'>green</t>, enemy towns are <t color='#000bde'>blue</t> / <t color='#de0300'>red</t>."
);
hint _scrollHint;
uiSleep 13;

//--- CARD 3: Commander / supply cue (why towns and orders matter).
_commandHint = parseText (
	"<t size='1.2' color='#28ff14'>Commander and supply move the war.</t><br/><br/>"
	+ "The commander uses <t color='#42b6ff'>side supply</t> to build factories, defences and upgrades. Captured towns feed that supply, so holding camps matters even when you are buying with your own cash.<br/><br/>"
	+ "Use the <t color='#42b6ff'>COMMAND / VOTE</t> tools to vote a commander and follow orders. If the AI is commander, it spends the side economy for you."
);
hint _commandHint;
uiSleep 12;

//--- CARD 4: EASA cue - only when the aircraft-loadout module is enabled.
if (_easaEnabled) then {
	_easaHint = parseText (
		"<t size='1.2' color='#28ff14'>Aircraft can refit at service points.</t><br/><br/>"
		+ "When EASA is unlocked, pilots in supported aircraft can use <t color='#42b6ff'>Loadout (EASA)</t> at base service points to swap anti-air, anti-ground or multirole kits.<br/><br/>"
		+ "Engineers can use repair-truck service points; GUER pilots can use friendly town centers."
	);
	hint _easaHint;
	uiSleep 12;
};

//--- CARD 5: GUER cue - only for playable resistance slots.
if (_isGuer) then {
	_guerNote = parseText (
		"<t size='1.2' color='#28ff14'>GUER plays differently.</t><br/><br/>"
		+ "You are the resistance side: no standard commander upgrade queue. Your kills unlock field tech, and destroyed enemy factories unlock FOB truck options.<br/><br/>"
		+ "Open the action / buy menus for <t color='#FFAC1C'>VBIED</t> and <t color='#FFAC1C'>FOB truck</t> plays. The RHUD shows <t color='#42b6ff'>Tech Kills</t> and <t color='#42b6ff'>FOB</t> tokens."
	);
	hint _guerNote;
	uiSleep 13;
};

//--- CARD 6: JIP cue - only for a mid-round joiner.
if (_isJip) then {
	_jipNote = parseText (
		"<t size='1.2' color='#28ff14'>You joined a match in progress.</t><br/><br/>"
		+ "The round is already underway - towns may already be captured and a commander may already be voted in. Check the <t color='#42b6ff'>map (M)</t> to read the current frontline, then grab gear and reinforce your side."
	);
	hint _jipNote;
	uiSleep 11;
};

//--- CARD 7: RESPAWN legend (one-liner on death/respawn).
_respawnNote = parseText (
	"<t size='1.2' color='#28ff14'>If you go down...</t><br/><br/>"
	+ "You respawn back at base (or a mobile respawn point) and keep playing - no permadeath. Re-buy / re-gear from the action menu and head back to the fight.<br/><br/>"
	+ "<t color='#42b6ff'>Need help?</t> Ask in chat or join our Discord: <t color='#28ff14'>discord.me/warfare</t><br/><br/>"
		+ "<t color='#28ff14'>Good luck out there!</t>"
);
hint _respawnNote;
uiSleep 10;

//--- Clear the last card so it does not linger on screen.
hintSilent "";
