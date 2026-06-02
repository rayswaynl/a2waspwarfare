# Client Skill Init Idempotency

## Status

`client-skill-init-idempotency` is source/Vanilla patched and smoke pending as of 2026-06-02. The patch removes the second `Skill_Init.sqf` call in client init while preserving the immediate `WFBE_SK_FNC_Apply` call.

## What I Read

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Apply.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_PreRespawnHandler.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- Vanilla Takistan `Client/Init/Init_Client.sqf` after LoadoutManager propagation.

## What The Code Did

Before the patch, `Init_Client.sqf` ran `Client\Module\Skill\Skill_Init.sqf` twice:

| Source | Behavior |
| --- | --- |
| `Client/Init/Init_Client.sqf:547` | First `Skill_Init.sqf` call. This is needed before default gear selection because `:551` switches on `WFBE_SK_V_Type`. |
| `Client/Init/Init_Client.sqf:571-572` | Second `Skill_Init.sqf` call immediately before `(player) Call WFBE_SK_FNC_Apply`. |
| `Client/Module/Skill/Skill_Init.sqf:10` | Compiles `WFBE_SK_FNC_Apply`. |
| `Client/Module/Skill/Skill_Init.sqf:39-49` | Sets `WFBE_SK_V_Type` and multiplies local `WFBE_C_PLAYERS_AI_MAX` by `1.5` for Soldier class. |
| `Common/Init/Init_CommonConstants.sqf:249` | Default `WFBE_C_PLAYERS_AI_MAX` is `16`. |
| `Client/Functions/Client_PreRespawnHandler.sqf:5` | Respawn reapply calls `WFBE_SK_FNC_Apply` without rerunning `Skill_Init.sqf`. |

Because `Skill_Init.sqf:49` has no applied flag or base-value reset, a Soldier client could compound the local AI cap from 16 -> 24 -> 36 during one init path. The likely intended one-time Soldier boost is 16 -> 24.

## Patch Shape

The source mission patch removes only the second `Skill_Init.sqf` call:

- Keep `Client/Init/Init_Client.sqf:547` so `WFBE_SK_V_Type` exists before class-based default gear selection.
- Keep `(player) Call WFBE_SK_FNC_Apply` in the later skill block so the selected class still gets skill effects/actions before play.
- Do not change `Skill_Init.sqf` internals, because a single init call is enough for the current path.
- Propagate with `Tools/LoadoutManager` so Vanilla Takistan matches source.

Changed source files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf`

## Validation

Source-only validation done:

- Chernarus `Init_Client.sqf` has exactly one `Skill_Init.sqf` call and one immediate `WFBE_SK_FNC_Apply` call.
- Vanilla Takistan `Init_Client.sqf` has exactly one `Skill_Init.sqf` call and one immediate `WFBE_SK_FNC_Apply` call.
- `Skill_Init.sqf` still compiles `WFBE_SK_FNC_Apply`.
- `Client_PreRespawnHandler.sqf` still applies skill effects on respawn.
- `git diff --check` passes.
- `dotnet run` in `Tools/LoadoutManager` reached `CHERNARUS DONE` and `TAKISTAN DONE`, then failed at the known missing `7za` environment variable described in repo instructions.

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
