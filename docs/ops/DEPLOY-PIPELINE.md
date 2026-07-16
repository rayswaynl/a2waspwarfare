# WASP Deploy Pipeline — `Tools/Ops/Deploy-Wasp.ps1`

**ONE reusable, idempotent deploy script.** Replaces the ~150 single-use throwaway scripts
that accumulated on the box (`_freshname_pbo_deploy_b59.ps1` … `deploy47.ps1`,
`rc11-deploy` … `rc31zg`, `_box_deploy_b746` …). A new script was minted per build and never
consolidated; the script that produced the current live build could not even be located.

> **Operator tool.** The owner runs this. Agents never run it against the live server
> (`docs/AGENT-HANDBOOK.md` → *Box and deploy policy*). All code changes ship as draft PRs;
> the owner folds them to the box by hand.

---

## What it does (the full chain)

| Phase | Action | Reuses |
|------:|--------|--------|
| 1 | **Build / mirror** — regenerate the Takistan + Zargabad mirrors from Chernarus, then restore the TK/ZG `version.sqf.template`s | `Tools/LoadoutManager` (`dotnet run -c RELEASE`) |
| 2 | **Pack** — stage each mission folder under its build-tagged name and pack to `.pbo` | external packer (see below) |
| 3 | **Stage + copy** — archive the current live PBO (rollback point), then place the new PBO in `MPMissions` | — |
| 4 | **Repoint cfg** — repoint the active `template = "…";` line | `Tools/Ops/Set-MissionTemplate.ps1 -Apply` |
| 5 | **Restart** — trigger the existing scheduled task (the **only** stop/start) | `WaspServiceRestart` → `C:\WASP\service-restart.ps1` |
| 6 | **Verify** — service `Running`, server + both HCs alive, RPT shows the expected `WASPSCALE\|v2\|…\|build=` token | — |
| 7 | **Rollback** — keep the last *N* live PBOs; restore the newest on demand or on verify failure | — |

Chernarus is the **source of truth**; Takistan and Zargabad are **generated**. Never hand-edit
the mirrors — fix the generator and regenerate (repo `CLAUDE.md` source rule).

---

## Safe by default

Without `-Apply` the script is a **full dry run**: it validates the plan, prints every step it
would take, and writes **nothing** to the live box. Build (phase 1) and pack (phase 2) also
only run under `-Apply` (or the explicit `-RunBuild` / `-RunPack` dry-run overrides) and only
ever write to the local staging dir — so a review dry run is completely side-effect free.

```powershell
# Review dry run — writes nothing:
.\Tools\Ops\Deploy-Wasp.ps1 -Build cmdcon48aicom -ActiveMap ch

# Owner, on the box — real deploy:
.\Tools\Ops\Deploy-Wasp.ps1 -Build cmdcon48aicom -ActiveMap ch -Apply

# Emergency rollback to the previous known-good Chernarus PBO:
.\Tools\Ops\Deploy-Wasp.ps1 -ActiveMap ch -Rollback -Apply
```

---

## PBO packer — the recovered `pack_pbo.py` (no binary dependency)

The original task noted "no packing tool exists in-repo". That gap is closed by
**PR #1085** (`Tools/Pack/pack_pbo.py`), which recovered the owner's actual packing method: a
**pure-Python** PBO writer with no `MakePbo`/`cpbo`/`armake2` binary dependency — matching what
every one of the ~90 recovered hand-rolled `_pack_*.py` build scripts actually did. This
pipeline **stacks on #1085** and drives that tool by default:

```
python Tools\Pack\pack_pbo.py --source <missionFolder> --output <build-tagged.pbo> --build-tag <tag> --force
```

`pack_pbo.py` sets the PBO `prefix` from the source folder name + `--build-tag`, so no
build-tagged staging folder is needed on the default path. No binary is added to the repo.

**Verified:** packing the live Chernarus source through the pipeline produced a 13.1 MB PBO
(912 entries, `prefix='[55-2hc]warfarev2_073v48co_cmdcon48aicom.chernarus'`), and the
independent `Tools/Pack/read_pbo.py` validator confirmed the SHA1 trailer checksum OK.

**Optional native override.** `-PboTool <path>` switches to a Mikero-style positional packer
(`MakePbo <sourceFolder> <outputPbo>`, <https://mikero.bytex.digital/>) for operators who
prefer it; that path stages a build-tagged folder and packs it. If neither the repo tool nor a
`-PboTool` is available, the pack phase **blocks** with `WASP_DEPLOY_ABORT_NOPBOTOOL` rather
than guessing.

> Note: `version.sqf` is gitignored (generated). In a bare checkout `pack_pbo.py` falls back to
> `version.sqf.template` with a warning — fine for a structural/smoke pack, but run phase 1
> (LoadoutManager) first so a real `version.sqf` is present before an actual deploy.

---

## Why this cannot repeat the 2026-06-23 incident

On 2026-06-23 a hand-copied cfg-repoint guard `throw`ed on a **no-op** (re-deploying the same
build) *after* the service had already been stopped, leaving the server **down**.

Two independent guards make that impossible here:

1. **The cfg is repointed while the server is still UP**, and it is the **last** mutation
   before the restart. Phase order is: place PBO → repoint cfg → *then* trigger the restart
   task. If the repoint fails, the restart is never triggered and the server keeps running the
   old mission. The restart task (phase 5) is the single stop/start, fired only after every
   file + cfg change already succeeded.
2. **Verify-before-stop.** Before touching anything, the script runs `Set-MissionTemplate` in
   dry-run mode to confirm the target `template = …` line actually exists. A missing/renamed
   line aborts immediately, server untouched. (`Set-MissionTemplate` itself already encodes the
   correct 3-way guard: no-match → throw, no-op → success, differs → rewrite — so the original
   buggy `throw`-on-no-op cannot recur.)

If phase 6 verify fails **after** the restart, the pipeline auto-restores the archived
known-good PBO + cfg and restarts once (`restore-on-failure`; disable with `-NoAutoRollback`).

---

## Rollback design (replaces the stale "backup")

Recon found the only "backup" PBOs on the box were from **2026-06-08** — over a month stale —
so rollback was effectively broken. This pipeline keeps a real rolling archive:

- Before every deploy, the current live PBO for the active map is copied to
  `…\wasp-pbo-archive\<map>\<yyyyMMdd-HHmmss>__<original>.pbo`.
- The newest **`-KeepArchives`** (default **5**) are retained per map; older ones are pruned.
- `-Rollback -Apply` restores the newest archived PBO for `-ActiveMap`: copy back to
  `MPMissions`, repoint the cfg to it (verify-before-stop first), trigger the restart.

---

## Verify signal

Phase 6 windows the server RPT to the current match (after the last `MISSINIT`) and looks for a
`WASPSCALE|v2|…|build=<tag>` line whose `build=` field contains the expected token. The token is
derived exactly as the on-server parser does (`AI_Commander.sqf`): the `cmdcon<…>` slice of the
mission name if present, otherwise the full mission name. Use a `cmdcon`-style build tag for a
clean telemetry token; any tag still verifies via substring match (`-ExpectBuild` to override).

---

## Relationship to `deploy-v2.ps1`

`docs/ops/deploy-v2.ps1` is the previous consolidation attempt — a single monolith that
**reimplements** the stop/HC-reseat/start dance inline (with all its race fixes) rather than
composing the box's own restart task. It remains the reference for the box's process/port/HC
readiness semantics and path layout. `Deploy-Wasp.ps1` supersedes the throwaway lineage by
**composing** the existing operator tools (`Set-MissionTemplate.ps1`, the `WaspServiceRestart`
task) instead of re-copying restart logic, and by adding a real rolling rollback archive. The
HC-reseat internals stay owned by `C:\WASP\service-restart.ps1` (the restart task), which is the
correct single owner of the stop/start sequence.

---

## Tests

`Tools/Ops/Deploy-Wasp.Tests.ps1` — dependency-free (no Pester, no live box). Covers the
naming, `WASPSCALE build=` token derivation, and archive-rotation/retention logic (the parts
that decide *which* file is deployed and *which* archive is kept). The live phases
(copy/repoint/restart/verify) are integration-only and are exercised by the dry run, not by unit
tests — they cannot run off-box.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\Ops\Deploy-Wasp.Tests.ps1
```

---

## Parameters worth knowing

| Param | Meaning |
|-------|---------|
| `-Build <tag>` | Build tag embedded in the PBO filename (required unless `-SkipPack -PboPath`). |
| `-ActiveMap ch\|tk\|zg` | Which map is live in `MPMissions`. Default `ch`. |
| `-Apply` | Perform the live-box mutations. Omit for a dry run. |
| `-Rollback` | Restore the newest archived PBO instead of deploying. |
| `-SkipBuild` / `-SkipPack -PboPath <pbo>` | Deploy a pre-built PBO (split build-machine vs box workflows). |
| `-PboTool <path>` | Explicit packer path (else auto-detect). |
| `-KeepArchives <N>` | Rollback retention depth (default 5). |
| `-NoAutoRollback` | Disable restore-on-failure after verify. |
| `-RepoRoot` / `-MissionsDir` / `-CfgPath` / `-RptPath` / `-ArchiveRoot` / `-StageRoot` | Path overrides; defaults match the live box. |

The build machine and the box can be the same host or split: run pack on the machine with the
repo (`-RunPack`, copy the resulting `.deploy-stage\*.pbo` across), then
`-SkipPack -PboPath <pbo> -Apply` on the box.
