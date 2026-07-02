# Takistan Deep Parity + Improvement Audit

Read-only audit (2026-07-02, build84/cmdcon42 worktree). Compares the live CH mission tree
`Missions\[55-2hc]warfarev2_073v48co.chernarus` against the TK tree
`Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan`. No mission edits made.

**Headline:** Code parity is essentially perfect. The LoadoutManager mirror keeps every `.sqf`
byte-identical CH→TK except **two** files that legitimately hand-differ by design:
`Server\Init\Init_Server.sqf` (one line: DB map id `1`→`2`) and `Server\Config\Config_GUE.sqf`
(GUE_* → TK_GUE_*_EP1 classnames). `version.sqf` differs by the map defines
(`IS_CHERNARUS_MAP_DEPENDENT` / `IS_NAVAL_MAP` off, maxplayers 55→61). `description.ext` and
`Rsc\Parameters.hpp` are **byte-identical** — so all param DEFAULTS are CH-derived and uniform.

That means TK's real divergence risk lives in two places: (a) the **mission.sqm** (the mirror skips
it, so it silently falls behind), and (b) **CH-tuned numeric constants that are single global values**
never branched per-world. Both are where the findings below concentrate.

---

## TOP-10 RANKED ACTIONS

| # | What | Why it matters on TK | Effort | Exact anchor |
|---|------|----------------------|--------|--------------|
| 1 | **`_egressOK` world-size hardcode** — `_ws = 15360` used for the base-selection edge-margin reject | On the 12800 TK map, the top/right 2560 m strip never triggers the margin reject → base-selection egress can pick candidates hugging the true TK edge. (Codex #148 fix pending — confirm it lands.) | S | `Server\Init\Init_Server.sqf:342` |
| 2 | **TownMode presets missing on TK** — CH has 7 removal-set arrays, TK has 4 | Selecting `WFBE_C_TOWNS_AMOUNT` = 5/6/7 (BigTowns / CentralLine / SmallTowns) on TK finds a nil array → silently degrades to "all towns". Three lobby town-count options are **non-functional** on Takistan. | S | TK `mission.sqm` `Init_TownMode` init (~line 61) vs CH (~3332); consumed at `Common\Init\Init_TownMode.sqf:11-13` |
| 3 | **AICOM slope-Z + recovery-Z are CH-tuned single globals** — `WFBE_C_AICOM_SLOPE_Z=0.86`, `WFBE_C_AICOM_RECOVERY_SLOPE_Z=0.85` | Both comments say "tuned for rolling Chernarus roads". On Takistan's steeper ridge grades these thresholds throttle/road-snap either too eagerly or too late. Branch per-world like the plane-alt idiom. | S | `Common\Init\Init_CommonConstants.sqf:1029` and `:795` |
| 4 | **TK airfield roster is thin + no per-airfield special** — generic pool 2 aircraft vs CH's 5, and TK's specials list is keyed to `"Balota"` (a CH town) | Holding Rasman AF / Loy Manara AF is a much weaker prize than a CH airfield: 2 aircraft (An2, Mi17_TK) vs CH's 5 (An2, Mi17, Mi171Sh gunship, Su25, L159) + a Balota-exclusive L-39. TK airfields get **zero** signature exclusive. Biggest "TK plays blander" lever. | M | `Common\Init\Init_Common.sqf:408-426` |
| 5 | **TK land-HVT objective (mirror the CH carrier HVT)** — TK has no HVT flavor; carrier HVT is correctly CH-only | Takistan is the canonical SCUD map. A capturable GUER-held **SCUD-site land HVT** reuses `Support_ScudStrike.sqf` almost verbatim + the existing `server_town.sqf:300` capture block. Highest flavor-per-effort new-content item. | S (SCUD-only) / M (3-HVT set) | Parallel `Server\FSM\server_town.sqf:298-333`; gate on `worldName=="takistan"` |
| 6 | **`wfbe_skip_auto_hangar` flag missing on TK's 2 airports** — CH sets it on all 3 | Airfield-hangar auto-spawn suppression behaves differently on TK than CH (behavioral divergence, un-ported from the b754b/c carrier-hangar work). | S | TK `mission.sqm` 2× `LocationLogicAirport` init vs CH 3× (`this setVariable ["wfbe_skip_auto_hangar",true,true]`) |
| 7 | **AICOM road-march lane offset vs narrow TK roads** — perpendicular lane jitter up to ~120 m, snap radius 250 m (global) | On Takistan's sparse valley/switchback net, a 120 m perpendicular guess can land off any road → the 250 m snap misses → team dropped to a cross-country beeline over a ridge. Consider a tighter TK lane offset / wider TK snap. | S | `Common\Functions\Common_BuildRoadRoute.sqf:52-54`; `WFBE_C_AICOM_ROUTE_SNAP_RADIUS` `Init_CommonConstants.sqf:305` |
| 8 | **TK briefingName is stale** — `"PR 8 - June Feature Bundle (Takistan)"` | CH shows `"Warfare V48 Chernarus [GUER]"` with an expansive description; TK's lobby label is a months-old placeholder. Cosmetic but player-visible. | S | TK `mission.sqm` `class Intel` first block `briefingName`/`briefingDescription` |
| 9 | **STARTING_DISTANCE 7500 is a compile-time define, uniform both maps** — proportionally much tighter on TK | 7500/12800 = 0.59 of the TK map width vs 0.49 on CH → TK starts are relatively closer together (bigger fraction of a smaller map). Worth a TK-specific value (e.g. 8500-9000) if TK rounds feel cramped early. | S | `version.sqf.template:13` (`#define STARTING_DISTANCE 7500`); consumed `initJIPCompatible.sqf:22` |
| 10 | **ICBM/SCUD TEL range cap 10350 m is map-blind** — covers 81% of TK width vs 67% of CH | Not a bug (if anything TK gets a relatively stronger strike), but note the land-TEL SCUD is TK's real "big weapon" story and is effectively map-spanning on Takistan. Verify that's intended. | S (verify only) | `Init_CommonConstants.sqf:808` (`WFBE_C_ICBM_TEL_RANGE=10350`) |

Effort key: **S** = ≤ half a day, one file / one constant. **M** = 1-2 days, new small script + wiring.

---

## LANE 1 — Map-conditional code (the parity goldmine)

Every worldName / map-keyed conditional in the CH tree, with the TK value and a verdict. The two
idioms are: (a) preprocess `IS_chernarus_map_dependent` / `IS_naval_map` booleans (from `version.sqf`
defines), used for **classname / faction content** swaps; (b) runtime `worldName` switches, used for
**numeric tuning**. (a) is uniformly correct (content follows the map). (b) is where tuning gaps hide.

### Numeric tuning conditionals (the ones that matter)

| Conditional | file:line | CH value | TK value | Verdict |
|---|---|---|---|---|
| World-size / boundaries | `Common\Init\Init_Boundaries.sqf:5,8` | 15360 | 12800 | **OK** — correct per-map, canonical source |
| AICOM heli fly-off box size | `Common\Functions\Common_RunCommanderTeam.sqf:579-583` | 15360 | 12800 | **OK** — fixed 2026-06-27 (was hardcoded 15360, off by 2560 on TK) |
| AICOM plane cruise altitude | `Common_RunCommanderTeam.sqf:1008-1013`, `:1316` | 400 | 500 | **NEEDS-VERIFY** — TK peaks ~2000 m elevation; 500 m is AGL-ish cruise floor, likely fine for orbit-attack but the guard should be re-checked against the highest AICOM target town's ground elevation (a jet ordered to a 1500 m-elevation ridge town at "500 m" floor may still weave into terrain). Proposed: keep 500 but confirm `flyInHeight` is treated as AGL by the engine here. |
| `_egressOK` base-edge world-size | `Server\Init\Init_Server.sqf:342` | 15360 (hardcoded) | **15360 (WRONG on TK)** | **NEEDS-TK-TUNE** → branch to 12800 (codex #148 pending). See action #1. |
| ICBM/SCUD TEL range cap | `Init_CommonConstants.sqf:808` | 10350 (global) | 10350 | **NEEDS-VERIFY** — map-blind; 81% of TK width. Intended? See action #10. |
| AICOM road standoff | `Init_CommonConstants.sqf:302` | 24 | 40 | **OK** — already TK-branched (build84 backlog#1); wider on open TK so bases don't hug highways. Good example of the idiom done right. |
| GUER FOB trucks | `Init_CommonConstants.sqf:139` | (CH trio) | TK trio | **OK** — worldName-branched content |
| Supply heli types | `Init_CommonConstants.sqf:1078` | MH60S/Mi17_Ins | UH60M_EP1/Mi17_TK_EP1 | **OK** — content branch |
| HC park position | `Headless\Init\Init_HC.sqf:133` | sea ring-search | landlocked branch | **OK** — TK-aware (landlocked → no water park) |
| Oilfields feature | `Server\Server_Oilfields.sqf:45`, `Init_Server.sqf:927` | inert | **TK-only ON** | **OK** — TK-exclusive resource node (build83); good TK identity content |

### Single-global constants that are CH-tuned but NEVER branched (the real goldmine)

These are numbers whose comments explicitly say "Chernarus" but which apply globally on TK too:

| Constant | file:line | Value | CH-tuning evidence | Proposed TK |
|---|---|---|---|---|
| `WFBE_C_AICOM_SLOPE_Z` (careful-gear governor throttle) | `Init_CommonConstants.sqf:1029` | 0.86 | comment: "stops the LIMITED↔NORMAL accordion on **rolling Chernarus roads**" | TK-branch ~0.80 (≈37°) so only the genuinely steep TK grades downshift — Chernarus's 0.86 (~31°) fires on ordinary TK inclines and over-throttles convoys. |
| `WFBE_C_AICOM_RECOVERY_SLOPE_Z` (foot-node steepness → road snap) | `Init_CommonConstants.sqf:795` | 0.85 | recovery-v2 slope-snap; tuned once, never per-map | On TK ridges 0.85 may be reached constantly (wide road-snapping) or too rarely. Proposed TK ~0.80-0.82; measure foot-team road-snap rate on a TK soak. |
| `WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R` | `Init_CommonConstants.sqf:796` | 200 | pairs with the above | Consider 250-300 on TK (sparser mountain road net → wider search to actually find a track). |
| `STARTING_DISTANCE` | `version.sqf.template:13` | 7500 | compile-time; identical both maps | 8500-9000 for TK if early rounds feel cramped (see action #9). |

**Booleans branch (a) — all verified OK (content follows map, no tuning risk):**
`Common_AddVehicleTexture.sqf` (woodland vs desert camo), all `Core_Structures\*` (USMC/RU/Gue vs
`*_EP1` classnames), `Core_Units\*`, `Init_Common.sqf:272-273` (US_Camo/RU vs US/TKA teams),
`server_town.sqf:519-521` (ServicePoint classnames), `GUI_UpgradeMenu.sqf:55` (T-72+BMP-2 vs ZU-23
Ural GUE tier-3), `Client_RequestFireMission.sqf:68` (Takistani arty audio). None are tuning; all
correctly map-follow.

---

## LANE 2 — mission.sqm-level divergence (the mirror skips it)

Structural counts (CH | TK): triggers `class Sensors` **0 | 0** (fully script-driven, no editor
triggers on either); markers **5 | 5** (respawn×3 + deadspawn×2 — parity); playable slots **34 | 34**
(parity on count); `LocationLogicDepot` towns **46 | 33**; `LocationLogicAirport` **3 | 2**;
`class Groups` items 146 | 98. The count deltas are **terrain-structural** (Chernarus simply has more
named settlements), not parity bugs.

### Confirmed actionable gaps (verified by direct grep)

1. **TownMode presets — TK has 4 of 7** (action #2). CH defines
   `Towns_RemovedXSmall/Small/Medium/Large/BigTowns/CentralLine/SmallTowns`; TK defines only the
   first four. Consumed in `Common\Init\Init_TownMode.sqf:6-14`: cases 5/6/7 read the missing arrays,
   get nil, and the `isNil` guard (line 16) resets `TownTemplate=[]` → **silent no-op** (degrades to
   all-towns, does not crash). So three lobby town-count options do nothing on TK. **Fix:** author TK
   `Towns_RemovedBigTowns` / `Towns_RemovedCentralLine` / `Towns_RemovedSmallTowns` arrays (lists of
   TK town names to remove) in the WF_Logic init in TK's mission.sqm.

2. **`wfbe_skip_auto_hangar` missing on TK's 2 airports** (action #6). Grep: CH=3 occurrences (all
   `LocationLogicAirport` inits), TK=0. TK airports use only `init="this enableSimulation false;"`.
   Un-ported from the carrier-hangar suppression work. **Fix:** append
   `this setVariable ["wfbe_skip_auto_hangar",true,true];` to both TK airport inits.

3. **Stale TK briefingName** (action #8): `"PR 8 - June Feature Bundle (Takistan)"` +
   June-era `briefingDescription`, vs CH's current `"Warfare V48 Chernarus [GUER]"`.

### Not gaps (verified parity or correct-by-design)

- **Khe Sanh carrier towns (CH-only, 6 refs → 3 towns): NOT a gap to port.** These are the naval-HVT
  carrier logics on Chernarus's east coast. TK is landlocked → correctly absent (see Lane 3). Do not
  "port" them; instead consider the TK land-HVT (Lane 3 proposal / action #5).
- Playable slot **count** = 34 on both. Minor per-role mix difference (CH Medic6/Soldier6 vs TK
  Medic4/Soldier8) is a byproduct of today's spawn rework + the 26-shell-slot de-slot; not a missing
  feature.
- Weather/fog/date effectively parity (both weather=0, 2016-12, day 28 vs 26).
- `class Intel` secondary blocks: TK's use startWeather 0.40 / 2009 vs CH 0.25 / 2008 — these are
  inert editor artifacts (the live block is the first, with resistanceWest/briefingName). Harmless.

### Git-log evidence

TK `mission.sqm` history (10 commits) received: build8 parity (`4b98a9356`), GUER port
(`5050b4775`), HC-slot surgery (`840700790`, `3899c73e8`), slot-roster copy (`05ded7660`), and the
two spawn reworks. It **never** received the naval-HVT commits (`2e1c59317`, `be2bbd084` — correct,
landlocked), the airfield-hangar-suppression change, or a TownMode-preset commit. So gaps #1 and #2
above are un-ported-history-confirmed, not just current-state diffs.

---

## LANE 3 — Naval / carrier story on TK

**Verdict: cleanly no-ops, zero half-spawned artifacts.** Fully evidenced.

The gate is the preprocess boolean `IS_naval_map`, set from the `#define IS_NAVAL_MAP` in each tree's
real `version.sqf` (included at `initJIPCompatible.sqf:4`): **CH `version.sqf:6` = active**, **TK
`version.sqf:6` = `//#define IS_NAVAL_MAP` (commented)** → `IS_naval_map` is true on CH, false on TK.
This is a per-map file the mirror deliberately does not overwrite (same pattern as mission.sqm).

`Server\Init\Init_NavalHVT.sqf:28` (mirrored, identical text) exits **above** every `createVehicle`,
`getPos`, marker lookup, and the `waitUntil {townInit}` — on TK it logs one benign INFORMATION line
and stops. Defense-in-depth: even if bypassed, `:135-137` bails when the three "Khe Sanh" town logics
aren't found, and TK's mission.sqm has **zero** Khe Sanh logics (grep=0) → no position resolves to
`[0,0,0]` → nothing spawns at map origin. No other unconditional naval spawn path exists.

**SCUD nuance (important):** there are TWO SCUD systems. (a) **Carrier-SCUD is CH-only** (deck
launcher spawned by `Init_NavalHVT.sqf:337`; `Support_ScudStrike.sqf:38-45` needs an owned carrier
platform that never exists on TK → harmless deny). (b) **The land ICBM/SCUD TEL is map-agnostic and
TK GETS IT** — `Server\Init\Init_IcbmTel.sqf:82-92` spawns a `MAZ_543_SCUD_TK_EP1` TEL near each HQ
on SCUD research (`WFBE_UP_ICBM=11`), with NUKE / SATURATION / RECON / FASCAM / STEELRAIN / BUSTER
munitions (constants `Init_CommonConstants.sqf:803-827`, `WFBE_C_ICBM_TEL=1`). **So Takistan is not
SCUD-less — it has the land TEL, which is thematically ideal for the SCUD map.**

### PROPOSAL — TK land-HVT (action #5), effort-sized

The CH carrier HVT is a **capturable neutral (GUER-owned) objective on the normal town FSM** plus
per-HVT bonuses (air-shop, SCUD platform, proximity CAP). The capture-reaction core is map-agnostic
already — the ONLY CH-specific parts are sea math (`setPosASL`, `surfaceIsWater`, LHD hull,
`IS_naval_map`). A land version deletes those and keeps the town logic + tag +
`server_town.sqf:298-333` capture block.

- **S (~½ day) — SCUD-site land HVT.** Add one `LocationLogicDepot` "Rasman SCUD Site" to TK's
  mission.sqm; a tiny `Init_LandHVT.sqf` (gate `worldName=="takistan"`) that tags it and registers it
  in `WFBE_NAVAL_HVT_PLATFORMS`; reuse `Support_ScudStrike.sqf` unchanged (needs an owned platform,
  not literally a carrier) and the existing `server_town.sqf:300` capture block. Gives TK "own the
  site → launch a SCUD saturation strike" with almost no new code. **Recommended starting point.**
- **M (~2 days) — 3-HVT set** mirroring Alpha/Bravo/Charlie: Rasman air-shop HVT, mountain-fortress
  HVT (Loy Manara / Feruz Abad ridge), SCUD-site HVT. Port `Init_NavalHVT.sqf`'s air-shop wiring
  (`:458-481`) + a proximity-gated ground garrison (port CAP loop `:488-575`, swap Mi24_P/An2 for a
  Takistani garrison). Marker recolor + air-shop re-spawn on capture come free from
  `server_town.sqf:298-333`.
- **L (~4-5 days) — M + bespoke fortress geometry** (walkable HESCO/bunker statics at the mountain
  HVT), per-HVT reward tables, and AICOM awareness so the AI commander contests the HVTs.

Key anchors: gate `takistan\version.sqf:6` + `initJIPCompatible.sqf:15-18`; no-op guard
`Init_NavalHVT.sqf:28`; CH orchestrator `Init_NavalHVT.sqf` (tag `:215`, air-shop `:458-481`, SCUD
platform `:274-290`, CAP `:488-575`); **capture block to parallel `server_town.sqf:300`**; land TEL
`Init_IcbmTel.sqf:82-92`.

---

## LANE 4 — TK terrain-specific tuning opportunities

Takistan is steep (peaks ~2000 m), open, and has a sparser road net than Chernarus. The new movement
systems were tuned on Chernarus; here are the evidence-based TK opportunities (all via the existing
worldName-switch idiom):

1. **Recovery-v2 slope-snap `0.85` z** (`Init_CommonConstants.sqf:795`, action #3). z=cos(slope):
   0.85≈32°. On TK ridges this threshold is hit far more often than on Chernarus → either constant
   road-snapping of foot teams (jittery) or, if TK grades exceed the intent, too-late snapping. Branch
   per-world and measure the foot-snap rate on a TK soak. Pairs with `FOOT_ROAD_R=200` (`:796`) which
   should widen to ~250-300 on TK's sparse tracks.

2. **Careful-gear governor `SLOPE_Z=0.86`** (`Init_CommonConstants.sqf:1029`, action #3). Comment
   literally says tuned for "rolling Chernarus roads". 0.86≈31°; ordinary TK inclines exceed this and
   downshift convoys to LIMITED unnecessarily → slow AICOM transit across TK. Propose TK ~0.80 (≈37°)
   so only genuine steep grades throttle.

3. **Road-march lane offset vs narrow mountain roads** (`Common_BuildRoadRoute.sqf:52-54`, action #7).
   The perpendicular lane jitter (caller passes up to `wfbe_aicom_lanejit*120` m) pushes the mid-route
   guess sideways; on a Takistan switchback that guess can leave every road, the 250 m
   `WFBE_C_AICOM_ROUTE_SNAP_RADIUS` (`:305`) misses, and the node is dropped → the team beelines
   cross-country over a ridge. Propose a **tighter TK lane offset** (e.g. ×60 instead of ×120) and/or
   a **wider TK snap radius** (~350 m). The road-snap fix (w3k) helps but doesn't remove the sideways
   push before the snap.

4. **AI plane altitude 500 m on TK** (`Common_RunCommanderTeam.sqf:1009`). The map-aware floor is
   already TK=500 / CH=400 — good. But TK town elevations vary 0-1500 m; if `flyInHeight` is AGL the
   500 m clears ridgelines fine, if it's ASL a jet ordered to a high-elevation ridge town could fly
   *below* the terrain. **Verify the engine's `flyInHeight` reference frame on 1.64 here** and, if
   ASL, add the target town's ground elevation to the floor. (Marked NEEDS-VERIFY, not a confirmed
   bug — the comment claims height support is weak for planes on 1.64 anyway.)

5. **MHQ relocation in canyon terrain** (`AI_Commander_MHQReloc.sqf`). The reloc uses the same lenient
   `isFlatEmpty` gradient the commander uses for structures (`WFBE_C_STRUCTURES_FLAT_GRAD=2`,
   `Init_CommonConstants.sqf:1280`) — which was deliberately loosened cmdcon32 (0.5→2) *because* the
   strict value over-blocked on mountainous TK. So the reloc/deploy flat-gate is already TK-friendly.
   No change needed, but note: the player flat-check is DISABLED entirely on both maps
   (`WFBE_C_STRUCTURES_FLAT_CHECK=0`, `:1278`, cmdcon34) — a TK-tuned gradient could re-enable it for
   TK later (the comment invites exactly this).

6. **Town activation radii vs dispersed TK villages** — verified NOT a gap. Each town's range is a
   mission.sqm per-town parameter (3rd number in the `Init_Town.sqf` call). TK villages use 400-600 m,
   big towns 800-1200 m; CH villages use 100-300 m. **TK's town radii are genuinely hand-tuned for its
   dispersed compound geography — not a lazy CH-mirror.** Good as-is.

---

## LANE 5 — TK identity / content gaps (ranked)

What makes TK play blander than CH today:

1. **Airfield roster is the biggest gap** (action #4, `Init_Common.sqf:408-426`). CH airfields grant a
   5-aircraft generic pool (An2_TK, Mi17_Ins, Mi171Sh_rockets gunship, Su25_Ins, L159_ACR) **plus** a
   Balota-exclusive L-39. TK airfields (Rasman AF, Loy Manara AF) grant only **2** (An2_TK,
   Mi17_TK_EP1) and **no per-airfield special** — the `WFBE_AIRFIELD_UNITS_SPECIAL` list is keyed to
   `"Balota"`, which doesn't exist on TK, so both TK airfields resolve the bare generic list. Holding a
   TK airfield is a materially weaker prize. **Fix:** add TK-appropriate aircraft to the generic TK
   pool (e.g. a Mi-24 gunship variant, an Su-25 variant available on TK) and give Rasman/Loy Manara a
   signature per-airfield exclusive (mirror the L-39-at-Balota pattern). Low effort, high flavor.

2. **Town/airfield density** — 33 towns + 2 airfields vs CH's 46 + 3 (28% fewer capture nodes, one
   fewer airfield). Largely intrinsic to the map, but if TK rounds feel thin, a few additional
   capturable camps/objectives (or the land-HVT set from action #5) close the gap without needing more
   named settlements.

3. **No HVT objective on TK** — the entire carrier-HVT identity layer (capturable strongpoint with a
   payoff) is CH-only. Action #5's land-HVT (esp. the SCUD-site variant) is the direct remedy and
   plays to TK's canonical SCUD identity.

4. **TKGUE faction depth is fine** — Core_TKGUE 42 buy-list items vs Core_GUE 43 (parity); Core_TKA 79
   vs Core_RU 63 (TK Army is actually *deeper* than CH RU). GUER/Army rosters, defenses, and statics
   are at parity or better. Not a gap.

5. **Params default to CH** — `Rsc\Parameters.hpp` and `description.ext` are byte-identical CH↔TK, so
   every param default (economy, AI counts, town amount, starting distance) is CH-derived. Most are
   map-neutral, but `STARTING_DISTANCE` (action #9) is the one that reads differently on the smaller
   map. Any TK-specific default must be authored via a `worldName`-switch in a constants file, not in
   the shared Parameters.hpp.

6. **Positive TK-exclusive content already shipped** — Oilfields (build83, neutral capturable resource
   node, TK-only) and the land SCUD/ICBM TEL are genuine TK identity wins. Building on those (more
   TK-exclusive objectives) is a better direction than trying to make TK a Chernarus clone.

---

## Appendix — files that legitimately hand-differ CH↔TK (not gaps)

- `Server\Init\Init_Server.sqf` — 1 line: `CallDatabaseSetMap` arg `1`→`2` (CH=1, TK=2).
- `Server\Config\Config_GUE.sqf` — GUE_* → TK_GUE_*_EP1 garrison classnames (content).
- `Common\Config\Core_Artillery\Artillery_*.sqf` + TK-only `Artillery_TKA/TKGUE/US.sqf` — per-map
  faction artillery (content).
- `Client\GUI\GUI_Menu_Help.sqf` — map-specific help text.
- `version.sqf` — map defines (`IS_CHERNARUS_MAP_DEPENDENT`, `IS_NAVAL_MAP` off), maxplayers 55→61,
  mission name, terrain marker.
- `mission.sqm`, `loadScreen.jpg`, `texHeaders.bin`, `Textures/*_EP1/desert .paa` — per-map assets.

All other `.sqf` are byte-identical (mirror-maintained). Edit CH source only; run the LoadoutManager
mirror to propagate.

---

## IMPLEMENTED — cmdcon42-h TK polish batch (claude-gaming 2026-07-02)

Quick-win subset of the actions above. Items #1 (egress, codex #148), #4 (airfield roster) and
#5-audit (land-HVT) intentionally **not** in this batch (owned elsewhere / awaiting Ray). All edits
land on `claude/cmdcon42` (PR #143). CH `.sqf` edited then LoadoutManager-mirrored to TK; the three
`mission.sqm` edits are TK-only by nature (mirror skips `.sqm`; CH `.sqm` untouched).

### TK `mission.sqm` (surgery, re-parse verified — items #2/#6/#8)

- **Action #2 — TownMode presets 4→7.** Ported the three missing removal-set arrays into the TK
  `WF_Logic` init (id=26), keeping the existing entry structure (no new class Items, `class Groups
  items=98` unchanged). Semantics confirmed via `Parameters.hpp` texts + stringtable: the array LISTS
  THE TOWNS TO REMOVE ("No Big Towns" / "No central towns" / "No small towns"). TK town keys derived
  from the `LocationLogicDepot` Init_Town radii (size proxy). Picks:
  - `Towns_RemovedBigTowns` (value 5, "No Big Towns", removes 9 → keeps 22): the radius≥800 towns —
    `FeeruzAbad, LoyManara, Garmsar, Nagara, Rasman, ChakChak, Sakhee, Zavarak, Bastam`.
  - `Towns_RemovedCentralLine` (value 6, "No central towns", removes 10 → keeps 21): the populated
    central belt nearest map-centre (6400,6400) — `Anar, Falar, FeeruzAbad, Kakaru, Imarat, Bastam,
    Garmarud, Timurkalay, Sakhee, Gospandi`.
  - `Towns_RemovedSmallTowns` (value 7, "No small towns", removes 17 → keeps 14 big/medium): all
    radius≤500 villages — `Landay, Jaza, HazarBagh, Ravanay, Sultansafee, Chardarakht, Chaman,
    Jilavur, Khushab, Kakaru, Anar, Timurkalay, Imarat, Gospandi, Karachinar, Nur, Shamali`.
  - Ratios track CH (CH removes 26/33/37% of 46; TK 29/32/55% of 31). Re-parse: all 7 arrays present,
    init string quote-balanced (246 `""` pairs, even) + bracket-balanced (16/16), new arrays parse to
    9/10/17 entries, global brace balance 900/900.
- **Action #6 — `wfbe_skip_auto_hangar` on TK's 2 airports.** Prepended
  `this setVariable ["wfbe_skip_auto_hangar",true,true];` to both `LocationLogicAirport` inits
  (id=66 Loy Manara AF, id=78 Rasman AF), matching CH's 3-airport template. Count now 2 (was 0).
- **Action #8 — briefingName.** `"PR 8 - June Feature Bundle (Takistan)"` →
  `"Warfare V48 Takistan [GUER]"` and briefingDescription updated to CH's current RC blurb.

### CH `.sqf` constants → mirrored to TK (items #3/#7/#5-audit/#9)

All use the proven `if (isNil "X") then {X = if (worldName == "Takistan") then {A} else {B}}` idiom
(same as the live `WFBE_C_AICOM_ROAD_STANDOFF`) — the `isNil` guard keeps any pre-set param/flag
global as the override; the per-world value applies only when unset.

- **Action #3 — slope constants** (`Init_CommonConstants.sqf`):
  `WFBE_C_AICOM_SLOPE_Z` CH 0.86 / **TK 0.80** (~37°; ordinary TK inclines exceed 0.86 and over-throttle
  convoys); `WFBE_C_AICOM_RECOVERY_SLOPE_Z` CH 0.85 / **TK 0.80**; `WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R`
  CH 200 / **TK 300** (sparser TK road net → wider snap search).
- **Action #7 — TEL range** (`Init_CommonConstants.sqf`): `WFBE_C_ICBM_TEL_RANGE` CH 10350 / **TK 8240**
  (Ray's pick; 0.644 of TK width vs the map-spanning 0.81 the CH value would give). Flag override wins.
- **Action #7-audit (Lane 4 #3) — lane offset** (`Common_BuildRoadRoute.sqf` + 3 callers): factored
  the hardcoded `laneJit * 120` into a new worldName-aware constant `WFBE_C_AICOM_LANE_OFFSET`
  (`Init_CommonConstants.sqf`): CH 120 / **TK 60** (narrow TK switchbacks — a 120 m perpendicular guess
  leaves the road, the snap misses, team beelines over a ridge). Callers `AI_Commander_AssignTowns.sqf`
  and `AI_Commander_Execute.sqf` (×2) now read the constant.
- **Action #9 — STARTING_DISTANCE** (`initJIPCompatible.sqf`): `STARTING_DISTANCE` is a compile-time
  `#define` in the gitignored per-map `version.sqf` (7500 both maps), so the value can't live in-repo
  there. Instead the consumer resolves per-world: `startingDistance` stays `STARTING_DISTANCE`, then on
  Takistan (and only when the define is still its 7500 default, so a deploy-time override still wins)
  `startingDistance = 6300` (0.49 of TK width = CH-ratio parity → more legal spawn pairs).

Bracket delta per changed file: **(0,0,0)** on all 11 files. All 5 edited `.sqf` are CH↔TK
content-identical post-mirror.
