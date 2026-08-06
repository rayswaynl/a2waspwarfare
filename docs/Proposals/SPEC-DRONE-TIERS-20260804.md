# Drone Tiers — Loitering Munitions + GBU Strike Drone (v2, 2026-08-04)

**This document supersedes the munitions and UI sections of
`docs/Proposals/SPEC-MQ9-ARMED-UAV-20260804.md` per owner rulings below.** It keeps that
spec's config-truth (§3 classnames/proof chain), locality pattern (§5), rearm trap (§7),
and A2 trap list (§8) **by reference** — they are not re-litigated here, only cited where
this feature reuses them. Everything about *what gets built, for whom, priced how, gated
how* is redefined by this document.

Base checked: `origin/update/wave-20260802` (`952c287635`, fetched 2026-08-04), repo
read-only for this research pass — every citation is `git show
origin/update/wave-20260802:<path>`, never recollection. Mission source of truth is
`Missions/[55-2hc]warfarev2_073v48co.chernarus/` (`<CH>/` below); Takistan/Zargabad are
LoadoutManager mirrors, not edited directly. Prior research this spec draws on and does
not repeat: `docs/design/v2/EASA-FOB-PURCHASE-SURFACE-MAP-20260804.md` (EASA end-to-end,
both FOB systems, GUER Depot, cash/supply idiom — untracked local file, same fetch base)
and `docs/design/v2/FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md` (the "earlier scope" ruling 2
names).

## 0. Owner design rulings (2026-08-04, verbatim intent)

1. Add a UAV upgrade **LEVEL 2**; armed-drone capability locks behind it.
2. Munitions follow the **earlier scope** —
   `docs/design/v2/FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md`: **loitering munitions,
   player-launched, manual fire, driver-operable**.
3. **Three tiers**, staggered in price, slotted via the existing **EASA system** for easy
   tuning.
4. Purchase **only** from a deployed FOB (`WFBE_C_STRUCTURES_FOB` feature); **GUER gets
   its own acquisition path** (designer latitude — GUER FOB truck depot is the starting
   candidate).
5. **Fourth option**: a **GBU-class strike drone**, reusing the MQ-9 config-truth from
   `SPEC-MQ9-ARMED-UAV-20260804.md` — expensive, very late-game.

## 1. Feature summary — end state

Flag on: a WEST/EAST player who has researched `WFBE_UP_UAV` **Level 2** and stands at
their side's own live Forward FOB tent can open a new "Drone Shop" WF_Menu row and buy
one of three price-staggered **loitering munitions** (Tier 1 Light / Tier 2 Medium /
Tier 3 Heavy — same driver-operable, manual-fire, ram-or-detonate flight model the
existing FPV strike drone already ships) or, once very heavily invested, a **Tier 4 GBU
strike drone** — the SPEC-MQ9 armed-MQ9-UAV feature, reused wholesale, purchased through
this same shop instead of (or in addition to) the plain Tactical-menu UAV call. A GUER
player reaches the identical tier ladder through GUER's own Drone Operations dialog
(`idd=32000`), gated on a live GUER FOB (Barracks/Light/Heavy) instead of the WEST/EAST
tent.

Flag off (`WFBE_C_DRONE_TIERS = 0`): **mission byte-identical to HEAD.** The existing
`WFBE_C_FPV_DRONE` support call keeps working exactly as it does today for every side —
unconditional field launch, no FOB requirement, no UAV-level gate, GUER at $5,000 /
WEST-EAST at $2,500 (live default, see §3.0 trap). Nothing in this spec touches that code
path unless the new master flag is on.

## 2. Flags — master + per-tier subflags

Per repo flag policy (`CLAUDE.md`): new feature additions default 0, flag-off is
byte-identical, registered once in `Common/Init/Init_CommonConstants.sqf`, never editing
an existing default. `WFBE_C_FPV_DRONE`'s existing default (`= 1`, live/on) is **not**
touched — see §3.0 for why a *new* master flag, not a repurposed old one, is required.

```sqf
//--- Drone Tiers (SPEC-DRONE-TIERS-20260804, owner rulings 2026-08-04). Master: 0 = the
//--- mission is byte-identical to HEAD — WFBE_C_FPV_DRONE keeps its current unconditional,
//--- all-sides, no-FOB behaviour untouched. 1 = the tiered/FOB-gated system below replaces it.
if (isNil "WFBE_C_DRONE_TIERS") then {WFBE_C_DRONE_TIERS = 0};

//--- Per-tier subflags, meaningful only while the master is on. Independently toggleable so a
//--- staged rollout (e.g. ship Tier 1 rework, hold Tier 4 back) never needs a code change.
if (isNil "WFBE_C_DRONE_TIER1") then {WFBE_C_DRONE_TIER1 = 1}; //--- Light loitering munition (existing FPV asset, reworked).
if (isNil "WFBE_C_DRONE_TIER2") then {WFBE_C_DRONE_TIER2 = 1}; //--- Medium loitering munition.
if (isNil "WFBE_C_DRONE_TIER3") then {WFBE_C_DRONE_TIER3 = 1}; //--- Heavy loitering munition.
if (isNil "WFBE_C_DRONE_TIER4") then {WFBE_C_DRONE_TIER4 = 1}; //--- GBU-class strike drone (reuses SPEC-MQ9).

//--- Tier prices. Cash, single tuple each (EASA-idiom literal ints, owner ruling 3 — see §6).
if (isNil "WFBE_C_DRONE_TIER1_COST") then {WFBE_C_DRONE_TIER1_COST = 5000};   //--- = live WFBE_C_FPV_DRONE_COST_GUER unchanged.
if (isNil "WFBE_C_DRONE_TIER2_COST") then {WFBE_C_DRONE_TIER2_COST = 9000};
if (isNil "WFBE_C_DRONE_TIER3_COST") then {WFBE_C_DRONE_TIER3_COST = 15000};
if (isNil "WFBE_C_DRONE_TIER4_COST") then {WFBE_C_DRONE_TIER4_COST = 45000};  //--- expensive, late-game per ruling 5.

//--- Tier warheads (CfgAmmo classes createVehicle'd directly by Support_FPV_Detonate.sqf — see §5.0).
if (isNil "WFBE_C_DRONE_TIER1_AMMO") then {WFBE_C_DRONE_TIER1_AMMO = "R_57mm_HE"};   //--- unchanged from today.
if (isNil "WFBE_C_DRONE_TIER2_AMMO") then {WFBE_C_DRONE_TIER2_AMMO = "Bo_FAB_250"};  //--- see §5.2 proof + open verification note.
if (isNil "WFBE_C_DRONE_TIER3_AMMO") then {WFBE_C_DRONE_TIER3_AMMO = "Bo_GBU12_LGB"}; //--- see §5.3; SPEC-MQ9 §3-proven class, reused.

//--- Tier 4 balance knobs (SPEC-MQ9 §2 tunables, unrenamed so any future SPEC-MQ9 PR body
//--- referencing them stays valid; this feature is simply what wires them to a purchase path).
if (isNil "WFBE_C_UAV_ARMED_GBU12_MAGS") then {WFBE_C_UAV_ARMED_GBU12_MAGS = 2}; //--- Tier 4 default: 2 mags = 8x GBU-12 (SPEC-MQ9 default was 1/4x; bumped — see §5.4).

//--- FOB proximity + GUER path (see §7-8).
if (isNil "WFBE_C_DRONE_FOB_RANGE") then {WFBE_C_DRONE_FOB_RANGE = 40};       //--- m from a live FOB tent (WEST/EAST) / FOB factory (GUER) to open the shop.
if (isNil "WFBE_C_DRONE_REARM_COOLDOWN") then {WFBE_C_DRONE_REARM_COOLDOWN = 90}; //--- per-UID seconds between any drone-tier purchase (mirrors WFBE_C_FPV_COOLDOWN's role, wider since 4 tiers share one slot).
```

Consumer sites test every flag `> 0` (never bare truthy, never `==`/`!=`) —
`WFBE_C_DRONE_TIERS > 0` gates the master switch, then the per-tier flag gates whether
that specific row is offered.

## 3. What changes for the existing `WFBE_C_FPV_DRONE` call

### 3.0 Live-default trap (verify before touching anything)

`WFBE_C_FPV_DRONE_COST` defaults to **2500** on `Init_CommonConstants.sqf:3012`
(`if (isNil …) then {… = 2500}`), which runs at mission init **before** any consumer's
`getVariable […, 7500]` read — the `7500` fallbacks baked into `fpv.sqf:26`,
`Support_FPV.sqf:351`, and `GUI_Menu_Tactical.sqf:141` are dead code under normal boot
order (`wasp-getvariable-fallback-trap`: fallback ≠ live value). The live WEST/EAST price
today is **$2,500**, not the $7,500 the comments/fallbacks imply. Tier 1's price in §2
above (`$5,000`) matches the live **GUER** rate (`WFBE_C_FPV_DRONE_COST_GUER`, correctly
defaulted at `Init_CommonConstants.sqf` next to it) since ruling's rework makes Tier 1
GUER-exclusive (§4) — WEST/EAST's $2,500 field-launch price becomes moot once their
Tactical Center row is retired under the master flag.

### 3.1 Why a new master flag, not a repurposed old one

`WFBE_C_FPV_DRONE` is live at default `1` in production. This feature changes its
*availability rules* (GUER-only, FOB-gated) for every side simultaneously — that is a
default-on behavior change, which the flag policy forbids doing to an existing flag's
default. `WFBE_C_DRONE_TIERS` (new, default 0) is the switch: **off**, `fpv.sqf` and the
Tactical Center row behave exactly as today, untouched, for every side. **On**, the
consumer sites below gate on `WFBE_C_DRONE_TIERS > 0` first and branch to the new
behavior; the old unconditional branch is what remains when it's off.

### 3.2 GUER-only rework (resolves the previously-open "GUER-only" item)

`docs/Proposals/SPEC-MQ9-ARMED-UAV-20260804.md:4` flagged "making the FPV strike drone
GUER-only" as a separately-tracked, undesigned owner item. This spec's PR-1 (§13)
resolves it as part of Tier 1:

- **WEST/EAST**: the `GUI_Menu_Tactical.sqf:137-141` row-append block
  (`if ((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) > 0) then {…}`) gets an
  outer `if (WFBE_C_DRONE_TIERS <= 0) then {…}` wrap — when the master flag is on, this
  row is never appended, and the `"FPV_Strike"` case at `:435` / `:583` becomes
  unreachable (dead code retained for flag-off parity, not deleted). WEST/EAST access to
  any loitering munition moves entirely into the new FOB-gated shop (§7), starting at
  whichever tiers are enabled — Tier 1 through Tier 4 are **not** GUER-exclusive on the
  *shop* side, only the *old field-launch call* is retired for WEST/EAST.
- **GUER**: `Client/GUI/GUI_Menu_GuerDrones.sqf`'s existing FPV card (state machine
  `_fpvState 0/1/2`, IDCs `32012-32014`) is kept as the live UI, but its LAUNCH branch
  (`MenuAction == 1`, `:203-210`) gains the same FOB-proximity gate the WEST/EAST shop
  uses (§7.2) in place of today's unconditional access — GUER's existing $5,000 price and
  cooldown UI are otherwise unchanged, they simply now require standing at a live GUER
  FOB structure first.
- **Owner-reviewable**: this makes GUER's Drone Operations dialog the sole home of Tier 1
  specifically (its cheapest, signature "improvised drone" asset, matching GUER's
  existing preferential $5k pricing and asymmetric-warfare flavor already built into the
  flag system) — while GUER *also* gets shop access to Tiers 2-4 like WEST/EAST, just
  through its own FOB path (§8) rather than the Forward FOB tent. If the owner instead
  wants WEST/EAST to keep a (FOB-gated) Tier 1 option too, delete the outer wrap in
  `GUI_Menu_Tactical.sqf` and route it through §7 like Tiers 2-4 — flagged here, not
  decided, per the task's ask to mark the GUER-only call explicitly reviewable.

## 4. UAV upgrade LEVEL 2

### 4.1 Today (single-tier, `Upgrades_CO_US.sqf` shown, others mirror)

`WFBE_UP_UAV = 5` (`Init_CommonConstants.sqf:42`, one of 24 fixed slot indices). Every
side's `Upgrades_<SIDE>.sqf` carries this **identical parallel-array shape** at index 5
(verified on `Upgrades_CO_US.sqf`, mirrored structurally — including the always-false
`ENABLED[5]` slot — on `Upgrades_GUE.sqf`, which has no UAV classname):

| Array | Index 5 value today |
|---|---|
| `ENABLED[5]` | `if (isNil {getVariable Format["WFBE_%1UAV",_side]}) then {false} else {true}` |
| `COSTS[5]` | `[[2000,0]]` |
| `LEVELS[5]` | `1` |
| `LINKS[5]` | `[[WFBE_UP_AIR,2]]` |
| `TIMES[5]` | `[60]` |
| `AI_ORDER` | one static entry, `[WFBE_UP_UAV,1]` |

`GUI_Menu_Tactical.sqf:425-427` gate: `_currentLevel = _currentUpgrades select
WFBE_UP_UAV; _controlEnable = … && {_currentLevel > 0} && …` — a bare `> 0` check, level
1 and level 2 are indistinguishable to it today because there is no level 2.

**SPEC-MQ9 §6 recommended NOT promoting this (Option 1: ride the existing binary gate).
Owner ruling 1 explicitly overrides that recommendation — this spec designs the
promotion, not whether to do it.**

### 4.2 The promotion

Per side file that actually carries a UAV classname, append a second tuple/level to each
array:

```sqf
//--- COSTS[5]: add a level-2 tuple. Non-binding price — same "literal array of tuples" idiom
//--- every other multi-level upgrade in this file already uses (Barracks/Air/Gear, etc).
[[2000,0],[6000,0]], //--- UAV: L1 plain UAV (unchanged), L2 unlocks the Drone Shop's armed tiers.

//--- LEVELS[5]: 1 -> 2.
2, //--- UAV

//--- LINKS[5]: level-2 gates on level-1 of the SAME upgrade (must already own a UAV to arm one) —
//--- the standard self-referential per-level idiom this array already uses for e.g. Barracks/Gear.
[[WFBE_UP_AIR,2]],[[WFBE_UP_UAV,1]], //--- UAV: L1 dep unchanged, L2 requires UAV L1.

//--- TIMES[5]: add a level-2 research time.
[60,90], //--- UAV

//--- AI_ORDER: append [WFBE_UP_UAV,2] after the existing [WFBE_UP_UAV,1] entry (do not rely on
//--- Check_Upgrades.sqf's tail auto-append for pacing — see §4.3 below for why).
```

**Which files, exactly — verify before assuming "6 files":** SPEC-MQ9 §6 counted CDF, US,
US_Camo, USMC, RU, INS as the six UAV-bearing sides. `Root_USMC.sqf:135-151` and
`Root_US_Camo.sqf` show these are **not** simple 1:1 side→file mappings — each Root file
branches (`if {…WF_A2_Vanilla…} then {…Upgrades_CO_US.sqf…} else {…Upgrades_USMC.sqf…}`)
between a shared `Upgrades_CO_US.sqf` table and a USMC/US_Camo-specific
`Upgrades_USMC.sqf` table depending on a vanilla/OA branch condition; `Root_RU.sqf` shows
the same `Upgrades_CO_RU.sqf` vs `Upgrades_RU.sqf` split. **Before editing, re-read each
Root file's live branch condition** (not assumed from this spec) to determine which of
`Upgrades_CO_US.sqf` / `Upgrades_USMC.sqf` (and `Upgrades_CO_RU.sqf` /
`Upgrades_RU.sqf`) is actually the table read on this OA-only (1.64) build — editing the
inactive branch would silently do nothing. `Upgrades_CDF.sqf` and `Upgrades_INS.sqf` are
unambiguous (one call site each). GUE/CO_GUE stay untouched (`ENABLED[5]` is always false
there — no UAV classname exists for GUER, and this spec does not add one).

**Enable-predicate must become platform-aware, not just level-aware.** SPEC-MQ9 §6
already flagged this: if RU/INS's `LEVELS[5]` is promoted to 2 alongside the others
(needed only for **array-shape consistency within that side's own tables**, not because
RU/INS gets an armed tier — `Pchela1T` has no gunner turret, per SPEC-MQ9 §3), a naive
`_currentLevel > 0` check at the Drone Shop's Tier-4 row would light up for RU/INS
players who researched a level 2 that does nothing. The shop's Tier-4 enable check (§7)
must therefore additionally test `typeOf playerUAV in WFBE_C_UAV_ARMED_CLASSES` (or
equivalently the side's own classname constant) — reusing SPEC-MQ9 §2's existing
allowlist, not inventing a new one — never a bare level check alone.

### 4.3 AI-commander research handling

Two live idioms in `AI_Commander.sqf` cover this; the choice matters because Tier 4 is
gated on a real structure (a deployed FOB), not just cash+time:

1. **Static, structure-conditional append at doctrine-build time** —
   `AI_Commander.sqf:199-217` (`WFBE_C_AICOM_RESEARCH_AIR` block): builds `_raExtend =
   [[WFBE_UP_AIR,1],[WFBE_UP_AIR,2]]` and appends it into `_program` once, at commander
   init, gated on the side already owning the prerequisite structure (checked via
   `GetFactories`).
2. **Reactive, one-shot runtime append** — `AI_Commander.sqf:1037-1046` (CBR-radar
   block): guarded by `!isNil "WFBE_UP_CBRADAR"` (constant-exists) **and** `count
   _upgLvls > WFBE_UP_CBRADAR` (array-bounds safety — a build without the level-2 entry
   is a no-op, not an error) **and** a persisted one-shot latch
   (`_logik getVariable/setVariable "wfbe_aicom_cbr_research_appended"`), triggered by a
   live runtime condition rather than baked into the static order.

**Recommendation: idiom 2 (reactive one-shot), not idiom 1.** `WFBE_UP_UAV,2` should not
be static-baked into every side's `AI_ORDER` the way `[WFBE_UP_UAV,1]` already is,
because the AI commander researching it is worthless before the AI has ever actually
built a Forward FOB (Tier 4's purchase gate, §7) — reuse the CBR pattern exactly:
`!isNil "WFBE_UP_UAV"` (always true, harmless) **and** `count _upgLvls > WFBE_UP_UAV`
(bounds-safe against a side whose table wasn't promoted) **and** a live condition —
`(_side) Call WFBE_CO_FNC_GetSideStructures` finding a live `wfbe_structure_type ==
"ForwardFOB"` entry, or for GUER, `count (missionNamespace getVariable
["WFBE_GUER_FOB_ACTIVE", []]) > 0` (existing live ledger, `Server_BuildingKilled.sqf:197`,
`Server_OnPlayerConnected.sqf:317`) — **and** a fresh one-shot latch,
`wfbe_aicom_uav2_research_appended`, distinct from the CBR one.

### 4.4 Cross-side parity discipline

This is the real cost SPEC-MQ9 §6 already flagged, not the mechanism: all five
parallel arrays (`ENABLED/COSTS/LEVELS/LINKS/TIMES`) plus `AI_ORDER` must move together
**within each edited side file** — a miswired `LEVELS[5]=2` with `COSTS[5]` still holding
only one tuple throws on the first level-2 purchase attempt (index-out-of-range on the
tuple lookup), not at load time. Verify tuple-count == `LEVELS[5]` per file after editing,
same discipline `Upgrades_CO_US.sqf`'s own existing 24-row tables already demand.

## 5. The four tiers — platforms, warheads, config proof

**Design choice: all three loitering-munition tiers reuse the identical, already-proven
`AH6X_EP1` airframe** (`WFBE_%1FPVDRONE`, already registered per side in
`Common/Config/Core_Root/Root_{US,USMC,US_Camo,RU,INS,CDF,GUE}.sqf`) — zero new airframe
classname risk. Tiers differ **only** by warhead (`WFBE_C_DRONE_TIERn_AMMO`) and price.
This is deliberate: introducing a distinct hull per tier is possible later via the exact
same `Root_<SIDE>.sqf` classname-registration idiom already proven for the FPV drone, but
is not required by any owner ruling and would add classname-proof burden this spec avoids
by design. Flagged as an owner-reviewable cosmetic option, not built here.

### 5.0 Why the warhead is a drop-in swap (mechanism proof)

`Server/Support/Support_FPV_Detonate.sqf:264`: `createVehicle [_ammoClass, _dronePos, [],
0, "NONE"]` — the server detonates the warhead by `createVehicle`-ing a **bare CfgAmmo
class directly** (the classic "spawn a shell to detonate it" idiom, same one
`Support_ScudStrike.sqf` uses, cited in this file's own header comment). This reads
`_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"]`
(`:164`) and separately queries `configFile >> "CfgAmmo" >> _ammoClass >>
"indirectHitRange"` twice (`:176`, `:213`) for blast-radius-scoped kill attribution — both
reads work for **any** valid `CfgAmmo` classname, with no dependency on the class having
ever been fired from a real weapon/magazine in this mission. Consequence: a new tier
needs **only** a proven `CfgAmmo` classname, not a new weapon/magazine/turret chain — the
lowest-risk possible extension point.

### 5.1 Tier 1 — Light Loitering Munition (existing asset, reworked)

- Platform: `AH6X_EP1` (unchanged, live).
- Warhead: `R_57mm_HE` (unchanged, live default, `WFBE_C_FPV_DRONE_AMMO` /
  `WFBE_C_DRONE_TIER1_AMMO`) — "RPG-warhead scale: hit 150 / indirect 40 / r 12" per the
  existing constant's own comment.
- Price: $5,000 (GUER-exclusive under this rework — matches the live
  `WFBE_C_FPV_DRONE_COST_GUER` rate unchanged; see §3.2).
- Flight/fire model: unchanged — §6.

### 5.2 Tier 2 — Medium Loitering Munition

- Platform: `AH6X_EP1` (same hull, §5 design choice).
- Warhead: `Bo_FAB_250`. **Proof, with an explicit verification gap flagged**:
  `Init_CommonConstants.sqf:108` (GUER VBIED blast-radius design comment) already treats
  `Bo_FAB_250` as a real, calibration-grade `CfgAmmo` classname in this exact codebase
  ("The blast is now 3x Bo_FAB_250 (far bigger than the old 3x 122mm HE)"), and the
  standard vanilla A2 OA `CfgMagazines` naming convention (`NRnd_FAB_250` magazine →
  `Bo_FAB_250` ammo — the identical pattern already config-proven for `4Rnd_GBU12` →
  `Bo_GBU12_LGB` in SPEC-MQ9 §3) is independently corroborated by the Su-34 EASA loadout
  table already carrying `4Rnd_FAB_250`/`2Rnd_FAB_250` magazines
  (`EASA_Init.sqf:15`). This is strong in-repo corroboration but **not** the
  line-numbered `CfgAmmo.txt` citation SPEC-MQ9 had (that came from the external
  `rayswaynl/arma2-co-config-reference` dump, not fetched in this research pass) — **the
  implementer must confirm `Bo_FAB_250` against that same reference dump (or the
  `a2oa-verify-command` skill's ladder) before PR-3 (§13) lands**, exactly the discipline
  this repo's CLAUDE.md requires for "every new classname."
- Price: $9,000.

### 5.3 Tier 3 — Heavy Loitering Munition

- Platform: `AH6X_EP1` (same hull).
- Warhead: `Bo_GBU12_LGB` — config-proven in SPEC-MQ9 §3 (`4Rnd_GBU12` magazine →
  `Bo_GBU12_LGB` ammo, `CfgMagazines.txt:1658-1661` → `CfgAmmo.txt:3667`, base
  `LaserBombCore`, `irLock=0,laserLock=1`), reused here as a bare ammo class exactly like
  §5.0 describes — the laser-guidance fields are irrelevant to this use (the ammo is
  `createVehicle`'d directly, not fired/guided), only its warhead/blast profile matters.
- Price: $15,000.
- **Owner-reviewable overlap note**: Tier 3 and Tier 4 (§5.4) intentionally share the same
  underlying warhead-tier config-truth (`Bo_GBU12_LGB`) — they are differentiated by
  *mechanic*, not warhead: Tier 3 is a single-shot, driver-operable, ram-or-detonate
  kamikaze loitering munition (§6); Tier 4 is a reusable-per-sortie, remote-controlled
  strike aircraft carrying multiple such warheads (§5.4). If the owner would rather Tier 3
  use a visibly distinct warhead from Tier 4, swap `WFBE_C_DRONE_TIER3_AMMO` for another
  proven class (e.g. `Bo_FAB_250` at a heavier multiplier via a second constant) — this is
  a one-line tunable change, not a design change.

### 5.4 Tier 4 — GBU-Class Strike Drone (reuses SPEC-MQ9 wholesale)

**Reads literally per ruling 5: "reuse the MQ-9 config-truth."** Tier 4 is *not* a
loitering munition — it is SPEC-MQ9-ARMED-UAV's armed-MQ9 feature (§2-§7 of that spec),
purchased through this shop instead of being a free rider on the plain UAV-upgrade gate:

- Platform: `MQ9PredatorB` (CDF/USMC) / `MQ9PredatorB_US_EP1` (US/US_Camo) — SPEC-MQ9 §3,
  unchanged citation chain. `Pchela1T` (RU/INS) is excluded exactly as SPEC-MQ9 §3
  excludes it — structurally no gunner `MainTurret` — enforced by
  `WFBE_C_UAV_ARMED_CLASSES`, carried forward unmodified.
- Munition: **only** the GBU-12 injection (`BombLauncherA10`/`4Rnd_GBU12`→
  `Bo_GBU12_LGB`, SPEC-MQ9 §3), mounted via `addWeaponTurret [-1]` /
  `addMagazineTurret [-1]` — the same turret-path idiom, same locality-wait pattern
  (SPEC-MQ9 §5), same `Common_RearmVehicle.sqf` avoidance (SPEC-MQ9 §7). Whether the
  native Hellfire and/or the Maverick injection also ship on Tier 4 is a balance
  decision, not a config-truth one — SPEC-MQ9's proof chain covers all three, this spec
  only requires GBU-12 to satisfy ruling 5's literal "GBU-class" framing. **Recommended:
  ship Hellfire (native, free) + GBU-12 (injected) only** — Maverick held back as a
  distinguishing reason to keep the plain (unarmed-turret) UAV upgrade and the MQ-9
  armed-turret spec conceptually separate lines, not a hard requirement.
- Munition count: `WFBE_C_UAV_ARMED_GBU12_MAGS = 2` (§2) — 8x GBU-12 across the sortie,
  double SPEC-MQ9's non-binding default of 1 (4x), reflecting Tier 4's "expensive,
  very late-game" framing; purely a balance knob, zero config-truth implication.
- Flight/fire model: **not** the FPV manual-fire/driver-operable flow (ruling 2 scopes
  that to Tiers 1-3 only) — the existing UAV interface's stock turret weapon-select
  action, exactly as SPEC-MQ9 §4 describes (`player remoteControl` the turret occupant;
  native A2/OA "Select Weapon" cycles Hellfire/GBU-12). No new dialog.
- Gate: `WFBE_UP_UAV` Level 2 (§4) **and** a live FOB (§7/§8) **and**
  `WFBE_C_DRONE_TIER4 > 0`.
- Price: $45,000 — highest tier by a wide margin, matching "expensive, very late-game."
- Rearm: **never** through `Common_RearmVehicle.sqf` (SPEC-MQ9 §7's wipe-back trap,
  carried forward unmodified) — this feature adds no rearm mechanic; each Tier-4 sortie
  expends its fixed magazine count once, exactly like SPEC-MQ9 §7 describes for the
  plain armed-UAV case.

## 6. Manual-fire / driver-operable flight flow (Tiers 1-3)

Ruling 2 names this shape explicitly; it already exists end-to-end for Tier 1 and needs
**no new code**, only parameterization by tier:

- **Purchase → spawn**: `Client/Module/FPV/fpv.sqf`'s auth/purchase capability handshake
  (`_sendFpvToServer` / `WFBE_PVF_RequestSpecial` → `Server/Support/Support_FPV.sqf`) —
  server re-derives cost and cooldown from the tier's own constants (never trusts the
  client), exact-`typeOf`-matches the airframe, rejects `wfbe_buyteam`-tagged hulls
  (factory-bought lookalikes, the 2026-07-24 fix). Parameterize by reading
  `WFBE_C_DRONE_TIER{N}_COST` in place of the current single
  `WFBE_C_FPV_DRONE_COST`/`_COST_GUER` pair, keyed by which tier row the player clicked.
- **Flight**: `Client/Module/FPV/fpv_interface.sqf` — `player remoteControl _driver` (the
  AI pilot seat), full manual flight, first-person camera. Unchanged for every tier.
- **Fire**: two `addAction`s on the drone — `"DETONATE WARHEAD"` (manual, player-initiated)
  and `"Abort flight (self-destruct)"` — plus an impact fuze that auto-detonates on a hard
  collision after a 3s arming delay (`WFBE_C_FPV_ARM_DELAY`) measured as a damage *delta*
  from the arm-time baseline (spawn-safety fix, unaffected by tier). This **is** the
  "manual fire, driver-operable" flow ruling 2 asks for — unchanged across all three
  tiers, only the eventual warhead class differs (§5.0).
- **Detonation authority**: `Server/Support/Support_FPV_Detonate.sqf` — exact-object
  private-capability check (never position/side/alive-state matching) before
  `createVehicle`-ing `WFBE_C_DRONE_TIER{N}_AMMO`. Parameterize the ammo-class read the
  same way as cost above.

**Mechanically**: every one of these files needs a *tier lookup*, not new logic — thread
a `_tier` value (1-3) through the existing purchase→spawn→fire→detonate chain (client
capability payload gains one integer, server re-derives cost/ammo/pilot-class from that
tier number using the constants in §2, never a client-supplied price or ammo string).
This is the smallest-diff way to satisfy "three tiers... driver-operable" without forking
`fpv.sqf`/`fpv_interface.sqf`/`Support_FPV*.sqf` into three near-duplicate file sets.

## 7. EASA slotting — exact registration shape

Ruling 3 says "slotted via the existing EASA system for easy tuning." Per the
EASA-FOB-PURCHASE-SURFACE-MAP §1.5 finding: **EASA re-equips a vehicle the player is
already sitting in — it never spawns a new vehicle.** It cannot literally host the
purchase flow (§6 needs a spawn). Ruling 3's intent, read against that constraint, is: use
the EASA **data-table shape** for the price/tier ladder, following the `#1901` SEAD-row
precedent for "slot a new option into an existing table" — not that the Drone Shop's
buy button literally lives inside `GUI_Menu_EASA.sqf`.

Concrete registration, mirroring `EASA_Init.sqf:685-708`'s `//LoadoutManagerSeadEasaInsert`
marker-block idiom exactly:

```sqf
//LoadoutManagerDroneTierEasaInsert
//--- Drone Tier price/label table (owner ruling 3, 2026-08-04): NOT wired into GUI_Menu_EASA.sqf's
//--- equip flow (EASA re-equips a vehicle the player is sitting in; it never spawns one — see
//--- EASA-FOB-PURCHASE-SURFACE-MAP §1.5). This block only publishes the tunable price/label rows;
//--- Client/GUI/GUI_Menu_DroneShop.sqf (new, §8) reads WFBE_EASA_DRONE_TIERS directly instead of
//--- going through EASA_Equip.sqf or _easaLoadout at all.
if ((missionNamespace getVariable ["WFBE_C_DRONE_TIERS", 0]) > 0) then {
	WFBE_EASA_DRONE_TIERS = [
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER1_COST", 5000]),  "Tier 1 - Light Loitering Munition",  1],
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER2_COST", 9000]),  "Tier 2 - Medium Loitering Munition", 2],
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER3_COST", 15000]), "Tier 3 - Heavy Loitering Munition",  3],
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER4_COST", 45000]), "Tier 4 - GBU Strike Drone",          4]
	];
};
//LoadoutManagerDroneTierEasaInsert_END
```

`[price, label, tierNumber]` mirrors the existing `[price, label, [[weapons],[ammo]]]`
row shape structurally (same "literal array of tuples, hand-tuned ints" idiom §1.3 of the
mapping doc describes — "no formula, no cost curve, just literal numbers per row") while
substituting a `tierNumber` for the unused weapon/ammo pair, since the Drone Shop consumes
it directly rather than through `EASA_Equip.sqf`. Placed in `EASA_Init.sqf` (registered
once, alongside the SEAD block) purely so the *tuning surface* — the file a designer
already knows to open to reprice things — is the same one, per ruling 3's literal ask;
the shop dialog (§8) is the actual consumer, not `GUI_Menu_EASA.sqf`.

## 8. FOB-scoped purchase (WEST/EAST)

### 8.1 What's on the tent today

`Server/PVFunctions/RequestForwardFOB.sqf` builds a `LocationLogicCamp` + per-side tent
(`WFBE_%1FARP`, e.g. `Camp_EP1`) tagged `wfbe_structure_type = "ForwardFOB"`,
`wfbe_is_fob = true`, registered in `WFBE_FOB_<side>` (array of tent objects,
`Init_CommonConstants.sqf:3197-3214` for all constants: `WFBE_C_FOB_COST=25000`,
`WFBE_C_FOB_CAP_PER_SIDE=2`, `WFBE_C_FOB_MIN_RANGE=370`). **It attaches zero
`addAction`s** — its only live behavior is `Server_ForwardFOBWorker.sqf` (hostile-ping +
passive repair bubble).

### 8.2 Why a naive `addAction` on the tent is wrong

`Init_Unit.sqf:179-180`'s existing `wfbe_engine_stealth_action` comment states the trap
outright: *"Starting armor is created by Init_Server.sqf, where addAction would be
server-local and invisible on dedicated clients."* `RequestForwardFOB.sqf` creates the
tent inside a server PVF — the identical situation. A single server-side
`_tent addAction […]` would never appear on a dedicated client.

### 8.3 The precedented fix: polled proximity flag, not addAction

`Client/FSM/updateavailableactions.fsm:154-186` already computes booleans like
`gearInRange` every tick by walking `Client/Functions/Client_GetClosestCamp.sqf` (a
`nearEntities [WFBE_Logic_Camp, _range]` scan filtered by `alive (_x getVariable
"wfbe_camp_bunker")` and `sideID`) — exactly the lookup `RequestForwardFOB.sqf`'s own
`FOBCAMPPROBE` self-check (`:143-149`) already proves finds a live Forward FOB tent.

Add `droneShopInRange` to the same FSM, same idiom:

```sqf
"droneShopInRange = false;" \n
"{if (alive (_x getVariable [\"wfbe_camp_bunker\", objNull])) then {" \n
"  if ((_x getVariable [\"sideID\", -1]) == sideID && {(_x getVariable [\"wfbe_camp_bunker\", objNull]) getVariable [\"wfbe_structure_type\", \"\"] == \"ForwardFOB\"}) then {droneShopInRange = true};" \n
"}} forEach (player nearEntities [WFBE_Logic_Camp, (missionNamespace getVariable [\"WFBE_C_DRONE_FOB_RANGE\", 40])]);" \n
```

Feed it into the existing `_usable` array (`updateavailableactions.fsm:248`) alongside
`gearInRange`/`hqInRange`, gating a new "Drone Shop" `WF_Menu` row/button exactly the way
`gearInRange` already gates "Buy Gear" (`GUI_Menu.sqf:128-133`'s `MenuAction == 2` case) —
**not** an `addAction` on the tent. This needs the same engine-behavior verification the
mapping doc's §5 already flags as unbuilt/unverified: confirm a runtime-created object's
`getVariable` reads are consistent across every client the way `nearEntities` already is
per `RequestForwardFOB.sqf`'s own self-check — do this before committing to the FSM
approach over any alternative (`a2oa-verify-command` skill discipline).

### 8.4 Purchase flow — server-authoritative, cash-only (reuse Forward FOB's idiom, not EASA's)

The mapping doc §4.3 is explicit: EASA/BuyUnits charge **client-computed,
client-applied** (`Call GetPlayerFunds; if (_funds >= _cost) then {…; -_cost Call
ChangePlayerFunds}`, no server round-trip); Forward FOB deliberately opts into a
**server-authoritative** shape instead (client pre-check for UI feedback only; server
re-reads `_group getVariable "wfbe_funds"` itself before debiting via
`WFBE_CO_FNC_ChangeTeamFunds`). **Recommendation: copy Forward FOB's shape, not
EASA/BuyUnits'** — a capped, structure-gated military asset should not trust a
client-supplied price, exactly Forward FOB's own reasoning
(`Action_BuildForwardFOB.sqf`'s header comment). New dedicated PVF, `RequestDroneTier`,
registered in `Common/Init/Init_PublicVariables.sqf` (`Init_PublicVariables.sqf:17`'s
list, alongside `RequestForwardFOB`):

```sqf
_l = _l + ["RequestDroneTier"]; //--- Drone Tiers shop (flag WFBE_C_DRONE_TIERS): FOB-gated purchase of Tiers 1-4 (Server\PVFunctions\RequestDroneTier.sqf).
```

`Server/PVFunctions/RequestDroneTier.sqf` mirrors `RequestForwardFOB.sqf`'s
validate-then-charge sequence: re-derive the tier's cost from `WFBE_C_DRONE_TIER{N}_COST`
server-side (never a client-supplied number), re-check the caller is within
`WFBE_C_DRONE_FOB_RANGE` of a live `wfbe_structure_type == "ForwardFOB"` tent belonging
to their own side (re-derived from the object's own position, never client-reported
position — the same "never trust client position" rule
`FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md`'s security notes already state for the FOB-launch
gate design), re-check `WFBE_UP_UAV` Level 2 (§4) and the appropriate `WFBE_C_DRONE_TIER{N}`
subflag, re-check the per-UID `WFBE_C_DRONE_REARM_COOLDOWN` stamp, **then** debit via
`WFBE_CO_FNC_ChangeTeamFunds` and either spawn the loitering-munition airframe (Tiers 1-3,
reusing `fpv.sqf`'s existing spawn-safety radial-offset+clearance-retry pattern at the FOB
tent's position instead of a Command Center's) or the MQ-9 (Tier 4, reusing
`Support_UAV.sqf`'s existing spawn path with SPEC-MQ9's arming block appended).

### 8.5 Cap / cooldown

- **Cap**: none beyond the existing "one live FPV drone per player"
  (`!(alive playerFPV)`) rule for Tiers 1-3, and the existing "one live UAV per player"
  (`!(alive playerUAV)`) rule for Tier 4 — both already enforced by the code being reused,
  not new.
- **Cooldown**: `WFBE_C_DRONE_REARM_COOLDOWN` (default 90s, §2), per-UID, shared across
  all four tiers (buying any tier starts the same cooldown) — wider than the existing
  60s `WFBE_C_FPV_COOLDOWN` since it now gates four price points instead of one, and
  prevents a rapid tier-hop purchase pattern.

### 8.6 Interaction with FOB death

`Server/Functions/Server_ForwardFOBKilled.sqf` already deletes the camp logic
immediately (closing the `Action_RepairCamp.sqf` resurrect-exploit window,
`Server_ForwardFOBKilled.sqf`'s own header comment), drops the side's `WFBE_FOB_<side>`
registry entry, and deletes the tent+antenna after a 10s wreck-visibility delay
(mirroring `Server_BuildingKilled.sqf`'s tail). **No new teardown code is needed for the
shop itself** — `droneShopInRange` (§8.3) reads `alive (_x getVariable
"wfbe_camp_bunker")` on every poll, so it goes false the instant the tent dies, closing
the shop UI/menu row automatically. **Open owner decision, mirroring
`FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md`'s Phase-C item**: if a purchase is mid-flight
(drone already spawned, pilot still flying it) when the FOB that sold it dies, does the
drone (a) fly on unaffected (recommended — the asset is already paid for and airborne,
punishing a player mid-flight for something outside their control is poor game feel) or
(b) get scuttled? This spec recommends (a), matching the existing FPV watchdog's own
philosophy (a drone in flight is tracked by its own TTL/pilot-death conditions, never
by an external structure's lifecycle) — not decided here, flagged for the same
owner-review the earlier spec already deferred it to.

## 9. GUER acquisition path

Per the mapping doc §3, GUER has **no** commander/structure-scoped shop at all — every
GUER purchase forces through the Depot-typed `RscMenu_BuyUnits` dialog
(`Client_BuildUnit.sqf:1151`, `_type='Depot'` hard-forced), and the existing GUER FOB
system (B75: FOB trucks earned via kill-tech tokens `WFBE_GUER_FOB_AVAIL`, bought at any
friendly/neutral town-center Depot, driven out and built via `Action_BuildFOB.sqf`) has
**zero purchase surface of its own** once built — it becomes an ordinary registered
structure.

**Recommendation: reuse GUER's existing Drone Operations dialog (`idd=32000`,
`Client/GUI/GUI_Menu_GuerDrones.sqf`) as the shop UI, gated on `WFBE_GUER_FOB_ACTIVE`
proximity — not the Depot roster.** This is the "GUER FOB truck depot" the ruling names
as the starting candidate, read as: the *token/build* path stays the existing B75 system
unchanged (kill-earned tokens, Depot-bought trucks, field-built factories); the *shop*
that then sells drone tiers is GUER's own Drone Ops dialog, proximity-gated on a live
GUER FOB structure exactly like §8.3 gates WEST/EAST's shop on the Forward FOB tent:

```sqf
//--- GUER FOB proximity gate, mirroring §8.3's droneShopInRange but against the GUER ledger
//--- (Server_BuildingKilled.sqf:197 / Server_OnPlayerConnected.sqf:317 — existing, live).
_guerFobNear = false;
{ if (!isNull _x && {alive _x} && {(player distance _x) < (missionNamespace getVariable ["WFBE_C_DRONE_FOB_RANGE", 40])}) then {_guerFobNear = true}; }
	forEach (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
```

This is genuinely designer latitude (the EASA-FOB map's §3 already lists three candidate
shapes and deliberately did not pick one) — **the Drone-Ops-dialog-plus-FOB-ledger-gate
option above is this spec's recommendation, not a decision**. The two alternatives the
mapping doc already scoped (extend the Depot roster with a FOB-liveness gate; or a
hybrid keeping the Depot UI with a nearest-FOB distance re-check layered on top) remain
available if the owner prefers GUER's shop to live in the same dialog as its other
purchases rather than the Drone Ops dialog. **Owner-reviewable — mark before PR-4 (§13)
starts.**

## 10. A2 OA traps that bite each part

From `CLAUDE.md` / `sqf-edit-guard` (this worktree's version, which explicitly documents
`BAREEXIT` — the 2026-08-03 empty-Factory-Upgrade-Menu incident class):

- **BAREEXIT**: every early-return in the new `RequestDroneTier.sqf`, the FSM
  `droneShopInRange` block, and the tier-lookup branches inside `fpv.sqf`/
  `Support_FPV.sqf` must be `if (..) exitWith {}`, never a bare `exitWith` — a bare one
  silently parse-fails the *entire file*.
- **Turret-index trap (Tier 4 only)**: `[-1]` = hull/single-turret path for
  `addWeaponTurret`/`addMagazineTurret` on `MainTurret` — carried unmodified from
  SPEC-MQ9 §8. Never plain `addWeapon`/`addMagazine` on the MQ-9 (silent no-op).
- **Locality (Tier 4 only)**: the GBU-12 injection must wait for `local _uav` before
  touching the turret — SPEC-MQ9 §5's bounded `waitUntil`, unmodified. Tiers 1-3 need no
  equivalent wait; `fpv.sqf` already creates the drone as a fresh, immediately-crewed
  vehicle rather than injecting weapons onto a pre-existing server-local one.
- **`Common_RearmVehicle.sqf` avoidance (Tier 4 only)**: SPEC-MQ9 §7's wipe-back trap,
  unmodified — the injected GBU-12 magazine exists only at runtime; routing Tier 4
  through the config-reading rearm function would silently strip it.
- **GROUPGETVAR**: `RequestDroneTier.sqf`'s funds re-read must use `_group getVariable
  "wfbe_funds"` (1-arg + `isNil` guard, or the existing `WFBE_CO_FNC_ChangeTeamFunds`
  choke-point) — never the 2-arg `getVariable [name, default]` form on a GROUP receiver.
- **Numeric-flag guard**: every new `WFBE_C_DRONE_*` read uses `> 0`, never bare
  truthiness, never `==`/`!=`.
- **Never trust client position/price**: `RequestDroneTier.sqf` re-derives the FOB's
  position from the server-held tent object, the cost from `WFBE_C_DRONE_TIER{N}_COST`,
  and the tier number bounds-checks against `[1,2,3,4]` — a malformed/out-of-range tier
  argument must reject, not index an array out of bounds.
- **`_x` capture**: the GUER-ledger `forEach` in §9 and the FSM `forEach` in §8.3 don't
  nest another `forEach` inside them; if a future edit adds one, capture `_x` to a named
  local first (standard trap, flagged because both blocks are new code, not because
  either currently violates it).
- **New-classname index**: `Bo_FAB_250` (§5.2, flagged as needing final external-dump
  confirmation) and the reused `Bo_GBU12_LGB`/`BombLauncherA10`/`MaverickLauncher`
  (already indexed by SPEC-MQ9) must all appear in the PR body's config-proof section per
  `Tools/Lint`'s classname-index gate.
- **Mirror regen**: every touched file (`Init_CommonConstants.sqf`, all edited
  `Upgrades_<SIDE>.sqf`, `EASA_Init.sqf`, `GUI_Menu_Tactical.sqf`, `fpv.sqf`,
  `fpv_interface.sqf`, `Support_FPV.sqf`, `Support_FPV_Detonate.sqf`,
  `GUI_Menu_GuerDrones.sqf`, `updateavailableactions.fsm`, plus the two new files
  `RequestDroneTier.sqf` and `GUI_Menu_DroneShop.sqf`) is a Chernarus-source edit — run
  `Tools\LoadoutManager` (`dotnet run -c RELEASE`) after every batch and restore the
  TK/ZG `version.sqf.template` drift before staging, per the standard mirror step.
- **Flag-off byte-identical**: every new read in every touched file must be reachable
  only behind `WFBE_C_DRONE_TIERS > 0` (or, for Tier-1-only changes, additionally behind
  the master flag per §3.1's wrap) — this is the single hardest invariant to keep across
  a change this wide; verify per-file, not just per-flag.

## 11. Test plan — behavior assertions only

This repo has already had to unwind the "assert exact literal source text" anti-pattern
multiple times (SPEC-MQ9 §9 cites two prior incidents); the existing
`Tools/Lint/test_fpv_purchase_authority.py` shows the correct style already in
production — it asserts *ordering and mutual-exclusion invariants* (e.g. "the auth
request happens before drone creation," "the client never calls `ChangePlayerFunds`
directly"), not that a specific line of code exists verbatim.

### Must be verified in-game (no static test can meaningfully assert these)

- `droneShopInRange` (§8.3) actually goes true within one FSM tick of standing near a
  live Forward FOB tent on a real dedicated-server hop, and false within one tick of the
  tent dying — editor preview hides this timing (single-machine, no real replication).
- Each tier's warhead (`R_57mm_HE`/`Bo_FAB_250`/`Bo_GBU12_LGB`) actually detonates with a
  visibly different blast profile at the drone's server-authoritative death position.
- Tier 4's GBU-12 injection actually appears on the MQ-9's turret HUD and the native
  weapon-select action actually cycles to it — SPEC-MQ9 §9's own in-game checklist,
  unmodified, still applies verbatim.
- GUER's Drone Ops LAUNCH button actually refuses purchase away from a live GUER FOB and
  allows it in range, after the §3.2/§9 proximity-gate rework.
- The rearm cooldown (`WFBE_C_DRONE_REARM_COOLDOWN`) actually blocks a tier-hop purchase
  (buy Tier 1, immediately try to buy Tier 3) for the full cooldown window.
- Flag-off (`WFBE_C_DRONE_TIERS = 0`) mission is byte-identical to HEAD under an actual
  mission diff/soak on all three terrains, not just by code inspection.
- Mirrors (TK/ZG) behave identically to Chernarus in a live session.

### What a contract test can meaningfully assert (behavior/shape)

- **Client never debits directly for any tier**: `fpv.sqf`'s existing
  `test_fpv_purchase_authority.py`-style assertion (`assertNotIn("call
  changeplayerfunds", …)`) extended to also scan `RequestDroneTier.sqf`'s Tier-4 spawn
  path — a real behavioral guarantee (absence of a client-side debit), not a tautology.
- **Tier ↔ cost/ammo mapping is total and bounds-checked**: a structural check that
  `RequestDroneTier.sqf` handles exactly tiers `[1,2,3,4]` and has an explicit reject
  branch for anything else — guards against a silent out-of-bounds array read, a real
  failure mode, not a literal-text pin.
- **`Common_RearmVehicle.sqf` never referenced from the Tier-4 spawn path** — reuses
  SPEC-MQ9 §9's existing absence-check technique verbatim, extended to the new call site.
- **Flag registration idiom**: `WFBE_C_DRONE_TIERS` and every per-tier/per-price/per-ammo
  constant registered exactly once in `Init_CommonConstants.sqf` using the `if (isNil
  "X") then {X = v};` fallback form — guards against a duplicate/drifted registration.
- **Scope boundary (Tier 4)**: `WFBE_C_UAV_ARMED_CLASSES` (reused from SPEC-MQ9) still
  contains exactly `MQ9PredatorB`/`MQ9PredatorB_US_EP1` and never `Pchela1T` — SPEC-MQ9
  §9's existing test, unmodified, still guards Tier 4.
- **WEST/EAST Tactical-Center FPV row is unreachable when the master flag is on**: a
  structural check that `GUI_Menu_Tactical.sqf`'s `"FPV_Strike"` row-append is nested
  inside the new `if (WFBE_C_DRONE_TIERS <= 0) then {…}` wrap (§3.2) — a genuine
  behavioral guarantee about the GUER-only rework, not a tautology.
- **Mirror parity**: every touched file byte-identical across CH/TK/ZG after the
  LoadoutManager run — reuses `test_uav_spawn_authority.py`'s
  `test_generated_copies_match_source` technique as-is.

## 12. PR-sized work breakdown (tier-1 ships first)

All PRs: draft-only, `gh pr create --draft --base master`, GUIDE-REV `GR-2026-07-08a` in
the body, flag name + default + why-flag-off-is-inert + test plan + mirrors-confirmed
fields. Claim-protocol check before starting each.

1. **PR-1 — Tier 1 rework: GUER-only + FOB purchase.** Registers `WFBE_C_DRONE_TIERS`
   (master, default 0) and `WFBE_C_DRONE_TIER1*` constants only. Wraps the WEST/EAST
   `GUI_Menu_Tactical.sqf` FPV row behind `WFBE_C_DRONE_TIERS <= 0` (§3.2). Adds the GUER
   FOB-proximity gate to `GUI_Menu_GuerDrones.sqf`'s LAUNCH branch (§3.2, §9's ledger
   check). No UAV Level 2, no EASA table, no Tiers 2-4, no WEST/EAST shop yet — flag on
   is scoped to "GUER's existing drone, now FOB-gated" only. Smallest reviewable unit that
   resolves the previously-open GUER-only item end-to-end. Includes the §11
   flag-off-byte-identical and WEST/EAST-row-unreachable contract tests.
2. **PR-2 — UAV Level 2 (§4).** The five-array promotion across the verified-branch side
   files (§4.2's "verify before assuming 6 files" caveat applies here), the
   platform-aware enable-predicate fix, and the reactive one-shot AI-commander research
   append (§4.3). Independent of PR-1; can land in either order, but Tier 4 (PR-5) depends
   on it.
3. **PR-3 — Tiers 2-3 platform + EASA table.** Registers `WFBE_C_DRONE_TIER{2,3}*`
   constants, the `WFBE_EASA_DRONE_TIERS` table (§7), and threads the tier-lookup through
   `fpv.sqf`/`Support_FPV.sqf`/`Support_FPV_Detonate.sqf` (§6) so all three tiers share one
   code path. **Blocked on confirming `Bo_FAB_250` against the external config-reference
   dump (§5.2) before merge** — do not ship on the in-repo-comment corroboration alone.
4. **PR-4 — WEST/EAST FOB shop + GUER shop wiring.** The `droneShopInRange` FSM addition
   (§8.3), the new `RequestDroneTier` PVF + `Server/PVFunctions/RequestDroneTier.sqf`
   (§8.4), a new `Client/GUI/GUI_Menu_DroneShop.sqf` dialog for WEST/EAST, and the GUER
   Drone-Ops-dialog integration (§9, **owner-reviewable path choice — confirm before
   starting**). Depends on PR-1 (Tier 1 constants/gating exist) and PR-3 (Tiers 2-3
   exist); Tier 4 rows are added but stay inert without PR-5.
5. **PR-5 — Tier 4 GBU strike drone.** Registers `WFBE_C_DRONE_TIER4*` +
   `WFBE_C_UAV_ARMED*` constants (reusing SPEC-MQ9's names), the SPEC-MQ9 §5 arming block
   in the UAV spawn path, the §4 selectweapon default fix, and wires it as the shop's
   Tier-4 row (§5.4). Depends on PR-2 (UAV Level 2 exists) and PR-4 (a shop exists to sell
   it from). This is the single most expensive/latest-game PR — land last by design.
6. **PR-6 — Contract tests + mirror-parity check.** The §11 static assertions not already
   folded into PR-1/PR-3/PR-5. Can land alongside its corresponding feature PR or
   immediately after.
7. **Verification gate (not a PR).** The full §11 in-game checklist on a live
   dedicated-server session before any per-tier flag is considered for default-on.
   Flipping any default is an owner call; this spec only proposes shipping everything
   default-0/1-under-a-default-0-master.

## 13. Open owner decisions (summary)

- **§3.2**: Tier 1 GUER-exclusivity — confirmed reading of the PR-breakdown instruction,
  but the WEST/EAST Tactical-Center row removal is a live-behavior-visible change worth
  an explicit owner sign-off before PR-1 ships.
- **§5.3**: Tier 3 and Tier 4 intentionally share the `Bo_GBU12_LGB` warhead
  config-truth — differentiated by mechanic (single-shot kamikaze vs. reusable
  multi-shot sortie), not by warhead. Swap Tier 3's ammo constant if the owner wants
  visible separation instead.
- **§5.2**: `Bo_FAB_250` needs final confirmation against the external
  `arma2-co-config-reference` dump before PR-3 merges — flagged as a blocking
  verification step, not an open design question.
- **§8.6**: mid-flight drone behavior when its selling FOB dies — recommend "flies on
  unaffected," not decided.
- **§9**: GUER acquisition path — recommend Drone-Ops-dialog + `WFBE_GUER_FOB_ACTIVE`
  proximity gate; two alternatives remain on the table, genuinely designer latitude per
  ruling 4.
- **§4.2**: confirm which upgrade-table file (`Upgrades_CO_US.sqf` vs `Upgrades_USMC.sqf`,
  `Upgrades_CO_RU.sqf` vs `Upgrades_RU.sqf`) is the live OA-branch table before editing —
  an implementation-verification step, not an owner decision, but flagged because getting
  it wrong ships a silent no-op.
- **§5.4**: whether Tier 4 also carries the Maverick injection (SPEC-MQ9's third
  munition) alongside GBU-12, or stays Hellfire+GBU-12 only as recommended — pure balance
  call.
