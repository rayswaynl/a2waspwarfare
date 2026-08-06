# Review: July-25 U3 trio (client-qol / territorial-hud / naval-rumor)

**Task:** `wasp-review-u3-trio-20260731`  
**Reviewer lane:** `grok-main-07311829-night` (grok)  
**Review type:** read-only worktree vs current `origin/master`  
**Date (UTC):** 2026-07-31  
**Confidence:** high on merge-overlap and flag presence; medium on behavioral intent of incomplete CMD_DEST_PREVIEW (no runtime smoke).

---

## Scope and method

Three sibling worktrees on shared base `639817de24` (`docs(wave-20260725): integration manifest…`, 2026-07-25), each holding **uncommitted** feature dirt only (no commits on the branch beyond the base). All three are **~690 commits behind** `origin/master` (`6a9f3994d6` at review time).

| Worktree path | Branch | Uncommitted | CH+mirrors stat |
|---|---|---|---|
| `C:/Users/Steff/build0725/client-qol` | `claude/u3-client-qol-20260725` | 16 modified | +355 / −19 |
| `C:/Users/Steff/build0725/territorial-hud` | `claude/u3-territorial-hud-20260725` | 6 modified | +171 / −6 |
| `C:/Users/Steff/build0725/naval-rumor` | `claude/u3-naval-rumor-20260725` | 12 modified + 3 untracked | +57 / −3 (+ new function file ×3) |

**Method (verified):**

1. `git status` / `git diff --stat` / CH-only `git diff` on each worktree (read-only; no stash).
2. `git fetch origin master` and content grep of `origin/master` for overlapping flags, functions, and callers.
3. GitHub PR state for merged U3 siblings (`gh pr view` 1420 / 1422 / 1382).
4. Structural completeness check of producers vs consumers in the uncommitted diffs.

**Not verified:** RPT/soak runtime, LoadoutManager regen, A2 engine probe of new paths, lint gate on the worktree dirt, and whether any human already discarded these worktrees after PR #1791 triage.

---

## Executive verdict

| # | Worktree | Verdict | Why (one line) |
|---|---|---|---|
| 1 | **territorial-hud** | **SUPERSEDED — discard worktree dirt** | Shipped as **PR #1422** (merged 2026-07-25); master has a **superior** server-snapshot countdown chip (`WFBE_TERRITORIAL_HUD`), currently armed default **1**. |
| 2 | **naval-rumor** | **SUPERSEDED — discard worktree dirt** | Shipped as **PR #1420** (merged 2026-07-25); master uses **inline** rate-limited `DashboardAnnounce` at the same two edges (no separate `Common_NavalTheaterRumor.sqf`). |
| 3 | **client-qol** | **SALVAGE (partial) as flag-gated draft PR** | Uncommitted dirt is **client-qol-batch3**, **not** the already-merged CMD team-status strip (#1382). Two complete sub-features + one **incomplete** sub-feature remain off master. |

**No draft PR should be opened from the territorial-hud or naval-rumor worktrees as-is** — they would re-introduce inferior / alternate designs of features already on master.

---

## 1) territorial-hud — SUPERSEDED

### Worktree intent (uncommitted)

- Flag `WFBE_C_TERRITORIAL_HUD` default **0** in `Init_CommonConstants.sqf`.
- RHUD reuses spare idc pair **[27,28]** for a "Territory:" chip.
- Content is **client-side standing only**: `west/east Call GetTownsHeld` vs `WFBE_C_VICTORY_TERRITORIAL_FRAC`, with labels like `WEST leads N/T` / `… SIEGE`.
- Explicit header comment: real minute clock is **not** available client-side because `WFBE_TERRITORIAL_CLOCK_<sid>` is server-local with no publicVariable.

### Master state (verified)

- Flag present: `WFBE_C_TERRITORIAL_HUD` (default **1** after wave arming; comment still says "default-off" but value is `1` in constants).
- Helper `_RHUDUpdateTerritorial` reads **server-authored** `missionNamespace` array `WFBE_TERRITORIAL_HUD` (`[sideId, endTime]`) and renders `Territory: <minutes>m <SIDE>`.
- Server path: `Server/FSM/server_victory_threeway.sqf` publishes the snapshot when flag > 0.
- Merged PR: **#1422** `feat(client-qol): territorial victory countdown chip` — merge commit path `a056db0045` / `49f4889faf`.

### Delta vs worktree

| Aspect | Worktree (U5 uncommitted) | Master (PR #1422+) |
|---|---|---|
| Data source | Client `GetTownsHeld` | Server snapshot `WFBE_TERRITORIAL_HUD` |
| Shows real countdown? | No (standing only) | Yes (remaining minutes) |
| Default | 0 | 1 (armed) |
| Design quality | Honest but weak HUD | Matches player need |

### Verdict

**SUPERSEDED / DISCARD.** Do not salvage the worktree standing-only chip. Master already owns the feature with better correctness. Worktree may be removed after owner ack of this review (hygiene only; this card does not delete worktrees).

**Follow-up fold card:** none for product. Optional hygiene: `worktree remove` for `build0725/territorial-hud` once owner accepts discard.

---

## 2) naval-rumor — SUPERSEDED

### Worktree intent (uncommitted)

- New `Common/Functions/Common_NavalTheaterRumor.sqf` + `Compile` in `Init_Common.sqf` as `WFBE_CO_FNC_NavalTheaterRumor`.
- Flags: `WFBE_C_NAVAL_THEATER_RUMOR` default 0; interval default **600** s; message strings `WFBE_C_NAVAL_RUMOR_USV_MSG` / `WFBE_C_NAVAL_RUMOR_CAP_MSG`.
- Call sites on existing rising edges only:
  - `Server_USVFlotilla.sqf` gate-open
  - `Init_NavalHVT.sqf` CAP arm (GUER-owned HVT)
- Broadcast via existing `DashboardAnnounce` / `WFBE_CO_FNC_SendToClients` (good pattern; no new PV).

### Master state (verified)

- Flag + interval present in constants (`INTERVAL` default **120** on master).
- **No** `Common_NavalTheaterRumor.sqf` on master.
- Inline implementation at the same two edges with local `_rumorLast` clocks and hard-coded / `Format` messages:
  - USV: `"Hostile small craft are active on the coast."`
  - CAP: `"Carrier CAP airborne near %1."` (includes HVT name)
- Merged PR: **#1420** `feat(naval): rate-limited theatre rumor announces on existing USV/CAP gates`.

### Delta vs worktree

| Aspect | Worktree | Master (#1420) |
|---|---|---|
| Architecture | Shared helper function | Inline at two call sites |
| Interval default | 600 s | 120 s |
| Configurable messages | Yes (constants) | Hard-coded / Format |
| Flag default | 0 | 0 |

Worktree is an alternate packaging of the **same product idea**, already shipped. Helper-extraction or configurable message strings are **not** present on master as residual work from this tree — if desired later, open a **new** micro-card from master HEAD, not a rebase of this dirt.

### Verdict

**SUPERSEDED / DISCARD.** Do not open a draft PR from this worktree.

**Follow-up fold card:** none required. Optional: if owner wants configurable rumor strings, new card from master (not this dirt).

---

## 3) client-qol — SALVAGE (partial)

### Important naming note

Branch name suggests the whole July-25 client-qol wave, but **uncommitted dirt is labeled `client-qol-batch3` in comments** and is **not** the CMD team-status strip already merged as **PR #1382** (`WFBE_C_CMD_TEAM_STATUS`).

### Sub-feature matrix (vs `origin/master`)

| Sub-feature | Flag / hook | Present on master? | Completeness in worktree | Salvage? |
|---|---|---|---|---|
| Towns tab SV + held floor | `WFBE_C_TOWNS_TAB_SV` default 0 | **No** | **Complete** (producer + UI) | **Yes** |
| Commander tools unused-nudge | reuses `WFBE_C_QOL_TRIO`; local `WFBE_QOL_CMD_TACTICAL_OPENED` stamp | **No** (this nudge) | **Complete** | **Yes** (under existing QoL master flag) |
| CMD dest-preview on MOVE | `WFBE_C_CMD_DEST_PREVIEW` default 0 | **No** | **INCOMPLETE** | **Only if builder finishes apply block** |

### Detail — TOWNS_TAB_SV (salvage)

Touches CH (+ mirrored dirt already in worktree; builder must re-mirror from CH only):

- `Client/GUI/GUI_Menu_TownsGarrison.sqf` — when flag on, each owned-town row shows `SV cur/max` and client-observed `held >=Xm`.
- Honest limitation documented in header: no server capture timestamp; local `WFBE_QOL_TOWN_HELD_SINCE` is a floor after first observation (JIP shows `<1m` initially).
- Uses already-client-readable `supplyValue` / `maxSupplyValue` (same data map markers use) — no new intel / PV.

**Master relation:** Towns garrison panel itself exists (PR #1321 / #1561); this is an **additive** flag-gated row enrichment, not a reimplementation of the panel.

### Detail — command/tactical open stamp + advisor nudge (salvage)

- `GUI_Menu_Command.sqf` / `GUI_Menu_Tactical.sqf`: on open, if `WFBE_C_QOL_TRIO > 0`, set local `WFBE_QOL_CMD_TACTICAL_OPENED = true`.
- `Client_QOL_Advisor.sqf`: after 20 min, if commander and stamp never set, one-shot tip about Command Console / Tactical Center.

Flag-off inert path: entire stamp + nudge gated on existing `WFBE_C_QOL_TRIO` (already default 1 on master — **note:** this is not a new default-0 feature flag; shipping the nudge will change live QoL behavior when TRIO is on). Owner may prefer a dedicated default-0 subflag; call that out in the draft PR.

### Detail — CMD_DEST_PREVIEW (do not ship as-is)

**Producer exists:**

- Constants: `WFBE_C_CMD_DEST_PREVIEW = 0`
- On MOVE order in Command Console: `WFBE_CMD_DEST_PREVIEW = [_team, _position, time + 4]`

**Consumer is stub-only:**

- `updateteamsmarkers.sqf` adds privates `_cmdPreviewMode/_cmdPreviewData/_cpPos/_cpDx/_cpDy` and reads the flag once per tick into `_cmdPreviewMode`.
- **No code path reads `WFBE_CMD_DEST_PREVIEW` or applies a marker direction from it.**  
  Verified by searching the whole Chernarus mission tree under the worktree for those tokens.

Shipping this would be a **flag that does nothing when on** (dead feature). Salvage only after completing the apply block (mirror the existing `_destDirMode` bearing idiom; TTL must expire).

### A2 OA notes (advisory; no engine probe)

- Diffs reviewed for obvious A3-only commands: none spotted in the added CH hunks.
- Uses `private ["…"]`, `&& {…}` lazy forms, `missionNamespace getVariable [name, default]` on non-group receivers — consistent with house style.
- TownsGarrison uses `private "_heldTxt33"` one-arg private form (valid A2).
- **Not run:** `Tools\Lint\check_sqf.py` on the worktree (read-only review card; builder lane owns lint).

### Rebase cost

Base is **690 commits** behind master. Files touched on master since base (RHUD, constants, TownsGarrison button ungating, etc.) mean salvage must be a **cherry-pick of intent onto fresh master**, not a blind commit of the worktree. Especially:

- Do **not** include territorial/naval dirt from sibling trees.
- Re-apply only CH files, then LoadoutManager mirror + template restore.
- Expect conflict risk in `Init_CommonConstants.sqf` (high churn).

### Verdict

**SALVAGE as flag-gated draft PR** for:

1. `WFBE_C_TOWNS_TAB_SV` (default 0) — Towns tab SV + held floor.  
2. Optional: cmd/tactical unused-tools nudge (either under `WFBE_C_QOL_TRIO` with owner awareness that TRIO is already on, **or** a new default-0 subflag).

**DROP from salvage set:** `WFBE_C_CMD_DEST_PREVIEW` until the marker apply path is written and verified.

---

## Recommended follow-up fold cards (survivors only)

These are **scoped builder cards** for a later claim (not claimed by this review lane).

### Card A — `wasp-client-qol-batch3-towns-sv-20260731` (ready-shaped)

- **Goal:** Draft PR: Towns garrison tab SV + held-floor duration, flag `WFBE_C_TOWNS_TAB_SV` default 0.
- **Source of intent:** uncommitted CH hunks in `build0725/client-qol` (`GUI_Menu_TownsGarrison.sqf` + constants registration).
- **Base:** fresh `origin/master` worktree (not the stale u3 tree).
- **Do:** re-author / port CH only → LoadoutManager → lint → draft PR body per GUIDE-REV `GR-2026-07-08a`.
- **Do not:** port CMD_DEST_PREVIEW stub; do not touch RHUD territorial or naval rumor.
- **Test plan sketch:** flag 0 → byte-identical Towns rows; flag 1 → owned towns show SV x/y and `held >=`; enemy towns still excluded.

### Card B — `wasp-client-qol-cmd-tools-nudge-20260731` (optional, owner pick)

- **Goal:** Commander tip when Command/Tactical never opened this session.
- **Decision needed:** ship under existing `WFBE_C_QOL_TRIO` (already default 1) vs new `WFBE_C_QOL_CMD_TOOLS_NUDGE` default 0.
- **Source:** `Client_QOL_Advisor.sqf` + open stamps in Command/Tactical menus.

### Card C — `wasp-cmd-dest-preview-finish-20260731` (blocked until design confirm)

- **Goal:** Complete marker apply for MOVE-order preview (or discard the sub-feature).
- **Blocker:** worktree is incomplete; needs full apply + TTL in `updateteamsmarkers.sqf`, conflict check vs `WFBE_C_TEAMMARKER_DEST_DIR` history (documented never-expire stamp bug — preview must use its own bounded record only).
- **Not ready** until a builder owns the missing consumer.

### Hygiene (non-product)

- After owner ack: remove or archive the three `build0725/{client-qol,territorial-hud,naval-rumor}` worktrees so they stop appearing as "real uncommitted work" in triage (related: open docs PR #1791 worktree triage).

---

## What this review could NOT verify

- Runtime HUD/layout collisions if someone re-applied the standing-only territorial chip on top of master (not recommended).
- Whether PR #1420/#1422 post-merge follow-ups changed flag arming beyond constants (only constants + call sites checked).
- Whether owner already decided discard via another board note after this card was queued.
- Lint cleanliness of the uncommitted dirt on the 690-behind base.
- Peach/console delivery of this report is recorded in the Fleet close evidence, not in this file body.

---

## Evidence anchors (paths / PRs)

- Worktrees: `C:/Users/Steff/build0725/client-qol`, `…/territorial-hud`, `…/naval-rumor` (read-only).
- Base: `639817de2406bfadfcbff376c1e426f0d39b2bc5`
- Master at review: `6a9f3994d68048de15febe6e401a6b36426bb3b1` (`origin/master`)
- Merged superseding PRs: [#1420](https://github.com/rayswaynl/a2waspwarfare/pull/1420), [#1422](https://github.com/rayswaynl/a2waspwarfare/pull/1422); related sibling [#1382](https://github.com/rayswaynl/a2waspwarfare/pull/1382)
- This report: `Docs/Proposals/wasp-review-u3-trio-20260731/REPORT.md`

---

## One-line owner summary

**Discard territorial-hud + naval-rumor (already on master, better/inline forms). Salvage only client-qol-batch3 Towns SV (+ optional tools nudge) as a fresh flag-gated draft from master; finish or drop the incomplete CMD dest-preview stub.**

*Verdicts are review-diversity input, not a final merge call.*
