# Current Source Status Snapshot

Last checked: 2026-06-02T18:51+02:00 by direct source inspection against source Chernarus and generated Vanilla Takistan.

Use this page before trusting older worklog, event or knowledge entries about the disputed cleanup lanes. Current source Chernarus and generated Vanilla Takistan are implementation-ready, not patched, for the six cleanup lanes below; WASP marker wait cleanup also remains unpatched. Arma 2 OA runtime smoke follows after future source patches.

The source repo status at this check only showed unrelated `Init_CommonConstants.sqf` and `Rsc/Parameters.hpp` edits. Those source edits shift the Chernarus supply-mission line numbers, but the disputed lane behavior still matches the current unpatched evidence below.

## Current Findings

| Lane | Current source state | Evidence |
| --- | --- | --- |
| Commander reassignment DR-15 | Patch-ready/current-source-unpatched. `Server_AssignNewCommander.sqf` still assigns `_side = _this`, while `RequestNewCommander.sqf` still sends its own `new-commander-assigned` notification after spawning the helper. | Source: `Server/Functions/Server_AssignNewCommander.sqf:3,9`; `Server/PVFunctions/RequestNewCommander.sqf:13-14`. Vanilla: same files/lines under `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`. |
| Factory queue cleanup DR-33 | Patch-ready/current-source-unpatched. `Client_BuildUnit.sqf` still uses random `varQueu` token churn, and the crewless branch still exits without the local queue decrement. | Source: `Client/Functions/Client_BuildUnit.sqf:167-168,213,365,467,469`. Vanilla: same file/lines. Public `queu` broadcast review remains separate. |
| Paratrooper marker revival | Patch-ready/current-source-unpatched. Sender and handler file exist, but `HandleParatrooperMarkerCreation` is still absent from the client PVF registration list. | Source: `Server/Support/Support_Paratroopers.sqf:117`; `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:1,20,30,38,45`; `Common/Init/Init_PublicVariables.sqf:31-41,46` lacks the command. Vanilla: same maintained-target state. |
| Duplicate client `Skill_Init` | Patch-ready/current-source-unpatched. Client init still calls `Skill_Init.sqf` twice before applying skills. | Source: `Client/Init/Init_Client.sqf:547,571-572`. Vanilla: same file/lines. |
| Hosted server FPS loop sleep | Patch-ready/current-source-unpatched. Both FPS publishers still check `isDedicated` inside their scripts rather than exiting/sleeping non-dedicated hosts before the loop. | Source: `Server/GUI/serverFpsGUI.sqf:4`; `Server/Module/serverFPS/monitorServerFPS.sqf:2`. Vanilla: same files/lines. |
| Supply mission command-center scan narrowing | Patch-ready/current-source-unpatched. The 80-meter command-center scan still uses a broad class list before filtering for `Base_WarfareBUAVterminal`; the 8-meter nearby-object scan remains separately broad by design. | Source Chernarus: `Server/Module/supplyMission/supplyMissionStarted.sqf:37,39,42,45,61`. Vanilla: same file at `:20,22,25,28,44`. |
| WASP marker wait cleanup | Opportunity-not-patched. The display-54 wait remains sleepless; the display-12 sibling already uses `sleep 0.1`. | Source: launched from `Client/Init/Init_Client.sqf:267`; `WASP/global_marking_monitor.sqf:62,64,68-69,80-81`. Vanilla: same file/lines. |

## Handoff Rule

The source-patched pulses in older notes are superseded by this direct source+Vanilla check. Do not mark any lane above as source/Vanilla patched until Chernarus source is patched, generated Vanilla Takistan is propagated or independently verified, and the relevant Arma 2 OA runtime smoke is recorded.

## Continue Reading

Previous: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) | Next: [Feature status register](Feature-Status-Register)

Main map: [Home](Home) | Fast path: [LLM agent entry pack](LLM-Agent-Entry-Pack) | Agent file: [`agent-context.json`](agent-context.json)
