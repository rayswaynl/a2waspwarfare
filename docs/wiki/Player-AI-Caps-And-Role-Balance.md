# Player AI Caps And Role Balance

This page documents the live player group-size cap used by the buy menu and RHUD, plus a Discord-ready balance table for the default server setting.

Scope: source mission `Missions/[55-2hc]warfarev2_073v48co.chernarus`. The formulas below have been checked in the active docs branch; before making a release claim, recheck the exact branch or PBO being tested because `master`, docs branches and release branches can differ.

For the old BennyBoy WarfareBE baseline behind the current FPS debate, see [Old WarfareBE performance comparison](Old-WarfareBE-Performance-Comparison). The short version: old default player AI was lower (`12` vs current Wasp lobby default `15`), but old WarfareBE still had town scans, town-AI activation and static-defense gunners.

## Source Formula

The default multiplayer lobby value is `WFBE_C_PLAYERS_AI_MAX = 15` (`Rsc/Parameters.hpp:62-68`). If no lobby parameter supplies it, `Init_CommonConstants.sqf` falls back to `16`, so always state which baseline you are using.

The live buy menu and RHUD use the same shape:

| Source | Behavior |
| --- | --- |
| `Client/Module/Skill/Skill_Init.sqf:49` | Soldier-slot players multiply local `WFBE_C_PLAYERS_AI_MAX` by `1.5` with `ceil`. With the default lobby value, `15` becomes `23`. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:116-128` | Barracks upgrade scales the cap as `round(max/4)`, `round(max/4)*2`, `round(max/4)*3`, then full `max`. |
| `Client/GUI/GUI_Menu_BuyUnits.sqf:130-140` | If the player's group is the commander team, the cap gets `+10`; the menu checks queued units plus live group units plus requested crew slots against the final cap. |
| `Client/Client_UpdateRHUD.sqf:312-325` | RHUD mirrors the same visible max-units formula. |

Formula cheat sheet:

```text
base cap = WFBE_C_PLAYERS_AI_MAX
soldier base cap = ceil(1.5 * base cap)
commander group cap = barracks-scaled cap + 10
AI followers for a solo player = final group cap - 1
```

The cap is checked against live group units plus queued units. A solo player already counts as one live group unit, so the number of AI followers is usually `group cap - 1`.

Important naming trap: `WFBE_C_PLAYERS_AI_MAX` is the player follower cap. `WFBE_C_AI_MAX` is a separate AI-group knob exposed in `Rsc/Parameters.hpp:56-60` with a fallback at `Init_CommonConstants.sqf:92`; the 2026-06-05 branch check found no active maintained-root runtime consumer for that value across current source/Vanilla, `origin/master`, `miksuu/master` or release. Do not use `WFBE_C_AI_MAX` when answering how many AI a normal player can personally command; use [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs) for the cleanup route.

Scout recheck 2026-06-04: the current Chernarus source still matches the table below. `Common/Functions/Common_GetLiveUnits.sqf:1-8` counts the player as one live group unit, so the Discord table intentionally reports AI followers rather than total group cap.

## Discord Table

Default lobby baseline: `GroupSizePlayer = 15`. Values below are AI followers for a solo player.

```text
A2 Wasp Warfare - player AI follower caps

Barracks        Normal player   Commander   Soldier slot   Soldier + Commander
Level 0         3 AI            13 AI       5 AI           15 AI
Level 1         7 AI            17 AI       11 AI          21 AI
Level 2         11 AI           21 AI       17 AI          27 AI
Level 3         14 AI           24 AI       22 AI          32 AI
```

| Barracks level | Normal player | Commander | Soldier slot | Soldier + Commander |
| --- | ---: | ---: | ---: | ---: |
| Level 0 | 3 AI | 13 AI | 5 AI | 15 AI |
| Level 1 | 7 AI | 17 AI | 11 AI | 21 AI |
| Level 2 | 11 AI | 21 AI | 17 AI | 27 AI |
| Level 3 | 14 AI | 24 AI | 22 AI | 32 AI |

Group-slot version, including the player:

| Barracks level | Normal group cap | Commander group cap | Soldier group cap | Soldier commander group cap |
| --- | ---: | ---: | ---: | ---: |
| Level 0 | 4 | 14 | 6 | 16 |
| Level 1 | 8 | 18 | 12 | 22 |
| Level 2 | 12 | 22 | 18 | 28 |
| Level 3 | 15 | 25 | 23 | 33 |

Fallback baseline if the lobby parameter layer is absent: `WFBE_C_PLAYERS_AI_MAX = 16` from `Init_CommonConstants.sqf:243`.

| Barracks level | Normal player | Commander | Soldier slot | Soldier + Commander |
| --- | ---: | ---: | ---: | ---: |
| Level 0 | 3 AI | 13 AI | 5 AI | 15 AI |
| Level 1 | 7 AI | 17 AI | 11 AI | 21 AI |
| Level 2 | 11 AI | 21 AI | 17 AI | 27 AI |
| Level 3 | 15 AI | 25 AI | 23 AI | 33 AI |

Lobby/default note: the lobby parameter defaults AI teams to off (`WFBE_C_AI_TEAMS_ENABLED` default 0) while AI commander defaults to on (`WFBE_C_AI_COMMANDER_ENABLED` default 1), while the fallback constants in `Init_CommonConstants.sqf` default them on if the parameter layer is absent. Do not use the fallback defaults as proof of live multiplayer settings unless the parameter include failed or was intentionally bypassed.

## Adjacent Limits That Are Not The Player Cap

Factory queue caps throttle production starts, not AI followers. They are initialized client-side at `Client/Init/Init_Client.sqf:185-196` and enforced by the buy menu at `GUI_Menu_BuyUnits.sqf:145-158`.

```text
Factory queue caps

Barracks  10
Light      5
Heavy      5
Aircraft   2
Airport    2
Depot      4
```

Human squad membership is separate again. `WFBE_C_PLAYERS_SQUADS_MAX_PLAYERS = 4` (`Init_CommonConstants.sqf:264-266`) limits how many human players can join one squad through `Client_FNC_Groups.sqf:111-147,172-210`; it does not change the follower table above.

AI team joining is parameter-gated by `WFBE_C_AI_TEAMS_ENABLED` (`Rsc/Parameters.hpp:74-79`, `Init_CommonConstants.sqf:94-95`). The group UI checks that gate before letting a player request to join an AI-led group (`Client_FNC_Groups.sqf:129-136`), but that is not the same as increasing or reducing a player's own AI followers.

Headless/delegated AI limits are locality and performance routing, not personal squad size. `WFBE_C_AI_DELEGATION` is imported/forced in the init path (`initJIPCompatible.sqf:155-169`), while `WFBE_C_AI_DELEGATION_GROUPS_MAX = 1` and the FPS gate live in `Init_CommonConstants.sqf:98-100` and `Server_FNC_Delegation.sqf:145-157`.

AI commander behavior does not directly change the player follower cap in current source. `WFBE_C_AI_COMMANDER_ENABLED` is a lobby/runtime AI-commander toggle (`Rsc/Parameters.hpp:92-97`, `Init_CommonConstants.sqf:91-93`); stable source still treats full autonomous AI commander production as partial/latent, so do not answer player cap questions with AI commander production settings.

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

Before cutting CTI identity too hard, test current Wasp with the old-style cap neighborhood: normal roles around `8-10` late-game followers, Soldier kept higher, and commander bonus reduced or role-gated. Compare that against old WarfareBE with the same cap and view-distance settings.

Dynamic cap warning from the 2026-06-05 old-BE FPS archaeology pass: if caps later scale by live player count, do not implement it as a hidden client-only guess. Publish the active cap from trusted mission/server state, make buy menu and RHUD read the same value, and start with a non-destructive "future purchases only" cap so players do not suddenly lose already-fielded AI mid-fight.

## Dynamic Cap Proposal

The follow-up FPS opportunity scout produced a concrete test policy at `C:\Users\Steff\Documents\Codex\2026-06-05\wasp-old-vs-current-fps-investigation\outputs\Old-BE-vs-Current-Wasp-FPS-Opportunity-Audit.md`.

Recommended rollout:

1. Public pilot: cap normal players around `10` AI and record FPS/entity evidence. Keep this framed as a test, not a permanent identity change.
2. Final policy: server-published, role-aware dynamic cap based on total player count or per-side human count.
3. Enforcement: non-destructive for future purchases first. Do not delete already-fielded player AI when more players join.
4. UI parity: buy menu and RHUD must read the same active cap source.

Starting values for a full-server test:

| Total players | Approx. per side | Normal slots | Soldier slots | Commander bonus | Soldier commander ceiling | Intent |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 10 | 5 | 12 | 18 | +5 | 20 | Low-pop games keep classic CTI squad scale. |
| 15 | 7-8 | 10 | 16 | +5 | 20 | First public pilot target; close to the proposed "10 max" while preserving Soldier. |
| 20 | 10 | 9 | 15 | +5 | 18 | Starts separating full-server protection from low-pop feel. |
| 25 | 12-13 | 8 | 14 | +4 | 17 | Protects full-server FPS while retaining a Soldier squad role. |
| 30 | 15 | 7 | 12 | +3 | 15 | Full-server protection mode; avoids 30 players each bringing large personal squads. |

Formula sketch:

```text
normalCap = clamp(floor(sidePlayerAIBudget / max(1, sideHumanPlayers)), 7, 12)
soldierCap = clamp(normalCap + 5 or +6, 12, 18)
commanderBonus = if totalPlayers < 20 then 5 else if totalPlayers < 30 then 4 else 3
commanderCap = min(roleCap + commanderBonus, soldierCommanderCeiling)
```

Initial budgets to test: `110` player-owned AI per side for normal public play, `90` for stress testing. Keep town AI, static gunners, AI teams and support units outside this budget, but record them next to it so the project does not simply move load from player followers to town/server AI.

## Development Notes

- Do not use the unused `WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX = 6` constant as proof of current behavior. The live Soldier cap path uses `ceil (1.5 * WFBE_C_PLAYERS_AI_MAX)`.
- If `Skill_Init.sqf` ever runs more than once, Soldier cap inflation can compound. Current source calls `Skill_Init.sqf` once before `WFBE_SK_FNC_Apply`; keep [Client skill init idempotency](Client-Skill-Init-Idempotency) in the smoke plan.
- Vehicle crew counts also consume group slots when selected in the buy menu (`Client_BuildUnit.sqf:216-235,237-240,364-460`); empty vehicles do not consume follower slots, but crewed heavy vehicles can fill a group quickly.
- Factory queue maxima, human squad size, AI-team joining, headless delegation and AI-commander toggles are adjacent limits. Keep them out of Discord cap answers unless someone specifically asks about production queues, player squad joining or server locality.

## Continue Reading

Previous: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Next: [AI, headless and performance](AI-Headless-And-Performance)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
