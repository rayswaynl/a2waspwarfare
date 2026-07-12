# SOAK-RUNSHEET — 3 soak build configs (FORTIF / CTL / RC)

**Status:** PRE-FLIGHT C staging only. Nothing below has been packed, transferred, or
deployed. All three configs are staged up to (not including) the pack step, per the
SOAK-PREP task scope. This runsheet is the exact remaining command sequence —
fill in the owner-only steps (marked ⚠ OWNER) before executing.

Source: `W:\Mijn vualt\Fleet\Docs\LAUNCH-PLAYBOOK-2026-07.md` §3 (Soak Program),
§3.1 sequence, §3.2 gates. Cross-reference that doc for the full gate/verdict
language — this sheet is the mechanical command list only.

---

## 0. Build-identity precondition (read before using this runsheet)

The Main-PC checkout at `C:\Users\Steff\a2waspwarfare` was found dirty and 454
commits behind `origin/master` during this same SOAK-PREP pass (see
`C:\Users\Steff\a2waspwarfare-quarantine\main-checkout-914cc31c1\PROVENANCE.md`).
**Do not build any soak PBO from that checkout as-is.** This runsheet's commit
SHAs and validation runs were captured from a clean worktree
(`C:\Users\Steff\a2waspwarfare-soakprep`, branch `fable/soak-prep-preflight-20260713`)
created fresh from `origin/master` — use that worktree, or an equally clean fresh
checkout/worktree of the same SHA, for the actual pack step. Do **not** use the
dirty main checkout until the owner has ruled on it per the PROVENANCE.md table.

Also note (same pass): **no current worktree, `.claude/worktrees/*` entry, or the
Main-PC's local ArmA2 install has a 2-HC-configured Chernarus `mission.sqm` that is
also current with `origin/master`.** The tracked/master Chernarus `mission.sqm` has
**zero** `forceHeadlessClient` entries (confirmed: `grep -c forceHeadlessClient` on
both the worktree here and `origin/master`'s own blob = 0). Every mission.sqm with
2 `forceHeadlessClient=1` entries found on this machine is stale (weeks behind,
predates the CTL/FORTIF/AICOM-V2 flags) — see the SOAK-PREP report's "TRUE 2-HC
mission" finding. **This means: as of today, there is no ready-to-pack 2-HC
Chernarus mission at current master.** This is a code gap, not a packing gap, and
is called out explicitly in the playbook (§3.1 PRE-FLIGHT A: "If none exists
cleanly, this is a code task, not a soak task — surface to owner before
freezing"). The FORTIF and CTL soak configs below can still be staged/built
against the *current* mission.sqm (0 HC — matches how the box is already running
today, single-instance, no HC split) but will NOT exercise 2-HC-specific code
paths; the RC soak (§3.1, cut at the 07-20 freeze) is where a real 2-HC mission.sqm
must exist before that freeze — **flag to owner now**, not at freeze time.

---

## 1. The three configs

| Config | Base commit | What differs from master | Status |
|---|---|---|---|
| **(a) FORTIF** | `cf8d83040a297cfc1fc84f0621a774c49227f594` (`origin/master` tip as of 2026-07-13, "fix(lane364): add AICOM posture reason telemetry (#1073)") | Nothing — current master as-is. `WFBE_C_DEF_FORTIF_PACK` is already armed (=1) on this commit per Go/No-Go gate 2. | Ready to pack from this SHA once the owner clears the 2-HC-mission gap above (or explicitly accepts a non-HC FORTIF soak). |
| **(b) CTL** | Same base (`cf8d83040`) **+ local-only patch**, never committed | `Tools/Soak/staged/SOAK-ONLY-NEVER-COMMIT-ctl-lane-flip.patch` flips `AICOMV2_LANE_CMD_TOWN_LEDGER` 0→1 in `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf` line 2679. This is a soak-only override of the owner's 2026-07-09 DISARM ruling (see the flag's own inline comment) — apply it locally for the CTL soak build, grade, then **discard the patch** (never `git add`/commit it). | Patch file staged, verified to apply cleanly and revert cleanly against `cf8d83040` (round-tripped during this pass). Not yet applied for a real build. |
| **(c) RC** | Not yet knowable — "full Phase-2 flagged feature set frozen at 07-20 on the resolved 2-HC Chernarus mission" (playbook §3.1) | N/A until the 07-20 code freeze | Cannot be staged yet by design — this is a future step, included here only so the command sequence below is complete. |

### Applying / reverting the CTL patch (soak-only, do this in a disposable worktree)

```powershell
cd C:\Users\Steff\a2waspwarfare-soakprep   # or a fresh worktree at the same SHA
git apply Tools\Soak\staged\SOAK-ONLY-NEVER-COMMIT-ctl-lane-flip.patch
# ... build/pack the CTL PBO from this dirty worktree ...
git checkout -- "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"
git status --porcelain   # must be clean before doing anything else in this worktree
```

**Never `git add` or commit while this patch is applied.** If a PR ever needs to
touch this area, edit it as a fresh, separate, properly-flagged change — this patch
exists only to produce one soak-test binary.

---

## 2. Validation already run (this pass, against `cf8d83040`, clean worktree)

| Check | Command | Result |
|---|---|---|
| LoadoutManager mirror drift | `cd Tools\LoadoutManager && dotnet run -c RELEASE -- --check` | **PASS** — `Takistan drift: none (mirror check passed)`, `Zargabad drift: none (mirror check passed)`. (Only compiler warnings, no drift findings.) |
| Lint gate | `python Tools\Lint\check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index` | **204 pre-existing findings** (all `A3MARKER`, e.g. `Common_ModifyVehicle.sqf`, `Server_HandleBuildingDamage.sqf` on Zargabad) — matches the playbook's LOOP-CLOSE reconciliation figure exactly ("lint: 204 pre-existing findings, zero new"). No new findings possible here since no mission-code file was actually modified (the CTL flip was applied-and-reverted only to produce the patch). |

Both checks were run against the same clean worktree used to record the SHA above
(`C:\Users\Steff\a2waspwarfare-soakprep`), NOT the dirty main checkout — see §0.

---

## 3. Heartbeat poller

Staged alongside this file: `Watch-SoakHeartbeat.ps1` + `SOAK-HEARTBEAT-INSTALL.md`.
Install and smoke-test it (Game PC, per its own install doc) **before** starting
any of the soaks below — it is the only thing that will notice a mid-soak crash,
since the NSSM crash-recovery gap (Go/No-Go gate 9) means the service will not
restart itself.

---

## 4. Exact remaining commands per soak (playbook §3.1/§2.1, mechanical steps only)

These are the same steps for FORTIF, CTL, and (later) RC — only the source
commit/patch state changes per §1 above. ⚠ OWNER markers = steps this lane cannot
execute (live-box or credential-touching or first-time-procedure items).

### 4.1 Pack (folder → `.pbo`)

⚠ **OWNER-VERIFY — this is the confirmed launch blocker, not a solved step.**
SOAK-PREP's tooling hunt (see the accompanying report) found:

- **No packing tool or command is documented anywhere in this repo** (`AGENTS.md`,
  `docs/`, `CLAUDE.md` — searched; nothing found). `docs/ops/deploy-v2.ps1` (the
  real, working deploy script) *assumes* already-packed `.pbo` files exist in
  `C:\WASP\incoming\` — it does not pack them.
- A **working, generic pack script exists but is unmerged**:
  `Tools/PrTestHarness/Experital/Pack-WaspExperital.ps1` on branch
  `tools/reusable-pr-test-harness` (not on `master`). It auto-detects
  `cpbo.exe`/`armake2.exe`/`MakePbo.exe` on PATH (or via `-PboToolPath`), stages the
  mission folder under the PBO's required internal name, and packs. **None of
  those three external tools were found installed anywhere searched on the Main
  PC** (Arma 3 Tools, BI Tools 2, armake2 — all absent). This script targets the
  experimental `WASP_Experital_TEST.Chernarus` name, not the 3 real launch
  mission names — it is a *pattern* to adapt, not a ready-to-run command.
- **The Game PC's history shows the ACTUAL historical method**: dozens of
  one-off, per-build Python scripts named `_pack_ch_<tag>.py` / `_pack_tk_<tag>.py`
  in `C:\Users\Game\` (most recent: `_pack_ch_cmdcon41c.py` / `_pack_tk_cmdcon41c.py`,
  2026-07-02) — each is a **hand-rolled, from-scratch Arma 2 PBO binary writer in
  plain Python** (no external tool at all: it manually builds the PBO header,
  `prefix` property, file entry table, and trailing SHA1, per the uncompressed A2
  PBO format). This is almost certainly "how Steff's binaries are actually made."
  **But**: (1) it is 100% outside version control — lives only as scratch files on
  the Game PC; (2) each copy hardcodes that build's own paths/tag (`MDIR`, `OUT`,
  `BUILD`, `PREFIX`) — there is no generic, parameterized version; (3) it stopped
  being used at `cmdcon41c` (2026-07-02) — the more recent RC30/RC31 builds (last
  verified box state, 07-08) have **no matching `_pack_*` script at all** on the
  Game PC, meaning even this ad hoc method wasn't used (or wasn't captured) for the
  most recent builds. **Confirm with Steff directly which of these (if either) is
  the real procedure before relying on it for the soak or the 1.0 release pack.**
- Suggested owner-facing question: *"For the last RC30/RC31 Zargabad soak
  (2026-07-08), how was the `.pbo` actually produced — by hand, by one of the
  `_pack_ch_*.py`-style scripts, or some other tool/process not found in this
  search?"*

Once the owner confirms a method, the missing piece to fill in here is a single
parameterized pack command/script for the 3 launch missions (Chernarus, Takistan,
Zargabad) — building on whichever of the two candidates above the owner picks.

### 4.2 Transfer

```powershell
# Main PC -> Game PC -> livehost, exactly as playbook step 13 (nested-SSH gotcha:
# plain scp only, no pipes/`;` across the 2-hop)
scp <buildtag>-ch.pbo <buildtag>-tk.pbo <buildtag>-zg.pbo gamingpc:C:/Users/Game/wasp-release/
ssh gamingpc "scp C:\Users\Game\wasp-release\<buildtag>-*.pbo livehost:C:\WASP\incoming\"
# Confirm all 3 land, each >5MB (deploy-v2.ps1 hard-aborts otherwise):
ssh gamingpc "ssh livehost dir C:\WASP\incoming"
```

### 4.3 Deploy

⚠ **OWNER — live-box action, needs an explicit go per soak run.**

```powershell
# empty-server confirmation first (pgate aborts otherwise unless -Force):
ssh gamingpc "ssh livehost sc query Arma2OA-PR8"
# then, per playbook step 16 — via WaspServiceRestart / deploy-v2.ps1 ONLY, never
# hand-roll stop/replace/start:
ssh gamingpc "ssh livehost powershell -NoProfile -File C:\WASP\deploy-v2.ps1 -BuildTag <tag> -ActiveMap ch"
```

Start the heartbeat poller (§3) immediately before this step; stop it after grading.

### 4.4 Sampling (during the soak)

Sample err/fps/ai-count every ~10min (PR #1056 harvest format) via the existing
monitor tooling:

```powershell
# windowed RPT pull (scopes to the current MISSINIT):
.\Tools\Monitor\Get-WindowedRpt.ps1 -RptPath <path-to-live-RPT>
# live AICOM2/DECAP watch (optional, human eyes-on):
.\Tools\PrTestHarness\Ops\aicom-watch.ps1
```

### 4.5 Grade

```powershell
python Tools\Soak\analyze_soak.py arma2oaserver.RPT ArmA2OA.RPT
.\Tools\PrTestHarness\Aicom\Score-AicomRounds.ps1 -RptPath arma2oaserver.RPT -MaxErrors 20
```

Record the verdict against §3.2 Gates 1/2/3 (playbook) in a soak-log addendum
(not created by this lane — the owner/next lane logs the actual run's numbers
here once a soak is actually executed).

---

## 5. What this runsheet does NOT cover

- The actual pack step's exact command (§4.1) — owner-verify first.
- Executing any of the 3 soaks — this is prep/staging only.
- The RC build's source commit (not cuttable until the 07-20 freeze).
- Resolving the 2-HC-mission gap (§0) — flagged, not fixed, by this lane.
