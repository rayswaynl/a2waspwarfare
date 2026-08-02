# Review: naval HVT objectives uncommitted delta — salvage or discard

| Field | Value |
|---|---|
| Task id | `wasp-review-naval-hvt-delta-20260731` |
| Reviewer lane | `grok-main-07311829-night` (grok) |
| Date (UTC) | 2026-07-31 |
| Worktree (read-only) | `C:\Users\Steff\a2wasp-navalhvt` |
| Branch / HEAD | `feat/naval-hvt-objectives` @ `2e1c593171` |
| Compare base | `origin/master` @ `6a9f3994d6` (fetched 2026-07-31) |
| Scope | Uncommitted working-tree delta only (+ branch vs master context) |
| Confidence | **High** for discard of the uncommitted dirt; **Medium** for "no live client gap" (no RPT/runtime probe) |

**Owner framing:** REVIEW CARD only. No stash/checkout/clean. No SQF edits. Verdicts are review-diversity input, not a final merge call.

---

## Executive verdict

**DISCARD the uncommitted 1,107-line / 28-file working-tree delta.**

There is **no salvage fold** worth a follow-up implementation card from this dirt pile.

| Layer | Finding |
|---|---|
| Branch commits | Fully **already-landed / superseded**. `git rev-list --count origin/master..HEAD` = **0**. Merge-base = branch HEAD. Master has evolved naval HVT far past this tip. |
| Uncommitted CH (source) | Almost nothing real: 1 whitespace-only EASA line, 2 EOL-noise files, 1 **orphan** untracked client script that is never launched and does not match current architecture. |
| Uncommitted TK (mirrors) | ~all of the +1107 lines. Stale **LoadoutManager / CH→TK paste pollution** of ideas already on master CH (and already mirrored on master TK/ZG for naval files), plus map-size **corruption** (12800→15360 on Takistan paths). |
| Unique untracked naval copies on TK | Stale copies of branch-era files; master already ships TK/ZG `Init_NavalHVT.sqf`, `Support_ScudStrike.sqf`, `Common_AddVehicleMarking.sqf`, `Server_NavalHVT_BubbleComplete.sqf`. |

**Recommended owner action:** drop the worktree (or hard-reset dirt only after another lane's dispose card) — do **not** fold this dirt into master.

---

## Inventory (what the 1,107 lines actually are)

### Measured shape (read-only)

```
git status --short  → 33 modified + 6 untracked  (39 paths; card said ~28 content files)
git diff --stat     → 29 files changed, 1107 insertions(+), 208 deletions(-)
```

| Bucket | Paths | Lines (approx) | Role |
|---|---|---|---|
| CH modified | `EASA_Init.sqf` (+1/−1 whitespace), `Common_ReturnAircraftNameFromItsType.sqf` + `Common_BalanceInit.sqf` (EOL only; empty content diff with `--ignore-cr-at-eol`) | ~1 real | Noise |
| CH untracked | `Client/Init/Init_NavalHVTClient.sqf` (42 lines, SHA256 `71204D2C…C48108`) | 42 | Orphan client |
| TK modified | Squad_USMC/RU (~720+), stringtable (~126), Root_*/Defenses/Core_GUE, vehicle markings, SkinSelector, structures, upgrades, Init_Server, server_town, constants, etc. | ~1060 | Mirror pollution + non-naval already-landed ideas |
| TK untracked | `Init_NavalHVT.sqf`, `Support_ScudStrike.sqf`, `Common_NearestOpenCoast.sqf`, `Common_AddVehicleMarking.sqf`, `Root_GUE_PlayerOverlay.sqf` | n/a (untracked) | Stale naval/mirror copies |

### Branch vs master (committed)

- Branch HEAD `2e1c593171` message: `fix(naval-hvt): sync branch with deployed b83nav (towns + respawn + name + loop cap)`.
- **Zero commits** on branch that are not already in `origin/master` history.
- `Init_NavalHVT.sqf` size: branch HEAD **333** lines vs master **~1413** lines — master is the evolved live lineage (deck camps, CAP/skirmish, bubble, USV hooks, etc.).

### Deck-camp constants note (card callout)

- Card: real deck-camp constants live at `Init_NavalHVT.sqf:1283`, not a dead constant.
- Verified on **current master** working tree: deck-camp runtime builder uses camp model offsets **`[[-10, 18, 0], [-10, -18, 0]]`** in the "no camps AND no deckpart ref" / runtime deck-camp path (content near the ~1280 region; file has grown past a single magic constant).
- Branch HEAD's 333-line `Init_NavalHVT.sqf` is the **older** carrier assemble path; it is **not** the place to re-litigate deck-camp constants from this dirt.

---

## Idea-by-idea verdicts

Legend: **already-landed** | **superseded** | **salvageable** | **junk**

### A. Naval HVT feature core (branch era)

| Idea | Verdict | Evidence |
|---|---|---|
| A1. Three LHD carriers (Alpha/Bravo/Charlie) as capturable naval HVTs | **already-landed** | Master `Init_NavalHVT.sqf` header + `mission.sqm` Khe Sanh logics; `WFBE_C_NAVAL_HVT` default 1 |
| A2. Pre-placed sqm town logics + server decorate/CAP | **already-landed** | Master explicitly: town logics PRE-PLACED in mission.sqm, registered by `Init_Town` before naval init |
| A3. SCUD strike support (`Support_ScudStrike`, `KAT_ScudStrike`, HandleSpecial case) | **already-landed** | Master `Init_Server.sqf`, `Server_HandleSpecial.sqf`, constants block |
| A4. Post-capture client announce + carrier hangar respawn (`server_town` naval block) | **already-landed** | Master `server_town.sqf` ~585+; client `HandleSpecial` case `naval-hvt-captured` |
| A5. Flag/constants `WFBE_C_NAVAL_HVT`, SCUD cost/cooldown/warheads | **already-landed** | Master `Init_CommonConstants.sqf` (~2407+) plus later SCUD product flags |
| A6. Deck-Z, deck camps, capture height B755, bubble, skirmish CAP, USV coupling | **already-landed / superseded** | Present on master; **absent or thinner** on branch HEAD 333-line file — do not fold branch-era file over master |

### B. Untracked / orphan naval add-ons in this dirt

| Idea | Verdict | Evidence |
|---|---|---|
| B1. `Init_NavalHVTClient.sqf` — wait for `WFBE_NAVAL_HVT_CLIENTREG`, push logics into client `towns[]`, Depot marker + name label | **junk** (architecture-orphaned) | (1) No reference anywhere on worktree launches this file. (2) No producer of `WFBE_NAVAL_HVT_CLIENTREG` on branch or master. (3) Master architecture is **sqm pre-placed** towns → client already gets them via normal town/marker init; master also has shop-POI markers for naval HVTs in `Init_Markers.sqf`. Runtime-create client reg is a **dead alternate path**. |
| B2. `Common_NearestOpenCoast.sqf` (committed on branch CH; untracked TK copy) | **junk** (dead helper) | File exists on branch HEAD; **zero call sites** on the worktree. **Absent** from `origin/master`. Extracted for reuse that never shipped. |
| B3. TK untracked `Init_NavalHVT.sqf` / `Support_ScudStrike.sqf` / `AddVehicleMarking.sqf` | **already-landed** (on master mirrors) + **junk as dirt** | Master already has TK+ZG copies of naval/marking files. Untracked TK hash ≠ branch CH HEAD hash for Init_NavalHVT — stale partial copy, not a better source. |

### C. Uncommitted TK "naval wiring" (looks naval, is polluted)

| Idea | Verdict | Evidence |
|---|---|---|
| C1. TK `Init_Server` SCUD compile + `execVM Init_NavalHVT` | **already-landed** on CH/master; **junk to paste onto TK dirt** | Same blocks already on master CH. Naval is `IS_naval_map`-gated on master; dumping CH launch into dirty TK without map guards is wrong direction. |
| C2. TK `server_town` naval post-capture block | **already-landed** on master CH (and mirrored) | Matches live master block shape. |
| C3. TK constants naval/SCUD + `WFBE_C_VEHICLE_MARKINGS` | **already-landed** | Master constants already contain both. |
| C4. TK `Init_Server` map size `12800` → `15360` | **junk / harmful** | Takistan world size is 12800; 15360 is Chernarus. Same CH paste in `Common_RunCommanderTeam` heli exit clamp. |
| C5. TK `Init_Server` airfield probe ungated + `SET_MAP` 1→2 | **mixed noise** | Probe ungating undoes TK-safe Chernarus-only gate present in branch index. SET_MAP 2 may be "more correct for TK" but is not a naval HVT idea and must not ride this dirt. |

### D. Non-naval bulk (majority of +1107)

These are **not naval HVT objectives**. They are older CH content sitting dirty on the TK mirror of this worktree. Cross-checked against current master CH:

| Idea | Verdict | Master status |
|---|---|---|
| D1. Combined-arms Squad_USMC / Squad_RU rebuild | **already-landed** | Master CH has "COMBINED-ARMS REBUILD 2026-06-14" |
| D2. GUER patrol revamp (technicals / T72 column) | **already-landed** | Master `Root_GUE.sqf` |
| D3. GUER statics strip to ZU-23 only | **already-landed** | Master `Defenses_GUE.sqf` |
| D4. Core_GUE Warlord / Ka137 / Mi24_P rows | **already-landed** (evolved) | Master has later B60/B66 air-level fixes |
| D5. Vehicle markings + CreateVehicle hook + texture append | **already-landed** | Master `AddVehicleMarking` + `WFBE_CO_FNC_AddVehicleMarking` call |
| D6. SkinSelector pool expansion / Miksuu skins | **already-landed** | Master SkinSelector_Data |
| D7. Structures reskin (Antenna CBR, nest bank/reserve) | **already-landed** | Master Structures_CO_RU |
| D8. AI upgrade order strip ARTYTIMEOUT | **already-landed** | Master Upgrades_CO_US/RU |
| D9. Briefing "Experimental" rename + AI & Factions page | **already-landed** | Master briefing.sqf |
| D10. stringtable churn (voting keys removed/reordered, etc.) | **junk as dirt** | Large churn; not naval; risk of TK drift vs master mirrors |
| D11. Core_TKGUE Ka137 block removed | **junk / wrong direction** | Contaminated TK-specific registration; master CH keeps Ka137 via Core_GUE with intentional load-order comments |
| D12. EASA whitespace-only Ka137 default array spacing | **junk** | Pure formatting |

---

## Scoped fold plan (survivors)

### Survivors for implementation cards

**None.**

No follow-up card is recommended to re-apply any subset of this uncommitted delta.

### Optional future *ideas* (not fold-from-this-dirt)

These are notes only — **not** justified by unique code in this worktree worth cherry-picking:

1. **Sea town name labels** — if live players still complain that Khe Sanh names are hard to read on the map, design a **new** flag-gated marker pass against *current* master `Init_Markers` / town marker pipeline. Do **not** revive `Init_NavalHVTClient` + `CLIENTREG`.
2. **NearestOpenCoast utility** — only if a future feature needs open-sea bearings; re-extract from a clean design, not from this orphan file.

### Dispose recommendation (for a separate dispose/hygiene card)

| Action | Detail |
|---|---|
| Keep | Nothing from the uncommitted dirt |
| Discard dirt | All 39 dirty/untracked paths in `a2wasp-navalhvt` |
| Worktree | Safe to remove registration after owner/dispose lane confirms no other claim — branch has no unique commits vs master |
| Do **not** | `git add` any of this; do **not** run LoadoutManager from this dirty tree; do **not** overwrite master naval with branch HEAD 333-line file |

---

## What was verified / not verified

### Verified (commands / reads)

- Worktree branch, HEAD, status, `git diff --stat` / `--numstat`, sample diffs for all major idea clusters.
- `origin/master` fetch; merge-base; `origin/master..HEAD` commit count = 0.
- Master naval file list; `Init_NavalHVT` size and deck-camp offsets; `mission.sqm` Khe Sanh logics.
- Master presence of SCUD/server_town/constants/HandleSpecial/Init_Markers naval hooks.
- Cross-check of non-naval bulk ideas against master CH sources.
- `Init_NavalHVTClient.sqf` full read; no launch sites; no `CLIENTREG` producer.
- `NearestOpenCoast` zero call sites on worktree; absent on master.

### Not verified (limits)

- Live server RPT / in-engine marker UX (whether sea names feel weak on box).
- Whether master TK/ZG mirrors are byte-healthy vs CH after unrelated recent PRs (out of scope; only checked naval file *existence* on master mirrors).
- Full line-by-line identity of every TK dirty file vs master TK (sampled; pattern is consistent CH-paste / already-landed).
- Did not run lint, LoadoutManager, or any write operation on the worktree.

---

## Bottom line

| Question | Answer |
|---|---|
| Salvage or discard? | **Discard** |
| Any unique naval idea left in the dirt? | **No** (one dead client path + one unused helper) |
| Is the branch itself valuable? | **No unique commits** vs master; master is the real naval lineage |
| Follow-up cards? | **None** for fold; optional separate **worktree dispose** only |

**Confidence: High** on discard. **Could not verify:** live client map UX gap that would justify a *new* name-label feature (independent of this dirt).
