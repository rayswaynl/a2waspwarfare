# Server Init Bind Cleanup

Status: docs-ready branch-split low-risk cleanup lane. No gameplay source changed by this page.

This page owns DR-43b: duplicate compile/bind rows in `Server/Init/Init_Server.sqf`. The issue is not runtime-critical today because each live duplicate points at the same file and the second bind silently wins. The risk is maintenance drift: a future edit can change only one copy, hide a stale function target, or confuse nearby victory/endgame cleanup. Current docs/source `HEAD@d830379768` still carries the old duplicate block in both maintained roots; current stable/B69/B74 carry the one-live-bind shape and should not be reopened for this cleanup.

## Current Branch Matrix

| Scope | Live duplicate binds | Commented duplicate remnants | Development meaning |
| --- | --- | --- | --- |
| docs/source `HEAD@d830379768` Chernarus | `WFBE_CO_FNC_LogGameEnd` (`Init_Server.sqf:64,89`), `WFBE_SE_FNC_PlayerObjectsList` (`:69,91`), `WFBE_SE_FNC_AwardScorePlayer` (`:83,93`). | AFK kick active/commented (`:63,88`), server FPS monitor commented twice (`:65,90`), MASH marker active/commented (`:70,92`); monitor also execVMs later at `:595`. | De-duplicate live binds and either remove or clearly mark commented remnants. |
| docs/source `HEAD@d830379768` maintained Vanilla | Same line shape as source Chernarus. | Same line shape. | Propagate/source-sync cleanup with Chernarus; do not leave Vanilla with the old init block. |
| current stable `origin/master@0139a346` | One live bind per checked function in both maintained roots: `WFBE_CO_FNC_LogGameEnd` (`Init_Server.sqf:81`), `WFBE_SE_FNC_PlayerObjectsList` (`:86`), `WFBE_SE_FNC_AwardScorePlayer` (`:99`). | AFK active/commented (`:80,104`) and server-FPS commented remnants (`:82,105`) remain; no MASH marker compile is present in the checked init block. | Stable already has the live duplicate-bind cleanup; preserve it when merging older docs/Miksuu code. |
| current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` | One live bind per checked function in both maintained roots: `WFBE_CO_FNC_LogGameEnd` (`Init_Server.sqf:83`), `WFBE_SE_FNC_PlayerObjectsList` (`:88`), `WFBE_SE_FNC_AwardScorePlayer` (`:101`). | AFK active/commented (`:82,106`) and server-FPS commented remnants (`:84,107`) remain; B69-to-B74 has no checked `Init_Server.sqf` path diff. | Current B69/B74 match the stable one-live-bind shape for this lane; do not reopen them for DR-43b. |
| current Miksuu `b8389e748243` | Same old live duplicates as docs/source in both maintained roots (`:64,89`, `:69,91`, `:83,93`). | Same old AFK/server-FPS/MASH remnants; MASH marker also has the active first bind at `:70`. | Upstream still needs the cleanup or a careful merge from the current stable/B69/B74 shape. |
| `origin/perf/quick-wins@0076040f` | Chernarus has one live bind per function (`:64`, `:69`, `:83`) plus an explanatory cleanup comment around `:88`; maintained Vanilla still has the old duplicate shape (`:64,89`, `:69,91`, `:83,93`). | Chernarus comment remnants differ from Vanilla; Vanilla keeps the old MASH/comment block and monitor startup still execs later. | Perf is partial propagation: do not claim the branch fixed Vanilla until regenerated/reviewed. |
| historical `a96fdda2` | One live bind per checked function in both maintained roots: `WFBE_CO_FNC_LogGameEnd` (`Init_Server.sqf:65`), `WFBE_SE_FNC_PlayerObjectsList` (`:70`), `WFBE_SE_FNC_AwardScorePlayer` (`:83`). | AFK active/commented (`:64,88`) and server-FPS commented remnants (`:66,89`) remain; no checked live `release/*` head is exposed on 2026-06-22. | Treat this as historical release-line evidence until a live release ref is restored/rechecked; preserve the one-live-bind shape if cherry-picking. |

## What To Change

1. Keep one live compile/bind for each function.
2. Remove or intentionally annotate commented duplicate remnants instead of leaving them as apparent half-patches.
3. Keep `WFBE_CO_FNC_LogGameEnd` pointed at `Server/Functions/Server_LogGameEnd.sqf`; do not wire the stale `Server/PVFunctions/LogGameEnd.sqf` twin.
4. Keep behavior cleanup separate from init hygiene unless the branch explicitly smokes the touched behavior.

## Cross-System Caveats

- Victory/endgame: `WFBE_CO_FNC_LogGameEnd` sits next to DR-11/DR-13/DR-36 work. De-duplicating the bind is safe; changing win/loss semantics is not part of this lane.
- Supply mission: `WFBE_SE_FNC_PlayerObjectsList` is live and currently owns supply player-object rows. De-duplicating the bind should not change the supply authority work.
- Score awards: `WFBE_SE_FNC_AwardScorePlayer` is live economy/score plumbing. De-duplicating the bind should not change award validation.
- AFK/FPS/MASH: commented duplicate remnants should not be re-enabled as a cleanup shortcut. AFK, server FPS and MASH each have their own owner pages.

## Validation

Source checks:

- On the target branch/root, one live `WFBE_CO_FNC_LogGameEnd` compile remains.
- On the target branch/root, one live `WFBE_SE_FNC_PlayerObjectsList` compile remains.
- On the target branch/root, one live `WFBE_SE_FNC_AwardScorePlayer` compile remains.
- Commented duplicate remnants are removed or explicitly labelled historical.
- `Server/PVFunctions/LogGameEnd.sqf` remains unregistered unless a separate victory/endgame owner intentionally retires or rewires it.

Runtime smoke, if code is changed:

- Dedicated server boots through server init.
- Victory/endgame still calls the live win-stat logger once for the tested scenario.
- Supply mission start/completion still updates player-object rows.
- Score award path still works for kill/capture/reward flows.
- AFK handling, server FPS HUD and MASH marker status do not regress from their current documented owner states.

## Continue Reading

Previous: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) | Next: [Victory and endgame atlas](Victory-And-Endgame-Atlas)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-feature-status.jsonl`](agent-feature-status.jsonl)
