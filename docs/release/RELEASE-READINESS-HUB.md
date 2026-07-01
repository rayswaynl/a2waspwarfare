# WASP Warfare — Release Readiness Hub (Chernarus + Takistan)

**Owner:** claude-gaming &middot; **PR:** [#129](https://github.com/rayswaynl/a2waspwarfare/pull/129) &middot; **Branch:** `claude/release-readiness-2026-07-01` &middot; **Base:** `origin/master` (`5bf5f9238`) + carried fixes &middot; **Updated:** 2026-07-01

Single source-of-truth ledger for getting the updated WASP Warfare mission release-ready on **both** maintained terrains — Chernarus (`Missions/…chernarus`, canonical) and Takistan (`Missions_Vanilla/…takistan`, LoadoutManager mirror) — with the code optimized and the **AI Commander** improved. Consolidates codex PRs #123–#126 into one living hub; lands verified low-risk fixes incrementally; stages riskier work as reviewable proposals.

> **Method:** a 24-agent read-only recon + adversarial-verify workflow audited every dimension (static compat + parity, AI Commander ×5, performance ×3, wiki ×2, external sources ×3). Every landed fix below was confirmed real by one agent **and** independently verified A2-OA-safe by a second. Behavioral findings are staged, not landed, until they have runtime proof.

---

## 1. Release gate — current verdict: **NO-GO** (runtime evidence pending)

| Terrain | Server | HC1 | HC2 | Start-client | Late-JIP |
|---|---|---|---|---|---|
| Chernarus | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Takistan  | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

Static gates **PASS** (see §4). Runtime proof (approval-gated, §7) is the sole remaining blocker across all lanes: expected AICOM tokens, release markers, package SHA, client/HC role proofs, no stop-condition errors, and the Takistan WEST founding-fallback token. **Forum-sourced release-soak watch item:** grep the server RPT for the `server_groupsGC` `>= 130` / `AT CAP` per-side group-count warnings — crossing 130 in normal play is the documented root cause of the classic "Warfare AI goes passive after ~2h" bug (A2/OA hard ~144-groups/side engine cap). The mission is already hardened against it; the soak just needs to confirm it never trips.

---

## 2. Consolidation of the codex release lanes

| PR | Lane | Disposition |
|---|---|---|
| #123 | release-captain findings LOG | folded into §1 gate + §6 |
| #124 | r8 stack + RPT tooling (conflicted) | tooling referenced; findings folded |
| #125 | AICOM command-center + `Tools/PrTestHarness` (mergeable) | biggest AICOM lane — reviewed §3, selectively fold |
| #126 | AICOM guardrails + ledger | verified pieces already in master via #127 |
| **#127** | merged | already in `origin/master` |

---

## 3. AI Commander (core feature) — review + status

The `Server/AI/Commander` subsystem is **ours-only** (confirmed absent from upstream `Miksuu/a2waspwarfare`: 36 files on origin, 0 upstream), the largest behavioral surface, and the top release risk. All 18 files are **A2-OA token-clean** on live lines (verified).

### ✅ Landed (verified safe, this PR)
- **P1 double-fallback RESOLVED** — `AI_Commander_Teams.sqf`: the second (cmdcon31) starved-infantry fallback was a byte-identical duplicate of the cmdcon33 block operating on the *same* founding pass (`_eligible` is only filtered, never rebuilt, between them; the admitted infantry template survives both the static-strip and air-gate), so its admit branch was provably unreachable. **Removed.**
- Group-cap founding ceiling: hardcoded `110` → tunable `WFBE_C_AICOM_GROUP_CAP` (default 110, no behavior change).
- Scope-leak hygiene: `_ltDisband`/`_ltBeacon` added to `AI_Commander.sqf` `private[]`; `_rIssues`/`_rMaxIssues`/`_rMaxDist` added to `AI_Commander_Produce.sqf` `private[]`.
- Aligned the dead `WFBE_C_AICOM_TEAMS_PC_LOW` fallback defaults (were 6 / 15 in two files) to the live const value 12.
- `AI_Commander_PlayerArty.sqf`: added the missing `isNull _logik` guard (GetSideLogic returns objNull, never nil) and defaulted the two `WFBE_C_ARTILLERY` reads — defensive hardening, zero behavior change.

### 🔬 Carried on branch (Ray, `bcc6e3974`, cmdcon33) — verification-pending
WEST founds-0-on-Takistan fallback relocation + HQ-deploy `objNull` guard / `Warfare_HQ_base_unfolded` flat-check exemption, both maps.

### 📋 Staged AICOM proposals (confirmed real, need runtime proof — NOT landed)
| Sev | Item | File |
|---|---|---|
| P1 | **Strategy scorer is dead work when Allocate is live AND aims artillery at a divergent target** — Allocate (`WFBE_C_AICOM2_ALLOCATE_ENABLE=1`) overwrites the fist, but Strategy still uses its own `_targets` for artillery aim + FRONT telemetry. Gate the scorer behind `ALLOCATE_ENABLE<=0`; have artillery read the live fist. | `AI_Commander_Strategy.sqf:103-372` |
| P1 | `_findBuildPos` rebuilds the side-structures list ~150-190× per placement → snapshot once. | `AI_Commander_Base.sqf` |
| P2 | Allocate exits at L155 without clearing stale `wfbe_aicom_targets` (mirror the L36 clear). *Lowest-risk fix in the set.* | `AI_Commander_Allocate.sqf:155` |
| P2 | Last-stand recall has no authoritative `wfbe_aicom_laststand` early-out in Allocate (coupling relies on per-team teammode). | `Strategy` / `Allocate` |
| P2 | Reactive-defense reliever count conflates existing + new reliefs → starves new reliefs (RELIEF_MAX default **1**). | `AI_Commander_Strategy.sqf:432-495` |
| P2 | Counter-battery scan radius 10 km from enemy HQ can miss a forward-deployed SPG (12.8–15 km base separation). | `AI_Commander_Base.sqf:381-403` |
| P3 | "Smarter commander" set: doctrine de-correlation boot-race; base-defense modulo can leave 0 dedicated AT; factory-rally snapshots a stale front; concentrate-first death-marches out-of-reach teams; harass can steal the heavy punch. All behavioral — soak-gated. | `AI_Commander*.sqf` |

> **`aicom-actions` re-run (2026-07-01) — coverage gap CLOSED.** A follow-up 4-agent pass deep-reviewed all 9 action files (all A2-OA token-clean). Results:
> - ✅ **Landed:** the two PlayerArty hardening fixes above.
> - ⚠️ **Ray decision — feature-flag doc drift (P2):** three AICOM features' file headers claim "default-OFF / ships INERT for a soak" but the constants ship them **ON** — `WFBE_C_AICOM_PARATROOPS_ENABLE=1` (Paratroops **live**), `WFBE_C_AICOM_SPAWNBEACON_ENABLE=1` (Beacon **live**), `WFBE_C_AICOM_HC_TOPUP_ENABLE=1` (HCTopUp dark only by an un-compiled function + unwritten consumer). **Are Paratroops/Beacon meant to be live? Should HCTopUp's flag go to 0 to make its "off" contract true?** The doc-only fix (either direction) is held pending your intent.
> - 🐛 **Notable live bug staged (P2):** `AI_Commander_BaseSell.sqf` searches `WFBE_%1STRUCTURENAMES` (classnames) with a logical `wfbe_structure_type` key ("Barracks"/"Light"/…), so `find` returns −1 for **every** structure → the cost-based Pass-2 never fires and stranded structures get recycled for **0 refund / no live-count decrement**. Real (BaseSell is armed); fix = search `WFBE_%1STRUCTURES`; needs runtime proof.
> - 📋 Staged perf/behavioral: `DisbandLowTier` runs 2× `count allUnits` per foot team every 300 s (localise to a `nearEntities` query); Paratroops picks the "most-threatened" town by array order, not threat; Beacon O(vehicles) scan every 120 s. All soak-gated.
> - Rejected on verify: PlayerArty↔Strategy artillery double-fire (Strategy arty is hard-locked off); MHQReloc `_back` telemetry staleness (unreachable); Execute HC-flip latch (no live path re-homes a team's HC-ness mid-order).

---

## 4. Static release gate + parity — **PASS** (with 1 P1 parity item)

- **A2/OA compat: CLEAN.** Full-tree scan of both roots for 14 forbidden A3-only tokens found **zero** on any live line — every hit is a comment, a `diag_log`/hint string, or prose. Safe substitutes (`visiblePosition`, `set [count arr,v]`, literal world size, `typeName ==`) verified live.
- **Config/docs:** the "commander guide says AI removed" premise did **not** reproduce (it correctly documents the AI as active). Real doc mismatches were fixed this PR (§3 landed + below).
- **⚠️ P1 parity — `Client/GUI/GUI_Menu_Help.sqf` diverged:** Takistan still ships the **old** help-menu design while Chernarus has the redesigned 7-section controller. LoadoutManager did not re-sync it. **Owner decision needed:** treat Help.sqf as a per-map curated file (add to the mirror exclusion list) or factor the map-specific place names out to config so the controller body stays byte-identical. **Note:** the same class of issue affects `briefing.html` — the Takistan briefing currently contains Chernarus place names (Krasnostav, NWAF/NEAF/Balota, "…on Chernarus"); a proper Takistan localization pass is owed.

---

## 5. Performance / optimization

Constraints respected throughout: **no** sim/distance-gating of AI, **no** antistack changes, AICOM team size untouched.

### ✅ Landed
- Aligned the divergent dead `PC_LOW` team-count fallbacks (doc/robustness), see §3.

### 📋 Staged (confirmed, need A/B soak proof)
| Sev | Lever | File |
|---|---|---|
| P1 | **Empty-group churn:** town activation pre-creates one server-local group per merged roster *before* the delegation mode is known, then abandons them on the HC/client-delegate paths → transient groups race the 144/side cap until the 60 s GC reaps them. Fix: defer group creation to the server-AI path, or delete the empties on delegation. | `Server/FSM/server_town_ai.sqf:233-266` |
| P2 | **Merge consolidation headroom:** replace the hardcoded `>10` merge cap with a tunable (mirroring the defender path) and A/B raise `WFBE_C_TOWNS_MERGE_TARGET` 5→8 → fewer group-brains for identical unit counts. Ship via the existing `GCSTAT` telemetry. | `Server/Functions/Server_GetTownGroups.sqf` |
| P2 | Phasing: `AssignTowns`/`AssignTypes` re-derive town-census + per-team facts the `Snapshot` cached seconds earlier — flag-gated adoption of `wfbe_aicom2_snap` (freshness-guarded). | `AI_Commander_AssignTowns/AssignTypes/Snapshot.sqf` |
| P3 | Low-risk micro-opts flagged by the perf-scans verifier: `Common_AdjustViewDistanceTimerScript.sqf` busy-wait → single `sleep`; hoist side-independent `_basePcN` above the GC side loop. Both still want a smoke. | various |

> **Notes:** `WFBE_C_TOWNS_EAGER_GARRISON_COUNT` does **not** exist in this build (memory note is stale for the release worktree). Several perf-scan recon items were **rejected on verify** as already-implemented (AICOM already hoists `allUnits`/`allGroups`), **already-reverted** (the server_town scan-dedup caused capture wedges), or **stale** (`updateclient.sqf` does have `sleep 1`). Dead-code sweep: 3 audit Tier-1 items are already removed; a handful of true zero-reference files remain safe to delete (`Common_HandleATReloadVehicle.sqf`, `groupsMonitor.sqf`, `WASP/Init_Client.sqf`, `version.sqf.template`) — and the audit's `SaveTemplateProfile` "dead" claim is a **false positive** (it's LIVE; SQF `Call` shares caller scope). The `perf-scans` recon lane also stubbed — **re-run owed.**

---

## 6. Sources & external intake

- **Upstream `Miksuu/a2waspwarfare`: CLEAN — nothing to backport.** origin is 799 commits ahead; upstream's only 3 ahead-commits (town-defense diagnostics) are already content-identical on origin. Upstream HEAD is ~3 weeks stale. `Server/AI/Commander` confirmed ours-only (no baseline to diff).
- **Jerry bIdentify:** `WarfareV2_073LiteCO.zip` (`/file/5420`, SHA256 `212048b9…58e0a`, 1.65 MB, **available**) is the pristine Benny 0.73 Lite CO baseline our fork descends from — the primary reference for baseline diffing. ~80% of the warfare folder is MIA (Armaholic-sourced). Use the folder tree, not `/search`.
- **BI forums / A2-OA docs:** (1) the ~144-groups/side hard cap is the root cause of "Warfare AI goes passive after ~2h" — our `server_groupsGC` empty-group sweep + 130/144 RPT warnings are the correct, load-bearing mitigation (→ §1 soak watch). (2) A2 OA has **no** `setGroupOwner`/`setOwner` — HC AI ownership is lobby-seating only (matches the known WASP HC constraint). (3) JIP: `publicVariableClient` values are **not** re-synced on reconnect — enrollment state must be server-broadcast or re-derived on `Init_Client` (matches the known "joins with no team/money" class).
- Miksuu Drive dump (pw `armedassault`): enumeration remains gated; not required given upstream is clean.

---

## 7. Approval gates — will NOT do without explicit Ray approval

Launch Arma locally &middot; SSH to livehost &middot; copy/analyze private RPTs &middot; upload/replace live mission files &middot; restart server processes &middot; clear caches &middot; deploy/rollback. **Wiki fixes are staged only** (wiki pushes publish live) — see §9.

---

## 8. Changelog of this PR

- **2026-07-01 (a)** — Hub created; consolidated codex lanes #123–126; carried Ray's cmdcon33 fixes (`bcc6e3974`); isolated worktree off `origin/master`.
- **2026-07-01 (b)** — 24-agent recon + adversarial-verify pass completed. **Landed 11-file verified fix set** (`bb5721a01`): resolved the P1 AICOM double-fallback, 4 hygiene/robustness fixes, briefing economy/patrol + commander-guide doc corrections; mirrored to Takistan via LoadoutManager; static gate PASS. Full findings backlog recorded in §3–§6.

---

## 9. Staged wiki fixes (publish only after review — wiki push is live)

| Sev | Page | Fix |
|---|---|---|
| P1 | `AI-Commander-Tunable-Constants-Reference.md` | 7 wrong defaults (TEAMS_PC_LOW 12, MID 8, HIGH 5, FULL 3, LOWPOP_EXTRA 4, AIR_MIN_TOWNS 3, SUPPLY_RESERVE 1000); remove `WFBE_C_AICOM_UPGRADE_FUNDS_RATE` (no longer exists); fix supply-reserve semantics (research is supply-only now). |
| P2 | `Mission-Start-Parameters-Index.md` | STARTING_HOUR default 9→8; MAP_ICON_BLINKING_ENABLED 0→1. |
| P2 | `Quad-AI-Commander.md`, `AI-Commander-Autonomy-Audit.md` | promote AICOM verdict from "partial/latent" to "active/live" (supervisor+worker family is compiled + spawned). |
| P2 | `End-Of-Game-Stats-Victory-Screen.md` | winner payload no longer inverted since B67. |
| P3 | AICOM + Experimental refs pages | source line numbers ~600 off (file grew); re-anchor or drop the "exact line" claim. |
| — (gap) | new pages | **Command Console / War Room** (IDD 14000), **Victory Outro FX** (`WFBE_C_VICTORY_OUTRO_FX`), **player-facing AI Commander overview** (difficulty, hybrid takeover), player command-console knobs. |
