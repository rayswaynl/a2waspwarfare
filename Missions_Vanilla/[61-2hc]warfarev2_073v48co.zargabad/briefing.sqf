//--- Author [ICE] & Net_2  (map-notes redesign 2026-06-29)
//---
//--- WHAT CHANGED: the Notes/Diary is now split into FOUR named subjects via
//--- createDiarySubject (A2-OA 1.00+; A2-OA-valid, NOT A3-only) so a new player can
//--- find topics by tab instead of one flat list. createDiarySubject returns a Number (use the String name as the id)
//--- subject id; createDiaryRecord["<thatId>", [...]] files a record under that tab.
//---
//--- ORDERING GOTCHA (unchanged): A2-OA PREPENDS new records, so the in-game order of
//--- pages within a subject is the REVERSE of source order here. Each subject below is
//--- written bottom-up: the page meant to show FIRST in-game is the LAST createDiaryRecord
//--- call for that subject. Subjects themselves are also prepended; we add them in the
//--- order that puts "Welcome / Start Here" topmost in the Notes tab.
//---
//--- LOAD WIRING: unchanged. Client\Init\Init_Client.sqf preprocess-compiles this whole
//--- file once per client after the Commander Update FSM block. No new wiring needed.
//---
//--- All records are created on `player` (identity-bound, survive respawn). Accent gold
//--- is #F5D363, used for emphasis and 1.2-size sub-headers, matching house style.

//===========================================================================
//  SUBJECTS  (created first so records can be filed under them)
//  createDiarySubject [ name, displayName ]  -> the String NAME passed is the id used by createDiaryRecord; assign it explicitly
//  the subject id in createDiaryRecord. Picture arg is optional and omitted here.
//===========================================================================
private ["_subFactions","_subAdvanced","_subBasics","_subStart"];

//--- Add in reverse of desired top-to-bottom tab order (engine prepends subjects too):
_subFactions = "WFNotesFactions"; player createDiarySubject ["WFNotesFactions", "Sides & AI Commander"];
_subAdvanced = "WFNotesAdvanced"; player createDiarySubject ["WFNotesAdvanced", "Advanced & Economy"];
_subBasics   = "WFNotesBasics"; player createDiarySubject ["WFNotesBasics",   "How To Play"];
_subStart    = "WFNotesStart"; player createDiarySubject ["WFNotesStart",    "Start Here"];


//===========================================================================
//  SUBJECT: Start Here   (newcomer quick-start)
//  Written bottom-up: "Welcome" is last so it shows FIRST in-game.
//===========================================================================

player createDiaryRecord [_subStart, ["Key Controls",
	"<br/><t size='1.2' color='#F5D363'>The controls you need</t><br/><br/>" +
	"<t color='#F5D363'>M</t> - open the map. Towns, both bases, both banks and airfields are marked. Your class tag (SOL/SUP/MED/ENG/SNI) follows you on the map.<br/><br/>" +
	"<t color='#F5D363'>Mouse scroll wheel</t> - opens your <t color='#F5D363'>action menu</t>. The <t color='#F5D363'>WF menu</t> lives here: it is how you buy gear, units and vehicles, change class, request upgrades, and more. You must be inside a base or near a factory for the buy options to appear.<br/><br/>" +
	"<t color='#F5D363'>Class Info</t> action (scroll menu) - re-read what your current class can do at any time.<br/><br/>" +
	"<t color='#F5D363'>Respawn</t> - when you die you pick a spawn point on the map: your base, or any town strongpoint your side holds."
]];

player createDiaryRecord [_subStart, ["Your First 5 Minutes",
	"<br/><t size='1.2' color='#F5D363'>New here? Do this</t><br/><br/>" +
	"1. Press <t color='#F5D363'>M</t> and look at the map - find your base and the nearest contested town.<br/><br/>" +
	"2. Scroll-wheel to open the <t color='#F5D363'>WF menu</t> at base. Buy gear from the Barracks [B] and a class that suits you (see the Class Guide).<br/><br/>" +
	"3. Grab a vehicle from the Light Factory [LF] or ride with the team toward a town.<br/><br/>" +
	"4. Help <t color='#F5D363'>capture towns</t> (see How To Play) - that is how your side wins ground and earns income.<br/><br/>" +
	"5. Do not micro-manage the base. A human or AI <t color='#F5D363'>commander</t> runs construction and upgrades. You fight."
]];

player createDiaryRecord [_subStart, ["Welcome to WASP Warfare",
	"<br/>Warfare blends team multiplayer with realtime strategy. Two armies - <t color='#F5D363'>WEST (BLUFOR)</t> and <t color='#F5D363'>EAST (OPFOR)</t> - fight for control of the whole map, each led by a commander.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>How you win</t><br/>" +
	"Capture towns to expand and earn income, then <t color='#F5D363'>destroy the enemy HQ</t> - while defending your own. A side whose HQ is gone and cannot recover is finished.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Two resources</t><br/>" +
	"<t color='#F5D363'>Cash ($)</t> is yours - it buys weapons, units and vehicles.<br/>" +
	"<t color='#F5D363'>Supply</t> is the commander's - it builds and upgrades factories and structures.<br/><br/>" +
	"Read <t color='#F5D363'>Your First 5 Minutes</t> next, then <t color='#F5D363'>Key Controls</t>."
]];


//===========================================================================
//  SUBJECT: How To Play   (core loop: towns, economy, buying, controls)
//  Written bottom-up so the in-game order reads: Capturing Towns -> Income &
//  Economy -> Buying Units & Structures -> Commander & War Room.
//===========================================================================

player createDiaryRecord [_subBasics, ["Commander & the War Room",
	"<br/><t size='1.2' color='#F5D363'>Who is the commander?</t><br/>" +
	"One commander per side runs the strategy: deploys and relocates the HQ (the Mobile HQ vehicle), builds and sells factories and defences, researches upgrades, and gives the team orders. It can be a player or the <t color='#F5D363'>AI Commander</t> (see Sides & AI Commander).<br/><br/>" +
	"<t size='1.2' color='#F5D363'>The Command Center / War Room</t><br/>" +
	"Build a <t color='#F5D363'>Command Center [CC]</t> to unlock the war-room tools: buy remotely from anywhere on the map, fire <t color='#F5D363'>artillery missions</t>, and start upgrades. Build an <t color='#F5D363'>Anti-Air Radar [AAR]</t> to track enemy aircraft on the map and to enable the Counter Battery Radar.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Commander priorities</t><br/>" +
	"Build factories early. Keep some supply in reserve for the AAR/CBR and the Bank. Spend upgrade supply on the Barracks and on the factory type your team uses most."
]];

player createDiaryRecord [_subBasics, ["Buying Units & Structures",
	"<br/><t size='1.2' color='#F5D363'>Where you buy</t><br/>" +
	"Stand inside a base perimeter or near a factory, scroll-wheel, and use the <t color='#F5D363'>WF menu</t>. A <t color='#F5D363'>Command Center</t> lets the commander buy from anywhere.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Factories (and their map letters)</t><br/>" +
	"Barracks [B] - gear and infantry.<br/>" +
	"Light Factory [LF] - light vehicles.<br/>" +
	"Heavy Factory [HF] - tanks and APCs.<br/>" +
	"Air Factory [AF] - helicopters and aircraft.<br/>" +
	"Service Point [SP] - rearm, repair, refuel.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Reading the buy menu</t><br/>" +
	"Special vehicles are colour-coded; single-click any entry for a usage hint. The queue depth shows as <t color='#F5D363'>N/CAP</t> - caps grow with factory level (Barracks 10+, Light 5+, Heavy/Air 3+). You can cancel the last queued order for a refund.<br/><br/>" +
	"Structures (factories, CC, AAR, Bank, defences) are placed by the <t color='#F5D363'>commander</t> from the Construction Menu near the HQ."
]];

player createDiaryRecord [_subBasics, ["Income & Economy",
	"<br/><t size='1.2' color='#F5D363'>Two pools, two owners</t><br/>" +
	"<t color='#F5D363'>Cash ($)</t> is personal - you spend it on gear, units and vehicles.<br/>" +
	"<t color='#F5D363'>Supply</t> is the side pool - the commander spends it on building and upgrading.<br/><br/>" +
	"Both sides start with <t color='#F5D363'>$30,000 cash and 12,800 supply</t>.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>The +SV income line</t><br/>" +
	"Each town your side holds feeds your side <t color='#F5D363'>Supply Value (SV)</t> over time - you will see a recurring <t color='#F5D363'>+SV</t> income tick. More towns held = more SV income = more units and upgrades. This is why capturing and holding towns matters: it pays for the war.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>The Bank (endgame cash)</t><br/>" +
	"Once the commander builds the <t color='#F5D363'>Federal Reserve / Bank Rossii</t>, your side earns <t color='#F5D363'>$6,000 total every 5 minutes</t>, split among living players, for as long as your HQ stands. See Advanced & Economy."
]];

player createDiaryRecord [_subBasics, ["Capturing Towns",
	"<br/>Capturing towns is the core of the game: it grants <t color='#F5D363'>income (+SV)</t>, forward respawns, and ground toward the enemy HQ.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Step 1 - clear & hold the camps</t><br/>" +
	"Take the <t color='#F5D363'>strongpoints</t> (the small bunker camps around the town circle) first. A camp your side holds becomes a <t color='#F5D363'>respawn point</t> as long as you stay within the town's range.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Step 2 - take the town centre</t><br/>" +
	"With the camps yours, dominate the <t color='#F5D363'>town depot</t> - the marked depot circle at the centre. Hold numerical superiority there and the town flips to your side.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Capture grace period</t><br/>" +
	"After you take a town, enemy AI cannot respawn there for <t color='#F5D363'>5 minutes</t>, and any lingering enemy defenders have <t color='#F5D363'>3 minutes</t> to clear out. Use this window to dig in and bring up defences before the next push."
]];


//===========================================================================
//  SUBJECT: Advanced & Economy   (the long "experimental" content)
//  Written bottom-up so the in-game order leads with the Bank/CBR/airfields
//  economy material, then the deeper systems.
//===========================================================================

player createDiaryRecord [_subAdvanced, ["Class Guide",
	"<br/>Your class sets your role and abilities. It is shown as a quiet hint when you join or change class (top right), and re-readable from the <t color='#F5D363'>Class Info</t> action.<br/><br/>" +
	"<t color='#F5D363'>ENGINEER</t> - repair vehicles, salvage wrecks, restore camps, use EASA at repair-truck service points.<br/><br/>" +
	"<t color='#F5D363'>SOLDIER</t> - 1.5x AI team size, restore camps.<br/><br/>" +
	"<t color='#F5D363'>SPECOPS</t> - lockpick enemy vehicles, run supply missions.<br/><br/>" +
	"<t color='#F5D363'>SPOTTER (Sniper)</t> - spot enemies as map marks, lockpick, restore camps.<br/><br/>" +
	"<t color='#F5D363'>MEDIC</t> - fast healing, restore camps, and the only class that can spawn at the Medic Redeployment Truck.<br/><br/>" +
	"Class tags (SOL/SUP/MED/ENG/SNI) appear on the map."
]];

player createDiaryRecord [_subAdvanced, ["Patrols, Convoys & Queues",
	"<br/><t size='1.2' color='#F5D363'>Patrols and Convoys</t><br/>" +
	"The commander can research the Patrols upgrade (4 levels - supply 300 / 1,600 / 2,400 / 3,200). Patrols spawn near your HQ and push toward the frontline, capturing towns as they go (max 2 active per side). <t color='#F5D363'>Level 4 Convoys</t> add a supply truck to each patrol that pays your whole team $750, split equally, at every town stop. Each active patrol lowers every player's max AI by 1.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Factory Queue (N/CAP)</t><br/>" +
	"The buy menu shows queue depth as <t color='#F5D363'>N/CAP</t>. Caps scale with factory level (Barracks min 10, Light 5, Heavy/Air 3). Cancel the last queued order for a refund (capped at 50% if a discount was applied).<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Medic Redeployment Truck</t><br/>" +
	"Medics only - a forward spawn truck from the Light Factory (violet row). It activates when parked with the engine off, a free cargo seat, and at least 500 m from any non-friendly town."
]];

player createDiaryRecord [_subAdvanced, ["Airfields & Premium Unlocks",
	"<br/><t size='1.2' color='#F5D363'>Airfields</t><br/>" +
	"NWAF, NEAF and Balota Airfield are capturable towns (max 40 SV; resets to 10 on capture). Holding an airfield gives a repair point, a permanent 2,000 m CBR for that field, and an exclusive hangar stocking aircraft found nowhere else (L-39, An-2, Mi-17 variants on Chernarus).<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Capture-to-Unlock premium units</t><br/>" +
	"Holding <t color='#F5D363'>Krasnostav</t> unlocks the Czech T-72 (Heavy Factory level 4, $7,000).<br/>" +
	"Holding <t color='#F5D363'>NW Airfield</t> unlocks the RM-70 rocket artillery (Light Factory level 4, $6,800, fully integrated into artillery fire missions).<br/>" +
	"Each unlocks for the holding side only, at your own factories, while you hold the trigger town."
]];

player createDiaryRecord [_subAdvanced, ["Building Bases (Commander)",
	"<br/>Each side starts with one <t color='#F5D363'>Mobile HQ [MHQ]</t>. Deploy it to found a base, then add Barracks, Light/Heavy/Air factories, a Command Center, an Anti-Air Radar and a Service Point from the Construction Menu.<br/><br/>" +
	"The HQ can be packed up and redeployed, and you can run multiple bases. Defence budget is capped per category per base (it scales with Barracks level), and statics and mines are blocked if <t color='#F5D363'>3+</t> enemy ground units are inside base range.<br/><br/>" +
	"If your HQ depot is destroyed, the team can <t color='#F5D363'>RECOVER HQ</t> at the wrecked depot (commander team only, a cash cost applies) - this is your lifeline, defend it."
]];

player createDiaryRecord [_subAdvanced, ["Bank & Counter Battery Radar",
	"<br/><t size='1.2' color='#F5D363'>Bank (endgame)</t><br/>" +
	"The commander builds the <t color='#F5D363'>Federal Reserve / Bank Rossii</t> (9,500 supply; must be placed more than 800 m from your HQ, one per side). While your HQ stands it pays <t color='#F5D363'>$6,000 total every 5 minutes</t>, split among living team members. Destroying the enemy bank awards <t color='#F5D363'>+10,000 side supply</t> and <t color='#F5D363'>$25,000 to the killer</t>. Both banks are marked on the map for both sides.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Counter Battery Radar (CBR)</t><br/>" +
	"Build the CBR (2,400 supply) to detect and mark enemy artillery firing positions for 75 seconds - it requires your AAR to be alive. The CBR Radar upgrade extends detection radius: 750 m → 1,500 m → 2,000 m. Capturing an airfield grants a permanent 2,000 m CBR there."
]];


//===========================================================================
//  SUBJECT: Sides & AI Commander   (the three factions + AI + meta systems)
//  Written bottom-up so the in-game order leads with The Three Sides, then GUER,
//  then the AI Commander, then the meta systems.
//===========================================================================

player createDiaryRecord [_subFactions, ["Wildcards, Mods & Telemetry",
	"<br/><t size='1.2' color='#F5D363'>Wildcards</t><br/>" +
	"Random battlefield events fire through the round - veteran reinforcement companies, local uprisings, heliborne QRF drops and more - shifting momentum on either side. Stay flexible.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Clean Captures</t><br/>" +
	"Taking a town from GUER no longer hands you its static emplacements - you take the ground clean and bring or build your own defences. GUER keeps and rebuilds its statics when it recaptures.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Mods</t><br/>" +
	"We strongly suggest the mods listed on our Discord - they improve the experience enormously.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>Performance Telemetry</t><br/>" +
	"This build samples each client's FPS periodically and reports it to the server for a day/night performance study. Diagnostic only - it changes nothing in-game."
]];

player createDiaryRecord [_subFactions, ["GUER - the Guerrillas",
	"<br/>The <t color='#F5D363'>GUER resistance</t> is a living third faction, not just neutral garrisons - and it has <t color='#F5D363'>no base of its own</t>. It is a base-less harasser that fields mechanized patrols across the map.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>It bites harder the more it loses</t><br/>" +
	"While GUER holds plenty of towns it raids with light technicals. Squeeze it below <t color='#F5D363'>20 towns</t> and it escalates to BRDM-2 armour with AT/AA support and a second patrol. A cornered insurgency is the most dangerous - do not assume a shrinking GUER is a beaten one.<br/><br/>" +
	"For WEST and EAST, GUER is a spoiler: it holds the towns you both want and can punish a careless flank at any time."
]];

player createDiaryRecord [_subFactions, ["The AI Commander",
	"<br/>Any side can be run by an <t color='#F5D363'>AI Commander</t> that manages the economy, builds the base, researches upgrades and leads its combat teams in assaults on towns.<br/><br/>" +
	"If no human takes the Commander slot within <t color='#F5D363'>5 minutes</t> of round start (the timer re-arms whenever a player commander leaves), the AI takes over construction.<br/><br/>" +
	"You can <t color='#F5D363'>claim Commander</t> at any time. Even then the AI keeps its own HQ combat teams fighting and never leaves them standing idle, while you run the economy and give orders. Any team you order directly stays under your command."
]];

player createDiaryRecord [_subFactions, ["The Three Sides",
	"<br/>Three factions share the map.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>WEST (BLUFOR)</t><br/>" +
	"A full army with a base, factories, economy and a commander. Captures towns, builds up, and wins by destroying the enemy HQ.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>EAST (OPFOR)</t><br/>" +
	"The mirror of WEST - a full army with its own base and commander. WEST and EAST are the two contenders for the map.<br/><br/>" +
	"<t size='1.2' color='#F5D363'>GUER (Guerrillas)</t><br/>" +
	"A <t color='#F5D363'>base-less harasser</t>, not a contender for victory. GUER holds town garrisons and roams in patrols, and it grows more dangerous as it is pushed back. See the next page."
]];
