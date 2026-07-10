# WASP mass-unit stresstest harness

Repo-tracked, reviewed toolset for running a mass-AI-unit stresstest against a dedicated WASP
test deployment (the shared Miksuus-TEST box), replacing the ad-hoc one-off scripts used on
2026-07-08/09. That run failed for four separate, now-fixed engineering reasons (see
[Defects fixed](#defects-fixed-2026-07-08-09-incident) below).

Everything here is inert until an operator deliberately wires it into a mission checkout and
runs the pack/deploy scripts by hand. Nothing in this directory touches the live mission tree,
the build box, or the test box on its own.

## Flow

1. **Branch a mission checkout.** On the build box, branch off the release train the stresstest
   should represent (e.g. `git checkout -b claude/mass-unit-stresstest origin/fable/update2-consolidation`).
2. **Apply the two patch snippets** in `patches/` to that checkout's mission source (exact
   target file + insertion point documented in each snippet's header comment):
   - `patches/Init_CommonConstants.snippet.sqf` -> registers `WFBE_C_DEBUG_STRESS_SPAWN_GROUPS`
     (default 0 = inert). Deliberately **not** added to `Rsc/Parameters.hpp` - this flag must
     never be reachable as a lobby toggle.
   - `patches/Init_Server.snippet.sqf` -> the one-line spawn hook, gated on that flag.
3. **Copy the spawn script** into that checkout: `Server_DebugStressSpawn.sqf` ->
   `<mission>/Server/Debug/Server_DebugStressSpawn.sqf`.
4. **Set the flag** for this run, e.g. `WFBE_C_DEBUG_STRESS_SPAWN_GROUPS = 150` in the patched
   `Init_CommonConstants.sqf` (hard-capped at 200 inside `Server_DebugStressSpawn.sqf`
   regardless of what this is set to).
5. **Pack**: `python pack_stresstest.py --mission-dir <checkout mission dir> --out <pbo path>
   --prefix <bracketed PBO prefix> --candidate stresstest-<date>`. This renders `version.sqf`
   from `version.sqf.template` and asserts it exists and is well-formed *before* writing the PBO
   - see [Defect 1](#defect-1-missing-versionsqf) below.
6. **Stage** the PBO on the test box under `C:\WASP\staging\<label>\`.
7. **Deploy**: `deploy.ps1` (stop-first, drift-verified template swap, RPT archive, expanded
   failure probe). Prints the cfg backup path `rollback.ps1` needs.
8. **Monitor**: `monitor.ps1 -RptPath <box RPT path> [-Follow]` - server/HC FPS vs AI_TOT, this
   harness's own `STRESSTEST|v1|SPAWN_BATCH`/`SPAWN_COMPLETE` markers, `GRPBUDGET` warnings, and
   process stability, with the FPS cliff flagged automatically.
9. **If it fails to load, or you're done**: `rollback.ps1` (also stop-first - see
   [Defect 2](#defect-2-rollback-restored-cfg-before-stopping-the-service) below).

## The one hands-on step, and why it stays hands-on

`deploy.ps1` and `rollback.ps1` both stop and restart the **shared** `Arma2OA-PR8` Windows
service and its two headless-client scheduled tasks on Miksuus-TEST - a box that also runs
Miksuu's own `@admkswf` content, independent background automation (`WaspMatchEndRotate`,
`WaspHeavyMon`, stats web), and is not WASP-exclusive. Actually invoking that stop/restart chain
is intentionally left to the box owner running these scripts directly, not automated by any
agent tooling. This is **not** a gap in the harness - it is the permission guardrail protecting a
shared production-adjacent box from an unattended process taking it down. Everything up through
"stage the PBO" and everything in `monitor.ps1` (which only reads) is safe to automate; the
stop/restart step itself is the one place a human stays in the loop.

## Defects fixed (2026-07-08/09 incident)

### Defect 1: missing `version.sqf`

The historical per-build packers (`C:\Users\Game\wasp-build\_pack_*.py`, one hand-copied
throwaway script per build - there is no Mikero pboProject / BI AddonBuilder on the build box,
confirmed by recon) walk a git checkout directory and explicitly skip `*.template` files. The
real `version.sqf` is git-ignored and only ever created by rendering `version.sqf.template`; a
fresh checkout has no `version.sqf` on disk, so the walk silently produced a PBO with **no**
`version.sqf` in it. Both `description.ext` and `initJIPCompatible.sqf` `#include "version.sqf"`,
so the mission failed to parse at load.

**Fix**: `pack_stresstest.py` renders `version.sqf` from `version.sqf.template` first (keeping
`WF_DEBUG` commented off, stamping a fresh `WF_RELEASE_MARKER`), then asserts it exists and is
well-formed - twice: once right after rendering, and again against the walked file list right
before the PBO bytes are written - and refuses to pack (non-zero exit, explicit message) if
either check fails. Verified: a self-test pack against this repo's own Zargabad mission source
correctly rendered and included `version.sqf` (910 files, correct PBO header, self-check passed).

### Defect 2: rollback restored cfg before stopping the service

The rollback script that ran that night copied the cfg backup over `server-pr8.cfg` **before**
calling `service-restart.ps1` - the only place in that script that stops anything. The running
`arma2oaserver.exe` can hold the config file, so the restore raced a live process.

**Fix**: `rollback.ps1` runs its own stop chain (identical to `deploy.ps1`'s) *first*, then
restores the cfg, then calls the box's `service-restart.ps1` for bring-up - matching the order
`deploy.ps1` already used correctly. Verified by reading both the actual `deploy-stresstest-zg.ps1`
(stop-then-edit, correct) and `rollback-stresstest.ps1` (edit-then-stop-via-service-restart,
the bug) that ran on the box.

### Defect 3: `STRESSTEST|v1|SPAWN_BATCH` was a no-op

The prior mass-spawn script logged its batch progress through `WFBE_CO_FNC_LogContent`, which is
compiled to a no-op whenever `WF_LOG_CONTENT` is left commented out in `version.sqf.template` -
the normal, non-debug state every real deploy uses. The monitor had no batch signal.

**Fix**: `Server_DebugStressSpawn.sqf` logs `STRESSTEST|v1|START` / `SPAWN_BATCH` /
`SPAWN_COMPLETE` / `CAPPED` / `ABORT` via **plain `diag_log`**, never
`WFBE_CO_FNC_LogContent`, so they are always in the RPT regardless of lobby/debug settings.
`monitor.ps1` parses these directly.

### Defect 4: RPT failure probe missed the actual failure signatures

The deploy script's post-boot RPT grep only checked for `Invalid number|_camp_range|Cannot load
mission|Unknown` - it did not include `Include file`, `ErrorMessage:`, or a bare `not found`,
which is exactly what a missing `#include "version.sqf"` produces. The probe reported a clean
"3/3 up" while the mission had actually failed to load.

**Fix**: both `deploy.ps1` and `rollback.ps1` use the expanded pattern
`'Invalid number|_camp_range|Cannot load mission|Cannot load|Unknown|Include file|ErrorMessage:|not found'`
and warn explicitly when a failure signature appears with no success signature alongside it.

## Files

| File | Purpose |
|---|---|
| `Server_DebugStressSpawn.sqf` | Isolated, flag-gated debug mass-AI-spawn script. A2 OA 1.64-safe (lints clean via `Tools/Lint/check_sqf.py`). |
| `patches/Init_CommonConstants.snippet.sqf` | One-line flag registration to apply to a stresstest branch's mission source. Not wired into master. |
| `patches/Init_Server.snippet.sqf` | One-line spawn hook to apply to a stresstest branch's mission source. Not wired into master. |
| `pack_stresstest.py` | Renders + asserts `version.sqf`, then packs the mission into a PBO (same binary format the project's hand-rolled build-box packers use). |
| `deploy.ps1` | Stop-first deploy: backup cfg, stop chain, copy PBO, drift-verified template swap, RPT archive, bring-up, expanded RPT probe. |
| `rollback.ps1` | Stop-first rollback: stop chain, restore cfg, drift-verified, RPT archive, bring-up, expanded RPT probe. |
| `monitor.ps1` | Parses WASPSCALE / STRESSTEST / GRPBUDGET / emergency-GC RPT lines; flags the FPS-vs-AI_TOT cliff; one-shot or `-Follow`. |

## Design notes carried from the original recon

- Spawned groups alternate WEST/EAST/GUER, in batches of 10 every ~2 minutes (not 2 seconds) so
  the mission's own `WASPSCALE` heartbeat (every ~300s) gives a clean FPS-vs-unit-count curve
  instead of one instant cliff-dive.
- Groups spawn at existing `towns` positions (the same locations real AI-commander/town-defense
  code already operates at) with light jitter, not on top of player bases, and are given a move
  order toward the next town in rotation via the mission's own `Common_WaypointSimple.sqf` so the
  load is realistic pathfinding/tick load, not idle unit count.
- Roster is 4 infantry of the side's own soldier class plus (when available) the side's first
  supply-truck class, resolved dynamically via the same `WFBE_%1SOLDIER` / `WFBE_%1SUPPLYTRUCKS`
  pattern `Common_RunSidePatrol.sqf` already uses - works on any map/faction root, no hardcoded
  classnames.
- Hard-capped at 200 groups inside the script regardless of the configured value.
- The per-side 140-group cap + emergency-GC warning already built into
  `Common_CreateGroup.sqf`, and the 144/side `GRPBUDGET` warning already built into
  `AI_Commander.sqf`, are reused as-is as the natural "approaching the ceiling" signals - no new
  instrumentation needed for that part.
