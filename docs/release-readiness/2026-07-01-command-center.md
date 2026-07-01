# 2026-07-01 Command-Center Release Readiness

This is the public-safe coordination task for the Chernarus and Takistan release
candidate on `codex/release-command-center-20260630`.

## Current Candidate

- Candidate: `release-command-center-20260630`
- Branch: `codex/release-command-center-20260630`
- Draft PR: `https://github.com/rayswaynl/a2waspwarfare/pull/125`
- Current package identity: `b4628c35afeef15a1703021e6171706a949e5afa` / marker `b4628c35af`, `_MISSIONS.7z` SHA256 `FA7E07C6D8A02C0574E619C54BB61FC0D6244D3559F2C15428B3BEADD9169A54`, `1,881` entries, `7,158,447` bytes.
- Package status: package provenance must pass after each release-identity refresh; handoff status should be `ready_for_runtime_collection` before runtime RPT collection.
- Runtime status: pending explicit runtime approval, fresh dual-terrain RPT packet, and deploy approval

Expected runtime markers use the current short release git:

```text
WASPRELEASE|v1|candidate=release-command-center-20260630|git=<current-short-git>|terrain=chernarus
WASPRELEASE|v1|candidate=release-command-center-20260630|git=<current-short-git>|terrain=takistan
```

## Multi-Agent Task Split

| Role | Scope | Current verdict |
| --- | --- | --- |
| AICOM scout | Commander core, HC delegation, AICOM telemetry, buy-unit/marker proof | Code path is ready for runtime evidence; do not merge `origin/claude/command-center-instruct` blindly because it would reintroduce command-dialect drift. |
| Release/RPT scout | Package, handoff, runtime packet, final static gates | Round-40 artifacts were stale after the role-proof commit; refresh package/handoff after every new source commit. |
| Wiki/source scout | Public wiki status, source-intake discipline, BI docs | Wiki should stay runtime-pending and sanitized; add source-intake discoverability before publishing broad release claims. |
| Branch intake scout | Open PRs, local worktrees, candidate cherry-picks | AICOM v2, commander cache, PR #120, most PR #122 content, and newer harness gates are already included or superseded. PR #109 is the only plausible gameplay intake, and should stay explicit/deferred. |
| Merge-gate scout | PR #125 reconciliation with `origin/master` | Build83/cmdcon35 is now reconciled into PR #125 at `b4628c35af`; GitHub reports the draft PR clean/mergeable. Keep future master drift explicit and package-gated rather than merging blindly during runtime evidence collection. |

## 2026-07-01 Agent Loop Update

- Continued draft PR #125 instead of opening a duplicate release PR; this branch remains the command-center release-readiness lane.
- Code scout found the fork's AICOM layer is the largest delta from `Miksuu/a2waspwarfare`; town runtime scans and AICOM allUnits/allGroups scans remain the main later optimization surfaces.
- External-source scout confirmed Jerry/bIdentify and `Miksuu/a2waspwarfare` are reachable, with `WarfareV2_073LiteCO.zip` the best public Benny 2.073 lineage baseline; Google Drive archive enumeration, direct stats backend and SSH/RPT access remain blocked without interactive approval/session context.
- Wiki scout confirmed Chernarus and Takistan pages exist but need release-facing freshness wording, exact dual-terrain RPT status, and generated Takistan parity notes before runtime-proven claims.
- Applied a small AICOM HC-dispatch bookkeeping fix: pending-slot age now starts at dispatch and clears when HC creation acknowledges or fails before registration. This makes `HCDISPATCH_REAP` measure actual dispatch age instead of delayed scan age.
- Darkened `WFBE_C_AICOM_HC_TOPUP_ENABLE` back to `0` because the top-up worker is still draft-only and lacks the live HC-side refill consumer. The safer group-count merge lever remains separately opt-in.
- Reduced repeated AICOM founding scans by snapshotting `allUnits`/`allGroups`/`vehicles` once per `AI_Commander_Teams` decision and reusing those snapshots for player scaling, safe-retire checks, side-AI cap, group-cap checks, and attack-heli/artillery cap checks.
- Removed the last AICOM `find` ambiguity review items from `AI_Commander_Base.sqf` by replacing scaffold structure lookups with an explicit A2-safe local index helper.
- Added a static runtime-proof emitter contract to the smoke gate so AICOM, HC/delegation, town cleanup, group-budget, supply, artillery and Takistan WEST fallback source tokens cannot disappear before the runtime RPT phase.
- Synced the Takistan in-game Help menu to the redesigned controller while keeping Takistan-specific airfield and premium-unlock anchors (`Loy Manara`, `Rasman AF`).
- Hardened town-AI HC delegation mode so stale/dead HC registry groups no longer suppress server-side fallback town-unit creation.
- Strengthened `Run-WaspFinalCheck.ps1` so the final pre-test gate now runs whole-root A2/OA compatibility lint for both Chernarus and Takistan, in addition to smoke and HIGH BugHunt; the smoke gate's changed-file dialect scan now covers both maintained mission roots.
- Debounced repeated group-cap diagnostics: `GRPBUDGET|WARN` is edge-triggered with `GRPBUDGET|RECOVER`, AI Commander founding cap warnings are throttled to once per side per 15 minutes, and lower-level create-group/create-team cap failures report once per side/machine every five minutes.
- Reduced repeated AICOM Strategy town scans by consuming the freshly published `wfbe_aicom2_snap` town census in `AI_Commander_Strategy.sqf`, with the old live `towns` scan kept as fallback. Spearhead scoring/debug and the optional commander-artillery support-town guard now reuse the same per-tick owned/capturable town arrays.
- Hardened the PVF dispatch shape checks before handler selection and routed remaining active AICOM group receiver reads through the existing OA-safe group-variable helper. The stale `aicom-focus`, `aicom-defend`, and `aicom-reinforce` command cases now require the human-commander requester/team validation used by the live command-console actions.
- Current `origin/master`/Build83 cmdcon35 has been reconciled into this PR while preserving the release harness, HCTopUp draft exclusion, AICOM/PVF authority hardening and the active AICOM executor latch reset.
- Runtime status is unchanged: not release-ready until an exact ten-file Chernarus/Takistan RPT packet passes the packet validator and release scorer.

## Proven Static And Package Gates

- `dotnet run` from `Tools\LoadoutManager` must complete and leave no unintended tracked source diff.
- Latest static validation at `b4628c35af`: the AICOM group/latch smoke guard passes; the remaining static smoke failures are the known RHUD/stress active-copy local prerequisites; Chernarus and Takistan `Tools\PrTestHarness\Smoke\Lint-A2Compat.ps1` each passed with `FAIL 0`, `REVIEW 1` for the known array `find "Aircraft"` heuristic; whole-mission HIGH BugHunt is clean.
- `Tools\PrTestHarness\Smoke\Test-WaspStaticSmoke.ps1` includes the `Release runtime-proof token emitters` source contract. This proves emitter strings are present for the runtime scorer, not that runtime evidence has passed.
- `Tools\PrTestHarness\Package\Test-WaspReleasePackage.ps1` must pass against `_MISSIONS.7z` with expected candidate `release-command-center-20260630` and the current `git rev-parse --short=10 HEAD`.
- `Tools\PrTestHarness\Release\New-WaspReleaseHandoff.ps1` must pass against the current package manifest.
- `Tools\PrTestHarness\Release\Test-WaspReleaseHandoff.SelfTest.ps1`
- `Tools\PrTestHarness\Rpt\Test-WaspRuntimeRptPacket.SelfTest.ps1`
- `Tools\PrTestHarness\Rpt\Test-WaspReleaseRptEvidence.PerTerrainSelfTest.ps1`
- `Tools\PrTestHarness\Run-WaspFinalCheck.ps1` now covers static smoke, whole-root Chernarus/Takistan A2/OA lint, and whole-mission HIGH BugHunt.

Package self-test is expensive because it mutates archive fixtures; rerun it before final deploy handoff if the package or package validator changes.

## Remaining Release Gates

1. Get explicit approval before local Arma launch, SSH collection, live upload, restart, or deploy.
2. Collect exact ten-file runtime RPT packet for both terrains: server, HC1, HC2, start-client, late-JIP.
3. Validate `runtime-rpt-packet-manifest.json` with matching candidate/git/archive SHA and required validator gates exactly once.
4. Produce redaction-safe runtime summary bound to the same package identity and RPT root hashes.
5. Prove runtime semantics: startup markers, role proof, HC registry/delegation, AICOM heartbeat/stat/snapshot/team founding, town cleanup, WDDM/static/artillery, supply workflow, JIP/HUD, and Takistan WEST infantry fallback.
6. After runtime pass, update the wiki from runtime-pending to runtime-proven with sanitized evidence only.
7. Get deploy approval, then capture live placement, restart, rollback, and server stats proof.

## Source Intake Lanes

- Main repo: `rayswaynl/a2waspwarfare`
- Original running mission repo: `Miksuu/a2waspwarfare`
- Public wiki: `https://github.com/rayswaynl/a2waspwarfare/wiki`
- Jerry file library: `https://bidentify.jerryhopper.com/files`
- Jerry OA Warfare bucket: `https://bidentify.jerryhopper.com/files/arma2oa/scenarios/mpgamemodes/warfare`
- BI Arma 2 OA command docs: `https://community.bohemia.net/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands`
- BI Warfare BE forum thread: `https://forums.bohemia.net/forums/topic/131145-warfare-be/`
- BI WASP forum threads:
  - `https://forums.bohemia.net/forums/topic/184178-mpcti-wasp-warfare-rhs-edition/`
  - `https://forums.bohemia.net/forums/topic/234844-mpcti-warfare-missions-wasp-edition/`
- Miksuu Drive mission dump: inventory and compare only with explicit source-handling discipline; do not publish passwords, raw private archive contents, or unsourced claims.
- Server stats and RPTs: use sanitized summaries only; do not publish raw private paths, IP/UID details, credentials, or ops commands.

## Wiki Update Plan

- The release source-intake page is linked from the wiki sidebar and July readiness page; remaining source-intake work is per-source cards for Jerry, Miksuu dump/repo deltas, and BI forum evidence.
- Keep public wiki claims labeled `runtime-pending` until exact RPT packets pass.
- Update `Current-Source-Status-Snapshot.md`, `Agent-Release-Readiness-Ledger.md`, `Testing-Debugging-And-Release-Workflow.md`, `Progress-Dashboard.md`, `Arma-2-OA-Command-Version-Reference.md`, `Arma-2-OA-Compatibility-Audit.md`, and `External-Arma-2-OA-Reference-Index.md`.
- Treat BI command pages as the source of truth for command availability. If the project blocks an available command for release safety, document it as a project rule rather than an engine fact.

## Stop And Resume Rules

- Stop before SSH, raw RPT publication, local Arma launch for proof collection, live server upload/restart, deploy, or rollback.
- Do not merge whole feature branches into this release candidate during runtime evidence gating.
- Chernarus remains the source mission; use LoadoutManager to propagate Takistan after mission edits.
- Keep generated/private handoff artifacts local unless they are sanitized and intentionally documented.
