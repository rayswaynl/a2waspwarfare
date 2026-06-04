# Arma 2 OA Compatibility Audit

Audit date: 2026-06-02. Scope: documentation and machine-readable wiki context for `rayswaynl/a2waspwarfare`.

This page records the Arma 2 OA compatibility check for scripting assumptions. The mission target is Arma 2: Operation Arrowhead / Combined Operations 1.64, not Arma 3.

## Checked

- Explicit `Arma 3`, `Arma3` and `A3` wording.
- Modern remote-execution terms: `remoteExec`, `remoteExecCall`, `isRemoteExecuted`, `remoteExecutedOwner` and `CfgRemoteExec`.
- Function/command assumptions around `BIS_fnc_MP`, SQF `params`, `private _var = ...`, `addMissionEventHandler`, `parseSimpleArray`, `isEqualTo`, `setGroupOwner`, `groupOwner`, modern `select` range/filter forms, A3-only string helpers, the A3 `selectRandom` command, `distance2D`, `lnbSetTooltip` and `try`/`catch` forms.
- CBA/ACE and Eden references that could be mistaken for required Arma 3-era dependencies.
- Source-root documentation outside `docs/wiki`, including `README.md`, `AGENTS.md`, `Guides/`, `Tools/*/README.md`, mission `Common/Config/readme.txt` files and machine-readable sample/config files.
- High-traffic pages: [LLM agent entry pack](LLM-Agent-Entry-Pack), [AI assistant developer guide](AI-Assistant-Developer-Guide), [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index), [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json), [`agent-knowledge.jsonl`](agent-knowledge.jsonl), [`agent-events.jsonl`](agent-events.jsonl) and [`llms.txt`](llms.txt).

## Source Basis

- [Arma 2 OA scripting command category](https://community.bohemia.net/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands) is the baseline for command availability.
- [remoteExec](https://community.bohemia.net/wiki/remoteExec) and [Arma 3 remote execution](https://community.bohemia.net/wiki/Arma_3:_Remote_Execution) are Arma 3-era and must not be imported into OA mission SQF.
- [params](https://community.bohemia.net/wiki/params) is Arma 3-era SQF syntax; OA mission parameters instead use `paramsArray` / `class Params`.
- [private](https://community.bohemia.net/wiki/private) supports OA-safe `private "_var"` and `private ["_var"]`; `private _var = value` is an Arma 3-style shortcut and should not appear in OA patch examples.
- [isEqualTo](https://community.bohemia.net/wiki/isEqualTo) and [isEqualType](https://community.bohemia.net/wiki/isEqualType) are Arma 3-era comparison helpers; OA patches should use `==`, `typeName` and explicit shape checks instead.
- [BIS_fnc_MP](https://community.bohemia.net/wiki/BIS_fnc_MP) is documented for Take On Helicopters and Arma 3, not as an OA-listed function. This mission already has its own PVF/publicVariable wrappers, so docs should not recommend `BIS_fnc_MP`.
- [setGroupOwner](https://community.bohemia.net/wiki/setGroupOwner) and [groupOwner](https://community.bohemia.net/wiki/groupOwner) are Arma 3 1.40 commands, not OA 1.64 commands; DR-21 HC mitigation can redirect future spawns but cannot live-transfer groups.
- [select](https://community.bohemia.net/wiki/select) is OA-safe for classic index/boolean/config forms, but the page also lists Arma 3-era substring/range/filter forms such as `string select [start,length]`, `array select [start,count]` and `array select {condition}`. Do not copy those newer examples into OA SQF.
- [selectRandom](https://community.bohemia.net/wiki/selectRandom) is an Arma 3 1.56 command. Do not rewrite OA-safe `_arr call BIS_fnc_selectRandom` or `_arr select floor(random count _arr)` into the command form.
- [distance2D](https://community.bohemia.net/wiki/distance2D) is an Arma 3 1.50 command. The mission uses the OA-compatible [BIS_fnc_distance2D](https://community.bohemia.net/wiki/BIS_fnc_distance2D) function in CoIn placement (`Client/Module/CoIn/coin_interface.sqf:602`); do not rewrite that source-backed function call to the command form.
- [lnbSetTooltip](https://community.bohemia.net/wiki/lnbSetTooltip) is an Arma 3 1.94 command. Keep OA UI notes on click hints, static text or existing control/listbox primitives unless an OA page proves a tooltip helper.
- [try](https://community.bohemia.net/wiki/try) / `catch` basic exception handling is listed for Arma 2 OA 1.50. The `args try code` alternate syntax on the BI page is Arma 3 1.54, so do not copy that form into OA examples.
- String helpers such as `splitString`, `joinString`, `trim` and regex matching are Arma 3-era conveniences unless an OA page/function proves otherwise. Wasp patches should use OA-safe `toArray`/`toString`, `find`, `select`, loops or local helper functions.
- [hasInterface](https://community.bohemia.net/wiki/hasInterface) is valid for Arma 2 OA 1.63+; BI's [A2OA 1.63 patch notes](https://community.bohemia.net/wiki/A2OA:_Patch_v1.63) also list it as a new scripting function for detecting headless clients or dedicated servers. Current source uses it in `Headless/Functions/HC_IsHeadlessClient.sqf` and several performance-scope helpers, so it is not an Arma 3-only command for the 1.64 target.
- [publicVariable](https://community.bohemia.net/wiki/publicVariable) is the BI-documented persistent/JIP-compatible broadcast primitive. [publicVariableClient](https://community.bohemia.net/wiki/publicVariableClient) is OA 1.62 targeted delivery and source-backed through `owner _player`, but BI notes it is not persistent/JIP-compatible. Use it for one-client replies, not late-join state reconstruction.
- [addPublicVariableEventHandler](https://community.bohemia.net/wiki/addPublicVariableEventHandler) is OA-compatible, but the current BI page also includes Arma 3 deprecation/alternative-syntax notes. Wasp docs should rely on the OA/source pattern that consumes the broadcast variable name/value and does not expose a trusted sender identity.
- [nearestObjects](https://community.bohemia.net/wiki/nearestObjects), [nearEntities](https://community.bohemia.net/wiki/nearEntities) and [nearObjects](https://community.bohemia.net/wiki/nearObjects) are OA-compatible object-detection commands, but they are not interchangeable. For DR-39, the command-center target is a structure, so `nearEntities` is the wrong optimization even though it is OA-safe for soldier/vehicle detection.

## Corrections Made

- Replaced stale DR-1 pseudocode that used Arma 3-style `private _fn` and `isEqualTo {}` with OA-safe `Private [...]`, `missionNamespace getVariable`, `typeName` and allowlist checks.
- Replaced stale DR-6 pseudocode `private _cost` with OA-safe `private "_cost";`.
- Removed an `isEqualTo` guard from the AntiStack extension hardening example; use `typeName`, `==` and shape checks instead.
- Changed guardrails that called `BIS_fnc_MP` simply "Arma 3-only" to the more precise "not listed for OA and not used by this mission".
- Corrected DR-21 HC failover wording: remove `setGroupOwner` live-transfer advice for OA 1.64; use future-spawn routing only unless runtime/source evidence proves another OA-safe path.
- Added explicit caveats that Bohemia pages can contain newer Arma 3 notes even when the linked primitive exists in OA.
- Added and expanded the `Tools/ValidateWiki.ps1` guardrail scan so high-traffic onboarding/current-state docs plus the canonical OA compatibility/reference pages fail validation if modern Arma 3/SQF terms appear without warning/caveat framing.
- Corrected the self-host field note that had treated all `try`/`catch` as unavailable; BI documents the basic form for OA 1.50, while the `args try code` alternate form remains Arma 3-era.
- Tightened networking docs so `publicVariableClient` remains an OA/source-backed unicast primitive, but not a persistent/JIP state mechanism.
- Reworded residual generic `params` prose in [Economy authority first cut](Economy-Authority-First-Cut) to `request arguments` / `payload values`, so it cannot be mistaken for the Arma 3 SQF `params` command.
- Reworded the DR-41 attack-wave `addAction` note in [Deep-review findings](Deep-Review-Findings) to say `addAction arguments`; source Chernarus and generated Vanilla both use an `addAction` argument array at `Client/FSM/updateclient.sqf:240`, not SQF `params`.

## No Doc Change Needed

- `JIP`, `publicVariable`, `publicVariableServer`, `publicVariableClient`, `addPublicVariableEventHandler`, `owner`, `paramsArray`, `class Params`, `hasInterface`, CBA warning suppression and `modACE` flags are valid or source-backed for this OA/CO mission context when worded as current docs do. `hasInterface` was re-checked on 2026-06-02 against the BI command page, the OA 1.63 patch notes and current mission source; `publicVariableClient` stays scoped to targeted sends, not JIP persistence.
- `BIS_fnc_selectRandom` is OA-compatible and source-backed in `Client_BuildUnit.sqf`; the command `selectRandom` is the Arma 3-only trap.
- `BIS_fnc_distance2D` is OA-compatible and source-backed in `Client/Module/CoIn/coin_interface.sqf`; the command `distance2D` is the Arma 3-only trap.
- Eden mentions found in source/docs refer to an Arma 2 terrain/folder name such as `Modded_Missions/...eden`, not the Arma 3 Eden editor.
- The source-root `Tools/PerformanceAuditAnalyzer/README.md` mentions [systemTime](https://community.bohemia.net/wiki/systemTime) only as a contrast; BI marks that command as introduced with Arma 3 2.00. The README correctly explains that Arma 2 OA mission-side audit anchors use SID/tick/frame instead of exporting a misleading wall-clock mission date.

## Inverse Traps

- `diag_tickTime` and `uiSleep` are OA-compatible in this mission context. Do not remove them as if they were Arma 3-only without a specific OA source/runtime reason.
- `setVehicleInit` and `processInitCommands` are OA-era commands that Arma 3 later removed. Wasp source uses hardcoded init strings; do not replace them only because Arma 3 documentation treats them differently.
- `apply` is an Arma 3 command and remains unsafe to import into OA snippets.

## Still Needs Runtime Confirmation

- Any future PVF dispatcher patch should be tested in Arma 2 OA dedicated and hosted sessions; source-only review cannot prove JIP ordering, scheduler timing or PVEH edge behavior.
- The docs assume `publicVariable` last-value availability for JIP from BI documentation, but feature-specific replay still depends on the mission's own state model.
- Current docs now avoid `publicVariableClient` persistence claims; OA runtime smoke is still needed before changing any feature from broadcast/resend to targeted replies.
- CBA/ACE compatibility remains a runtime/modpack question; current docs should not treat either as required unless source or server config proves it.

## Continue Reading

Previous: [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index) | Next: [AI assistant developer guide](AI-Assistant-Developer-Guide)

Main map: [Home](Home) | Reference guide: [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) | Networking: [Networking and public variables](Networking-And-Public-Variables)
