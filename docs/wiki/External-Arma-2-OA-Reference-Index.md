# External Arma 2 OA Reference Index

This page maps official or near-official Arma 2 Operation Arrowhead references to the mission concepts used in `a2waspwarfare`. Treat these links as engine/runtime context only. Repo source still wins for what this fork actually does.

## Quick Rule

Use Arma 2 OA 1.64-era behavior. If a Bohemia page also mentions Arma 3 behavior, do not import the Arma 3-only part unless the wiki explicitly labels it as non-authoritative context.

## Reference Map

| Concept | External reference | Applies here | Avoid this mistake |
| --- | --- | --- | --- |
| OA command availability | [Arma 2 OA scripting command category](https://community.bohemia.net/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands) | Baseline check before using commands in mission SQF. | Do not add Arma 3-only commands to OA mission code. |
| Broadcast public variables and JIP persistence | [publicVariable](https://community.bohemia.net/wiki/publicVariable) | Generic PVF broadcasts and direct channels such as `WFBE_DAYNIGHT_DATE`, `SEND_MESSAGE`, side supply and supply-mission status. | Do not assume changing a variable auto-syncs it; the repo must broadcast it again. Also keep payloads small. |
| Client to server PV | [publicVariableServer](https://community.bohemia.net/wiki/publicVariableServer) | `Common_SendToServerOptimized.sqf` uses this for OA/CO client-to-server PVF traffic. | Do not assume this validates sender authority; it only targets the server. |
| Server to one client PV | [publicVariableClient](https://community.bohemia.net/wiki/publicVariableClient), [owner](https://community.bohemia.net/wiki/owner) | `Common_SendToClient.sqf` targets `owner _player` and reduces broadcast waste for single-client replies. | Do not use broadcast plus UID filtering when true unicast is available and supported. |
| Public-variable handlers | [addPublicVariableEventHandler](https://community.bohemia.net/wiki/addPublicVariableEventHandler) | `Init_PublicVariables.sqf` registers `WFBE_PVF_*`; many direct channels self-register handlers. | The handler sees variable name and value, not a trusted sender identity. Server authority must be reconstructed from server-side state. |
| Locality, hosted server, JIP and headless client roles | [Locality in Multiplayer](https://community.bohemia.net/wiki/Locality_in_Multiplayer) | `initJIPCompatible.sqf`, `Init_Server.sqf`, `Init_Client.sqf` and `Init_HC.sqf` split behavior by server, player client and headless client. | Do not collapse hosted server, dedicated server, normal client and HC paths; this fork has different branches for each. |
| Mission description and parameters | [Description.ext](https://community.bohemia.net/wiki/Description.ext), [Mission Parameters](https://community.bohemia.net/wiki/paramsArray), [Arma 2 OA multiple mission parameters](https://community.bohemia.net/wiki/Arma_2_OA:_Multiple_Mission_Parameters_Configuration) | `description.ext` includes `version.sqf`, resource headers and `Rsc/Parameters.hpp`. | Do not forget DR-43: raw source currently lacks `version.sqf`, so packaging/generation context matters. |
| FSM files and `execFSM` | [FSM](https://community.bohemia.net/wiki/FSM), [execFSM](https://community.bohemia.net/wiki/execFSM) | Live FSMs are `Client/FSM/updateactions.fsm`, `Client/FSM/updateavailableactions.fsm` and `Client/kb/hq.fsm`. Missing `Server/FSM/supplytruck.fsm` is part of the AI supply logistics landmine. | Do not document `AI_UpdateSupplyTruck.sqf` as restorable by a compile line alone; the FSM file is absent. |
| `compile`, `preprocessFile`, `preprocessFileLineNumbers` | [compile](https://community.bohemia.net/wiki/compile), [preprocessFile](https://community.bohemia.net/wiki/preprocessFile), [preprocessFileLineNumbers](https://community.bohemia.net/wiki/preprocessFileLineNumbers) | Init scripts compile hundreds of SQF files; PVF registration compiles `CLTFNC*` and `SRVFNC*` functions. | Do not compile sender-controlled strings. DR-1's fix replaces per-message `Call Compile` lookup with safe namespace lookup. |
| Extensions | [callExtension](https://community.bohemia.net/wiki/callExtension) | AntiStack and database bridge work through the repo's `Extension/` project and server module calls. | `callExtension` is blocking; do not put slow or untrusted extension calls in hot loops without explicit review. |
| BattlEye server setup | [BattlEye](https://community.bohemia.net/wiki/BattlEye) | `BattlEyeFilter/publicvariable.txt` is part of deployment/runtime hardening, outside LoadoutManager mission propagation. | Do not treat missing or weak BE filters as fixed by mission generation. |
| Arma 2/OA public-variable filters | [Bohemia forum: server-side event logging/blocking](https://forums.bohemia.net/forums/topic/131085-introducing-server-side-event-loggingblocking/) | DR-1 and DR-41 need a real `publicvariable.txt` allow-list covering `WFBE_PVF_*` and direct channels. | Do not add a restrictive default without allow-listing legitimate channels, or normal mission networking will kick players. |

## How To Use This Page

- For engine semantics, start from the reference map above.
- For repo behavior, read the source-backed wiki page next: [Networking and public variables](Networking-And-Public-Variables), [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Tools and build workflow](Tools-And-Build-Workflow), [External integrations](External-Integrations), or [Deep-review findings](Deep-Review-Findings).
- For any authority/security claim, cite both sides: the engine reference that explains the primitive and the repo file that shows this fork's actual payload, handler or lifecycle path.

## Source Anchors Checked For This Pass

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_PublicVariables.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_SendToServerOptimized.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_SendToClient.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/description.ext`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/FSM/`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/kb/hq.fsm`
- `BattlEyeFilter/publicvariable.txt`
- `Extension/`

## Continue Reading

- [Networking and public variables](Networking-And-Public-Variables)
- [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle)
- [Tools and build workflow](Tools-And-Build-Workflow)
- [Deep-review findings](Deep-Review-Findings)
