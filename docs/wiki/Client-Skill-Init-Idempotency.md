# Client Skill Init Idempotency

## Status

`client-skill-init-idempotency` is branch-local source + maintained Vanilla propagated and smoke pending as of 2026-06-03. This docs branch removes the second `Skill_Init.sqf` call in client init while preserving the immediate `WFBE_SK_FNC_Apply` call; stable `origin/master` still has the duplicate init and should not be described as shipped there. Current release head `7195b331` now carries the same single-init shape in both maintained release roots, but Arma Soldier/non-Soldier/respawn smoke is still pending. The earlier checkout-root blocker was removed by the LoadoutManager root-discovery patch, and propagation now works from this Codex checkout with `A2WASP_SKIP_ZIP=1`.

## What I Read

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Apply.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_PreRespawnHandler.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- Vanilla Takistan `Client/Init/Init_Client.sqf` after LoadoutManager propagation.
- `origin/master` and `origin/release/2026-06-feature-bundle` versions of the Chernarus and maintained Vanilla client init files for branch status.

## Branch Status

Current branch status is:

| Branch / source | Evidence | Meaning |
| --- | --- |
| This docs branch, source Chernarus | `Client/Init/Init_Client.sqf:547`, `:551`, `:571` | One `Skill_Init.sqf` call remains before default gear selection, and `(player) Call WFBE_SK_FNC_Apply` still runs later. |
| This docs branch, maintained Vanilla Takistan | `Client/Init/Init_Client.sqf:547`, `:551`, `:571` | Vanilla matches the source Chernarus single-init shape after propagation. |
| `origin/master`, source Chernarus | `Client/Init/Init_Client.sqf:561`, `:565`, `:585-586` | Unpatched on master: it still calls `Skill_Init.sqf` twice before applying skills. |
| `origin/release/2026-06-feature-bundle` head `3282ff3f`, source Chernarus | `Client/Init/Init_Client.sqf:565`, `:589-590` | Historical release spot-check: still duplicated the init. Superseded by current release head `7195b331`. |
| `origin/release/2026-06-feature-bundle` head `7195b331`, Chernarus and maintained Vanilla | `Client/Init/Init_Client.sqf:564`, `:587` | Current release head now has one `Skill_Init.sqf` call followed by `WFBE_SK_FNC_Apply` in both maintained roots. Arma smoke remains pending. |
| Shared skill init module | `Client/Module/Skill/Skill_Init.sqf:10`, `:40-49` | Compiles `WFBE_SK_FNC_Apply`, sets `WFBE_SK_V_Type`, and multiplies local `WFBE_C_PLAYERS_AI_MAX` by `1.5` for Soldier class. |
| Shared common constant | `Common/Init/Init_CommonConstants.sqf:243` | Default `WFBE_C_PLAYERS_AI_MAX` is `16`. |
| Respawn path | `Client/Functions/Client_PreRespawnHandler.sqf:5` | Respawn reapply calls `WFBE_SK_FNC_Apply` without rerunning `Skill_Init.sqf`. |

Because `Skill_Init.sqf:49` has no applied flag or base-value reset, a Soldier client could compound the local AI cap from 16 -> 24 -> 36 during one init path. The likely intended one-time Soldier boost is 16 -> 24.

## Patch Shape

The source mission patch removes only the second `Skill_Init.sqf` call:

- Keep `Client/Init/Init_Client.sqf:547` so `WFBE_SK_V_Type` exists before class-based default gear selection.
- Keep `(player) Call WFBE_SK_FNC_Apply` in the later skill block so the selected class still gets skill effects/actions before play.
- Do not change `Skill_Init.sqf` internals, because a single init call is enough for the current path.
- Propagate with `Tools/LoadoutManager` so Vanilla Takistan matches source.

Changed source files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`

Propagated maintained Vanilla file:

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf`

## Validation

Source/Vanilla validation done:

- Chernarus `Init_Client.sqf` has exactly one `Skill_Init.sqf` call and one immediate `WFBE_SK_FNC_Apply` call.
- Vanilla Takistan has the same single-init shape after the propagation run.
- `Skill_Init.sqf` still compiles `WFBE_SK_FNC_Apply`.
- `Client_PreRespawnHandler.sqf` still applies skill effects on respawn.
- `git diff --check` passes.
- `dotnet run` in `Tools/LoadoutManager` now works from `work\a`; use `A2WASP_SKIP_ZIP=1` for propagation-only runs so missing `7za` remains non-blocking.

Pending smoke:

- Local/hosted: join as Soldier and confirm the visible/local AI cap is the one-time boosted value, not the compounded value.
- Local/hosted: join as non-Soldier and confirm normal cap/class behavior.
- Respawn: confirm skill actions/effects are present after death/respawn.
- Dedicated/JIP: confirm no client init regressions in JIP join path.

## Modded Mission Note

Modded mission folders also show duplicate `Skill_Init.sqf` calls in some variants, but those folders are divergent/generated/forked targets and several stale files contain merge-conflict markers. Per repo rules, do not patch modded folders by hand until the generated/forked mission maintenance model is resolved.

## Handoff

For Codex/future code owner:

- Keep this as a small client-init cleanup unless future evidence shows another `Skill_Init.sqf` entrypoint can run more than once.
- If another path must call `Skill_Init.sqf`, guard only the Soldier AI-cap mutation or store a base cap before applying the 1.5x boost.
- Pair any future modded propagation with the generated mission cleanup work from `Tools-And-Build-Workflow`, DR-4 and DR-32.

For Claude:

- Good contradiction check: prove whether any UI or respawn path expects cooldown variables from the removed second init call. Current source evidence says respawn uses `WFBE_SK_FNC_Apply` only.

## Continue Reading

- Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep)
- Next: [Feature status register](Feature-Status-Register)
