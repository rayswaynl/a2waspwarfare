# OpsSalvage — remaining unversioned Game PC harness families

**Provenance:** recovered 2026-07-08 from loose, never-committed files at `C:\Users\Game\` on the
Game PC. Salvaged per the same never-lose-unversioned-work precedent as `Tools/PerfTest/`
(PR #917, PerfON/OFF A/B harness) and `Tools/Ops/Update-PublicStats.ps1` (PR #905). This sweep
covers four additional families the owner identified as still loose on the box: headless-client
bring-up/test tooling, soak/stability watchers, perf probes, and Chernarus map-switch deploy
scripts. **Nothing was deleted on the Game PC** — these are copies; the box remains the live
authoring machine for this class of ad-hoc ops script.

**Scope discipline:** `C:\Users\Game\` currently has **~250 other loose `.ps1` files** beyond the
four families below — an active, ongoing AICOM/rc-deploy pipeline (`rc10-deploy.ps1` … `rc31-deploy.ps1`),
a wiki claim/release lane pipeline (`claim-lane*-wiki.ps1` / `release-lane*-wiki.ps1`, ~20 files),
a BattlEye-enablement campaign (`be-attempt*.ps1`, `be-confirm.ps1`, `be-revert*.ps1`, `asrcheck.ps1`,
etc., ~20 files), nav/stats/poster reporting scripts, and the already-salvaged `perftest-ctl.ps1` /
`PerfOFF.zip` / `PerfON.zip` (PR #917) and `Update-PublicStats.ps1` (PR #905). All of that is
**intentionally excluded** from this PR — it's separate, actively-churning campaigns (many files
dated as recent as 2026-07-08, the day of this sweep) that don't fit the "stale harness family"
shape this precedent targets. Each would warrant its own deliberate, narrowly-scoped salvage pass.

**Safety note (read before running anything here):** several `HcTest/hc-be-test*.ps1` scripts
**actively stop the live `Arma2OA-PR8` service, flip `server-pr8.cfg`'s `BattlEye=` flag, kill
`arma2oaserver`/`ArmA2OA` processes, and delete the live RPT** as part of a BattlEye-enablement
experiment (they do revert in a `finally` block). The `MapSwitch/*.ps1` scripts similarly stop the
service chain, move/extract mission folders, and rewrite `server-pr8.cfg`. **These are salvaged as
reference/evidence of what was tested, not scripts meant to be re-run casually** — treat them the
same way PR #905 treats `Update-PublicStats.ps1`: a mirror of on-box state, not a checkout-runnable
tool. All of them hardcode box-local paths (`C:\WASP\...`, `C:\Program Files (x86)\Steam\...`,
`C:\Users\Administrator\...`) that point at the Hetzner production Arma 2 box (reached via
`ssh Administrator@78.46.107.142` in the companion Soak scripts) — **not** the Game PC they were
staged from. Re-pointing/verifying those paths is a prerequisite for any reuse.

**Privacy note:** `Soak/wasp-b57-full.ps1` and `Soak/wasp-b57-expansive.ps1` embed two Discord
snowflake IDs in prompt text (the owner's own ID, and a "never use this ID, it routes to his
partner" guard for a second ID). Neither is a credential — a snowflake ID alone cannot authenticate
— so they're not treated as a secret-scan hit, but they are personally-identifying and flagged here
for visibility rather than silently included.

## Secret-scan verdict: CLEAN

Full-tree scan for `token|key|password|webhook|Authorization|Bearer|-----BEGIN` (plus a second pass
for common hardcoded-credential shapes: `sk-…`, `ghp_…`, Slack/Discord webhook URLs, PEM blocks) —
**zero real secrets across all 51 files.** All hits are either:
- game/file vocabulary (`_recon_hc.ps1`'s `-- cfg missions structure (no secrets) --` comment;
  `_chernarus-switch-pbo-v.ps1`'s `# the world is the FINAL dot-token` comment; a kill-handler
  "token" referenced in the soak analysis docs), or
- safe **runtime env-var lookups by name** — `wasp-b57-soak.ps1`, `wasp-b48-soakwatch.ps1`, and
  `wasp-perf-report-trigger.ps1` all read `PEACH_OPS_API_KEY` / `BRAIN_TOKEN` from a local `.env`
  file via `Get-Content ... | Where-Object {$_ -like 'KEY=*'}` at run time — the literal secret
  value is never present in any of these scripts.

No files were excluded on security grounds.

---

## `HcTest/` — headless-client bring-up/test scripts (18 files)

Two time clusters of small PowerShell utilities for bringing up, monitoring, and BattlEye-testing
the Arma 2 headless-client (HC) pair (`MiksuuHC` / `MiksuuHC2` scheduled tasks) against the live PR8
server:

- **2026-06-23 evening cluster** (bring-up/monitor/recon): `_bringup_hc.ps1`, `_confirm_hc.ps1`,
  `_monitor_hc.ps1`, `_recon_hc.ps1`, `_watch_hc.ps1`.
- **2026-07-06 afternoon cluster** (BattlEye-under-HC test suite): `hc-recon.ps1`, `hc-be-recon.ps1`
  (read-only recon), `hc-be-test.ps1` / `hc-be-test2.ps1` (**live BE=1 experiments** — stop service,
  flip cfg, relaunch HC via `ArmA2OA_BE.exe`, verdict, then revert in `finally`), `hc-be-diag.ps1`,
  `hc-tidy.ps1` (cleanup — deletes the be-test scripts + backup from the box once done),
  `hc-check3.ps1`, `hc-cycle.ps1` (HC-only bounce, self-deletes at the end), `find_hc_rpts.ps1`.
- **2026-07-07 follow-on** (tiny, <1KB each, same HC/headless-client subsystem):
  `hcparams.ps1`, `hcdefdiag.ps1`, `hcdefdiag2.ps1`, `hcreseat.ps1`.

**Excluded (out of scope, judgment call):** a much larger, separate BattlEye-enablement campaign
(`be-attempt.ps1`, `be-confirm.ps1`, `be-recon.ps1`, `be-revert*.ps1`, `be-probe*.ps1`,
`be-procmon.ps1`, `be-dllinfo.ps1`, `becheck.ps1`, `berevert.ps1`, `asrcheck.ps1`, `asrdirect.ps1`,
~20 files, dated 2026-07-06→07-08) sits in the same window but is a distinct, larger BE-only effort,
not "HC test" — left on box, candidate for its own future salvage PR. Also excluded: raw RPT
captures `hc1.RPT`/`hc2.RPT` (7/6, ~4.5MB) and `cur-hc1.rpt`/`cur-hc2.rpt` (7/7, ~4.3MB) — sizeable
binary-ish log dumps that are incidental byproducts of these scripts, not scripts themselves; left
on box.

**Stale-path warning:** every script here hardcodes `C:\WASP\...` and
`C:\Users\Administrator\AppData\Local\ArmA 2 OA\...` (the Hetzner production box), plus the
scheduled-task names `MiksuuHC`/`MiksuuHC2`/`DismissACR`/`Arma2OA-PR8`. Verify these still exist
before reuse.

## `Soak/` — soak/stability watch loops (15 files)

Three generations of "watch the live match, DM Ray a digest, keep it alive" scheduled-task loops,
plus their captured output:

- **`wasp-b48-soakwatch.ps1`** (2026-06-19, earliest) — 30-min tick, small report each tick + BIG
  deep-dive every 4th (~2h), heuristic findings, Peach+ DM, dashboard self-heal. Companions:
  `wasp-soakwatch.log`, `wasp-soakwatch-findings.md` (431-line historical log of every tick's
  message, 2026-06-19→20), `wasp-soakwatch-state.json`.
- **`wasp-b57-soak.ps1`** (2026-06-21, successor) — adds RERUN-ON-WIN / keep-alive: on round-end or
  server-down it fires `WaspServiceRestart` via SSH to continue the SAME mission, with an 8-min
  cooldown guard. Companion: `wasp-b57-soak.log` (278-line tick log, 2026-06-20→21).
- **`_soak_b74.ps1`** — one-shot deep RPT slice (errors/economy/founding/veteran/MHQ-reloc/factories
  /airfield-air/AICOM-posture) for a specific soak snapshot, not a scheduled loop.
- **`fix_soak_marker.ps1`** / **`fix_soak_restore.ps1`** (2026-07-07) — small string-patch utilities
  that repoint a staged `soak1-deploy.ps1`/`soak1-restore.ps1`'s build-marker/pbo-name strings for a
  fresh soak-cycle rerun; later-dated but clearly soak-family by name and purpose.
- **`wasp-b57-expansive.ps1`** / **`wasp-b57-full.ps1`** (2026-06-21/22) — headless `claude -p`
  overnight deep-debate (every ~2h) and 06:00 morning-consolidation launchers for a
  propose-only improvement-plan loop against the live B59 mission; these are the ONLY files in this
  sweep that shell out to `claude -p --dangerously-skip-permissions` on the box itself.
- **`WASP-SOAK-HYPOTHESES.md`** / **`WASP-SOAK-REPORT-cmdcon27.md`** (2026-06-30) — the analysis
  ledger and definitive write-up from an overnight cmdcon27/28/29 soak; kept as the paired
  documentation for the watch-loop family (explains what the loops were validating and the
  assault-reach/round-closure findings that came out of them).

**State files (`wasp-b57-soak-state.*`)** — 8 timestamped snapshots existed on the box for
2026-06-21 (`b61` 10:47 → `b62` 11:47 → `b63` 12:17 → `b64` 12:47 → `b65` 14:47 → `b66` 18:18 →
`b67` 19:18 → bare `wasp-b57-soak-state.json` 20:17, the final/latest). Per the owner's "keep
newest 2, list the rest as left-on-box" instruction, **only `wasp-b57-soak-state.json` (final,
20:17) and `wasp-b57-soak-state.json.b67-20260621-192613` (19:18) were pulled**; `b61`–`b66` (6
files, ~1.7KB total) remain on the box only.

**Stale-path warning:** `wasp-b57-soak.ps1`/`wasp-b48-soakwatch.ps1` target `ssh
Administrator@78.46.107.142` and hardcode the mission name `[55-2hc]warfarev2_073v48co_b68.chernarus`
(soak.ps1) — both are almost certainly stale against the current live build.

## `PerfProbes/` — one-shot perf diagnostic probes (5 files)

- **`wasp-perf-baseline.ps1`** — parses `SRVPERF` lines into an fps-vs-units curve (binned), worst-5
  samples, HC fps.
- **`_box_perf_deep.ps1`** — the deep version: PerformanceAudit bracket ranking by cumulative ms,
  fps-vs-load curve by unit/group bin, HC/client-side perf line search, group-source/GC accounting,
  AICOM team-footprint counts.
- **`_box_srvperf.ps1`** — quick snapshot: procs up, latest MISSINIT, recent SRVPERF lines, filtered
  error count (excludes known-benign third-party addon errors), RPT age.
- **`_bench_compare.ps1`** — compares client-side FPS-by-AI-band across multiple captured client
  RPTs (`C:\Users\Game\Downloads\ArmA2OA*.RPT` + the reaped `client-main.rpt`) to A/B build+VD
  combinations.
- **`wasp-perf-report-trigger.ps1`** — standing 3-hourly scheduled-task trigger that posts a
  high-priority brain task (via the claude-bridge `/task` API + `BRAIN_TOKEN`) asking the
  brain-runner's Claude session to gather live perf over SSH and DM Ray via Peach+.

**Excluded:** `perftest-ctl.ps1` — this is the A/B driver already salvaged in `Tools/PerfTest/`
(PR #917); not duplicated here.

**Stale-path warning:** all target the Hetzner box RPT path
(`C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT`) or `ssh
Administrator@78.46.107.142`.

## `MapSwitch/` — Chernarus map-switch / redeploy scripts (13 files)

The `_chernarus-switch*.ps1` family: stop the `MiksuuPR8`/`MiksuuHC`/`MiksuuHC2` chain, park the
prior mission (folder or `.pbo`) under `C:\WASP\mission-park\old-baks\`, deploy a new build (from a
zip or a pre-packed `.pbo`), repoint `server-pr8.cfg`'s `PR8_Chernarus` template line, rotate the
RPT, and relaunch the chain with the proven HC reslot-bounce sequence. 11 files match
`_chernarus-switch*.ps1` exactly, in build order:

| File | Build tag | Source | Notes |
|---|---|---|---|
| `_chernarus-switch.ps1` | B36 | zip | earliest, 2026-06-18 |
| `_chernarus-switch-pbo.ps1` | B48 | `.pbo` | first `.pbo`-based switch (vs folder) |
| `_chernarus-switch-folder.ps1` | sf (stable-folder) | zip | reverts to a pre-B48 known-good |
| `_chernarus-switch-headb49.ps1` | headb49 | zip | clean HEAD + B49 join-fix |
| `_chernarus-switch-pbo-v.ps1` | b51 (versioned) | `.pbo` | versioned-name variant of the pbo switch |
| `_chernarus-switch-b51.ps1` | b51 (folder) | zip | folder variant, same build |
| `_chernarus-switch-restore.ps1` | restore | zip | same source zip as `-folder.ps1`, second use |
| `_chernarus-switch-deslot.ps1` | deslot | zip | B49 join-fix + 26 shell slots de-slotted |
| `_chernarus-switch-b52.ps1` | b52 | zip | + JIP fade-clear fix |
| `_chernarus-switch-b53.ps1` | b53 | zip | + persistent fade watchdog |
| `_chernarus-switch-b54.ps1` | b54 | zip | + uiSleep fade-clear, 2026-06-20 |

Plus two included by judgment (task explicitly allows "anything else obviously WASP-ops-shaped"):
- **`_box_chernarus-switch.ps1`** — **byte-identical** to `_chernarus-switch.ps1` (4355 bytes, same
  B36 content), just saved under the later `_box_*` naming convention on 2026-06-22. This is the
  **canonical/most-recent copy by timestamp** of the B36 switch logic, even though its content is
  the earliest build in the sequence — the `_box_` prefix is the naming convention the owner moved
  to for later ops scripts (see `_box_deploy_*`, `_box_recover*`, etc. left on the box).
  `_chernarus-switch-b54.ps1` (2026-06-20 07:48) is the **canonical latest by build progression**.
- **`_run-switch-detached.ps1`** — a tiny (634-byte) detached-process launcher, saved with the exact
  same timestamp as `_chernarus-switch.ps1` (2026-06-18 19:24:37). Its current content actually
  launches `C:\WASP\takistan-switch.ps1` (Takistan, not Chernarus) — it's a reusable
  "launch-a-switch-script-detached-and-report" wrapper pattern, included as a companion utility for
  the family rather than a Chernarus-specific script.

**Excluded (out of scope, judgment call):** `_box_takistan-switch.ps1` (same-minute sibling of
`_box_chernarus-switch.ps1`, but a different terrain feeding into a much larger, separate Takistan
merge/deploy pipeline — `_tk_deploy_recon.ps1`, `_tk_execute_merges.ps1`, `_tk_gap_diff.ps1`,
`_tk_merge_prep.ps1`, `_tk_port_dropins.ps1`, `_tk_verify_structure.ps1`, `_deploy_switch_tk.ps1`,
`_fire_tk_switch.ps1`, `_wait_smoke_tk.ps1`, ~9 files); the 5 `aicom-chernarus-*.zip` build archives
(~45MB total) — large binary mission-build zips, a different concern (AICOM mission builds, not
map-switch tooling) than the switch scripts that consume them.

**Stale-path warning:** every script's `$srcZip`/`$pbosrc` points at a specific staged file under
`C:\WASP\staging\...` that almost certainly no longer exists (each build's staging artifact is
overwritten/cleaned by the next); the `server-pr8.cfg` template regex assumes the box's current cfg
still has a `template = "[55-2hc]warfarev2_073v48co...chernarus...";` line to match against.

---

## Byte totals

| Family | Files | Approx. bytes |
|---|---|---|
| HcTest | 18 | ~27.7 KB |
| Soak | 15 | ~132.6 KB |
| PerfProbes | 5 | ~13.0 KB |
| MapSwitch | 13 | ~55.1 KB |
| **Total** | **51** | **~228 KB** |
