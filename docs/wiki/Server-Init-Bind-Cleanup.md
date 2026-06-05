# Server Init Bind Cleanup

Status: docs-ready low-risk cleanup lane. No gameplay source changed by this page.

This page owns DR-43b: duplicate compile/bind rows in `Server/Init/Init_Server.sqf`. The issue is not runtime-critical today because each live duplicate points at the same file and the second bind silently wins. The risk is maintenance drift: a future edit can change only one copy, hide a stale function target, or confuse nearby victory/endgame cleanup.

## Current Branch Matrix

| Scope | Live duplicate binds | Commented duplicate remnants | Development meaning |
| --- | --- | --- | --- |
| docs/source Chernarus | `WFBE_CO_FNC_LogGameEnd` (`Init_Server.sqf:64,89`), `WFBE_SE_FNC_PlayerObjectsList` (`:69,91`), `WFBE_SE_FNC_AwardScorePlayer` (`:83,93`). | AFK kick (`:63,88`), server FPS monitor (`:65,90`), MASH marker (`:70,92`). | De-duplicate live binds and either remove or clearly mark commented remnants. |
| maintained Vanilla Takistan | Same line shape as source Chernarus. | Same line shape. | Propagate/source-sync cleanup with Chernarus; do not leave Vanilla with the old init block. |
| `origin/master` / `miksuu/master` | Same live duplicates in Chernarus and Vanilla. | Same commented remnants; server still calls AFK handler and execs `monitorServerFPS` later. | Stable/upstream still need this cleanup. |
| `origin/release/2026-06-feature-bundle` Chernarus | Release Chernarus removed the three live duplicate binds; the remaining lines are the first live binds plus commented AFK/server-FPS/MASH remnants (`Init_Server.sqf:64-91`). | Commented remnants remain; release also comments the redundant monitor publisher around `:594`. | Useful comparison point, but not full propagation. |
| `origin/release/2026-06-feature-bundle` Vanilla | Same old live duplicates and commented remnants as stable. | Same old remnants. | Release is Chernarus-only for this cleanup; Vanilla still needs parity. |

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

- One live `WFBE_CO_FNC_LogGameEnd` compile remains.
- One live `WFBE_SE_FNC_PlayerObjectsList` compile remains.
- One live `WFBE_SE_FNC_AwardScorePlayer` compile remains.
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
