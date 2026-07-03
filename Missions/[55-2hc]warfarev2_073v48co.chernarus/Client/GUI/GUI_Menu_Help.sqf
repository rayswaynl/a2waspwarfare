/* =====================================================================
   WASP WARFARE - HELP MENU CONTROLLER (REDESIGN)   A2 OA 1.64
   Draft REPLACEMENT for Client\GUI\GUI_Menu_Help.sqf.

   Same stateless switch-on-arg contract the dialog expects:
     ['onLoad'] execVM ...                     -> populate list, select 0
     ['onHelpLBSelChanged', _idx] call compile -> swap content + title

   Controls (see Dialogs_HelpMenu.hpp):
     160001  RscListBox        section list (left)
     160002  RscStructuredText content pane (right, in a controls group)
     160003  RscStructuredText dynamic title bar

   Sections (label list and _helps array MUST stay index-aligned & same length):
     0 Getting Started
     1 Controls
     2 Economy
     3 Combat & Capturing
     4 Commanding the AI
     5 Factions
     6 FAQ

   Only A2-OA-valid commands used: displayCtrl, lbAdd, lbSetCurSel,
   ctrlSetStructuredText, parseText, findDisplay, compile,
   preprocessFileLineNumbers. No A3-only commands.
   ===================================================================== */

private ["_action"];
disableSerialization;
_action = _this select 0;

//--- Shared palette (kept consistent with the rest of the WF UI).
#define HDR  "#2394ef"   /* section heading - WF blue   */
#define KEY  "#ffec1c"   /* key term / label - yellow   */
#define GOLD "#F5D363"   /* emphasis - gold             */
#define WARN "#e8bd12"   /* caution / commander - amber */

switch (_action) do {

	case "onLoad": {
		private ["_disp", "_lb"];
		_disp = findDisplay 508000;
		_lb = _disp displayCtrl 160001;
		lbClear _lb;
		{
			_lb lbAdd _x;
		} forEach [
			"Getting Started",
			"Controls",
			"Economy",
			"Combat & Capturing",
			"Commanding the AI",
			"Factions",
			"FAQ"
		];
		_lb lbSetCurSel 0;   // fires onLBSelChanged -> paints title + page 0
	};

	case "onHelpLBSelChanged": {
		private ["_changeTo", "_disp", "_titles", "_helps"];
		_changeTo = _this select 1;
		_disp = findDisplay 508000;

		//--- Title-bar label per section (index-aligned to the list).
		_titles = [
			"Getting Started",
			"Controls",
			"Economy",
			"Combat & Capturing",
			"Commanding the AI",
			"Factions",
			"Frequently Asked Questions"
		];

		_helps = [

//================================================================ 0  GETTING STARTED
"<t size='1.4' color='" + HDR + "' underline='true'>Getting Started</t><br /><br />
<t color='" + KEY + "'>CTI</t> (Conquer The Island) pits <t color='" + KEY + "'>West</t> against <t color='" + KEY + "'>East</t> for control of the map. Each side is led by a <t color='" + WARN + "'>Commander</t> who builds a base from the <t color='" + WARN + "'>MHQ</t> (Mobile HQ) and reinforces the team with bought units and vehicles.<br /><br />
<t size='1.2' color='" + KEY + "'>Your first five minutes</t><br />
1. Pick a class in the lobby (SOL / SPEC / MED / ENG / SNI). Tags show on the map and in your Notes.<br />
2. Spawn, then open the <t color='" + GOLD + "'>WF Menu</t> (scroll-wheel action, blue 'Options') for everything: buy gear, buy units, give orders.<br />
3. Head to the nearest contested <t color='" + KEY + "'>town</t> (blue/red circle on the map) and help capture it.<br /><br />
<t size='1.2' color='" + KEY + "'>How you win</t><br />
Default victory is <t color='" + GOLD + "'>Towns</t>: hold a target number of towns. Lobby parameters can switch this (e.g. <t color='" + GOLD + "'>Annihilation</t> = destroy all enemy forces and structures). Check the parameter screen if unsure.<br /><br />
<t size='1.2' color='" + KEY + "'>Respawn &amp; forward spawns</t><br />
While dead you pick a spawn from the yellow circles on the map. Base buildings (MHQ, Barracks, all Factories) are <t color='" + GOLD + "'>unlimited-range</t> spawns. A <t color='" + KEY + "'>MEV</t> (medical/ambulance vehicle) gives a <t color='" + GOLD + "'>forward</t> spawn within 500 m of it - drive one up to the fight so the team does not run from base every time. Service points, the Command Center and radars are NOT spawn points.<br /><br />
Tip: wait until a forward spawn exists before pushing a town, so deaths cost seconds, not a long walk.<br />",

//================================================================ 1  CONTROLS
"<t size='1.4' color='" + HDR + "' underline='true'>Controls</t><br /><br />
Most of WASP is driven from the <t color='" + GOLD + "'>WF Menu</t> rather than hotkeys. Open it from the <t color='" + KEY + "'>scroll-wheel action menu</t> -> blue <t color='" + GOLD + "'>Options</t> (works on foot and while mounted).<br /><br />
<t size='1.2' color='" + KEY + "'>WF Menu buttons</t><br />
- <t color='" + GOLD + "'>Purchase Gear</t> - weapons/equipment (in Barracks range, or at a captured town centre's stairs).<br />
- <t color='" + GOLD + "'>Purchase Units</t> - infantry/vehicles/aircraft (in a Factory's range; remote-buy if a Command Center exists).<br />
- <t color='" + GOLD + "'>Tactical Center</t> - UAV, ammo drops, artillery and support requests.<br />
- <t color='" + GOLD + "'>Service Point</t> - rearm, refuel, repair, heal.<br />
- <t color='" + GOLD + "'>Economy / Command / Upgrades</t> - commander tools (sell structures, set orders, research).<br />
- <t color='" + GOLD + "'>Help</t> - this panel.<br /><br />
<t size='1.2' color='" + KEY + "'>Construction quick-actions</t> (scroll-wheel custom actions)<br />
- Action 14 - <t color='" + GOLD + "'>Auto Wall Construction</t> toggle around base structures.<br />
- Action 16 - <t color='" + GOLD + "'>Auto Manning Defence</t> mode.<br />
- Action 17 - <t color='" + GOLD + "'>Sell</t> the nearest fortification / static defence.<br /><br />
<t size='1.2' color='" + KEY + "'>Comfort</t><br />
- <t color='" + GOLD + "'>Earplugs</t> toggle fades radio/voice and works while mounted.<br />
- <t color='" + GOLD + "'>Class Info</t> action (and the join screen) explains your role's kit.<br /><br />
Note: WASP intentionally uses the action menu instead of a help hotkey, so there is no key to memorise - it is always one scroll away.<br />",

//================================================================ 2  ECONOMY
"<t size='1.4' color='" + HDR + "' underline='true'>Economy</t><br /><br />
Two currencies drive the war: <t color='" + GOLD + "'>$ cash</t> (you spend it on gear and units) and <t color='" + GOLD + "'>supply</t> (the side resource the commander spends on structures and upgrades). Both sides start with <t color='" + GOLD + "'>$30,000</t> and <t color='" + GOLD + "'>12,800 supply</t>.<br /><br />
<t size='1.2' color='" + KEY + "'>Where income comes from</t><br />
- Captured <t color='" + KEY + "'>towns</t> pay supply and cash. A fully 'pushed' town (high Supply Value) pays more and defends harder.<br />
- <t color='" + KEY + "'>Supply trucks</t> raise a town's Supply Value: shuttle them between MHQ / Service Point (to reload) and the town centre's 30 m delivery range. The counter reads e.g. 10/70.<br /><br />
<t size='1.2' color='" + KEY + "'>The Bank (Federal Reserve / Bank Rossii)</t><br />
A 9,500-supply structure, one per side, placed &gt; 800 m from your HQ. While your HQ stands it pays <t color='" + GOLD + "'>$6,000 every 5 minutes</t> split among living players. Destroying the enemy Bank awards <t color='" + GOLD + "'>+10,000</t> side supply and <t color='" + GOLD + "'>$25,000</t> to the killer. Both Banks are marked on the map for both sides - it is a real endgame objective.<br /><br />
<t size='1.2' color='" + KEY + "'>Factory queue &amp; refunds</t><br />
The buy menu shows the queue as <t color='" + GOLD + "'>N/CAP</t>. Caps: Barracks 10, Light Factory 5, Heavy/Aircraft 3. <t color='" + GOLD + "'>Cancel Last</t> refunds your most recent queued order (up to 50% on discounted orders).<br /><br />
<t size='1.2' color='" + KEY + "'>Premium unlocks</t><br />
Hold <t color='" + GOLD + "'>Krasnostav</t> -> Czech T-72 at Heavy Factory L4 ($7,000). Hold <t color='" + GOLD + "'>NW Airfield</t> -> RM-70 rocket artillery at Light Factory L4 ($6,800). Unlocks apply to the holding side only.<br />",

//================================================================ 3  COMBAT & CAPTURING
"<t size='1.4' color='" + HDR + "' underline='true'>Combat &amp; Capturing</t><br /><br />
The map is a ring of <t color='" + KEY + "'>towns</t>, each a 500 m circle. You can only attack towns adjacent to ground you already hold.<br /><br />
<t size='1.2' color='" + KEY + "'>Reading town markings</t><br />
- <t color='" + KEY + "'>Blue / red 400 m</t> ring - capturable, adjacent to your territory.<br />
- <t color='" + WARN + "'>Hatched yellow 600 m</t> - in 'peace-time' after a recent capture; not yet attackable.<br />
- <t color='#ff8800'>Orange 400 m</t> - an attack is in progress.<br />
- <t color='#33cc33'>Hatched green 600 m</t> - captured by your side.<br /><br />
<t size='1.2' color='" + KEY + "'>How a capture works</t><br />
1. Defenders only spawn when a friendly unit crosses the <t color='" + GOLD + "'>600 m</t> line - cross deliberately.<br />
2. Take the town's <t color='" + KEY + "'>Strongpoints</t> (small cylinders; watch the 'strongpoint' counter).<br />
3. Then create numerical superiority in the <t color='" + GOLD + "'>40 m</t> ring around the depot (the 'town' counter) to capture.<br /><br />
<t size='1.2' color='" + KEY + "'>Counter-battery &amp; air defence</t><br />
- <t color='" + KEY + "'>Anti-Air Radar (AAR)</t> tracks enemy aircraft above ~30 m (red diamond on map); prerequisite for the CBR.<br />
- <t color='" + KEY + "'>Counter Battery Radar (CBR)</t>, 2,400 supply, marks enemy artillery firing positions for 75 s while your AAR is alive. The CBR upgrade grows its radius 750 -> 1,500 -> 2,000 m. Capturing an airfield grants a free permanent 2,000 m CBR.<br /><br />
<t size='1.2' color='" + KEY + "'>Airfields</t><br />
NWAF, NEAF and Balota are capturable (40 SV, PMC garrison). Taking one gives a repair point and an exclusive hangar with unique aircraft (L-39, An-2, Mi-17 variants). Aircraft buy at hangars (green map symbol) when an Air Factory exists.<br />",

//================================================================ 4  COMMANDING THE AI
"<t size='1.4' color='" + HDR + "' underline='true'>Commanding the AI</t><br /><br />
Either side can be run by an <t color='" + GOLD + "'>AI Commander</t>. It manages supply, builds the base, researches upgrades and leads its HQ teams in assaults on towns.<br /><br />
<t size='1.2' color='" + KEY + "'>Taking command</t><br />
If no human takes the Commander slot within 5 minutes of round start (re-armed whenever a player commander leaves), the AI takes over building. You can claim Commander at any time. Even then the AI keeps fighting with its own HQ teams and never leaves them idle, while you run the economy and issue orders. <t color='" + GOLD + "'>Any team you order directly becomes yours.</t><br /><br />
<t size='1.2' color='" + KEY + "'>Commander tools (WF Menu, in Command Center range)</t><br />
- <t color='" + GOLD + "'>Economy</t> - sell structures, distribute income.<br />
- <t color='" + GOLD + "'>Command Center</t> - set team orders and squad respawn.<br />
- <t color='" + GOLD + "'>Upgrade Menu</t> - research better equipment and unlocks.<br /><br />
<t size='1.2' color='" + KEY + "'>Patrols &amp; convoys (upgrade)</t><br />
Patrols upgrade across 4 levels (300 / 1,600 / 2,400 / 3,200 supply). Up to <t color='" + GOLD + "'>2 active patrols</t> per side; each active patrol reduces every player's max AI by 1. Level 4 fields a <t color='" + KEY + "'>convoy</t> supply truck that pays $750 split equally at each town stop.<br /><br />
<t size='1.2' color='" + KEY + "'>Team composition notes</t><br />
- Tanks and wheeled APCs arrive crewed by engineers.<br />
- Commander field compositions are capped at 3 per base area (cash refunded over-cap).<br />
- Defense budgets cap statics / fortifications / mines per category; statics &amp; mines are blocked when 3+ enemy ground units are in base range.<br />",

//================================================================ 5  FACTIONS
"<t size='1.4' color='" + HDR + "' underline='true'>Factions</t><br /><br />
WASP runs <t color='" + GOLD + "'>three</t> living factions, not two sides plus neutral garrisons.<br /><br />
<t size='1.2' color='" + KEY + "'>West &amp; East</t><br />
The two playable belligerents, each led by a human or AI Commander, fighting for the towns and the win condition above.<br /><br />
<t size='1.2' color='" + KEY + "'>GUER resistance (third faction)</t><br />
GUER is an active third force. Its mechanized patrols grow <t color='" + GOLD + "'>more dangerous the more towns it loses</t> - technicals while it holds the map, escalating to BRDM-2 armour with AT/AA and a second patrol once squeezed below 20 towns. Treat a cornered GUER as a real threat, not a mop-up.<br /><br />
<t size='1.2' color='" + KEY + "'>Clean captures</t><br />
Capturing a town from GUER no longer hands you its static weapon emplacements - you take the ground clean and bring or build your own defences. GUER rebuilds its statics if it recaptures.<br /><br />
<t size='1.2' color='" + KEY + "'>Wildcards</t><br />
Random battlefield events fire through the round - veteran companies, town uprisings, heliborne QRF and more. Stay flexible.<br /><br />
<t size='1.2' color='" + KEY + "'>Classes (both sides)</t><br />
SOL / SPEC / MED / ENG / SNI, shown on join and via the <t color='" + GOLD + "'>Class Info</t> action; tags appear on the map and in Notes. A medic-only <t color='" + KEY + "'>Redeployment Truck</t> (Light Factory, violet row) gives medics a forward spawn.<br />",

//================================================================ 6  FAQ
"<t size='1.4' color='" + HDR + "' underline='true'>Frequently Asked Questions</t><br /><br />
<t size='1.2' color='" + KEY + "'>Where do I buy things?</t><br />
Open the WF Menu in range of the right structure: gear at the <t color='" + GOLD + "'>Barracks</t> (or a captured town centre's stairs), infantry/vehicles at the matching <t color='" + GOLD + "'>Factory</t>. A <t color='" + GOLD + "'>Command Center</t> lets you remote-buy infantry and vehicles from anywhere.<br /><br />
<t size='1.2' color='" + KEY + "'>Why can't I attack that town?</t><br />
It is either not adjacent to your territory, or it is in hatched-yellow <t color='" + GOLD + "'>peace-time</t> after a recent capture. Wait for the marker to clear, or push an adjacent town first.<br /><br />
<t size='1.2' color='" + KEY + "'>I keep spawning at base - why?</t><br />
You died more than 500 m from any MEV / forward spawn. Drive a MEV up near the fight, or capture a closer town, to create a nearer spawn.<br /><br />
<t size='1.2' color='" + KEY + "'>How do I get money?</t><br />
Capture and push towns, build the Bank (pays every 5 min while your HQ stands), kill the enemy Bank, and run convoy supply trucks.<br /><br />
<t size='1.2' color='" + KEY + "'>What are the structure tags on the map?</t><br />
MHQ, B (Barracks), LF/HF/AF (Light/Heavy/Air Factory), S (Service Point), C (Command Center), AAR (Anti-Air Radar), CBR (Counter Battery Radar), Bank (Federal Reserve).<br /><br />
<t size='1.2' color='" + KEY + "'>Server rules</t><br />
No team-killing, HQ-entry only as commander, no building-stacking inside objects &gt;50%, factories must have an entrance, no bug-using or hacking. Admins escalate: warning -> kick -> time-ban. Play fair.<br />"

		];

		//--- Guard the index, then paint title + content.
		if (_changeTo < 0 || _changeTo >= (count _helps)) exitWith {};

		(_disp displayCtrl 160003) ctrlSetStructuredText parseText
			("<t size='1.25' color='#2394ef' shadow='1'>WASP Warfare  -  " + (_titles select _changeTo) + "</t>");

		(_disp displayCtrl 160002) ctrlSetStructuredText parseText (_helps select _changeTo);
	};
};
