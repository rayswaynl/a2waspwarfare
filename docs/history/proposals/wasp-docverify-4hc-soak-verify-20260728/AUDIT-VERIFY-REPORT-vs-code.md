# Doc-vs-code audit: `docs/Proposals/wasp-4hc-soak-20260726/VERIFY-REPORT.md`

| Field | Value |
| --- | --- |
| Task id | `wasp-docverify-4hc-soak-verify-20260728` |
| Auditor | `grok-main-07290000-12` (Grok) |
| Audit date (UTC) | 2026-07-29 |
| Target doc | `docs/Proposals/wasp-4hc-soak-20260726/VERIFY-REPORT.md` |
| Code root | `C:\Users\Steff\a2wasp-smlfix` (brief path typo `.ts` → actual `a2wasp-smlfix`) |
| Branch | `release/wasp-aicom-recovery-20260727` (tracking origin, already up to date) |
| HEAD | `2bcb0cf5e4d9966d081dca80aadad5b69cdab619` — Merge PR #1593 `fable/defense-fixes` |
| Method | **Static read-only** code verification only. No box RPT re-pull, no deploy, no mission edits. |
| Confidence | **High** for “does this source still match the doc’s code claims?” **None** for “is the 2026-07-26 live `_topNear` RPT failure still happening on box?” (not re-soaked). |

---

## 1. What the doc claims (summary in own words)

`VERIFY-REPORT.md` is a **read-only adversarial soak review** of live box build `dbg0726f` (Chernarus, ~0.22 h AICOM window, four HCs) against three merges that were ancestors of then-`origin/master` tip `70e4c23670`:

| PR | Topic | Doc verdict |
| --- | --- | --- |
| **#1473** | HC-name registry + `_topDefer` / `_topNear` seed before `WFBE_CO_FNC_RealPlayersNear` in top-up path | **FAIL** — legacy `_topdefer` strings gone, but HC2/HC4 still logged **`_topNear` undefined** after the call; top-ups still completed (`TOPUP_DONE`) |
| **#1471** | Destroyed-hull handling: AirResp / W13 / W22 must not instantly delete wrecks | **NOT PROVEN** — source branch conditions look right; soak never hit W13/W22 or correlated wreck retention |
| **#1474** | Group capture + debounced `TEAMCENSUS` telemetry | **PASS** — server RPT showed expected rows; founding gate is founded+pending+construction, not editor count |

Overall batch grade: **FAIL** (also analyzer ARRIVAL 0/12; short early-round sample). Follow-ups listed: fix/prove HC bundle for `_topNear`, shot-down flight correlation + W13/W22 coverage, longer soak at AI_TOT 330–430.

---

## 2. Claim-by-claim verification against CURRENT code

Legend: **IMPLEMENTED** = behavior still present (line may have moved). **PARTIAL** = part landed / part not. **DRIFTED** = code exists but differs from doc’s citation or meaning. **DEAD** = file/branch/build reference gone. **RUNTIME-UNVERIFIED** = code says fixed; live soak not re-run.

### 2.1 Meta / scope claims

| Doc claim | Status | Evidence |
| --- | --- | --- |
| Target `origin/master` tip `70e4c23670` (merge #1474); #1473 `23e40c7e`, #1471 `095fea39` are ancestors of that tip | **DRIFTED (historical)** | Those objects still exist in the object DB (`git cat-file -t 70e4c23670` → `commit`). On **this** checkout they are **not** merge-base ancestors of `HEAD` (`merge-base --is-ancestor … HEAD` exit 1 for all three PR merges). Content of the fixes is present via other history on `release/wasp-aicom-recovery-20260727`. |
| Live box serving `dbg0726f` | **DEAD / historical** | Mission folder in this tree is only `[55-2hc]warfarev2_073v48co.chernarus` — no `*_dbg0726f` folder. Doc is a point-in-time box observation, not a current deploy label. |
| Analyzer: `python Tools/Soak/analyze_soak.py …` | **IMPLEMENTED** | `Tools/Soak/analyze_soak.py` still present at repo root. |
| Read-only box review / no deploy | N/A (doc process claim) | Not re-validated; accepted as historical process note. |

### 2.2 #1473 — HC registry + top-up proximity seed

| Doc claim | Status | Current code |
| --- | --- | --- |
| `_topDefer = false` and `_topNear = -1` precede `RealPlayersNear` at `Common_RunCommanderTeam.sqf:2991-3001` | **IMPLEMENTED + DRIFTED (lines)** | Same pattern now at **`Common_RunCommanderTeam.sqf:3167-3170`**. Lines 2991–3001 are now abandoned-vehicle dismount logic, not top-up. Private list includes both names at **3121**. Comments at 3161–3166 document the 2026-07-26 seed fix. |
| `typeName _topNear == "SCALAR"` guard before defer | **IMPLEMENTED** | **3170**: `if ((typeName _topNear) == "SCALAR" && {_topNear > 0}) then {_topDefer = true};` |
| Four-HC registry in `Init_CommonConstants.sqf:3184-3200` | **IMPLEMENTED + DRIFTED (lines)** | Registry is now **`Init_CommonConstants.sqf:3316-3332`**: `WFBE_C_HC_SLOTS` default 4 + derived `WFBE_C_HC_NAMES` (`HC` + `HC-AI-Control-1..N`). Lines 3184–3200 are now HCREG/orphan-heal / AICAP trim — unrelated. |
| Consumed by `Common_RealPlayersNear.sqf:42-49` | **IMPLEMENTED (minor line drift)** | **46–49** read `WFBE_C_HC_NAMES` with complete 4-HC fallback list. Lines 42–44 still HC-group unit collection. File is 58 lines; still returns **SCALAR** only (early `exitWith {0}`). |
| `WFBE_CO_FNC_RealPlayersNear` registered for all machines | **IMPLEMENTED** | `Init_Common.sqf:105` — **backslash** path `Common\Functions\Common_RealPlayersNear.sqf` (critical: historical commit `e0a4058250` documents that a **forward-slash** path caused “Script … not found”, nil function, and mass `_topNear` / `_pnear` undefined errors). |
| Soak: zero legacy `_topdefer` tokens; HC2/HC4 still `_topNear` undefined then `TOPUP_DONE` | **RUNTIME-UNVERIFIED** (historical FAIL) | **Code path for undefined `_topNear` after a failed Call is closed in source** (private + seed + typeName guard). Whether box still shows the error depends on deploy/build; **this audit did not re-read HC RPTs**. Confidence that **current source** still reproduces the old undefined-var cascade: **low**. Confidence that a **missing/nil RealPlayersNear** would still break proximity defer (silently treat as “no player nearby” via seed -1): **medium-high** — soft-fail, not hard abort. |

**Highest-value finding for #1473:** The doc’s **FAIL is still the correct historical soak verdict**, but agents must **not** treat “current master still has live `_topNear` undefined” as proven. The **missing-script** warnings the doc logged on HC1/HC3 line up with the later RealPlayersNear path-separator root cause; current tree uses backslash registration.

### 2.3 #1471 — AirResp / W13 / W22 wreck handling

| Doc claim | Status | Current code |
| --- | --- | --- |
| AirResp only deletes live `_h` (`AI_Commander_AirResp.sqf:330-334`) | **IMPLEMENTED** (lines stable) | **330–334**: `if (alive _h) then { delete crew; deleteVehicle _h; deleteGroup }`. Long comment block 309–329 documents DESPAWN vs DESTROYED (2026-07-26). |
| W13 deletes after 90s only if live (`AI_Commander_Wildcard.sqf:913-927`) | **IMPLEMENTED** (lines nearly stable) | Spawn block **913–927**: `sleep 90` then **`if (alive _heli)`** before delete. |
| W22 deletes after 180s only if live (`:1152-1163`) | **IMPLEMENTED** (lines nearly stable) | **1152–1163**: `sleep 180` then **`if (alive _pl)`**. |
| Generic cleanup owns surviving server-local flights (`server_groupsGC.sqf:508-520`) | **DRIFTED (citation meaning)** | **508–520** are now **comments** on the heli-husk reaper scope (explicitly **does not** tag AirResp/W13/W22; those are server-local → generic TrashObject). Actual heli reaper body starts ~**529+**. Claim “generic pipeline owns destroyed server-local hulls” remains **IMPLEMENTED** via killed-EH → TrashObject narrative in AirResp/W13 comments. |
| Soak: no W13/W22 / wreck-correlation → NOT PROVEN | **Still true as methodology** | Source conditions remain correct; **no new runtime proof** in this audit. Doc’s NOT PROVEN is **not wrong** — it is **still open for runtime**. |

### 2.4 #1474 — TEAMCENSUS + founding gate

| Doc claim | Status | Current code |
| --- | --- | --- |
| Capture outer group before unit count; emit debounced TEAMCENSUS (`AI_Commander_Teams.sqf:53-65,77-118,132-134`) | **IMPLEMENTED + DRIFTED (lines)** | Outer `_grp` capture: **112–118**. Census rows / emit: **99–132**, **169–171** (`diag_log ("TEAMCENSUS|…")`). Lines 53–72 are now scan-chunk helpers, not census. |
| Default `WFBE_C_AICOM_C3_TELEMETRY=1` permits it | **IMPLEMENTED** | `Init_CommonConstants.sqf:335` — default **1**. Gate at Teams **99**: `(getVariable [..., 0]) > 0` plus 300s debounce. |
| Founding gate `founded + pending + construction >= target` (`:402-408`) | **IMPLEMENTED + DRIFTED (lines)** | Now **`AI_Commander_Teams.sqf:446`**: `if ((_foundedTeams + _pending + _constructionPending) >= _target) exitWith {…}`. Editor count still log-only (comments 90–94). |
| Soak PASS with sample TEAMCENSUS rows | **Historical only** | Not re-soaked. Emitter still present. |

### 2.5 Performance / analyzer FAIL section

| Doc claim | Status | Notes |
| --- | --- | --- |
| Analyzer whole-window FAIL; ARRIVAL 0/12; short 0.22 h sample | **Historical** | No contradiction possible from source alone. |
| Follow-up needs longer soak + peak AI_TOT | **Still valid process advice** | Not a code claim. |

---

## 3. Factually wrong / misleading for agents (highest value)

1. **Line numbers are largely stale.** Treating `Common_RunCommanderTeam.sqf:2991-3001` or `Init_CommonConstants.sqf:3184-3200` as the HC/top-up sites will send agents into the wrong blocks. Current anchors are listed above.
2. **Do not restate “HC2/HC4 `_topNear` undefined is still live” as a current code fact.** That was a **2026-07-26 box observation**. Current source seeds `_topNear`, registers RealPlayersNear with a PBO-safe path, and type-checks the return. **Runtime re-soak is required** to close the FAIL; static code says the hard abort path is gone.
3. **`dbg0726f` is not a current tree mission name** in this checkout. Cite it only as historical box build id.
4. **`server_groupsGC.sqf:508-520` is no longer “the generic cleanup body”** — it is commentary adjacent to the commander attack-heli wreck reaper. Relying on that line range as “proof of generic GC logic” misleads.
5. **PR merge SHAs are not ancestors of this recovery branch HEAD**, even though equivalent fix content is present. Agents doing `git merge-base --is-ancestor 70e4c23670 HEAD` on this branch will get a false negative if they equate “PR SHA on branch” with “fix content present.”

---

## 4. Is the `_topNear` failure “still live”?

| Layer | Verdict | Confidence |
| --- | --- | --- |
| **Source (this HEAD)** | Hard undefined-variable cascade from top-up proximity probe looks **closed** (seed + private + SCALAR guard + RealPlayersNear always returns number if the function body runs + backslash compile path). | **High** |
| **Soft failure if RealPlayersNear is still nil/missing on a misbuilt PBO** | Proximity defer degrades to “spawn anyway” (`_topNear` stays -1); should **not** spam `_topNear` undefined. | **Medium-high** |
| **Live box right now** | **Not verified** in this task (read-only doc audit; no HC RPT window). | **N/A** |

So: the doc’s FAIL remains a valid **historical** batch gate; for **current code**, the #1473 **code** side of follow-up item 1 appears landed; **soak re-grade is still open**.

---

## 5. Doc keep / status / archive verdict

**Verdict: KEEP, but add a status header — do not archive.**

Reasons:
- It is the only compact adversarial record of the `dbg0726f` 4-HC window tying #1473/#1471/#1474 to real RPT symptoms (especially the “string substitution is not a pass” lesson on #1473).
- #1471’s **NOT PROVEN** and the short-window performance FAIL remain process-true until a longer correlated soak.
- Leaving it unlabeled as current will **mislead** agents into reopening fixed line citations and assuming live `_topNear` undef as present-day code.

**Suggested status header** (for a human/editor; this audit does **not** edit the target doc):

```markdown
> STATUS (2026-07-29 static re-verify, task wasp-docverify-4hc-soak-verify-20260728):
> Historical FAIL soak of dbg0726f remains valid evidence.
> Code-side anchors for #1473/#1471/#1474 still present on release/wasp-aicom-recovery-20260727 @ 2bcb0cf5e4
> but line numbers in this doc are STALE; see Docs/Proposals/wasp-docverify-4hc-soak-verify-20260728/AUDIT-VERIFY-REPORT-vs-code.md.
> Runtime re-soak of four-HC current-MISSINIT still required before treating #1473 as soak-PASS.
```

---

## 6. What this audit could NOT verify

- Any live HC/server RPT after 2026-07-26.
- Whether the box currently runs a build containing the backslash RealPlayersNear registration and the seed block.
- W13/W22 dispatch frequency or wreck object-id correlation end-to-end.
- Whether `origin/master` tip (not this recovery branch) differs in any of the cited sites (this audit is bound to the brief’s branch/checkout).
- Config ground truth under `C:\Users\Steff\arma2-co-config-reference` was not required for the named SQF claims and was not loaded.

---

## 7. Provenance

| Item | Value |
| --- | --- |
| Target doc path | `C:\Users\Steff\a2wasp-smlfix\docs\Proposals\wasp-4hc-soak-20260726\VERIFY-REPORT.md` |
| This report (scratch) | `C:\Users\Steff\fleet-lane-scratch\Docs\Proposals\wasp-docverify-4hc-soak-verify-20260728\AUDIT-VERIFY-REPORT-vs-code.md` |
| This report (co-located copy) | `C:\Users\Steff\a2wasp-smlfix\docs\Proposals\wasp-docverify-4hc-soak-verify-20260728\AUDIT-VERIFY-REPORT-vs-code.md` |
| Repo HEAD | `2bcb0cf5e4d9966d081dca80aadad5b69cdab619` |
| Mission source root | `Missions/[55-2hc]warfarev2_073v48co.chernarus/` |
| Key files read | `Common_RunCommanderTeam.sqf`, `Common_RealPlayersNear.sqf`, `Init_Common.sqf`, `Init_CommonConstants.sqf`, `AI_Commander_AirResp.sqf`, `AI_Commander_Wildcard.sqf`, `AI_Commander_Teams.sqf`, `server_groupsGC.sqf` |

**MILESTONE shape for close:** owner-facing report artifact (this file).
