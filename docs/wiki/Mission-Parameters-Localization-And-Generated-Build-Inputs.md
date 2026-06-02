# Mission Parameters Localization And Generated Build Inputs

This page owns mission parameter flow, localization hazards and generated include/build inputs. It complements [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Tools and build workflow](Tools-And-Build-Workflow), [Content structure and maps](Content-Structure-And-Maps) and [Source fix propagation queue](Source-Fix-Propagation-Queue).

## Source Of Truth

`description.ext:52` includes `Rsc\Parameters.hpp`; the `class Params` order is the authoritative `paramsArray` index order. `description.ext:39` and `initJIPCompatible.sqf:4` both include `version.sqf`, but the file is absent in the current source checkout and is generated/ignored by LoadoutManager.

Source refs:

- `Rsc/Parameters.hpp:3-561` declares mission parameters.
- `Common/Init/Init_Parameters.sqf:5-10` caches parameter values.
- `initJIPCompatible.sqf:121` compiles parameters before constants; `:212` sets `WFBE_Parameters_Ready`.
- `Common/Init/Init_CommonConstants.sqf:65-67` documents the nil-default pattern that avoids overriding MP parameters.
- `Client/GUI/GUI_Display_Parameters.sqf:3-12` displays parameter names/statuses from the same `Params` tree.

## Parameter Cache Flow

1. `description.ext` includes `Rsc\Parameters.hpp`.
2. Arma populates `paramsArray` from `class Params` order in multiplayer.
3. `Init_Parameters.sqf` loops over `missionConfigFile >> "Params"`.
4. In multiplayer, it reads `paramsArray select _i`; in single-player, it reads each class `default`.
5. Each value is written to `missionNamespace` with the parameter class name.
6. `Init_CommonConstants.sqf` then fills nil defaults without overwriting already-cached MP values.

Runtime consumers include day/night duration, AFK timeout, AntiStack enable, performance audit enable, map icon blinking, bomb restrictions and many gameplay/economy toggles.

## In-Game Parameter Display

`RscDisplay_Parameters` loads `Client/GUI/GUI_Display_Parameters.sqf`, which reads titles/texts/values from `missionConfigFile >> "Params"` and current values from `paramsArray` or default. That makes the `Params` tree both the host setup source and the in-game reference display source.

## Localization Integrity

The scout pass found no live missing `$STR_...` keys for `Rsc/Parameters.hpp` references. Known quality gaps remain:

- `WFBE_C_ANTISTACK_ENABLED` and `WFBE_C_PERFORMANCE_AUDIT_ENABLED` use literal English titles in `Parameters.hpp:547-555`.
- `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` reuses `$STR_WF_PARAMETER_BombAltitude` at `Parameters.hpp:290-291`, while the consumer is distance-based.
- Several translated parameter/help strings fall back to English or contain stale text; treat `stringtable.xml` as functional but not polished.

## Version And Include Generation

`version.sqf` is included by both `description.ext` and `initJIPCompatible.sqf`, but it is not present in the current source mission. LoadoutManager generates it; `Tools/LoadoutManager/FileManagement/FileManager.cs:92-100` treats it specially, and terrain generation writes version output from the C# terrain flow.

Practical rule: a fresh source checkout is not self-contained for mission packing/testing until generated files exist. Use LoadoutManager from a correctly named `a2waspwarfare` checkout before claiming release readiness.

## LoadoutManager Overwrite Boundaries

Important tooling evidence:

- `FileManager.cs:59-84` and `:103-136` copy/delete outputs and remove destination extras.
- `FileManager.cs:140-152` requires an ancestor folder literally named `a2waspwarfare`; otherwise it throws.
- `BaseTerrain.cs:94-104` writes generated mission files such as EASA/balance/aircraft names/version outputs.
- `BaseTerrain.cs:35-66` rewrites the source mission `Sounds/description.ext` from `.ogg` filenames.
- `SqfFileGenerator.cs:127-135` calls package/zip operations after generation.
- `ZipManager.cs:73-77` throws if the `7za` environment variable is not set.

This is why the current `work\a` checkout cannot run LoadoutManager cleanly: it lacks the literal ancestor folder name expected by `FindA2WaspWarfareDirectory`.

## Patch And Validation Checklist

| Finding | Patch shape | Validation |
| --- | --- | --- |
| Literal English admin parameter titles | Add stringtable-backed titles for AntiStack and performance audit, or document them as intentionally admin-only English. | Parameter display shows intended labels; no missing stringtable keys. |
| Bomb distance title reuses altitude text | Add `STR_WF_PARAMETER_BombDistanceRestriction` and use it for `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION`. | Host parameter list and in-game parameter display distinguish altitude from distance. |
| Missing fallback for bomb distance | Add an `Init_CommonConstants.sqf` fallback or use `getVariable` default in the consumer. | Bomb-distance handling works in SP, MP and generated missions. |
| Literal `a2waspwarfare` root requirement | Discover repo root by project file, git root or explicit config rather than folder name. | LoadoutManager runs from `work\a` and a normal `a2waspwarfare` clone. |
| Missing `7za` aborts after generation | Split generation/copy from packaging or make missing `7za` a non-fatal packaging-only warning. | Generated files land even when package creation is skipped. |
| Generated files lack banners | Add generated-file banners to generated SQF/description/version outputs. | Future agents avoid hand-editing generated targets. |

## Developer Rules

- Do not reorder `class Params` without auditing every `paramsArray` index.
- Do not hand-edit generated Vanilla mission drift as a substitute for LoadoutManager propagation.
- Treat `version.sqf` as generated input, not missing dead code.
- Keep Arma 2 OA config syntax in mind; do not import Arma 3 `description.ext` assumptions.

Previous: [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) | Next: [Tools and build workflow](Tools-And-Build-Workflow)

Main map: [Home](Home) | Release gate: [Source fix propagation queue](Source-Fix-Propagation-Queue) | Machine ledger: [`agent-release-readiness.json`](agent-release-readiness.json)
