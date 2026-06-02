# Arma 2 OA External Reference Guide

This page is the first stop for engine-level claims. Use it to decide which official Bohemia reference to check before changing mission SQF or writing architecture guidance.

Repo source still wins for what `a2waspwarfare` actually does. External docs only explain the Arma 2 OA primitive underneath the repo code.

## Fast Map

| If you are touching | Check first | Wasp pages to read next |
| --- | --- | --- |
| PVF dispatcher, direct public variables, JIP state | [publicVariable](https://community.bohemia.net/wiki/publicVariable), [publicVariableServer](https://community.bohemia.net/wiki/publicVariableServer), [publicVariableClient](https://community.bohemia.net/wiki/publicVariableClient), [addPublicVariableEventHandler](https://community.bohemia.net/wiki/addPublicVariableEventHandler) | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) |
| Object variables and replicated state | [setVariable](https://community.bohemia.net/wiki/setVariable), [getVariable](https://community.bohemia.net/wiki/getVariable) | [Variable and naming conventions](Variable-And-Naming-Conventions), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Economy, towns and supply](Economy-Towns-And-Supply) |
| Object scans and class filters | [nearestObjects](https://community.bohemia.net/wiki/nearestObjects), [isKindOf](https://community.bohemia.net/wiki/isKindOf) | [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Compiled handler lookup and source line diagnostics | [compile](https://community.bohemia.net/wiki/compile), [preprocessFile](https://community.bohemia.net/wiki/preprocessFile), [preprocessFileLineNumbers](https://community.bohemia.net/wiki/preprocessFileLineNumbers), [missionNamespace](https://community.bohemia.net/wiki/missionNamespace) | [SQF code atlas](SQF-Code-Atlas), [Function and module index](Function-And-Module-Index), [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) |
| Role split, hosted/dedicated behavior, JIP and HC | [Locality in Multiplayer](https://community.bohemia.net/wiki/Locality_in_Multiplayer), [Description.ext](https://community.bohemia.net/wiki/Description.ext), [paramsArray](https://community.bohemia.net/wiki/paramsArray) | [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [AI, headless and performance](AI-Headless-And-Performance) |
| FSMs, extensions and deployment hardening | [FSM](https://community.bohemia.net/wiki/FSM), [execFSM](https://community.bohemia.net/wiki/execFSM), [callExtension](https://community.bohemia.net/wiki/callExtension), [BattlEye](https://community.bohemia.net/wiki/BattlEye) | [Modules atlas](Modules-Atlas), [Tools and build workflow](Tools-And-Build-Workflow), [External integrations](External-Integrations) |

## Guardrails

- `publicVariable` broadcasts the current missionNamespace variable value; later local changes do not sync automatically unless code broadcasts again. The publicVariable page also notes that broadcast variables are available to JIP clients with their last broadcast value.
- `addPublicVariableEventHandler` fires when a broadcast is received. It is not a sender-authentication API, so Wasp server handlers must re-derive side, role, funds, object ownership and range from server-owned state.
- `publicVariableServer` and `publicVariableClient` target direction; they do not validate the gameplay authority of the payload. This is why DR-1 PVF dispatcher hardening and DR-41 direct-channel hardening are separate layers.
- `nearestObjects` accepts a class-name array and `[]` searches all classes. The command uses `isKindOf` matching, so a parent class such as `Base_WarfareBUAVterminal` can cover inherited command-center terminals.
- `preprocessFileLineNumbers` preserves file/line context for runtime errors. Prefer it for compiled mission files, and do not reintroduce per-message `Call Compile` on sender-controlled strings.
- Avoid Arma 3-only assumptions unless explicitly labelled as non-authoritative. In particular, do not introduce `remoteExec`, `remoteExecCall`, `params`, `parseSimpleArray` or `isEqualTo` into OA mission SQF without an OA availability proof.

## Common Mistakes

| Mistake | Better move |
| --- | --- |
| Treating a client menu check as server authority. | Keep the menu as affordance and validate the request on the server. |
| Assuming a public-variable handler proves who sent a request. | Reconstruct requester/side from trusted server state or channel context. |
| Replacing a broad `nearestObjects` scan without smoking gameplay. | Use the class-filter candidate, then smoke real map objects and mission behavior. |
| Copying an Arma 3 wiki example directly into OA code. | Check OA command availability and prefer source-local idioms already used by this repo. |

## Full Index

For the longer source-backed map, use [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index). It keeps the detailed reference table and source anchors.

## Continue Reading

Previous: [AI assistant developer guide](AI-Assistant-Developer-Guide) | Next: [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index)

Main map: [Home](Home) | Networking: [Networking and public variables](Networking-And-Public-Variables) | Source findings: [Deep-review findings](Deep-Review-Findings)
