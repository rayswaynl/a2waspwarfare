# Bloat / LOC Report — 2026-07-05

Tool: `git ls-files` + Python line counter (cloc not installed). Binaries excluded from LOC. Workflow `wf_a00082ab-7ef`, read-only.

## a2waspwarfare — 524,114 text LOC / 4,243 text files

| Directory | Files | LOC |
|---|---:|---:|
| Missions_Vanilla (generated Takistan+Zargabad mirrors) | 1,556 | 227,400 |
| Modded_Missions (7 community maps) | 1,396 | 140,916 |
| Missions (Chernarus **source**) | 775 | 116,181 |
| docs | 194 | 17,614 |
| Tools | 250 | 16,703 |
| DiscordBot | 41 | 2,384 |
| other (root/Extension/Guides/…) | 31 | 2,916 |

By language: SQF 407k, HPP 36k, MD 20k, SQM 18k, XML 18k, C# 9k, PY 5.4k, PS1 4k.

**~71% of the SQF/HPP corpus is generated mirrors** (LoadoutManager output). Real source of truth is the 116k-LOC Chernarus mission.

### The V1 commander body count
`Server/AI/Commander/*` = 18 files, **8,422 LOC** in Chernarus (largest: Teams 1,249 / Strategy 1,129 / AI_Commander 1,096 / Base 1,006 / AssignTowns 788), ×3 missions = **25,266 LOC scheduled for removal** at cutover step 5. Plus `AI_Commander_HCTopUp.DRAFT.sqf` (280 LOC ×3) — a tracked draft file that should never deploy.

## miksuus-website-discord-bot — 97,972 text LOC / 513 files

web 31.6k · db 28.9k (26.4k = Drizzle migration SQL, normal) · docs 17.2k · root 11k (10.9k = package-lock) · bot 6.6k · brand 2.3k.

## Bloat candidates (ranked by value/risk)

| # | Item | Why | Risk / gate |
|---|---|---|---|
| 1 | V1 commander tree (25,266 LOC ×3 missions) | Cutover directive: mapped → shelved → removed | **BLOCKED until parity soak passes** (cutover step 3) |
| 2 | 74 `STATUS-*.md` / `NOCHANGE-*.md` one-shot analysis docs (4,666 LOC, 40% of docs/design) | Completed decision records, not living docs | Zero — archive to `docs/design/archive/` or tagged branch |
| 3 | Session handoff artifacts (`MORNING-HANDOFF-2026-07-02.md`, `OVERNIGHT-LOOP-2026-07-02.md`, `HC-SLOT-MAGNET-HANDOFF.md`, `B57-SOAK-PROPOSALS.md` at root) | Process dumps, unreferenced | Zero — delete or archive |
| 4 | `AI_Commander_HCTopUp.DRAFT.sqf` ×3 | Tracked draft; superseded by V2 migration | Low — remove at cutover |
| 5 | Tools/MatchReport/assets — 31 PNG, 24.1 MB in git (code is only 2.8k LOC) | Binary blobs inflate every clone | Medium — LFS migration, assets actively used by render.py |
| 6 | 78 ogg files (7.3 MB) byte-identical ×3 missions | Generator copies instead of referencing | Low — generator change or accept |
| 7 | Stub missions: tavi (4.9k LOC sqm-dump), dingor, isladuala | Not playable, placeholder trees | Low — mark WIP or remove |
| 8 | miksuu: `assets/models/tank.glb` (85.5 MB) + `mi24-hind.glb` (20.9 MB) | 106 MB of 3D models in plain git | Medium — check web/ references, then LFS |
| 9 | miksuu: `brand/ambient-background/media/hero-bg.{mp4,webm}` byte-identical to `web/public/brand/` copies (5.4 MB) | Confirmed duplicate (MD5) | Low — keep served copy, check ambient.html refs |
| 10 | miksuu: `web/public/changelog.json.bak-pre78` (830 lines) | Only .bak in repo | Zero — delete |
| 11 | Master-instructions prompt files in `docs/project-management/` | Sprint scaffolding, not design docs | Keep for this run; archive with the run's closure |

### Telemetry emitter count (before-state)
~40 distinct diag_log families in the Chernarus mission; the heavyweight is `AICOMSTAT` with **168 emitters across 35 files** (V1 commander) vs `AICOM2` with 39 emitters in 5 files (V2 lane). Full census + verdicts: `TELEMETRY-AND-STATS-V2-PLAN.md`. Post-cutover target: retire the V1-only share of those 168 after mapping, leaving the unified grammar + the ~30 non-commander families (groupsGC, GUER systems, client diagnostics) intact.

### After-state
No code was removed this run (discovery only). The LOC delta section will be filled by Agent B's build log when cleanup packets execute.
