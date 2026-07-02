# Base-Building Design Proposal — Factory compositions, defense/fort menu redo, Bank model

**Status:** PROPOSAL ONLY — no mission files edited. Deliverables are design docs +
WDDM-reviewable composition drafts under `docs/design/compositions/` (SQF blocks primary).
**Author lane:** build84 design pass, 2026-07-02 (rev 2 — Ray review feedback folded in).
**Scope:** (A) new compositions for factories — a **pure wall-material tier ladder**
(Ray: "practical, not visual — no statics, bunkers, big bloat");
(B) redo the commander construction menu's Defenses + Fortifications lists;
(C) a more fitting Bank/Reserve building model; (D) implementation sketch.

Every classname is evidence-tagged **IN-TREE** (already spawned by a live template in
this mission, or present in the WDDM `classnames.json` base-game config ground-truth) or
**NEEDS-BOX-VERIFY** (Ray's rule — confirm it spawns before shipping).

---

## 0. The tool + the format (how Ray reviews these)

**WDDM** (`rayswaynl/WDDM`, live at <https://rayswaynl.github.io/WDDM/>) is a browser-based,
offline, single-file **top-down composition editor** — exactly the tool for this job.

- **Export format** — a `missionNamespace setVariable ['NAME',[ ... ]]` block where each
  element is **`['classname',[x,y,z],dir]`**. `+Y` = building **front**, `+X` = **right**,
  `dir` in degrees, **Z ignored** (flattened to ground at spawn).
- **This is byte-for-byte the format the mission already consumes.**
  `Server\Functions\Server_CreateDefenseTemplate.sqf` (alias `CreateDefenseTemplate`) does
  `_origin modelToWorld _relPos` + `setDir (getDir _origin - _relDir)` — identical to WDDM's
  documented math. The dressing path `Server\Functions\Server_SpawnStructureDressing.sqf`
  uses the same element shape. A WDDM export pastes straight into
  `Server\Init\Init_Defenses.sqf` with **zero translation**.
- **Loading the drafts (fixed):** WDDM's project loader is a **file picker** — the
  **Load .json** button under *Save / load project (JSON)* (`index.html` `$('loadJson')`:
  file input → `FileReader` → `JSON.parse` → `loadProject`). There is NO paste field for
  project JSON; an earlier revision of these docs wrongly said "paste", which is why the
  files appeared not to load. The emitted schema was verified field-for-field against the
  tool's own `projectData()` / `loadProject()` (keys `name, parentW, parentD, parentDir,
  structureType, fortOnly, mode, objs[{cls,x,y,z,dir}]`) — it matches exactly and
  hand-traces through `loadProject` to a successful load. Fallback path: paste the SQF
  entries into *Import an existing template* and pick the Structure footprint manually.
  See `compositions/README.md` for both step-by-step paths.
- WDDM ships the **real mission walls as reference presets** (`hq_concrete_walk_exit` etc.)
  and auto-validates classnames against its base-game config export; everything used here passes.

---

## 1. Current mission state (the benchmark)

### 1a. The composition system

- **Spawner:** `CreateDefenseTemplate` (`Server\Functions\Server_CreateDefenseTemplate.sqf`).
  Signature `[_origin, _template] call CreateDefenseTemplate`. Parallel dressing spawner
  `WFBE_SE_FNC_SpawnStructureDressing` (Bank/Reserve/Radar). Both take `['class',[x,y,z],dir]`;
  missing classes are **logged + skipped** (fail-safe).
- **Templates defined in:** `Server\Init\Init_Defenses.sqf` as `WFBE_NEURODEF_<TYPE>_WALLS`.
- **Auto-wall hook:** on structure build, `Construction_SmallSite.sqf:123-131` /
  `Construction_MediumSite.sqf:163-171` / `Construction_HQSite.sqf:39` call the spawner with
  `format ["WFBE_NEURODEF_%1_WALLS", _rlType]`. `_rlType` ∈ `Headquarters, Barracks, Light,
  CommandCenter, Heavy, Aircraft, ServicePoint`.
- **Gating:** per-side boolean **`WFBE_AUTOWALL_<side>`** (default true). `AARadar` hard-excluded;
  `CBRadar/Bank/Reserve/ArtilleryRadar` use the dressing path.
- **Editing the `_WALLS` array is a zero-code change** — it flows through the spawner as-is.

### 1b. What each structure gets TODAY

| Structure | Var | Today |
|---|---|---|
| **HQ** | `WFBE_NEURODEF_HEADQUARTERS_WALLS` | 19× `Concrete_Wall_EP1` box (±6.1 m) + 4 jersey chicane, south gap — **the reference** |
| Barracks | `WFBE_NEURODEF_BARRACKS_WALLS` | 8× `Base_WarfareBBarrier5x` corner-gapped ring |
| Light Factory | `WFBE_NEURODEF_LIGHT_WALLS` | 10× `Land_HBarrier_large`, loose gappy ring |
| Heavy Factory | `WFBE_NEURODEF_HEAVY_WALLS` | 13× `Land_HBarrier_large`, loose ring |
| Aircraft Factory | `WFBE_NEURODEF_AIRCRAFT_WALLS` | 10× `Land_HBarrier_large` (= Light) |
| Command Center | `WFBE_NEURODEF_COMMANDCENTER_WALLS` | 7× HBarrier horseshoe |
| ServicePoint | `WFBE_NEURODEF_SERVICEPOINT_WALLS` | **empty `[]`** |
| Bank | `WFBE_NEURODEF_BANK_WEST/EAST` | ~24-object HESCO compound with towers/props (dressing) |

**The HQ's wall class — the HIGH-tier material — is `Concrete_Wall_EP1`**
(`Server\Init\Init_Defenses.sqf:183-207`, comment: "Shielded HQ walls (WDDM: hq_concrete_walk_exit)").

### 1c. Extracted placement rules (from the HQ + Barracks benchmarks)

| Rule | Value | Source |
|---|---|---|
| Wall standoff from building edge | ~1–4 m outside the model footprint | HQ ring ±6.1 on 13×10; Barracks ±11 on 18×12 |
| Walking gap width | ~3–5 m single gap | HQ south face (~4.4 m) |
| Corner foot gaps | ~2–5 m where segments don't meet | Barracks ring |
| **Never a closed ring** | every ring ≥1 real gap + open corners | both; A2 AI wedges on closed loops (hard rule) |
| Segment lengths (gap math) | `Concrete_Wall_EP1` ≈ 3.6 m · `Land_HBarrier_large` ≈ 5 m · `Base_WarfareBBarrier5x` ≈ 12 m · `Base_WarfareBBarrier10x` ≈ 24 m · `Land_fort_bagfence_long` ≈ 2.85 m | WDDM catalog |

**Vehicle-exit constraint** (from `Client\Functions\Client_BuildUnit.sqf` + CLAUDE.md): a
purchased vehicle spawns on a **HeliH-family pad baked into the factory model** (Light=`HeliH`,
Heavy=`HeliHRescue`, Aircraft=`HeliHCivil`, Barracks/Service=`Sr_border`); **fallback egress is
the building's +X (right) side** (`_dir=90`). Rules: never wall over the model footprint; keep
the **+X face fully open** on vehicle factories; every other face keeps ≥3 m foot gaps.

---

## A. Composition tier system — a pure wall-material ladder

**Ray spec (2026-07-02):** tier = **wall material, nothing else**. No wire, no nests, no
towers, no bunkers, no flags, no chicanes, no statics — "practical, not visual". Each
composition is a ring/line-set of the tier's wall class with a clear vehicle exit and foot
gaps, at minimal object count.

| Tier | Buildings | Wall class | Evidence |
|---|---|---|---|
| **LOW** | Barracks, Light Factory | `Land_fort_bagfence_long` (2.85 m sandbag) | IN-TREE (AAPOS/CBR/RESERVE templates) |
| **MEDIUM** | Heavy Factory, ServicePoint (opt.), Bank | `Base_WarfareBBarrier10x` (24 m HESCO slab) + `Land_HBarrier_large` (5 m) for gap control | IN-TREE (BANK/RESERVE + LIGHT/HEAVY walls) |
| **HIGH** | Command Center, Aircraft Factory | **`Concrete_Wall_EP1`** (3.6 m) — the HQ's exact wall class | IN-TREE (HEADQUARTERS_WALLS) |

Files: `compositions/*.wddm.json` (WDDM projects) + `compositions/PROPOSED_Init_Defenses_blocks.sqf`
(paste-ready SQF, **primary format**).

### A.1 — BARRACKS · LOW (6 objects) — `barracks_low.wddm.json`

18×12, infantry factory, no vehicle egress.

```
              FRONT (+Y)
   ══ ══   gap   ══ ══        4× bagfence at y=8 (x=-6,-2.9,2.9,6)
  (bagfence line, ~3 m centre foot gap)
 ‖                       ‖    1× bagfence flank step each side (x=±10, y=0)
 ‖   [ BARRACKS 18×12 ]  ‖
                              rear fully OPEN
              REAR (-Y)
```
Access: 3 m centre gap + open flanks beyond the short steps + fully open rear. NO closed ring.

### A.2 — LIGHT FACTORY · LOW (10 objects) — `light_factory_low.wddm.json`

22×14, vehicles exit **+X (right) → right face fully open**.

```
              FRONT (+Y)
   ══ ══   gap   ══ ══        4× bagfence at y=9 (x=±3.4, ±6.5), ~4 m centre gap
 ‖
 ‖   [ LIGHT 22×14 ]          →→→ +X OPEN = VEHICLE EXIT →→→
 ‖  2× bagfence left screen (x=-13, y=±1.6)
   ══ ══   gap   ══ ══        4× bagfence at y=-9, ~4 m centre gap
              REAR (-Y)
```
Access: centre gaps front/rear, right side fully clear, left screen is 5.7 m total (open
above/below). NO closed ring.

### A.3 — HEAVY FACTORY · MEDIUM (3 objects) — `heavy_factory_medium.wddm.json`

28×16, armor exits **+X (right) → right face fully open**. One 24 m HESCO slab = one object.

```
              FRONT (+Y)
   ═══════ HESCO 10x ═══════   1× slab at y=12 (spans x=-12..12; corners open ~2 m+)
 ║
 ║   [ HEAVY 28×16 ]           →→→ +X OPEN = ARMOR EXIT →→→
 ║  1× slab left (x=-17, spans y=-12..12)
   ═══════ HESCO 10x ═══════   1× slab at y=-12
              REAR (-Y)
```
Access: ~5 m corner gaps at both left corners, front/rear-right corners open, right fully
clear. 3 objects — FPS-lightest possible medium wall. NO closed ring.

### A.4 — AIRCRAFT FACTORY · HIGH (16 objects) — `aircraft_factory_high.wddm.json`

30×18, aircraft exit **+X (right) → right face fully open** (taxi apron). HQ-grade
`Concrete_Wall_EP1` on front, rear and left.

```
              FRONT (+Y)
   ▬▬▬▬▬▬ concrete ▬▬▬▬▬▬     6× at y=12 (spans x=-10.8..10.8; corners open 4 m+)
 ▮
 ▮   [ AIRCRAFT 30×18 ]        →→→ +X OPEN = AIRCRAFT APRON →→→
 ▮  4× concrete left (x=-18, spans y=-7.2..7.2)
   ▬▬▬▬▬▬ concrete ▬▬▬▬▬▬     6× at y=-12
              REAR (-Y)
```
Access: all four corners open ≥4 m, right face fully clear. NO closed ring.

### A.5 — COMMAND CENTER · HIGH (11 objects) — `command_center_high.wddm.json`

12×10, no vehicle egress. The HQ box pattern at small scale, same wall class.

```
              REAR (+Y)
   ▬▬▬ 3× concrete ▬▬▬        y=7 (spans x=-5.4..5.4)
 ▮                    ▮
 ▮  [ CMD CTR 12×10 ] ▮       3× concrete each side (x=±7, spans y=-5.4..5.4)
 ▮                    ▮
   ▬▬ gate 3.6 m ▬▬           2× concrete at y=-7 (x=±3.6) → single walking gate
              FRONT (-Y)
```
Access: one ~3.6 m front gate + ~2.3 m diagonal corner openings on all four corners
(walls don't meet). NOT a closed ring.

### A.6 — Object-count / perf summary

| Composition | Tier / wall class | Objects (was) | AI cost |
|---|---|---|---|
| Barracks | LOW `Land_fort_bagfence_long` | **6** (8) | 0 |
| Light Factory | LOW `Land_fort_bagfence_long` | **10** (10) | 0 |
| Heavy Factory | MEDIUM `Base_WarfareBBarrier10x` | **3** (13) | 0 |
| ServicePoint (optional) | MEDIUM `Base_WarfareBBarrier10x` | **1** (0) | 0 |
| Aircraft Factory | HIGH `Concrete_Wall_EP1` | **16** (10) | 0 |
| Command Center | HIGH `Concrete_Wall_EP1` | **11** (7) | 0 |
| Bank (part C) | MEDIUM 10x + `Land_HBarrier_large` gate face | **7** (~24) | 0 |

Total across all seven: **54 objects vs ~72 live** — a net reduction, all walls, zero AI,
zero decoration. Concrete counts are inherently higher (3.6 m segments — the HQ itself uses
19), and that segment-heaviness IS the visible "expensive tier" signal Ray asked for.

---

## B. Defenses + Fortifications menu redo

### B.1 — How the menu works (data, not code)

1. **Name list** `WFBE_<SIDE>DEFENSENAMES` (`Common\Config\Core_Structures\Structures_CO_US.sqf:161` etc.).
2. **Per-class data array** in `Common\Config\Core\Core_*.sqf`:
   `[label, picture, PRICE(idx2), time, crew, upgrade, CATEGORY(idx6), skill, faction, turrets]`.
   A class with **no data array is silently dropped** (`Init_Coin.sqf:54`).
3. **Tab router** `Client\Init\Init_Coin.sqf` — CATEGORY → tab: `Defense`, `Fortification`,
   `Strategic`, `Ammo`.

> Footgun: `Common\Config\Defenses\Defenses_*.sqf` hold a *second, dead* price table
> (registration commented out). Live prices are the `Core_*.sqf` index-2 values.

### B.2 — Audit of today's list (WEST / Chernarus = USMC, live prices)

| Category | Class | Display | Price | Verdict |
|---|---|---|---|---|
| Defense | `USMC_WarfareBMGNest_M240` | M240 nest | 300 | keep |
| Defense | `M2HD_mini_TriPod` | M2HD mini | 200 | keep |
| Defense | `M2StaticMG` | M2 .50 | 225 | keep |
| Defense | `SearchLight` | Searchlight | 125 | **REMOVE** — server is permanent daylight (B.4) |
| Defense | `MK19_TriPod` | MK19 GL | 700 | keep |
| Defense | `TOW_TriPod` | TOW AT | 2000 | keep, but AT price cliff (see B.3) |
| Defense | `Stinger_Pod` | Stinger AA | 3000 | keep |
| Defense | `M252` | mortar | 1150 | keep |
| Defense | `M119` | howitzer | 2800 | keep |
| Fortification | `Land_HBarrier3/5/large` | H-barriers | 30/50/80 | keep |
| Fortification | `US_WarfareBBarrier5x/10x/10xTall_EP1` | HESCO | 50/100/200 | keep |
| Fortification | `Land_fort_bagfence_long/corner/round` | sandbags | 10/8/12 | keep |
| Fortification | `Land_fortified_nest_small` | nest | 40 | keep |
| Fortification | `Land_fort_rampart` | rampart | 30 | keep |
| Fortification | `Land_fort_artillery_nest` | arty nest | 65 | keep |
| Fortification | `Hhedgehog_concreteBig` | concrete hedgehog | 95 | keep |
| Fortification | `Hedgehog_EP1` | hedgehog | 5 | keep |
| Fortification | `Fort_RazorWire` | razor wire | 25 | **flag for Ray** — he calls wire visual fluff; struck from all compositions, menu removal is his call |
| Fortification | `Concrete_Wall_EP1` | concrete wall | 30 | keep |
| Strategic | `Land_CamoNet_NATO/Var/B` | camo nets | 35/45/55 | recategorize → Fortification/Utility |
| Strategic | `Sign_Danger` | minefield | 1200 | keep (Strategic) |
| Strategic | `Land_Campfire` | campfire | 3 | **remove** (decoration) |
| Strategic | `Sr_border`/`HeliH*` | spawn markers | 15 | keep (functional) |
| Ammo | `US*Box` ×6 | crates | 850–7200 | keep |
| Defense (WDDM) | AA/Arty/Mixed light+heavy positions | 2500–5000 | keep |
| Fortification (WDDM) | Base wall straight/corner/gate | 250–300 | keep |
| — | `BAF_GPMG_Minitripod_W`, `BAF_GMG_Tripod_W`, `BAF_L2A1_*` | — | — | **DEAD** (no data array → invisible); prune |
| — | `MASH_EP1` | MASH | — | load-order ambiguous on CH; verify or pin to `MASH` |

**What nobody builds and why:** loose single fortifications (tedious one-at-a-time placement —
the WDDM wall prefabs get used instead); camo nets buried in the wrong tab; no cheap WEST AT
(700→2000 cliff; EAST has SPG-9 at 475); no elevated/overwatch buildable; no one-click obstacle line.

### B.3 — Proposed rework

Categories (within the existing 4 tabs): Infantry nests / AT / AA / Indirect (Defense) ·
Barriers / Obstacles / Utility (Fortification) · Strategic · Ammunition.

| Change | Item | Current | Proposed | Rationale |
|---|---|---|---|---|
| **ADD** | `Land_fort_watchtower_EP1` — Watchtower | not buildable | Fortification/Utility, **150** | player-usable elevated overwatch (enterable ladder+platform). Menu item only — NOT in any composition. **NEEDS-BOX-VERIFY** usability; drop if the platform isn't practically usable |
| **ADD (AA)** | **Flak Tower** (elevated AA + AI gunner) | — | Defense/AA, **~1400** | see B.5; menu item ONLY, never part of a composition (Ray) |
| **ADD (WEST AT)** | cheaper WEST static AT tier | TOW 2000 only | Defense/AT, **~900** | removes the 700→2000 cliff (EAST SPG-9 = 475). **NEEDS-BOX-VERIFY** a valid class |
| **ADD** | Hedgehog line prefab (4× `Hedgehog_EP1`) | piece-by-piece | Fortification/Obstacles, **30** | one-click AT obstacle line via the existing `WFBE_POSITION_TEMPLATE_MAP` prefab pattern |
| **RECATEGORIZE** | Camo nets | Strategic | Fortification/Utility | findability |
| **REMOVE** | Searchlights (all sides) | Defense 125 | drop | permanent daylight (B.4) |
| **REMOVE** | `Land_Campfire` | Strategic 3 | drop | decoration |
| **REMOVE** | BAF tripods ×4 | invisible | prune from `DEFENSENAMES` | dead entries |
| **FIX** | `MASH_EP1` | ambiguous | pin registered class | avoid load-order no-show |
| **DELETE (dead code)** | `Defenses_*.sqf` price arrays | inert | remove / mark dead | kill the misleading duplicate table |

Per-side flavor: fortifications stay shared/identical across sides; defenses stay
faction-authentic (US M2/TOW/Stinger · TK KORD/Metis/Igla/ZU-23 · GUER DSHKM/SPG-9).
GUER has no AA-missile/ATGM — balance call for Ray, flagged not assumed.

### B.4 — Daylight clamp: night-only items struck

The server runs a permanent-daylight clamp (`WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP`, loops
08:00→17:00, `Common\Init\Init_CommonConstants.sqf ~L1120`). Night-only items have zero
function: searchlights removed (B.3), no illumination props anywhere in this proposal
(the old Bank composition's `Land_Ind_IlluminantTower` is dropped with the rest of its props).

### B.5 — Flak Tower (elevated AA + AI gunner) — **menu item ONLY, never in a composition**

A commander-buildable premium AA position: an AA static (ZU-23 EAST / Stinger-pod or M2 WEST)
mounted on a tower's top deck, crewed through the mission's existing manning system.

**(1) Host candidates:**

| Class | Top deck | Evidence |
|---|---|---|
| **`Land_Fort_Watchtower_EP1`** (recommend) | flat railed platform ~5–6 m up | IN-TREE. **Roof-mount NEEDS-BOX-VERIFY** |
| `Land_Mil_ControlTower_EP1` | large flat observation deck, taller | IN-TREE (config-valid). NEEDS-BOX-VERIFY |
| `Land_fortified_nest_big_EP1` (fallback) | raised firing deck, lower but known-solid | IN-TREE (current Bank model) |

Placement idiom: gun `setPosATL` at deck height + `setVectorDirAndUp` level — the same
offset-child pattern as the commented concrete-stack in `Construction_StationaryDefense.sqf:85-91`.
**Static-on-building is physics-fragile in A2** (settle/jitter) → box-verify each host; fall
back to the nest deck if no tower holds the gun stable.

**(2) AI gunner — the existing pooled system, no new code, no new group:**
- `Construction_StationaryDefense.sqf:96-146`: any built defense with `emptyPositions "gunner" > 0`
  is manned from the per-base-area **`DefenseTeam`** group (persistent), capped by the area's
  `weapons` count and `WFBE_C_BASE_DEFENSE_MAX_AI`, via `Spawn HandleDefense`.
- `Server_HandleDefense.sqf:14-21`: crews **mount instantly at the gun** (`_moveInGunner=true` —
  no walk, no ladder problem) and the loop **re-mans** an empty seat after 7 s.
- Always active — no sim/distance gating (satisfies the standing HARD rule).

Cost: 1 pooled AI gunner — same AI-budget footprint as a plain ZU-23 emplacement.

**(3) Menu entry:** Defense/AA, **~1400** (EAST plain ZU-23 = 945; the premium buys elevation +
tower cover). Implemented as a `WFBE_POSITION_TEMPLATE_MAP` anchor → 2-element template
`[host tower @ ground, AA static @ deck height]` — the exact pattern the WDDM positions use.
WEST mounts `Stinger_Pod_US_EP1` or `M2StaticMG` (A2 OA has no US static bullet-AA); EAST/GUER
get the true `ZU23_TK_EP1`.

---

## C. Bank / Reserve building model

### C.1 — Today

- **Bank** ("Federal Reserve" / "Bank Rossii") — the income objective (one per side, >800 m from
  base, $6000/300 s). Live model = **`Land_fortified_nest_big_EP1`** ("Bunker (large)", ~16×16),
  set at `Structures_CO_US.sqf:112` / `Structures_CO_RU.sqf:112` (+ `%1BANK` var :149). Was
  `Land_Mil_hangar_EP1`. Its dressing is a ~24-object HESCO compound with towers/flag/props.
- **Reserve** — separate cosmetic structure, `Land_fortified_nest_small_EP1`, $2000.

**Problem:** a bunker doesn't read as "money lives here."

### C.2 — Three candidate models (config-valid IN-TREE; footprint/door NEEDS-BOX-VERIFY)

| # | Class | Reads as | Approx footprint |
|---|---|---|---|
| **1 (recommend)** | `Land_A_Office01_EP1` | administrative/financial office — the clearest "bank" silhouette, tall landmark | ~12×12 |
| 2 | `Land_Mil_Guardhouse_EP1` | hardened blockhouse / strongroom | ~8×8 |
| 3 | `Land_Ind_Garage01_EP1` | enclosed depot with roll door | ~14×8 |

Recommendation: **`Land_A_Office01_EP1`** — unambiguous civic/financial read, visible objective
landmark, plan drops into the existing dressing with a ring tightening. Keep
`Land_fortified_nest_big_EP1` as documented fallback if the door orientation fails the box check.

### C.3 — Proposed Bank walls (MEDIUM tier, 7 objects) — `bank_medium.wddm.json`

Wall-ladder spec like everything else — big walls, one raid gate, nothing decorative:

```
              REAR (+Y)
   ═══════ HESCO 10x ═══════   1× slab at y=13 (spans x=-12..12; rear corners open ~3 m)
 ║                         ║
 ║   [ BANK ~16×12 ]       ║   1× 10x slab each side (x=±15, spans y=-12..12)
 ║                         ║
   ▬▬ ▬▬  GATE 5 m  ▬▬ ▬▬     4× Land_HBarrier_large at y=-13 (x=±5, ±10)
              FRONT (-Y)          → single ~5 m raid gate, front corners ~2.5 m
```
7 objects vs ~24 live. Both sides identical (no faction props left) — one array serves
`WFBE_NEURODEF_BANK_WEST` and `_EAST` (alias line in the SQF blocks file). The raid still has
exactly one hard approach; the walls, not props, carry the "defended objective" read.

---

## D. Implementation sketch (for the later build lane)

| Piece | Where it hooks | Change | Size | Gate |
|---|---|---|---|---|
| **A. Wall-ladder compositions** (Barracks/Light/Heavy/Aircraft/CmdCtr + optional ServicePoint) | `Server\Init\Init_Defenses.sqf` — replace the `WFBE_NEURODEF_<TYPE>_WALLS` bodies with `compositions/PROPOSED_Init_Defenses_blocks.sqf` | **data-only** | **S** | existing `WFBE_AUTOWALL_<side>`; optionally one soak behind `WFBE_C_COMPOSITIONS_V2` |
| **A2. Bank walls** | same file — replace `WFBE_NEURODEF_BANK_WEST/EAST` bodies (+ alias) | data-only | **S** | ships with A |
| **B1. Menu adds** (watchtower, hedgehog line, WEST cheap AT, Flak Tower) | `WFBE_<SIDE>DEFENSENAMES` + `Core_*.sqf` data arrays; prefabs via `WFBE_POSITION_TEMPLATE_MAP` | data + map entries | **M** | additive; box-verify items flagged above first |
| **B2. Menu remove/recat/fix** (searchlights, campfire, BAF, camo tabs, MASH) | `Core_*.sqf` + `DEFENSENAMES` prune | data-only | **S** | low-risk |
| **B3. Dead-code delete** (`Defenses_*.sqf` price arrays) | remove/mark dead | cleanup | **S** | none |
| **C. Bank model swap** | `Structures_CO_US.sqf:112,149` / `Structures_CO_RU.sqf:112,149` → `Land_A_Office01_EP1` | 2 classnames | **M** | behind `WFBE_C_BANK_MODEL_V2`; **box-verify footprint/door first** |

Rollout: A/A2 (compositions, one soak) → B (menu) → C (model swap after box check).
Each independently shippable and revertible. Zero AI-budget impact except the opt-in Flak Tower.

---

## Appendix — classname evidence tags

**Composition classes (all IN-TREE — spawned by live templates in `Init_Defenses.sqf` today):**
`Land_fort_bagfence_long` · `Base_WarfareBBarrier10x` · `Land_HBarrier_large` ·
`Concrete_Wall_EP1` (the HQ wall class). These four are the ENTIRE composition vocabulary.

**Menu-proposal classes:** `Land_fort_watchtower_EP1`, `Hedgehog_EP1`, `ZU23_TK_EP1`,
`Stinger_Pod_US_EP1`, `M2StaticMG` — IN-TREE. `Land_Mil_ControlTower_EP1`,
`Land_A_Office01_EP1`, `Land_Mil_Guardhouse_EP1`, `Land_Ind_Garage01_EP1` — config-valid
IN-TREE, structural (footprint NEEDS-BOX-VERIFY).

**STRUCK from compositions per Ray (2026-07-02):** `Fort_RazorWire`, `Land_fortified_nest_small_EP1`,
`Land_fort_watchtower_EP1` (as composition element), `Land_CncBlock_Stripes` (chicanes),
`FlagCarrierGUE`, plus the old Bank props (`Land_Ind_IlluminantTower`, camo nets, crates,
cones, signs, campfire). Searchlights struck everywhere (permanent daylight).

**NEEDS-BOX-VERIFY before ship:**
- Flak-tower roof-mount stability on `Land_Fort_Watchtower_EP1` (fallback: nest-big deck).
- Watchtower practical usability as a menu buildable (drop if not).
- A valid sub-2000 WEST static AT class.
- `MASH_EP1` menu presence on Chernarus (load-order).
- Bank model door/entrance orientation vs the front raid gate.
