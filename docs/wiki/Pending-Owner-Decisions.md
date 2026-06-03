# Pending Owner Decisions

This page keeps open code-owner decisions in one place. Review work is not the blocker for these rows; choosing and applying fixes is.

## Authority And Forgery

| Decision | Findings | Severity | Owner note |
| --- | --- | --- | --- |
| PVF dispatcher allowlist plus handler authority | DR-1, DR-38 | High | `Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` still compile sender-chosen command strings. Use [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook). |
| Direct publicVariable authority | DR-41, DR-44 | High | Channels such as `ATTACK_WAVE_INIT` and `wfbe_supply_temp_<side>` are outside the PVF dispatcher. Each direct PVEH needs server-side re-derivation. |
| Economy spend/effect paths | DR-6, DR-14, DR-16, DR-22, DR-23, DR-27, DR-28 | High/Critical | Construction, buy/sell, upgrades, ICBM, gear/EASA/service and supply rewards are still legacy/client-authoritative in important places. |
| BattlEye posture | DR-30 | High if public | In-repo evidence only proves the AFK publicVariable rule. Production `BEpath` filters need server-owner confirmation. |

## Correctness And Runtime Robustness

| Decision | Finding | Severity | Status |
| --- | --- | --- | --- |
| Commander reassignment helper/caller bug and duplicate notification | DR-15 | Medium | Patch-ready/current-source-unpatched; see [Commander reassignment call shape](Commander-Reassignment-Call-Shape). |
| Factory queue soft-lock and token churn | DR-33 | Medium | Patch-ready/current-source-unpatched; see [Factory queue counter token cleanup](Factory-Queue-Counter-Token-Cleanup). |
| Paratrooper drop marker registration | DR-2 | Medium | Sender and handler exist, but client PVF registration is still missing; see [Paratrooper marker revival](Paratrooper-Marker-Revival). |
| Duplicate client `Skill_Init` | current-source snapshot | Medium | Current source/Vanilla still call `Skill_Init` twice before `WFBE_SK_FNC_Apply`. |
| Hosted/listen server FPS loop spin | DR-19 | Low/Medium | Current source/Vanilla still enter both loops before checking `isDedicated`; see [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep). |
| Supply cooldown casing and reward authority | DR-18 plus supply review | Medium/High | Standardize cooldown key and move mission state/reward authority server-side; see [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook). |
| Supply command-center scan narrowing | performance sweep | Low | Patch-ready/current-source-unpatched; see [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing). |
| Victory winner inversion / duplicate game-end | DR-11, DR-13, DR-36 | High | Parenthesize/guard win clauses and prevent same-tick double-fire. |
| JIP wait-chain timeouts | DR-37 | Medium | Add defensive timeouts without breaking OA JIP synchronization. |
| WASP marker wait cleanup | DR-40 | Low | Opportunity-not-patched; add throttled wait/sleep after OA display smoke. |

## Maintenance Model Decisions

| Decision | Finding | Note |
| --- | --- | --- |
| Modded missions: regenerate from source vs maintain as forks | DR-32 | Napf/eden/lingor are divergent hand-edited forks; source fixes do not automatically reach them. |
| Abandoned stub missions: complete or delete | DR-32 | Sahrani/dingor/tavi/isladuala are non-runnable stubs. |
| MASH map marker feature: revive or remove | DR-34 | Dead both ends; revive needs server-held list, JIP re-send and unique marker names. |
| Dead WASP actions | DR-35 | `OnArmor` and `GearYourUnit` are commented in `AddActions.sqf`. |
| `supplyMissionActive.sqf` dead twin | DR-39 | Compiled but no static caller found. |
| Duplicate `Init_Server` binds | DR-43b | Low-risk cleanup, especially around endgame logging. |
| `version.sqf` source/packaging policy | DR-43a | Referenced by mission boot but generated/ignored in the current workflow. |

## Continue Reading

Coverage: [Codebase coverage ledger](Codebase-Coverage-Ledger) | Findings: [Deep-review findings](Deep-Review-Findings) | Feature register: [Feature status register](Feature-Status-Register)
