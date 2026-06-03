# Performance Opportunity Sweep

This page ranks source-backed performance opportunities in the Chernarus source mission. It deliberately separates measurement-led tuning from fixes that are already bundled with security, correctness or gameplay behavior.

## Ranked Opportunities

| Priority | Opportunity | Source evidence | Why it matters | Implementation shape |
| --- | --- | --- | --- | --- |
| P0 | PVF dispatcher lookup | `Server/Functions/Server_HandlePVF.sqf:14`; `Client/Functions/Client_HandlePVF.sqf:22`; `Common/Init/Init_PublicVariables.sqf:44-50` | Every PVF dispatch recompiles the sender-chosen function string. This is both performance waste and DR-1 hardening. | Use [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook): OA-safe allowlist lookup, `typeName` guard, keep `Spawn`, log rejects. |
| P1 | Hosted server FPS loop sleep/consolidation | `Server/GUI/serverFpsGUI.sqf:1,4,10`; `Server/Module/serverFPS/monitorServerFPS.sqf:1-6`; `Server/Init/Init_Server.sqf:578,595` | Current source/Vanilla still enter loops before `isDedicated`; on hosted/listen the sleep is skipped. | Patch-ready/current-source-unpatched. Exit or sleep non-dedicated before the loop while preserving dedicated 8-second publishing. |
| P1 | Supply mission command-center scan narrowing | Source Chernarus `Server/Module/supplyMission/supplyMissionStarted.sqf:42,45,61`; generated Vanilla `:25,28,44` | The 80m return scan still asks for all classes before filtering `Base_WarfareBUAVterminal`; the 8m nearby-player/object scan is intentionally broad. | Patch-ready/current-source-unpatched. Narrow only the 80m command-center scan with class-filtered `nearestObjects`; do not replace the structure scan with `nearEntities`. |
| P2 | Duplicate client `Skill_Init` | `Client/Init/Init_Client.sqf:547,571-572`; `Client/Module/Skill/Skill_Init.sqf:39-49` | Duplicate initialization can compound Soldier AI cap because `Skill_Init` is not idempotent. | Patch-ready/current-source-unpatched. Remove the duplicate init or make the routine idempotent; keep `WFBE_SK_FNC_Apply`. |
| P2 | Factory queue broadcast churn and soft-lock | `Client/Functions/Client_BuildUnit.sqf:167-207`; `:365`; `:467-469` | Random queue tokens, public queue broadcasts and the crewless early exit combine into correctness/network churn risk. | Patch-ready/current-source-unpatched. Fix queue decrement first, then token uniqueness/broadcast reduction with UI smoke. |
| P2 | WASP marker dialog busy wait | `WASP/global_marking_monitor.sqf:62-64,73,80` | Display 54 wait is sleepless and time-bounded; display 12 already uses a throttled wait idiom. | Opportunity-not-patched. Add a small sleep/timeout after OA display timing smoke. |
| P3 | Cleaner/restorer wide scans | `Server/FSM/cleaners/*`; `Server/FSM/restorers/buildings_restorer.sqf` | Wide scans exist but run on long timers, sleep between items and have performance audit rows. | Measurement first. Do not patch until RPT audit output proves cost. |

## Not First-Patch Items

- Town and town-AI loops already include cooperative sleeps and `PerformanceAudit_Record` calls. Changing scan cadence can alter capture/activation/despawn behavior.
- Client marker loops and RHUD already include visibility/caching throttles. Use performance audit output before changing cadence.
- Cleaner/restorer scripts should stay audit-led because their wide scans are low-cadence and spread per-item work with sleeps.

## Suggested Patch Order

1. PVF dispatcher lookup, because it is both P0 security and performance.
2. Hosted server FPS loop sleep, if hosted/listen mode still matters.
3. Supply command-center scan narrowing.
4. Duplicate client `Skill_Init`.
5. Factory queue cleanup.
6. WASP marker dialog wait cleanup.
7. Cleaner/restorer or marker-loop tuning only after RPT evidence.

## Continue Reading

Runtime context: [AI, headless and performance](AI-Headless-And-Performance) | Current truth: [Current source status snapshot](Current-Source-Status-Snapshot) | Backlog: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)
