# ARCHIVE MINING — Miksuu Drive + Jerry bIdentify (code ideas & mod candidates)

**Date:** 2026-07-02 · **Scope:** READ-ONLY research. Nothing in any repo or on the box was changed.
**For:** WASP Warfare — heavily-modified **Warfare BE 2.073** fork, Arma 2 OA **1.64** dedicated + 2 HCs, vanilla CO + `@CBA_CO` server-side.
**House rules honored:** no ACR content proposed; no sim-/distance-gating of AI proposed.

## How this doc relates to the existing design docs (READ FIRST — avoids duplication)

`docs/design/OPTIONAL-CLIENT-MODS.md` **already owns two lanes** and this doc does **not** re-derive them:
- The **client-optional pack** lane (JSRS 1.5, Blastcore R1.2, STHUD, JTD id 1935) + the `@wasp_optional` build/sign/deploy architecture.
- The **AI-behaviour-mod handoff** table (ASR AI 3, Zeus AI, TPWCAS, GL4, SLX, bCombat, UPSMON) — framed there as *server/HC-side* handoffs, correctly.
- That doc's **§(f) "Miksuu Drive inventory" section explicitly says the Drive was NOT reachable** from a prior attempt ("a real file-by-file Drive listing cannot be produced from this machine").

**What THIS doc adds that those docs do not have:**
1. The **actual, extracted Drive inventory** (4,210 archives, categorized) — filling the gap §(f) left open. The Drive *was* reachable this run via Ray's `embeddedfolderview` link.
2. **Code-idea mining from real unpacked source** — the CTI/Warfare **ancestry** (Warfare-BE-1.6 "Oden", crCTI, mcti), plus DAC / VFAI / RUG DSAI / R3F behaviours. `OPTIONAL-CLIENT-MODS.md` never opened any source; it only listed mod names.
3. **Additional client-side candidates** that doc missed (PROPER FPS-reduction suite, IHUD, foldmap, FOV, minimal crosshair, RCon admin tools).
4. The **Jerry bIdentify** server-side/CTI/player-side findings.

Where a mod already appears in `OPTIONAL-CLIENT-MODS.md`, this doc cross-references rather than re-proposes (e.g. ASR AI 3 is already live in `@adwasp`; Zeus/TPWCAS/GL4 are already handed off).

---

# 1. MIKSUU DRIVE INVENTORY

**Source:** Ray's link `https://drive.google.com/…/embeddedfolderview?id=1saZFKkhygT3DuG9lFkXzmcYC4rQ6lFNM` — renders a plain HTML file list; fetched the 3 MB raw HTML and parsed **4,210 entries**.

**Shape of the Drive:** it is **not** a curated Miksuu working folder — it is a **flat mirror of the entire classic Armaholic / armedassault.info addon catalog**: 4,210 files, **all `*_WithPW.7z`** (password `armedassault`), all mime `x-7z-compressed`, **no subfolders**, last-modified 2024-07-11. Each outer `.7z` (password-protected) wraps **one inner archive** (`.zip` / `.rar` / `.7z`, **no password**) which holds the actual `@mod` / mission `.pbo` / tool. So extraction is a **two-step** de-archive.

> Full parsed index (id → filename, 4,210 rows) saved to scratchpad `archive-mining/miksuu_index.tsv` for future lookups. Download helper (handles the Google confirm-token dance) at `archive-mining/gdl.sh`; a minimal pure-Python **PBO extractor** at `archive-mining/depbo.py` (7-Zip cannot read `.pbo`).

## 1a. Category counts (of the 4,210)

| Bucket | ~count | Notes |
|---|---|---|
| Warfare / CTI missions | ~26 | Oden Warfare (=**Warfare BE 1.6** lineage, 7 map reskins × versions), crCTI, mcti r6–r9, cti_doolittle, @Proman, HiFiFX+Warfare |
| AI / behaviour mods | ~60 | ASR AI (1.7→1.15.1), VFAI (v15→v26), RUG DSAI, TPWC AI SUPPRESS (101→304), TPW AI LOS, GroupLink II Plus, Zeus AI (zeu_cfg_core_ai_skills 1.02→1.04), Blakes AI FO, glt_dynamic_ai, PROPER AI test fw |
| Mission frameworks / packs | ~74 | Domination (DomiA2 1.09→2.02), Insurgency, MSO 4.x, Evolution, GITS Evo, F3-adjacent, many coop packs |
| Dynamic-spawn / garrison | DAC V2 & **V3**, UPSMON5, SilentRescue, LHD_Spawner, SimpleVehicleRespawn | zone-based AI directors |
| ACE / ACEX (all versions) | ~80 | **OUT of scope** (total conversion, gameplay) — listed only so they aren't re-mined |
| SLX suite | ~12 | AI steering/wounding/hit-effects; Ray already flagged "extraction complexity > gain" |
| Artillery / support / CAS | ~15 | R3F Arty&Log, RealMortars, Real_artillery_2, Mando Missile, FAC, Viper/VIP arty |
| Revive / medical | ~9 | ADO_Revive (1.3→1.52), R3F_revive, Farooq-adjacent |
| Admin / RCon | ~3 | ArmA2 RCon 1.2 / 1.3 |
| Tools | ~47 | Eliteness, PboView, worldtools, editor updates, string-table editor |
| Client visual/HUD/QoL | many | **PROPER** suite (vegetation/clutter/shader removal = client FPS), @IHUD, @tao_foldmap, @unafov, AircraftHUD, minimal/colour crosshair |
| Units / weapons / islands / skins | the rest (~3,900) | the bulk — content variety, not code/mod-of-interest for this task |

**Notably ABSENT (expected):** VCOM AI, GAIA, bCombat-for-A3, LAMBS — these are Arma-3-era; their absence confirms the mirror is A1/A2-vintage. (bCombat *does* exist for A2 and is already in the handoff table; it did not surface under my keyword sweep of this mirror, so treat it as "on bIdentify, not confirmed in this Drive.")

## 1b. Items pulled + extracted this run (top 12, prioritized) and their value

All downloaded to `archive-mining/dl/`, extracted to `archive-mining/ex2/` (and CTI PBOs to `archive-mining/pbo/`). Sizes = outer `.7z`.

| # | Drive filename | Drive id | Size | What's inside | Value to us |
|---|---|---|---|---|---|
| 1 | `@zeu_cfg_core_ai_skills_v1.04_WithPW.7z` | `1DjYq717khlDCExDDU8Tu2sLpGlXs4Wpa` | 25 KB | `@zcommon/Addons/zeu_cfg_core_ai_{skills,spotting,sensors}.pbo` (+experimental engagement), signed `ZEU.bikey` | **Config-only AI skills mod** (patches `CfgAISkill`/unit skill via config, *no scripts, no EH*). Already handed off in `OPTIONAL-CLIENT-MODS.md §(g)`. **HC note below.** |
| 2 | `asr_ai-1.15.1_WithPW.7z` | `1c7cAZyA0p1L1wqN0sopoufQmH--KFscz` | 55 KB | `@ASR_AI/addons/*` (skill/sensors/rof/rearming/dispersion), `userconfig/ASR_AI/asr_ai_settings.hpp`, signed | **Live already** (v1.16 in `@adwasp`). This is the older **1.x** line; the `asr_ai_settings.hpp` here is a clean reference for tuning knobs (see Code Ideas). |
| 3 | `VFAI_ProjectV26_WithPW.7z` | `1sDVaV3yNvSSUz84aaNlw5fy8Z0QS670G` | 188 KB | `VFAI_Project/Addons/VFAI_{Equipment,Smokeshell,ControlPanel}.pbo`, signed `VICFA.bikey` | Script-based infantry AI: **auto-equip from battlefield, throw smoke when hit, drop empty weapons**, per-group action-menu toggle. Lighter/older analog to ASR rearming. Code idea below. |
| 4 | `crcti_mpmissions_WithPW.7z` | `1Ds0Yp--AOp0oL3UZhBb_dDrY7AFZhrg2` | 1.7 MB | `crcti_WARFARE_03.{Chernarus,utes}.pbo` (528 files unpacked) | **Different CTI lineage** (CRC/Mando). Distinct victory model (hold-towns countdown), param bitmask trick, group-order dialogs. |
| 5 | `mcti_r9_40vs40.Chernarus_WithPW.7z` | `1Pup6QbLoBXQFqzo_ZfPR5Aw9UikQnhl6` | 117 KB | `mcti_r9_40vs40.Chernarus.pbo` (160 files) | **Compact modern A2 CTI** (McArcher). Clean single-file `mca_ai_commander.sqf`; uses R3F artillery quarters + radio-terminal captures. Contrast only (JIP-unsafe `SetVehicleInit`). |
| 6 | `DAC_V3_WithPW.7z` | `1LC612ch5KnNKb0kLkYuUH1dZP8XZZs0b` | 8.2 MB | `@DAC/Addons/DAC_{Source,Sounds}.pbo` + **raw** `Configs/DAC/*.sqf` + 33-part ENG demo | Silola's **Dynamic-AI-Creator**: zone spawn director with parameterized behaviour/waypoint/camp/artillery tables (readable SQF). Refinement ideas for patrols/garrison. |
| 7 | `ArmA_GroupLink_II_Plus!_v.1.0_WithPW.7z` | `1YwuL-YV_ESxjM9_E43nRyzgTm5nTrzF2` | 3.1 MB | `GL2Plus.pbo` + full **mission-embedded `.sqs`** source tree | 2007 =\SNKMAN/= ArmA1 dynamic reinforcement/reaction + dynamic-voice + first-aid. **Ancestor of GL4** (already handed off). `.sqs` + A1 classes = high port cost; reference only. |
| 8 | `RUG_DSAI_WithPW.7z` | `1CKkVlubAzNnYC_5KJpbvb3mZS3w0WQzp` | 36 MB | `RUG_DSAI*.pbo` (EN/RU/ES/AR voice packs) + readme, signed | **Cosmetic only** — AI shout/curse/reload/grenade voices, XEH-driven, SP+MP-sync. Big (sound). Low priority; a "flavour" client/server option. |
| 9 | `TPW_AI_LOS_102_WithPW.7z` | `1jRptRbZz7A_mlo6Xh1QDQK-GVn1plQpk` | 8.7 KB | `@TPW_AI_LOS/tpw_ai_los102.sqf` (raw) + hpp | Per-unit LOS/foliage occlusion gate for *knowsAbout*. **Borders on sim-gating** (caps detection by distance/LOS) → against house rules; do not port. Noted for completeness. |
| 10 | `R3F_Arty_and_Log_1.3_WithPW.7z` | `1wOVC7Qxgose8_W75qPXyonh2JTnCV-cT` | 340 KB | `R3F_Arty_and_Log_1.3/` mission-script system (90 files), **GPLv3** | Deployable **manual-artillery computer + object load/tow/lift logistics**. GPL (attribution/copyleft caveat). Logistics-carry is a distinct QoL mechanic. |
| 11 | `Oden Warfare Pack 1.05h_WithPW.7z` | `1dXzvW0aYW7KyTk7pzvcKj-M7UW3sh9el` | 369 KB | `*105hWarfare16.<map>.pbo` × 7 maps × 4 faction reskins (Civ/Cold/PLA/Swe) | **THE ancestry find.** `*Warfare16` = **Warfare BE 1.6-era** with the *identical* `Server/AI/Commander/` file layout as WASP. Direct baseline to diff AICOM against. See Code Ideas §2. |
| 12 | `glt_dynamic_ai_1.4_WithPW.7z` | `1rB-gzqnUdVHfVkRtRqvG1fFt-GmbrmLF` | 190 KB | `gltdynamicai.pbo` + 1.33 PDFs + example.utes | GLT dynamic spawn/patrol director (addon form). Overlaps DAC; PDF docs only shipped (pbo binarized). Reference. |

> **Not pulled but flagged for a future run** (higher-value duplicates to diff): `mcti_r6/r7/r8` (CTI evolution deltas), `DomiA2_2_02` (Domination's mission-generation + caching model), `cti_doolittle_b22`, `ADO_Revive_1.52` (if a revive lane is ever wanted), the `PROPER` client suite (FPS-reduction addons for weak clients — see §3).

---

# 2. CODE IDEAS (concrete mechanics worth porting)

Excludes what WASP already has per the brief (road marches, garrison sorties, road patrols, TPWCAS suppression, recovery v2, SCUD/TEL, territorial victory). Each item: **source · what it does · A2-OA-1.64 fit · effort · license.**

## Tier A — from the Warfare-BE-1.6 ancestor ("Oden Warfare16") — highest fit (same architecture as WASP)

**A1. Revive the two *stubbed* commander economy behaviours: Supply-Truck runs and Salvager.** ⭐ top pick
- **Source:** `pbo/oden_wf16/Server/AI/Commander/Commander_SupplyTruckAction.sqf` and `Commander_SalvagerAction.sqf`. In `Commander_StrategicUpdate.sqf` both are `Compile PreprocessFile`'d but tagged **`//theOden (not used :-)`** — they were built (8/2009) then never wired into the BE commander loop.
  - *SupplyTruck:* if working AI supply trucks `< MAXAISUPPLYTRUCKS`, roll a chance `= (townsHeld/10 + (max-working)/max)*100`, spawn `<sideLetter>SUPPLYTRUCK` + driver at base, hand to `BIS_WF_UpdateSupplyTruckAI` (drives supply between depot/factories → income/logistics).
  - *Salvager:* keep `MAXAISALVAGERS` salvage trucks alive; `BIS_WF_UpdateSalvagerAI` collects battlefield wrecks → supply.
- **What it gives WASP:** two *ancestral, side-symmetric* economy sub-behaviours the AI commander can run — a self-refilling **logistics loop** and a **battlefield-salvage income** stream, both tied to towns-held (natural catch-up pressure). Novel vs WASP's current commander.
- **A2 fit:** pure A2-native commands (`createVehicle`, `MoveInDriver`, `CreateGroup`, `Spawn`) — **no A3-isms**. Depends on `<side>SUPPLYTRUCK`/`SALVAGETRUCK`/`SOLDIER` class macros + `BIS_WF_Update*AI` handlers; WASP has the same `GetSideLetter`/`WFSideText`/`BIS_WF_InitUnit` scaffolding, so the port is mostly re-supplying those two `Update*AI` bodies (may need writing/finishing).
- **Effort:** **M** (behaviour bodies must be completed; the spawn/gate logic is done). **License:** BIS Warfare sample lineage (same provenance as WASP itself).

**A2. Centroid "Area of Influence" + "Expeditionary Hostile Location" targeting.**
- **Source:** `Commander_StrategicUpdate.sqf` (medium-update block): averages living team-leader positions into `<side>AverageAreaOfInfluence`, then `GetClosestHostileLocation` from that centroid → `<side>ExpeditionaryHostileLocations`. A cheap **front-line follows your own mass** heuristic for choosing the next attack target.
- **A2 fit:** trivial vector math, A2-native. **Effort:** **S**. Good if WASP's target-town pick is currently HQ-radial rather than front-relative. **License:** as above.

**A3. "Island index" → auto air-assault when target is on a different landmass.** ⭐ novel
- **Source:** `pbo/oden_wf16/Oden/airAssault.sqf` + `Oden/fnBuildAirsupport.sqf`, gated in `Server/AI/Team/Team_Update.sqf`. Each town carries a manually-authored **island/landmass index** (editor/map-config, not auto-detected). When an AI team's current town and its target town have **different island indices**, the team routes via **air-assault insertion** (`airAssault`) instead of a ground march.
- **Value:** WASP's AI marches are road-routed — which strands teams when the objective is across water / on a separate landmass (a real problem on archipelago maps). A per-town island tag + "different island ⇒ fly/insert" gate is a **clean, portable** fix and genuinely novel vs WASP's current pathing. **A2 fit:** native (config int per town + a branch in team-update). **Effort:** **M** (needs per-town island tagging on each WASP map + the air-insertion branch). **License:** BIS Warfare lineage.

**A4. Town-defense placement + patrol-generation heuristics (BE-1.6 baseline).**
- **Source:** `Server/AI/Commander/Commander_BuildTownDefenses.sqf`, `Server/Server_UpdateTownPatrols.sqf`, `Server/AI/Team/Team_FindFactoriesAction.sqf`, `Server/Functions/Server_AITeamFastTravel.sqf`.
- **Value:** a clean **diffable baseline** for the exact systems WASP has heavily rewritten — useful to spot where WASP diverged (per memory: AICOM is OURS-ONLY vs upstream, so this 1.6 layer is the closest thing to a baseline). Mine for any placement/patrol logic WASP dropped. **Effort:** review-only (**S** to extract a specific idea). **License:** BIS Warfare.

## Tier B — infantry-behaviour mods (script-portable)

**B1. VFAI "throw smoke when hit" + "drop empty weapon" + "auto-equip from field".**
- **Source:** `ex2/vfai/VFAI_Project/Addons/VFAI_{Smokeshell,Equipment,ControlPanel}.pbo` (readmes: `Smokeshell.Readme.txt`, `Equipment.Readme.txt`, `ControlPanel.Readme.txt`; PBOs binarized — logic described in readmes, re-implementable). By VictorFarbau, 2009.
  - Smokeshell: unit throws a `SmokeShell` on taking a hit (self-concealment) — a small survivability tweak.
  - Equipment: units scavenge weapons/ammo from crates/vehicles/dead — *narrower* than ASR's rearming (WASP's ASR AI 3 already covers this globally, so **Equipment is redundant**).
  - ControlPanel: per-group leader action-menu to toggle these live.
- **A2 fit:** yes (XEH/EH-based). **Effort:** **S** for the smoke-when-hit tweak alone (a few lines on a `HandleDamage`/`Hit` EH). **License:** freeware, attribute VictorFarbau. **Redundancy:** don't port Equipment (ASR covers it); the *smoke-when-hit* is the only non-redundant bit, and ASR's `throwsmoke` option (see B2) may already cover even that.

**B2. ASR AI `asr_ai_settings.hpp` — the tuning reference (already live, mine the knobs).**
- **Source:** `ex2/asr_ai/asr_ai-1.15.1/userconfig/ASR_AI/asr_ai_settings.hpp`. Confirms exact levers WASP's live `@adwasp` ASR can set: `radionet`/`radiorange` (AI share enemy positions over radio — **note: SP+server only, NOT dedicated-client AI**), `gunshothearing`, `buildingSearching`+`buildingSearchingAlwaysUp` (house-clearing), `throwsmoke`, `join_loners` (merge single survivors into nearest group — **directly relevant to WASP's "starved-infantry"/lone-unit tidiness**), `stayLow`, `split_legged` (a slow/immobile unit self-detaches so it doesn't drag its group — relevant to WASP's frozen/stuck-team concerns), per-unit-type `class sets` skill bands.
- **A2 fit:** already running. **Effort:** **S** (config tuning, no code). **Value:** `join_loners` + `split_legged` map onto known WASP pain points (lone/stuck AI) — worth explicitly enabling/tuning. **License:** Robalo, non-commercial; already in use.

## Tier C — CTI-lineage mechanics (contrast / selective)

**C1. crCTI "hold-towns → countdown-to-victory" timer.**
- **Source:** `pbo/crcti_cher/Player/Info/TimeUntilTownWin.sqs` (+ the town-win driver it reports). Once a side dominates towns, a **minutes-to-win countdown** starts and is shown to players ("Town Win in N minutes") — an **endgame-pressure** mechanic distinct from WASP's territorial victory (which is state-based, not a forced countdown).
- **Value:** optional *tension* layer — dominating a majority of towns arms a losing-clock, discouraging turtling and shortening stalemates. **A2 fit:** trivial. **Effort:** **S–M** (a server timer + a client HUD line). **License:** crCTI (community CTI; attribute).

**C2. crCTI compact param bitmask (StartPos·10 + StartMoney/Time).**
- **Source:** `pbo/crcti_cher/description.ext` `titleParam1`/`valuesParam1` — encodes 3 setup axes into one lobby param via `pos*10 + variant`. A tidy trick if WASP ever runs short on lobby param slots. **Effort:** **S**. Minor.

**C3. mcti commander "narrates each build to command chat."**
- **Source:** `pbo/mcti_r9/mca_ai_commander.sqf` (`_me commandChat "Building Aircraft Factory..."` etc.). UX flavour: the AI commander announces its construction decisions. **Caveat:** the surrounding file uses **`SetVehicleInit`/`ProcessInitCommands`** for building init — a **JIP-unsafe** pattern WASP's memory explicitly warns against; take only the *narration idea*, not the mechanism. **Effort:** **S**. **License:** McArcher (community).

## Tier D — dynamic-AI-director refinements (overlaps existing WASP systems — refine, don't adopt wholesale)

**D1. DAC terrain-aware waypoint validation for patrols.**
- **Source:** `ex2/dac_v3/Configs/DAC/DAC_Config_Waypoints.sqf` — per **unit-class** (Sol/Veh/Tan/Air/Camp) waypoint placement uses slope/height checks (`_checkAreaH`, `_checkMinH/MaxH`, `_checkObjH1/2`, `_checkResol`) so patrol nodes aren't placed on cliffs/roofs/water. `DAC_Config_Behaviour.sqf` similarly parameterizes skill/combat/behaviour/formation/**fleeing**/**building-search**/**support**/**hide-time** per behaviour level.
- **Value:** WASP already has road patrols; DAC's **off-road terrain validation** and its **per-level behaviour tables** (esp. `_setFleeing`, `_setBldgBeh`, `_setHidTime`) are a source of *tuning* ideas for garrison/patrol AI, not a new system. **A2 fit:** native SQF. **Effort:** **S** to lift a validation snippet; **L** to adopt DAC wholesale (don't). **License:** Silola/DAC (freeware, attribute; non-commercial).

**D2. R3F object load/tow/lift logistics (player QoL).**
- **Source:** `ex2/r3f_artylog/R3F_Arty_and_Log_1.3/` (mission-script). Players **load ammo crates/objects into trucks, tow vehicles, sling-lift** via action menu — a logistics-carry layer WASP's build-menu economy doesn't cover. **A2 fit:** yes (mission scripts). **Effort:** **M**. **License:** **GPLv3** (madbull/R3F) — *copyleft*: folding it into the mission is legal but obligates GPL terms on the distributed mission; **flag for Ray** before adoption. Its *manual-artillery computer* overlaps WASP's arty and is not needed.

## Tier E — server/HC code-idea mines from bIdentify (SQF sources to read, NOT mods to ship)

These are the highest-value *net-new* mechanics from the bIdentify sweep (full ids/sizes in §4a). All run where AI is local → **the 2 HCs** for WASP.

**E1. HETMAN Artificial Commander — commander-level heuristics.** ⭐
- **Source:** bIdentify `4220 HAC_v1.47.7z` (Rydygier; ~4 MB of readable SQF). A full whole-side field commander: threat assessment, force allocation, order dispatch, objective prioritization.
- **Value:** WASP's AICOM is **OURS-ONLY with no upstream baseline** (per memory `wasp-baseline-lineage-recon`) — HETMAN is the single best external body of *commander-AI* logic to mine for target-selection / force-allocation ideas. **Do NOT run it** (it would compete with AICOM). **A2 fit:** native A2 SQF. **Effort:** **M** to extract a discrete heuristic. **License:** Rydygier, community (attribute; check terms before copying verbatim).

**E2. AI-led artillery (commander calls indirect fire).**
- **Source:** bIdentify `4234 RYD_FAW1.31.zip` ("Fire At Will", Rydygier). An AI battery autonomously selects targets and fires indirect.
- **Value:** distinct from WASP's SCUD/TEL — gives **AICOM a fire-support arm** (call arty on a contested town). Pairs with the Oden supply/salvager economy (A1) for a richer commander. **A2 fit:** native. **Effort:** **M**. **License:** community.

**E3. AI helicopter tasking (insertion / extraction / landing).**
- **Source:** bIdentify `4198 Ai-Heli-Control-version-1.3.7z`.
- **Value:** directly feeds WASP's **cmdcon heli-guard** lane — reliable AI-heli landing/insertion is a known Arma-2 pain point. Helis are HC-crewed → HC-local. **A2 fit:** native. **Effort:** **M**. **License:** community.

**E4. Runtime AI-skill control for the war-room console.**
- **Source:** bIdentify `4201 JED_ESS_V1.7.rar` (Enhanced Skills Slider) — set a side/group/unit's `skill` live.
- **Value:** WASP's war-room already has direct Move/Patrol/Defend; a **live difficulty knob** (bump/drop AI skill mid-match) is a natural, low-risk console addition. **A2 fit:** `unit setSkill […]` is A2-native. **Effort:** **S–M**. **License:** community.

## Explicitly NOT proposed (against house rules / redundant / low-fit)
- **TPW AI LOS** (`tpw_ai_los102.sqf`) — caps `knowsAbout` by distance/LOS = **sim-gating** → violates the no-gating rule.
- **GroupLink II Plus** — 2007 `.sqs`, ArmA1 classes; superseded by GL4 (already handed off). Port cost ≫ gain.
- **RUG DSAI**, **SLX**, **ACE/ACEX**, **Blakes AI FO**, **glt_dynamic_ai** — cosmetic (DSAI), "extraction > gain" (SLX, Ray's call), total-conversion (ACE), or DAC-overlap (glt).

---

# 3. MOD CANDIDATES

## 3a. Server-side (⚠ HC-locality: WASP runs AI on **2 headless clients** — an AI addon only affects units **local to the machine it's loaded on**)

**The HC rule that governs every AI-addon verdict here:** ASR AI, Zeus AI, VFAI, RUG DSAI all state *"configures only the AI local to the machine where it is installed."* On WASP, **most AI is owned by the two HCs**, so a *config/CfgAISkill* mod (Zeus) or a *script/EH* mod (ASR, VFAI) must be loaded on **the HCs (and ideally the server)** — **not** just the server — to affect the AI players actually fight. Loading it server-only leaves HC-owned AI unmodified. `OPTIONAL-CLIENT-MODS.md §(g)` frames these as server-side; the **precise** requirement is **server + both HCs**.

| Mod | Drive filename / bIdentify | Signed? | Size (outer .7z) | Verdict (HC-aware) |
|---|---|---|---|---|
| **ASR AI 1.15.1** | `asr_ai-1.15.1_WithPW.7z` (`1c7cAZ…`) | yes (`asr_ai.bikey`) | 55 KB | **Already live** as v1.16 in `@adwasp`. This older build only useful as an `asr_ai_settings.hpp` reference (§B2). Must run on **HCs+server**. No new action. |
| **Zeus AI Combat Skills 1.04** | `@zeu_cfg_core_ai_skills_v1.04_WithPW.7z` (`1DjYq7…`) | yes (`ZEU.bikey`) | 25 KB | **Config-only** (`CfgAISkill`/unit-skill patch, no scripts). Already handed off. Because it is *config*, it changes AI on **whatever machine loads it** → needs HCs+server. Stacks with ASR but **overlaps** it (both set skills) → pick one or tune carefully. |
| **VFAI Project v26** | `VFAI_ProjectV26_WithPW.7z` (`1sDVaV…`) | yes (`VICFA.bikey`) | 188 KB | Script/EH infantry AI (auto-equip, smoke-when-hit, drop-empty). **Mostly redundant** with ASR's rearming+`throwsmoke`. Only the *smoke-when-hit* + *drop-empty* are non-redundant, and are cheaper to re-implement mission-side (§B1) than to add another signed addon to all 3 machines. **Verdict: mine the idea, don't ship the mod.** |
| **RUG DSAI** | `RUG_DSAI_WithPW.7z` (`1CKkVl…`) | yes (`RUG_DSAI.bikey`) | 36 MB | **Cosmetic AI voices** only. XEH-driven, SP+MP-sync. If shipped, needs HCs (AI is local there) + clients to hear synced. 36 MB for flavour → **low priority**; a "spice" option at most. |
| **ArmA2 RCon 1.2 / 1.3** | `arma2rcon1.3_WithPW.7z`, `ArmA2_RCon_1.2_WithPW.7z` | (tool) | small | Standalone **BattlEye RCon admin client** (kick/ban/say/exec). WASP box currently runs `BattlEye=0` (per `OPTIONAL-CLIENT-MODS.md` appendix) → **inert unless BE is enabled**. Note only. |
| **GroupLink II Plus / SLX / ACE** | (various) | mixed | — | **Not recommended** (see §2 exclusions). |

> **No dedicated AI-*aviation*/pathfinding addon exists in this Drive** (confirmed by keyword sweep) — matching `OPTIONAL-CLIENT-MODS.md §(g)`'s conclusion that AI-air-crash/pathing is a *mission-side* FSM problem (EASA / AICOM-AIRCRAFT), not something an off-the-shelf A2 addon fixes.

## 3b. Optional player-side (NEW candidates not in `OPTIONAL-CLIENT-MODS.md`)

`OPTIONAL-CLIENT-MODS.md` already covers JSRS/Blastcore/STHUD/JTD. These are **additional** client-only candidates surfaced by the Drive sweep (verify exact bIdentify ids at pull time):

| Mod | Drive filename | Signed? | Size | Verdict (client-only) |
|---|---|---|---|---|
| **PROPER suite** (VegetationReplacement / clutter / shader-removal) | `@PROPER_VegetationReplacement_BETA3_WithPW.7z`, `proper_shaders_removed…`, `proper_r_…clutter…` | some signed | small–med | **Client FPS-reduction** pack: strips heavy foliage/clutter/shaders for players on weak rigs. Pure client visual → in-scope, no server impact. **Best new addition to `@wasp_optional`** for low-end players (complements Blastcore's low-FX note). Caveat: reduces visual parity; make it opt-in. |
| **@IHUD** (infantry HUD) | `@IHUD_WithPW.7z` | check | small | Minimal ammo/stance HUD overlay. Client-local. Candidate alongside STHUD. Verify it doesn't touch gameplay. |
| **@tao_foldmap** | `@tao_foldmap_a3-2.1_WithPW.7z` | check | small | On-screen foldable mini-map (TAO). *Filename says `a3`* → **verify A2-OA compatibility before proposing** (may be an A3 build). |
| **@unafov** (FOV changer) | `@unafov_WithPW.7z` | check | tiny | Adjusts field-of-view. Client-local config. Popular QoL. Verify 1.64 compat. |
| **Minimal / colour crosshair** | `afp_MinimalCrosshair_v102_WithPW.7z`, `Color_CrossHair_WithPW.7z` | check | tiny | Cosmetic crosshair tweaks. Client-local. Minor QoL. |
| **AircraftHUD v4** | `AircraftHUD_v4_WithPW.7z` | check | small | Extra cockpit HUD for planes. Client-local; niche (WASP has aircraft). Verify no config-class collision. |

> **Process note:** every player-side candidate above needs the same treatment `OPTIONAL-CLIENT-MODS.md` prescribes — confirm on bIdentify, `bisign2bikey` if needed, fold into the curated `@wasp_optional` pack (Model A), and smoke-test one-with/one-without. The **PROPER FPS pack** is the standout because it targets Ray's recurring perf concern from the *client* side (nothing else in the optional list helps weak-rig FPS).

---

# 4. JERRY bIDENTIFY FINDINGS

**Index shape:** three trees (`Arma`, `Arma2`, `Arma2 OA`) at `/files/arma[2][oa]`; leaf-folder pages render per-file rows; detail pages at `/file/<id>`. **Two caveats from the sweep:** (1) bIdentify shows **no bikey/bisign field** on any page — it mirrors Armaholic *metadata*, not signatures, so every "signed?" below is **inferred from packaging convention → verify before deploy**; (2) many entries are **metadata-only ("MIA", no download)** — fine here since we mine for *ideas*. Ranges covered: `arma2oa/addons/misc` (4152–4266 full), `arma2oa/addons/units` (4385–4551, all cosmetic reskins → skipped), and the warfare/CTI/domination/AAS leaf buckets for both trees.

## 4a. Server-side candidates & code-idea mines (bIdentify) — HC-locality applies as in §3a

`id | filename | signed? | size | verdict`

1. **`4170` | `ASR-AI-Addons-v1162.7z` | assume signed (Robalo) — verify | 58 KB | TOP.** Canonical A2 AI-skill mod (= the `@adwasp` ASR line, v1.16.2). Combat FSMs run **wherever the group is local → your 2 HCs**, so deploy = **server + both HCs**. Count-neutral, non-gating (house-rule-safe). *Already live for WASP; listed as the bIdentify anchor.*
2. **`4212` | `tpwcas5.51.zip` | assume unsigned script-addon — verify | MIA | HIGH.** TPWCAS (ollem) suppression — "SP, MP & Dedicated compatible." **Already in WASP** (TPWCAS is folded per the brief) — id recorded for provenance; the 5.51 build is a newer reference than most.
3. **`4220` | `HAC_v1.47.7z` | unsigned framework PBO | 4 MB | HIGH — code-idea, NOT deploy.** ⭐ **HETMAN Artificial Commander** (Rydygier) — a whole-side field-commander AI (plans, allocates forces, dispatches orders). **Directly parallel to WASP's OURS-ONLY AICOM.** Do **not** ship (it would fight our commander), but it is the richest SQF source in the index for **commander-level target-selection / force-allocation / order-dispatch** heuristics. Effort to mine an idea: **M**. Provenance-diff value: high, since AICOM has no upstream baseline.
4. **`4234` | `RYD_FAW1.31.zip` | unsigned | MIA | MEDIUM — code-idea.** ⭐ **"Fire At Will"** (Rydygier) — functional **AI-led artillery** (an AI battery decides & fires indirect). WASP has SCUD/TEL munitions but a *commander-driven AI artillery call* is a distinct capability AICOM could gain. Server/HC-side. Effort **M**.
5. **`4198` | `Ai-Heli-Control-version-1.3.7z` | unsigned | MIA | MEDIUM — code-idea.** ⭐ Control of AI helicopters (tasking/landing/insertion). **Directly relevant to WASP's cmdcon heli-guard lane.** Helis are HC-crewed → HC-local patterns. Mine for AI-heli insertion/extraction/landing logic. Effort **M**.
6. **`4201` | `JED_ESS_V1.7.rar` | assume unsigned | 629 KB | MEDIUM — code-idea for war-room.** **Enhanced Skills Slider** — change a side/group/unit's skill **at runtime**. WASP's war-room console already does direct Move/Patrol/Defend; a **runtime AI-skill knob** is a natural console addition. Server-side. Effort **S–M**.
7. **`4179` | `@DFB_v12.zip` | assume signed (@mod) — verify | 721 KB | MEDIUM — concept only.** **Dynamic Force Balancer** — scales enemy **count** to balance difficulty. Aligns with WASP's `WFBE_PopTier` / `TOTAL_AI_MAX` levers (count-based, **not** sim-gating → house-rule-safe *as a concept*). Mine the balance formula; don't adopt its cutting behaviour wholesale.
8. **`4186` | `@Iranian_Forces_AI_Config.rar` | assume signed (@mod) — verify | 2.6 MB | MEDIUM.** A `CfgAISkill`/behaviour **config** addon ("improve AI behaviour"). Global config, dedicated-safe. Alternative/complement to ASR/Zeus — mine its skill-curve numbers only (adding a 3rd skill-config mod on top of ASR+Zeus would over-stack).
9. **`4215` | `GIB_Team_Planner_v20.7z` | assume unsigned | MIA | LOW-MED — idea only.** In-map **map-click → waypoint-set** planner for sub-teams. The click-to-order SQF is a code-idea for war-room group ordering. Client-origin tool.
10. **`4180` | `asr_mapgrids-1.4.zip` | assume signed (Robalo) — verify | MIA | LOW.** Config-only GPS/grid-accuracy tweak. Trivial; completeness of the ASR set.
11. **`4173` | `TrueMods_11-25-10.rar` | unsigned bundle | 41.7 MB | LOW — cherry-pick only.** Broad dated grab-bag; open only to lift one specific tweak.

**Excluded server-side:** `4153 @ussocom_performance`, `4157 PROPER_OA` (generic config/FPS replacers — clash risk with WASP's tuned configs); all `addons/units` 4385–4551 (cosmetic reskins).

## 4b. CTI / Warfare code-idea sources (bIdentify) — the ancestry & contrast set

`id | filename | what it is | why mine it`

1. **`5420` | `WarfareV2_073LiteCO.zip` | Warfare BE **2.073** Combined-Ops (Lite) | ⭐ THE literal parent baseline.** 1.6 MB, downloadable. **Diff WASP's fork against this to recover any stock behaviour it drifted from** — the single most useful CTI pull (WASP == modified BE 2.073). Complements the Drive's *older* BE-1.6 "Oden" (§2 Tier A): 1.6 = commander stubs, 2.073 = WASP's actual base.
2. **`5418` | `WarfareV2_072LiteOA.7z` | Warfare BE 2.072 (OA) | adjacent-version diff** — 2.072→2.073 delta shows Benny's last changes across the versions WASP straddles.
3. **`5419` | `Gossamers_Warfare_v3_04d_CO_FullPack.7z` | Gossamer's Warfare | ⭐ different CTI school.** Independently reworked economy / town capture / **AI town garrisons** — highest-value **non-Benny** source for alternative garrison-consolidation and commander logic (WASP's group-reduction lane).
4. **`5299` | `PromanMissions_v02-28-2012.7z` | crCTI **Proman** (CTI-24) | most-evolved crCTI branch** — richest crCTI SQF for upgrades/purchasing/AI-team ordering (deeper than the Drive's `crcti_WARFARE_03`).
5. **`5321` | `POv2.05.7z` | **Patrol Operations 2** (Roy86) | best-in-class COOP task/AI + **HC** framework.** Not CTI, but its **dynamic task generation, JIP handling, and headless-client offload** patterns are directly relevant to WASP's JIP + 2-HC lanes. (Variants: `5332 PatrolOps2XL`, `5339 PO2 French Army`.)
6. **`3146` | `domination_Panthera_West_AI_117…` (+ `3141` esbekistan, `3142` Fallujah) | **Domination** (Xeno) West-AI build | ⭐ the most-copied AI objective-cycling SQF in A2.** Mine Domination's **West-AI target-cycling / respawn / MHQ** for AICOM objective-selection ideas.
7. **`3139` | `mcti_r10_40vs40.Chernarus.rar` | MCTI 40v40 (r10) | scale on our map** — newer than the Drive's r9; mine large-player + many-AI-team management (relevant to WASP's group-count FPS knee).
8. **`5323` | `UC_v106_RC1.zip` | **Urban Conquest** | sector-capture scoring** — alternative capture/hold logic that could feed WASP's parked novel win-modes (BEACON LINE / THE VAULT).
9. **`3135` | `crcti_WARFARE_0.07.7z` / `3136` `crcti_Golden_Army_1.02.7z` | crCTI family** — lean CTI group/MHQ management; contrast to BE. (The Drive already yielded `crcti_WARFARE_03`.)
10. **`5311` | `MSO_Missions_4-55.7z` | Multi-Session Ops | modular MP + **HC-offload** architecture** — mine the headless-offload/module design.
11. **`5297`/`5298` | `WAR-Front-Demo` / `Dust_v1.2` | lesser CTI forks** — low priority; skim only if a specific need isn't met by the big four.

> **Priority order for a WASP-relevant deep dive (bIdentify):** `5420` (parent) → `5419` (Gossamer garrisons) → `4220` HETMAN (commander AI) → `3146` Domination West-AI → `5321` Patrol Ops (HC/JIP). Note the bIdentify Insurgency bucket was **empty** in both trees; `advance_and_secure` (5280–5283) = AAS map packs only.

## 4c. Optional player-side (bIdentify) — additional to §3b and to `OPTIONAL-CLIENT-MODS.md`

`id | filename | signed? | size | verdict`

1. **`4254` | `CorePatch-v10024.zip` | assume signed — verify | 11.2 MB | ⭐ TOP non-cosmetic.** Community **engine/config bug-fix** patch for A2:CO 1.63/1.64 — fixes long-standing vanilla bugs; safe, widely run, **client-side**. The standout *non-visual* addition to `@wasp_optional`. (Confirm it plays nice with the box's config expectations before recommending broadly.)
2. **`4246` | `SmartCamera_v1.1.zip` | assume unsigned | 296 KB | ⭐ ties into MatchReport.** Autonomous dynamic camera — directly relevant to WASP's **endgame winner-cam / MatchReport recap** lane (PR#114/#115); mine or ship for cinematic spectate. (`4152 GCam2.zip`, 412 KB = smooth free-cam, same use-case + orbit-cam code-idea.)
3. **`4211` | `vk_markers_v023.zip` | assume unsigned | 169 KB | HUD/QoL.** APP-6A standardized map markers — richer shared iconography; ties into match-report replay/marker work.
4. **`4262` | `RKSL_FlareSystem_and_System_v204.rar` | assume signed — verify | 119 KB | aircraft visual.** Countermeasure flare visuals/behaviour. Light, aircraft-relevant.
5. **`4197` | `pook_signalpanels_v1.0.zip` | assume signed — verify | 491 KB | niche.** Deployable VS-17 panels (visual marking aid).
6. **`4187` | `@ADO_Boussole.rar` (709 KB) / `4200` `AZC_GPS_v02.7z` (MIA) | compass / GPS overlays | niche HUD** — minor navigation immersion.

**Down-ranked / skipped player-side:** animation replacements (`4183 smk_anims`, `4226/4227 Smookie/Saku`), sky/lighting (`4241 PMC Skybox`, `4259 SSL`), `4177 @Blastcore_Visuals_R1.2` (already covered) — visual-only/heavier. **ACR-rule exclusions:** `4225 @OAMemesRC2` (CO/ACR tips), `4393 SBE_ACR`.

**Bottom line (bIdentify):** best *deployable* server-side picks that respect house rules are **`4170` ASR-AI** and **`4212` TPWCAS** (both already in WASP — so bIdentify mainly *confirms* our AI stack); the best *net-new code mines* are **`4220` HETMAN** (commander AI), **`4234` FAW** (AI artillery), **`4198` Ai-Heli-Control** (AI heli tasking), and **`4201` JED_ESS** (runtime skill for the war-room). Best CTI pulls are **`5420`** (literal parent) and **`5419`** (Gossamer garrisons). Best player-side is **`4254` CorePatch**.

---

## 4d. 2026-07-03 lane-21 candidate scout (metadata-only, no downloads)

Follow-up sweep over the warfare/CTI bucket pages found four adjacent candidate archives that were not already ranked in the tables above. This pass deliberately stopped at bIdentify metadata: no archive was downloaded, unpacked, or copied into the repo.

| id | Bucket | File | bIdentify metadata | WASP value | Verdict |
|---|---|---|---|---|---|
| `5430` | `arma2oa/scenarios/mpgamemodes/warfare` | `CWR2Warfare.7z` | "CWR2 Superpowers Warfare"; author `[ASA]ODEN`; 43,148 bytes; hash `561d85c07da9f2676edc3c16d1fb92e2ff281626ac07afebea989dc8d3df53da`; original Armaholic id 15742. | Oden-authored, very small Warfare/Superpowers variant. Could expose a compact mission-level delta around Superpowers/Warfare setup and CWR2 class separation. | Low-risk future read, but do not port content: CWR2 dependency makes it a reference-only mine unless a specific mission-logic pattern is found. |
| `3257` | `arma2/scenarios/mpgamemodes/warfare` | `BHP_WarfareV2_073CO.saru.zip` | "Sarugao 1.0 Island Warfare mission 2.073 CO"; author `kovacsadam`; 549,012 bytes; hash `30f876a19de31541ffc80335475735ffdc0f4768f687e6d99918d0db3ce60382`; original Armaholic id 17848. | Same BE 2.073 CO lineage as WASP on a custom island. Good candidate for map-port drift, island-objective setup, and any map-aware constants that survived a community port. | Medium future read after `5420`; useful for map-port practices, not a feature proposal by itself. |
| `3262` | `arma2/scenarios/mpgamemodes/warfare` | `WarfareV2_046Lite.Sara.zip` | "Warfare - Benny Edition -Sahrani- (@)"; author `Big`; 152,038 bytes; hash `4b4d25b2eef0d4c7c0c476a540a20fa840d676ee6f8b2b44545562dcee57fe80`; original Armaholic id 7669. | Older BE 2.046 Sahrani port. Useful only when tracing pre-2.07x behavior history or Sahrani map adaptation. | Lower priority than `5418`/`5420`; keep as lineage fallback. |
| `3140` | `arma2/scenarios/mpgamemodes/capture_the_island` | `Carrier_WarfareBE_2.054_CVM0506@Duala.rar` | "Carrier WarfareBE @Duala Testmissions"; author `[URC]Stoned`; 1,111,578 bytes; hash `50dfcadf0a60facda558b05a0832c6843320ef23b7105c89886c8ee4fa6ad465`; original Armaholic id 9368. | Most actionable new lead in this scout: a WarfareBE carrier test mission on Duala. Could contain mission-side carrier placement, respawn/shop/access, or deck-object lessons relevant to the Khe Sanh naval-HVT carrier release problem. | Route to the existing `KHESANH-REL` owner only. This lane does not claim or edit Khe Sanh carrier work. |

Bucket context checked during this pass:
- `arma2oa/scenarios/mpgamemodes/warfare`: 2 available files and 24 missing. The already-ranked `5420` BE 2.073 parent and `5419` Gossamer rows remain the first priority; `5430` is the new small Oden/CWR2 side lead.
- `arma2/scenarios/mpgamemodes/warfare`: 2 available files and 12 missing. The new available rows are `3257` Sarugao BE 2.073 CO and `3262` Sahrani BE 2.046.
- `arma2/scenarios/mpgamemodes/capture_the_island`: 1 available file and 5 missing. The available row is `3140` Carrier WarfareBE @Duala; the already-ranked `3139` MCTI r10 remains missing in this bucket snapshot.
- `arma2/scenarios/mpgamemodes/domination`: 0 available files and 6 missing. This confirms the previously ranked `3146` Domination Panthera West-AI remains metadata-only from bIdentify unless sourced elsewhere.

Next selective pull order if a future mining lane downloads archives: `3140` first for the carrier/HVT owner, then `3257` for BE 2.073 map-port comparison, then `5430` for a quick Oden/CWR2 reference read. Keep `3262` as a historical fallback.

---

# 5. APPENDIX — reproduction & provenance

- **Drive listing:** `curl -sL "https://drive.google.com/embeddedfolderview?id=1saZFKkhygT3DuG9lFkXzmcYC4rQ6lFNM"` → 3 MB HTML → parsed 4,210 `flip-entry` rows (id + title). Index at scratchpad `archive-mining/miksuu_index.tsv`.
- **Download:** `archive-mining/gdl.sh <id> <out>` (single-file Drive uc?export=download + confirm-token fallback to `drive.usercontent.google.com`). All 12 pulls verified `377abc…` (7z magic).
- **De-archive:** two-step (`7z x -parmedassault` outer → `7z x` inner). PBOs via `archive-mining/depbo.py` (pure-Python PBO reader; 7-Zip can't read `.pbo`).
- **Password** `armedassault` confirmed working on every outer `.7z`.
- **Extractions on disk (scratchpad, not committed):** `archive-mining/ex2/*` (mods), `archive-mining/pbo/{crcti_cher,mcti_r9,oden_wf16}` (unpacked CTI missions).
- **Cross-refs:** `docs/design/OPTIONAL-CLIENT-MODS.md` (client-optional + AI handoff lanes), memory `wasp-baseline-lineage-recon` (Miksuu=parent, AICOM ours-only), `wasp-inplace-hotfix-cache-trap` (client pbo naming), host `CLAUDE.md` (A2-OA-1.64, ignore A3 docs).
