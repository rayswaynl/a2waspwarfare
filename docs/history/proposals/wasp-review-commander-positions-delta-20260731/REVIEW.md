# Review: commander-positions WDDM follow-on pass (19 files uncommitted)

**Task id:** `wasp-review-commander-positions-delta-20260731`  
**Reviewer lane:** `grok-main-07311829-night` (grok, read-only)  
**Date (UTC):** 2026-07-31  
**Scope:** worktree `C:/Users/Steff/a2waspwarfare-positions` on branch `feat/commander-positions` @ `560db61c32`, plus cross-check of `C:/Users/Steff/WDDM` and current `a2waspwarfare` `origin/master`.  
**Method:** read-only git status/diff/log + file reads. No stash, no edits to the worktree, no mission runs.

---

## Verdict

**DEAD EXPERIMENTS / SUPERSEDED WIP — not the next preset wave.**

**Confidence: high (0.88)** for “do not fold this dirty tree as-is.”  
**Confidence: medium (0.70)** that the only salvageable idea is the “Redo base walls” hotkey QoL, if the owner still wants it.

This tree is early-June follow-on dirt left on a branch whose base feature was already integrated and then heavily evolved on master. It does **not** import any of WDDM’s later 76-preset candidate sheet into the mission.

---

## Worktree facts (verified)

| Item | Value |
|------|--------|
| Path | `C:/Users/Steff/a2waspwarfare-positions` |
| Branch | `feat/commander-positions` |
| HEAD | `560db61c32` — `fix(commander-positions): build composition at the placement point, not the map corner` (2026-06-03) |
| Upstream | based on `origin/feat/commander-positions` **gone** |
| Distance behind `origin/master` | **4106** commits (`git rev-list --count HEAD..origin/master`) |
| Base in master? | Yes — `560db61c32` is ancestor of `origin/master` (exit 0) |
| Uncommitted content diff | **19 files, +305 / −124** (`git diff --shortstat`) |
| Extra untracked | 5 files (RedoBaseWalls × CH/TK + RequestRedoBaseWalls × CH/TK + TK ConstructPosition) |
| Porcelain noise | ~30 lines — several CH/TK files show as modified only via LF/CRLF warnings and do not appear in `git diff --name-only` (EASA, BalanceInit, aircraft-name helpers) |
| Zargabad touch | **None** |
| Read-only | Yes (no stash, no write) |

Committed history on this branch (already in master lineage via release integrate):

- `98b15e97a6` feat(defenses): commander-buildable defense positions + modular base walls  
- `560db61c32` fix placement at placement point (not map corner)  
- Master also shows `2a9996ae99 release: integrate WDDM commander-buildable defense positions` and later expansions (e.g. PR **#492** thin-tower flak + WDDM defenses, fortif pack, light/heavy tiers).

---

## What the 19-file delta actually contains

Three themes, not a new preset wave:

### A. Auto-wall redesign (CH + TK `Init_Defenses.sqf`)

Replaces legacy `Land_HBarrier_large` factory rings with large rectangular `Base_WarfareBBarrier10x` for:

- `WFBE_NEURODEF_BARRACKS_WALLS`
- `WFBE_NEURODEF_LIGHT_WALLS`
- `WFBE_NEURODEF_HEAVY_WALLS`
- `WFBE_NEURODEF_AIRCRAFT_WALLS`

Adds new `WFBE_NEURODEF_HEADQUARTERS_WALLS` as **8× `Base_WarfareBBarrier5x`**.

### B. HQ wall attach + “Redo walls” QoL (new behavior)

- `Construction_HQSite.sqf`: on deploy, if auto-wall on, spawn HQ walls and store `WFBE_Walls`; on undeploy, delete them.
- New untracked:
  - `Server/Functions/Server_RedoBaseWalls.sqf` (mtime **2026-06-05**, ~2.2 KiB)
  - `Server/PVFunctions/RequestRedoBaseWalls.sqf`
- `coin_interface.sqf`: bare User14 still toggles auto-wall; **Ctrl/Shift+User14** sends `RequestRedoBaseWalls` with mode `all` / `hq` / `factories`.
- `Init_PublicVariables.sqf` + `HandleSpecial.sqf` wire the PV + client “base walls redone” chat line.
- `Init_Server.sqf` compiles `WFBE_SE_FNC_RedoBaseWalls`.

### C. TK Stage-1 catch-up (not “new presets”)

On this branch HEAD, CH already has Stage-1 positions + `Server_ConstructPosition.sqf`; TK did **not** at HEAD. The dirty TK tree adds:

- Full Stage-1 composition templates + `WFBE_POSITION_TEMPLATE_MAP` / anchors (6 anchors: AA / Arty / Mixed / wall straight-corner-gate)
- `Core_CIV.sqf` menu rows + `Structures_CO_US/RU` defense name lists
- `RequestDefense.sqf` anchor → `Server_ConstructPosition` branch
- Untracked TK `Server_ConstructPosition.sqf` (copy of the June CH placement-fix version)
- Drop of a leftover `hintsilent` in TK `Construction_StationaryDefense.sqf`

This is mirror/backfill of the **original** 6-anchor Stage-1 set, not the expanded master catalog.

---

## Cross-check: current master (shipped reality)

On `C:/Users/Steff/a2waspwarfare` working tree (current master checkout):

| Capability | Master state |
|------------|--------------|
| `Server_ConstructPosition.sqf` | **Present** |
| `Server_RedoBaseWalls.sqf` | **Absent** (this WIP idea never landed) |
| HQ auto-walls on deploy | **Already present** — uses `WFBE_NEURODEF_HEADQUARTERS_WALLS` |
| HQ wall composition | **`Concrete_Wall_EP1` funnel + CncBlock gate** (owner survivability design), **not** Barrier5x |
| Factory walls | Legacy H-barrier rings **plus** V3/V4 concrete-backed variants (`*_WALLS_V3`, `*_WALLS_V4`) |
| Position catalog | Far beyond Stage-1: light/heavy AA/arty/mixed tiers, hedgehog line, flak tower, fortification pack under `WFBE_C_DEF_FORTIF_PACK` |
| Anchor count (base map) | 11+ names (vs WIP’s 6); fortif pack appends more when flag > 0 |
| Coin User14 | Auto-wall toggle only — **no** redo-walls modifier |

**Implication:** applying this dirty tree on top of master would **regress** HQ/factory wall design (Barrier10x/5x rectangles overwrite the concrete evolution) and would reintroduce the obsolete Stage-1-only TK mapping if someone “synced” from this tree.

Master already contains the original commander-positions integrate and many follow-ons (examples found via `gh pr list`): **#492**, **#695**, **#801**, **#1574** (Reserve Guard / strongpoint), fortif-pack work, etc. Closed early PR **#10** “commander-buildable defensive positions” never merged as that PR but the feature entered via release integrate + later build waves.

---

## Cross-check: WDDM repo

| Item | Value |
|------|--------|
| Path | `C:/Users/Steff/WDDM` |
| Current branch | `main` @ `1f6cd32` (behind origin/main by 2) |
| `feat/commander-positions` | Tip `08b5ad7` **already ancestor of main** (fully merged) |
| Shipped WDDM work | `402f757` end-game positions + base-wall prefabs; `08b5ad7` mission-valid classname fix (no-drift with a2waspwarfare) |
| `PRESETS` count on main `index.html` | **76** keys |
| Sheet comment (verbatim intent) | Original **9** wall_*/aapos/artypos/mixedpos entries are the PR#8-bundled set; **everything else is a NEW candidate** (“tell me which rock”) |

Candidate families on WDDM main that are **not** represented by this worktree delta:

- fort_* sandbag/H-barrier/wire/bunker shells  
- wall_hesco_run, hq_walk_exit / hq_concrete_walk_exit, factory_*_walk_exit, uav_walk_exit  
- radar_*, reserve_* (incl. CHOSEN designs + reserve_guard west/east)  
- aa/at/mg/gl/mortar/arty/mixed/cp **v1/v2** tiers west+east  
- fortress_* 8/12/16 AI (mega-fortress, commit `a5eb9e4`, present on main)  
- guer_town_*, base_* FOB/airbase/firebase experiments  

**This worktree does not fold any of those candidates.** True “next preset wave” work starts from **WDDM main’s PRESETS sheet + current mission master**, not from `a2waspwarfare-positions`.

---

## Classification matrix

| Theme | Live value? | Fold? |
|-------|-------------|-------|
| Barrier10x factory wall swap | **No** — superseded by master concrete V3/V4 + HQ concrete funnel | Discard |
| Barrier5x HQ walls | **No** — conflicts with master Concrete_Wall_EP1 HQ | Discard |
| TK Stage-1 backfill of June 6 anchors | **No** — master already has richer maps on all maintained terrains via proper release path | Discard |
| Line-ending / EASA / BalanceInit dirt | Noise only | Discard |
| RedoBaseWalls hotkey + server redo | **Maybe** — unique vs master; still potentially useful QoL | Optional **fresh** PR from master only |
| WDDM 76-preset next wave | Live design surface, **outside this tree** | Separate owner pick card |

---

## Scoped fold plan (if owner still wants anything)

### Recommended default: discard worktree dirt

1. Leave `a2waspwarfare-positions` dirty as-is **or** owner-delete the worktree after a backup zip if desired — **do not commit** this delta onto any live branch.  
2. No mission PR from this tree.  
3. Optionally archive a patch of `Server_RedoBaseWalls.sqf` + `RequestRedoBaseWalls.sqf` + the coin_interface modifier block only, for reference.

### Optional salvage (owner gate): Redo walls QoL only

If owner wants “Ctrl/Shift+User14 redo HQ/factory walls” on live:

1. Branch **from current `origin/master`** (not from `560db61`).  
2. Port **only**:
   - `Server/Functions/Server_RedoBaseWalls.sqf`
   - `Server/PVFunctions/RequestRedoBaseWalls.sqf`
   - Register compile in `Init_Server.sqf`
   - PV name in `Init_PublicVariables.sqf`
   - Coin keybind branch + HUD hint in `coin_interface.sqf`
   - `HandleSpecial` case `base-walls-redone`
3. Re-test against master’s **concrete** `WFBE_NEURODEF_*_WALLS` / `HEADQUARTERS_WALLS` names (already present).  
4. Flag policy: treat as feature → `WFBE_C_*` default 0 unless owner says correctness/QoL ship-direct.  
5. Source = Chernarus only; LoadoutManager mirror; restore TK/ZG `version.sqf.template`.  
6. **Do not** port any `Init_Defenses.sqf` wall composition changes from this tree.

### True next preset wave (separate card)

1. Owner picks N candidates from WDDM `PRESETS` (comment already marks non-PR#8 as candidates).  
2. Export/validate classnames against mission (repeat `08b5ad7` no-drift discipline).  
3. New PR on a2waspwarfare from **master**, CH source + mirror, flag-gated if additive.  
4. Do **not** use `a2waspwarfare-positions` as base (4106 commits stale).

---

## What this review could NOT verify

- In-game FPS or placement feel of Barrier10x vs concrete slabs.  
- Whether any owner still prefers the June Barrier5x HQ sketch over the live concrete funnel (no evidence found in this tree).  
- Byte-identity of every WDDM preset `objs` array vs any master template (spot-checked architecture only).  
- Live server / RPT behavior (out of scope; read-only).  
- Whether fleet lane `wddm-commander-positions` has an open claim elsewhere (searched PRs + local repos only; no live claim board mutation).  
- Peach/Fleet-Drop delivery of this report is performed after write; see task evidence line.

---

## Recommendation (owner-facing)

1. **Label the worktree dirt: dead experiments / superseded.** Do not fold.  
2. **Optional:** one small master-based card for RedoBaseWalls QoL if still wanted.  
3. **Next preset wave:** open a pick-list against WDDM’s 76 PRESETS (fortress / reserve / tiered AA-AT-MG / guer_town / base_*), not this June tree.

---

## Evidence paths

- Worktree: `C:/Users/Steff/a2waspwarfare-positions` (read-only inspected)  
- Mission master checkout: `C:/Users/Steff/a2waspwarfare`  
- WDDM: `C:/Users/Steff/WDDM` (`main`, PRESETS in `index.html`)  
- This report: `Docs/Proposals/wasp-review-commander-positions-delta-20260731/REVIEW.md`

**MILESTONE note:** advisory review report for owner decision; not a merge claim.

---

*End of review. Verdict is review-diversity INPUT only; owner decides discard vs optional RedoBaseWalls salvage vs WDDM next-wave picks.*
