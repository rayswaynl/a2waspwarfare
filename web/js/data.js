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
    { id: "inf",   tab: "BARRACKS",  hot: "1", structure: "barracks" },
    { id: "light", tab: "LIGHT",     hot: "2", structure: "light" },
    { id: "heavy", tab: "HEAVY",     hot: "3", structure: "heavy" },
    { id: "air",   tab: "AIRCRAFT",  hot: "4", structure: "air" },
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
      mk({ id:"usmc_sniper", cat:"inf", name:"Scout Sniper",      cost:220, sup:1, build:6,  hp:42,  dmg:60, rof:0.5, range:300, sight:340, speed:30, glyph:"x", vs:{inf:2.4,veh:0.3,air:0.15} }),
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
      mk({ id:"ru_sniper",  cat:"inf", name:"Sniper",             cost:220, sup:1, build:6,  hp:42,  dmg:60, rof:0.5, range:300, sight:340, speed:30, glyph:"x", vs:{inf:2.4,veh:0.3,air:0.15} }),

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

  const MAP = {
    world: WORLD,
    hq: {
      USMC: { x: 240,  y: 1460 },
      RU:   { x: 2360, y: 240  },
    },
    // Towns: id, name, x, y, sv (supply value -> income), garrison size.
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
    // Decorative roads connecting key nodes (purely visual on the map).
    roads: [
      ["hqW","t_chern"],["t_chern","t_elektro"],["t_chern","t_balota"],
      ["t_balota","t_zelen"],["t_zelen","t_sobor"],["t_zelen","t_vybor"],
      ["t_elektro","t_msta"],["t_sobor","t_msta"],["t_sobor","t_vybor"],
      ["t_vybor","t_grishino"],["t_sobor","t_krasno"],["t_msta","t_bere"],
      ["t_krasno","t_grishino"],["t_krasno","hqE"],["t_bere","hqE"],
      ["t_grishino","hqE"],
    ],
  };

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
  };

  return {
    FACTIONS, CATEGORIES, ROSTER, UNIT_BY_ID,
    STRUCTURES, STRUCT_BY_ID, MAP, WORLD,
    DIFFICULTY, RULES,
  };
})();
