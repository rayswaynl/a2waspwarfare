# AICOM V2 External Prior Art

Source status: `E:\arma2-cache` was not reachable from the sandbox and web search returned no usable source snippets in this run. This report records the required prior-art architecture findings and the exact archive verification work still needed. Password for archive extraction per roster: `armedassault`.

## Source Verification Queue

| Source | Required location | Status | Required extraction |
|---|---|---|---|
| HETMAN Artificial Leader / HAL by Rydygier | `E:\arma2-cache` and BI forum/manual mirrors | Blocked | Extract scripts/manual; identify objective scoring, reserve, mission cycle. |
| Oden Warfare16 | Miksuu Drive mirror / `E:\arma2-cache` | Blocked | Extract `airAssault.sqf` and island-index logic. |
| Gossamer Warfare v3 | Armaholic/Jerry Hopper mirror | Blocked | Extract garrison and town defense commander patterns. |
| crCTI | GitHub/BI forums/archive | Blocked | Extract commander objective assignment/economy driver. |
| WICT | BI forums/archive | Blocked | Extract dynamic zone/spawn objective model. |
| Benny Warfare BE 2.073 | upstream branch and archive | Local git blocked | Confirm inherited null commander, AI wallet, upgrade arrays. |

## HETMAN HAL Architecture Finding

HAL is the most important A2 commander prior art because it treats the commander as a planning loop over objectives and force pools, not as a per-group waypoint script. Required V2 lessons:

| HAL concept | Architectural meaning | WASP V2 equivalent |
|---|---|---|
| Leader brain | A central leader assesses known objectives and subordinate groups. | Server-only AICOM supervisor namespace. |
| Objective scoring | Objectives are ranked by value, distance/reach, enemy presence, friendly strength, and strategic role. | Pure Assessment layer computes target utility and local superiority. |
| Force reservation | Not every group is committed; some forces defend, reserve, recon, support, or wait for mass. | Planning layer has committed assault bundle plus reserve pool; no dribble attacks. |
| Mission cycle | Periodic cycle: scan intel, classify groups, score objectives, assign missions, monitor completion, replan after delay. | V2 cycle with hysteresis, event-driven urgent hooks, and heartbeat. |
| Task taxonomy | Attack, defend, recon, flank, support, reserve, withdraw are separate mission types. | V2 order record has explicit type and WHY, not only target position. |
| Recon before assault | Better attacks follow reconnaissance/intel accumulation. | Doctrine: legible recon/artillery before assault and no psychic reactions. |
| Morale/casualty awareness | Depleted groups are withdrawn or reassigned rather than endlessly pushed. | Depleted merge and retreat/reform. |

HAL design to copy conceptually: centralized scoring plus reserved force pools. HAL design not to copy blindly: any scheduler, command syntax, or group ownership assumption that does not fit A2 OA Warfare HC locality.

## Benny Warfare / BE 2.073

| Finding | Status | V2 implication |
|---|---|---|
| WASP inherited the Warfare economy/build/upgrade skeleton, including AI wallets and ordered upgrade arrays. | VERIFY against `upstream/v24042025` and `Server_AI_Com_Upgrade.sqf`. | V2 should wrap existing economy APIs instead of replacing economy storage. |
| Stock upstream likely has no comparable WASP AICOM `Server/AI/Commander/` tree. | Roster expects zero upstream delta. | WASP AICOM is a fork-owned system; prior art is conceptual, not direct upstream port. |
| Static upgrade arrays are inherited-style behavior. | VERIFY. | V2 build/research planner may mutate goals but must keep existing arrays as fallback. |

## crCTI

Required concrete finding to verify: crCTI-style commanders generally separate economy/base production from objective assignment and use town value/front position to decide attacks. For V2, borrow the separation of concerns, not code.

| Idea | Tag | WASP equivalent |
|---|---|---|
| Objective assignment from town/front state | A2-compatible concept | Assessment target utility over map profile graph. |
| Economy driver separate from assault orders | A2-compatible concept | Build/research planner separate from team execution. |
| Commander can function without HC-specific locality | Needs porting | WASP requires HC contract and server-owned decisions. |

## WICT

WICT is relevant as dynamic battlefield pressure and zone activation prior art.

| Idea | Tag | WASP equivalent |
|---|---|---|
| Zone-based activation around player/front | A2-compatible concept | Wildcard/no-dead-air events and map-profile zones. |
| Dynamic spawn pressure | Needs porting | Must respect group caps, GUER volume, and Warfare economy. |
| Ambient battle illusion | Concept-only for AICOM | Do not use to fake commander decisions without WHY/intel telemetry. |

## Oden Warfare16

| Idea | Tag | WASP equivalent |
|---|---|---|
| Island-index air-assault branch | A2-compatible after source verification | Utes attacker doctrine and any map-profile amphibious fallback. |
| Air insertion as workaround for boat AI | A2-compatible concept | Invasion attacker waves can use air assault when boats fail. |
| Map/island objective indexing | Needs porting | V2 map profile route graph and zone annotations. |

## Gossamer Warfare

| Idea | Tag | WASP equivalent |
|---|---|---|
| Strong town garrisons and defense presence | A2-compatible concept | V2 defense/reserve planner and Utes defender profile. |
| Garrison placement by town geometry | Needs data port | Map profiles annotate approach vectors and garrison footprints. |

## A3 Concepts Are Concept-Only

| Source family | Tag | Restriction |
|---|---|---|
| ALiVE | Concept-only | Do not port A3 commands, profile system, or remoteExec assumptions. |
| Antistasi | Concept-only | Guerrilla pressure ideas only; no A3 syntax or economy assumptions. |
| Modern Arma AI mods | Concept-only | Any `remoteExec`, `pushBack`, `params`, `findIf`, or A3 group ownership API is banned. |

## Borrow Verdict Table

| Idea | Source | Verdict | Effort | Why |
|---|---|---|---|---|
| Central objective scoring | HAL | HIGH | Medium | Matches pure planning core and solves target churn. |
| Force reservation | HAL | HIGH | Medium | Required for "refuse fair fights". |
| Mission cycle with deliberate replans | HAL | HIGH | Low | Fits commit/hysteresis doctrine. |
| Island-index air assault | Oden Warfare16 | HIGH for Utes, MEDIUM for AICOM | Medium | A2 boat/pathing mitigation. |
| Zone activation pressure | WICT | MEDIUM | Medium | Useful for visible pulse, but must not fake intel. |
| Garrison geometry | Gossamer | MEDIUM | Medium | Useful for map profiles/defense. |
| crCTI economy/objective split | crCTI | MEDIUM | Low | Reinforces layer separation. |
| A3 virtual AI/profile systems | ALiVE/Antistasi | LOW concept-only | High | A2/OA incompatibility and banned commands. |

## Archive Extraction Instructions for Owner/Orchestrator

1. Extract HAL archive from `E:\arma2-cache` with password `armedassault`.
2. Copy only file names, script structure, and summarized decision architecture into this doc; do not paste large manuals.
3. Confirm Oden `airAssault.sqf` island-index logic and note exact file id/path.
4. Fill source citations for crCTI and WICT concrete findings.
5. Re-run final A2 safety pass: every borrowed idea must be one of `A2-compatible`, `needs-porting`, or `concept-only`.
