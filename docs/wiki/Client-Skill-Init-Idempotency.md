# Client Skill Init Idempotency

## Status

`client-skill-init-idempotency` is patch-ready/current-source-unpatched. Current source Chernarus and generated Vanilla Takistan still call `Skill_Init.sqf` at `Client/Init/Init_Client.sqf:547` and again at `:571`, then call `WFBE_SK_FNC_Apply` at `:572`.

## What I Read

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Init.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Apply.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_PreRespawnHandler.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf`

## What The Code Does Now

Current source/Vanilla still run `Client\Module\Skill\Skill_Init.sqf` twice before applying the selected class effects:

| Source | Behavior |
| --- | --- |
| `Client/Init/Init_Client.sqf:547` | First `Skill_Init.sqf` call. This is needed before default gear selection because `:551` switches on `WFBE_SK_V_Type`. |
| `Client/Init/Init_Client.sqf:571` | Second `Skill_Init.sqf` call; this is the duplicate to remove. |
| `Client/Init/Init_Client.sqf:572` | `(player) Call WFBE_SK_FNC_Apply`; this apply call should remain after the duplicate init is removed. |
| `Client/Module/Skill/Skill_Init.sqf:10` | Compiles `WFBE_SK_FNC_Apply`. |
| `Client/Module/Skill/Skill_Init.sqf:39-49` | Sets `WFBE_SK_V_Type` and multiplies local `WFBE_C_PLAYERS_AI_MAX` by `1.5` for Soldier class. |
| `Common/Init/Init_CommonConstants.sqf:249` | Default `WFBE_C_PLAYERS_AI_MAX` is `16`. |
| `Client/Functions/Client_PreRespawnHandler.sqf:5` | Respawn reapply calls `WFBE_SK_FNC_Apply` without rerunning `Skill_Init.sqf`. |

Because `Skill_Init.sqf:49` has no applied flag or base-value reset, the duplicated init path can compound a Soldier client's local AI cap from 16 -> 24 -> 36 during one client init path. The likely intended one-time 16 -> 24 behavior still needs the source patch and Arma smoke.

## Patch Shape

The source/Vanilla patch should remove only the second `Skill_Init.sqf` call:

- Keep `Client/Init/Init_Client.sqf:547` so `WFBE_SK_V_Type` exists before class-based default gear selection.
- Keep `(player) Call WFBE_SK_FNC_Apply` in the later skill block so the selected class still gets skill effects/actions before play.
- Do not change `Skill_Init.sqf` internals, because a single init call should be enough after the patch.
- Propagate or patch Vanilla Takistan to the same single-init shape.

Expected changed maintained files:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf`

## Validation

Source-only after patch:

- After patching, Chernarus `Init_Client.sqf:547` should call `Skill_Init.sqf`; the later skill block should call `WFBE_SK_FNC_Apply` rather than compiling `Skill_Init.sqf` again.
- Vanilla Takistan is propagated to the same single-init shape.
- `Skill_Init.sqf` still compiles `WFBE_SK_FNC_Apply`.
- `Client_PreRespawnHandler.sqf` still applies skill effects on respawn.

Pending Arma smoke:

- Local/hosted: join as Soldier and confirm the visible/local AI cap is the one-time boosted value, not the compounded value.
- Local/hosted: join as non-Soldier and confirm normal cap/class behavior.
- Respawn: confirm skill actions/effects are present after death/respawn.
- Dedicated/JIP: confirm no client init regressions in JIP join path.

## Modded Mission Note

Modded mission folders also show duplicate `Skill_Init.sqf` calls in some variants, but those folders are divergent/generated/forked targets and several stale files contain merge-conflict markers. Per repo rules, do not patch modded folders by hand until the generated/forked mission maintenance model is resolved.

## Handoff

For Codex/future code owner:

- Run Arma smoke for Soldier/non-Soldier caps, respawn skill reapply and JIP client init before closing the lane as runtime-verified.
- If another path must call `Skill_Init.sqf`, guard only the Soldier AI-cap mutation or store a base cap before applying the 1.5x boost.
- Pair any future modded propagation with the generated mission cleanup work from `Tools-And-Build-Workflow`, DR-4 and DR-32.

For Claude:

- Good contradiction check: prove whether any UI or respawn path expects cooldown variables from the second init call after it is removed. Current source evidence says respawn uses `WFBE_SK_FNC_Apply` only.

## Continue Reading

- Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep)
- Next: [Feature status register](Feature-Status-Register)
