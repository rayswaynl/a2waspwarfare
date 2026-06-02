# Player AI Caps And Role Balance

This page documents the live player group-size cap used by the buy menu and RHUD, plus a Discord-ready balance table for the default server setting.

Scope: current `master` source mission, `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

## Source Formula

The default multiplayer lobby value is `WFBE_C_PLAYERS_AI_MAX = 15` (`Rsc/Parameters.hpp:62-68`). If no lobby parameter supplies it, `Init_CommonConstants.sqf` falls back to `16`, so always state which baseline you are using.

The live buy menu and RHUD use the same shape:

| Source | Behavior |
| --- | --- |
| `Client/Module/Skill/Skill_Init.sqf:49` | Soldier-slot players multiply local `WFBE_C_PLAYERS_AI_MAX` by `1.5` with `ceil`. With the default lobby value, `15` becomes `23`. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:112-122` | Barracks upgrade scales the cap as `round(max/4)`, `round(max/4)*2`, `round(max/4)*3`, then full `max`. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:123-128` | If the player's group is the commander team, the cap gets `+10`. |
| `Client/Client_UpdateRHUD.sqf:312-325` | RHUD mirrors the same visible max-units formula. |

The cap is checked against live group units plus queued units. A solo player already counts as one live group unit, so the number of AI followers is usually `group cap - 1`.

## Discord Table

Default lobby baseline: `GroupSizePlayer = 15`. Values below are AI followers for a solo player.

```text
A2 Wasp Warfare - player AI follower caps

Barracks        Normal player   Soldier slot   Soldier + Commander
Level 0         3 AI            5 AI           15 AI
Level 1         7 AI            11 AI          21 AI
Level 2         11 AI           17 AI          27 AI
Level 3         14 AI           22 AI          32 AI
```

| Barracks level | Normal player | Soldier slot | Soldier + Commander |
| --- | ---: | ---: | ---: |
| Level 0 | 3 AI | 5 AI | 15 AI |
| Level 1 | 7 AI | 11 AI | 21 AI |
| Level 2 | 11 AI | 17 AI | 27 AI |
| Level 3 | 14 AI | 22 AI | 32 AI |

Group-slot version, including the player:

| Barracks level | Normal group cap | Soldier group cap | Soldier commander group cap |
| --- | ---: | ---: | ---: |
| Level 0 | 4 | 6 | 16 |
| Level 1 | 8 | 12 | 22 |
| Level 2 | 12 | 18 | 28 |
| Level 3 | 15 | 23 | 33 |

## Balance Suggestions

The current table gives Soldier commanders a very large late-game squad. That is fun for infantry leadership, but it can become expensive for server FPS when many players fill their groups.

Suggested direction:

| Role | Suggested cap style | Reason |
| --- | --- | --- |
| Normal roles | Keep lower, around `8-10` AI at full barracks. | Engineers, medics, spotters and specops already bring utility; lower AI reduces background simulation load. |
| Soldier slot | Keep the big squad identity, around `16-20` AI at full barracks. | Soldier should be the role for players who want to lead infantry pushes. |
| Commander | Add a smaller fixed bonus, such as `+5` instead of `+10`, or only apply the full bonus to Soldier commanders. | Commander already has strategic power; too many personal AI can pull attention away from base/economy work and add server load. |
| Specialist commander | Consider normal-role cap plus `+5`, not full Soldier-scale cap. | Keeps commander survivable without making every commander a frontline platoon. |

For a public server, the cleanest tuning lever is the lobby `WFBE_C_PLAYERS_AI_MAX` parameter. Code changes should come later if the project wants role-specific caps rather than the current Soldier multiplier plus commander bonus.

## Development Notes

- Do not use the unused `WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX = 6` constant as proof of current behavior. The live Soldier cap path uses `ceil (1.5 * WFBE_C_PLAYERS_AI_MAX)`.
- If `Skill_Init.sqf` ever runs more than once, Soldier cap inflation can compound. Current source calls `Skill_Init.sqf` once before `WFBE_SK_FNC_Apply`; keep [Client skill init idempotency](Client-Skill-Init-Idempotency) in the smoke plan.
- Vehicle crew counts also consume group slots when selected in the buy menu.

## Continue Reading

Previous: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Next: [AI, headless and performance](AI-Headless-And-Performance)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
