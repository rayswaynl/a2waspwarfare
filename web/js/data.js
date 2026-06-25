/* =============================================================================
 * WASP WARFARE — WEB EDITION
 * data.js — factions, unit rosters, structures, map.
 *
 * Numbers are inspired by the Arma 2 "Warfare Benny Edition" (WFBE / WASP)
 * mission found in the source repo, then compressed onto a web-friendly scale
 * so a full match plays out in ~10–15 minutes instead of an hour.
 *   - Dual economy: FUNDS (buy units) + SUPPLY (logistics cap / structures)
 *   - Town Supply Value (SV) drives income, exactly like the original.
 *   - Factory tiers: Barracks / Light / Heavy / Aircraft, gated by structures.
 * ========================================================================== */

const DATA = (() => {
  "use strict";

  /* ---- Factions ---------------------------------------------------------- */
  // West = USMC, East = RU — the two stock Chernarus sides of the mission.
  const FACTIONS = {
    USMC: {
      id: "USMC",
      name: "USMC",
      long: "US Marine Corps",
      side: "WEST",
      color: "#4ea3ff",
      colorDim: "#1c3c5c",
      accent: "#9ad0ff",
      flag: "★",
    },
    RU: {
      id: "RU",
      name: "RU",
      long: "Russian Federation",
      side: "EAST",
      color: "#ff5a4d",
      colorDim: "#5c1f1c",
      accent: "#ffb0a8",
      flag: "☭",
    },
  };

  /* ---- Unit categories (map to factories) -------------------------------- */
  const CATEGORIES = [
    { id: "inf",   tab: "BARRACKS",  hot: "Q", structure: "barracks" },
    { id: "light", tab: "LIGHT",     hot: "W", structure: "light" },
    { id: "heavy", tab: "HEAVY",     hot: "E", structure: "heavy" },
    { id: "air",   tab: "AIRCRAFT",  hot: "R", structure: "air" },
  ];

  /* ---- Unit roster -------------------------------------------------------
   * cost   : funds
   * sup    : supply (logistics) the unit occupies while alive
   * build  : seconds to produce
   * hp     : hit points
   * dmg    : damage per shot
   * rof    : shots per second
   * range  : engagement range (world px)
   * speed  : world px / second
   * sight  : vision radius (world px)
   * armor  : flat damage reduction
   * vs     : multiplier vs {inf, veh, air}
   * air    : true if it flies (only hit by AA-capable / air units realistically;
   *          here air can be hit by anything but takes reduced dmg from inf)
   * ------------------------------------------------------------------------ */
  function mk(o) {
    return Object.assign(
      { sup: 1, build: 4, armor: 0, sight: 230, air: false,
        vs: { inf: 1, veh: 1, air: 1 }, glyph: "•" }, o);
  }

  // Shared archetypes, themed per faction. Keeps both sides balanced/symmetric
  // while preserving the original's unit names.
  const ROSTER = {
    USMC: [
      // --- Barracks ---
      mk({ id:"usmc_rifle",  cat:"inf", name:"Rifleman",          cost:60,  sup:1, build:3,  hp:46,  dmg:7,  rof:2.2, range:165, speed:34, glyph:"r", vs:{inf:1.2,veh:0.25,air:0.15} }),
      mk({ id:"usmc_ar",     cat:"inf", name:"Automatic Rifleman",cost:110, sup:1, build:4,  hp:50,  dmg:6,  rof:4.0, range:175, speed:32, glyph:"a", vs:{inf:1.35,veh:0.3,air:0.2} }),
      mk({ id:"usmc_lat",    cat:"inf", name:"LAT Specialist",    cost:150, sup:1, build:4,  hp:48,  dmg:34, rof:0.5, range:195, speed:32, glyph:"l", vs:{inf:0.7,veh:1.7,air:0.3} }),
      mk({ id:"usmc_hat",    cat:"inf", name:"HAT Specialist",    cost:330, sup:2, build:6,  hp:50,  dmg:62, rof:0.32,range:230, speed:30, glyph:"h", vs:{inf:0.6,veh:2.4,air:0.4} }),
      mk({ id:"usmc_aa",     cat:"inf", name:"AA Specialist",     cost:240, sup:2, build:6,  hp:48,  dmg:55, rof:0.35,range:300, speed:30, glyph:"s", vs:{inf:0.4,veh:0.6,air:3.2} }),
      mk({ id:"usmc_medic",  cat:"inf", name:"Corpsman",          cost:130, sup:1, build:4,  hp:52,  dmg:5,  rof:2.0, range:150, speed:34, glyph:"+", heal:5, vs:{inf:0.8,veh:0.2,air:0.1} }),
      mk({ id:"usmc_engi",   cat:"inf", name:"Combat Engineer",   cost:170, sup:1, build:5,  hp:54,  dmg:5,  rof:2.0, range:150, speed:32, glyph:"e", repair:9, vs:{inf:0.7,veh:0.2,air:0.1} }),
      mk({ id:"usmc_sniper", cat:"inf", name:"Scout Sniper",      cost:220, sup:1, build:6,  hp:42,  dmg:60, rof:0.5, range:300, sight:360, speed:30, glyph:"x", scout:true, vs:{inf:2.4,veh:0.3,air:0.15} }),
      // --- Light Factory ---
      mk({ id:"usmc_hmmwv",  cat:"light", name:"HMMWV M2",        cost:300, sup:2, build:8,  hp:160, dmg:9,  rof:5.0, range:210, speed:62, armor:3, glyph:"j", vs:{inf:1.3,veh:0.6,air:0.4} }),
      mk({ id:"usmc_lav",    cat:"light", name:"LAV-25",          cost:760, sup:3, build:12, hp:300, dmg:24, rof:2.6, range:240, speed:52, armor:7, glyph:"v", vs:{inf:1.2,veh:1.3,air:0.5} }),
      mk({ id:"usmc_tow",    cat:"light", name:"HMMWV TOW",       cost:620, sup:3, build:11, hp:150, dmg:80, rof:0.4, range:300, speed:58, armor:3, glyph:"t", vs:{inf:0.5,veh:2.6,air:0.3} }),
      mk({ id:"usmc_avenger",cat:"light", name:"HMMWV Avenger",   cost:880, sup:3, build:13, hp:160, dmg:60, rof:0.7, range:340, speed:58, armor:3, glyph:"y", vs:{inf:0.4,veh:0.6,air:3.4} }),
      mk({ id:"usmc_supply", cat:"light", name:"Supply Truck",    cost:380, sup:2, build:10, hp:200, dmg:0,  rof:0,   range:0,   speed:46, armor:2, glyph:"u", supplyTruck:18, vs:{inf:0,veh:0,air:0} }),
      // --- Heavy Factory ---
      mk({ id:"usmc_aav",    cat:"heavy", name:"AAV-7",           cost:1200,sup:4, build:16, hp:520, dmg:20, rof:3.0, range:240, speed:44, armor:10, glyph:"p", vs:{inf:1.3,veh:0.9,air:0.4} }),
      mk({ id:"usmc_abrams", cat:"heavy", name:"M1A1 Abrams",     cost:2400,sup:6, build:24, hp:1000,dmg:150,rof:0.55,range:300, speed:40, armor:22, glyph:"A", vs:{inf:1.4,veh:2.4,air:0.5} }),
      mk({ id:"usmc_tusk",   cat:"heavy", name:"M1A2 TUSK",       cost:3000,sup:7, build:28, hp:1180,dmg:160,rof:0.6, range:310, speed:40, armor:26, glyph:"T", vs:{inf:1.6,veh:2.6,air:0.6} }),
      mk({ id:"usmc_mlrs",   cat:"heavy", name:"MLRS",            cost:3200,sup:6, build:30, hp:360, dmg:120,rof:0.18,range:560, sight:240, speed:36, armor:6, arty:true, glyph:"M", vs:{inf:2.6,veh:1.6,air:0} }),
      // --- Aircraft Factory ---
      mk({ id:"usmc_huey",   cat:"air", name:"UH-1Y Venom",       cost:1600,sup:4, build:20, hp:360, dmg:14, rof:4.0, range:250, speed:96, armor:4, air:true, glyph:"H", vs:{inf:1.5,veh:0.8,air:0.7} }),
      mk({ id:"usmc_cobra",  cat:"air", name:"AH-1Z Viper",       cost:3400,sup:6, build:30, hp:520, dmg:46, rof:2.2, range:320, speed:104,armor:7, air:true, glyph:"C", vs:{inf:1.6,veh:2.2,air:1.1} }),
      mk({ id:"usmc_apache", cat:"air", name:"AH-64 Apache",      cost:4200,sup:7, build:34, hp:620, dmg:56, rof:2.4, range:340, speed:108,armor:8, air:true, glyph:"K", vs:{inf:1.7,veh:2.4,air:1.2} }),
      mk({ id:"usmc_harrier",cat:"air", name:"AV-8B Harrier",     cost:5200,sup:8, build:40, hp:520, dmg:110,rof:0.7, range:300, speed:150,armor:6, air:true, glyph:"J", vs:{inf:2.0,veh:2.6,air:1.0} }),
    ],
    RU: [
      mk({ id:"ru_rifle",   cat:"inf", name:"Rifleman",           cost:60,  sup:1, build:3,  hp:46,  dmg:7,  rof:2.2, range:165, speed:34, glyph:"r", vs:{inf:1.2,veh:0.25,air:0.15} }),
      mk({ id:"ru_ar",      cat:"inf", name:"Machinegunner",      cost:110, sup:1, build:4,  hp:50,  dmg:6,  rof:4.0, range:175, speed:32, glyph:"a", vs:{inf:1.35,veh:0.3,air:0.2} }),
      mk({ id:"ru_lat",     cat:"inf", name:"RPG Soldier",        cost:150, sup:1, build:4,  hp:48,  dmg:34, rof:0.5, range:195, speed:32, glyph:"l", vs:{inf:0.7,veh:1.7,air:0.3} }),
      mk({ id:"ru_hat",     cat:"inf", name:"HAT Specialist",     cost:330, sup:2, build:6,  hp:50,  dmg:62, rof:0.32,range:230, speed:30, glyph:"h", vs:{inf:0.6,veh:2.4,air:0.4} }),
      mk({ id:"ru_aa",      cat:"inf", name:"Igla Gunner",        cost:240, sup:2, build:6,  hp:48,  dmg:55, rof:0.35,range:300, speed:30, glyph:"s", vs:{inf:0.4,veh:0.6,air:3.2} }),
      mk({ id:"ru_medic",   cat:"inf", name:"Medic",              cost:130, sup:1, build:4,  hp:52,  dmg:5,  rof:2.0, range:150, speed:34, glyph:"+", heal:5, vs:{inf:0.8,veh:0.2,air:0.1} }),
      mk({ id:"ru_engi",    cat:"inf", name:"Combat Engineer",    cost:170, sup:1, build:5,  hp:54,  dmg:5,  rof:2.0, range:150, speed:32, glyph:"e", repair:9, vs:{inf:0.7,veh:0.2,air:0.1} }),
      mk({ id:"ru_sniper",  cat:"inf", name:"Sniper",             cost:220, sup:1, build:6,  hp:42,  dmg:60, rof:0.5, range:300, sight:360, speed:30, glyph:"x", scout:true, vs:{inf:2.4,veh:0.3,air:0.15} }),

      mk({ id:"ru_uaz",     cat:"light", name:"UAZ DShKM",        cost:300, sup:2, build:8,  hp:150, dmg:9,  rof:5.0, range:210, speed:64, armor:2, glyph:"j", vs:{inf:1.3,veh:0.6,air:0.4} }),
      mk({ id:"ru_btr",     cat:"light", name:"BTR-90",           cost:780, sup:3, build:12, hp:320, dmg:26, rof:2.6, range:240, speed:54, armor:8, glyph:"v", vs:{inf:1.2,veh:1.4,air:0.5} }),
      mk({ id:"ru_vodnik",  cat:"light", name:"GAZ Vodnik AT",    cost:620, sup:3, build:11, hp:170, dmg:80, rof:0.4, range:300, speed:58, armor:4, glyph:"t", vs:{inf:0.5,veh:2.6,air:0.3} }),
      mk({ id:"ru_tunguska",cat:"light", name:"2S6 Tunguska",     cost:900, sup:3, build:13, hp:240, dmg:62, rof:0.8, range:350, speed:48, armor:6, glyph:"y", vs:{inf:0.5,veh:0.9,air:3.4} }),
      mk({ id:"ru_supply",  cat:"light", name:"Supply Truck",     cost:380, sup:2, build:10, hp:200, dmg:0,  rof:0,   range:0,   speed:46, armor:2, glyph:"u", supplyTruck:18, vs:{inf:0,veh:0,air:0} }),

      mk({ id:"ru_bmp",     cat:"heavy", name:"BMP-3",            cost:1300,sup:4, build:16, hp:560, dmg:30, rof:2.4, range:250, speed:46, armor:11, glyph:"p", vs:{inf:1.4,veh:1.3,air:0.4} }),
      mk({ id:"ru_t72",     cat:"heavy", name:"T-72",             cost:2300,sup:6, build:24, hp:960, dmg:148,rof:0.5, range:300, speed:40, armor:21, glyph:"A", vs:{inf:1.4,veh:2.3,air:0.5} }),
      mk({ id:"ru_t90",     cat:"heavy", name:"T-90",             cost:3000,sup:7, build:28, hp:1180,dmg:160,rof:0.6, range:310, speed:42, armor:26, glyph:"T", vs:{inf:1.6,veh:2.6,air:0.6} }),
      mk({ id:"ru_grad",    cat:"heavy", name:"BM-21 Grad",       cost:3200,sup:6, build:30, hp:340, dmg:120,rof:0.18,range:560, sight:240, speed:38, armor:5, arty:true, glyph:"M", vs:{inf:2.6,veh:1.6,air:0} }),

      mk({ id:"ru_mi8",     cat:"air", name:"Mi-8 Hip",           cost:1600,sup:4, build:20, hp:380, dmg:14, rof:4.0, range:250, speed:96, armor:4, air:true, glyph:"H", vs:{inf:1.5,veh:0.8,air:0.7} }),
      mk({ id:"ru_hind",    cat:"air", name:"Mi-24 Hind",         cost:3400,sup:6, build:30, hp:560, dmg:46, rof:2.2, range:320, speed:100,armor:8, air:true, glyph:"C", vs:{inf:1.6,veh:2.2,air:1.1} }),
      mk({ id:"ru_ka52",    cat:"air", name:"Ka-52 Alligator",    cost:4200,sup:7, build:34, hp:640, dmg:58, rof:2.4, range:340, speed:108,armor:9, air:true, glyph:"K", vs:{inf:1.7,veh:2.4,air:1.2} }),
      mk({ id:"ru_su25",    cat:"air", name:"Su-25 Frogfoot",     cost:5200,sup:8, build:40, hp:540, dmg:110,rof:0.7, range:300, speed:150,armor:6, air:true, glyph:"J", vs:{inf:2.0,veh:2.6,air:1.0} }),
    ],
  };

  // Index by id for fast lookup.
  const UNIT_BY_ID = {};
  for (const f of Object.keys(ROSTER)) for (const u of ROSTER[f]) UNIT_BY_ID[u.id] = u;

  /* ---- Structures (built with SUPPLY at your HQ) ------------------------- */
  const STRUCTURES = [
    { id:"barracks", name:"Barracks",        cost:180,  build:8,  unlocks:"inf",   glyph:"B",
      desc:"Recruit infantry." },
    { id:"light",    name:"Light Factory",   cost:420,  build:12, unlocks:"light", glyph:"L",
      desc:"Build light vehicles & supply trucks." },
    { id:"heavy",    name:"Heavy Factory",   cost:900,  build:16, unlocks:"heavy", glyph:"V",
      desc:"Build tanks, IFVs and artillery." },
    { id:"air",      name:"Aircraft Factory",cost:1400, build:20, unlocks:"air",   glyph:"A",
      desc:"Build helicopters and jets." },
    { id:"depot",    name:"Supply Depot",    cost:300,  build:10, unlocks:null,    glyph:"D",
      supplyCap:6, desc:"+6 supply cap. Raises your logistics ceiling." },
  ];
  const STRUCT_BY_ID = {};
  for (const s of STRUCTURES) STRUCT_BY_ID[s.id] = s;

  /* ---- Map / theatre -----------------------------------------------------
   * World is 2600 x 1700 px. Two HQs at opposite corners, a chain of towns
   * between them. Town names lifted from Chernarus (the mission's map).
   * sv = supply value tier; bigger towns pay more but defend harder.
   * ------------------------------------------------------------------------ */
  const WORLD = { w: 2600, h: 1700 };

  // CHERNARUS — green, forested. Default theatre.
  const MAP_CHERNARUS = {
    id: "chernarus", name: "Chernarus", biome: "green",
    world: WORLD,
    tint: { top: "#1a2415", bot: "#141d11", grid: "rgba(120,150,90,0.05)", forest: "rgba(30,60,28," },
    hq: { USMC: { x: 240, y: 1460 }, RU: { x: 2360, y: 240 } },
    towns: [
      { id:"t_chern",  name:"Chernogorsk",   x: 560,  y: 1180, sv: 26, garrison: 5 },
      { id:"t_elektro",name:"Elektrozavodsk",x: 900,  y: 1380, sv: 22, garrison: 4 },
      { id:"t_balota", name:"Balota",        x: 380,  y: 980,  sv: 14, garrison: 3 },
      { id:"t_zelen",  name:"Zelenogorsk",   x: 760,  y: 760,  sv: 18, garrison: 4 },
      { id:"t_sobor",  name:"Stary Sobor",   x: 1300, y: 860,  sv: 30, garrison: 6 },
      { id:"t_vybor",  name:"Vybor",         x: 1080, y: 520,  sv: 20, garrison: 4 },
      { id:"t_msta",   name:"Msta",          x: 1620, y: 1180, sv: 16, garrison: 3 },
      { id:"t_bere",   name:"Berezino",      x: 2040, y: 1320, sv: 24, garrison: 5 },
      { id:"t_krasno", name:"Krasnostav",    x: 1900, y: 720,  sv: 20, garrison: 4 },
      { id:"t_grishino",name:"Grishino",     x: 1480, y: 420,  sv: 18, garrison: 4 },
    ],
    roads: [
      ["hqW","t_chern"],["t_chern","t_elektro"],["t_chern","t_balota"],
      ["t_balota","t_zelen"],["t_zelen","t_sobor"],["t_zelen","t_vybor"],
      ["t_elektro","t_msta"],["t_sobor","t_msta"],["t_sobor","t_vybor"],
      ["t_vybor","t_grishino"],["t_sobor","t_krasno"],["t_msta","t_bere"],
      ["t_krasno","t_grishino"],["t_krasno","hqE"],["t_bere","hqE"],
      ["t_grishino","hqE"],
    ],
    // Forests: tactical cover + concealment for infantry.
    forests: [
      { x: 700, y: 980, r: 150 }, { x: 980, y: 700, r: 130 }, { x: 1300, y: 1080, r: 170 },
      { x: 1150, y: 660, r: 120 }, { x: 1700, y: 920, r: 150 }, { x: 1500, y: 1240, r: 140 },
      { x: 1780, y: 560, r: 120 }, { x: 520, y: 760, r: 110 }, { x: 2000, y: 1080, r: 140 },
    ],
    // Capturable strategic points: radar (reveal), oil (income), repair (heal).
    points: [
      { id:"p_radar",  name:"Radar Station", type:"radar",  x: 1300, y: 1180 },
      { id:"p_oil",    name:"Oil Refinery",  type:"oil",    x: 1080, y: 1000 },
      { id:"p_repair", name:"Repair Depot",  type:"repair", x: 1560, y: 700 },
    ],
  };

  // TAKISTAN — arid desert, sparse cover, more open fighting.
  const MAP_TAKISTAN = {
    id: "takistan", name: "Takistan", biome: "desert",
    world: WORLD,
    tint: { top: "#2b2412", bot: "#221c0e", grid: "rgba(180,150,80,0.05)", forest: "rgba(90,80,40," },
    hq: { USMC: { x: 240, y: 240 }, RU: { x: 2360, y: 1460 } },
    towns: [
      { id:"t_rasman",  name:"Rasman",      x: 560,  y: 520,  sv: 24, garrison: 5 },
      { id:"t_loy",     name:"Loy Manara",  x: 980,  y: 360,  sv: 20, garrison: 4 },
      { id:"t_nagara",  name:"Nagara",      x: 720,  y: 880,  sv: 16, garrison: 3 },
      { id:"t_zargabad",name:"Zargabad",    x: 1300, y: 820,  sv: 32, garrison: 6 },
      { id:"t_feruz",   name:"Feruz Abad",  x: 1120, y: 1240, sv: 18, garrison: 4 },
      { id:"t_chak",    name:"Chak Chak",   x: 1640, y: 460,  sv: 18, garrison: 4 },
      { id:"t_garmsar", name:"Garmsar",     x: 1700, y: 1120, sv: 22, garrison: 5 },
      { id:"t_sakhe",   name:"Sakhe",       x: 1980, y: 760,  sv: 20, garrison: 4 },
      { id:"t_falar",   name:"Falar",       x: 1460, y: 1320, sv: 16, garrison: 3 },
      { id:"t_shukurkalay",name:"Shukurkalay",x: 2020,y: 1280,sv: 24, garrison: 5 },
    ],
    roads: [
      ["hqW","t_rasman"],["t_rasman","t_loy"],["t_rasman","t_nagara"],
      ["t_loy","t_zargabad"],["t_nagara","t_zargabad"],["t_nagara","t_feruz"],
      ["t_loy","t_chak"],["t_zargabad","t_chak"],["t_zargabad","t_garmsar"],
      ["t_feruz","t_falar"],["t_chak","t_sakhe"],["t_garmsar","t_sakhe"],
      ["t_garmsar","t_falar"],["t_falar","t_shukurkalay"],["t_sakhe","hqE"],
      ["t_shukurkalay","hqE"],["t_garmsar","hqE"],
    ],
    forests: [
      { x: 900, y: 760, r: 90 }, { x: 1400, y: 600, r: 80 }, { x: 1600, y: 980, r: 90 },
      { x: 1180, y: 1040, r: 80 },
    ],
    points: [
      { id:"p_radar",  name:"Radar Station", type:"radar",  x: 1300, y: 620 },
      { id:"p_oil",    name:"Oil Refinery",  type:"oil",    x: 1480, y: 980 },
      { id:"p_repair", name:"Repair Depot",  type:"repair", x: 1000, y: 920 },
    ],
  };

  const MAPS = { chernarus: MAP_CHERNARUS, takistan: MAP_TAKISTAN };
  const MAP = MAP_CHERNARUS; // default / back-compat

  /* ---- Forward Outpost (deployed from a supply truck) -------------------- */
  const OUTPOST_DEF = {
    id: "outpost", name: "Forward Outpost", cat: "def", emplacement: false, outpost: true,
    speed: 0, sup: 0, build: 8, hp: 700, dmg: 7, rof: 3.0, range: 200, armor: 8, sight: 340,
    air: false, vs: { inf: 1.2, veh: 0.4, air: 0.3 }, glyph: "O",
    desc: "Forward base: vision, heal aura, +5 supply.",
  };

  /* ---- Commander upgrades (escalating funds cost per level) -------------- */
  const UPGRADES = [
    { id:"economy",    name:"War Economy",   glyph:"$", levels:3, baseCost:400, costMult:1.7, desc:"+22% town income per level." },
    { id:"weapons",    name:"Weapons",       glyph:"⚔", levels:3, baseCost:450, costMult:1.7, desc:"+14% unit damage per level." },
    { id:"armor",      name:"Armor",         glyph:"▣", levels:3, baseCost:450, costMult:1.7, desc:"+14% HP on new units per level." },
    { id:"logistics",  name:"Logistics",     glyph:"▤", levels:3, baseCost:350, costMult:1.6, desc:"+6 supply cap per level." },
    { id:"production",  name:"Production",   glyph:"⚙", levels:2, baseCost:500, costMult:1.8, desc:"-16% build time per level." },
  ];
  const UPGRADE_BY_ID = {};
  for (const u of UPGRADES) UPGRADE_BY_ID[u.id] = u;

  /* ---- Commander support powers (cooldown + funds cost) ------------------ */
  const POWERS = [
    { id:"artillery", name:"Artillery Barrage", glyph:"❂", cost:250, cd:50,
      desc:"Saturate an area with 8 shells. Spares friendlies." },
    { id:"airstrike", name:"Airstrike", glyph:"✈", cost:400, cd:70,
      desc:"A jet strafes a line through the target." },
    { id:"paradrop", name:"Paradrop", glyph:"☂", cost:300, cd:80,
      desc:"Drop a 5-man squad anywhere on the map." },
    { id:"smoke", name:"Smoke Screen", glyph:"☁", cost:120, cd:35,
      desc:"Lay concealing smoke — blocks vision and cuts incoming fire." },
  ];
  const POWER_BY_ID = {};
  for (const p of POWERS) POWER_BY_ID[p.id] = p;

  /* ---- Weather presets (vision / accuracy modifiers + look) -------------- */
  const WEATHER = {
    clear:     { id:"clear",     name:"Clear",     vision:1.0,  accuracy:1.0,  desc:"Good visibility." },
    overcast:  { id:"overcast",  name:"Overcast",  vision:0.9,  accuracy:1.0,  desc:"Grey skies." },
    rain:      { id:"rain",      name:"Rain",      vision:0.72, accuracy:0.9,  desc:"Reduced sight, slicker aim." },
    sandstorm: { id:"sandstorm", name:"Sandstorm", vision:0.55, accuracy:0.82, desc:"Choking dust — short sight." },
  };

  /* ---- Defensive emplacements (placed near owned territory) -------------- */
  function mkDef(o) {
    return Object.assign(
      { cat:"def", emplacement:true, speed:0, sup:2, build:8, armor:6, sight:300,
        air:false, vs:{ inf:1, veh:1, air:1 }, glyph:"#" }, o);
  }
  const DEFENSES = [
    mkDef({ id:"d_mg",  name:"MG Nest",    cost:200, hp:280, dmg:8,  rof:5.0, range:220, build:6,
            glyph:"#", vs:{inf:1.6,veh:0.4,air:0.3}, desc:"Cheap. Shreds infantry." }),
    mkDef({ id:"d_at",  name:"AT Gun",     cost:420, hp:340, dmg:90, rof:0.5, range:300, build:9,
            glyph:"=", vs:{inf:0.5,veh:2.6,air:0.3}, desc:"Stops armour cold." }),
    mkDef({ id:"d_aa",  name:"AA Battery", cost:480, hp:300, dmg:60, rof:0.8, range:360, build:9,
            glyph:"^", vs:{inf:0.4,veh:0.5,air:3.4}, desc:"Owns the sky overhead." }),
    mkDef({ id:"d_bunker", name:"Bunker",  cost:300, hp:900, dmg:6,  rof:3.0, range:180, build:10, armor:14,
            glyph:"B", vs:{inf:1.2,veh:0.3,air:0.2}, desc:"Tanky strongpoint." }),
  ];
  const DEFENSE_BY_ID = {};
  for (const d of DEFENSES) DEFENSE_BY_ID[d.id] = d;

  /* ---- Difficulty presets ------------------------------------------------ */
  const DIFFICULTY = {
    recruit:  { id:"recruit",  name:"Recruit",   aiFunds:0.75, aiAggro:0.7, startFunds:900, startSup:14, desc:"Forgiving. The AI builds slowly." },
    veteran:  { id:"veteran",  name:"Veteran",   aiFunds:1.0,  aiAggro:1.0, startFunds:800, startSup:12, desc:"A fair fight. Recommended." },
    elite:    { id:"elite",    name:"Elite",     aiFunds:1.35, aiAggro:1.3, startFunds:760, startSup:12, desc:"The AI pushes hard and early." },
  };

  /* ---- Economy / rules tuning ------------------------------------------- */
  const RULES = {
    incomeInterval: 4,      // seconds between paychecks
    incomePerSV: 0.5,       // funds per SV per second  -> SV*interval*this each tick
    captureRange: 95,       // world px: be this close to a town to contest it
    captureRate: 12,        // capture progress / sec at parity (100 = owned)
    baseSupplyCap: 16,      // starting supply ceiling (before depots)
    hqHp: 2200,
    hqRepair: 6,            // hp/sec HQ self-repairs when not under fire
    startStructures: ["barracks"], // both sides begin with a barracks
    captureFundsBonus: 6,   // one-off funds = sv * this on capture
    dominationHold: 75,     // seconds you must hold the town majority to win
    pointCaptureRange: 80,  // capture radius for strategic points
    pointCaptureRate: 18,   // points capture faster than towns (no garrison)
    oilIncome: 9,           // flat funds/sec while you hold an oil refinery
    radarRadius: 520,       // fog reveal radius around a held radar
    pointRepairRate: 10,    // hp/sec heal aura at a repair depot
  };

  /* ---- Strategic point types (capturable, non-town objectives) ----------- */
  const POINT_TYPES = {
    radar:  { id:"radar",  name:"Radar Station", glyph:"⌖", color:"#7ad0ff", desc:"Reveals the fog around it." },
    oil:    { id:"oil",    name:"Oil Refinery",  glyph:"⬣", color:"#f2c14a", desc:"+9 funds/sec while held." },
    repair: { id:"repair", name:"Repair Depot",  glyph:"✚", color:"#7ef07e", desc:"Heals nearby friendly units." },
  };

  /* ---- Victory conditions ------------------------------------------------ */
  const WIN_CONDITIONS = {
    conquest:   { id:"conquest",   name:"Conquest",   desc:"Destroy the enemy HQ, or hold every town." },
    domination: { id:"domination", name:"Domination", desc:"Hold a majority of towns for 75s straight — or take the HQ." },
  };

  return {
    FACTIONS, CATEGORIES, ROSTER, UNIT_BY_ID,
    STRUCTURES, STRUCT_BY_ID, MAP, WORLD, MAPS,
    POWERS, POWER_BY_ID, DEFENSES, DEFENSE_BY_ID,
    OUTPOST_DEF, UPGRADES, UPGRADE_BY_ID, WIN_CONDITIONS,
    WEATHER, POINT_TYPES,
    DIFFICULTY, RULES,
  };
})();
