# Commander's Handbook

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

**Audience:** player-facing. This page surfaces the content of `Guides/CommanderGuide/commanderGuide.md` (repo root) with costs and limits cross-verified against source. The upstream guide document was originally LLM-drafted and carries several WIP markers; sections with confirmed source values are noted here with citations. Sections that remain unverified in the guide text are marked **[guide-draft]**.

---

## Glossary

| Abbreviation | Meaning |
|---|---|
| B | Barracks |
| LF | Light Factory |
| HF | Heavy Factory |
| AF | Aircraft Factory |
| CC | Command Center |
| AAR | Anti Air Radar |
| SP | Service Point |
| MHQ | Mobile Headquarters |
| SV | Supply Value (town income output) |

Source: `Guides/CommanderGuide/commanderGuide.md:3-11`

---

## The Commander Role

- The commander controls team strategy, moves and deploys the MHQ, builds and sells bases, and manages upgrades.
- When no human player is elected commander, the AI Commander automatically takes control of the side — it builds bases, researches upgrades, fields teams, and executes tactical events. Electing a player commander overrides the AI. The vote menu shows "No Commander" as the option to leave the AI in charge. `Common/Init/Init_CommonConstants.sqf:103` (`WFBE_C_AI_COMMANDER_ENABLED = 1`); `Server/Init/Init_Server.sqf:846-847`.
- Commander income is based on a configurable percentage (`wfbe_commander_percent`, default **70%**) of total town income, split via the income system (default system 3 — Commander System). The remainder is divided among team players. The commander-percent slider is capped at `WFBE_C_ECONOMY_INCOME_PERCENT_MAX = 30` **from above** (the percent the commander claims is stored separately as a percentage of total; verify in-game).

Source: `Client/Init/Init_Client.sqf:365` (default 70); `Common/Init/Init_CommonConstants.sqf:160,167-168` (income system 3, divided factor 1.2, max slider 30)

---

## Mobile Headquarters (MHQ)

| Side | Vehicle class |
|---|---|
| BLUFOR (USMC/West) | `LAV25_HQ` (mobile) / `LAV25_HQ_unfolded` (deployed) |
| OPFOR (RU/East) | `BTR90_HQ` (mobile) / `BTR90_HQ_unfolded` (deployed) |

Source: `Common/Config/Core_Structures/Structures_USMC.sqf:6-7` (BLUFOR); `Common/Config/Core_Structures/Structures_RU.sqf:6-7` (OPFOR)

### Deploying the HQ

- Cost to deploy or mobilize: **`WFBE_C_STRUCTURES_HQ_COST_DEPLOY`** (default **100 supply**). `Common/Init/Init_CommonConstants.sqf:307`
- Cannot deploy within 200 m of an enemy or neutral (unowned) town: `WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED = 200`. `Common/Init/Init_CommonConstants.sqf:308`
- HQ build exclusion radius around the nearest existing base area: `WFBE_C_BASE_AREA_RANGE = 250 m` + `WFBE_C_BASE_HQ_BUILD_RANGE = 120 m`. `Common/Init/Init_CommonConstants.sqf:129-130`
- Do not deploy inside a building (server rules); walls can be placed around and a camo net placed on top.
- Rotate factories with **Ctrl** during CoIn placement (`coin_interface.sqf:438,786`).
- Auto-wall construction toggle: **User14** keybind in CoIn. `Client/Module/CoIn/coin_interface.sqf:180`

Source: `Guides/CommanderGuide/commanderGuide.md:72-86`

### HQ Repair

| Repair method | Cost | Notes |
|---|---|---|
| Supply repair (supply + repair truck) | **25,000 supply** (1st repair) | `WFBE_C_BASE_HQ_REPAIR_PRICE_1ST = 25000`. Escalates: 2nd = 40,000, 3rd = 50,000. |
| Cash repair at town depot | **200,000$** | One-time only per session (`cashrepaired` gate). All towns' SV reset to 10 afterward. |

Source: `Common/Init/Init_CommonConstants.sqf:133-142`; `WASP/actions/Action_RepairMHQDepot.sqf:6-28`

- A map marker for the lost HQ wreck is created automatically. **[guide-draft]** — marker creation path not traced here.
- Losing the HQ in the early game (before supply income is established) is typically fatal.

---

## Town Capture via MHQ

- Town activation radius: **600 m** (hardcoded in `Common/Init/Init_Town.sqf:10`). Drive to within 600 m to activate a town for capture.
- Towns provide extra AI defenses and natural cover for base structures, but offer no stealth — the enemy can discover a base while capturing nearby towns.

Source: `Common/Init/Init_Town.sqf:10,32`; `Guides/CommanderGuide/commanderGuide.md:127-132`

---

## Base and Structure Limits

All limits derive from `WFBE_C_STRUCTURES_MAX = 3` unless overridden per-type.

| Structure type | Max per side | Source |
|---|---|---|
| HQ (deployed base) | **1** (unique per side) | Each side has exactly one MHQ that deploys/mobilizes via `Construction_HQSite.sqf`. HQ is the first entry in the structures array and is explicitly excluded from the per-type build-limit system: `coin_interface.sqf:93-96` strips element 0 from both `_buildingsNames` and `_buildingsType` before the limit loop, so `_find` is always -1 for HQ and no `WFBE_C_STRUCTURES_MAX_*` lookup ever runs for it. `WFBE_C_STRUCTURES_MAX = 3` (`Init_CommonConstants.sqf:462`) does not apply to HQ. |
| Barracks (B) | 3 | `WFBE_C_STRUCTURES_MAX_BARRACKS = WFBE_C_STRUCTURES_MAX`. Line 447 |
| Light Factory (LF) | 3 | `WFBE_C_STRUCTURES_MAX_LIGHT = WFBE_C_STRUCTURES_MAX`. Line 448 |
| Command Center (CC) | 3 | `WFBE_C_STRUCTURES_MAX_COMMANDCENTER = WFBE_C_STRUCTURES_MAX`. Line 449 |
| Heavy Factory (HF) | 3 | `WFBE_C_STRUCTURES_MAX_HEAVY = WFBE_C_STRUCTURES_MAX`. Line 450 |
| Aircraft Factory (AF) | 3 | `WFBE_C_STRUCTURES_MAX_AIRCRAFT = WFBE_C_STRUCTURES_MAX`. Line 451 |
| Service Point (SP) | **6** | `WFBE_C_STRUCTURES_MAX_SERVICEPOINT = WFBE_C_STRUCTURES_MAX * 2`. Line 452 |
| Tents | 3 | `WFBE_C_STRUCTURES_MAX_TENTS = 3`. Line 453 |
| AARadar (AAR) | **1** | `WFBE_C_STRUCTURES_MAX_AARadar = 1`. `Common/Init/Init_CommonConstants.sqf:675` |

Source: `Common/Init/Init_CommonConstants.sqf:447-453`; `Server/Functions/Server_HandleBuildingRepair.sqf:39-40`

> **Note:** The source guide states "2 production factories" and "4 SP/AAR" limits. The code shows the production-factory limits all default to 3 (the global `WFBE_C_STRUCTURES_MAX`), and SP is 6 (3 × 2). The "2 factory" and "4 SP" figures from the guide text are LLM-draft guesses and do not match the verified source values above. Server operators can override any per-type limit by setting the relevant `WFBE_C_STRUCTURES_MAX_*` variable before the constants block runs.

---

## Structure Build Costs

Costs are in **supply** and verified against `Common/Config/Core_Structures/Structures_USMC.sqf` (BLUFOR) and `Structures_RU.sqf` (OPFOR). Both sides use identical supply costs.

| Structure | Supply cost | Build time (live) | Source line |
|---|---|---|---|
| HQ Deploy/Mobilize | 100 | 30 s | `Structures_USMC.sqf:27,28` (cost from `Init_CommonConstants.sqf:307`) |
| Barracks (B) | 200 | 60 s | `Structures_USMC.sqf:35,36` |
| Light Factory (LF) | 600 | 60 s | `Structures_USMC.sqf:44,45` |
| Command Center (CC) | 1,200 | 60 s | `Structures_USMC.sqf:53,54` |
| Heavy Factory (HF) | 2,800 | 60 s | `Structures_USMC.sqf:62,63` |
| Aircraft Factory (AF) | 4,400 | 60 s | `Structures_USMC.sqf:71,72` |
| Service Point (SP) | 700 | 60 s | `Structures_USMC.sqf:80,81` |
| Anti Air Radar (AAR) | 3,200 | 60 s | `Structures_USMC.sqf:90,91` (gated by `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0`) |

SP can also be purchased for **5,500$** (cash) from the Strategic buy menu. `Common/Config/Core/Core_US.sqf:284-285`

Build times halve to 1 second in `WF_Debug` mode (`Structures_USMC.sqf:27,36,45,54,63,72,81,91`).

Structure sale refund: **50%** of supply cost. `WFBE_C_STRUCTURES_SALE_PERCENT = 50`. `Common/Init/Init_CommonConstants.sqf:316`

---

## Command Center Coverage

- CC provides a 5,500 m radius purchase zone (the guide stated 4,800 m — that value is **incorrect**).
- Verified value: `WFBE_C_STRUCTURES_COMMANDCENTER_RANGE = 5500`. `Common/Init/Init_CommonConstants.sqf:312`
- Place a CC near a road if you want AI supply trucks to access it. `Guides/CommanderGuide/commanderGuide.md:143`

---

## Starting Supply

- Default supply at game start: **12,800 supply** per side (`WFBE_C_ECONOMY_SUPPLY_START_WEST/EAST = 12800`). `Common/Init/Init_CommonConstants.sqf:314-315`
- Server operators may configure a different value via mission parameters before this block runs.

Source: `Common/Init/Init_CommonConstants.sqf:314-315`

---

## Early Game Priority

Verified recommendation from `Guides/CommanderGuide/commanderGuide.md:141-156`:

1. Build CC first — it starts the upgrade clock immediately.
2. Choose one production factory: LF or HF (not both initially).
   - LF path: upgrade to **LF3** as fast as possible (unlocks LAV-25 / Pandur without launcher).
   - HF path: upgrade to **HF1** as fast as possible (unlocks BVP-1 / Bradley with gun).
3. Buy a vehicle with gunner only, fill queue with driver+gunner bots, start capturing towns.
4. Next priority: **Gear 2** + **Barracks 1** (if on LF path, supplies should be available post-LF3).

---

## Upgrade Reference (Both Sides, Verified)

Both BLUFOR (`Upgrades_USMC.sqf`) and OPFOR (`Upgrades_RU.sqf`) use **identical** costs, levels, and times. Source: comparison of both files confirms character-for-character parity on the COSTS/LEVELS/TIMES arrays.

### Upgrade Costs and Unlock Times

| Upgrade | `WFBE_UP_*` | Levels | Costs (supply per level) | Times (s per level) | Key Prereqs |
|---|---|---|---|---|---|
| Barracks | `WFBE_UP_BARRACKS = 0` | 3 | 540 / 1,350 / 2,070 | 30 / 60 / 90 | Gear 2, 3, 5 |
| Light Factory | `WFBE_UP_LIGHT = 1` | 4 | 250 / 950 / 1,900 / 3,500 | 40 / 60 / 80 / 100 | — |
| Heavy Factory | `WFBE_UP_HEAVY = 2` | 4 | 1,200 / 4,400 / 9,500 / 10,500 | 50 / 70 / 90 / 110 | — |
| Aircraft Factory | `WFBE_UP_AIR = 3` | 5 | 1,200 / 4,000 / 9,200 / 10,500 / 17,600 | 60 / 75 / 90 / 105 / 120 | — |
| Paratroopers | `WFBE_UP_PARATROOPERS = 4` | 3 | 1,500 / 2,500 / 3,500 | 35 / 55 / 75 | Barracks+Air+Gear (per level) |
| UAV | `WFBE_UP_UAV = 5` | 1 | 2,000 | 60 | Air 2 |
| Supply Rate | `WFBE_UP_SUPPLYRATE = 6` | 3 | 2,700 / 4,800 / 6,000 | 60 / 80 / 120 | — |
| Respawn Range | `WFBE_UP_RESPAWNRANGE = 7` | 2 | 500 / 1,500 | 30 / 60 | Light 1 (lvl 1 only) |
| Airlift | `WFBE_UP_AIRLIFT = 8` | 1 | 1,000 | 30 | Air 1 |
| Custom Flares | `WFBE_UP_FLARESCM = 9` | 1 | 4,500 | 100 | Air 2; module gate: `WFBE_C_MODULE_WFBE_FLARES` |
| Artillery Reload | `WFBE_UP_ARTYTIMEOUT = 10` | 6 | 800 / 1,400 / 2,200 / 3,700 / 6,100 / 10,000 | 40 / 70 / 100 / 130 / 160 / 190 | — |
| ICBM | `WFBE_UP_ICBM = 11` | 1 | 49,500 + 80,000 cash | 300 | Air 3; module gate: `WFBE_C_MODULE_WFBE_ICBM > 0` |
| Fast Travel | `WFBE_UP_FASTTRAVEL = 12` | 1 | 1,500 | 60 | Light 1 + Supply 1; module gate: `WFBE_C_GAMEPLAY_FAST_TRAVEL > 0` |
| Gear | `WFBE_UP_GEAR = 13` | 5 | 250 / 650 / 1,200 / 2,100 / 2,400 | 25 / 50 / 75 / 100 / 125 | — |
| Build Ammo | `WFBE_UP_AMMOCOIN = 14` | 1 | 750 | 40 | Gear 2 |
| EASA | `WFBE_UP_EASA = 15` | 1 | 4,000 | 90 | Air 1; module gate: `WFBE_C_MODULE_WFBE_EASA > 0` |
| Supply Paradrop | `WFBE_UP_SUPPLYPARADROP = 16` | 1 | 2,000 | 50 | Airlift 1 |
| Artillery Ammo | `WFBE_UP_ARTYAMMO = 17` | 1 | 2,500 | 60 | Gear 1 + Heavy 1 |
| IR Smoke | `WFBE_UP_IRSMOKE = 18` | 2 | 3,000 / 9,000 | 120 / 180 | Heavy 3 (lvl 1); module gate: `WFBE_C_MODULE_WFBE_IRSMOKE > 0` |
| Aircraft AA Missiles | `WFBE_UP_AIRAAM = 19` | 1 | 7,500 | 120 | Air 3 |
| Anti Air Radar | `WFBE_UP_AAR = 20` | 0** | 5,000 / 12,500 (supply) | n/a | **`COSTS[20]`=`[5000,12500]` but `LEVELS[20]=0`, so the AAR *research* upgrade is inactive in current config; the `300 / 1,000 / 2,000` values belong to `WFBE_UP_PATROLS = 22`. See [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas).** |

Source: `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:31-145`; `Common/Config/Core_Upgrades/Upgrades_RU.sqf:31-145`

> Module-gated upgrades (Flares, ICBM, Fast Travel, EASA, IR Smoke) only appear in the upgrade menu when the corresponding `WFBE_C_MODULE_*` mission parameter is set. `Upgrades_USMC.sqf:5-28`

### Upgrade Categories: What You Unlock

| Upgrade | What it adds (verified level-by-level in guide) |
|---|---|
| Gear 0 | Basic rifles, M136/RPG-18 |
| Gear 1 | Better rifles, GPS, rockets with V warhead; **[guide-draft]** NLAW status unverified |
| Gear 2 | M14/FN FAL, RPG with VL rockets, rangefinder |
| Gear 3 | Snipers with scopes, MAAWS, VR rockets |
| Gear 4 | Long-range snipers, laser designator (pairs with AF4) |
| Gear 5 | Thermal sights, Javelin (BLUFOR) / Metis (OPFOR) |
| Barracks | More infantry slots per factory; each level adds higher-tier infantry. Commander role flat bonus of +10 units. **[guide-draft]** |
| Light 0 | Cars, unarmed vehicles |
| Light 1 | Light armed vehicles |
| Light 2 | Ambulance, Repair Truck |
| Light 3 | LAV-25 (BLUFOR) / BTR-90 without launcher (OPFOR); Pandur without launcher |
| Light 4 | Pandur with launcher (BLUFOR); BTR-90 with launcher (OPFOR) |
| Heavy 0 | AV7 / M113 (not recommended) |
| Heavy 1 | Bradley without launcher (BLUFOR); BVP-1 (OPFOR, good AI) |
| Heavy 2 | Bradley with TOW (BLUFOR); BMP-2 with Konkurs (OPFOR) |
| Heavy 3 | M1 Abrams / T-72; Warrior (BLUFOR, good AI); BMP-3 (OPFOR) |
| Heavy 4 | M1A2 TUSK; T-90; M6 Linebacker / Tunguska AA |
| Air 1 | UH-60 / Mi-8 (transport); MV-22 (BLUFOR) **[guide-draft]** |
| Air 2 | Ambulance helicopters; AH-6J / UH-1H light attack |
| Air 3 | A-10A / Su-25A (limited guided without EASA) |
| Air 4 | A-10C / Su-25T with guided weapons |
| Air 5 | F-35 / Su-34 (best jets); AH-1Z / Ka-52 (best attack helicopters) |

Source: `Guides/CommanderGuide/commanderGuide.md:200-395` (guide-draft text); costs verified in `Upgrades_USMC.sqf`

---

## CoIn Hotkeys (Construction Interface)

| Action | Binding |
|---|---|
| Rotate object | **Ctrl** (key 29 / 157) |
| Toggle auto-wall construction | **User14** |
| Re-place last built defense | **User15** |
| Toggle auto-manning defense | **User16** |
| Sell targeted defense (commander only) | **User17** |
| Confirm placement | Default Action (LMB) |
| Exit CoIn | Menu Back (Escape or equivalent) |

Source: `Client/Module/CoIn/coin_interface.sqf:180,221,232,240,438,786`

---

## Economy and Sharing

- Income system default: **System 3** (Commander System) — commander takes `wfbe_commander_percent` % (default 70%) of total town income, divided by 1.2 to prevent runaway income, plus their player share; remaining players split the non-commander portion equally. `Common/Init/Init_CommonConstants.sqf:160,167`
- Commander can adjust the slider in the Economy menu up to `WFBE_C_ECONOMY_INCOME_PERCENT_MAX = 30` **[Note: the relationship between the 70% default and the 30% slider cap requires in-game verification - these may represent different things in the UI]**.
- Supply cap: `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT = 40,000` supply maximum per side. `Common/Init/Init_CommonConstants.sqf:164`
- Supply team limit: `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50,000`. Line 170.
- Engineer slot commanders can salvage wrecks from the scroll menu — useful when the base is under attack and vehicles are being destroyed. `Guides/CommanderGuide/commanderGuide.md:436-441`
- Money can be sent to teammates from the advanced money transfer menu.

---

## Key Tactical Notes

### Base Positioning
- **High ground** — improved sight lines and defensive advantage.
- **Central map** — maximizes CC coverage radius (5,500 m) and supply truck accessibility.
- **Stealthy hide** — sell the base before enemies spot it; a hidden CC provides coverage from the center indefinitely if undiscovered.
- Towns are naturally defensible but are discoverable because enemies pass through them during capture cycles.

Source: `Guides/CommanderGuide/commanderGuide.md:480-496`

### Counterbase Tactic
- Redeploy MHQ behind enemy lines to force a 2-front war.
- Three bases are allowed, so a purpose-built counterbase is a valid late-game escalation path.

Source: `Guides/CommanderGuide/commanderGuide.md:499-501`

### Air Superiority Endgame
- Up to 3 bases permitted; not all need an AF. A late-game third base with AF + SP dedicated to air operations is viable.
- AF need not be placed on an actual runway — any open area large enough for takeoff works.

Source: `Guides/CommanderGuide/commanderGuide.md:506-511`

### Comeback Mechanics
- Defend tightly, draw out the enemy, and capitalize on their mistakes.
- Be aware: a defending team is a prime ICBM target. Lift the MHQ to high ground if ICBM threat is real.
- Supply upgrade unlocks are especially valuable after losing towns — get Supply 1 fast if you are capturing large-SV towns or recovering from a new-HQ cash purchase (all towns reset to SV 10 on cash-HQ purchase; `WASP/actions/Action_RepairMHQDepot.sqf:28`).

Source: `Guides/CommanderGuide/commanderGuide.md:475-478,522-525`

### Airlift Combo
- AF1 + Airlift upgrade (1,000 supply, 30 s) enables MH-60S / Mi-17 to lift the MHQ across the map.
- Airlift upgrade time is 30 seconds — you can queue the vehicle purchase first, then start the upgrade; if the vehicle is ready when the upgrade completes you gain airlift capability immediately.

Source: `Guides/CommanderGuide/commanderGuide.md:224-228`; `Upgrades_USMC.sqf:40` (1,000 supply cost); `Upgrades_USMC.sqf:129` (30 s)

---

## Continue Reading

- [Commander-HQ-Lifecycle-Atlas](Commander-HQ-Lifecycle-Atlas) — full technical lifecycle of MHQ deploy, mobilize, kill, and repair events with SQF call chains.
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — developer-level upgrade system internals (unlock checks, PV dispatch, AI order lists).
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — town SV mechanics, supply accumulation rates, and income pipeline.
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — buy-menu structure, unit queue, and factory unlock gating.
- [Construction-And-CoIn-Systems-Atlas](Construction-And-CoIn-Systems-Atlas) — CoIn placement engine, defense templates, base area system, and build limit enforcement.
